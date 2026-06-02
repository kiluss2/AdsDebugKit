import UIKit

final class AdsDebugAdUnitsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let table = AdsDebugTableView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.register(AdUnitModeCell.self, forCellReuseIdentifier: AdUnitModeCell.reuseID)
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
        AdTelemetry.shared.getAdUnits().count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        AdsDebugTheme.sectionHeader(title: "Ad Units (\(AdTelemetry.shared.getAdUnits().count))")
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        38
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let units = AdTelemetry.shared.getAdUnits()
        guard indexPath.row < units.count,
              let cell = tableView.dequeueReusableCell(withIdentifier: AdUnitModeCell.reuseID, for: indexPath) as? AdUnitModeCell else {
            return UITableViewCell()
        }
        let unit = units[indexPath.row]
        cell.configure(
            unit: unit,
            resolvedAdUnitId: AdTelemetry.shared.resolvedAdUnitIdForDisplay(unit),
            mode: AdTelemetry.shared.displayMode(for: unit)
        ) { [weak self] mode in
            AdTelemetry.shared.setCustomMode(mode, forAdUnitName: unit.name)
            self?.table.reloadRows(at: [indexPath], with: .automatic)
        }
        return cell
    }
}

private final class AdUnitModeCell: UITableViewCell {
    static let reuseID = "AdUnitModeCell"

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let idLabel = UILabel()
    private let unitLabel = UILabel()
    private let stack = UIStackView()
    private let visibleModes: [AdUnitCustomMode] = [.release, .debug, .falseAd]
    private var buttons: [UIButton] = []
    private var onMode: ((AdUnitCustomMode) -> Void)?
    private var currentMode: AdUnitCustomMode = .release

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = AdsDebugTheme.card
        cardView.layer.cornerRadius = AdsDebugTheme.cardCornerRadius
        cardView.layer.borderWidth = 0
        cardView.layer.masksToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = AdsDebugTheme.textPrimary
        titleLabel.numberOfLines = 0

        idLabel.font = .systemFont(ofSize: 11)
        idLabel.textColor = AdsDebugTheme.textMuted
        idLabel.numberOfLines = 0

        unitLabel.font = .systemFont(ofSize: 12, weight: .medium)
        unitLabel.textColor = AdsDebugTheme.textSecondary

        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fill

        let root = UIStackView(arrangedSubviews: [titleLabel, idLabel, unitLabel, stack])
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(root)

        buttons = visibleModes.map { mode in
            let button = UIButton(type: .system)
            button.setTitle(mode.displayName, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
            button.layer.cornerRadius = 7
            button.layer.borderWidth = 1
            button.tag = visibleModes.firstIndex(of: mode) ?? 0
            button.addTarget(self, action: #selector(modeTap(_:)), for: .touchUpInside)
            button.widthAnchor.constraint(equalToConstant: 76).isActive = true
            stack.addArrangedSubview(button)
            return button
        }

        let verticalGap = AdsDebugTheme.cardVerticalGap / 2
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalGap),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalGap),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AdsDebugTheme.cardHorizontalInset),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AdsDebugTheme.cardHorizontalInset),

            root.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AdsDebugTheme.cardContentVerticalPadding),
            root.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -AdsDebugTheme.cardContentVerticalPadding),
            root.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AdsDebugTheme.cardContentHorizontalPadding),
            root.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AdsDebugTheme.cardContentHorizontalPadding),
            stack.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        unit: AdDebugAdUnit,
        resolvedAdUnitId: String,
        mode: AdUnitCustomMode,
        onMode: @escaping (AdUnitCustomMode) -> Void
    ) {
        titleLabel.text = unit.name
        idLabel.text = "adUnit=\(resolvedAdUnitId.isEmpty ? "(empty ad unit id)" : resolvedAdUnitId)"
        unitLabel.text = unit.isReadOnly ? "unit=\(unit.unit.displayName) • readOnly=manifest_app_id" : "unit=\(unit.unit.displayName) • appliedMode=\(mode.displayName)"
        self.currentMode = mode
        self.onMode = onMode
        stack.isHidden = unit.isReadOnly
        updateButtons()
    }

    @objc private func modeTap(_ sender: UIButton) {
        let mode = visibleModes[sender.tag]
        onMode?(mode)
    }

    private func updateButtons() {
        for button in buttons {
            let mode = visibleModes[button.tag]
            let selected = mode == currentMode
            button.backgroundColor = selected ? AdsDebugTheme.modeButtonSelected : AdsDebugTheme.modeButtonBackground
            button.setTitleColor(selected ? AdsDebugTheme.selectedControlText : AdsDebugTheme.textSecondary, for: .normal)
            button.layer.borderColor = (selected ? mode.tintColor : AdsDebugTheme.buttonBorder).cgColor
        }
    }
}

private extension AdUnitCustomMode {
    var tintColor: UIColor {
        switch self {
        case .release:
            return AdsDebugTheme.success
        case .debug:
            return AdsDebugTheme.loading
        case .falseAd:
            return AdsDebugTheme.failed
        case .admobOnly:
            return AdsDebugTheme.textSecondary
        }
    }
}
