# BLE Direct Connection Feature Plan

## Feature: Direct BLE Connection from Libre Sensor to Apple Watch

### Overview

Enable the Apple Watch to connect directly to Libre sensors via Bluetooth, reducing dependency on the iPhone for continuous glucose monitoring.

### Background & Research

Based on analysis of the DiaBLE project, Apple Watch can run an independent Bluetooth stack that connects directly to Libre sensors. Key findings:

- **No Watch NFC Support**: Sensor activation must occur via iPhone NFC first
- **Shared Credentials**: Watch uses pre-stored sensor UID, patch info, and unlock codes
- **Independent Operation**: Watch can operate autonomously once configured
- **Extended Runtime**: Background BLE operations using `WKExtendedRuntimeSession`

### Architecture Overview

```
┌─────────────┐    NFC     ┌─────────────┐
│   iPhone    │ ◄────────► │ Libre Sensor│
│             │            │             │
└─────────────┘            └─────────────┘
       │                          ▲
       │ WatchConnectivity         │ BLE
       │ (Share Credentials)       │
       ▼                          │
┌─────────────┐                   │
│ Apple Watch │ ◄─────────────────┘
│ (Direct BLE)│
└─────────────┘
```

### Implementation Phases

#### Phase 1: Watch Bluetooth Infrastructure (Week 1-2)

**New Files to Create:**
```
xDrip Watch App/
├── Managers/
│   ├── WatchBluetoothManager.swift      # Independent CBCentralManager
│   ├── WatchSensorManager.swift         # Sensor state coordination
│   └── WatchDataSyncManager.swift       # iPhone ↔ Watch sync
├── Extensions/
│   └── WKExtendedRuntimeSession+Extension.swift
└── Models/
    └── WatchSensorState.swift           # Watch-specific sensor data
```

**Key Components:**

```swift
// WatchBluetoothManager.swift
class WatchBluetoothManager: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    private var extendedSession: WKExtendedRuntimeSession?
    private let restoreIdentifier = "xdripswift-watch-bluetooth"
    
    func startScanning(for sensorType: SensorType) {
        // Scan for Libre service UUIDs
        let services = [CBUUID(string: "FDE3")] // Libre 2/3 service
        centralManager.scanForPeripherals(withServices: services, options: nil)
    }
    
    func connectToSensor(peripheral: CBPeripheral, credentials: SensorCredentials) {
        // Implement connection with stored unlock codes
    }
}
```

#### Phase 2: Libre Protocol Implementation (Week 2-3)

**Port Crypto Functions from DiaBLE:**

```swift
// LibreCrypto.swift - Ported from DiaBLE
struct LibreCrypto {
    static func streamingUnlockPayload(
        id: SensorUid, 
        info: PatchInfo, 
        enableTime: UInt32, 
        unlockCount: UInt16
    ) -> [UInt8] {
        // Port DiaBLE's streaming unlock implementation
    }
    
    static func decryptBLE(id: SensorUid, data: Data) throws -> Data {
        // Port DiaBLE's BLE data decryption
    }
    
    static func authenticateLibre2(
        peripheral: CBPeripheral,
        credentials: SensorCredentials
    ) async throws -> Bool {
        // Implement Libre 2 authentication state machine
    }
}
```

**Authentication State Machine:**
```swift
enum LibreAuthenticationState {
    case notAuthenticated
    case enableNotification
    case challengeResponse
    case getSessionInfo
    case authenticated
    case bleLogin
}
```

#### Phase 3: Data Synchronization (Week 3-4)

**Bidirectional Data Sync:**

```swift
// WatchDataSyncManager.swift
class WatchDataSyncManager {
    func shareSensorCredentials(_ credentials: SensorCredentials) {
        // iPhone → Watch: Share sensor UID, patch info, unlock codes
        let message = [
            "sensorUID": credentials.uid,
            "patchInfo": credentials.patchInfo,
            "unlockCode": credentials.unlockCode,
            "unlockCount": credentials.unlockCount
        ]
        wcSession.sendMessage(message, replyHandler: nil)
    }
    
    func syncGlucoseReadings(_ readings: [BgReading]) {
        // Watch → iPhone: Sync new glucose readings
        let readingsData = readings.map { $0.toDictionary() }
        wcSession.transferUserInfo(["glucoseReadings": readingsData])
    }
}
```

**Modified Files:**
- `WatchStateModel.swift` - Add direct sensor data handling
- `WatchManager.swift` - Implement bidirectional sync
- `xDrip Watch App/Views/MainView.swift` - Connection status UI

#### Phase 4: Configuration & User Interface (Week 4)

**Settings Integration:**
- Watch sensor connection preference (iPhone vs Watch priority)
- Connection status indicators
- Battery impact warnings
- Sensor activation flow UI

**User Flow:**
1. User activates sensor via iPhone NFC (existing flow)
2. iPhone shares sensor credentials with Watch
3. User chooses primary connection device in settings
4. Watch connects independently via BLE
5. Both devices can operate simultaneously with conflict resolution

### Technical Challenges & Solutions

| Challenge | Solution | Implementation |
|-----------|----------|----------------|
| No Watch NFC | iPhone activation required first | Share credentials via WatchConnectivity |
| Battery Impact | Smart connection management | Configurable scan intervals, WKExtendedRuntimeSession |
| Dual Device Conflict | Master/slave with failover | iPhone primary, Watch backup/preferred |
| Connection Reliability | Robust reconnection logic | Exponential backoff, service-specific peripheral retrieval |

### Testing Strategy

**Unit Tests:**
- Crypto function accuracy vs DiaBLE reference
- Authentication state machine transitions
- Data synchronization integrity

**Integration Tests:**
- End-to-end sensor connection flow
- Battery impact measurement over 24h periods
- Connection reliability with iPhone unavailable

**User Acceptance Tests:**
- Sensor activation flow usability
- Settings configuration clarity
- Performance comparison vs iPhone-only mode

### Timeline

**Total Duration**: 4-5 weeks

| Week | Phase | Deliverables |
|------|-------|--------------|
| 1-2 | Watch Bluetooth Infrastructure | Independent CBCentralManager operational |
| 2-3 | Libre Protocol Implementation | Authentication & data decryption working |
| 3-4 | Data Synchronization | Bidirectional iPhone ↔ Watch sync |
| 4 | Configuration & UI | Complete user configuration flow |
| 5 | Testing & Optimization | Battery optimization, reliability testing |

### Success Metrics

- Successful sensor connection rate >95%
- Battery life impact <20% increase in Watch consumption
- Data sync reliability >99% when iPhone available
- User preference for Watch connection >30% adoption

### Resource Requirements

**Development Environment:**
- Xcode 15+ with iOS 17+ SDK
- Apple Watch Series 4+ for testing (requires real Bluetooth hardware)
- iPhone 12+ with NFC capability
- Libre 2/3 sensors for testing

**Testing Resources:**
- Physical CGM sensors for end-to-end testing
- Multiple iOS/watchOS device combinations
- Extended testing periods for battery impact assessment

### Long-term Maintenance

**Code Architecture:**
- Modular design allows independent feature updates
- Protocol-based Bluetooth implementation supports future sensors

**Apple Platform Updates:**
- Watch BLE implementation may require updates for new watchOS versions
- Core Bluetooth API changes monitoring required

**Sensor Ecosystem Evolution:**
- New Libre sensor generations may require protocol updates
- Additional CGM manufacturer support extensible via existing patterns