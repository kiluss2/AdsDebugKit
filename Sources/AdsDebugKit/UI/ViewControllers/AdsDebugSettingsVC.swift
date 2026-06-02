import UIKit

final class AdsDebugSettingsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private enum Row: Int, CaseIterable {
        case debugEnabled
        case showToasts
        case rawLogTap
        case keepEvents
        case editKeepEvents
        case overrideMode
        case cycleMode
        case clearEvents
    }

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
        Row.allCases.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        AdsDebugTheme.sectionHeader(title: "Settings")
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        38
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = Row(rawValue: indexPath.row) else {
            return UITableViewCell()
        }

        switch row {
        case .debugEnabled:
            return makeSwitchCell(title: "Debug enabled", isOn: AdTelemetry.isDebugEnabled(), tag: row.rawValue)
        case .showToasts:
            return makeSwitchCell(title: "Show event toasts", isOn: AdTelemetry.shared.settings.showToasts, tag: row.rawValue)
        case .rawLogTap:
            return makeSwitchCell(title: "Legacy raw log tap", isOn: AdTelemetry.shared.settings.rawLogTapEnabled, tag: row.rawValue)
        case .keepEvents:
            return makeCardCell(title: "Keep events", lines: ["value=\(AdTelemetry.shared.settings.keepEvents)"])
        case .editKeepEvents:
            return makeButtonCell(title: "Edit keep events", color: AdsDebugTheme.textPrimary)
        case .overrideMode:
            return makeOverrideCell()
        case .cycleMode:
            return makeButtonCell(title: "Cycle mode", color: AdsDebugTheme.textPrimary)
        case .clearEvents:
            return makeButtonCell(title: "Clear events", color: AdsDebugTheme.failed)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = Row(rawValue: indexPath.row) else { return }

        switch row {
        case .editKeepEvents:
            showKeepEventsEditor()
        case .overrideMode:
            showOverrideModePicker()
        case .cycleMode:
            cycleMode()
        case .clearEvents:
            AdTelemetry.shared.clearEvents()
            AdToast.show("Cleared debug events")
        default:
            break
        }
    }

    private func makeSwitchCell(title: String, isOn: Bool, tag: Int) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = AdsDebugTheme.textPrimary
        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)

        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.tag = tag
        toggle.onTintColor = AdsDebugTheme.switchOn
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [titleLabel, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: AdsDebugTheme.cardHorizontalInset),
            row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 26)
        ])

        return cell
    }

    private func makeCardCell(title: String, lines: [String]) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none

        let card = makeCardView()
        let stack = makeCardStack()
        card.addSubview(stack)
        cell.contentView.addSubview(card)

        let titleLabel = makeTitleLabel(title)
        stack.addArrangedSubview(titleLabel)
        lines.forEach { stack.addArrangedSubview(makeLineLabel($0)) }

        pinCard(card, stack: stack, to: cell.contentView)
        return cell
    }

    private func makeOverrideCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.selectionStyle = .default

        let card = makeCardView()
        let stack = makeCardStack()
        card.addSubview(stack)
        cell.contentView.addSubview(card)

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 10

        let titleLabel = makeTitleLabel("Ad ID override")
        let infoLabel = UILabel()
        infoLabel.text = "i"
        infoLabel.textAlignment = .center
        infoLabel.textColor = AdsDebugTheme.textPrimary
        infoLabel.font = .systemFont(ofSize: 13, weight: .bold)
        infoLabel.backgroundColor = AdsDebugTheme.card
        infoLabel.layer.cornerRadius = 14
        infoLabel.layer.borderWidth = 1
        infoLabel.layer.borderColor = AdsDebugTheme.buttonBorderActive.cgColor
        infoLabel.layer.masksToBounds = true
        infoLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true
        infoLabel.heightAnchor.constraint(equalToConstant: 28).isActive = true

        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(infoLabel)
        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(makeLineLabel("mode=\(AdTelemetry.shared.settings.adIdOverrideMode.rawValue)"))
        stack.addArrangedSubview(makeLineLabel("Cycle: normal/fail-primary/fail-all/force-admob-only/custom."))

        pinCard(card, stack: stack, to: cell.contentView)
        return cell
    }

    private func makeButtonCell(title: String, color: UIColor) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.selectionStyle = .default

        let buttonView = UIView()
        buttonView.backgroundColor = AdsDebugTheme.buttonBackground
        buttonView.layer.cornerRadius = AdsDebugTheme.cardCornerRadius
        buttonView.layer.borderWidth = 1
        buttonView.layer.borderColor = AdsDebugTheme.buttonBorder.cgColor
        buttonView.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(buttonView)

        let label = UILabel()
        label.text = title
        label.textAlignment = .center
        label.textColor = color
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        buttonView.addSubview(label)

        NSLayoutConstraint.activate([
            buttonView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: AdsDebugTheme.cardVerticalGap / 2),
            buttonView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -AdsDebugTheme.cardVerticalGap / 2),
            buttonView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: AdsDebugTheme.cardHorizontalInset),
            buttonView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -AdsDebugTheme.cardHorizontalInset),
            buttonView.heightAnchor.constraint(equalToConstant: 48),

            label.leadingAnchor.constraint(equalTo: buttonView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: buttonView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: buttonView.centerYAnchor)
        ])

        return cell
    }

    private func makeCardView() -> UIView {
        let card = UIView()
        card.backgroundColor = AdsDebugTheme.card
        card.layer.cornerRadius = AdsDebugTheme.cardCornerRadius
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private func makeCardStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func makeTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = AdsDebugTheme.textPrimary
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.numberOfLines = 2
        return label
    }

    private func makeLineLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = AdsDebugTheme.textSecondary
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.numberOfLines = 0
        return label
    }

    private func pinCard(_ card: UIView, stack: UIStackView, to contentView: UIView) {
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AdsDebugTheme.cardVerticalGap / 2),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AdsDebugTheme.cardVerticalGap / 2),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AdsDebugTheme.cardHorizontalInset),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AdsDebugTheme.cardHorizontalInset),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: AdsDebugTheme.cardContentVerticalPadding),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AdsDebugTheme.cardContentVerticalPadding),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AdsDebugTheme.cardContentHorizontalPadding),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AdsDebugTheme.cardContentHorizontalPadding)
        ])
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        guard let row = Row(rawValue: sender.tag) else { return }

        switch row {
        case .debugEnabled:
            AdTelemetry.setDebugEnabled(sender.isOn)
        case .showToasts:
            var settings = AdTelemetry.shared.settings
            settings.showToasts = sender.isOn
            AdTelemetry.shared.settings = settings
        case .rawLogTap:
            AdTelemetry.shared.setRawLogTapEnabled(sender.isOn)
        default:
            break
        }
    }

    private func showOverrideModePicker() {
        let alert = UIAlertController(title: "Ad ID Override", message: nil, preferredStyle: .actionSheet)
        for mode in AdIdOverrideMode.allCases {
            alert.addAction(UIAlertAction(title: mode.displayName, style: .default) { [weak self] _ in
                AdTelemetry.shared.setAdIdOverrideMode(mode)
                self?.table.reloadData()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showKeepEventsEditor() {
        let alert = UIAlertController(
            title: "Keep Events",
            message: "Number of events/log lines to keep (1-1000)",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
            textField.text = "\(AdTelemetry.shared.settings.keepEvents)"
            textField.placeholder = "\(AdTelemetry.shared.settings.keepEvents)"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let text = alert.textFields?.first?.text,
                  let value = Int(text),
                  value >= 1 && value <= 1000 else {
                return
            }
            var settings = AdTelemetry.shared.settings
            settings.keepEvents = value
            AdTelemetry.shared.settings = settings
            self?.table.reloadData()
        })
        present(alert, animated: true)
    }

    private func cycleMode() {
        let nextMode: AdIdOverrideMode
        switch AdTelemetry.shared.settings.adIdOverrideMode {
        case .normal:
            nextMode = .failPrimary
        case .failPrimary:
            nextMode = .failAll
        case .failAll:
            nextMode = .forceAdMobOnly
        case .forceAdMobOnly:
            nextMode = .custom
        case .custom:
            nextMode = .normal
        }

        AdTelemetry.shared.setAdIdOverrideMode(nextMode)
        table.reloadData()
    }
}
