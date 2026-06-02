# AdsDebugKit

AdsDebugKit is an in-app debug panel for inspecting iOS ads, ad revenue, external tracking events, custom QA logs, and runtime ad unit overrides in debug or internal release builds.

It is designed for production QA flows where testers need to enable a hidden debug panel from inside the app, inspect real ad states, force ad-load failures, test AdMob-only fallback, and verify tracking SDK callbacks without rebuilding the app.

## Requirements

- iOS 13+
- Swift 5.9+
- Xcode 15+
- Swift Package Manager

## Features

- Hidden unlock gesture support for release builds.
- Scene-aware near-fullscreen UIKit debug panel with a SwiftUI lifecycle adapter.
- Ad state dashboard for real ad placements: load, show/impression, and revenue.
- External tracking tab for Adjust, AppsFlyer, Firebase, Meta, in-house, and similar SDK events.
- Custom event tab for app-defined QA/debug signals.
- Runtime ad unit override modes: normal, fail primary, fail all, force AdMob-only, and custom per placement.
- Official iOS Google Mobile Ads demo IDs for debug requests.
- Structured parser for `ads_debug=1`, `external_debug=1`, and `custom_debug=1`.
- Backward-compatible APIs: `AdTelemetry.initialize`, `AdIDProvider`, `AdEvent`, `RevenueEvent`, and `logDebugLine`.
- Optional legacy raw log tap for old stdout/stderr SDK logs.

## Installation

### Swift Package Manager

In Xcode:

1. Open File -> Add Package Dependencies...
2. Paste the repository URL:

```text
https://github.com/kiluss2/AdsDebugKit.git
```

3. Select the version, for example `2.0.0`.
4. Add `AdsDebugKit` to your app target.

In `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/kiluss2/AdsDebugKit.git", from: "2.0.0")
]
```

## Quick Start

### 1. Provide Ad IDs

iOS does not auto-discover ad IDs from config, resources, or Info.plist. The app must provide all placements through `AdIDProvider`. This is intentional: iOS apps can name enums and config keys differently, so the app-provided provider is the stable source of truth.

```swift
import AdsDebugKit

enum AdvertisementID: String, CaseIterable, AdIDProvider {
  case banner = "ADSBannerID"
  case interstitial = "ADSInterstitialID"
  case interstitialAdMobOnly = "ADSInterstitialAdMobOnlyID"
  case rewarded = "ADSRewardedID"
  case native = "ADSNativeID"

  var name: String { rawValue }

  var id: String {
    // Return the real ad unit ID from your config, remote config, or Info.plist layer.
    getAdUnitID(for: self)
  }
}
```

### 2. Initialize Once

Initialize from `AppDelegate`, `SceneDelegate`, or a SwiftUI `App.init()`.

```swift
import AdsDebugKit

let config = AdTelemetryConfiguration(
  allAdIDs: { AdvertisementID.allCases },
  adUnitMetadata: { provider in
    guard let adId = provider as? AdvertisementID else { return nil }
    return AdDebugAdUnit(
      name: adId.name,
      adUnitId: adId.id,
      unit: AdDebugUnit(adUnitName: adId.name, adUnitId: adId.id),
      admobOnlyAdUnitId: nil
    )
  },
  admobOnlyAdID: { provider in
    // Optional: return the matching AdMob-only fallback provider for mediation placements.
    nil
  },
  rawLogTapPolicy: .disabled
)

AdTelemetry.initialize(config)
```

### 3. Enable Debug Mode

Only enable debug mode from debug builds, internal builds, remote config, or a hidden tester gesture.

```swift
AdTelemetry.setDebugEnabled(true)
```

When debug mode is enabled, shake the device to toggle the panel. You can also show it directly:

```swift
AdsDebugWindowManager.shared.show()
AdsDebugWindowManager.shared.hide()
AdsDebugWindowManager.shared.toggle()
```

### 4. Attach A Hidden Gesture

Use the same style as Android: attach an unlock gesture to a quiet view, such as an app icon on a splash or settings screen.

```swift
let helper = DebugComboGestureHelper()
helper.setup(on: appIconView) {
  AdTelemetry.setDebugEnabled(true)
  AdsDebugWindowManager.shared.show()
}
```

Keep a strong reference to `helper` for as long as the unlock view is alive.

### 5. Log Ad Events

Log from the real ad SDK lifecycle callbacks:

```swift
AdTelemetry.shared.log(AdEvent(
  unit: .interstitial,
  action: .loadStart,
  adId: AdvertisementID.interstitial
))

AdTelemetry.shared.log(AdEvent(
  unit: .interstitial,
  action: .loadSuccess,
  adId: AdvertisementID.interstitial,
  network: "admob"
))

AdTelemetry.shared.log(AdEvent(
  unit: .interstitial,
  action: .loadFail,
  adId: AdvertisementID.interstitial,
  error: error.localizedDescription
))
```

Supported actions include `loadStart`, `loadSuccess`, `loadFail`, `showStart`, `showSuccess`, `showFail`, `showDismissed`, `click`, `impression`, `populate`, `fallback`, `debug`, and `custom`.

### 6. Log Revenue

For Google Mobile Ads, log revenue from `paidEventHandler`. AdsDebugKit does not import Google Mobile Ads, so the app owns the SDK integration.

```swift
AdTelemetry.shared.logRevenue(RevenueEvent(
  unit: .interstitial,
  adId: AdvertisementID.interstitial,
  network: "admob",
  valueUSD: 0.0025,
  precision: "publisher_defined"
))
```

### 7. Resolve Ad Unit IDs Before Loading Ads

Runtime override only affects requests that pass through the resolver before loading an ad.

```swift
let requestAdUnitId = AdTelemetry.shared.resolveAdUnitId(
  provider: AdvertisementID.interstitial,
  role: .primary
)
```

For an AdMob-only fallback request:

```swift
let fallbackAdUnitId = AdTelemetry.shared.resolveAdUnitId(
  provider: AdvertisementID.interstitial,
  admobOnlyProvider: AdvertisementID.interstitialAdMobOnly,
  role: .admobOnly
)
```

You can also resolve raw strings when your ads module does not want to pass enum values around:

```swift
let adUnitId = AdTelemetry.shared.resolveAdUnitId(
  placement: "ADSInterstitialID",
  primaryAdUnitId: primaryId,
  unit: .interstitial,
  admobOnlyAdUnitId: fallbackId,
  role: .primary
)
```

Recommended architecture: keep this call behind a small bridge in your ads module. That keeps ad loading code independent from debug UI details.

```swift
enum AdsDebugBridge {
  static func resolve(
    provider: any AdIDProvider,
    admobOnlyProvider: (any AdIDProvider)? = nil,
    role: AdIdRequestRole = .primary
  ) -> String {
    AdTelemetry.shared.resolveAdUnitId(
      provider: provider,
      admobOnlyProvider: admobOnlyProvider,
      role: role
    )
  }
}
```

## Release Safety

AdsDebugKit is safe to include in release builds when debug mode is disabled.

When `debugEnabled = false`:

- Ad unit override is disabled.
- `resolveAdUnitId(...)` returns the original configured IDs.
- Shake detector is stopped.
- Legacy raw log tap is stopped.
- The debug overlay is hidden.
- Event logging APIs return without storing UI state.

This means app ads use the normal production configuration unless a tester explicitly enables debug mode.

## Runtime Ad Unit Override

### Override Modes

- `normal`: use configured app IDs.
- `failPrimary`: priority placements use invalid IDs; normal and AdMob-only requests stay configured.
- `failAll`: all overridable ad unit requests use invalid IDs.
- `forceAdMobOnly`: primary requests fail; AdMob-only fallback requests use configured backup IDs.
- `custom`: each placement can be set from the Ad Units tab.

Custom per-placement modes:

- `release`: use the configured app ID.
- `debug`: use the official iOS AdMob demo ID for the detected unit type.
- `false`: use an invalid ad unit ID.
- `admobOnly`: use the configured AdMob-only fallback when available.

App IDs in the `ca-app-pub-xxx~yyy` format are read-only and are not overridden.

### Official iOS AdMob Demo IDs

The debug mode uses Google's official iOS demo ad unit IDs:

- App open: `ca-app-pub-3940256099942544/5575463023`
- Banner fixed: `ca-app-pub-3940256099942544/2934735716`
- Adaptive banner: `ca-app-pub-3940256099942544/2435281174`
- Interstitial: `ca-app-pub-3940256099942544/4411468910`
- Rewarded: `ca-app-pub-3940256099942544/1712485313`
- Rewarded interstitial: `ca-app-pub-3940256099942544/6978759866`
- Native: `ca-app-pub-3940256099942544/3986624511`

## Structured Ads Logging

AdsDebugKit can parse deterministic structured lines through API calls. Unlike Android, iOS does not globally hook Timber or logcat.

```swift
AdTelemetry.shared.logStructuredLine(
  "ads_debug=1 event=load_success unit=interstitial placement=ADSInterstitialID adUnit=ca-app-pub-xxx/yyy network=AdMob"
)
```

Required fields:

- `ads_debug=1`
- `event` or `action`
- `unit`
- `placement` or `name`

Useful optional fields:

- `adUnit`
- `network`
- `lineItem`
- `message`
- `error`
- `eCPM`
- `valueUSD`
- `revenueUSD`
- `precision`

Revenue can be emitted as a structured line by including `valueUSD`:

```swift
AdTelemetry.shared.logStructuredLine(
  "ads_debug=1 event=paid unit=interstitial placement=ADSInterstitialID adUnit=ca-app-pub-xxx/yyy valueUSD=0.0025 network=AdMob precision=publisher_defined"
)
```

## External Tracking Logs

External tracking logs use typed APIs or structured lines:

```text
external_debug=1 provider=<provider> event=<event> status=<status> message=<optional>
```

```swift
AdTelemetry.shared.logExternal(
  provider: "appsflyer",
  event: "start",
  status: .success,
  message: "started"
)

AdTelemetry.shared.logStructuredLine(
  "external_debug=1 provider=appsflyer event=purchase status=success message=ok"
)
```

Supported statuses:

- `submitted`
- `success`
- `failed`
- `raw`
- `debug`

Recommended provider names:

- `adjust`
- `appsflyer`
- `firebase`
- `meta`
- `tiktok`
- `in_house`

Recommended event names:

- `init`
- `start`
- `purchase`
- `ad_revenue`
- `custom`

Provider guidance:

- Google Mobile Ads: log load/show/click/impression from delegates and revenue from `paidEventHandler`.
- Adjust: iOS does not provide an Android-style official per-request response callback for every tracking/ad-revenue call. Use available Adjust delegate callbacks for event/session success or failure, and log local `submitted` for ad revenue calls. OSLog response capture is best-effort only.
- AppsFlyer: use `start(completionHandler:)` and `logEvent(...completionHandler:)` to log success or failure.
- Firebase Analytics: log `submitted` after the local API call; Firebase does not expose a stable per-event delivery callback.
- Meta App Events: log `submitted` after the local API call; SDK debug/flush logs are supplementary and not a stable delivery callback.

Keep these hooks in the app tracking layer, not in UI code.

## Custom Debug Events

Use custom events for app-specific QA signals that should not be mixed into ad states or external SDK tracking.

```swift
AdTelemetry.shared.logCustom(
  event: "paywall_opened",
  status: "submitted",
  values: ["source": "onboarding"]
)

AdTelemetry.shared.logStructuredLine(
  "custom_debug=1 event=paywall_opened status=submitted message=onboarding"
)
```

## Debug Console

Tabs are aligned with Android:

- `Ad States`: current load/show/revenue state per placement.
- `Ad Events`: chronological ad lifecycle and revenue events.
- `Externals`: tracking callbacks plus legacy raw lines in one feed.
- `Custom`: app-defined QA/debug events.
- `Settings`: debug mode, toast, override mode, event retention, and legacy raw log tap.
- `Ad Units`: all configured placements and per-placement override mode.

The panel uses a GIF background, adaptive light/dark foreground theme based on the first GIF frame, rounded translucent cards, and shadowed section headers for readability.

### SwiftUI Apps

SwiftUI apps still run inside `UIWindowScene`. Use the lifecycle adapter when you do not have an AppDelegate entry point:

```swift
import SwiftUI
import AdsDebugKit

@main
struct MyApp: App {
  init() {
    AdTelemetry.initialize(AdTelemetryConfiguration(
      allAdIDs: { AdvertisementID.allCases }
    ))
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .adsDebugConsoleLifecycle(enabled: true)
    }
  }
}
```

You can also call `AdsDebugSwiftUIBridge.show()`, `hide()`, or `toggle()` from SwiftUI controls.

## Legacy Raw Log Tap

Prefer typed callbacks and `logStructuredLine`. Raw log capture is legacy and disabled by default.

```swift
let config = AdTelemetryConfiguration(
  allAdIDs: { AdvertisementID.allCases },
  rawLogTapPolicy: .legacyFiltered
)

AdTelemetry.initialize(config)
AdTelemetry.shared.setRawLogTapEnabled(true)
```

Policies:

- `.disabled`: no raw runtime capture.
- `.legacyFiltered`: capture filtered stdout/stderr-style logs only.
- `.legacyFilteredWithOSLog`: also poll `OSLogStore` for Adjust-style response lines.

`OSLogStore` polling can be expensive on noisy devices. Use `.legacyFilteredWithOSLog` only for short local debugging sessions, not for normal QA or release builds.

## Configuration

```swift
AdTelemetryConfiguration(
  allAdIDs: { AdvertisementID.allCases },
  adUnitMetadata: { provider in
    guard let adId = provider as? AdvertisementID else { return nil }
    return AdDebugAdUnit(
      name: adId.name,
      adUnitId: adId.id,
      unit: AdDebugUnit(adUnitName: adId.name, adUnitId: adId.id),
      isReadOnly: false,
      admobOnlyAdUnitId: nil
    )
  },
  admobOnlyAdID: { provider in
    nil
  },
  rawLogTapPolicy: .disabled
)
```

Settings are stored in `UserDefaults` and migrated from older payloads with safe defaults.

## Public API Surface

Main entry points:

- `AdTelemetry.initialize(...)`
- `AdTelemetry.setDebugEnabled(...)`
- `AdTelemetry.refreshDebugServices()`
- `AdTelemetry.shared.log(...)`
- `AdTelemetry.shared.logRevenue(...)`
- `AdTelemetry.shared.logExternal(...)`
- `AdTelemetry.shared.logCustom(...)`
- `AdTelemetry.shared.logStructuredLine(...)`
- `AdTelemetry.shared.resolveAdUnitId(...)`
- `AdsDebugWindowManager.shared.show()`
- `AdsDebugWindowManager.shared.hide()`
- `AdsDebugWindowManager.shared.toggle()`
- `AdsDebugSwiftUIBridge`
- `DebugComboGestureHelper`
- `AdTelemetryConfiguration`
- `AdIDProvider`
- `AdDebugAdUnit`
- `AdDebugUnit`
- `AdIdOverrideMode`
- `AdUnitCustomMode`
- `AdIdRequestRole`
- `AdRawLogTapPolicy`

Implementation details such as the panel view controllers, window internals, GIF theme detection, and raw log tap internals should be treated as private.

## App Migration From v1

Existing apps using these APIs should continue to compile:

- `AdTelemetry.initialize(...)`
- `AdIDProvider`
- `AdEvent`
- `RevenueEvent`
- `logDebugLine(...)`

Recommended migration for full v2 behavior:

1. Keep the existing `AdIDProvider` enum.
2. Add optional `adUnitMetadata` and `admobOnlyAdID` mappings.
3. Add a small ads-module bridge around `resolveAdUnitId(...)`.
4. Replace ad load IDs with the bridge result before each SDK load call.
5. Forward tracking SDK callbacks into `logExternal(...)`.
6. Move app QA prints to `logCustom(...)` or `custom_debug=1`.
7. Leave `rawLogTapPolicy` disabled unless an old SDK still emits useful stdout/stderr logs.

## Verification

Library checks:

```bash
xcodebuild test -scheme AdsDebugKit -destination 'platform=iOS Simulator,name=iPhone 17'
```

Consumer app checks:

```bash
xcodebuild -workspace <App>.xcworkspace -scheme <AppScheme> -configuration Debug -sdk iphonesimulator build
```

## Publishing

SPM releases are Git tags. Before publishing:

1. Run the library tests.
2. Build a representative consumer app.
3. Make sure the working tree is clean.
4. Tag the verified commit.

```bash
git tag -a v2.0.0 -m "Release v2.0.0"
git push origin v2.0.0
gh release create v2.0.0 \
  --title "AdsDebugKit v2.0.0" \
  --notes "AdsDebugKit iOS v2 release."
```

Do not retag an existing version. If the library changes after `2.0.0`, bump the tag, for example to `2.0.1`.

## License

MIT
