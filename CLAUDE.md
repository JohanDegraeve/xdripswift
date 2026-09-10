# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Identity

xDrip4iOS (`xdripswift`) is an open-source iOS/watchOS app for real-time continuous glucose monitor (CGM) data. It operates in **Master** mode (direct BLE connection to sensors/transmitters) or **Follower** mode (remote readings from Nightscout, Dexcom Share, LibreLinkUp, CareLink, etc.). Licensed under GPL v3.0.

## Build System

- **Xcode 26**, **Swift 5**, minimum **iOS 16.2** / **watchOS 10**
- Open `xdrip.xcworkspace` (not `.xcodeproj`)
- Scheme: `xdrip` (includes Watch app, Widget, Notification Content Extension, Watch Complication Extension targets)
- No CocoaPods/SPM — all dependencies are in-repo source
- Fastlane for CI/TestFlight builds (custom fork from `loopandlearn/fastlane`, ref pinned in `Gemfile`)
- GitHub Actions workflows: `build_xdrip.yml`, `create_certs.yml`, `add_identifiers.yml`, `validate_secrets.yml`
- Config overrides via `xDripConfigOverride.xcconfig` (git-ignored, developer-edited)
- Version number in `xDrip/Version.xcconfig`

### Build Commands

```bash
# Install Ruby deps (for fastlane)
bundle install

# Build via fastlane (TestFlight deployment)
bundle exec fastlane beta

# Xcode command-line build
xcodebuild -workspace xdrip.xcworkspace -scheme xdrip -configuration Debug build

# Run tests
xcodebuild -workspace xdrip.xcworkspace -scheme xdrip -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test class
xcodebuild -workspace xdrip.xcworkspace -scheme xdrip -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:xdripTests/CalibrationReadinessTests test

# Run a single test method
xcodebuild -workspace xdrip.xcworkspace -scheme xdrip -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:xdripTests/CalibrationReadinessTests/testCalibrationNotRequiredWhenNoSensor test
```

## Target Architecture

| Target | Purpose |
|---|---|
| `xdrip` (main iOS app) | All managers, Core Data, BLE, UI |
| `xDrip Watch App` | Standalone watchOS SwiftUI app; receives data via WCSession from phone |
| `xDrip Widget` | Home/Lock Screen widgets + Live Activities + Dynamic Island |
| `xDrip Notification Context Extension` | Custom notification UI with snooze and mini-chart |
| `xDrip Watch Complication` | Watch face complications |

## High-Level Architecture (iOS Main App)

### Entry Point: `@main` SwiftUI App

`XdripApp.swift` is the `@main` entry point. It creates a `RootApplicationCoordinator` (long-lived services owner) and a `RootTabStateModel`, then renders `RootTabView` with 5 tabs: Home, Treatments, Statistics, Devices, Settings. `AppDelegate` remains only for `UIApplicationDelegate` callbacks (supported orientations, Quick Actions) that lack SwiftUI equivalents.

### Service Coordination: `RootApplicationCoordinator`

`RootApplicationCoordinator` is the application service orchestrator. It owns and starts all long-lived managers (BLE, followers, alerts, watch, widgets, health kit, nightscout, live activities, etc.). It receives transmitter/follower/notification/UserDefaults callbacks. **This is the primary file to understand the app's dependency graph.**

`RootApplicationCoordinator` populates `RootTabDependencies` — a struct holding all services needed by SwiftUI tabs — preventing views from creating duplicate manager instances.

### Presentation Pattern: State-driven SwiftUI

The app uses an **MVVM-like pattern** where:

- **State models** (`RootHomeState`, `WatchStateModel`) are plain structs/classes holding formatted presentation values
- **ViewModels** (`StatisticsViewModel`, `TreatmentsViewModel`, `BluetoothPeripheralsViewModel`, `TreatmentEditorViewModel`) are `@ObservableObject` classes that load data and publish state
- **Views** observe state models and ViewModels, never calling Core Data or BLE directly
- A `@Published` state model is pushed from `RootApplicationCoordinator` → `RootHomeStateModel` → `RootHomeView` via a timer-driven refresh cycle

### Data Layer: Core Data with Accessor Pattern

- `CoreDataManager` uses a **parent-child context** pattern: `mainManagedObjectContext` (main queue, child) → `privateManagedObjectContext` (private queue, parent with persistent store coordinator). Batch operations use `privateChildManagedObjectContext()` for background work.
- `CoreDataManager` supports an **in-memory store** init (`init(inMemoryModelName:)`) for tests.
- **Accessor classes** (`BgReadingsAccessor`, `CalibrationsAccessor`, `TreatmentEntryAccessor`, `BLEPeripheralAccessor`, etc.) are the **only** way to read/write Core Data — views/ViewModels never touch NSManagedObjectContext directly
- Accessors take `CoreDataManager` as a dependency, enabling testability
- Core Data model: `xdrip.xcdatamodeld` — key entities: `BgReading`, `Calibration`, `Sensor`, `BLEPeripheral` (+ per-type sub-entities like `DexcomG5`, `DexcomG7`, `Libre2`, `MiaoMiao`, `Bubble`, `M5Stack`), `AlertEntry`, `AlertType`, `TreatmentEntry`, `NightscoutDeviceStatusEntry`, `NightscoutProfileEntry`, `BgAdjustment`, `SensorNoiseSample`
- Automatic migration enabled (`NSMigratePersistentStoresAutomaticallyOption`, `NSInferMappingModelAutomaticallyOption`). Current model version: v27.

### Bluetooth Architecture: Two-Layer Abstraction

1. **`BluetoothPeripheral`** — Core Data-backed model representing a discovered/paired device. Protocol `BluetoothPeripheral` with per-type implementations: `CGMG5BluetoothPeripheral`, `CGMG7BluetoothPeripheral`, `CGMLibre2BluetoothPeripheral`, `CGMBubbleBluetoothPeripheral`, `CGMMiaoMiaoBluetoothPeripheral`, `M5StackBluetoothPeripheral`, `HeartBeat` peripherals
2. **`BluetoothTransmitter`** — handles the actual BLE communication protocol. Each transmitter type maps to a peripheral type: `CGMG5Transmitter`, `CGMG7Transmitter`, `CGMLibre2Transmitter`, `CGMBubbleTransmitter`, `CGMMiaoMiaoTransmitter`, `M5StackBluetoothTransmitter`, heartbeat transmitters
3. **`BluetoothPeripheralManager`** (`:BluetoothPeripheralManaging`) — central orchestrator bridging peripherals ↔ transmitters ↔ UI

### CGM Data Flow

```
BLE Transmitter → raw reading → BgPostProcessingManager (smoothing) → BgReading (Core Data) → calibrations applied → final calculatedValue
```

**Smoothing algorithms** (in `Managers/PostProcessing/Smoothing/`): Exponential, Kalman, Loess, Savitzky-Golay, Hampel+Savitzky-Golay — pluggable via `BgSmoothingAlgorithmPlugin` protocol.

### Follower Data Flow

Follower managers (Nightscout, Dexcom Share, LibreLinkUp, CareLink, Medtrum EasyView, Shared Calendar) all conform to `FollowerDelegate`. A `FollowerBackgroundKeepAliveManager` orchestrates background fetch scheduling. `NightscoutFollowManager` can also import treatments, device status, and profiles.

### Key Manager Categories

| Category | Manager(s) |
|---|---|
| **Alerts** | `AlertManager` — evaluates readings against per-minute alert entries and triggers notifications |
| **Calibration** | `DexcomCalibrator`, `Libre1Calibrator`, `Libre1NonFixedSlopeCalibrator`, `NoCalibrator` — pluggable calibration strategies |
| **Watch** | `WatchManager` — `WCSession` delegate sending state to watch app |
| **Widgets** | `WidgetSharedUserDefaultsModel` — shared App Group data for widget timelines |
| **Live Activities** | `LiveActivityManager` — manages Dynamic Island / Lock Screen live CGM updates |
| **HealthKit** | `HealthKitManager` — writes glucose readings to Apple Health |
| **Nightscout** | `NightscoutSyncManager` — uploads readings/treatments; `NightscoutFollowManager` — follower mode |
| **Charts** | `GlucoseChartStateManager`, `GlucoseChartScrollCoordinator` — chart data and scroll sync |
| **Statistics** | `StatisticsManager` — TIR, AGP, reports |
| **Sensor Health** | `SensorHealthIssueManager` — detects sensor noise, flatlines, signal issues |
| **Loop** | `LoopFollowManager`, `LoopManager` — reads/writes data for Loop/iAPS/Trio AID systems |
| **Speak** | `BGReadingSpeaker` — spoken glucose readings |
| **Quick Actions** | `QuickActionsManager` — Home Screen quick actions (3D Touch / long press) |
| **M5Stack** | `M5StackBluetoothTransmitter` — BLE output to M5Stack/M5StickC companion displays |

### Settings/Configuration Pattern

All constants live in `xdrip/Constants/` as `enum Constants*` (no magic numbers/strings). Each domain has its own file (`ConstantsGlucoseChart.swift`, `ConstantsBluetoothPairing.swift`, etc.). UserDefaults keys follow a structured pattern with enum raw values (see `UserDefaults.swift` extensions).

## Watch App Architecture

- Standalone SwiftUI app (`xDripWatchApp.swift` → `RootView`)
- Receives state exclusively via `WCSession` from the phone's `WatchManager`
- Three pages (carousel): Main chart view, AGP chart view, Big Number view
- `WatchStateModel` is the single `@EnvironmentObject` for all watch views
- Complications use `WidgetSharedUserDefaultsModel` from App Group

## Widget Architecture

- `XDripWidgetBundle` — entry point for all widget types
- Uses `WidgetSharedUserDefaultsModel` (Codable, stored in App Group UserDefaults)
- Supports: Home Screen widgets, Lock Screen widgets, StandBy, Live Activities, Dynamic Island
- `LiveActivityManager` on the phone side pushes updates to Live Activities

## Testing

Tests live in `xDrip Tests/` and use `XCTest`. No mocking framework — tests create real Core Data stacks with in-memory stores and inject dependencies through initializers. Test files are focused: `CalibrationReadinessTests`, `DexcomG6BluetoothSlotTests`, `NightscoutFollowerGapFillTests`, `SensorHealthIssueManagerTests`, `RootHomeInteractionTests`, etc.

## Localization

- `Texts/` directory contains localized string constants
- String catalogs for `.xcstrings`-based localization
- Watch app has its own `Texts/` directory for watch-specific strings

## Key Conventions

- **`OSLog` everywhere** — each class has `private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ...)`. Use `trace()` function from `Utilities/Trace.swift` for logging
- **`@MainActor`** on all ViewModels and coordinators that touch UI state
- **`ConstantsLog.subSystem`** – subsystem for all OSLog instances
- **Accessor pattern** for Core Data — no direct NSManagedObjectContext access from views
- **Protocol-based polymorphism** for transmitters (`CGMTransmitter` protocol), calibration (`Calibrator` protocol), followers (`FollowerDelegate`), smoothing (`BgSmoothingAlgorithmPlugin`)
- **KVO on UserDefaults**: `RootApplicationCoordinator` uses `observeValue(forKeyPath:)` to react to UserDefaults changes alongside SwiftUI's `@AppStorage`
- **`ApplicationManager.shared`** — singleton lifecycle hook registry; managers register closures (keyed by string) for `appDidEnterBackground`, `appWillEnterForeground`, `appWillTerminate`
- **Info.plist feature flags**: `IgnoreFollowerTypes` and `DisableLoopShare` keys control feature availability at build time
- **Custom URL scheme**: `xdripswift://` for backup import; custom UTI `com.xdripswift.backup` for `.xdripbackup` files
- **Bridging header** (`xdrip-Bridging-Header.h`) — used for Objective-C interop (Libre NFC functionality)
- Development branch: `develop`; stable releases: `master`
- Copyright holder: Johan Degraeve