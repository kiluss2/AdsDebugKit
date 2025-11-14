//
//  ShakeMonitor.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

/// Invisible view to catch shake gestures
final class ShakeCatcherView: UIView {
    override var canBecomeFirstResponder: Bool { true }
    
    private var lastShakeAt: TimeInterval = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
        backgroundColor = .clear
        accessibilityElementsHidden = true
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func activate() {
        // Trở thành first responder khi window đã là key
        guard let win = window else { return }
        if win.isKeyWindow {
            _ = becomeFirstResponder()
            return
        }
        // Retry vài nhịp để chờ window ổn định (sau khi ad dismiss)
        // Tăng lên 8 bước để cover máy chậm hoặc dismiss mất > 1s
        for i in 1...8 { // ~0..640ms
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80 * i)) { [weak self] in
                guard let self = self, let w = self.window, w.isKeyWindow else { return }
                _ = self.becomeFirstResponder()
            }
        }
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        
        // Throttle shake → avoid double-toggle on a single shake
        let now = CACurrentMediaTime()
        guard now - lastShakeAt > 0.3 else { return }  // throttle 300ms
        lastShakeAt = now
        
        // Optional: ignore if already visible (prevent double-toggle)
        if !AdsDebugWindowManager.shared.isVisible {
            AdsDebugWindowManager.shared.toggle()
        }
    }
}

/// Auto-installer for shake detection on key windows
/// Does not require AppDelegate/SceneDelegate modifications
final class ShakeMonitor {
    static let shared = ShakeMonitor()
    
    private var installed = NSHashTable<UIWindow>.weakObjects()
    private var catcher = NSMapTable<UIWindow, ShakeCatcherView>(
        keyOptions: .weakMemory, valueOptions: .weakMemory)
    private var started = false
    private var reassertWorkItem: DispatchWorkItem?
    
    /// Feature flag: set false in production if needed
    var isEnabled = true
    
    private init() {}
    
    /// Call from anywhere (e.g., when enabling debug), NO AppDelegate needed
    func start() {
        // Ensure start() runs on main thread (defensive)
        if !Thread.isMainThread {
            return DispatchQueue.main.async { self.start() }
        }
        
        guard !started else { return }
        started = true
        
        // Cài ngay cho key window hiện tại
        installToKeyWindow()
        
        // Quan sát mọi thay đổi có thể do interstitial gây ra
        NotificationCenter.default.addObserver(self,
            selector: #selector(onKeyWindow(_:)),
            name: UIWindow.didBecomeKeyNotification, object: nil)
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(onResignKey(_:)),
            name: UIWindow.didResignKeyNotification, object: nil)
        
        // Khi một window xuất hiện/ẩn đi (inter thường tạo/ẩn UIWindow riêng)
        NotificationCenter.default.addObserver(self,
            selector: #selector(onWindowVisible(_:)),
            name: UIWindow.didBecomeVisibleNotification, object: nil)
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(onWindowHidden(_:)),
            name: UIWindow.didBecomeHiddenNotification, object: nil)
        
        // App/scene hoạt hóa lại (đôi khi inter/SDK "đánh lừa" state)
        NotificationCenter.default.addObserver(self,
            selector: #selector(onAppActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(self,
                selector: #selector(onSceneActive),
                name: UIScene.didActivateNotification, object: nil)
            NotificationCenter.default.addObserver(self,
                selector: #selector(onSceneWillDeactivate),
                name: UIScene.willDeactivateNotification, object: nil)
        }
    }
    
    func stop() {
        started = false
        reassertWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
        // Not required to remove catchers; leaving them is harmless
    }
    
    /// Public API to re-arm after disruptive UI (e.g., interstitial dismiss)
    /// Note: Usually not needed - ShakeMonitor auto-recovers via notifications
    func rearm() {
        guard started else { return }
        scheduleReassert(long: true)
    }
    
    // MARK: - Observers
    
    @objc private func onKeyWindow(_ note: Notification) {
        guard let win = note.object as? UIWindow else { return }
        installIfNeeded(on: win)
        scheduleReassert()  // gộp nhiều sự kiện, tránh re-activate liên tục
    }
    
    @objc private func onResignKey(_ note: Notification) {
        // Key window sắp đổi – chờ ổn định rồi mới giành first responder
        scheduleReassert(long: true)
    }
    
    @objc private func onWindowVisible(_ note: Notification) {
        scheduleReassert(long: true)
    }
    
    @objc private func onWindowHidden(_ note: Notification) {
        scheduleReassert(long: true)
    }
    
    @objc private func onAppActive() {
        scheduleReassert()
    }
    
    @available(iOS 13.0, *)
    @objc private func onSceneActive() {
        scheduleReassert()
    }
    
    @available(iOS 13.0, *)
    @objc private func onSceneWillDeactivate() {
        scheduleReassert(long: true)
    }
    
    // MARK: - Core
    
    /// Debounced (short/long) reassert
    /// - Parameter long: If true, uses longer backoff (12 hops ≈ 960ms) for disruptive UI changes like interstitial dismiss
    private func scheduleReassert(long: Bool = false) {
        guard isEnabled else { return }
        
        reassertWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.reassert() }
        reassertWorkItem = item
        
        // short: 0..240ms (4 nhịp) – cho sự kiện nhẹ
        // long : 0..960ms (12 nhịp) – dùng khi window churn mạnh (interstitial)
        let hops = long ? 12 : 4
        for i in 0..<hops {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80 * i), execute: item)
        }
    }
    
    private func reassert() {
        guard let key = Self.keyWindow else { return }
        installIfNeeded(on: key)
        catcher.object(forKey: key)?.activate()
    }
    
    private func installToKeyWindow() {
        guard let key = Self.keyWindow else { return }
        installIfNeeded(on: key)
        catcher.object(forKey: key)?.activate()
    }
    
    private func installIfNeeded(on window: UIWindow) {
        if installed.contains(window) { return }
        
        let v = ShakeCatcherView(frame: .zero)
        v.isUserInteractionEnabled = false
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(v)
        
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: 1),
            v.heightAnchor.constraint(equalToConstant: 1),
            v.topAnchor.constraint(equalTo: window.topAnchor),
            v.leadingAnchor.constraint(equalTo: window.leadingAnchor)
        ])
        
        installed.add(window)
        catcher.setObject(v, forKey: window)
    }
    
    // MARK: - Utils
    
    private static var keyWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
}


