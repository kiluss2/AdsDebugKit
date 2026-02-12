//
//  AdTelemetry.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit
import Foundation

public final class AdTelemetry {
    // MARK: - Singleton

    public static let shared = AdTelemetry()

    private init() {
        q.setSpecific(key: qKey, value: ())
    }

    // MARK: - Settings

    public struct Settings: Codable {
        public var debugEnabled: Bool = false
        public var showToasts: Bool = false
        public var keepEvents: Int = 100

        public init(debugEnabled: Bool = false, showToasts: Bool = false, keepEvents: Int = 100) {
            self.debugEnabled = debugEnabled
            self.showToasts = showToasts
            self.keepEvents = keepEvents
        }
    }

    // MARK: - Properties

    // Configuration
    private var configuration: AdTelemetryConfiguration?

    // Queue for thread-safe operations
    private let q = DispatchQueue(label: "telemetry.ads.q")
    private let qKey = DispatchSpecificKey<Void>()

    private var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: qKey) != nil
    }

    // Coalesced notify (avoid main-thread spam)
    private var notifyScheduled = false

    // Data storage
    public private(set) var events: [AdEvent] = []
    public private(set) var revenues: [RevenueEvent] = []
    // Store ad states by ad ID name (string) for Codable compatibility
    private var adStates: [String: AdStateInfo] = [:]
    private var _debugLines: [String] = []

    // UserDefaults
    private let udKey = "telemetry.ads.settings"

    // Formatters
    // Timestamp formatter (used only on the source queue)
    private lazy var timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.ssss"
        return f
    }()

    // MARK: - Initialization

    /// Initialize AdTelemetry (triggers singleton initialization and auto-starts debug services if enabled)
    /// Call this early in app lifecycle (e.g., in AppDelegate.didFinishLaunchingWithOptions)
    public static func initialize(_ config: AdTelemetryConfiguration) {
        _ = shared
        shared.configure(config)
        shared.startDebugServicesIfNeeded()
    }

    /// Configure AdTelemetry with app-specific ad ID provider
    /// Must be called before using AdTelemetry
    private func configure(_ config: AdTelemetryConfiguration) {
        configuration = config
    }

    // MARK: - Settings Management

    public var settings: Settings {
        get {
            if let d = UserDefaults.standard.data(forKey: udKey),
               let s = try? JSONDecoder().decode(Settings.self, from: d) {
                return s
            }
            // Migration: Check old UserDefaults key for backward compatibility
            let oldDebugEnabled = UserDefaults.standard.bool(forKey: "telemetry.ads.debugEnabled")
            if oldDebugEnabled {
                var newSettings = Settings()
                newSettings.debugEnabled = oldDebugEnabled
                UserDefaults.standard.removeObject(forKey: "telemetry.ads.debugEnabled")
                if let d = try? JSONEncoder().encode(newSettings) {
                    UserDefaults.standard.set(d, forKey: udKey)
                }
                return newSettings
            }
            return Settings()
        }
        set {
            if let d = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(d, forKey: udKey)
            }
            notify()
        }
    }

    public static func isDebugEnabled() -> Bool {
        return shared.settings.debugEnabled
    }

    public static func setDebugEnabled(_ enabled: Bool) {
        var s = shared.settings
        s.debugEnabled = enabled
        shared.settings = s

        if enabled {
            ExternalLogTap.shared.start()
            MotionShakeDetector.shared.start {
                AdsDebugWindowManager.shared.toggle()
            }
        } else {
            ExternalLogTap.shared.stop()
            MotionShakeDetector.shared.stop()
        }
    }

    /// Start debug services if debug is enabled (called on app launch)
    private func startDebugServicesIfNeeded() {
        guard AdTelemetry.isDebugEnabled() else { return }
        ExternalLogTap.shared.start()
        MotionShakeDetector.shared.start {
            AdsDebugWindowManager.shared.toggle()
        }
    }

    // MARK: - Public API: Event Logging

    public func log(_ e: AdEvent) {
        guard AdTelemetry.isDebugEnabled() else { return }

        q.async {
            self.events.insert(e, at: 0)
            self.trim()
            self.updateAdState(for: e)
            self.notifyOnQueue()

            if self.settings.showToasts {
                let message = "\(e.unit.raw) • \(e.action.rawValue)\(e.eCPM != nil ? String(format: " $%.4f", e.eCPM!) : "")"
                DispatchQueue.main.async {
                    AdToast.show(message)
                }
            }
        }
    }

    // MARK: - Public API: Revenue

    public func logRevenue(_ r: RevenueEvent) {
        guard AdTelemetry.isDebugEnabled() else { return }

        q.async {
            self.revenues.insert(r, at: 0)
            self.trim()
            self.notifyOnQueue()

            if self.settings.showToasts {
                let message = "Revenue \(r.unit.raw) +\(String(format: "$%.4f", r.valueUSD))"
                DispatchQueue.main.async {
                    AdToast.show(message)
                }
            }
        }

        addRevenue(for: r.adIdName, adId: r.adId, valueUSD: r.valueUSD)
    }

    public func totalRevenueUSD() -> Double {
        q.sync {
            revenues.reduce(0) { $0 + $1.valueUSD }
        }
    }

    public func revenueByNetwork() -> [(String, Double)] {
        q.sync {
            let dict = revenues.reduce(into: [String: Double]()) { acc, r in
                acc[r.network ?? "unknown", default: 0] += r.valueUSD
            }
            return dict.sorted { $0.value > $1.value }
        }
    }

    // MARK: - Public API: Ad States

    public func getAdStates() -> [AdStateInfo] {
        guard let config = configuration else { return [] }

        return q.sync {
            let allAdIds = config.getAllAdIDs()
            for adId in allAdIds {
                let adIdName = adId.name
                if adStates[adIdName] == nil {
                    adStates[adIdName] = AdStateInfo(
                        adIdName: adIdName,
                        adId: adId.id,
                        loadState: .notLoad,
                        showState: .no,
                        revenueUSD: 0,
                        successCount: 0,
                        failedCount: 0,
                        showedCount: 0
                    )
                }
            }
            return allAdIds.compactMap { adStates[$0.name] }
        }
    }

    // MARK: - Public API: Debug Logs

    public func logDebugLine(_ s: String) {
        logDebugLines([s])
    }

    /// ✅ Batch insert + single notify (huge lag saver)
    public func logDebugLines(_ lines: [String]) {
        guard !lines.isEmpty else { return }
        guard AdTelemetry.isDebugEnabled() else { return }

        q.async {
            let ts = self.timeFormatter.string(from: Date())

            for s in lines {
                let line = "[\(ts)] \(s)"
                self._debugLines.insert(line, at: 0)
            }

            let k = self.settings.keepEvents
            if self._debugLines.count > k {
                self._debugLines.removeLast(self._debugLines.count - k)
            }

            self.notifyOnQueue()
        }
    }

    public var debugLines: [String] {
        return q.sync { _debugLines }
    }

    // MARK: - Private Helpers

    private func trim() {
        let k = settings.keepEvents
        if events.count > k { events.removeLast(events.count - k) }
        if revenues.count > k { revenues.removeLast(revenues.count - k) }
    }

    /// Thread-safe notify entrypoint (can be called from any thread)
    private func notify() {
        if isOnQueue {
            notifyOnQueue()
        } else {
            q.async { self.notifyOnQueue() }
        }
    }

    /// ✅ Coalesce notifications to avoid main-thread spam
    /// Must be called on `q`
    private func notifyOnQueue() {
        if notifyScheduled { return }
        notifyScheduled = true

        DispatchQueue.main.async { [weak self] in
            NotificationCenter.default.post(name: .adTelemetryUpdated, object: nil)
            self?.q.async {
                self?.notifyScheduled = false
            }
        }
    }

    private func updateAdState(for event: AdEvent) {
        guard let adIdName = event.adIdName, let adId = event.adId, configuration != nil else { return }

        if adStates[adIdName] == nil {
            adStates[adIdName] = AdStateInfo(
                adIdName: adIdName,
                adId: adId,
                loadState: .notLoad,
                showState: .no,
                revenueUSD: 0,
                successCount: 0,
                failedCount: 0,
                showedCount: 0
            )
        }

        guard var currentState = adStates[adIdName] else { return }

        switch event.action {
        case .loadStart:
            if currentState.loadState == .notLoad || currentState.loadState == .failed {
                currentState = AdStateInfo(
                    adIdName: adIdName,
                    adId: adId,
                    loadState: .loading,
                    showState: currentState.showState,
                    revenueUSD: currentState.revenueUSD,
                    successCount: currentState.successCount,
                    failedCount: currentState.failedCount,
                    showedCount: currentState.showedCount
                )
            }
        case .loadSuccess:
            currentState = AdStateInfo(
                adIdName: adIdName,
                adId: adId,
                loadState: .success,
                showState: currentState.showState,
                revenueUSD: currentState.revenueUSD,
                successCount: currentState.successCount + 1,
                failedCount: currentState.failedCount,
                showedCount: currentState.showedCount
            )
        case .loadFail:
            currentState = AdStateInfo(
                adIdName: adIdName,
                adId: adId,
                loadState: .failed,
                showState: currentState.showState,
                revenueUSD: currentState.revenueUSD,
                successCount: currentState.successCount,
                failedCount: currentState.failedCount + 1,
                showedCount: currentState.showedCount
            )
        case .showStart:
            currentState = AdStateInfo(
                adIdName: adIdName,
                adId: adId,
                loadState: currentState.loadState,
                showState: .showed,
                revenueUSD: currentState.revenueUSD,
                successCount: currentState.successCount,
                failedCount: currentState.failedCount,
                showedCount: currentState.showedCount
            )
        case .showSuccess, .impression:
            currentState = AdStateInfo(
                adIdName: adIdName,
                adId: adId,
                loadState: currentState.loadState,
                showState: .showed,
                revenueUSD: currentState.revenueUSD,
                successCount: currentState.successCount,
                failedCount: currentState.failedCount,
                showedCount: currentState.showedCount + 1
            )
        default:
            break
        }

        adStates[adIdName] = currentState
    }

    private func addRevenue(for adIdName: String?, adId: String?, valueUSD: Double) {
        guard let adIdName, let adId else { return }

        q.async {
            if self.adStates[adIdName] == nil {
                self.adStates[adIdName] = AdStateInfo(
                    adIdName: adIdName,
                    adId: adId,
                    loadState: .notLoad,
                    showState: .no,
                    revenueUSD: 0,
                    successCount: 0,
                    failedCount: 0,
                    showedCount: 0
                )
            }

            guard var currentState = self.adStates[adIdName] else { return }
            currentState = AdStateInfo(
                adIdName: adIdName,
                adId: adId,
                loadState: currentState.loadState,
                showState: currentState.showState,
                revenueUSD: currentState.revenueUSD + valueUSD,
                successCount: currentState.successCount,
                failedCount: currentState.failedCount,
                showedCount: currentState.showedCount
            )
            self.adStates[adIdName] = currentState
            self.notifyOnQueue()
        }
    }
}

extension Notification.Name {
    public static let adTelemetryUpdated = Notification.Name("adTelemetryUpdated")
}

// MARK: - Toast (stacked)

public final class AdToast {
    public static func show(_ text: String) {
        AdToastCenter.shared.showText(text)
    }
}

final class AdToastCenter {
    static let shared = AdToastCenter()

    // Configuration
    var maxVisible: Int = 4
    var spacing: CGFloat = 8
    var bottomInset: CGFloat = 24
    var sideInset: CGFloat = 16
    var displayDuration: TimeInterval = 1.3
    var fadeIn: TimeInterval = 0.2
    var fadeOut: TimeInterval = 0.25

    private weak var stack: UIStackView?
    private let queue = DispatchQueue(label: "toast.queue", qos: .userInitiated)

    // Public API
    func showText(_ text: String) {
        guard let window = keyWindow() else { return }
        let toastView = makeToastView(text)
        let stack = ensureStack(in: window)

        trimIfNeeded(stack)

        toastView.alpha = 0
        toastView.transform = CGAffineTransform(translationX: 0, y: 10)
        stack.addArrangedSubview(toastView)
        UIView.animate(withDuration: fadeIn) {
            toastView.alpha = 1
            toastView.transform = .identity
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) { [weak self, weak toastView] in
            guard let view = toastView else { return }
            self?.hideToast(view)
        }
    }

    private func trimIfNeeded(_ stack: UIStackView) {
        while stack.arrangedSubviews.count >= maxVisible {
            guard let first = stack.arrangedSubviews.first else { break }
            stack.removeArrangedSubview(first)
            first.removeFromSuperview()
        }
    }

    private func ensureStack(in window: UIWindow) -> UIStackView {
        if let s = stack, s.superview != nil { return s }
        if let oldStack = stack { oldStack.removeFromSuperview() }

        let s = UIStackView()
        s.axis = .vertical
        s.alignment = .center
        s.distribution = .fill
        s.spacing = spacing
        s.translatesAutoresizingMaskIntoConstraints = false

        window.addSubview(s)
        NSLayoutConstraint.activate([
            s.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            s.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -bottomInset),
            s.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: sideInset),
            s.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -sideInset)
        ])

        self.stack = s
        return s
    }

    private func makeToastView(_ text: String) -> UIView {
        let label = PaddingLabel()
        label.text = "  " + text + "  "
        label.numberOfLines = 3
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .semibold)

        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.25
        label.layer.shadowRadius = 8
        label.layer.shadowOffset = CGSize(width: 0, height: 2)

        return label
    }

    private func hideToast(_ view: UIView) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.hideToast(view) }
            return
        }

        UIView.animate(withDuration: fadeOut, animations: {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 20)
        }, completion: { [weak self] _ in
            guard let self = self, let stack = self.stack else { return }
            DispatchQueue.main.async {
                stack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        })
    }

    private func keyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

// MARK: - PaddingLabel

final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right,
                      height: s.height + insets.top + insets.bottom)
    }
}
