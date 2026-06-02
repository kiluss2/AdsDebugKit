//
//  AdsDebugExternalLogsVC.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

final class AdsDebugExternalLogsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let table = AdsDebugTableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .clear
        
        table.dataSource = self
        table.delegate = self
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reload),
            name: .adTelemetryUpdated,
            object: nil
        )
    }
    
    @objc private func reload() {
        table.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AdTelemetry.shared.externalEventsSnapshot().count + AdTelemetry.shared.debugLines.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        AdsDebugTheme.sectionHeader(title: "Logs (\(AdTelemetry.shared.externalEventsSnapshot().count + AdTelemetry.shared.debugLines.count))")
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        38
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = AdsDebugCardTableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.selectionStyle = .none
        
        let externalEvents = AdTelemetry.shared.externalEventsSnapshot()
        if indexPath.row < externalEvents.count {
            let item = externalEvents[indexPath.row]
            let time = DateFormatter.cached.string(from: item.time)
            var parts = item.values
                .filter { !["external_debug", "provider", "event", "status", "message"].contains($0.key) }
                .map { "\($0.key)=\(Self.compactValue($0.value))" }
                .sorted()
            if parts.count > 6 {
                parts = Array(parts.prefix(6)) + ["+\(parts.count - 6) more"]
            }
            if let message = item.message, !message.isEmpty {
                parts.insert(Self.compactValue(message), at: 0)
            }
            c.configure(
                title: "[\(time)] \(item.provider) • \(item.event) • \(item.status.rawValue)",
                detail: parts.joined(separator: " • "),
                titleColor: AdsDebugTheme.statusColor(item.status),
                titleFont: .systemFont(ofSize: 13, weight: .semibold),
                detailFont: .systemFont(ofSize: 11, weight: .regular)
            )
            return c
        }

        let rawIndex = indexPath.row - externalEvents.count
        let linesArray = AdTelemetry.shared.debugLines
        guard rawIndex < linesArray.count else { return c }
        
        let line = linesArray[rawIndex]
        let monoCell = AdsDebugMonoTableViewCell(style: .default, reuseIdentifier: nil)
        monoCell.configure(text: line, color: Self.externalLineColor(line))
        return monoCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let externalEvents = AdTelemetry.shared.externalEventsSnapshot()
        if indexPath.row < externalEvents.count {
            let item = externalEvents[indexPath.row]
            UIPasteboard.general.string = "\(item.provider) \(item.event) \(item.status.rawValue) \(item.message ?? "")"
            AdToast.show("Copied external event")
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        let linesArray = AdTelemetry.shared.debugLines
        let rawIndex = indexPath.row - externalEvents.count
        guard rawIndex < linesArray.count else { return }
        
        let line = linesArray[rawIndex]
        UIPasteboard.general.string = line
        AdToast.show("Copied log line")
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    private static func compactValue(_ value: String) -> String {
        let trimmed = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 140 else { return trimmed }
        return String(trimmed.prefix(137)) + "..."
    }

    private static func externalLineColor(_ line: String) -> UIColor {
        let lower = line.lowercased()
        if lower.contains("status=failed") ||
            lower.contains("request failed") ||
            lower.contains("status_code_failure") ||
            lower.contains("result=server_error") ||
            lower.contains("result=no_connectivity") ||
            lower.contains("failure") ||
            lower.contains(" error") {
            return AdsDebugTheme.failed
        }
        if lower.contains("status=success") ||
            lower.contains("ad revenue tracked") ||
            lower.contains("event tracked") ||
            lower.contains("tracked") ||
            lower.contains("track") ||
            lower.contains("success") ||
            lower.contains("transaction_id") ||
            lower.contains("failed=0") {
            return AdsDebugTheme.success
        }
        if lower.contains("status=submitted") || lower.contains("status=loading") {
            return AdsDebugTheme.loading
        }
        return AdsDebugTheme.textSecondary
    }
}
