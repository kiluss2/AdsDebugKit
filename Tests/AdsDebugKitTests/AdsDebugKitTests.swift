import XCTest
@testable import AdsDebugKit

final class AdsDebugKitTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AdTelemetry.shared.resetForTesting()
        AdTelemetry.initialize(AdTelemetryConfiguration(
            allAdIDs: { TestAdID.allCases },
            admobOnlyAdID: { provider in
                provider.name == TestAdID.priority.name ? TestAdID.admobOnly : nil
            }
        ))
    }

    override func tearDown() {
        AdTelemetry.shared.resetForTesting()
        super.tearDown()
    }

    func testResolverReturnsOriginalWhenDebugDisabled() {
        let id = AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority)
        XCTAssertEqual(id, TestAdID.priority.id)
    }

    func testResolverFailPrimaryOnlyAffectsPriorityPlacements() {
        enableDebug(mode: .failPrimary)

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority),
            GoogleMobileAdsTestUnitIds.invalid
        )
        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.banner),
            TestAdID.banner.id
        )
    }

    func testResolverForceAdMobOnlyUsesFallbackForAdMobRole() {
        enableDebug(mode: .forceAdMobOnly)

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority, role: .primary),
            GoogleMobileAdsTestUnitIds.invalid
        )
        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority, role: .admobOnly),
            TestAdID.admobOnly.id
        )
    }

    func testResolverDoesNotOverrideAppId() {
        enableDebug(mode: .failAll)

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.appId),
            TestAdID.appId.id
        )
    }

    func testCustomDebugModeUsesIOSAdMobTestId() {
        enableDebug(mode: .custom)
        AdTelemetry.shared.setCustomMode(.debug, forAdUnitName: TestAdID.banner.name)

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.banner),
            GoogleMobileAdsTestUnitIds.fixedBanner
        )
    }

    func testDisplayModeMirrorsGlobalOverrideMode() {
        enableDebug(mode: .failAll)

        let units = AdTelemetry.shared.getAdUnits()
        let priority = units.first { $0.name == TestAdID.priority.name }!
        let banner = units.first { $0.name == TestAdID.banner.name }!

        XCTAssertEqual(AdTelemetry.shared.displayMode(for: priority), .falseAd)
        XCTAssertEqual(AdTelemetry.shared.displayMode(for: banner), .falseAd)
        XCTAssertEqual(
            AdTelemetry.shared.resolvedAdUnitIdForDisplay(banner),
            GoogleMobileAdsTestUnitIds.invalid
        )
    }

    func testCustomModeSnapshotsCurrentGlobalModeLikeAndroid() {
        enableDebug(mode: .failAll)

        let units = AdTelemetry.shared.getAdUnits()
        let priority = units.first { $0.name == TestAdID.priority.name }!
        let banner = units.first { $0.name == TestAdID.banner.name }!

        AdTelemetry.shared.setCustomMode(.release, forAdUnitName: TestAdID.banner.name)

        XCTAssertEqual(AdTelemetry.shared.settings.adIdOverrideMode, .custom)
        XCTAssertEqual(AdTelemetry.shared.displayMode(for: banner), .release)
        XCTAssertEqual(AdTelemetry.shared.displayMode(for: priority), .falseAd)
        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.banner),
            TestAdID.banner.id
        )
        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority),
            GoogleMobileAdsTestUnitIds.invalid
        )
    }

    func testCustomModeAllReleaseFallsBackToNormalLikeAndroid() {
        enableDebug(mode: .failPrimary)

        AdTelemetry.shared.setCustomMode(.release, forAdUnitName: TestAdID.priority.name)

        XCTAssertEqual(AdTelemetry.shared.settings.adIdOverrideMode, .normal)
        XCTAssertEqual(AdTelemetry.shared.settings.customAdUnitModes, [:])
    }

    func testCustomAdMobOnlyModeUsesFallbackForPrimaryRole() {
        enableDebug(mode: .custom)
        AdTelemetry.shared.setCustomMode(.admobOnly, forAdUnitName: TestAdID.priority.name)

        XCTAssertEqual(
            AdTelemetry.shared.resolveAdUnitId(provider: TestAdID.priority),
            TestAdID.admobOnly.id
        )
    }

    func testAdStatesDisplayResolvedIdAfterModeChange() {
        enableDebug(mode: .failAll)

        let states = AdTelemetry.shared.getAdStates()
        let banner = states.first { $0.adIdName == TestAdID.banner.name }

        XCTAssertEqual(banner?.adId, GoogleMobileAdsTestUnitIds.invalid)
    }

    func testLoadStartAfterSuccessShowsLoadingDuringRefresh() {
        enableDebug()

        AdTelemetry.shared.log(AdEvent(unit: .native, action: .loadSuccess, adId: TestAdID.banner))
        waitUntil {
            AdTelemetry.shared.getAdStates().first { $0.adIdName == TestAdID.banner.name }?.loadState == .success
        }

        AdTelemetry.shared.log(AdEvent(unit: .native, action: .loadStart, adId: TestAdID.banner))
        waitUntil {
            AdTelemetry.shared.getAdStates().first { $0.adIdName == TestAdID.banner.name }?.loadState == .loading
        }

        let banner = AdTelemetry.shared.getAdStates().first { $0.adIdName == TestAdID.banner.name }
        XCTAssertEqual(banner?.successCount, 1)
    }

    func testStructuredParserLogsAdExternalAndCustomEvents() {
        enableDebug()

        AdTelemetry.shared.logStructuredLine("ads_debug=1 event=loadSuccess unit=interstitial placement=ADSInterstitialOpenFirst2FID adUnit=ca-app-pub-test/1 network=admob")
        AdTelemetry.shared.logStructuredLine("external_debug=1 provider=adjust event=purchase status=success message='tracked ok'")
        AdTelemetry.shared.logStructuredLine("custom_debug=1 event=remote_config status=submitted message='loaded'")

        waitUntil {
            AdTelemetry.shared.eventsSnapshot().count == 1 &&
            AdTelemetry.shared.externalEventsSnapshot().count == 1 &&
            AdTelemetry.shared.customEventsSnapshot().count == 1
        }

        XCTAssertEqual(AdTelemetry.shared.eventsSnapshot().first?.action, .loadSuccess)
        XCTAssertEqual(AdTelemetry.shared.externalEventsSnapshot().first?.provider, "adjust")
        XCTAssertEqual(AdTelemetry.shared.customEventsSnapshot().first?.event, "remote_config")
    }

    func testDebugLinesDeduplicateSameRawLine() {
        enableDebug()

        let line = "Adjust Response message: Ad revenue tracked"
        AdTelemetry.shared.logDebugLines([line, line])

        waitUntil {
            AdTelemetry.shared.debugLines.count == 1
        }

        XCTAssertEqual(AdTelemetry.shared.debugLines.first?.contains(line), true)

        AdTelemetry.shared.clearEvents()
        waitUntil {
            AdTelemetry.shared.debugLines.isEmpty
        }

        AdTelemetry.shared.logDebugLine(line)
        waitUntil {
            AdTelemetry.shared.debugLines.count == 1
        }
    }

    func testSettingsDecodeOldPayloadWithDefaults() throws {
        let data = #"{"debugEnabled":true,"showToasts":true,"keepEvents":12}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AdDebugSettings.self, from: data)

        XCTAssertTrue(settings.debugEnabled)
        XCTAssertTrue(settings.showToasts)
        XCTAssertEqual(settings.keepEvents, 12)
        XCTAssertEqual(settings.adIdOverrideMode, .normal)
        XCTAssertEqual(settings.customAdUnitModes, [:])
        XCTAssertFalse(settings.rawLogTapEnabled)
    }

    func testEventTrimAppliesToAllStreams() {
        enableDebug()
        var settings = AdTelemetry.shared.settings
        settings.keepEvents = 1
        AdTelemetry.shared.settings = settings

        AdTelemetry.shared.log(AdEvent(unit: .banner, action: .loadStart, adId: TestAdID.banner))
        AdTelemetry.shared.log(AdEvent(unit: .banner, action: .loadSuccess, adId: TestAdID.banner))
        AdTelemetry.shared.logExternal(provider: "adjust", event: "a", status: .submitted)
        AdTelemetry.shared.logExternal(provider: "adjust", event: "b", status: .success)
        AdTelemetry.shared.logCustom(event: "a")
        AdTelemetry.shared.logCustom(event: "b")

        waitUntil {
            AdTelemetry.shared.eventsSnapshot().count == 1 &&
            AdTelemetry.shared.externalEventsSnapshot().count == 1 &&
            AdTelemetry.shared.customEventsSnapshot().count == 1
        }

        XCTAssertEqual(AdTelemetry.shared.eventsSnapshot().first?.action, .loadSuccess)
        XCTAssertEqual(AdTelemetry.shared.externalEventsSnapshot().first?.event, "b")
        XCTAssertEqual(AdTelemetry.shared.customEventsSnapshot().first?.event, "b")
    }

    func testConsoleTabsMatchAndroidOrder() {
        XCTAssertEqual(AdsDebugVC.tabTitles, ["Ad States", "Ad Events", "Externals", "Custom", "Settings", "Ad Units"])

        let vc = AdsDebugVC()
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.children.count, 1)
    }

    func testSettingsSwitchStaysInsideAndroidStyleRowLayout() {
        let vc = AdsDebugSettingsVC()
        vc.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let window = UIWindow(frame: vc.view.frame)
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()

        let table = vc.view.adsDebugFirstSubview(of: UITableView.self)
        XCTAssertNotNil(table)
        table?.layoutIfNeeded()

        guard let cell = table?.cellForRow(at: IndexPath(row: 0, section: 0)),
              let toggle = cell.adsDebugFirstSubview(of: UISwitch.self) else {
            return XCTFail("Expected first settings row to contain a switch")
        }

        cell.layoutIfNeeded()
        let switchFrame = toggle.convert(toggle.bounds, to: cell.contentView)
        XCTAssertLessThanOrEqual(switchFrame.maxX, cell.contentView.bounds.maxX - 16)
    }

    func testListDesignTokensKeepRoundedCardsAndShadowedHeaderText() {
        let cell = AdsDebugCardTableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.configure(title: "Card", detail: "Line")
        XCTAssertEqual(cell.contentView.subviews.first?.layer.cornerRadius, AdsDebugTheme.cardCornerRadius)

        let header = AdsDebugTheme.sectionHeader(title: "Ad Units (3)")
        header.frame = CGRect(x: 0, y: 0, width: 390, height: 38)
        header.layoutIfNeeded()
        XCTAssertEqual(header.backgroundColor, .clear)
        let label = header.adsDebugFirstSubview(of: UILabel.self)
        XCTAssertNotNil(label)
        XCTAssertGreaterThan(label?.layer.shadowOpacity ?? 0, 0)
    }

    private func enableDebug(mode: AdIdOverrideMode = .normal) {
        var settings = AdTelemetry.shared.settings
        settings.debugEnabled = true
        settings.adIdOverrideMode = mode
        AdTelemetry.shared.settings = settings
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ predicate: @escaping () -> Bool
    ) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if predicate() { return }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        XCTFail("Condition was not met in time", file: file, line: line)
    }
}

private extension UIView {
    func adsDebugFirstSubview<T: UIView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let match = subview.adsDebugFirstSubview(of: type) {
                return match
            }
        }
        return nil
    }
}

private enum TestAdID: String, CaseIterable, Codable, AdIDProvider {
    case priority = "ADSInterstitialOpenFirst2FID"
    case admobOnly = "ADSInterstitialOpenFirstAdMobOnlyID"
    case banner = "ADSBannerID"
    case appId = "GADApplicationIdentifier"

    var name: String { rawValue }

    var id: String {
        switch self {
        case .priority:
            return "ca-app-pub-1234567890123456/1111111111"
        case .admobOnly:
            return "ca-app-pub-1234567890123456/2222222222"
        case .banner:
            return "ca-app-pub-1234567890123456/3333333333"
        case .appId:
            return "ca-app-pub-1234567890123456~4444444444"
        }
    }
}
