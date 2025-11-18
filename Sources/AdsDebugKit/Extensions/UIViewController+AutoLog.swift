//
//  UIViewController+AutoLog.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit
import ObjectiveC

extension UIViewController {
    private static var hasSwizzled = false
    
    /// Enable automatic viewWillAppear logging for all view controllers
    /// This method uses method swizzling to intercept viewWillAppear calls
    /// and automatically log them to AdTelemetry when debug is enabled
    public static func enableAutoViewAppearLogging() {
        guard !hasSwizzled else { return }
        hasSwizzled = true
        
        let originalSelector = #selector(UIViewController.viewWillAppear(_:))
        let swizzledSelector = #selector(UIViewController.adsDebug_viewWillAppear(_:))
        
        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    @objc private func adsDebug_viewWillAppear(_ animated: Bool) {
        // Call original implementation (after swizzling, this calls the real viewWillAppear)
        adsDebug_viewWillAppear(animated)
        
        // Auto log view appear event for debugging
        guard AdTelemetry.isDebugEnabled() else { return }
        
        let vcName = String(describing: type(of: self))
        
        // Log to Adjust Logs page
        let logMessage = "[ViewAppear] \(vcName) will appear"
        AdTelemetry.shared.logDebugLine(logMessage)
        
        // Log to Events page (as an AdEvent)
        AdTelemetry.shared.log(AdEvent(
            unit: .custom(vcName),
            action: .custom("Will appear"),
            adId: nil,
            network: "Màn hình này chuẩn bị đc show",
            lineItem: nil,
            eCPM: nil,
            precision: nil,
            error: nil
        ))
    }
}

