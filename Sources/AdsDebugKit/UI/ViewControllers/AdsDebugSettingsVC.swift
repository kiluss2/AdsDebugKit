//
//  AdsDebugSettingsVC.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

final class AdsDebugSettingsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
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
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = UITableViewCell(style: .value1, reuseIdentifier: nil)
        c.selectionStyle = .default
        
        switch indexPath.row {
        case 0:
            c.textLabel?.text = "Debug Mode"
            let sw = UISwitch()
            sw.isOn = AdTelemetry.isDebugEnabled()
            sw.addTarget(self, action: #selector(toggleDebugMode(_:)), for: .valueChanged)
            c.accessoryView = sw
            c.selectionStyle = .none
        case 1:
            c.textLabel?.text = "Show toasts"
            let sw = UISwitch()
            sw.isOn = AdTelemetry.shared.settings.showToasts
            sw.addTarget(self, action: #selector(toggleToast(_:)), for: .valueChanged)
            c.accessoryView = sw
            c.selectionStyle = .none
        default:
            c.textLabel?.text = "Keep Events"
            c.detailTextLabel?.text = "\(AdTelemetry.shared.settings.keepEvents)"
            c.accessoryType = .disclosureIndicator
        }
        
        return c
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row == 2 else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        
        showKeepEventsEditor()
    }
    
    private func showKeepEventsEditor() {
        let alert = UIAlertController(title: "Keep Events", message: "Number of events to keep (1-1000)", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
            textField.text = "\(AdTelemetry.shared.settings.keepEvents)"
            textField.placeholder = "200"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let textField = alert.textFields?.first,
                  let text = textField.text,
                  let value = Int(text),
                  value >= 1 && value <= 1000 else {
                return
            }
            
            var s = AdTelemetry.shared.settings
            s.keepEvents = value
            AdTelemetry.shared.settings = s
            
            // Reload table to show updated value
            self?.table.reloadData()
        })
        
        present(alert, animated: true)
    }
    
    @objc private func toggleDebugMode(_ sw: UISwitch) {
        AdTelemetry.setDebugEnabled(sw.isOn)
    }
    
    @objc private func toggleToast(_ sw: UISwitch) {
        var s = AdTelemetry.shared.settings
        s.showToasts = sw.isOn
        AdTelemetry.shared.settings = s
    }
}


