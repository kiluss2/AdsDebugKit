import UIKit

final class AdsDebugVC: UIViewController {
    static let tabTitles = ["Ad States", "Ad Events", "Externals", "Custom", "Settings", "Ad Units"]

    private let backgroundView = AdsDebugBackgroundView()
    private let header = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let tabScrollView = UIScrollView()
    private let tabStack = UIStackView()
    private let contentView = UIView()
    private var tabButtons: [UIButton] = []
    private var selectedIndex = 0

    private lazy var childControllers: [UIViewController] = [
        AdsDebugStatesVC(),
        AdsDebugEventsVC(),
        AdsDebugExternalLogsVC(),
        AdsDebugCustomVC(),
        AdsDebugSettingsVC(),
        AdsDebugAdUnitsVC()
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildBackground()
        buildHeader()
        buildTabs()
        buildContent()
        selectTab(0, animated: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            AdsDebugWindowManager.shared.hide()
        }
    }

    private func buildBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func buildHeader() {
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        titleLabel.text = "Ads Debug Kit"
        titleLabel.textColor = AdsDebugTheme.textPrimary
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        closeButton.setTitle("x", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .semibold)
        closeButton.tintColor = AdsDebugTheme.textSecondary
        closeButton.accessibilityLabel = "Close Ads Debug Kit"
        closeButton.addTarget(self, action: #selector(closeTap), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(closeButton)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func buildTabs() {
        tabScrollView.translatesAutoresizingMaskIntoConstraints = false
        tabScrollView.showsHorizontalScrollIndicator = false
        view.addSubview(tabScrollView)

        tabStack.axis = .horizontal
        tabStack.spacing = 8
        tabStack.alignment = .fill
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        tabScrollView.addSubview(tabStack)

        tabButtons = Self.tabTitles.enumerated().map { index, title in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            button.layer.cornerRadius = 8
            button.layer.borderWidth = 1
            button.tag = index
            button.addTarget(self, action: #selector(tabTap(_:)), for: .touchUpInside)
            tabStack.addArrangedSubview(button)
            return button
        }

        NSLayoutConstraint.activate([
            tabScrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tabScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabScrollView.heightAnchor.constraint(equalToConstant: 48),

            tabStack.topAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.topAnchor, constant: 6),
            tabStack.bottomAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.bottomAnchor, constant: -6),
            tabStack.leadingAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            tabStack.trailingAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            tabStack.heightAnchor.constraint(equalTo: tabScrollView.frameLayoutGuide.heightAnchor, constant: -12)
        ])
    }

    private func buildContent() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: tabScrollView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func tabTap(_ sender: UIButton) {
        selectTab(sender.tag, animated: true)
    }

    private func selectTab(_ index: Int, animated: Bool) {
        guard index >= 0, index < childControllers.count else { return }

        let current = children.first
        let next = childControllers[index]
        selectedIndex = index
        updateTabButtons()

        current?.willMove(toParent: nil)
        current?.view.removeFromSuperview()
        current?.removeFromParent()

        addChild(next)
        next.view.translatesAutoresizingMaskIntoConstraints = false
        next.view.alpha = animated ? 0 : 1
        contentView.addSubview(next.view)
        NSLayoutConstraint.activate([
            next.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            next.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            next.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            next.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        next.didMove(toParent: self)

        if animated {
            UIView.animate(withDuration: 0.16) {
                next.view.alpha = 1
            }
        }
    }

    private func updateTabButtons() {
        for button in tabButtons {
            let isSelected = button.tag == selectedIndex
            button.backgroundColor = isSelected ? AdsDebugTheme.tabSelected : AdsDebugTheme.buttonBackground
            button.setTitleColor(isSelected ? .white : AdsDebugTheme.textSecondary, for: .normal)
            button.layer.borderColor = (isSelected ? AdsDebugTheme.buttonBorderActive : AdsDebugTheme.buttonBorder).cgColor
        }
    }

    @objc private func closeTap() {
        AdsDebugWindowManager.shared.hide()
    }
}
