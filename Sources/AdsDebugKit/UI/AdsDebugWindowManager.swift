//
//  AdsDebugWindowManager.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

/// Top-level window to present Ads Debug UI as a full-height sheet
public final class AdsDebugWindowManager: NSObject {
    public static let shared = AdsDebugWindowManager()

    private var debugWindow: UIWindow?
    private weak var hostVC: UIViewController?

    private override init() {}

    /// Show full-height sheet
    public func show() {
        guard debugWindow == nil else { return }

        // Pick the current foreground scene (for multi-window safety)
        let win = UIWindow(frame: UIScreen.main.bounds)
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            win.windowScene = scene
        }

        win.windowLevel = .alert + 2
        win.backgroundColor = .clear

        // Host VC used only to present the sheet
        let host = UIViewController()
        host.view.backgroundColor = .clear
        win.rootViewController = host
        win.makeKeyAndVisible()

        self.debugWindow = win
        self.hostVC = host

        // Present on next runloop turn to ensure animation
        DispatchQueue.main.async {
            let debugVC = AdsDebugVC()
            let nav = UINavigationController(rootViewController: debugVC)

            // Sheet style with full-height detent
            nav.modalPresentationStyle = .formSheet
            if #available(iOS 15.0, *), let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]                 // Full-height sheet
                sheet.prefersGrabberVisible = true          // Optional grabber
                sheet.preferredCornerRadius = 16            // Optional corner radius
                sheet.prefersEdgeAttachedInCompactHeight = false
                sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = false
            }
            nav.presentationController?.delegate = self

            host.present(nav, animated: true, completion: nil)
        }
    }

    /// Hide (dismiss presented sheet first if needed)
    public func hide() {
        if let presented = hostVC?.presentedViewController {
            presented.dismiss(animated: true) { [weak self] in
                self?.tearDownWindow()
            }
        } else {
            tearDownWindow()
        }
    }
    
    /// Toggle debug window (show if hidden, hide if visible)
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    private func tearDownWindow() {
        debugWindow?.isHidden = true
        debugWindow = nil
        hostVC = nil
    }

    public var isVisible: Bool {
        return debugWindow != nil && debugWindow?.isHidden == false
    }
}

extension AdsDebugWindowManager: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // User swiped down / interactive dismiss → cleanup window
        tearDownWindow()
    }
}
