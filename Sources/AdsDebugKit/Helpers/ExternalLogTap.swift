//
//  ExternalLogTap.swift
//  AdsDebugKit
//

import Foundation
import Darwin
import OSLog

final class ExternalLogTap {
    static let shared = ExternalLogTap()

    // MARK: - Pipe Properties (For Facebook & Debug mode)
    private var src: DispatchSourceRead?
    private var remainder = Data()
    private var originalStdout: Int32 = -1
    private var originalStderr: Int32 = -1

    // MARK: - OSLog Properties (For Adjust Standalone mode)
    private var isOSLogPolling = false
    private var lastProcessedLogTime: Date = Date()
    private var sessionStartTime: Date = Date()

    // De-dup ONLY for matched logs
    private var processedLogHashes = Set<Int>()

    // ❗️Do NOT annotate stored properties with @available.
    // Use Any? to keep compatibility with iOS < 15 targets.
    private var osStoreAny: Any?
    private var osTimerAny: Any?

    // MARK: - Tunables
    // ✅ KEEP EXACT TOKEN
    private let adjustToken = "[Adjust]d: Got JSON response with message:"

    private let fbPurchaseToken = "fb_mobile_purchase"
    private let fbFlushResultToken = "Flush Result :"
    private var isFBPurchasePending = false

    private let mirrorToStderr = false
    private let maxRemainderBytes = 1 << 20

    private init() {}

    func start() {
        startPipe()
        if #available(iOS 15.0, *) {
            startOSLogPolling()
        }
    }

    func stop() {
        // Stop Pipe
        src?.cancel()
        src = nil
        remainder.removeAll(keepingCapacity: false)

        // Stop OSLog Polling
        if #available(iOS 15.0, *) {
            stopOSLogPolling()
        }
    }

    // MARK: - A. Standard Output Pipe Logic (Facebook)

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

        let q = DispatchQueue(label: "adjust.log.tap.read", qos: .utility)
        let s = DispatchSource.makeReadSource(fileDescriptor: rfd, queue: q)

        s.setEventHandler { [weak self] in
            guard let self = self else { return }
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
            guard let self = self else { return }

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
                    batch.append(String(line[r.lowerBound...]))
                }
            } else {
                if line.contains(fbPurchaseToken) {
                    isFBPurchasePending = true
                }
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

    // MARK: - B. OSLog Scanning Logic (Optimized)

    @available(iOS 15.0, *)
    private func startOSLogPolling() {
        guard !isOSLogPolling else { return }
        isOSLogPolling = true

        sessionStartTime = Date()
        lastProcessedLogTime = sessionStartTime
        processedLogHashes.removeAll(keepingCapacity: true)

        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            osStoreAny = store
        } catch {
            osStoreAny = nil
            isOSLogPolling = false
            return
        }

        let q = DispatchQueue(label: "adjust.log.tap.oslog", qos: .utility)
        let t = DispatchSource.makeTimerSource(queue: q)
        t.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(250))
        t.setEventHandler { [weak self] in
            self?.scanRecentOSLogs_iOS15()
        }
        t.resume()
        osTimerAny = t
    }

    @available(iOS 15.0, *)
    private func stopOSLogPolling() {
        isOSLogPolling = false

        if let t = osTimerAny as? DispatchSourceTimer {
            t.cancel()
        }
        osTimerAny = nil
        osStoreAny = nil
    }

    @available(iOS 15.0, *)
    private func scanRecentOSLogs_iOS15() {
        guard let store = osStoreAny as? OSLogStore else { return }

        do {
            let position = store.position(date: lastProcessedLogTime)
            let entries = try store.getEntries(at: position)

            var newestSeen = lastProcessedLogTime
            var batch: [String] = []
            var scanned = 0

            for entry in entries {
                scanned += 1
                if scanned > 2500 { break }

                guard let log = entry as? OSLogEntryLog else { continue }

                // ✅ always advance watermark candidate
                if log.date > newestSeen { newestSeen = log.date }

                if log.date < sessionStartTime { continue }
                if log.date <= lastProcessedLogTime.addingTimeInterval(0.0001) { continue }

                let msg = log.composedMessage

                // ✅ KEEP EXACT TOKEN FILTER
                guard msg.contains(adjustToken) else { continue }

                // de-dup for matched logs
                let h = log.date.hashValue ^ msg.hashValue
                if processedLogHashes.contains(h) { continue }
                processedLogHashes.insert(h)
                if processedLogHashes.count > 3000 {
                    processedLogHashes.removeAll(keepingCapacity: true)
                }

                batch.append("OSLog: \(msg)")
                if batch.count >= 120 { break }
            }

            // ✅ critical fix: advance even if no matched logs
            if newestSeen > lastProcessedLogTime {
                lastProcessedLogTime = newestSeen.addingTimeInterval(0.0001)
            }

            if !batch.isEmpty {
                AdTelemetry.shared.logDebugLines(batch)
            }
        } catch {
            // silent
        }
    }
}
