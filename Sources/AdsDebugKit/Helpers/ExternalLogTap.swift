//
//  ExternalLogTap.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//  Optimized for Adjust v5 (OSLog) & Facebook (StdOut)
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
    private var logPollTimer: Timer?
    // Instead of using fetch time, we use the timestamp of the last processed log for better accuracy
    private var lastProcessedLogTime: Date = Date()
    private let sessionStartTime = Date()
    private var processedLogHashes = Set<Int>()
    
    // MARK: - Tunables
    private let adjustToken = "[Adjust]d: Got JSON response with message:"
    
    private let fbPurchaseToken = "fb_mobile_purchase"
    private let fbFlushResultToken = "Flush Result :"
    private var isFBPurchasePending = false
    
    private let mirrorToStderr = false
    private let maxRemainderBytes = 1 << 20

    private init() {}

    func start() {
        // A. Activate Pipe (Capture Facebook)
        startPipe()
        
        // B. Activate OSLog Polling (Capture Adjust)
        if #available(iOS 15.0, *) {
            startOSLogPolling()
        }
    }

    func stop() {
        // Stop Pipe
        src?.cancel()
        src = nil
        remainder.removeAll(keepingCapacity: false)
        
        // Stop OSLog Timer
        logPollTimer?.invalidate()
        logPollTimer = nil
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

        let q = DispatchQueue(label: "adjust.log.tap.read")
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
            }
            else {
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

        if remainder.count > maxRemainderBytes { remainder = remainder.suffix(4096) }
        
        if !batch.isEmpty {
            DispatchQueue.main.async {
                for msg in batch { AdTelemetry.shared.logDebugLine(msg) }
            }
        }
    }
    
    // MARK: - B. OSLog Scanning Logic (Optimized v2)
    
    @available(iOS 15.0, *)
    private func startOSLogPolling() {
        // IMPORTANT: Only start scanning from when this function is called.
        // No more backtracking to avoid re-capturing old logs from previous runs (if App wasn't fully killed)
        lastProcessedLogTime = Date()

        // Fix Delay: Switch to .userInitiated
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.logPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                DispatchQueue.global(qos: .utility).async {
                    self?.scanRecentOSLogs()
                }
            }
            self.logPollTimer?.fire()
            RunLoop.current.add(self.logPollTimer!, forMode: .default)
            RunLoop.current.run()
        }
    }
    
    @available(iOS 15.0, *)
    private func scanRecentOSLogs() {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            
            // Get position from the last processed time
            let position = store.position(date: lastProcessedLogTime)
            let entries = try store.getEntries(at: position)
            
            for entry in entries {
                guard let log = entry as? OSLogEntryLog else { continue }
                
                // 1. ANTI-LOOP LEVEL 1: Ignore logs created before App Start
                if log.date < sessionStartTime { continue }

                // 2. ANTI-LOOP LEVEL 2: Check timestamp
                // Log must be newer than the processed time (plus a small epsilon)
                if log.date <= lastProcessedLogTime.addingTimeInterval(0.0001) { continue }
                
                let msg = log.composedMessage
                
                // 3. ANTI-LOOP LEVEL 3 (Absolute): Use Hash
                // If content is identical AND time is identical -> Skip
                let logHash = log.date.hashValue ^ msg.hashValue
                if processedLogHashes.contains(logHash) { continue }
                
                // --- PROCESS LOG ---
                if msg.contains(adjustToken) {
                    
                    // If you want to filter out [Adjust]v uncomment below
                    // if msg.contains("[Adjust]v") { continue }
                    
                    // Update latest time marker
                    lastProcessedLogTime = log.date
                    
                    // Save hash so we don't process this again
                    processedLogHashes.insert(logHash)
                    
                    // Clean up hash set if too large (avoid long-term memory leak)
                    if processedLogHashes.count > 1000 { processedLogHashes.removeAll() }

                    let cleanMsg = "OSLog: \(msg)"
                    DispatchQueue.main.async {
                        AdTelemetry.shared.logDebugLine(cleanMsg)
                    }
                }
            }
        } catch {
             // print("Scan error: \(error)")
        }
    }
}
