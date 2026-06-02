# AdsDebugKit

A lightweight Swift Package Manager (SPM) library for detaily debugging and monitoring ad events, revenue, and states in iOS applications. It also provides a built-in debug console UI for real-time tracking.

## Requirements

- iOS 13+
- Swift 5.9+
- Xcode 14+

## ✨ Features

- 📊 Real-time Ad Event Tracking: Monitor ad events (load, show, click, dismiss, etc.) with a minimal API.
- 💰 Revenue Tracking: Log ad revenue by network and ad unit (USD).
- 📱 Debug Console UI: Full-screen dark panel with Ad States, Ad Events, Externals, Custom, Settings, and Ad Units tabs.
- 🔍 Ad State Monitoring: View load/show state for all configured ad IDs.
- 🧪 Runtime Ad Unit Overrides: Switch ad units between release, official iOS AdMob demo IDs, invalid IDs, and AdMob-only fallback.
- 🧾 Structured Logs: Parse Android-compatible `ads_debug=1`, `external_debug=1`, and `custom_debug=1` lines deterministically through API calls.
- 🧵 Thread-safe: All operations are handled safely across different threads.

## 📦 Installation

### Swift Package Manager (Xcode)

1. Go to File → Add Package Dependencies...
2. Paste the repository URL:  
   `https://github.com/kiluss2/AdsDebugKit.git`
3. Select the version (for example: from: `"2.0.0"`) and add AdsDebugKit to your app target.

### Package.swift

```swift
dependencies: [
  .package(url: "https://github.com/kiluss2/AdsDebugKit.git", from: "2.0.0")
]
```

## 🚀 Quick Start

### 1. Implement AdIDProvider

Your ad ID enum must conform to the `AdIDProvider` protocol so that AdsDebugKit can list and group your ad units:

```swift
import AdsDebugKit

enum AdvertisementID: String, CaseIterable, AdIDProvider {
  case banner = "ADSBannerID"
  case interstitial = "ADSInterstitialID"
  case rewarded = "ADSRewardedID"
  case native = "ADSNativeID"

  /// Name displayed in the debug UI
  var name: String { rawValue }

  /// The actual ad unit ID string
  var id: String {
    // Return the real ad unit ID (e.g. from Info.plist, Remote Config, etc.)
    getAdUnitID(for: self)
  }
}
```

### 2. Configure AdTelemetry

In your AppDelegate (or wherever your app is initialized):

```swift
import AdsDebugKit

func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
  let config = AdTelemetryConfiguration(
    // Provide all your ad IDs. iOS does not auto-discover IDs from resources.
    allAdIDs: { AdvertisementID.allCases },
    adUnitMetadata: { provider in
      guard let adId = provider as? AdvertisementID else { return nil }
      return AdDebugAdUnit(
        name: adId.name,
        adUnitId: adId.id,
        unit: AdDebugUnit(adUnitName: adId.name, adUnitId: adId.id)
      )
    },
    admobOnlyAdID: { provider in
      // Optional: return an AdMob-only fallback for mediation placements.
      nil
    },
    rawLogTapPolicy: .disabled
  )

  // Initialize (auto-starts if debug mode was previously enabled)
  AdTelemetry.initialize(config)

  return true
}
```

### 3. Enable debug mode (internal builds only)

You usually only want the console in debug / internal builds:

```swift
AdTelemetry.setDebugEnabled(true)
```

You can wrap this behind flags or remote config if needed.

### 4. Log events

Call log at the appropriate points in your ad integration:

```swift
// Log ad load start
AdTelemetry.shared.log(AdEvent(
  unit: .interstitial,
  action: .loadStart,
  adId: AdvertisementID.interstitial
))

// Log ad load success (with network)
AdTelemetry.shared.log(AdEvent(
  unit: .interstitial,
  action: .loadSuccess,
  adId: AdvertisementID.interstitial,
  network: "admob"
))

// Log ad load fail (with error)
AdTelemetry.shared.log(AdEvent(
  unit: .interstitial,
  action: .loadFail,
  adId: AdvertisementID.interstitial,
  error: error.localizedDescription
))
```

### 5. Log revenue

Typically from the paid-event callback of your ad SDK:

```swift
AdTelemetry.shared.logRevenue(RevenueEvent(
  unit: .interstitial,
  adId: AdvertisementID.interstitial,
  network: "admob",
  valueUSD: 0.0025, // Revenue in USD
  precision: "publisher_defined"
))
```

All other parameters (time, lineItem, eCPM, etc.) are optional.

### 6. Resolve ad unit IDs before loading ads

Runtime overrides only affect requests that pass through the resolver:

```swift
let adUnitID = AdTelemetry.shared.resolveAdUnitId(
  provider: AdvertisementID.interstitial,
  role: .primary
)

InterstitialAd.load(with: adUnitID, request: request) { ad, error in
  // ...
}
```

When debug mode is disabled or AdsDebugKit has not been initialized, the resolver returns the original release ID.

### 7. Log tracking callbacks

AdsDebugKit does not import Adjust, AppsFlyer, Firebase, Meta, or Google Mobile Ads. Apps should forward SDK callbacks into typed APIs:

```swift
AdTelemetry.shared.logExternal(
  provider: "adjust",
  event: "purchase",
  status: .success,
  message: "event tracking succeeded",
  values: ["callbackId": callbackId]
)

AdTelemetry.shared.logCustom(
  event: "paywall_result",
  status: "submitted",
  values: ["source": "onboarding"]
)
```

Structured parser compatibility is available without global log hooking:

```swift
AdTelemetry.shared.logStructuredLine("ads_debug=1 unit=interstitial action=load_success name=ADSInterstitialID")
AdTelemetry.shared.logStructuredLine("external_debug=1 provider=appsflyer event=start status=success")
AdTelemetry.shared.logStructuredLine("custom_debug=1 event=paywall status=submitted")
```

## 🛠 Debug Console

When debug mode is enabled (`AdTelemetry.setDebugEnabled(true)`):

- Shake Gesture: Show/hide the console by shaking the device.
- Programmatically:

```swift
// Show the console
AdsDebugWindowManager.shared.show()

// Hide the console
AdsDebugWindowManager.shared.hide()

// Toggle visibility
AdsDebugWindowManager.shared.toggle()
```

You can also integrate your own “secret” button/gesture to enable debug mode before opening the console.

### SwiftUI apps

SwiftUI apps still run inside `UIWindowScene`. Use the SwiftUI adapter when you do not have an AppDelegate entry point:

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

### Legacy raw log tap

`ExternalLogTap` is legacy and disabled by default. Prefer typed callbacks and `logStructuredLine`.
`.legacyFiltered` captures filtered stdout/stderr-style logs only; it does not scan `OSLogStore`.
If an old app still needs filtered runtime log capture, opt in explicitly:

```swift
let config = AdTelemetryConfiguration(
  allAdIDs: { AdvertisementID.allCases },
  rawLogTapPolicy: .legacyFiltered
)
AdTelemetry.initialize(config)
AdTelemetry.shared.setRawLogTapEnabled(true)
```

For short local debugging sessions that must inspect Adjust `OSLog` output, use `.legacyFilteredWithOSLog`.
This mode polls `OSLogStore`, can be expensive on noisy devices, and should not be left enabled for normal QA or release builds.

## 📝 License

This project is licensed under the MIT License. See the LICENSE file for details.
