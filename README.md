# AdsDebugKit

A lightweight Swift Package Manager (SPM) library for debugging and monitoring ad events, revenue, and states in iOS applications. It also provides a built-in debug console UI for real-time tracking.

## Requirements

- iOS 13+
- Swift 5.9+
- Xcode 14+

## ✨ Features

- 📊 Real-time Ad Event Tracking: Monitor ad events (load, show, click, dismiss, etc.) with a minimal API.
- 💰 Revenue Tracking: Log ad revenue by network and ad unit (USD).
- 📱 Debug Console UI: Full-screen debug interface, opened via shake gesture or programmatically.
- 🔍 Ad State Monitoring: View load/show state for all configured ad IDs.
- 🧵 Thread-safe: All operations are handled safely across different threads.

## 📦 Installation

### Swift Package Manager (Xcode)

1. Go to File → Add Package Dependencies...
2. Paste the repository URL:  
   `https://github.com/kiluss2/AdsDebugKit.git`
3. Select the version (for example: from: `"1.0.0"`) and add AdsDebugKit to your app target.

### Package.swift

```swift
dependencies: [
  .package(url: "https://github.com/kiluss2/AdsDebugKit.git", from: "1.0.0")
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
    // Provide all your ad IDs
    getAllAdIDs: { AdvertisementID.allCases },
    // (Optional) Logic to extract an AdID from a native ad object
    getNativeAdSlotId: { nativeAd in
      return nil
    },
    // (Optional) Default ID for native ads
    defaultNativeAdID: AdvertisementID.banner
  )

  AdTelemetry.shared.configure(config)
  // Initialize (auto-starts if debug mode was previously enabled)
  AdTelemetry.initialize()

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

## 📝 License

This project is licensed under the MIT License. See the LICENSE file for details.