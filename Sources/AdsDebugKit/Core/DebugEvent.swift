//
//  DebugEvent.swift
//  AdsDebugKit
//
//  Created by Sơn Lê on 13/11/25.
//

import Foundation

public enum AdDebugUnit: String, Codable, CaseIterable, Equatable {
    case appId
    case native
    case interstitial
    case rewarded
    case rewardedInterstitial
    case appOpen
    case banner
    case other

    public var displayName: String {
        switch self {
        case .appId: return "App ID"
        case .native: return "Native"
        case .interstitial: return "Interstitial"
        case .rewarded: return "Rewarded"
        case .rewardedInterstitial: return "Rewarded Interstitial"
        case .appOpen: return "App Open"
        case .banner: return "Banner"
        case .other: return "Other"
        }
    }

    public init(adUnitName: String, adUnitId: String) {
        let name = adUnitName.lowercased()
        let id = adUnitId.lowercased()
        if adUnitId.contains("~"), !adUnitId.contains("/") {
            self = .appId
        } else if name.contains("rewardedinterstitial") || name.contains("rewarded_interstitial") {
            self = .rewardedInterstitial
        } else if name.contains("reward") {
            self = .rewarded
        } else if name.contains("appopen") || name.contains("app_open") || name.contains("openapp") {
            self = .appOpen
        } else if name.contains("interstitial") || name.contains("inter") {
            self = .interstitial
        } else if name.contains("banner") {
            self = .banner
        } else if name.contains("native") {
            self = .native
        } else if id.contains("~"), !id.contains("/") {
            self = .appId
        } else {
            self = .other
        }
    }
}

public enum AdDebugAction: String, Codable, CaseIterable, Equatable {
    case loadStart
    case loadSuccess
    case loadFail
    case showStart
    case showSuccess
    case showFail
    case showDismissed
    case click
    case impression
    case populate
    case fallback
    case debug
    case custom
}

public enum AdIdOverrideMode: String, Codable, CaseIterable, Equatable {
    case normal
    case failPrimary
    case failAll
    case forceAdMobOnly
    case custom

    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .failPrimary: return "Fail Primary"
        case .failAll: return "Fail All"
        case .forceAdMobOnly: return "Force AdMob Only"
        case .custom: return "Custom"
        }
    }
}

public enum AdUnitCustomMode: String, Codable, CaseIterable, Equatable {
    case release
    case debug
    case falseAd
    case admobOnly

    public var displayName: String {
        switch self {
        case .release: return "Release"
        case .debug: return "Debug"
        case .falseAd: return "False"
        case .admobOnly: return "AdMob"
        }
    }
}

public enum AdIdRequestRole: String, Codable, CaseIterable, Equatable {
    case primary
    case admobOnly
}

public enum AdRawLogTapPolicy: String, Codable, Equatable {
    case disabled
    case legacyFiltered
    case legacyFilteredWithOSLog
}

public enum AdDebugExternalStatus: String, Codable, CaseIterable, Equatable {
    case submitted
    case success
    case failed
    case raw
    case debug

    public init(rawStatus: String?) {
        switch rawStatus?.lowercased() {
        case "submitted", "submit", "sent": self = .submitted
        case "success", "succeeded", "ok": self = .success
        case "failed", "fail", "error": self = .failed
        case "raw": self = .raw
        default: self = .debug
        }
    }
}

public struct AdDebugAdUnit: Codable, Equatable {
    public let name: String
    public let adUnitId: String
    public let unit: AdDebugUnit
    public let isReadOnly: Bool
    public let admobOnlyAdUnitId: String?

    public init(
        name: String,
        adUnitId: String,
        unit: AdDebugUnit,
        isReadOnly: Bool = false,
        admobOnlyAdUnitId: String? = nil
    ) {
        self.name = name
        self.adUnitId = adUnitId
        self.unit = unit
        self.isReadOnly = isReadOnly
        self.admobOnlyAdUnitId = admobOnlyAdUnitId
    }
}

public struct AdDebugExternalEvent: Codable, Equatable {
    public let time: Date
    public let provider: String
    public let event: String
    public let status: AdDebugExternalStatus
    public let message: String?
    public let values: [String: String]

    public init(
        time: Date = Date(),
        provider: String,
        event: String,
        status: AdDebugExternalStatus,
        message: String? = nil,
        values: [String: String] = [:]
    ) {
        self.time = time
        self.provider = provider
        self.event = event
        self.status = status
        self.message = message
        self.values = values
    }
}

public struct AdDebugCustomEvent: Codable, Equatable {
    public let time: Date
    public let event: String
    public let status: AdDebugExternalStatus
    public let message: String?
    public let values: [String: String]

    public init(
        time: Date = Date(),
        event: String,
        status: AdDebugExternalStatus,
        message: String? = nil,
        values: [String: String] = [:]
    ) {
        self.time = time
        self.event = event
        self.status = status
        self.message = message
        self.values = values
    }
}

public struct AdDebugSettings: Codable, Equatable {
    public var debugEnabled: Bool
    public var showToasts: Bool
    public var keepEvents: Int
    public var adIdOverrideMode: AdIdOverrideMode
    public var customAdUnitModes: [String: AdUnitCustomMode]
    public var rawLogTapEnabled: Bool

    public init(
        debugEnabled: Bool = false,
        showToasts: Bool = false,
        keepEvents: Int = 100,
        adIdOverrideMode: AdIdOverrideMode = .normal,
        customAdUnitModes: [String: AdUnitCustomMode] = [:],
        rawLogTapEnabled: Bool = false
    ) {
        self.debugEnabled = debugEnabled
        self.showToasts = showToasts
        self.keepEvents = keepEvents
        self.adIdOverrideMode = adIdOverrideMode
        self.customAdUnitModes = customAdUnitModes
        self.rawLogTapEnabled = rawLogTapEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case debugEnabled
        case showToasts
        case keepEvents
        case adIdOverrideMode
        case customAdUnitModes
        case rawLogTapEnabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        debugEnabled = try c.decodeIfPresent(Bool.self, forKey: .debugEnabled) ?? false
        showToasts = try c.decodeIfPresent(Bool.self, forKey: .showToasts) ?? false
        keepEvents = try c.decodeIfPresent(Int.self, forKey: .keepEvents) ?? 100
        adIdOverrideMode = try c.decodeIfPresent(AdIdOverrideMode.self, forKey: .adIdOverrideMode) ?? .normal
        customAdUnitModes = try c.decodeIfPresent([String: AdUnitCustomMode].self, forKey: .customAdUnitModes) ?? [:]
        rawLogTapEnabled = try c.decodeIfPresent(Bool.self, forKey: .rawLogTapEnabled) ?? false
    }
}

public enum GoogleMobileAdsTestUnitIds {
    public static let appOpen = "ca-app-pub-3940256099942544/5575463023"
    public static let adaptiveBanner = "ca-app-pub-3940256099942544/2435281174"
    public static let fixedBanner = "ca-app-pub-3940256099942544/2934735716"
    public static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    public static let rewarded = "ca-app-pub-3940256099942544/1712485313"
    public static let rewardedInterstitial = "ca-app-pub-3940256099942544/6978759866"
    public static let native = "ca-app-pub-3940256099942544/3986624511"
    public static let invalid = "ca-app-pub-3940256099942544/0000000000"

    public static func id(for unit: AdDebugUnit) -> String {
        switch unit {
        case .appOpen: return appOpen
        case .banner: return fixedBanner
        case .interstitial: return interstitial
        case .rewarded: return rewarded
        case .rewardedInterstitial: return rewardedInterstitial
        case .native: return native
        case .appId, .other: return invalid
        }
    }
}

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

    public init(debugUnit: AdDebugUnit) {
        switch debugUnit {
        case .interstitial: self = .interstitial
        case .rewarded, .rewardedInterstitial: self = .rewarded
        case .appOpen: self = .appOpen
        case .banner: self = .banner
        case .native: self = .native
        case .appId, .other: self = .custom(debugUnit.rawValue)
        }
    }

    public var debugUnit: AdDebugUnit {
        switch self {
        case .interstitial: return .interstitial
        case .rewarded: return .rewarded
        case .appOpen: return .appOpen
        case .banner: return .banner
        case .native: return .native
        case .custom(let value): return AdDebugUnit(adUnitName: value, adUnitId: "")
        }
    }
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
    case showing = "Showing"
    case showed = "Showed"
    case failed = "Failed"
}

/// Ad state information for a specific ad ID
/// Stores ad ID as string for Codable compatibility
public struct AdStateInfo: Codable {
    /// Ad ID name (rawValue from AdIDProvider)
    public let adIdName: String
    public let adId: String
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
        adId: String,
        loadState: AdLoadState,
        showState: AdShowState,
        revenueUSD: Double,
        successCount: Int = 0,
        failedCount: Int = 0,
        showedCount: Int = 0
    ) {
        self.adIdName = adIdName
        self.adId = adId
        self.loadState = loadState
        self.showState = showState
        self.revenueUSD = revenueUSD
        self.successCount = successCount
        self.failedCount = failedCount
        self.showedCount = showedCount
    }

    internal func withAdId(_ adId: String) -> AdStateInfo {
        AdStateInfo(
            adIdName: adIdName,
            adId: adId,
            loadState: loadState,
            showState: showState,
            revenueUSD: revenueUSD,
            successCount: successCount,
            failedCount: failedCount,
            showedCount: showedCount
        )
    }
}

/// Ad event with optional ad ID stored as string
public struct AdEvent: Codable {
    public let time: Date
    public let unit: AdUnitKind
    public let action: AdAction
    /// Ad ID name (rawValue from AdIDProvider), nil if not available
    public let adIdName: String?
    public let adId: String?
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
        self.adId = adId?.id
        self.network = network
        self.lineItem = lineItem
        self.eCPM = eCPM
        self.precision = precision
        self.error = error
    }

    public init(
        time: Date = Date(),
        unit: AdUnitKind,
        action: AdAction,
        adIdName: String?,
        adId: String?,
        network: String? = nil,
        lineItem: String? = nil,
        eCPM: Double? = nil,
        precision: String? = nil,
        error: String? = nil
    ) {
        self.time = time
        self.unit = unit
        self.action = action
        self.adIdName = adIdName
        self.adId = adId
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
    public let adId: String?
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
        self.adId = adId?.id
        self.network = network
        self.lineItem = lineItem
        self.valueUSD = valueUSD
        self.precision = precision
    }

    public init(
        time: Date = Date(),
        unit: AdUnitKind,
        adIdName: String?,
        adId: String?,
        network: String? = nil,
        lineItem: String? = nil,
        valueUSD: Double,
        precision: String? = nil
    ) {
        self.time = time
        self.unit = unit
        self.adIdName = adIdName
        self.adId = adId
        self.network = network
        self.lineItem = lineItem
        self.valueUSD = valueUSD
        self.precision = precision
    }
}

public typealias AdDebugEvent = AdEvent
public typealias AdDebugRevenueEvent = RevenueEvent
