//
//  AdsDebugAdjustLogsVC.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit
#if canImport(AdjustSdk)
import AdjustSdk
#endif

final class AdsDebugAdjustLogsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
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
        
        // Get ADID when opening Adjust Logs page (if Adjust SDK is available)
        #if canImport(AdjustSdk)
        Adjust.adid { adid in
            AdTelemetry.shared.logDebugLine("[ADID] \(adid ?? "nil")")
        }
        #endif
    }
    
    @objc private func reload() {
        table.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AdTelemetry.shared.debugLines.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Adjust Logs"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = UITableViewCell(style: .default, reuseIdentifier: nil)
        c.selectionStyle = .none
        
        let linesArray = AdTelemetry.shared.debugLines
        guard indexPath.row < linesArray.count else { return c }
        
        let line = linesArray[indexPath.row]
        c.textLabel?.text = line
        c.textLabel?.font = .systemFont(ofSize: 11)
        c.textLabel?.numberOfLines = 0
        if line.contains("[ViewAppear]") {
            c.textLabel?.textColor = .systemYellow
        } else if line.contains("Ad revenue tracked") {
            c.textLabel?.textColor = .systemGreen
        }
        c.detailTextLabel?.text = nil
        
        return c
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let linesArray = AdTelemetry.shared.debugLines
        guard indexPath.row < linesArray.count else { return }
        
        let line = linesArray[indexPath.row]
        UIPasteboard.general.string = line
        AdToast.show("Copied log line")
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

