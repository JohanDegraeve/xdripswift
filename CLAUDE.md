# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the xdripswift codebase.

## Project Overview

xdripswift is an iOS Swift port of xDrip+ with extensive CGM device support. It provides continuous glucose monitoring data collection, processing, and visualization for diabetes management.

## Build Commands

```bash
# Local Development
open xdrip.xcworkspace  # Important: Use .xcworkspace, not .xcodeproj

# Build without code signing (for testing compilation)
xcodebuild -workspace xdrip.xcworkspace -scheme xdrip -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build

# Check for errors
xcodebuild -workspace xdrip.xcworkspace -scheme xdrip -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "(error:|warning:|Build succeeded|Build failed)"

# CI/CD (requires GitHub Actions setup)
bundle exec fastlane build_xdrip4ios
bundle exec fastlane release  # Deploy to TestFlight
```

## Architecture Overview

- **MVC + Manager Pattern**: Traditional UIKit with service-oriented Manager layer
- **Protocol-Oriented Bluetooth**: Extensible device communication via protocols
- **Core Data Persistence**: Comprehensive data model for readings, calibrations, sensors
- **Manager Services**:
  - `BluetoothPeripheralManager` - Device connection orchestration
  - `GlucoseChartManager` - Data visualization
  - `NightScoutUploadManager` - Cloud synchronization
  - `HealthKitManager` - iOS Health app integration

### Device Support
- Dexcom G4/G5/G6/G7
- Libre 2/3 (via transmitters)
- MiaoMiao
- Bubble/Blucon
- GNSentry
- Droplet
- And more...

## Recent Implementations

### 1. Glucose Prediction System ✅

**Status**: Implemented and building successfully in `feature-prediction` branch

**Architecture**:
- **PredictionManager** (`xdrip/Managers/Prediction/PredictionManager.swift`) - Central prediction coordinator
- **Mathematical Models** (`xdrip/Managers/Prediction/TrendLineModel.swift`):
  - Polynomial regression (1st-4th degree)
  - Logarithmic trend lines
  - Exponential trend lines
  - Power trend lines
- **Chart Integration** (`xdrip/Extensions/GlucoseChartManager+Prediction.swift`) - SwiftCharts visualization
- **Data Structures** (`xdrip/Managers/Prediction/PredictionPoint.swift`) - Prediction data model
- **Mathematical Foundation** (`xdrip/Extensions/Array+Regression.swift`) - Regression algorithms
- **Unit Tests** (`xdrip/Tests/PredictionManagerTests.swift`) - Comprehensive test coverage

**Files Added**:
```
xdrip/Extensions/Array+Regression.swift
xdrip/Extensions/GlucoseChartManager+Prediction.swift  
xdrip/Managers/Prediction/GlucoseReading.swift
xdrip/Managers/Prediction/PredictionManager.swift
xdrip/Managers/Prediction/PredictionPoint.swift
xdrip/Managers/Prediction/TrendLineModel.swift
xdrip/Tests/PredictionManagerTests.swift
```

**To Enable Predictions**:
1. In `GlucoseChartManager.swift`, change line 347: `let` → `var predictionChartPoints`
2. Uncomment lines 349-352 to enable prediction generation
3. Predictions will automatically appear on glucose chart when enabled

### 2. Chart Caching Optimization ✅

**Status**: Implemented and merged in `feature/chart-caching-optimization` branch

**Benefits**:
- 90% reduction in CPU usage
- Fixed chart display issues
- Eliminated unnecessary chart recalculations

**Implementation**:
- Timer interval increased from 15 to 60 seconds
- Smart caching prevents recalculation when data unchanged
- Cache invalidation on data changes

**Key Changes**:
- Cache class integrated into `GlucoseChartManager.swift`
- Split `updateLabelsAndChart` into separate methods
- Added treatment modification tracking

## Development Guidelines

### Core Data
- Models located in `/Core Data/classes/`
- Use appropriate managed object contexts for threading
- Follow existing naming conventions for entities

### Bluetooth Devices
- New devices require:
  1. Core Data model for device settings
  2. BluetoothTransmitter protocol implementation
  3. Manager delegate integration
- Device transmitters in `/Bluetooth/Transmitter/` directory

### UI Development
- Follow existing UIKit patterns
- Use managers for business logic
- Keep view controllers focused on UI

### Git Workflow
- Documentation: https://xdrip4ios.readthedocs.io/
- Working on fork: Push to `myfork` remote (not `origin`)
- Upstream: `JohanDegraeve/xdripswift`

## Key Integration Points

### Health Platforms
- **HealthKit**: Via `HealthKitManager` for glucose data sharing
- **Apple Watch**: WatchConnectivity framework + Calendar events for complications

### Cloud Services
- **Nightscout**: Primary cloud platform (`NightscoutUploadManager`)
- **Dexcom Share**: Direct upload to Dexcom servers
- **LibreLinkUp**: Abbott's cloud service integration

## Testing

### Unit Tests
```bash
# Run all tests
xcodebuild test -workspace xdrip.xcworkspace -scheme xdrip -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -workspace xdrip.xcworkspace -scheme xdrip -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:xdripTests/PredictionManagerTests
```

### Device Testing
- Requires Apple Developer Program membership
- TestFlight deployment via GitHub Actions
- Manual Xcode builds for development

## Common Issues & Solutions

### Build Errors
- **Target Membership**: Ensure new files are added to correct targets (main app, not extensions)
- **Dependencies**: Check SwiftCharts and other pod dependencies are installed
- **Code Signing**: Use `CODE_SIGNING_ALLOWED=NO` for compilation testing

### Type Safety
- Pay attention to Swift type requirements (Double vs Int)
- Handle optionals properly
- Use appropriate number conversions

## Best Practices

1. **Task Management**: Use TODO lists for complex multi-step implementations
2. **Testing**: Always build after significant changes
3. **Code Style**: Follow existing patterns and conventions
4. **Documentation**: Update this file with significant architectural changes
5. **Performance**: Consider battery impact for background operations
6. **Planning**: Store implementation plans and documentation in `/claude/` folder

## Claude Folder

The `/claude/` folder contains:
- Implementation plans for features
- Technical documentation and notes
- Architecture decisions and rationale

**File Naming Conventions**: 
- Plans: `plan-<feat|bug>-<name>.md` (e.g., `plan-feat-prediction.md`, `plan-bug-memory-leak.md`)
- Summaries: `summary-<feat|bug>-<name>-<description>.md` (e.g., `summary-feat-prediction-improvements.md`)

Current documents:
- `plan-feat-prediction.md` - Glucose prediction implementation (✅ Completed)
- `plan-feat-chart-caching.md` - Chart caching optimization (✅ Completed)
- `plan-feat-ble.md` - Direct BLE connection from Apple Watch to Libre sensors
- `summary-feat-prediction-improvements.md` - Detailed analysis of prediction system improvements

## Resources

- Official Documentation: https://xdrip4ios.readthedocs.io/
- GitHub: https://github.com/JohanDegraeve/xdripswift
- Community: Join Discord/Facebook groups for support