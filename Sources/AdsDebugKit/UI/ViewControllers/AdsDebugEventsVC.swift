//
//  AdsDebugEventsVC.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

final class AdsDebugEventsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
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
    
    // MARK: - TableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2 + AdTelemetry.shared.revenueByNetwork().count
        default:
            return AdTelemetry.shared.events.count
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ["Overview", "Latest Events"][section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.selectionStyle = .none
        
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                c.textLabel?.text = String(format: "Total revenue: $%.4f", AdTelemetry.shared.totalRevenueUSD())
                c.detailTextLabel?.text = nil
            } else if indexPath.row == 1 {
                c.textLabel?.text = "Events stored: \(AdTelemetry.shared.events.count)"
                c.detailTextLabel?.text = "Tap to copy JSON"
                c.selectionStyle = .default
            } else {
                let pair = AdTelemetry.shared.revenueByNetwork()[indexPath.row - 2]
                c.textLabel?.text = pair.0.isEmpty ? "Unknown ad network" : pair.0
                c.detailTextLabel?.text = String(format: "$%.4f", pair.1)
            }
            
        default:
            // Events are already newest-first (inserted at beginning)
            let eventArray = AdTelemetry.shared.events
            guard indexPath.row < eventArray.count else { break }
            
            let e = eventArray[indexPath.row]
            let time = DateFormatter.cached.string(from: e.time)
            if e.action == .custom("Will appear") { c.textLabel?.textColor = .systemYellow}
            c.textLabel?.text = "[\(time)] \(e.unit.raw) • \(e.action.rawValue)"
            
            var parts: [String] = []
            if let adIdName = e.adIdName {
                parts.append("name:\(adIdName)")
            }
            if let n = e.network { parts.append("nw:\(n)") }
            if let li = e.lineItem { parts.append("li:\(li)") }
            if let cp = e.eCPM { parts.append(String(format: "ecpm:$%.4f", cp)) }
            if let pr = e.precision { parts.append("prec:\(pr)") }
            if let err = e.error { parts.append("err:\(err)") }
            
            c.detailTextLabel?.text = parts.joined(separator: " • ")
            c.detailTextLabel?.numberOfLines = 3
        }
        
        return c
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 0, indexPath.row == 1 else { return }
        
        if let data = try? JSONEncoder().encode(AdTelemetry.shared.events),
           let str = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = str
            AdToast.show("Copied events JSON")
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}


