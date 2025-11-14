//
//  AdTelemetryProtocols.swift
//  AdsDebugKit
//
//  Created on 2025.
//

import Foundation

/// Protocol for ad ID types that can be used with AdTelemetry
/// App must implement this protocol for their ad ID enum
public protocol AdIDProvider: Hashable, Codable, CaseIterable {
    /// Raw string value of the ad ID
    var rawValue: String { get }
    
    /// Display name of the ad ID (usually same as rawValue)
    var name: String { get }
    
    /// Actual ad unit ID string to use for ad requests
    var id: String { get }
}

/// Configuration for AdTelemetry to work with app-specific ad IDs
public struct AdTelemetryConfiguration {
    /// Closure to get all available ad IDs
    public let getAllAdIDs: () -> [any AdIDProvider]
    
    /// Closure to extract ad ID from a native ad object
    /// Returns nil if ad ID cannot be extracted
    public let getNativeAdSlotId: (Any) -> (any AdIDProvider)?
    
    /// Default ad ID to use when slot ID cannot be extracted from native ad
    public let defaultNativeAdID: any AdIDProvider
    
    public init(
        getAllAdIDs: @escaping () -> [any AdIDProvider],
        getNativeAdSlotId: @escaping (Any) -> (any AdIDProvider)?,
        defaultNativeAdID: any AdIDProvider
    ) {
        self.getAllAdIDs = getAllAdIDs
        self.getNativeAdSlotId = getNativeAdSlotId
        self.defaultNativeAdID = defaultNativeAdID
    }
}


