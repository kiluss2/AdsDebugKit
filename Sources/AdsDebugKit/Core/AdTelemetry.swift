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

    public typealias Settings = AdDebugSettings

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
    public private(set) var externalEvents: [AdDebugExternalEvent] = []
    public private(set) var customEvents: [AdDebugCustomEvent] = []
    // Store ad states by ad ID name (string) for Codable compatibility
    private var adStates: [String: AdStateInfo] = [:]
    private var _debugLines: [String] = []
    private var recentDebugLineTimestamps: [String: Date] = [:]
    private let recentDebugLineDedupWindow: TimeInterval = 2
    private let recentDebugLineLimit = 200

    // UserDefaults
    private let udKey = "telemetry.ads.settings"
    private let settingsLock = NSLock()
    private var settingsCache: Settings?
    private let adUnitsLock = NSLock()
    private var adUnitsCache: [AdDebugAdUnit]?

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
        invalidateAdUnitsCache()
    }

    // MARK: - Settings Management

    public var settings: Settings {
        get {
            settingsLock.lock()
            defer { settingsLock.unlock() }
            if let settingsCache { return settingsCache }
            let loaded = loadSettingsFromDefaults()
            settingsCache = loaded
            return loaded
        }
        set {
            settingsLock.lock()
            settingsCache = newValue
            if let d = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(d, forKey: udKey)
            }
            settingsLock.unlock()
            notify()
        }
    }

    private func loadSettingsFromDefaults() -> Settings {
        if let d = UserDefaults.standard.data(forKey: udKey),
           let s = try? JSONDecoder().decode(Settings.self, from: d) {
            return s
        }

        // Migration: Check old UserDefaults key for backward compatibility.
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

    private func clearSettingsCache() {
        settingsLock.lock()
        settingsCache = nil
        settingsLock.unlock()
    }

    private func invalidateAdUnitsCache() {
        adUnitsLock.lock()
        adUnitsCache = nil
        adUnitsLock.unlock()
    }

    public static func isDebugEnabled() -> Bool {
        return shared.settings.debugEnabled
    }

    public static func setDebugEnabled(_ enabled: Bool) {
        var s = shared.settings
        s.debugEnabled = enabled
        shared.settings = s

        shared.applyDebugServicesState()
    }

    public static func refreshDebugServices() {
        shared.applyDebugServicesState()
    }

    public func setRawLogTapEnabled(_ enabled: Bool) {
        var s = settings
        s.rawLogTapEnabled = enabled
        settings = s
        applyDebugServicesState()
    }

    public func setAdIdOverrideMode(_ mode: AdIdOverrideMode) {
        var s = settings
        s.adIdOverrideMode = mode
        settings = s
    }

    public func setCustomMode(_ mode: AdUnitCustomMode, forAdUnitName adUnitName: String) {
        guard isOverridablePlacement(adUnitName) else { return }

        let currentSettings = settings
        var currentModes: [String: AdUnitCustomMode]
        if currentSettings.adIdOverrideMode == .custom {
            currentModes = currentSettings.customAdUnitModes.filter { isOverridablePlacement($0.key) }
        } else {
            currentModes = snapshotDisplayModes(for: currentSettings.adIdOverrideMode)
        }

        currentModes[adUnitName] = mode
        let allRelease = currentModes.values.allSatisfy { $0 == .release }

        var s = currentSettings
        s.adIdOverrideMode = allRelease ? .normal : .custom
        s.customAdUnitModes = allRelease ? [:] : currentModes
        settings = s
    }

    public func customMode(forAdUnitName adUnitName: String) -> AdUnitCustomMode {
        return customMode(forAdUnitName: adUnitName, settings: settings)
    }

    public func displayMode(for adUnit: AdDebugAdUnit) -> AdUnitCustomMode {
        let currentSettings = settings
        return displayMode(for: adUnit, settings: currentSettings)
    }

    public func resolvedAdUnitIdForDisplay(_ adUnit: AdDebugAdUnit) -> String {
        let currentSettings = settings
        return resolvedAdUnitIdForDisplay(adUnit, settings: currentSettings)
    }

    private func resolvedAdUnitIdForDisplay(_ adUnit: AdDebugAdUnit, settings currentSettings: Settings) -> String {
        guard isOverridable(adUnit) else { return adUnit.adUnitId }
        switch currentSettings.adIdOverrideMode {
        case .normal:
            return adUnit.adUnitId
        case .failPrimary:
            return isPriorityPlacement(adUnit.name) ? invalidAdUnitId(for: adUnit.adUnitId) : adUnit.adUnitId
        case .failAll:
            return invalidAdUnitId(for: adUnit.adUnitId)
        case .forceAdMobOnly:
            return isAdmobOnlyPlacement(adUnit.name) ? adUnit.adUnitId : invalidAdUnitId(for: adUnit.adUnitId)
        case .custom:
            switch customMode(forAdUnitName: adUnit.name, settings: currentSettings) {
            case .release:
                return adUnit.adUnitId
            case .debug:
                return GoogleMobileAdsTestUnitIds.id(for: adUnit.unit)
            case .falseAd:
                return invalidAdUnitId(for: adUnit.adUnitId)
            case .admobOnly:
                return admobOnlyDisplayId(for: adUnit)
            }
        }
    }

    private func applyDebugServicesState() {
        let enabled = settings.debugEnabled
        if enabled {
            if shouldRunLegacyRawLogTap {
                ExternalLogTap.shared.start()
            } else {
                ExternalLogTap.shared.stop()
            }
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
        applyDebugServicesState()
    }

    private var shouldRunLegacyRawLogTap: Bool {
        return settings.rawLogTapEnabled && configuration?.rawLogTapPolicy == .legacyFiltered
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

    public func logExternal(
        provider: String,
        event: String,
        status: AdDebugExternalStatus,
        message: String? = nil,
        values: [String: String] = [:]
    ) {
        logExternal(AdDebugExternalEvent(
            provider: provider,
            event: event,
            status: status,
            message: message,
            values: values
        ))
    }

    public func logExternal(_ event: AdDebugExternalEvent) {
        guard AdTelemetry.isDebugEnabled() else { return }

        q.async {
            self.externalEvents.insert(event, at: 0)
            self.trim()
            self.notifyOnQueue()
        }
    }

    public func logCustom(
        event: String,
        status: AdDebugExternalStatus = .debug,
        message: String? = nil,
        values: [String: String] = [:]
    ) {
        logCustom(AdDebugCustomEvent(
            event: event,
            status: status,
            message: message,
            values: values
        ))
    }

    public func logCustom(_ event: AdDebugCustomEvent) {
        guard AdTelemetry.isDebugEnabled() else { return }

        q.async {
            self.customEvents.insert(event, at: 0)
            self.trim()
            self.notifyOnQueue()
        }
    }

    public func logStructuredLine(_ line: String) {
        let kv = AdStructuredLogParser.parse(line)
        if kv["ads_debug"] == "1" {
            let unitString = kv["unit"] ?? kv["format"] ?? "other"
            let actionString = kv["event"] ?? kv["action"] ?? kv["status"] ?? "debug"
            let revenue = Double(kv["valueUSD"] ?? kv["revenueUSD"] ?? kv["revenue"] ?? "")
            let adIdName = kv["placement"] ?? kv["name"] ?? kv["adIdName"]
            let adId = kv["adUnit"] ?? kv["adUnitId"] ?? kv["adId"] ?? kv["id"]
            let network = kv["network"] ?? kv["provider"]
            let lineItem = kv["lineItem"]
            let precision = kv["precision"]

            if let revenue {
                logRevenue(RevenueEvent(
                    unit: AdUnitKind(raw: unitString),
                    adIdName: adIdName,
                    adId: adId,
                    network: network,
                    lineItem: lineItem,
                    valueUSD: revenue,
                    precision: precision
                ))
            } else {
                log(AdEvent(
                    unit: AdUnitKind(raw: unitString),
                    action: AdAction(raw: actionString),
                    adIdName: adIdName,
                    adId: adId,
                    network: network,
                    lineItem: lineItem,
                    eCPM: Double(kv["eCPM"] ?? kv["ecpm"] ?? ""),
                    precision: precision,
                    error: kv["error"] ?? kv["message"]
                ))
            }
        } else if kv["external_debug"] == "1" {
            logExternal(
                provider: kv["provider"] ?? "external",
                event: kv["event"] ?? "debug",
                status: AdDebugExternalStatus(rawStatus: kv["status"]),
                message: kv["message"],
                values: kv
            )
        } else if kv["custom_debug"] == "1" {
            logCustom(
                event: kv["event"] ?? "custom",
                status: AdDebugExternalStatus(rawStatus: kv["status"]),
                message: kv["message"],
                values: kv
            )
        } else {
            logDebugLine(line)
        }
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

    public func eventsSnapshot() -> [AdEvent] {
        q.sync { events }
    }

    public func revenuesSnapshot() -> [RevenueEvent] {
        q.sync { revenues }
    }

    public func externalEventsSnapshot() -> [AdDebugExternalEvent] {
        q.sync { externalEvents }
    }

    public func customEventsSnapshot() -> [AdDebugCustomEvent] {
        q.sync { customEvents }
    }

    public func clearEvents() {
        q.async {
            self.events.removeAll()
            self.revenues.removeAll()
            self.externalEvents.removeAll()
            self.customEvents.removeAll()
            self._debugLines.removeAll()
            self.recentDebugLineTimestamps.removeAll()
            self.adStates.removeAll()
            self.notifyOnQueue()
        }
    }

    // MARK: - Public API: Ad Unit Resolver

    public func resolveAdUnitId(
        provider: any AdIDProvider,
        admobOnlyProvider: (any AdIDProvider)? = nil,
        role: AdIdRequestRole = .primary
    ) -> String {
        let unit = adDebugUnit(for: provider)
        let fallbackId = admobOnlyProvider?.id ?? unit.admobOnlyAdUnitId
        return resolveAdUnitId(
            placement: provider.name,
            primaryAdUnitId: provider.id,
            unit: unit.unit,
            admobOnlyAdUnitId: fallbackId,
            role: role
        )
    }

    public func resolveAdUnitId(
        placement: String,
        primaryAdUnitId: String,
        unit: AdDebugUnit,
        admobOnlyAdUnitId: String? = nil,
        role: AdIdRequestRole = .primary
    ) -> String {
        let currentSettings = settings
        guard currentSettings.debugEnabled else {
            return originalAdUnitId(primary: primaryAdUnitId, admobOnly: admobOnlyAdUnitId, role: role)
        }
        guard !isReadOnlyAppId(primaryAdUnitId) else { return primaryAdUnitId }

        switch currentSettings.adIdOverrideMode {
        case .normal:
            return originalAdUnitId(primary: primaryAdUnitId, admobOnly: admobOnlyAdUnitId, role: role)
        case .failPrimary:
            if role == .primary, isPriorityPlacement(placement) {
                return GoogleMobileAdsTestUnitIds.invalid
            }
            return originalAdUnitId(primary: primaryAdUnitId, admobOnly: admobOnlyAdUnitId, role: role)
        case .failAll:
            return invalidAdUnitId(for: primaryAdUnitId)
        case .forceAdMobOnly:
            if isAdmobOnlyPlacement(placement) {
                return primaryAdUnitId
            }
            if role == .admobOnly {
                return admobOnlyAdUnitId ?? primaryAdUnitId
            }
            return invalidAdUnitId(for: primaryAdUnitId)
        case .custom:
            return resolveCustomAdUnitId(
                placement: placement,
                primaryAdUnitId: primaryAdUnitId,
                unit: unit,
                admobOnlyAdUnitId: admobOnlyAdUnitId,
                role: role,
                settings: currentSettings
            )
        }
    }

    public func getAdUnits() -> [AdDebugAdUnit] {
        adUnitsLock.lock()
        if let adUnitsCache {
            adUnitsLock.unlock()
            return adUnitsCache
        }
        adUnitsLock.unlock()

        guard let config = configuration else { return [] }
        let units = config.getAllAdIDs().map { buildAdDebugUnit(for: $0) }

        adUnitsLock.lock()
        adUnitsCache = units
        adUnitsLock.unlock()

        return units
    }

    // MARK: - Public API: Ad States

    public func getAdStates() -> [AdStateInfo] {
        let units = getAdUnits()
        guard !units.isEmpty else { return [] }

        return q.sync {
            for unit in units {
                let adIdName = unit.name
                if adStates[adIdName] == nil {
                    adStates[adIdName] = AdStateInfo(
                        adIdName: adIdName,
                        adId: unit.adUnitId,
                        loadState: .notLoad,
                        showState: .no,
                        revenueUSD: 0,
                        successCount: 0,
                        failedCount: 0,
                        showedCount: 0
                    )
                }
            }
            let currentSettings = settings
            return units.compactMap { unit in
                guard let state = adStates[unit.name] else { return nil }
                return state.withAdId(resolvedAdUnitIdForDisplay(unit, settings: currentSettings))
            }
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
            let now = Date()
            let ts = self.timeFormatter.string(from: now)

            for s in lines {
                let key = self.debugLineKey(s)
                if self.isRecentDebugLineDuplicate(key, now: now) { continue }
                self.rememberDebugLineKey(key, now: now)
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
        if externalEvents.count > k { externalEvents.removeLast(externalEvents.count - k) }
        if customEvents.count > k { customEvents.removeLast(customEvents.count - k) }
    }

    /// Thread-safe notify entrypoint (can be called from any thread)
    private func notify() {
        if isOnQueue {
            notifyOnQueue()
        } else {
            q.async { self.notifyOnQueue() }
        }
    }

    private func debugLineKey(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"^\[[^\]]+\]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^OSLog:\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isRecentDebugLineDuplicate(_ key: String, now: Date) -> Bool {
        pruneRecentDebugLines(now: now)
        guard let previous = recentDebugLineTimestamps[key] else { return false }
        return now.timeIntervalSince(previous) < recentDebugLineDedupWindow
    }

    private func rememberDebugLineKey(_ key: String, now: Date) {
        recentDebugLineTimestamps[key] = now
        guard recentDebugLineTimestamps.count > recentDebugLineLimit else { return }
        let overflow = recentDebugLineTimestamps.count - recentDebugLineLimit
        let oldestKeys = recentDebugLineTimestamps
            .sorted { $0.value < $1.value }
            .prefix(overflow)
            .map(\.key)
        oldestKeys.forEach { recentDebugLineTimestamps.removeValue(forKey: $0) }
    }

    private func pruneRecentDebugLines(now: Date) {
        let cutoff = now.addingTimeInterval(-recentDebugLineDedupWindow)
        recentDebugLineTimestamps = recentDebugLineTimestamps.filter { $0.value >= cutoff }
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
                showState: .showing,
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
        case .showFail:
            currentState = AdStateInfo(
                adIdName: adIdName,
                adId: adId,
                loadState: currentState.loadState,
                showState: .failed,
                revenueUSD: currentState.revenueUSD,
                successCount: currentState.successCount,
                failedCount: currentState.failedCount + 1,
                showedCount: currentState.showedCount
            )
        default:
            break
        }

        adStates[adIdName] = currentState
    }

    private func adDebugUnit(for provider: any AdIDProvider) -> AdDebugAdUnit {
        if let cached = getAdUnits().first(where: { $0.name == provider.name }) {
            return cached
        }
        return buildAdDebugUnit(for: provider)
    }

    private func buildAdDebugUnit(for provider: any AdIDProvider) -> AdDebugAdUnit {
        if let configured = configuration?.adUnitMetadata?(provider) {
            return configured
        }
        let backup = configuration?.admobOnlyAdID?(provider)?.id
        let unit = AdDebugUnit(adUnitName: provider.name, adUnitId: provider.id)
        return AdDebugAdUnit(
            name: provider.name,
            adUnitId: provider.id,
            unit: unit,
            isReadOnly: isReadOnlyAppId(provider.id),
            admobOnlyAdUnitId: backup
        )
    }

    private func originalAdUnitId(primary: String, admobOnly: String?, role: AdIdRequestRole) -> String {
        switch role {
        case .primary: return primary
        case .admobOnly: return admobOnly ?? primary
        }
    }

    private func customMode(forAdUnitName adUnitName: String, settings currentSettings: Settings) -> AdUnitCustomMode {
        return currentSettings.customAdUnitModes[adUnitName] ?? .release
    }

    private func resolveCustomAdUnitId(
        placement: String,
        primaryAdUnitId: String,
        unit: AdDebugUnit,
        admobOnlyAdUnitId: String?,
        role: AdIdRequestRole,
        settings currentSettings: Settings
    ) -> String {
        switch customMode(forAdUnitName: placement, settings: currentSettings) {
        case .release:
            return originalAdUnitId(primary: primaryAdUnitId, admobOnly: admobOnlyAdUnitId, role: role)
        case .debug:
            return GoogleMobileAdsTestUnitIds.id(for: unit)
        case .falseAd:
            return invalidAdUnitId(for: primaryAdUnitId)
        case .admobOnly:
            return admobOnlyAdUnitId ?? primaryAdUnitId
        }
    }

    private func snapshotDisplayModes(for mode: AdIdOverrideMode) -> [String: AdUnitCustomMode] {
        return getAdUnits()
            .filter(isOverridable)
            .reduce(into: [String: AdUnitCustomMode]()) { result, adUnit in
                result[adUnit.name] = displayMode(for: adUnit, mode: mode)
            }
    }

    private func displayMode(for adUnit: AdDebugAdUnit, settings currentSettings: Settings) -> AdUnitCustomMode {
        guard isOverridable(adUnit) else { return .release }
        if currentSettings.adIdOverrideMode == .custom {
            return customMode(forAdUnitName: adUnit.name, settings: currentSettings)
        }
        return displayMode(for: adUnit, mode: currentSettings.adIdOverrideMode)
    }

    private func displayMode(for adUnit: AdDebugAdUnit, mode: AdIdOverrideMode) -> AdUnitCustomMode {
        guard isOverridable(adUnit) else { return .release }
        switch mode {
        case .normal:
            return .release
        case .failPrimary:
            return isPriorityPlacement(adUnit.name) ? .falseAd : .release
        case .failAll:
            return .falseAd
        case .forceAdMobOnly:
            return isAdmobOnlyPlacement(adUnit.name) ? .release : .falseAd
        case .custom:
            return customMode(forAdUnitName: adUnit.name)
        }
    }

    private func isOverridable(_ adUnit: AdDebugAdUnit) -> Bool {
        return !adUnit.isReadOnly && adUnit.unit != .appId
    }

    private func isOverridablePlacement(_ placement: String) -> Bool {
        guard let adUnit = getAdUnits().first(where: { $0.name == placement }) else { return true }
        return isOverridable(adUnit)
    }

    private func invalidAdUnitId(for primaryAdUnitId: String) -> String {
        return isReadOnlyAppId(primaryAdUnitId) ? primaryAdUnitId : GoogleMobileAdsTestUnitIds.invalid
    }

    private func admobOnlyDisplayId(for adUnit: AdDebugAdUnit) -> String {
        if adUnit.unit == .appId { return adUnit.adUnitId }
        if let direct = adUnit.admobOnlyAdUnitId { return direct }
        let peerName = admobOnlyPeerPlacement(for: adUnit.name)
        return getAdUnits().first(where: { $0.name == peerName })?.adUnitId ?? adUnit.adUnitId
    }

    private func isReadOnlyAppId(_ adUnitId: String) -> Bool {
        return adUnitId.contains("~") && !adUnitId.contains("/")
    }

    private func isPriorityPlacement(_ placement: String) -> Bool {
        let lower = placement.lowercased()
        return lower.contains("2fid") || lower.contains("mfid") || lower.contains("_2f_id") || lower.contains("_mf_id")
    }

    private func isAdmobOnlyPlacement(_ placement: String) -> Bool {
        return placement.lowercased().contains("admobonly") || placement.lowercased().contains("admob_only")
    }

    private func admobOnlyPeerPlacement(for placement: String) -> String? {
        guard !isAdmobOnlyPlacement(placement) else { return nil }
        if placement.hasSuffix("ID") {
            return String(placement.dropLast(2)) + "AdMobOnlyID"
        }
        if placement.hasSuffix("_id") {
            return String(placement.dropLast(3)) + "_admob_only_id"
        }
        return nil
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

    func resetForTesting() {
        ExternalLogTap.shared.stop()
        MotionShakeDetector.shared.stop()
        configuration = nil
        clearSettingsCache()
        invalidateAdUnitsCache()
        UserDefaults.standard.removeObject(forKey: udKey)
        UserDefaults.standard.removeObject(forKey: "telemetry.ads.debugEnabled")
        q.sync {
            events.removeAll()
            revenues.removeAll()
            externalEvents.removeAll()
            customEvents.removeAll()
            adStates.removeAll()
            _debugLines.removeAll()
            recentDebugLineTimestamps.removeAll()
            notifyScheduled = false
        }
    }
}

enum AdStructuredLogParser {
    static func parse(_ line: String) -> [String: String] {
        var result: [String: String] = [:]
        var key = ""
        var value = ""
        var readingKey = true
        var inQuotes = false
        var quote: Character = "\""

        func flush() {
            guard !key.isEmpty else { return }
            result[key] = value
            key.removeAll(keepingCapacity: true)
            value.removeAll(keepingCapacity: true)
            readingKey = true
        }

        for ch in line {
            if readingKey {
                if ch == "=" {
                    readingKey = false
                } else if ch == " " || ch == "\t" || ch == "\n" {
                    flush()
                } else {
                    key.append(ch)
                }
            } else {
                if inQuotes {
                    if ch == quote {
                        inQuotes = false
                    } else {
                        value.append(ch)
                    }
                } else if ch == "\"" || ch == "'" {
                    inQuotes = true
                    quote = ch
                } else if ch == " " || ch == "\t" || ch == "\n" {
                    flush()
                } else {
                    value.append(ch)
                }
            }
        }
        flush()
        return result
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
