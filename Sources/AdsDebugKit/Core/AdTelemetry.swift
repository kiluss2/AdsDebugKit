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
    
    private init() {}
    
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
    
    // Data storage
    public private(set) var events: [AdEvent] = []
    public private(set) var revenues: [RevenueEvent] = []
    // Store ad states by ad ID name (string) for Codable compatibility
    private var adStates: [String: AdStateInfo] = [:]
    private var _debugLines: [String] = []
    
    // UserDefaults
    private let udKey = "telemetry.ads.settings"
    
    // Formatters
    // Timestamp formatter (created once and used on the source queue/main thread only)
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
                // Migrate old value to new settings
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
    /// This ensures services are started even if debug was enabled in a previous session
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
            // Insert at beginning for newest-first order
            self.events.insert(e, at: 0)
            self.trim()
            self.updateAdState(for: e)
            self.notify()
            
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
            // Insert at beginning for newest-first order
            self.revenues.insert(r, at: 0)
            self.trim()
            self.notify()
            
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
    
    /// Get current ad states (thread-safe)
    /// Returns states for all configured ad IDs
    public func getAdStates() -> [AdStateInfo] {
        guard let config = configuration else {
            return []
        }
        
        return q.sync {
            // Initialize states for all ad IDs if not exists
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
        q.async {
            let line = "[\(self.timeFormatter.string(from: Date()))] \(s)"
            // Insert at beginning for newest-first order
            self._debugLines.insert(line, at: 0)
            // Keep only the first keepEvents lines (newest) to save memory
            let k = self.settings.keepEvents
            if self._debugLines.count > k {
                self._debugLines.removeLast(self._debugLines.count - k)
            }
            self.notify()
        }
    }
    
    public var debugLines: [String] {
        return q.sync { _debugLines }
    }
    
    // MARK: - Private Helpers
    
    private func trim() {
        let k = settings.keepEvents
        // Remove oldest items from end (since we insert at beginning)
        if events.count > k {
            events.removeLast(events.count - k)
        }
        if revenues.count > k {
            revenues.removeLast(revenues.count - k)
        }
    }
    
    private func notify() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .adTelemetryUpdated, object: nil)
        }
    }
    
    /// Update ad state when a new event is logged
    private func updateAdState(for event: AdEvent) {
        guard let adIdName = event.adIdName, let adId = event.adId, configuration != nil else { return }
        
        // Initialize if not exists
        if adStates[adIdName] == nil {
            // Try to get the ad ID from configuration
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
        
        // Update load state and counters based on event action
        switch event.action {
        case .loadStart:
            // Only set loading if current state is notLoad or failed
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
                successCount: currentState.successCount + 1,  // Increment success
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
                failedCount: currentState.failedCount + 1,  // Increment failed
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
                showedCount: currentState.showedCount + 1  // Increment showed
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
            self.notify()
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

        // TRIM: bỏ toast cũ ngay lập tức để tránh vòng lặp vô hạn trên main
        trimIfNeeded(stack)

        // Thêm và animate vào
        toastView.alpha = 0
        toastView.transform = CGAffineTransform(translationX: 0, y: 10)
        stack.addArrangedSubview(toastView)
        UIView.animate(withDuration: fadeIn) {
            toastView.alpha = 1
            toastView.transform = .identity
        }

        // Ẩn sau thời gian hiển thị
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) { [weak self, weak toastView] in
            guard let view = toastView else { return }
            self?.hideToast(view)
        }
    }

    // NEW: cắt bớt ngay lập tức (không animate) để count giảm ngay
    private func trimIfNeeded(_ stack: UIStackView) {
        while stack.arrangedSubviews.count >= maxVisible {
            guard let first = stack.arrangedSubviews.first else { break }
            stack.removeArrangedSubview(first)
            first.removeFromSuperview() // no animation → tránh block main
        }
    }
    
    // MARK: internals
    
    private func ensureStack(in window: UIWindow) -> UIStackView {
        // Thread-safe check and create
        if let s = stack, s.superview != nil {
            return s
        }
        
        // Remove old stack if exists but not in window
        if let oldStack = stack {
            oldStack.removeFromSuperview()
        }
        
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
        
        // Light shadow for easier layer distinction
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.25
        label.layer.shadowRadius = 8
        label.layer.shadowOffset = CGSize(width: 0, height: 2)
        
        return label
    }
    
    private func hideToast(_ view: UIView) {
        // Ensure on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.hideToast(view)
            }
            return
        }
        
        UIView.animate(withDuration: fadeOut, animations: {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 20)
        }, completion: { [weak self] _ in
            guard let self = self, let stack = self.stack else { return }
            // Ensure we're still on main thread
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
            .first(where: { $0.isKeyWindow })
    }
}

final class PaddingLabel: UILabel {
    var inset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: inset))
    }
    
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + inset.left + inset.right,
                      height: s.height + inset.top + inset.bottom)
    }
}
