//
//  DebugEvent.swift
//  AdsDebugKit
//
//  Created by Sơn Lê on 13/11/25.
//

import Foundation

public enum AdUnitKind: Codable, Equatable {
    case interstitial
    case rewarded
    case appOpen
    case banner
    case native
    case custom(String)

    public var raw: String {
        switch self {
        case .interstitial: return "interstitial"
        case .rewarded:     return "rewarded"
        case .appOpen:      return "appOpen"
        case .banner:       return "banner"
        case .native:       return "native"
        case .custom(let s):return s
        }
    }

    public init(raw: String) {
        switch raw {
        case "interstitial": self = .interstitial
        case "rewarded":     self = .rewarded
        case "appOpen":      self = .appOpen
        case "banner":       self = .banner
        case "native":       self = .native
        default:             self = .custom(raw)
        }
    }

    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        self = .init(raw: s)
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }

    public static let allBuiltins: [AdUnitKind] = [.interstitial, .rewarded, .appOpen, .banner, .native]
}

public enum AdAction: Codable, Equatable, RawRepresentable {
    public typealias RawValue = String

    case loadStart, loadSuccess, loadFail
    case showStart, showSuccess, showFail, dismiss, click
    case impression
    case custom(String)

    // MARK: RawRepresentable (string bridge)
    public init?(rawValue: String) { self = AdAction(raw: rawValue) }
    public var rawValue: String { raw }

    // MARK: String mapping
    public var raw: String {
        switch self {
        case .loadStart:   return "loadStart"
        case .loadSuccess: return "loadSuccess"
        case .loadFail:    return "loadFail"
        case .showStart:   return "showStart"
        case .showSuccess: return "showSuccess"
        case .showFail:    return "showFail"
        case .dismiss:     return "dismiss"
        case .click:       return "click"
        case .impression:  return "impression"
        case .custom(let s): return s
        }
    }

    public init(raw: String) {
        switch raw {
        case "loadStart":   self = .loadStart
        case "loadSuccess": self = .loadSuccess
        case "loadFail":    self = .loadFail
        case "showStart":   self = .showStart
        case "showSuccess": self = .showSuccess
        case "showFail":    self = .showFail
        case "dismiss":     self = .dismiss
        case "click":       self = .click
        case "impression":  self = .impression
        default:            self = .custom(raw) // unknowns become custom
        }
    }

    // MARK: Codable (single string)
    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        self = .init(raw: s)
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }

    // Optional: list of built-in (non-custom) actions
    public static let builtins: [AdAction] = [
        .loadStart, .loadSuccess, .loadFail,
        .showStart, .showSuccess, .showFail, .dismiss, .click,
        .impression
    ]
}

public enum AdLoadState: String, Codable {
    case notLoad = "No"
    case loading = "Loading"
    case success = "Success"
    case failed = "Failed"
}

public enum AdShowState: String, Codable {
    case no = "No"
    case showed = "Showed"
}

/// Ad state information for a specific ad ID
/// Stores ad ID as string for Codable compatibility
public struct AdStateInfo: Codable {
    /// Ad ID name (rawValue from AdIDProvider)
    public let adIdName: String
    public let loadState: AdLoadState
    public let showState: AdShowState
    public var revenueUSD: Double
    
    // Counters for tracking
    public var successCount: Int
    public var failedCount: Int
    public var showedCount: Int
    
    /// Create directly from adIdName (internal use)
    internal init(
        adIdName: String,
        loadState: AdLoadState,
        showState: AdShowState,
        revenueUSD: Double,
        successCount: Int = 0,
        failedCount: Int = 0,
        showedCount: Int = 0
    ) {
        self.adIdName = adIdName
        self.loadState = loadState
        self.showState = showState
        self.revenueUSD = revenueUSD
        self.successCount = successCount
        self.failedCount = failedCount
        self.showedCount = showedCount
    }
}

/// Ad event with optional ad ID stored as string
public struct AdEvent: Codable {
    public let time: Date
    public let unit: AdUnitKind
    public let action: AdAction
    /// Ad ID name (rawValue from AdIDProvider), nil if not available
    public let adIdName: String?
    public let network: String?
    public let lineItem: String?
    public let eCPM: Double?
    public let precision: String?
    public let error: String?
    
    /// Create from AdIDProvider
    public init(
        time: Date = Date(),
        unit: AdUnitKind,
        action: AdAction,
        adId: (any AdIDProvider)? = nil,
        network: String? = nil,
        lineItem: String? = nil,
        eCPM: Double? = nil,
        precision: String? = nil,
        error: String? = nil
    ) {
        self.time = time
        self.unit = unit
        self.action = action
        self.adIdName = adId?.name
        self.network = network
        self.lineItem = lineItem
        self.eCPM = eCPM
        self.precision = precision
        self.error = error
    }
}

/// Revenue event with optional ad ID stored as string
public struct RevenueEvent: Codable {
    public let time: Date
    public let unit: AdUnitKind
    /// Ad ID name (rawValue from AdIDProvider), nil if not available
    public let adIdName: String?
    public let network: String?
    public let lineItem: String?
    public let valueUSD: Double
    public let precision: String?
    
    /// Create from AdIDProvider
    public init(
        time: Date = Date(),
        unit: AdUnitKind,
        adId: (any AdIDProvider)? = nil,
        network: String? = nil,
        lineItem: String? = nil,
        valueUSD: Double,
        precision: String? = nil
    ) {
        self.time = time
        self.unit = unit
        self.adIdName = adId?.name
        self.network = network
        self.lineItem = lineItem
        self.valueUSD = valueUSD
        self.precision = precision
    }
}
