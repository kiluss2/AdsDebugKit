# AdsDebugKit

A comprehensive Swift Package Manager library for debugging and monitoring ad events, revenue, and states in iOS applications. This library provides a complete debug console UI with real-time event tracking, revenue analytics, and ad state monitoring.

## Features

- 📊 **Real-time Ad Event Tracking**: Monitor all ad events (load, show, dismiss, click, etc.) with clean, minimal API
- 💰 **Revenue Tracking**: Track ad revenue by network and ad unit
- 📱 **Debug Console UI**: Full-featured debug interface accessible via shake gesture or programmatically
- 🔄 **Automatic Shake Recovery**: Shake detection automatically recovers after full-screen ads dismiss - no manual intervention needed!
- 🔍 **Ad State Monitoring**: View load/show states for all ad IDs
- 📝 **Adjust Logs Integration**: Capture and display Adjust SDK logs (optional)
- 🎯 **Toast Notifications**: Visual feedback for ad events (optional)
- 🔐 **Thread-safe**: All operations are thread-safe with proper queue management
- 🎨 **Clean API**: Default values for all optional parameters - write less code, focus on what matters

## Requirements

- iOS 13.0+
- Swift 5.9+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/kiluss2/AdsDebugKit.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies...
2. Enter the repository URL
3. Select version or branch

### Local Package (Development)

If you're using a local package:

```swift
dependencies: [
    .package(path: "/path/to/AdsDebugKit")
]
```

## Quick Start

### 1. Implement AdIDProvider Protocol

Your ad ID enum must conform to `AdIDProvider`:

```swift
import AdsDebugKit

enum AdvertisementID: String, CaseIterable {
    case banner = "ADSBannerID"
    case interstitial = "ADSInterstitialID"
    case rewarded = "ADSRewardedID"
    case native = "ADSNativeID"
    
    var name: String { rawValue }
    var id: String {
        // Return the actual ad unit ID string
        // This could come from Info.plist, remote config, etc.
        return getAdUnitID(for: self)
    }
}

extension AdvertisementID: AdIDProvider {}
```

### 2. Configure AdTelemetry

In your `AppDelegate` or app initialization:

```swift
import AdsDebugKit

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Configure AdTelemetry
    let config = AdTelemetryConfiguration(
        getAllAdIDs: { AdvertisementID.allCases },
        getNativeAdSlotId: { nativeAd in
            // Extract ad ID from native ad object
            // This depends on how you store the ad ID in your native ad
            return extractAdID(from: nativeAd)
        },
        defaultNativeAdID: AdvertisementID.native
    )
    
    AdTelemetry.shared.configure(config)
    
    // Initialize (auto-starts debug services if previously enabled)
    AdTelemetry.initialize()
    
    return true
}
```

### 3. Log Ad Events

Throughout your ad integration code, log events. **All optional parameters have default values**, so you only need to pass what's relevant:

```swift
// Log ad load start (minimal - only required parameters)
AdTelemetry.shared.log(AdEvent(
    unit: .interstitial,
    action: .loadStart,
    adId: AdvertisementID.interstitial
))

// Log ad load success (with network and lineItem)
AdTelemetry.shared.log(AdEvent(
    unit: .interstitial,
    action: .loadSuccess,
    adId: AdvertisementID.interstitial,
    network: "admob",
    lineItem: "interstitial_001"
))

// Log ad load fail (with error)
AdTelemetry.shared.log(AdEvent(
    unit: .interstitial,
    action: .loadFail,
    adId: AdvertisementID.interstitial,
    error: error.localizedDescription
))

// Log revenue (valueUSD is required, others are optional)
AdTelemetry.shared.logRevenue(RevenueEvent(
    unit: .interstitial,
    adId: AdvertisementID.interstitial,
    network: "admob",
    lineItem: "interstitial_001",
    valueUSD: 0.0025,
    precision: "publisher_defined"
))
```

**Note**: `time` parameter defaults to `Date()`, and all optional parameters (`network`, `lineItem`, `eCPM`, `precision`, `error`) default to `nil`. Only pass them when you have actual values.

### 4. Access Debug Console

The debug console can be accessed in multiple ways:

**Option 1: Shake Gesture** (automatically enabled when debug mode is on)
- Shake your device to toggle the debug console
- **Automatic Recovery**: `ShakeMonitor` automatically recovers after full-screen ads (interstitial, rewarded, app open) dismiss. No manual intervention needed!
- The monitor listens to window lifecycle notifications and automatically re-arms shake detection with intelligent backoff timing

**Option 2: Programmatically**
```swift
// Show debug console
AdsDebugWindowManager.shared.show()

// Hide debug console
AdsDebugWindowManager.shared.hide()

// Toggle
AdsDebugWindowManager.shared.toggle()
```

**Option 3: Combo Gesture** (for enabling debug mode)
```swift
// Setup combo gesture on an image view (e.g., app icon)
// Combo: swipe down → double tap → swipe up
DebugComboGestureHelper().setup(on: iconImageView) {
    // Debug mode enabled callback
    print("Debug mode enabled!")
}
```

**Shake Detection Features:**
- ✅ **Automatic Recovery**: No need to call `ShakeMonitor.shared.rearm()` manually after ads dismiss
- ✅ **Smart Backoff**: Uses long backoff (960ms) after disruptive UI changes (interstitial, consent forms, etc.)
- ✅ **Window Lifecycle Aware**: Monitors window visibility, key status, and scene activation
- ✅ **Plug-and-Play**: Works with any ad SDK without requiring app code changes

## API Reference

### AdTelemetry

Main singleton for managing ad telemetry.

#### Configuration

```swift
func configure(_ config: AdTelemetryConfiguration)
```
Configure AdTelemetry with app-specific ad ID provider. Must be called before using AdTelemetry.

#### Initialization

```swift
static func initialize()
```
Initialize AdTelemetry and auto-start debug services if previously enabled.

#### Logging Events

```swift
func log(_ event: AdEvent)
```
Log an ad event. Only logs when debug mode is enabled.

```swift
func logRevenue(_ revenue: RevenueEvent)
```
Log a revenue event. Only logs when debug mode is enabled.

```swift
func logDebugLine(_ line: String)
```
Log a debug line (e.g., from Adjust SDK).

#### Querying Data

```swift
func getAdStates() -> [AdStateInfo]
```
Get current ad states for all configured ad IDs.

```swift
func totalRevenueUSD() -> Double
```
Get total revenue in USD.

```swift
func revenueByNetwork() -> [(String, Double)]
```
Get revenue grouped by network, sorted by value (descending).

#### Settings

```swift
var settings: Settings
```
Access and modify telemetry settings:
- `debugEnabled: Bool` - Enable/disable debug mode
- `showToasts: Bool` - Show toast notifications for events
- `keepEvents: Int` - Maximum number of events to keep (default: 200)

```swift
static func isDebugEnabled() -> Bool
static func setDebugEnabled(_ enabled: Bool)
```
Convenience methods for debug mode.

#### Native Ad Display

```swift
static func logNativeAdDisplay(_ nativeAd: Any, network: String?, lineItem: String?)
```
Log native ad display events. Uses configuration to extract ad ID from native ad object.

### AdEvent

Represents an ad event.

```swift
struct AdEvent: Codable {
    let time: Date                // Defaults to Date() if not provided
    let unit: AdUnitKind          // .interstitial, .rewarded, .appOpen, .banner, .native, .custom(String)
    let action: AdAction          // .loadStart, .loadSuccess, .loadFail, .showStart, .showSuccess, etc.
    let adIdName: String?         // Ad ID name (from AdIDProvider)
    let network: String?          // Ad network name (optional, defaults to nil)
    let lineItem: String?         // Line item name (optional, defaults to nil)
    let eCPM: Double?            // Effective CPM (optional, defaults to nil)
    let precision: String?       // Precision type (optional, defaults to nil)
    let error: String?           // Error message (optional, defaults to nil)
}

// Initializer with default values
init(
    time: Date = Date(),
    unit: AdUnitKind,
    action: AdAction,
    adId: (any AdIDProvider)? = nil,
    network: String? = nil,
    lineItem: String? = nil,
    eCPM: Double? = nil,
    precision: String? = nil,
    error: String? = nil
)
```

### RevenueEvent

Represents a revenue event.

```swift
struct RevenueEvent: Codable {
    let time: Date                // Defaults to Date() if not provided
    let unit: AdUnitKind
    let adIdName: String?         // Ad ID name (optional, defaults to nil)
    let network: String?          // Ad network name (optional, defaults to nil)
    let lineItem: String?         // Line item name (optional, defaults to nil)
    let valueUSD: Double          // Required - revenue value in USD
    let precision: String?       // Precision type (optional, defaults to nil)
}

// Initializer with default values
init(
    time: Date = Date(),
    unit: AdUnitKind,
    adId: (any AdIDProvider)? = nil,
    network: String? = nil,
    lineItem: String? = nil,
    valueUSD: Double,
    precision: String? = nil
)
```

### AdStateInfo

Represents the current state of an ad ID.

```swift
struct AdStateInfo: Codable {
    let adIdName: String           // Ad ID name
    let loadState: AdLoadState     // .notLoad, .loading, .success, .failed
    let showState: AdShowState     // .no, .showed
    var revenueUSD: Double         // Cumulative revenue for this ad ID
}
```

### AdTelemetryConfiguration

Configuration for AdTelemetry.

```swift
struct AdTelemetryConfiguration {
    let getAllAdIDs: () -> [any AdIDProvider]
    let getNativeAdSlotId: (Any) -> (any AdIDProvider)?
    let defaultNativeAdID: any AdIDProvider
}
```

### AdIDProvider Protocol

Protocol that ad ID types must conform to.

```swift
protocol AdIDProvider: Hashable, Codable, CaseIterable {
    var rawValue: String { get }
    var name: String { get }
    var id: String { get }
}
```

### AdsDebugWindowManager

Manages the debug console window.

```swift
class AdsDebugWindowManager {
    static let shared: AdsDebugWindowManager
    
    func show()
    func hide()
    func toggle()
    var isVisible: Bool
}
```

### ShakeMonitor

Automatic shake gesture detection with intelligent recovery after full-screen ads.

```swift
class ShakeMonitor {
    static let shared: ShakeMonitor
    
    func start()  // Called automatically when debug mode is enabled
    func stop()
    func rearm()  // Usually not needed - automatic recovery handles this
    var isEnabled: Bool
}
```

**Features:**
- ✅ **Automatic Recovery**: No need to call `rearm()` manually - automatically recovers after interstitial/rewarded/app open ads dismiss
- ✅ **Smart Backoff**: Uses intelligent backoff timing:
  - Short mode (240ms): For normal window changes
  - Long mode (960ms): For disruptive UI changes (interstitial, consent forms, etc.)
- ✅ **Window Lifecycle Aware**: Monitors multiple window events:
  - `UIWindow.didBecomeKeyNotification`
  - `UIWindow.didResignKeyNotification`
  - `UIWindow.didBecomeVisibleNotification`
  - `UIWindow.didBecomeHiddenNotification`
  - `UIApplication.didBecomeActiveNotification`
  - `UIScene.didActivateNotification` (iOS 13+)
  - `UIScene.willDeactivateNotification` (iOS 13+)
- ✅ **Plug-and-Play**: Works with any ad SDK without requiring app code changes

### DebugComboGestureHelper

Helper for combo gesture to enable debug mode.

```swift
class DebugComboGestureHelper {
    func setup(on imageView: UIImageView, completion: @escaping () -> Void)
    func cleanup()
}
```

### AdToast

Toast notification system.

```swift
class AdToast {
    static func show(_ text: String)
}
```

## Migration Guide

### From App-Specific Code

If you're migrating from app-specific debug code:

1. **Replace Configs.AdvertisementID with AdIDProvider**
   - Make your ad ID enum conform to `AdIDProvider`
   - Implement the required properties

2. **Update AdTelemetry Usage**
   - Add configuration step before initialization
   - Replace direct `Configs.AdvertisementID` usage with protocol

3. **Update Event Logging**
   - `AdEvent` now uses `adIdName: String?` instead of `adId: Configs.AdvertisementID?`
   - Use the new initializer: `AdEvent(..., adId: any AdIDProvider?, ...)`

4. **Update Native Ad Logging**
   - `logNativeAdDisplay` now accepts `Any` instead of `NativeAd`
   - Provide `getNativeAdSlotId` closure in configuration

5. **Update View Controllers**
   - `AdsDebugStatesVC` now uses configuration to get ad IDs
   - No changes needed for other view controllers

### Example Migration

**Before (Old Code):**
```swift
AdTelemetry.shared.log(AdEvent(
    time: Date(),
    unit: .interstitial,
    action: .loadStart,
    adId: Configs.AdvertisementID.ADSInterstitialID,
    network: nil,
    lineItem: nil,
    eCPM: nil,
    precision: nil,
    error: nil
))
```

**After (New Code - Clean):**
```swift
// Minimal - only required parameters
AdTelemetry.shared.log(AdEvent(
    unit: .interstitial,
    action: .loadStart,
    adId: Configs.AdvertisementID.ADSInterstitialID
))

// With network and lineItem when available
AdTelemetry.shared.log(AdEvent(
    unit: .interstitial,
    action: .loadSuccess,
    adId: Configs.AdvertisementID.ADSInterstitialID,
    network: network,
    lineItem: lineItem
))

// With error
AdTelemetry.shared.log(AdEvent(
    unit: .interstitial,
    action: .loadFail,
    adId: Configs.AdvertisementID.ADSInterstitialID,
    error: error.localizedDescription
))
```

**Key Changes:**
- ✅ No need to pass `time: Date()` - defaults to current time
- ✅ No need to pass `nil` for optional parameters - they default to `nil`
- ✅ Only pass parameters when you have actual values
- ✅ Code is much cleaner and easier to read

## Debug Console Features

The debug console provides four main tabs:

1. **Ad States**: View load/show states and revenue for all ad IDs
2. **Ad Events**: View all logged events with filtering and JSON export
3. **Adjust Logs**: View captured Adjust SDK logs (if Adjust SDK is available)
4. **Settings**: Configure debug mode, toasts, and event retention

## Thread Safety

All AdTelemetry operations are thread-safe. Events are logged on a background queue and notifications are posted on the main queue.

## Memory Management

- Events and revenues are automatically trimmed to `keepEvents` count (default: 200)
- Oldest events are removed when limit is reached
- Debug lines are also trimmed to prevent memory issues

## Optional Dependencies

### Adjust SDK

Adjust SDK integration is optional. If Adjust SDK is not available, the Adjust Logs tab will still work but won't fetch ADID.

To use Adjust SDK:
1. Add Adjust SDK to your project
2. The library will automatically detect it via `#if canImport(AdjustSdk)`

## Best Practices

1. **Configure Early**: Call `configure()` and `initialize()` as early as possible in app lifecycle (e.g., in `AppDelegate.didFinishLaunchingWithOptions`)

2. **Log All Events**: Log all ad lifecycle events for complete visibility:
   - Load events: `loadStart`, `loadSuccess`, `loadFail`
   - Show events: `showStart`, `showSuccess`, `showFail`
   - User interactions: `click`, `impression`
   - Lifecycle: `dismiss`

3. **Log Revenue**: Always log revenue events when available (typically in `paidEventHandler`)

4. **Use Default Values**: Don't pass `nil` explicitly - let default values handle it:
   ```swift
   // ✅ Good - clean and readable
   AdTelemetry.shared.log(AdEvent(
       unit: .banner,
       action: .loadStart,
       adId: Configs.AdvertisementID.ADSBannerID
   ))
   
   // ❌ Avoid - unnecessary nil parameters
   AdTelemetry.shared.log(AdEvent(
       unit: .banner,
       action: .loadStart,
       adId: Configs.AdvertisementID.ADSBannerID,
       network: nil,
       lineItem: nil,
       eCPM: nil,
       precision: nil,
       error: nil
   ))
   ```

5. **Pass Network/LineItem When Available**: Only pass `network` and `lineItem` when you have actual values (usually from `responseInfo`)

6. **Use Toast Sparingly**: Enable toasts only during active debugging to avoid UI clutter

7. **Limit Events**: Adjust `keepEvents` based on your needs (default 200 is usually sufficient)

8. **No Manual Shake Recovery**: Don't call `ShakeMonitor.shared.rearm()` manually - the library handles this automatically via window lifecycle notifications

## Troubleshooting

### Debug Console Not Showing

- Ensure `AdTelemetry.initialize()` is called
- Check that debug mode is enabled: `AdTelemetry.isDebugEnabled()`
- Verify shake gesture is working (check ShakeMonitor)
- **After Full-Screen Ads**: Shake detection automatically recovers within ~1 second. If it doesn't work immediately after ad dismiss, wait a moment and try again

### Events Not Logging

- Ensure debug mode is enabled
- Check that `configure()` was called before logging
- Verify events are being logged on the correct thread
- Ensure `adId` parameter is not `nil` (or use default value from configuration)

### Ad States Not Updating

- Ensure events are being logged with valid `adId`
- Check that ad ID exists in `getAllAdIDs()` closure
- Verify configuration is set correctly

### Shake Gesture Not Working After Ad Dismiss

- **This should be automatic!** `ShakeMonitor` listens to window lifecycle notifications and auto-recovers
- If issues persist:
  - Check that `ShakeMonitor` is started (happens automatically when debug mode is enabled)
  - Verify window notifications are being fired (check with breakpoints)
  - On very slow devices, recovery may take up to 1 second - wait and try again
  - If needed, you can manually call `ShakeMonitor.shared.rearm()`, but this should rarely be necessary

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]

## Support

[Add support information here]


