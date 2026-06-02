//
//  ExternalLogTap.swift
//  AdsDebugKit
//

import Foundation
import Darwin
import OSLog

final class ExternalLogTap {
    static let shared = ExternalLogTap()
    private init() {}

    // KEEP EXACT TOKEN
    private let adjustToken = "[Adjust]d: Got JSON response with message:"

    // MARK: - Pipe (stdout/stderr) - keep your existing behavior
    private var src: DispatchSourceRead?
    private var remainder = Data()
    private var originalStdout: Int32 = -1
    private var originalStderr: Int32 = -1
    private let mirrorToStderr = false
    private let maxRemainderBytes = 1 << 20

    // Facebook tokens (giữ logic cũ)
    private let fbPurchaseToken = "fb_mobile_purchase"
    private let fbFlushResultToken = "Flush Result :"
    private var isFBPurchasePending = false

    // MARK: - OSLog poller holder (must be Any? to avoid iOS<15 availability errors)
    private var osPollerAny: Any?

    func start() {
        startPipe()

        if #available(iOS 15.0, *) {
            startOSLogPoller_iOS15()
        }
    }

    func stop() {
        // Stop pipe
        src?.cancel()
        src = nil
        remainder.removeAll(keepingCapacity: false)

        // Stop OSLog poller
        if #available(iOS 15.0, *) {
            (osPollerAny as? OSLogAdjustPoller)?.stop()
            osPollerAny = nil
        }
    }

    // MARK: - A. Pipe capture (Facebook / legacy print)

    private func startPipe() {
        guard src == nil else { return }

        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)

        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)

        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else { return }
        let rfd = fds[0], wfd = fds[1]
        _ = fcntl(rfd, F_SETFL, O_NONBLOCK)

        dup2(wfd, STDOUT_FILENO)
        dup2(wfd, STDERR_FILENO)
        close(wfd)

        let q = DispatchQueue(label: "external.log.tap.read", qos: .utility)
        let s = DispatchSource.makeReadSource(fileDescriptor: rfd, queue: q)

        s.setEventHandler { [weak self] in
            guard let self else { return }
            var localBuffer = [UInt8](repeating: 0, count: 64 * 1024)

            while true {
                let n = read(rfd, &localBuffer, localBuffer.count)
                if n > 0 {
                    localBuffer.withUnsafeBytes { bytes in
                        if self.originalStdout >= 0 { _ = write(self.originalStdout, bytes.baseAddress, n) }
                        if self.mirrorToStderr, self.originalStderr >= 0 { _ = write(self.originalStderr, bytes.baseAddress, n) }
                    }
                    let chunk = Data(localBuffer[0..<n])
                    self.ingest(chunk)
                } else {
                    break
                }
            }
        }

        s.setCancelHandler { [weak self] in
            close(rfd)
            guard let self else { return }

            if self.originalStdout >= 0 {
                dup2(self.originalStdout, STDOUT_FILENO)
                close(self.originalStdout)
                self.originalStdout = -1
            }

            if self.originalStderr >= 0 {
                dup2(self.originalStderr, STDERR_FILENO)
                close(self.originalStderr)
                self.originalStderr = -1
            }
        }

        s.resume()
        src = s
    }

    private func ingest(_ chunk: Data) {
        remainder.append(chunk)
        var batch: [String] = []

        while let nlIndex = remainder.firstIndex(of: 0x0A) {
            var lineBytes = remainder[..<nlIndex]
            remainder.removeSubrange(..<remainder.index(after: nlIndex))
            if let last = lineBytes.last, last == 0x0D { lineBytes = lineBytes.dropLast() }

            let line = String(data: Data(lineBytes), encoding: .utf8) ?? String(decoding: lineBytes, as: UTF8.self)

            if line.contains(adjustToken) {
                if let r = line.range(of: "[Adjust]") {
                    batch.append(String(line[r.lowerBound...]).trimmingCharacters(in: .whitespaces))
                }
            } else {
                if line.contains(fbPurchaseToken) { isFBPurchasePending = true }
                if line.contains(fbFlushResultToken) {
                    if isFBPurchasePending {
                        let cleanMsg = line.trimmingCharacters(in: .whitespaces)
                        batch.append("[FaceBook]: Purchase " + cleanMsg)
                    }
                    isFBPurchasePending = false
                }
            }
        }

        if remainder.count > maxRemainderBytes {
            remainder = remainder.suffix(4096)
        }

        if !batch.isEmpty {
            AdTelemetry.shared.logDebugLines(batch)
        }
    }

    // MARK: - B. OSLog polling (Adjust) - iOS 15+

    @available(iOS 15.0, *)
    private func startOSLogPoller_iOS15() {
        if let p = osPollerAny as? OSLogAdjustPoller {
            p.start() // idempotent
            return
        }

        let poller = OSLogAdjustPoller(
            adjustToken: adjustToken,
            sink: { lines in
                AdTelemetry.shared.logDebugLines(lines)
            }
        )
        osPollerAny = poller
        poller.start()
    }
}

// MARK: - iOS 15+ OSLog poller (NO availability issues)

@available(iOS 15.0, *)
private final class OSLogAdjustPoller {
    private let adjustToken: String
    private let sink: ([String]) -> Void

    private let q = DispatchQueue(label: "external.log.tap.oslog", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var store: OSLogStore?

    private var lastProcessed: Date = .distantPast
    private var processedHashes = Set<Int>()

    // Tunables (quan trọng để không miss log do OSLog delay)
    private let interval: TimeInterval = 1.0
    private let initialBackfill: TimeInterval = 60     // ✅ rộng hơn để bắt kịp log delay
    private let overlap: TimeInterval = 8              // ✅ overlap nhẹ tránh miss
    private let maxEntriesPerTick = 1200               // ✅ giới hạn để tránh lag
    private let maxBatch = 150
    private let hashesCap = 6000

    init(adjustToken: String, sink: @escaping ([String]) -> Void) {
        self.adjustToken = adjustToken
        self.sink = sink
    }

    func start() {
        q.async { [weak self] in
            guard let self else { return }
            if self.timer != nil { return }

            if self.store == nil {
                self.store = try? OSLogStore(scope: .currentProcessIdentifier)
            }
            guard self.store != nil else { return }

            // ✅ Bắt đầu từ “quá khứ” để tránh miss do buffer/delay
            let startFrom = Date().addingTimeInterval(-self.initialBackfill)
            self.lastProcessed = startFrom
            self.processedHashes.removeAll(keepingCapacity: true)

            let t = DispatchSource.makeTimerSource(queue: self.q)
            t.schedule(deadline: .now() + 0.2, repeating: self.interval, leeway: .milliseconds(250))
            t.setEventHandler { [weak self] in
                self?.scan()
            }
            self.timer = t
            t.resume()
        }
    }

    func stop() {
        q.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = nil
            self.store = nil
            self.lastProcessed = .distantPast
            self.processedHashes.removeAll(keepingCapacity: false)
        }
    }

    private func scan() {
        guard let store else { return }

        let windowStart = max(lastProcessed.addingTimeInterval(-overlap),
                              Date().addingTimeInterval(-300)) // safety cap 5 phút

        do {
            let position = store.position(date: windowStart)
            let entries = try store.getEntries(at: position)

            var newestSeen = lastProcessed
            var batch: [String] = []
            var scanned = 0

            for entry in entries {
                scanned += 1
                if scanned > maxEntriesPerTick { break }

                guard let log = entry as? OSLogEntryLog else { continue }
                if log.date < windowStart { continue }

                if log.date > newestSeen { newestSeen = log.date }

                let msg = log.composedMessage

                guard msg.contains(adjustToken) else { continue }

                // de-dup
                let h = log.date.hashValue ^ msg.hashValue
                if processedHashes.contains(h) { continue }
                processedHashes.insert(h)
                if processedHashes.count > hashesCap {
                    processedHashes.removeAll(keepingCapacity: true)
                }

                batch.append("OSLog: \(msg.trimmingCharacters(in: .whitespaces))")
                if batch.count >= maxBatch { break }
            }

            // ✅ ALWAYS advance watermark (cực quan trọng)
            if newestSeen > lastProcessed {
                lastProcessed = newestSeen
            }

            if !batch.isEmpty {
                sink(batch)
            }
        } catch {
            // nếu lỗi store, lùi nhẹ để lần sau vẫn scan được
            lastProcessed = max(lastProcessed.addingTimeInterval(-2),
                                Date().addingTimeInterval(-initialBackfill))
        }
    }
}
