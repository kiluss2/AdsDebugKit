//
//  AdsDebugStatesVC.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

final class AdsDebugStatesVC: UIViewController, UITableViewDataSource {
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        table.dataSource = self
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
    
    private func getAdStates() -> [AdStateInfo] {
        // Get states from AdTelemetry (already maintained and updated)
        return AdTelemetry.shared.getAdStates()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let states = getAdStates()
        return states.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.selectionStyle = .none
        
        let states = getAdStates()
        guard indexPath.row < states.count else { return c }
        
        let state = states[indexPath.row]
        
        c.textLabel?.text = state.adIdName
        
        // Build load status string with counts
        var loadText = state.loadState.rawValue
        var loadColor: UIColor = .systemGray
        if state.loadState == .loading {
            loadColor = state.loadState == .loading ? .systemOrange : .systemGray
        } else if state.loadState == .success {
            loadText += "(\(state.successCount))"
            loadColor = .systemGreen
        } else if state.loadState == .failed {
            if state.failedCount > 0 { loadText += "(\(state.failedCount))" }
        }
        
        // Build show status string with count
        let showText: String
        let showColor: UIColor?
        if state.showedCount > 0 {
            showText = "\(state.showedCount)"
            showColor = .systemGreen
        } else {
            showText = "No"
            showColor = .systemGray
        }
        
        // Build details as a list of tuples: (label, value, colorForValue)
        // Only the value part will be colored, not the label
        let details: [(String, String, UIColor?)] = [
            ("Load: ", loadText, loadColor),
            ("Show/impression: ", showText, showColor),
            ("Rev: ", String(format: "$%.4f", state.revenueUSD), state.revenueUSD > 0 ? .systemYellow : nil)
        ]

        let detailText = NSMutableAttributedString()
        for (i, item) in details.enumerated() {
            if i > 0 { detailText.append(.init(string: " • ")) }
            // Append label (no color)
            detailText.append(NSAttributedString(string: item.0))
            // Append value (with color if specified)
            let valueAttributes = item.2.map { [NSAttributedString.Key.foregroundColor: $0] }
            detailText.append(NSAttributedString(string: item.1, attributes: valueAttributes))
        }
        c.detailTextLabel?.attributedText = detailText
        c.detailTextLabel?.numberOfLines = 3
        
        // Color coding for load state
        switch state.loadState {
        case .success:
            c.textLabel?.textColor = .systemGreen
        case .failed:
            c.textLabel?.textColor = .systemRed
        case .loading:
            c.textLabel?.textColor = .systemOrange
        case .notLoad:
            c.textLabel?.textColor = .systemGray
        }
        
        return c
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "All IDs"
    }
}
