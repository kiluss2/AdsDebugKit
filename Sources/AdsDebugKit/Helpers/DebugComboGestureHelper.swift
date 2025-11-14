//
//  DebugComboGestureHelper.swift
//  AdsDebugKit
//
//  Created on 2025.
//

import UIKit
import ObjectiveC

/// Helper class to handle debug combo gesture: swipe down → double tap → swipe up
public final class DebugComboGestureHelper: NSObject {
    
    // MARK: - State Machine
    
    private enum ComboState {
        case idle
        case swipeDown
        case doubleTap
    }
    
    // MARK: - Properties
    
    private weak var targetView: UIImageView?
    private var comboState: ComboState = .idle
    private var comboStartTime: Date?
    private var comboTimer: Timer?
    private let comboTimeout: TimeInterval = 3.0 // Must complete combo within 3 seconds
    
    // Gesture recognizers
    private var panGesture: UIPanGestureRecognizer?
    private var doubleTapGesture: UITapGestureRecognizer?
    
    // Thresholds for swipe detection
    private let velocityThreshold: CGFloat = 500
    private let translationThreshold: CGFloat = 50
    
    // Completion callback
    private var onComboCompleted: (() -> Void)?
    
    // Associated object key for storing helper in imageView
    private static var helperKey: UInt8 = 0
    
    // MARK: - Public Methods
    
    /// Setup debug combo gesture on the given image view
    /// Helper is automatically stored in imageView's associated object
    /// - Parameters:
    ///   - imageView: The image view to attach gestures to
    ///   - completion: Callback when combo is completed successfully
    public func setup(on imageView: UIImageView, completion: @escaping () -> Void) {
        // Cleanup previous setup if any
        if let existing = objc_getAssociatedObject(imageView, &Self.helperKey) as? DebugComboGestureHelper {
            existing.cleanup()
        }
        
        // Store self in imageView's associated object to prevent deallocation
        objc_setAssociatedObject(imageView, &Self.helperKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        targetView = imageView
        onComboCompleted = completion
        
        // Enable user interaction
        imageView.isUserInteractionEnabled = true
        
        // Pan gesture for swipe down/up
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        imageView.addGestureRecognizer(pan)
        panGesture = pan
        
        // Double tap gesture
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        imageView.addGestureRecognizer(doubleTap)
        doubleTapGesture = doubleTap
    }
    
    /// Cleanup and remove all gestures
    public func cleanup() {
        comboTimer?.invalidate()
        comboTimer = nil
        
        if let pan = panGesture {
            targetView?.removeGestureRecognizer(pan)
        }
        if let doubleTap = doubleTapGesture {
            targetView?.removeGestureRecognizer(doubleTap)
        }
        
        // Remove from associated object
        if let imageView = targetView {
            objc_setAssociatedObject(imageView, &Self.helperKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        panGesture = nil
        doubleTapGesture = nil
        targetView = nil
        onComboCompleted = nil
        resetCombo()
    }
    
    // MARK: - Private Methods
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let targetView = targetView else { return }
        
        let translation = gesture.translation(in: targetView)
        let velocity = gesture.velocity(in: targetView)
        
        switch gesture.state {
        case .ended:
            // Check if it's a swipe (velocity > threshold)
            if abs(velocity.y) > velocityThreshold && abs(translation.y) > translationThreshold {
                if velocity.y > 0 && translation.y > 0 {
                    // Swipe down
                    handleSwipeDown()
                } else if velocity.y < 0 && translation.y < 0 {
                    // Swipe up
                    handleSwipeUp()
                }
            }
        default:
            break
        }
    }
    
    @objc private func handleDoubleTap() {
        handleDoubleTapAction()
    }
    
    private func handleSwipeDown() {
        if comboState == .idle {
            comboState = .swipeDown
            comboStartTime = Date()
            startComboTimer()
        } else {
            resetCombo()
        }
    }
    
    private func handleDoubleTapAction() {
        if comboState == .swipeDown {
            comboState = .doubleTap
            // Timer continues, waiting for swipe up
        } else {
            resetCombo()
        }
    }
    
    private func handleSwipeUp() {
        if comboState == .doubleTap {
            // Combo completed!
            completeCombo()
        } else {
            resetCombo()
        }
    }
    
    private func startComboTimer() {
        comboTimer?.invalidate()
        comboTimer = Timer.scheduledTimer(withTimeInterval: comboTimeout, repeats: false) { [weak self] _ in
            self?.resetCombo()
        }
    }
    
    private func resetCombo() {
        comboState = .idle
        comboStartTime = nil
        comboTimer?.invalidate()
        comboTimer = nil
    }
    
    private func completeCombo() {
        resetCombo()
        AdTelemetry.setDebugEnabled(true)
        AdToast.show("Debug mode enabled")
        onComboCompleted?()
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - UIGestureRecognizerDelegate

extension DebugComboGestureHelper: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}


