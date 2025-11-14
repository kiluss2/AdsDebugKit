//
//  MotionShakeDetector.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import CoreMotion
import UIKit

public final class ProperShakeDetector {
    public static let shared = ProperShakeDetector()
    private let motion = CMMotionManager()
    private var handler: (() -> Void)?

    // --- Tunables (Adjustable parameters) ---
    
    // Acceleration threshold (g) to count as "one shake".
    // 1.5 - 2.0 is a good value for userAcceleration.
    private let shakeThreshold: Double = 1.8
    
    // Time window (seconds) in which 2 opposite shakes must occur.
    private let directionChangeTimeWindow: TimeInterval = 0.3
    
    // Wait time (seconds) between 2 triggers (debounce).
    private let debounceInterval: TimeInterval = 1.0

    // --- State ---
    private var lastFireTime: TimeInterval = 0
    private var lastDirection: Int = 0 // 0 = None, 1 = Positive, -1 = Negative
    private var lastDirectionChangeTime: TimeInterval = 0
    
    private let updateInterval = 1.0 / 60.0 // 60 Hz

    private init() {}

    public func start(_ onShake: @escaping () -> Void) {
        handler = onShake
        guard motion.isDeviceMotionAvailable else {
            print("ShakeDetector Error: Device Motion is not available.")
            return
        }

        motion.deviceMotionUpdateInterval = updateInterval
        motion.startDeviceMotionUpdates(to: .init()) { [weak self] data, _ in
            guard let self, let accel = data?.userAcceleration else { return }
            
            let now = CFAbsoluteTimeGetCurrent()

            // Find the axis with highest acceleration (focus on X and Y, for horizontal or vertical shake)
            let dominantAccel = (abs(accel.x) > abs(accel.y)) ? accel.x : accel.y

            // 1. Check if acceleration passes the threshold
            if abs(dominantAccel) > self.shakeThreshold {
                
                let currentDirection = (dominantAccel > 0) ? 1 : -1
                
                // 2. Check if this direction is *different* from previous one
                if currentDirection != self.lastDirection {
                    
                    // 3. If a direction was already set and it occurred within the time window
                    if self.lastDirection != 0 && (now - self.lastDirectionChangeTime) < self.directionChangeTimeWindow {
                        
                        // ---- SHAKE BACK AND FORTH DETECTED ----
                        
                        // 4. Check debounce (avoid repeated triggers)
                        if (now - self.lastFireTime) > self.debounceInterval {
                            self.lastFireTime = now
                            DispatchQueue.main.async { self.handler?() }
                        }
                        
                        // Reset state
                        self.lastDirection = 0
                        self.lastDirectionChangeTime = 0
                        
                    } else {
                        // This is the FIRST shake (or too late)
                        self.lastDirection = currentDirection
                        self.lastDirectionChangeTime = now
                    }
                }
            }
        }
    }

    public func stop() {
        motion.stopDeviceMotionUpdates()
        handler = nil
    }
}
