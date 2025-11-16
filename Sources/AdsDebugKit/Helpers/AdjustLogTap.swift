//
//  AdjustLogTap.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//  Optimized & safe version
//

import Foundation
import Darwin

/// Taps into the app's stdout/stderr, mirrors them back to the console,
/// and extracts specific Adjust log lines to forward to AdTelemetry.
final class AdjustLogTap {
    static let shared = AdjustLogTap() // Simple singleton access

    private var src: DispatchSourceRead?          // GCD source that watches the pipe's read FD
    private var remainder = Data()                // Holds partial line bytes (UTF-8 safe)
    private var originalStdout: Int32 = -1        // Backup of original stdout FD
    private var originalStderr: Int32 = -1        // Backup of original stderr FD

    // Tunables
    private let matchToken = "[Adjust]d: Got JSON response with message:" // Target substring to detect
    private let mirrorToStderr = false           // Usually mirroring stdout is sufficient
    private let maxRemainderBytes = 1 << 20      // 1 MB safeguard for partial-buffer growth

    private init() {}

    /// Starts intercepting stdout/stderr and processing log lines.
    /// Safe to call multiple times; subsequent calls are ignored.
    func start() {
        guard src == nil else { return }

        // 1) Preserve original FDs so we can mirror output and restore later.
        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)

        // 2) Disable stdio buffering to reduce log latency.
        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)

        // 3) Create a pipe; we'll read from rfd and redirect stdout/stderr to wfd.
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else { return }
        let rfd = fds[0], wfd = fds[1]
        _ = fcntl(rfd, F_SETFL, O_NONBLOCK) // Non-blocking read to avoid stalling

        // 4) Redirect both stdout & stderr to the pipe's writer end.
        dup2(wfd, STDOUT_FILENO)
        dup2(wfd, STDERR_FILENO)
        close(wfd) // Writer FD is now owned by stdout/stderr

        // 5) Install a read source on a private queue to drain the pipe promptly.
        let q = DispatchQueue(label: "adjust.log.tap.read")
        let s = DispatchSource.makeReadSource(fileDescriptor: rfd, queue: q)

        s.setEventHandler { [weak self] in
            guard let self = self else { return }

            // Drain available bytes (up to 64 KB per inner read) per event.
            var localBuffer = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                let n = read(rfd, &localBuffer, localBuffer.count)
                if n > 0 {
                    // Mirror raw bytes back to original console (no re-encoding).
                    localBuffer.withUnsafeBytes { bytes in
                        if self.originalStdout >= 0 {
                            _ = write(self.originalStdout, bytes.baseAddress, n)
                        }
                        if self.mirrorToStderr, self.originalStderr >= 0 {
                            _ = write(self.originalStderr, bytes.baseAddress, n)
                        }
                    }

                    // Feed captured bytes into our UTF-8 aware line parser.
                    let chunk = Data(localBuffer[0..<n])
                    self.ingest(chunk)
                } else {
                    // n == 0: writer closed, or n == -1 (EAGAIN etc.). Break and let the source re-fire later.
                    break
                }
            }
        }

        s.setCancelHandler { [weak self] in
            // Close the read FD and restore original stdout/stderr.
            close(rfd)
            if let self = self {
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
        }

        s.resume()
        src = s
    }

    /// Stops intercepting and restores stdout/stderr.
    func stop() {
        src?.cancel()
        src = nil
        remainder.removeAll(keepingCapacity: false)
    }

    // MARK: - Parsing & Filtering (UTF-8 safe)

    /// Append bytes, extract complete lines by '\n', decode to UTF-8, and batch-match Adjust logs.
    private func ingest(_ chunk: Data) {
        remainder.append(chunk)

        var batch: [String] = []

        // Look for newline (0x0A). If line ends with '\r\n', trim the '\r'.
        while let nlIndex = remainder.firstIndex(of: 0x0A) {
            var lineBytes = remainder[..<nlIndex]
            let nextStart = remainder.index(after: nlIndex)
            remainder.removeSubrange(..<nextStart)

            if let last = lineBytes.last, last == 0x0D {
                lineBytes = lineBytes.dropLast()
            }

            // UTF-8 decode (strict first, lossy fallback if needed).
            let line: String = String(data: Data(lineBytes), encoding: .utf8)
                ?? String(decoding: lineBytes, as: UTF8.self)

            // Only forward Adjust messages of interest.
            if line.contains(matchToken) {
                // Skip pure OSLog headers
                if let r = line.range(of: "[Adjust]") {
                    let clean = String(line[r.lowerBound...])
                    batch.append(clean)
                }
            }
        }

        // Safety cap: if we never see a newline for a long time, bound memory usage.
        if remainder.count > maxRemainderBytes {
            remainder = remainder.suffix(4096) // keep tail to preserve partial UTF-8
        }

        // Emit matches once per chunk to avoid flooding the main thread.
        if !batch.isEmpty {
            DispatchQueue.main.async {
                for msg in batch {
                    AdTelemetry.shared.logDebugLine(msg)
                }
            }
        }
    }
}
