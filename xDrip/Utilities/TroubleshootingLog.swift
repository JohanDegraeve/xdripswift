import Foundation
import UIKit

// Consumer-log pipeline:
//
//     typed fact offered by trace(...) -> signal filter -> private JSON-lines history -> report/UI
//
// The developer trace and this log deliberately meet only at the typed fact. The trace message,
// variadic arguments and Error values never move through this pipeline because the finished report
// is designed to be safe enough for a user to paste into a public support conversation.

/// Records the relative diagnostic role of a consumer-safe entry.
///
/// Standard entries describe outcomes a typical user can act on, such as a connection failure or
/// an accepted glucose reading. Detailed entries add useful supporting context, such as integration
/// failures and recoveries, imports, backfills and sensor warm-up milestones. Both levels are always
/// shown and exported. The level remains persisted so existing JSON-lines histories keep decoding and
/// call sites continue to document why a fact is useful; it is not a user-facing visibility setting.
/// Routine scans, polls and repeated successes are rejected before storage because frequency is not
/// diagnostic, even when a call site classifies the candidate as detailed.
enum TroubleshootingLogLevel: String, Codable {
    case standard
    case detailed
}

/// A closed list of glucose sources that may be named in a consumer report.
///
/// Keeping this as an enum is intentional. It prevents an account name, URL, device identifier or
/// other arbitrary source description from accidentally crossing the consumer-log privacy boundary.
enum TroubleshootingLogSource: String, Codable {
    case dexcom
    case dexcomG5
    case dexcomG6
    case dexcomOne
    case dexcomG7
    case dexcomOnePlus
    case dexcomStelo
    case miaoMiao
    case bubble
    case libre2
    case libre2EU
    case libre2PlusEU
    case medtrumNano
    case nightscout
    case libreLinkUp
    case libreLinkUpRussia
    case dexcomShare
    case medtrumEasyView
    case calendar
    case careLink

    /// Converts the persisted follower selection to its safe troubleshooting equivalent.
    init(_ followerSource: FollowerDataSourceType) {
        switch followerSource {
        case .nightscout: self = .nightscout
        case .libreLinkUp: self = .libreLinkUp
        case .libreLinkUpRussia: self = .libreLinkUpRussia
        case .dexcomShare: self = .dexcomShare
        case .medtrumEasyView: self = .medtrumEasyView
        case .calendar: self = .calendar
        case .careLink: self = .careLink
        }
    }

    /// Converts the active transmitter's controlled description into a persisted, share-safe CGM type.
    ///
    /// `CGMTransmitterType.detailedDescription()` distinguishes variants such as G5/G6/ONE and
    /// G7/ONE+/Stelo. The description is used only as a whitelist selector: it is never persisted
    /// directly, so an unexpected or user-modified string cannot enter the consumer report.
    init(
        directTransmitterType: CGMTransmitterType,
        detailedDescription: String? = nil
    ) {
        let description = detailedDescription ?? directTransmitterType.detailedDescription()

        switch directTransmitterType {
        case .dexcom:
            switch description {
            case "Dexcom G5": self = .dexcomG5
            case "Dexcom G6": self = .dexcomG6
            case "Dexcom ONE": self = .dexcomOne
            default: self = .dexcom
            }
        case .dexcomG7:
            switch description {
            case "Dexcom ONE+": self = .dexcomOnePlus
            case "Dexcom Stelo": self = .dexcomStelo
            default: self = .dexcomG7
            }
        case .miaomiao:
            self = .miaoMiao
        case .Bubble:
            self = .bubble
        case .Libre2:
            self = description == "Libre 2 Plus EU" ? .libre2PlusEU : .libre2EU
        case .medtrumTouchCareNano:
            self = .medtrumNano
        }
    }

    /// Converts a setup-screen Bluetooth choice into a safe CGM name before a device exists.
    ///
    /// The setup flow knows only a controlled peripheral type and, for Dexcom, the entered family
    /// prefix. It must never persist the transmitter ID itself. Libre 2 and Libre 2 Plus cannot be
    /// distinguished until NFC has read the sensor, so that setup choice deliberately uses the
    /// honest combined name rather than guessing the model from stale sensor information.
    init?(bluetoothPeripheralType: BluetoothPeripheralType, transmitterID: String? = nil) {
        switch bluetoothPeripheralType {
        case .DexcomType:
            switch transmitterID?.uppercased().first {
            case "4": self = .dexcomG5
            case "8": self = .dexcomG6
            case "5", "C": self = .dexcomOne
            default: self = .dexcom
            }
        case .DexcomG7Type:
            let normalizedID = transmitterID?.uppercased() ?? ""
            if normalizedID.hasPrefix("DX01") {
                self = .dexcomStelo
            } else if normalizedID.hasPrefix("DX02") {
                self = .dexcomOnePlus
            } else {
                self = .dexcomG7
            }
        case .MiaoMiaoType:
            self = .miaoMiao
        case .BubbleType:
            self = .bubble
        case .Libre2Type:
            self = .libre2
        case .MedtrumTouchCareNanoType:
            self = .medtrumNano
        case .M5StackType, .M5StickCType, .Libre3HeartBeatType,
             .DexcomG7HeartBeatType, .OmniPodHeartBeatType:
            return nil
        }
    }

    /// Stable English wording used by both the on-screen rows and exported plain text.
    var name: String {
        switch self {
        case .dexcom: return "Dexcom"
        case .dexcomG5: return "Dexcom G5"
        case .dexcomG6: return "Dexcom G6"
        case .dexcomOne: return "Dexcom ONE"
        case .dexcomG7: return "Dexcom G7"
        case .dexcomOnePlus: return "Dexcom ONE+"
        case .dexcomStelo: return "Dexcom Stelo"
        case .miaoMiao: return "MiaoMiao"
        case .bubble: return "Bubble"
        case .libre2: return "Libre 2/2+ EU"
        case .libre2EU: return "Libre 2 EU"
        case .libre2PlusEU: return "Libre 2 Plus EU"
        case .medtrumNano: return "Medtrum Nano Pump CGM"
        case .nightscout: return "Nightscout"
        case .libreLinkUp: return "LibreLinkUp"
        case .libreLinkUpRussia: return "LibreLinkUp Russia"
        case .dexcomShare: return "Dexcom Share"
        case .medtrumEasyView: return "Medtrum EasyView"
        case .calendar: return "Shared Calendar"
        case .careLink: return "CareLink"
        }
    }

    /// Only follower sources participate in download-failure recovery tracking. Direct CGMs have
    /// their connection and sensor health represented by the Bluetooth and sensor entry families.
    var isFollowerSource: Bool {
        switch self {
        case .nightscout, .libreLinkUp, .libreLinkUpRussia, .dexcomShare,
             .medtrumEasyView, .calendar, .careLink:
            return true
        case .dexcom, .dexcomG5, .dexcomG6, .dexcomOne, .dexcomG7, .dexcomOnePlus,
             .dexcomStelo, .miaoMiao, .bubble, .libre2, .libre2EU, .libre2PlusEU,
             .medtrumNano:
            return false
        }
    }
}

enum TroubleshootingAppActivity: String, Codable {
    case started
    case terminated
}

/// Bluetooth states deliberately refer only to "the configured device".
/// Peripheral names, serial numbers and transmitter identifiers must remain in developer tracing.
enum TroubleshootingBluetoothActivity: String, Codable {
    case scanning
    case connecting
    case connected
    case connectionRestored
    case disconnected
    case connectionFailed
    case connectionTimedOut
    case poweredOff
    case unauthorized
    case pairingRequested
    case pairingSucceeded
    case pairingFailed
}

/// A user-initiated Bluetooth discovery outcome for one named device.
///
/// Unlike routine connection-state events, these milestones are emitted only when an Add scan
/// either persists a genuinely new peripheral or resolves to a peripheral already stored by the
/// app. The Bluetooth name is intentionally included because it is the only useful way for a user
/// to confirm which device was selected. Normalize it before persistence so a peripheral cannot
/// inject line breaks into a copied/shared report or create an unbounded troubleshooting record.
struct TroubleshootingBluetoothDeviceName: Codable, Equatable {
    static let maximumLength = 80

    let value: String

    init?(_ rawValue: String?) {
        guard let rawValue else { return nil }

        let singleLine = rawValue
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let bounded = String(singleLine.prefix(Self.maximumLength))

        guard !bounded.isEmpty else { return nil }
        value = bounded
    }
}

enum TroubleshootingBluetoothDeviceActivity: String, Codable {
    case added
    /// Internal healthy connection candidate. The store discards it unless it proves recovery.
    case connected
    case connectionRequested
    case disconnected
    case removed
    case reconnectedToExisting
}

/// High-level actions and outcomes for the configured direct CGM.
///
/// These cases intentionally describe only things the user asked the app to do, plus the single
/// successful connection that completes that request. Routine radio connect/disconnect cycles stay
/// in developer tracing because exposing them would make a healthy Dexcom-style session look broken.
enum TroubleshootingCGMActivity: String, Codable {
    case addingStarted
    case connectionRequested
    case connected
    case disconnected
    case removed
    case nfcScanStarted
    case nfcScanSucceeded
    case nfcScanFailed
    case nfcScanCancelled
    case nfcScanTimedOut
    case nfcUnavailable
}

/// Safe follower milestones. Counts are allowed; response bodies and server errors are not.
enum TroubleshootingFollowerActivity: Codable, Equatable {
    case downloadStarted
    case loginStarted
    case loginSucceeded
    case loginFailed
    case loggedOut
    case sessionExpired
    case downloadSucceeded(readingCount: Int)
    case downloadFailed
    case noReadings
    case retryScheduled
    case recovered
}

/// Consumer-safe values for user-selected settings.
///
/// These enums intentionally duplicate a small subset of the app's settings instead of storing
/// descriptions. A translated label, patient alias or other arbitrary string must never become part
/// of a report that the user may paste into a public conversation.
enum TroubleshootingKeepAliveMode: String, Codable {
    case disabled, normal, aggressive, continuous, heartbeat

    init(_ value: FollowerBackgroundKeepAliveType) {
        switch value {
        case .disabled: self = .disabled
        case .normal: self = .normal
        case .aggressive: self = .aggressive
        case .continuous: self = .continuous
        case .heartbeat: self = .heartbeat
        }
    }

    var name: String {
        switch self {
        case .disabled: return "Disabled"
        case .normal: return "Normal"
        case .aggressive: return "Aggressive"
        case .continuous: return "Continuous"
        case .heartbeat: return "Heartbeat"
        }
    }
}

enum TroubleshootingDexcomConnectionMode: String, Codable {
    case primary, coexistence

    init(useOtherApp: Bool) {
        self = useOtherApp ? .coexistence : .primary
    }

    var name: String {
        switch self {
        case .primary: return "Primary"
        case .coexistence: return "Co-existence"
        }
    }
}

enum TroubleshootingDexcomBluetoothChannel: String, Codable {
    case mobileApp, receiverOrPump, anubisExperimental

    init(_ slot: DexcomG6BluetoothSlot) {
        switch slot {
        case .mobileApp: self = .mobileApp
        case .medicalDevice: self = .receiverOrPump
        case .anubisExperimental: self = .anubisExperimental
        }
    }

    var name: String {
        switch self {
        case .mobileApp: return "Mobile App"
        case .receiverOrPump: return "Receiver or Pump"
        case .anubisExperimental: return "Slot 3 (Anubis Experimental)"
        }
    }
}

enum TroubleshootingTherapySource: String, Codable {
    case automatic, none, nightscout, careLink

    init(_ value: TherapyDataSourceType) {
        switch value {
        case .automatic: self = .automatic
        case .none: self = .none
        case .nightscout: self = .nightscout
        case .careLink: self = .careLink
        }
    }

    var name: String {
        switch self {
        case .automatic: return "Automatic"
        case .none: return "Disabled"
        case .nightscout: return "Nightscout"
        case .careLink: return "CareLink"
        }
    }
}

enum TroubleshootingLiveActivityMode: String, Codable {
    case disabled, minimal, normal, large

    init(_ value: LiveActivityType) {
        switch value {
        case .disabled: self = .disabled
        case .minimal: self = .minimal
        case .normal: self = .normal
        case .large: self = .large
        }
    }

    var name: String { rawValue.capitalized }
}

enum TroubleshootingAIDFollowerMode: String, Codable {
    case none, loop, openAPS

    init(_ value: NightscoutFollowType) {
        switch value {
        case .none: self = .none
        case .loop: self = .loop
        case .openAPS: self = .openAPS
        }
    }

    var name: String {
        switch self {
        case .none: return "Disabled"
        case .loop: return "Loop"
        case .openAPS: return "Trio/iAPS/AAPS"
        }
    }
}

enum TroubleshootingCredentialField: String, Codable {
    case username
    case password
}

enum TroubleshootingSmoothingAlgorithm: String, Codable {
    case savitzkyGolay, exponential, kalman, loess, hampelSavitzkyGolay

    init(_ value: BgSmoothingAlgorithm) {
        self = TroubleshootingSmoothingAlgorithm(rawValue: value.rawValue) ?? .savitzkyGolay
    }

    var name: String {
        switch self {
        case .savitzkyGolay: return "Savitzky-Golay"
        case .exponential: return "Exponential"
        case .kalman: return "Kalman"
        case .loess: return "LOESS"
        case .hampelSavitzkyGolay: return "Hampel + Savitzky-Golay"
        }
    }
}

/// English, share-safe names for the three adjustment emphasis choices.
///
/// The consumer log persists this controlled enum instead of the localized UI description. This
/// keeps copied reports consistently English and prevents arbitrary presentation text crossing the
/// same privacy boundary as developer traces.
enum TroubleshootingAdjustmentEmphasis: String, Codable {
    case highs, normal, lows

    init(_ value: BgAdjustmentShapeType) {
        switch value {
        case .softerLows: self = .highs
        case .neutral: self = .normal
        case .softerHighs: self = .lows
        }
    }

    var name: String {
        switch self {
        case .highs: return "Highs"
        case .normal: return "Normal"
        case .lows: return "Lows"
        }
    }
}

enum TroubleshootingFiveMinuteReadingsMode: String, Codable {
    case enabled, disabled, notApplicable

    var name: String {
        switch self {
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        case .notApplicable: return "n/a"
        }
    }
}

/// The explicit range selected when the user applies settings in Glucose Adjustments.
/// Hours are a safe numerical setting, not a reading timestamp or other user data.
enum TroubleshootingPostProcessingApplyRange: Codable, Equatable {
    case now
    case hoursAgo(Int)
}

/// A complete snapshot of the resulting post-processing configuration.
///
/// Logging the complete state as one typed value avoids falsely claiming that BG adjustment was
/// explicitly disabled merely because the user changed smoothing. It also keeps adjustment,
/// smoothing, output cadence and the selected application range together as one understandable act.
struct TroubleshootingPostProcessingSettings: Codable, Equatable {
    let adjustmentEnabled: Bool
    let adjustmentSlope: Double?
    let adjustmentIntercept: Double?
    let adjustmentEmphasis: TroubleshootingAdjustmentEmphasis
    let smoothingEnabled: Bool
    let smoothingAlgorithm: TroubleshootingSmoothingAlgorithm
    let smoothingPeriodMinutes: Int
    let smoothingStrength: Int
    let fiveMinuteReadings: TroubleshootingFiveMinuteReadingsMode
    let applyRange: TroubleshootingPostProcessingApplyRange?
}

/// Settings and account changes that materially alter how glucose or therapy information flows.
/// No case accepts a free-form value. In particular, aliases and credentials are represented only
/// by whether they were set or removed, never by the value itself.
enum TroubleshootingConfigurationActivity: Codable, Equatable {
    case modeChanged(isMaster: Bool)
    case followerSourceChanged(TroubleshootingLogSource)
    case cgmSourceChanged(TroubleshootingLogSource)
    case cgmSourceDisconnected
    case keepAliveChanged(TroubleshootingKeepAliveMode)
    case dexcomConnectionModeChanged(TroubleshootingDexcomConnectionMode)
    case dexcomBluetoothChannelChanged(TroubleshootingDexcomBluetoothChannel)
    case therapySourceChanged(TroubleshootingTherapySource)
    case liveActivityChanged(TroubleshootingLiveActivityMode)
    case aidFollowerChanged(TroubleshootingAIDFollowerMode)
    case patientAliasChanged(isSet: Bool)
    case credentialChanged(source: TroubleshootingLogSource, field: TroubleshootingCredentialField, isSet: Bool)
    case postProcessingSettings(TroubleshootingPostProcessingSettings)
}

enum TroubleshootingDataManagementActivity: Codable, Equatable {
    case automaticCleanupChanged(enabled: Bool)
    case retentionChanged(days: Int)
    case deletionCompleted(itemCount: Int)
    case cleanupCompleted(itemCount: Int)
    case backupCreated
    case backupRestored
    case operationFailed
}

/// User changes to an individual stored glucose reading.
///
/// These are deliberately separate from bulk data-management operations. A support conversation
/// needs to distinguish a reading the app received from one the user later changed or removed.
/// Values remain canonical mg/dL and timestamps remain typed `Date` values, so this case cannot
/// carry a free-form note, Core Data identifier or other private developer-trace information.
enum TroubleshootingGlucoseManagementActivity: Codable, Equatable {
    case changed(previousMgDl: Double, updatedMgDl: Double, measuredAt: Date)
    case deleted(mgDl: Double, measuredAt: Date)
}

/// A share-safe treatment category used for explicit add/edit/delete actions.
///
/// Treatment amounts, notes, the "entered by" value and server identifiers are intentionally absent.
/// The Activity Log needs to explain that the user changed therapy data, not reproduce medical or
/// personally authored content in a report intended for public support conversations.
enum TroubleshootingTreatmentKind: String, Codable {
    case insulin
    case carbohydrates
    case exercise
    case bgCheck
    case basal
    case automaticBasal
    case siteChange
    case sensorStart
    case pumpBatteryChange
    case note

    init(_ treatmentType: TreatmentType) {
        switch treatmentType {
        case .Insulin: self = .insulin
        case .Carbs: self = .carbohydrates
        case .Exercise: self = .exercise
        case .BgCheck: self = .bgCheck
        case .Basal: self = .basal
        case .AutomaticBasal: self = .automaticBasal
        case .SiteChange: self = .siteChange
        case .SensorStart: self = .sensorStart
        case .PumpBatteryChange: self = .pumpBatteryChange
        case .Note: self = .note
        }
    }

    var name: String {
        switch self {
        case .insulin: return "Insulin"
        case .carbohydrates: return "Carbohydrate"
        case .exercise: return "Exercise"
        case .bgCheck: return "BG check"
        case .basal: return "Basal"
        case .automaticBasal: return "Automatic basal"
        case .siteChange: return "Site change"
        case .sensorStart: return "Sensor start"
        case .pumpBatteryChange: return "Pump battery change"
        case .note: return "Note"
        }
    }
}

/// A completed user change to one treatment record.
enum TroubleshootingTreatmentActivity: Codable, Equatable {
    case added(kind: TroubleshootingTreatmentKind, treatmentAt: Date)
    case edited(kind: TroubleshootingTreatmentKind, treatmentAt: Date)
    case deleted(kind: TroubleshootingTreatmentKind, treatmentAt: Date)
}

/// Controlled English status paired with the hourly sensor-noise measurements.
enum TroubleshootingSensorNoiseStatus: String, Codable {
    case collecting, low, elevated, veryHigh, extreme, flatlineSuspected

    init(_ value: SensorNoiseState) {
        switch value {
        case .collecting: self = .collecting
        case .low: self = .low
        case .elevated: self = .elevated
        case .veryHigh: self = .veryHigh
        case .extreme: self = .extreme
        case .flatlineSuspected: self = .flatlineSuspected
        }
    }

    var name: String {
        switch self {
        case .collecting: return "Collecting data"
        case .low: return "Low"
        case .elevated: return "Elevated"
        case .veryHigh: return "Very high"
        case .extreme: return "Extreme"
        case .flatlineSuspected: return "Possible flatline"
        }
    }
}

/// Share-safe traffic-light result captured when the user submits a calibration.
///
/// The Activity Log stores controlled levels rather than localized UI details. This preserves the
/// three conditions the user saw without allowing presentation text into the public support report.
enum TroubleshootingCalibrationReadinessLevel: String, Codable, Equatable {
    case good
    case caution
    case bad

    var name: String {
        switch self {
        case .good: return "green"
        case .caution: return "orange"
        case .bad: return "red"
        }
    }
}

/// Complete readiness snapshot paired with an accepted calibration.
struct TroubleshootingCalibrationReadiness: Codable, Equatable {
    let calibrationValue: TroubleshootingCalibrationReadinessLevel
    let stableTrend: TroubleshootingCalibrationReadinessLevel
    let sensorNoise: TroubleshootingCalibrationReadinessLevel
    let overall: TroubleshootingCalibrationReadinessLevel
}

/// A calculated or transmitter-reported sensor-health condition.
///
/// This is deliberately separate from the hourly `sensorNoise` measurement and configured alarm
/// delivery. It records transmitter conditions when first observed and calculated conditions when
/// activated, even when optional UI or alerts are disabled. No hardware identity is retained.
enum TroubleshootingSensorHealthAlert: String, Codable, Equatable {
    case persistentNoise
    case possibleFlatline
    case dexcomExcessNoise
    case dexcomTemporarySensorIssue
    case dexcomQuestionMarks
    case dexcomSensorFailure
    case dexcomTransmitterFailure
    case libreSensorFailure
    case dexcomTransmitterBatteryFailure
}

/// User-understandable stages of a sensor session without hardware identifiers or raw packets.
enum TroubleshootingSensorActivity: Codable, Equatable {
    case detected
    case started
    case startedWithCode(sensorCode: String)
    case warmingUp(minutesRemaining: Int)
    case stopped
    case notDetected
    case unusableReading
}

enum TroubleshootingSensorLabelScanSource: String, Codable, Equatable {
    case camera
    case photo
}

enum TroubleshootingSensorLabelScanFailure: String, Codable, Equatable {
    case cameraPermissionDenied
    case cameraUnavailable
    case malformedLabel
    case multipleValidLabels
    case noValidLabel
    case unreadableImage
}

/// A sensor-label scan result, including all decoded label information when available.
enum TroubleshootingSensorLabelScanActivity: Codable, Equatable {
    case succeeded(
        source: TroubleshootingSensorLabelScanSource,
        sensorCode: String,
        lotNumber: String,
        serialNumber: String
    )
    case failed(source: TroubleshootingSensorLabelScanSource, reason: TroubleshootingSensorLabelScanFailure)
}

/// Alert outcomes that explain user-visible behavior without copying alert text or notification data.
enum TroubleshootingAlertActivity: Codable, Equatable {
    case raised
    case scheduled(minutes: Int)
    case snoozed(minutes: Int)
    case preSnoozed(minutes: Int)
    case notificationDismissed
    case disabled
    case notificationsDenied
    case suppressedBySnooze
}

/// A closed list of optional destinations whose sharing result can be exposed safely.
enum TroubleshootingIntegration: String, Codable {
    case nightscout
    case nightscoutImport
    case nightscoutBackfill
    case healthKit
    case watch
    case liveActivity
    case calendar
    case contactImage
    case osAid

    var name: String {
        switch self {
        case .nightscout: return "Nightscout"
        case .nightscoutImport: return "Nightscout import"
        case .nightscoutBackfill: return "Nightscout backfill"
        case .healthKit: return "Apple Health"
        case .watch: return "Apple Watch"
        case .liveActivity: return "Live Activity"
        case .calendar: return "Calendar sharing"
        case .contactImage: return "Contact Image"
        case .osAid: return "OS-AID sharing"
        }
    }
}

enum TroubleshootingIntegrationActivity: Codable, Equatable {
    case started
    case succeeded(itemCount: Int?)
    case failed
    case noData
    case permissionDenied
    case restarted
    case ended
    case recovered
}

/// A deliberately small, typed description of information that is safe to show to an end user.
///
/// This type does not accept raw trace text or unbounded strings. The one deliberate device-name
/// payload is normalized and length-limited above. That typed boundary keeps developer messages,
/// hardware addresses and server responses out of reports that may be shared publicly.
enum TroubleshootingLogKind: Codable, Equatable {
    /// App lifecycle only; no scene, window or process diagnostics are retained.
    case app(TroubleshootingAppActivity)
    /// Bluetooth state without a peripheral name or identifier.
    case bluetooth(TroubleshootingBluetoothActivity)
    /// A successful user-initiated Add scan, including the bounded Bluetooth advertising name.
    case bluetoothDevice(name: TroubleshootingBluetoothDeviceName, activity: TroubleshootingBluetoothDeviceActivity)
    /// Follower activity with only a predefined source and optional reading count.
    case follower(source: TroubleshootingLogSource, activity: TroubleshootingFollowerActivity)
    /// An explicit direct-CGM action and its decisive outcome, without hardware identifiers.
    case cgm(source: TroubleshootingLogSource, activity: TroubleshootingCGMActivity)
    /// An accepted value stored canonically in mg/dL and converted only when the report is built.
    ///
    /// `measuredAt` belongs to the glucose sample, whereas `TroubleshootingLogEntry.timestamp`
    /// records when xDripswift accepted it. Keeping those clocks separate is essential: using a
    /// historical sample time as the row time can falsely place a backfill before the login or
    /// connection that actually retrieved it.
    case glucoseAccepted(
        mgDl: Double,
        source: TroubleshootingLogSource,
        measuredAt: Date
    )
    case sensor(TroubleshootingSensorActivity)
    /// A user-initiated sensor-label scan outcome with its decoded label metadata when available.
    case sensorLabelScan(TroubleshootingSensorLabelScanActivity)
    /// Hourly, bounded sensor-quality context. Values are aggregate glucose deviations only.
    case sensorNoise(shortTermMgDl: Double?, longTermMgDl: Double?, status: TroubleshootingSensorNoiseStatus)
    /// A deduplicated sensor-health condition, independent of UI and alarm delivery settings.
    case sensorHealthAlert(TroubleshootingSensorHealthAlert)
    /// Hourly aggregate reception quality without transmitter identity or packet contents.
    case transmitterReadSuccess(percent: Int, missedReadings: Int, expectedReadings: Int, windowHours: Int)
    /// An accepted calibration value and the optional guidance snapshot shown at submission time.
    ///
    /// Readiness is optional so entries written by older builds and the legacy notification prompt
    /// continue to decode without fabricating conditions the user was never shown.
    case calibrationAccepted(mgDl: Double, readiness: TroubleshootingCalibrationReadiness?)
    /// The persisted alert enum value is safe and compact; user-authored notification text is not.
    case alert(kindRawValue: Int, activity: TroubleshootingAlertActivity)
    case integration(name: TroubleshootingIntegration, activity: TroubleshootingIntegrationActivity)
    /// A real transmitter heartbeat received by the app; it contains no device identity or payload.
    case heartbeatReceived
    /// A typed user configuration change with no arbitrary or secret value.
    case configuration(TroubleshootingConfigurationActivity)
    /// Only controlled operation types and aggregate counts cross the sharing boundary.
    case dataManagement(TroubleshootingDataManagementActivity)
    /// A completed user edit or deletion of one stored glucose reading.
    case glucoseManagement(TroubleshootingGlucoseManagementActivity)
    /// A completed treatment change with no dose, note, account name or server identifier.
    case treatment(TroubleshootingTreatmentActivity)
}

/// One immutable record in the consumer troubleshooting history.
///
/// `kind` is the complete payload: there is intentionally no free-form message, metadata dictionary
/// or `Error` field. Adding one of those would allow private developer-trace data into a report that
/// users are encouraged to share publicly. Add a new typed case instead when new information is needed.
struct TroubleshootingLogEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let level: TroubleshootingLogLevel
    let kind: TroubleshootingLogKind

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: TroubleshootingLogLevel,
        kind: TroubleshootingLogKind
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.kind = kind
    }

    /// Creates a primary troubleshooting fact, such as a reading or user-visible failure.
    ///
    /// `timestamp` must always mean when the app recorded the activity. Source timestamps belong in
    /// a typed payload such as `glucoseAccepted.measuredAt`; they must never be substituted here or
    /// the Activity Log will present a false causal sequence.
    static func standard(_ kind: TroubleshootingLogKind, timestamp: Date = Date()) -> TroubleshootingLogEntry {
        TroubleshootingLogEntry(timestamp: timestamp, level: .standard, kind: kind)
    }

    /// Creates supporting diagnostic context. Both levels are now always shown and exported; the
    /// distinction remains to document call-site intent and decode histories written by older builds.
    /// The store still rejects routine timer noise regardless of this classification.
    static func detailed(_ kind: TroubleshootingLogKind, timestamp: Date = Date()) -> TroubleshootingLogEntry {
        TroubleshootingLogEntry(timestamp: timestamp, level: .detailed, kind: kind)
    }

    /// Preserves the identity, time and diagnostic level while replacing a generic healthy outcome
    /// with the more useful recovery milestone derived by the store's signal policy.
    func replacingKind(_ kind: TroubleshootingLogKind) -> TroubleshootingLogEntry {
        TroubleshootingLogEntry(id: id, timestamp: timestamp, level: level, kind: kind)
    }
}

extension Notification.Name {
    /// Posted on the main queue after the useful history changes so an open viewer can refresh.
    static let troubleshootingLogDidChange = Notification.Name("troubleshootingLogDidChange")
}

/// Stores the short consumer log separately from the developer traces.
///
/// A separate JSON-lines file means the viewer never needs to parse or temporarily load the much
/// larger developer traces. All file access is serialized so calls to `trace` from Bluetooth,
/// networking and UI threads cannot race each other. The append path is intentionally asynchronous:
/// troubleshooting persistence must never delay glucose processing or change app behavior.
final class TroubleshootingLogStore {
    static let shared = TroubleshootingLogStore()

    /// These are privacy and usability limits, not developer-trace rotation settings. Whichever cap
    /// is reached first wins, and pruning always removes the oldest records before newer context.
    // Twenty-four hours gives support conversations enough context to include an overnight period.
    // Five thousand entries accommodates 2,880 half-minute heartbeats plus 1,440 one-minute glucose
    // readings with room for lifecycle and failure rows. The 1 MiB byte cap remains a firm safety
    // boundary even if a future typed record encodes less compactly than today's entries.
    static let retentionPeriod: TimeInterval = 24 * 60 * 60
    static let maximumEntryCount = 5_000
    static let maximumFileSize = 1_024 * 1_024
    static let hourlyDiagnosticInterval: TimeInterval = 60 * 60

    private let fileURL: URL
    private let retentionPeriod: TimeInterval
    private let maximumEntryCount: Int
    private let maximumFileSize: Int
    private let now: () -> Date
    private let queue = DispatchQueue(label: "com.faifly.xdrip.troubleshooting-log", qos: .utility)

    /// Tracks whether an operational subsystem has an unresolved problem while replaying history.
    /// It is local to the filtering pass and is never persisted as a second source of truth.
    private enum OperationalHealthState {
        case healthy
        case problem
    }

    /// Authentication is tracked separately from download health. A valid session may sign in once
    /// and then download for hours, while a failed download does not necessarily mean sign-in failed.
    private enum AuthenticationState {
        case signingIn
        case loggedIn
        case failed
        case loggedOut
    }

    /// Both cache fields are queue-confined. Accessing them anywhere except `queue` would reintroduce
    /// races between Bluetooth callbacks, network completions and UI lifecycle tracing.
    private var cachedEntries: [TroubleshootingLogEntry]?
    private var cachedByteCount = 0
    /// A failed append or rewrite leaves the current-session cache useful but means the next
    /// successful storage opportunity must replace the whole file rather than append to stale data.
    private var persistenceNeedsRewrite = false

    /// The consumer history lives under Application Support rather than beside the e-mail trace
    /// attachments in Documents. This keeps the two retention policies and sharing paths independent.
    convenience init() {
        let fileManager = FileManager.default
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = applicationSupport.appendingPathComponent("Troubleshooting", isDirectory: true)
        self.init(fileURL: directory.appendingPathComponent("troubleshooting-log.jsonl"))
    }

    /// Dependency-injected limits, clock and URL make retention, corruption and write-failure behavior
    /// testable without changing production defaults or waiting for wall-clock time to pass.
    init(
        fileURL: URL,
        retentionPeriod: TimeInterval = TroubleshootingLogStore.retentionPeriod,
        maximumEntryCount: Int = TroubleshootingLogStore.maximumEntryCount,
        maximumFileSize: Int = TroubleshootingLogStore.maximumFileSize,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.retentionPeriod = retentionPeriod
        self.maximumEntryCount = maximumEntryCount
        self.maximumFileSize = maximumFileSize
        self.now = now
    }

    /// Queues filtering and persistence, then returns immediately.
    ///
    /// A candidate may be discarded as routine noise or converted into a single recovery milestone.
    /// Consumer logging must never delay glucose handling, Bluetooth callbacks or the developer trace
    /// call that offered the candidate.
    func record(_ entry: TroubleshootingLogEntry) {
        queue.async { [weak self] in
            self?.recordOnQueue(entry)
        }
    }

    /// A synchronous snapshot waits behind already queued writes, giving Copy and Share a complete
    /// report without making every trace call synchronous. The returned order is newest first.
    func snapshot() -> [TroubleshootingLogEntry] {
        queue.sync {
            prepareCacheOnQueue()
            pruneAndRewriteIfNeededOnQueue()
            // Later appends win ties. A recovery derived from the same accepted reading shares its
            // recording timestamp, and deterministic ordering keeps UI, Copy and Share identical.
            return (cachedEntries ?? []).enumerated().sorted {
                if $0.element.timestamp == $1.element.timestamp {
                    return $0.offset > $1.offset
                }
                return $0.element.timestamp > $1.element.timestamp
            }.map(\.element)
        }
    }

    private func recordOnQueue(_ entry: TroubleshootingLogEntry) {
        prepareCacheOnQueue()
        let previousEntries = cachedEntries ?? []
        let pruned = prunedEntries(previousEntries + [entry], referenceDate: now())

        // A routine healthy outcome or a repeated problem may add no new information. In that case
        // leave both memory and disk untouched, and do not make an open viewer redraw needlessly.
        guard pruned != previousEntries else { return }

        cachedEntries = pruned

        let appendedEntryWithoutTransformation = pruned.count == previousEntries.count + 1
            && Array(pruned.dropLast()) == previousEntries
            && pruned.last == entry
        let encodedLine = encodeLine(entry)

        // The cheap append path is safe only when policy accepted exactly the supplied entry. A
        // recovery can replace a generic success, and retention can remove older entries; both cases
        // require an atomic rewrite so the file remains identical to the in-memory history.
        let persistenceSucceeded: Bool
        if persistenceNeedsRewrite
            || !appendedEntryWithoutTransformation
            || encodedLine == nil
            || cachedByteCount + (encodedLine?.count ?? 0) > maximumFileSize {
            persistenceSucceeded = rewriteOnQueue(pruned)
        } else if let encodedLine {
            persistenceSucceeded = appendOnQueue(encodedLine)
        } else {
            persistenceSucceeded = false
        }
        persistenceNeedsRewrite = !persistenceSucceeded

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .troubleshootingLogDidChange, object: self)
        }
    }

    private func prepareCacheOnQueue() {
        guard cachedEntries == nil else { return }
        ensureParentDirectoryOnQueue()

        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            cachedEntries = []
            cachedByteCount = 0
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var decodedEntries = [TroubleshootingLogEntry]()
        var foundMalformedLine = false
        var foundLegacyNullPadding = false

        // An interrupted append can leave one incomplete final line. Ignore any malformed line and
        // rewrite the valid records rather than making the entire troubleshooting history unreadable.
        // Early versions accidentally wrote a null byte after each newline. Strip only that known
        // leading padding from each split record, then rewrite immediately in the corrected format.
        for line in data.split(separator: 0x0A) where !line.isEmpty {
            let cleanedLine = line.drop(while: { $0 == 0 })
            if cleanedLine.count != line.count {
                foundLegacyNullPadding = true
            }
            guard !cleanedLine.isEmpty else { continue }

            do {
                decodedEntries.append(try decoder.decode(TroubleshootingLogEntry.self, from: Data(cleanedLine)))
            } catch {
                foundMalformedLine = true
            }
        }

        let pruned = prunedEntries(decodedEntries, referenceDate: now())
        cachedEntries = pruned
        cachedByteCount = data.count

        if foundMalformedLine
            || foundLegacyNullPadding
            || pruned.count != decodedEntries.count
            || data.count > maximumFileSize {
            persistenceNeedsRewrite = !rewriteOnQueue(pruned)
        }
    }

    private func pruneAndRewriteIfNeededOnQueue() {
        let entries = cachedEntries ?? []
        let pruned = prunedEntries(entries, referenceDate: now())
        if pruned != entries {
            cachedEntries = pruned
        }
        guard persistenceNeedsRewrite || pruned != entries else { return }
        persistenceNeedsRewrite = !rewriteOnQueue(pruned)
    }

    private func prunedEntries(
        _ entries: [TroubleshootingLogEntry],
        referenceDate: Date
    ) -> [TroubleshootingLogEntry] {
        // Apply age and signal quality before count and encoded-size limits. This prevents a fast
        // polling source from evicting useful glucose, failure and recovery records with timer noise.
        let cutoff = referenceDate.addingTimeInterval(-retentionPeriod)
        let usefulEntries = signalFilteredEntries(entries.filter { $0.timestamp >= cutoff })
        let ageAndCountLimited = Array(usefulEntries.suffix(maximumEntryCount))

        var byteCount = 0
        var sizeLimitedReversed = [TroubleshootingLogEntry]()
        for entry in ageAndCountLimited.reversed() {
            guard let line = encodeLine(entry), byteCount + line.count <= maximumFileSize else { break }
            sizeLimitedReversed.append(entry)
            byteCount += line.count
        }
        return sizeLimitedReversed.reversed()
    }

    /// Removes timer noise and converts the first healthy outcome after a problem into a recovery.
    ///
    /// This policy is deliberately centralized rather than copied into every follower and sharing
    /// manager. Those systems run at very different cadences, but the consumer question is the same:
    /// did something fail, did it recover, and were readings still accepted? Replaying the policy over
    /// the file also upgrades an existing noisy 24-hour history after an app update.
    private func signalFilteredEntries<S: Sequence>(_ entries: S) -> [TroubleshootingLogEntry]
    where S.Element == TroubleshootingLogEntry {
        var followerHealth = [TroubleshootingLogSource: OperationalHealthState]()
        var authenticationState = [TroubleshootingLogSource: AuthenticationState]()
        var integrationHealth = [TroubleshootingIntegration: OperationalHealthState]()
        var lastIntegrationSuccessAt = [TroubleshootingIntegration: Date]()
        var bluetoothHealth = OperationalHealthState.healthy
        var pendingBluetoothConnectionName: TroubleshootingBluetoothDeviceName?
        var pendingCGMConnection: TroubleshootingLogSource?
        var lastAppActivity: TroubleshootingAppActivity?
        var lastSensorActivity: TroubleshootingSensorActivity?
        var lastSensorNoiseAt: Date?
        var lastTransmitterReadSuccessAt: Date?
        var lastAlertActivity = [Int: TroubleshootingAlertActivity]()
        var notificationPermissionProblemRecorded = false
        var result = [TroubleshootingLogEntry]()

        // Preserve append order while applying stateful noise reduction. Entry timestamps always
        // describe when the app recorded the activity; sample measurement time is payload data only.
        for entry in entries {
            switch entry.kind {
            case let .app(activity):
                // Foreground/background transitions are deliberately absent from the typed model.
                // They occur during ordinary phone use and displaced useful readings and failures.
                switch activity {
                case .started:
                    // Preserve every launch. `Trace.initialize` offers this fact only once per
                    // process, so two consecutive starts represent two real app processes. iOS does
                    // not guarantee `applicationWillTerminate` when the user force-closes the app,
                    // the system evicts it, or it stops while suspended. Requiring an intervening
                    // `.terminated` record therefore erased exactly the restart information that is
                    // most useful when investigating a gap in follower readings.
                    result.append(entry)
                    lastAppActivity = activity
                case .terminated:
                    // A termination callback is useful when iOS supplies it, but duplicate callback
                    // delivery within one process adds no context. Its absence must never affect
                    // whether the next process launch is retained.
                    guard lastAppActivity != .terminated else { continue }
                    result.append(entry)
                    lastAppActivity = activity
                }

            case let .bluetooth(activity):
                switch activity {
                case .scanning, .connecting, .disconnected:
                    // These are normal parts of many CGM connection cycles and do not explain a fault.
                    continue
                case .connected:
                    // A generic device (for example, a display or heartbeat peripheral) may connect
                    // while the user is adding a CGM. Never let that unrelated callback complete the
                    // pending CGM action; actual CGM connections arrive through the typed case below.
                    guard bluetoothHealth == .problem else { continue }
                    result.append(entry.replacingKind(.bluetooth(.connectionRestored)))
                    bluetoothHealth = .healthy
                case .connectionRestored:
                    guard bluetoothHealth == .problem else { continue }
                    result.append(entry)
                    bluetoothHealth = .healthy
                case .connectionFailed, .connectionTimedOut, .poweredOff, .unauthorized:
                    guard bluetoothHealth != .problem else { continue }
                    result.append(entry)
                    bluetoothHealth = .problem
                case .pairingRequested, .pairingSucceeded, .pairingFailed:
                    // The producer already throttles duplicate callbacks for one system prompt.
                    // Every candidate that reaches the store is therefore a real prompt or outcome
                    // the user may have acted on, and must remain independently visible.
                    result.append(entry)
                }

            case let .bluetoothDevice(name, activity):
                switch activity {
                case .added, .reconnectedToExisting:
                    // These are discrete outcomes of an explicit Add scan.
                    result.append(entry)
                case .connectionRequested:
                    // A saved non-CGM device was explicitly enabled by the user. Retain the action
                    // and let the next matching healthy connection provide its decisive outcome.
                    result.append(entry)
                    pendingBluetoothConnectionName = name
                case .connected:
                    // Every ordinary connection cycle may offer this named candidate. Retain it
                    // only when it completes the user's matching Connect action or proves recovery
                    // from a visible failure; all healthy heartbeat cycles remain suppressed.
                    if pendingBluetoothConnectionName == name {
                        result.append(entry)
                        pendingBluetoothConnectionName = nil
                        bluetoothHealth = .healthy
                    } else if bluetoothHealth == .problem {
                        result.append(entry.replacingKind(.bluetoothDevice(
                            name: name,
                            activity: .reconnectedToExisting
                        )))
                        bluetoothHealth = .healthy
                    }
                case .disconnected, .removed:
                    // These candidates exist only at confirmed user-action boundaries in the UI.
                    result.append(entry)
                    if pendingBluetoothConnectionName == name {
                        pendingBluetoothConnectionName = nil
                    }
                }

            case let .cgm(source, activity):
                switch activity {
                case .addingStarted, .connectionRequested:
                    // These are explicit button actions. The next typed CGM `.connected` candidate
                    // becomes the one useful completion row. Keeping the source here also avoids
                    // inspecting an arbitrary CoreBluetooth peripheral name later.
                    result.append(entry)
                    pendingCGMConnection = source
                case .connected:
                    // CGMs such as Dexcom may make a healthy connection for every reading. Retain the
                    // connection only when it completes the user's pending Add/Connect action, or when
                    // it proves recovery from a previously retained Bluetooth failure. Use the pending
                    // source for the first case because it was derived from the user's exact setup
                    // choice before a new transmitter had enough data to describe itself.
                    if let pendingSource = pendingCGMConnection {
                        result.append(entry.replacingKind(.cgm(source: pendingSource, activity: .connected)))
                        pendingCGMConnection = nil
                        bluetoothHealth = .healthy
                    } else if bluetoothHealth == .problem {
                        result.append(entry.replacingKind(.bluetooth(.connectionRestored)))
                        bluetoothHealth = .healthy
                    }
                case .disconnected, .removed:
                    // A confirmed Disconnect/Delete action is not the same as the transmitter's
                    // normal between-reading radio disconnect, so every user action remains visible.
                    result.append(entry)
                    pendingCGMConnection = nil
                case .nfcScanStarted, .nfcScanSucceeded:
                    // One NFC session has one start and one outcome. Retries are separate actions and
                    // are useful when explaining why Libre Bluetooth streaming never began.
                    result.append(entry)
                case .nfcScanFailed, .nfcScanCancelled, .nfcScanTimedOut, .nfcUnavailable:
                    // An unsuccessful NFC session ends this Add/Connect attempt. Clearing the pending
                    // source is essential: a later connection from some other configured CGM must not
                    // be misreported as the completion of the abandoned Libre action.
                    result.append(entry)
                    pendingCGMConnection = nil
                }

            case let .follower(source, activity):
                switch activity {
                case .downloadStarted, .noReadings, .retryScheduled:
                    // Polling and empty responses are expected between readings. Their repetition says
                    // nothing about whether the app eventually accepted fresh glucose information.
                    continue
                case .loginStarted:
                    // Preserve the start of a real sign-in attempt but collapse duplicate callbacks
                    // from the same attempt into a single user-understandable row.
                    guard authenticationState[source] != .signingIn else { continue }
                    result.append(entry)
                    authenticationState[source] = .signingIn
                case .loginSucceeded:
                    // A success is useful after launch, an explicit attempt or a failure. Repeated
                    // token/session checks while already signed in add no troubleshooting value.
                    guard authenticationState[source] != .loggedIn else { continue }
                    result.append(entry)
                    authenticationState[source] = .loggedIn
                case .loggedOut:
                    guard authenticationState[source] != .loggedOut else { continue }
                    result.append(entry)
                    authenticationState[source] = .loggedOut
                case .downloadSucceeded:
                    guard followerHealth[source] == .problem else { continue }
                    result.append(entry.replacingKind(.follower(source: source, activity: .recovered)))
                    followerHealth[source] = .healthy
                case .recovered:
                    guard followerHealth[source] == .problem else { continue }
                    result.append(entry)
                    followerHealth[source] = .healthy
                case .loginFailed:
                    authenticationState[source] = .failed
                    guard followerHealth[source] != .problem else { continue }
                    result.append(entry)
                    followerHealth[source] = .problem
                case .sessionExpired:
                    authenticationState[source] = .signingIn
                    guard followerHealth[source] != .problem else { continue }
                    result.append(entry)
                    followerHealth[source] = .problem
                case .downloadFailed:
                    guard followerHealth[source] != .problem else { continue }
                    result.append(entry)
                    followerHealth[source] = .problem
                }

            case let .glucoseAccepted(_, source, _):
                // An accepted follower reading is stronger evidence of recovery than a successful HTTP
                // status. Record that transition once, then retain the reading itself without suppression.
                if source.isFollowerSource, followerHealth[source] == .problem {
                    result.append(entry.replacingKind(.follower(source: source, activity: .recovered)))
                    followerHealth[source] = .healthy
                }
                result.append(entry)

            case let .sensor(activity):
                guard shouldKeepSensorActivity(activity, after: lastSensorActivity) else { continue }
                result.append(entry)
                lastSensorActivity = activity

            case .sensorLabelScan:
                // Each result belongs to an explicit camera or photo action and is useful even when
                // the preceding attempt had the same outcome.
                result.append(entry)

            case .sensorNoise:
                // Noise is calculated for the developer trace every ten minutes. One consumer row
                // per hour preserves the trend without allowing this periodic metric to overwhelm
                // readings and actual state changes. Replaying the policy also enforces the cadence
                // across app relaunches rather than relying on an in-memory timer.
                if let lastSensorNoiseAt,
                   entry.timestamp.timeIntervalSince(lastSensorNoiseAt) < Self.hourlyDiagnosticInterval {
                    continue
                }
                result.append(entry)
                lastSensorNoiseAt = entry.timestamp

            case .sensorHealthAlert:
                // SensorHealthIssueManager emits this only when a transmitter condition is first
                // observed or a calculated episode is activated. Never apply the hourly metric
                // throttle here: the state transition is meaningful even when a nearby noise
                // measurement was retained or external presentation remains intentionally delayed.
                result.append(entry)

            case .transmitterReadSuccess:
                // The producer already calculates this at most hourly. Keep the store-side boundary
                // as well so force-closing and reopening the app cannot create several near-identical
                // reception summaries inside one hour.
                if let lastTransmitterReadSuccessAt,
                   entry.timestamp.timeIntervalSince(lastTransmitterReadSuccessAt) < Self.hourlyDiagnosticInterval {
                    continue
                }
                result.append(entry)
                lastTransmitterReadSuccessAt = entry.timestamp

            case let .alert(kindRawValue, activity):
                switch activity {
                case .notificationsDenied:
                    // Notification permission is app-wide, so one record explains every affected
                    // alert. Repeating the same sentence once per alert type adds no diagnostic value.
                    guard !notificationPermissionProblemRecorded else { continue }
                    result.append(entry)
                    notificationPermissionProblemRecorded = true
                case .scheduled:
                    // Alert evaluation may update the countdown frequently. Keep the first schedule
                    // after a different state, then wait for a raise or an explicit snooze.
                    if case .scheduled? = lastAlertActivity[kindRawValue] { continue }
                    result.append(entry)
                    lastAlertActivity[kindRawValue] = activity
                case .raised:
                    // Rechecking an already active alert is not a second user-visible occurrence.
                    if case .raised? = lastAlertActivity[kindRawValue] { continue }
                    result.append(entry)
                    lastAlertActivity[kindRawValue] = activity
                case .snoozed:
                    // Snooze is an explicit user action. Preserve every action, even if the same
                    // duration is chosen twice, and allow a later schedule/raise to be shown again.
                    result.append(entry)
                    lastAlertActivity[kindRawValue] = activity
                case .preSnoozed:
                    // A pre-snooze is meaningful configuration, whether selected in Snooze settings
                    // or applied automatically after calibration. Preserve its actual duration.
                    result.append(entry)
                    lastAlertActivity[kindRawValue] = activity
                case .notificationDismissed:
                    // iOS reports this only for categories using `customDismissAction`. It is an
                    // explicit user interaction, so retain each dismissal rather than deduplicating it.
                    result.append(entry)
                    lastAlertActivity[kindRawValue] = activity
                case .disabled:
                    // The condition still occurred even though configuration prevented delivery.
                    // Collapse repeated evaluations until this alert reaches another state.
                    if case .disabled? = lastAlertActivity[kindRawValue] { continue }
                    result.append(entry)
                    lastAlertActivity[kindRawValue] = activity
                case .suppressedBySnooze:
                    // The same condition can be evaluated on every reading during a snooze. One row
                    // explains the suppression until this alert reaches a different state.
                    if case .suppressedBySnooze? = lastAlertActivity[kindRawValue] { continue }
                    result.append(entry)
                    lastAlertActivity[kindRawValue] = activity
                }

            case let .integration(name, activity):
                if name == .nightscoutBackfill {
                    // A gap check normally starts and finds nothing. Persisting both bookends on every
                    // launch hides the lifecycle and glucose facts the report is meant to explain.
                    // Keep a start only while it has no outcome; completion replaces it with one useful
                    // result, and an empty healthy check disappears. Replaying this policy also cleans
                    // the noisy start/no-data pairs written by earlier builds.
                    if let startIndex = result.lastIndex(where: {
                        guard case .integration(.nightscoutBackfill, .started) = $0.kind else { return false }
                        return true
                    }), activity != .started {
                        result.remove(at: startIndex)
                    }

                    switch activity {
                    case .started:
                        guard !result.contains(where: {
                            guard case .integration(.nightscoutBackfill, .started) = $0.kind else { return false }
                            return true
                        }) else { continue }
                        result.append(entry)
                    case .noData:
                        guard integrationHealth[name] == .problem else { continue }
                        result.append(entry.replacingKind(.integration(name: name, activity: .recovered)))
                        integrationHealth[name] = .healthy
                    case let .succeeded(itemCount):
                        guard itemCount.map({ $0 > 0 }) ?? true else {
                            if integrationHealth[name] == .problem {
                                result.append(entry.replacingKind(.integration(name: name, activity: .recovered)))
                                integrationHealth[name] = .healthy
                            }
                            continue
                        }
                        result.append(entry)
                        integrationHealth[name] = .healthy
                    case .failed, .permissionDenied:
                        guard integrationHealth[name] != .problem else { continue }
                        result.append(entry)
                        integrationHealth[name] = .problem
                    case .recovered:
                        guard integrationHealth[name] == .problem else { continue }
                        result.append(entry)
                        integrationHealth[name] = .healthy
                    case .restarted, .ended:
                        result.append(entry)
                    }
                    continue
                }

                if name == .nightscoutImport {
                    // A user-requested historical import is exceptional and may be long-running. Its
                    // start and final item count explain why many old records can appear together.
                    result.append(entry)
                    continue
                }

                switch activity {
                case .started, .noData:
                    continue
                case .succeeded:
                    if integrationHealth[name] == .problem {
                        result.append(entry.replacingKind(.integration(name: name, activity: .recovered)))
                    } else {
                        // Healthy customer-facing integrations can update every reading. Retain one
                        // success per hour as evidence that background work is alive, while failures
                        // and recoveries below remain immediate and unthrottled.
                        if let lastSuccess = lastIntegrationSuccessAt[name],
                           entry.timestamp.timeIntervalSince(lastSuccess) < Self.hourlyDiagnosticInterval {
                            continue
                        }
                        result.append(entry)
                    }
                    integrationHealth[name] = .healthy
                    lastIntegrationSuccessAt[name] = entry.timestamp
                case .recovered:
                    guard integrationHealth[name] == .problem else { continue }
                    result.append(entry)
                    integrationHealth[name] = .healthy
                    lastIntegrationSuccessAt[name] = entry.timestamp
                case .failed, .permissionDenied:
                    guard integrationHealth[name] != .problem else { continue }
                    result.append(entry)
                    integrationHealth[name] = .problem
                case .restarted, .ended:
                    result.append(entry)
                }

            case .calibrationAccepted:
                // Each calibration is a discrete user action and must remain independently visible.
                result.append(entry)

            case .heartbeatReceived, .configuration, .dataManagement, .glucoseManagement, .treatment:
                // Each heartbeat is evidence that the transmitter/app link was alive at that moment.
                // Configuration, reading-management and treatment rows are explicit user changes.
                // None is timer-derived polling noise, so every occurrence is meaningful and retained
                // independently. In particular, never deduplicate two deletions with the same value:
                // they can refer to different reading timestamps.
                result.append(entry)
            }
        }

        return result
    }

    /// Warm-up checks can run for every sensor response. Keep only quarter-hour milestones while
    /// preserving every transition into or out of warm-up and every other sensor lifecycle fact.
    private func shouldKeepSensorActivity(
        _ activity: TroubleshootingSensorActivity,
        after previous: TroubleshootingSensorActivity?
    ) -> Bool {
        let isSessionStart: (TroubleshootingSensorActivity?) -> Bool = { activity in
            switch activity {
            case .detected?, .started?, .startedWithCode?: return true
            default: return false
            }
        }

        // A manual Start action is recorded immediately, and some transmitters subsequently report
        // the same lifecycle transition as "new sensor detected". They use different typed cases so
        // their English can remain precise, but they are one session start and must produce one row.
        if isSessionStart(activity), isSessionStart(previous) {
            return false
        }

        guard case let .warmingUp(minutes) = activity,
              case let .warmingUp(previousMinutes) = previous else {
            return activity != previous
        }
        let milestone = max(0, minutes + 14) / 15
        let previousMilestone = max(0, previousMinutes + 14) / 15
        return milestone != previousMilestone
    }

    private func encodeLine(_ entry: TroubleshootingLogEntry) -> Data? {
        // One JSON object per line lets reload salvage every complete record if the process is
        // suspended during an append. ISO-8601 avoids locale-dependent persistence.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard var data = try? encoder.encode(entry) else { return nil }
        // Force a single-byte newline. An untyped integer literal can select Data's generic append
        // overload and write the integer's trailing null byte, corrupting the next JSON record.
        data.append(UInt8(0x0A))
        return data
    }

    private func ensureParentDirectoryOnQueue() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var values = URLResourceValues()
        // The history is short-lived support data that can be regenerated; it must not consume the
        // user's iCloud backup allowance or unexpectedly survive through a backup restore.
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(values)
    }

    @discardableResult
    private func appendOnQueue(_ data: Data) -> Bool {
        ensureParentDirectoryOnQueue()
        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try Data().write(to: fileURL, options: .atomic)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            cachedByteCount += data.count
            applyFileProtectionOnQueue()
            return true
        } catch {
            // Never call trace here: doing so would recurse back into this store. The failure is
            // deliberately isolated from the glucose or networking operation that created the entry.
            debuglogging("failed to append troubleshooting log")
            return false
        }
    }

    @discardableResult
    private func rewriteOnQueue(_ entries: [TroubleshootingLogEntry]) -> Bool {
        ensureParentDirectoryOnQueue()
        let data = entries.compactMap(encodeLine).reduce(into: Data()) { $0.append($1) }
        do {
            try data.write(to: fileURL, options: .atomic)
            cachedByteCount = data.count
            applyFileProtectionOnQueue()
            return true
        } catch {
            // Keep the in-memory cache useful for the current session even if disk is unavailable.
            debuglogging("failed to rewrite troubleshooting log")
            return false
        }
    }

    private func applyFileProtectionOnQueue() {
        // Background glucose work can continue after the first unlock, while iOS still protects the
        // file across device restarts until the user has authenticated.
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path
        )
    }
}

/// A fresh, human-readable snapshot of non-secret app configuration placed above every report.
///
/// This information is generated when the viewer reloads and is never written to the JSON-lines
/// history. It intentionally omits the build number, account details, endpoint URLs and hardware IDs.
struct TroubleshootingLogAppInfo: Equatable {
    /// Stable source-project identity used as the report title. `appName` remains separate because
    /// the installed target's bundle display name can intentionally use different branding and
    /// support still needs to identify that exact app.
    let projectName: String
    let appName: String
    let version: String
    let deviceClass: String
    let systemVersion: String
    let modeDescription: String
    let dataSourceDescription: String
    let dexcomBluetoothChannelDescription: String?
    let unitDescription: String
    let keepAliveDescription: String?
    let processingLines: [String]
    let integrationLines: [String]

    /// Reads current settings so a report reflects configuration changes made after older entries.
    static func current(
        defaults: UserDefaults = .standard,
        currentSourceCanUseFiveMinuteReadings: Bool? = nil,
        dexcomBluetoothChannel: TroubleshootingDexcomBluetoothChannel? = nil
    ) -> TroubleshootingLogAppInfo {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let deviceClass = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let modeDescription: String
        let dataSourceDescription: String
        let keepAliveDescription: String?

        if defaults.isMaster {
            modeDescription = "Master"
            dataSourceDescription = defaults.activeSensorDescription ?? defaults.cgmTransmitterTypeAsString ?? "Direct sensor"
            keepAliveDescription = nil
        } else {
            modeDescription = "Follower"
            dataSourceDescription = TroubleshootingLogSource(defaults.followerDataSourceType).name

            // The troubleshooting report is intentionally English even when the app UI is using
            // another language, so pasted reports have one predictable support vocabulary.
            switch defaults.followerBackgroundKeepAliveType {
            case .disabled: keepAliveDescription = "Disabled"
            case .normal: keepAliveDescription = "Normal"
            case .aggressive: keepAliveDescription = "Aggressive"
            case .continuous: keepAliveDescription = "Continuous"
            case .heartbeat: keepAliveDescription = "Bluetooth heartbeat"
            }
        }

        // These high-level flags are added only to copied and shared reports. They describe which
        // destinations should receive data, not the credentials, calendars, sites or devices behind
        // them, and they are intentionally omitted from the on-screen activity history.
        let nightscoutUploadsEnabled = defaults.nightscoutEnabled
            && (defaults.isMaster ? defaults.masterUploadDataToNightscout : defaults.followerUploadDataToNightscout)
        let osAidDescription: String
        switch defaults.loopShareType {
        case .disabled: osAidDescription = "Disabled"
        case .loop: osAidDescription = "Loop"
        case .trio: osAidDescription = "Trio"
        }

        let smoothingDescription: String
        if defaults.enableSmoothing {
            smoothingDescription = "\(TroubleshootingSmoothingAlgorithm(defaults.bgSmoothingAlgorithm).name), strength \(defaults.bgSmoothingStrength), \(defaults.bgSmoothingPeriodInMinutes)-minute period"
        } else {
            smoothingDescription = "None"
        }

        // Prefer the post-processing manager's reading-based cadence result. This matters for
        // Nightscout in particular: the provider name cannot tell us whether the configured site is
        // forwarding one-minute or five-minute readings. The controlled-name fallback exists only
        // for tests and previews that construct this value without the app's Core Data dependencies.
        let fiveMinuteReadingsAreNotApplicable: Bool
        if let currentSourceCanUseFiveMinuteReadings {
            fiveMinuteReadingsAreNotApplicable = !currentSourceCanUseFiveMinuteReadings
        } else if defaults.isMaster {
            let source = (defaults.activeSensorDescription ?? defaults.cgmTransmitterTypeAsString ?? "").lowercased()
            fiveMinuteReadingsAreNotApplicable = source.contains("dexcom")
        } else {
            fiveMinuteReadingsAreNotApplicable = [.dexcomShare, .careLink].contains(defaults.followerDataSourceType)
        }
        let fiveMinuteDescription = fiveMinuteReadingsAreNotApplicable
            ? "n/a"
            : (defaults.useFiveMinuteReadings ? "Enabled" : "Disabled")

        return TroubleshootingLogAppInfo(
            // Keep the installed branding separate from the stable project title. This identifies
            // both the originating project and the exact branded app without repeating either line.
            projectName: ConstantsHomeView.gitHubRepositoryName,
            appName: ConstantsHomeView.applicationName,
            version: version,
            deviceClass: deviceClass,
            systemVersion: UIDevice.current.systemVersion,
            modeDescription: modeDescription,
            dataSourceDescription: dataSourceDescription,
            dexcomBluetoothChannelDescription: dexcomBluetoothChannel?.name,
            unitDescription: defaults.bloodGlucoseUnitIsMgDl ? "mg/dL" : "mmol/L",
            keepAliveDescription: keepAliveDescription,
            processingLines: [
                "BG adjustment: \(defaults.enableAdjustment ? "Enabled" : "None")",
                "Smoothing: \(smoothingDescription)",
                "5-minute readings: \(fiveMinuteDescription)"
            ],
            integrationLines: [
                "Nightscout uploads: \(nightscoutUploadsEnabled ? "Enabled" : "Disabled")",
                "Apple Health: \(defaults.storeReadingsInHealthkit ? "Enabled" : "Disabled")",
                "Live Activity: \(defaults.liveActivityType.debugDescription)",
                "Calendar sharing: \(defaults.createCalendarEvent ? "Enabled" : "Disabled")",
                "OS-AID sharing: \(osAidDescription)"
            ]
        )
    }
}

/// Produces every user-visible and exported string from typed entries.
///
/// The viewer rows, Copy action and Share sheet all use this builder, which prevents the on-screen
/// interpretation from drifting away from the text a user sends to support. Inputs are expected in
/// newest-first order, matching `TroubleshootingLogStore.snapshot()`.
struct TroubleshootingLogReportBuilder {
    let entries: [TroubleshootingLogEntry]
    let usesMgDl: Bool
    let appInfo: TroubleshootingLogAppInfo
    let generatedAt: Date
    let timeZone: TimeZone

    /// Returns entries whose controlled, user-facing sentence contains the supplied text.
    ///
    /// Filtering the same sentence used by the row avoids exposing or searching developer-only
    /// trace data. Whitespace-only input restores the complete list, and localized comparison makes
    /// ordinary case differences behave as users expect from a search field.
    func entries(matching filterText: String) -> [TroubleshootingLogEntry] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }

        return entries.filter { entry in
            message(for: entry).localizedCaseInsensitiveContains(query)
        }
    }

    /// Builds export-only configuration context. The app version deliberately excludes its build number.
    ///
    /// This information is valuable to somebody interpreting a shared report but deliberately stays
    /// out of the activity screen, where it would displace the time-ordered troubleshooting history.
    var headerLines: [String] {
        var lines = [
            "\(appInfo.projectName) Troubleshooting Log",
            "Created: \(Self.fullDateFormatter(timeZone: timeZone).string(from: generatedAt)) \(timeZone.abbreviation(for: generatedAt) ?? timeZone.identifier)",
            "App Name: \(appInfo.appName)",
            "Version: \(appInfo.version)",
            "Device: \(appInfo.deviceClass), iOS \(appInfo.systemVersion)",
            "Mode: \(appInfo.modeDescription) (\(appInfo.dataSourceDescription))"
        ]

        if let dexcomBluetoothChannel = appInfo.dexcomBluetoothChannelDescription {
            lines.append("Dexcom Bluetooth channel: \(dexcomBluetoothChannel)")
        }
        if let keepAlive = appInfo.keepAliveDescription {
            lines.append("Background keep-alive: \(keepAlive)")
        }
        lines.append("Glucose unit: \(appInfo.unitDescription)")
        lines.append(contentsOf: appInfo.processingLines)
        lines.append(contentsOf: appInfo.integrationLines)
        return lines
    }

    /// Complete selectable/shareable plain text, grouped by local day with the newest entries first.
    var reportText: String {
        var lines = headerLines
        lines.append("")
        lines.append("Latest information first")

        guard !entries.isEmpty else {
            lines.append("No troubleshooting information was recorded during this period.")
            return lines.joined(separator: "\n")
        }

        var previousDay: Date?
        let calendar = Calendar.current
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            if previousDay != day {
                lines.append("")
                lines.append(Self.dayFormatter(timeZone: timeZone).string(from: entry.timestamp))
                previousDay = day
            }
            lines.append("\(Self.timeFormatter(timeZone: timeZone).string(from: entry.timestamp))  \(message(for: entry))")
        }
        return lines.joined(separator: "\n")
    }

    /// Maps only typed, bounded values to stable English sentences.
    ///
    /// Never accept a fallback developer message here. Exhaustively handling the enum ensures a new
    /// payload cannot become shareable until its privacy and wording have been considered explicitly.
    func message(for entry: TroubleshootingLogEntry) -> String {
        switch entry.kind {
        case let .app(activity):
            switch activity {
            case .started: return "App started."
            case .terminated: return "App was closed."
            }

        case let .bluetooth(activity):
            switch activity {
            case .scanning: return "Bluetooth is scanning for the configured device."
            case .connecting: return "Bluetooth is connecting to the configured device."
            case .connected: return "Bluetooth connected to the configured device."
            case .connectionRestored: return "Bluetooth recovered and reconnected to the configured device."
            case .disconnected: return "Bluetooth disconnected from the configured device."
            case .connectionFailed: return "Bluetooth could not connect and will try again."
            case .connectionTimedOut: return "Bluetooth connection setup timed out and will try again."
            case .poweredOff: return "Bluetooth is turned off."
            case .unauthorized: return "xDrip4iOS does not have permission to use Bluetooth."
            case .pairingRequested: return "The CGM transmitter requested Bluetooth pairing."
            case .pairingSucceeded: return "The CGM transmitter paired successfully."
            case .pairingFailed: return "The CGM transmitter did not complete Bluetooth pairing."
            }

        case let .bluetoothDevice(name, activity):
            switch activity {
            case .added: return "Added new Bluetooth device: \(name.value)."
            case .connected: return "Bluetooth connected to device: \(name.value)."
            case .connectionRequested: return "Connection requested for Bluetooth device: \(name.value)."
            case .disconnected: return "Disconnected Bluetooth device: \(name.value)."
            case .removed: return "Removed Bluetooth device: \(name.value)."
            case .reconnectedToExisting: return "Reconnected to existing Bluetooth device: \(name.value)."
            }

        case let .cgm(source, activity):
            switch activity {
            case .addingStarted: return "Started adding \(source.name)."
            case .connectionRequested: return "Reconnect requested for \(source.name)."
            case .connected: return "\(source.name) connected."
            case .disconnected: return "\(source.name) was disconnected."
            case .removed: return "\(source.name) was removed."
            case .nfcScanStarted: return "\(source.name) NFC sensor scan started."
            case .nfcScanSucceeded: return "\(source.name) NFC sensor scan succeeded."
            case .nfcScanFailed: return "\(source.name) NFC sensor scan failed."
            case .nfcScanCancelled: return "\(source.name) NFC sensor scan was cancelled."
            case .nfcScanTimedOut: return "\(source.name) NFC sensor scan timed out."
            case .nfcUnavailable: return "NFC sensor scanning is not available on this iPhone."
            }

        case let .follower(source, activity):
            switch activity {
            case .downloadStarted: return "\(source.name) checked for glucose information."
            case .loginStarted: return "\(source.name) started signing in."
            case .loginSucceeded: return "\(source.name) signed in successfully."
            case .loginFailed: return "\(source.name) could not sign in. Check the account settings."
            case .loggedOut: return "\(source.name) logged out."
            case .sessionExpired:
                return source == .careLink
                    ? "CareLink session expired. Log in again."
                    : "\(source.name) session expired and is signing in again."
            case let .downloadSucceeded(readingCount): return "\(source.name) returned \(readingCount) glucose reading\(readingCount == 1 ? "" : "s")."
            case .downloadFailed: return "\(source.name) could not retrieve glucose information."
            case .noReadings: return "\(source.name) returned no new glucose readings."
            case .retryScheduled: return "\(source.name) scheduled another attempt."
            case .recovered: return "\(source.name) recovered and glucose information is being received again."
            }

        case let .glucoseAccepted(mgDl, _, measuredAt):
            // The current CGM/follower type is already prominent in the copied/shared report header.
            // Keep it in the typed entry for recovery filtering, but do not repeat it on every row.
            return "New reading: \(glucoseText(mgDl: mgDl)) at \(measurementTimeText(measuredAt, recordedAt: entry.timestamp))."

        case let .sensor(activity):
            switch activity {
            case .detected: return "A new sensor session was started."
            case .started: return "A sensor session started."
            case let .startedWithCode(sensorCode): return "A sensor session started with sensor code \(sensorCode)."
            case let .warmingUp(minutesRemaining): return "Sensor is warming up for about \(minutesRemaining) more minute\(minutesRemaining == 1 ? "" : "s")."
            case .stopped: return "The sensor session stopped."
            case .notDetected: return "No active sensor was detected."
            case .unusableReading: return "A sensor reading was rejected because it was not usable."
            }

        case let .sensorLabelScan(activity):
            switch activity {
            case let .succeeded(source, sensorCode, lotNumber, serialNumber):
                return "Dexcom G6 sensor label \(source.rawValue) scan succeeded: sensor code \(sensorCode), lot \(lotNumber), serial \(serialNumber)."
            case let .failed(source, reason):
                return "Dexcom G6 sensor label \(source.rawValue) scan failed: \(sensorLabelScanFailureText(reason))."
            }

        case let .sensorNoise(shortTermMgDl, longTermMgDl, status):
            var measurements = [String]()
            if let shortTermMgDl {
                measurements.append("30-minute \(Self.compactDecimal(shortTermMgDl)) mg/dL")
            }
            if let longTermMgDl {
                measurements.append("4-hour \(Self.compactDecimal(longTermMgDl)) mg/dL")
            }
            guard !measurements.isEmpty else {
                return "Sensor noise: no measurement yet (status: \(status.name))."
            }
            return "Sensor noise: \(measurements.joined(separator: ", ")) (status: \(status.name))."

        case let .sensorHealthAlert(alert):
            switch alert {
            case .persistentNoise:
                return "Persistent sensor noise alert was triggered."
            case .possibleFlatline:
                return "Possible sensor flatline alert was triggered."
            case .dexcomExcessNoise:
                return "Dexcom reported excessive sensor noise."
            case .dexcomTemporarySensorIssue:
                return "Dexcom reported a temporary sensor issue."
            case .dexcomQuestionMarks:
                return "Dexcom reported a sensor question-mark state."
            case .dexcomSensorFailure:
                return "Dexcom reported a sensor failure."
            case .dexcomTransmitterFailure:
                return "Dexcom reported a transmitter failure."
            case .libreSensorFailure:
                return "Libre reported a sensor failure."
            case .dexcomTransmitterBatteryFailure:
                return "Dexcom reported a transmitter battery failure."
            }

        case let .transmitterReadSuccess(percent, missedReadings, expectedReadings, windowHours):
            let window: String
            if windowHours >= 24 {
                window = "24 hours"
            } else if windowHours <= 0 {
                window = "less than 1 hour"
            } else {
                window = "about \(windowHours) hour\(windowHours == 1 ? "" : "s")"
            }
            return "Transmitter read success: \(percent)% over \(window) (\(missedReadings) of \(expectedReadings) reading\(expectedReadings == 1 ? "" : "s") missed)."

        case let .calibrationAccepted(mgDl, readiness):
            let accepted = "Calibration accepted: \(glucoseText(mgDl: mgDl))."
            guard let readiness else { return accepted }
            return accepted + " Guidance was \(readiness.overall.name) " +
                "(calibration value \(readiness.calibrationValue.name), " +
                "trend \(readiness.stableTrend.name), sensor noise \(readiness.sensorNoise.name))."

        case let .alert(kindRawValue, activity):
            let alertName = Self.alertName(rawValue: kindRawValue)
            switch activity {
            case .raised: return "\(alertName) alert was raised."
            case let .scheduled(minutes): return "\(alertName) alert was scheduled in \(minutes) minute\(minutes == 1 ? "" : "s")."
            case let .snoozed(minutes): return "\(alertName) alert was snoozed for \(minutes) minute\(minutes == 1 ? "" : "s")."
            case let .preSnoozed(minutes): return "\(alertName) alert was pre-snoozed for \(minutes) minute\(minutes == 1 ? "" : "s")."
            case .notificationDismissed: return "\(alertName) alert notification was dismissed."
            case .disabled: return "\(alertName) alert condition was met, but the alert is disabled."
            case .notificationsDenied: return "Notifications are not allowed, so an alert may not appear."
            case .suppressedBySnooze: return "\(alertName) alert condition was met, but the alert was pre-snoozed."
            }

        case let .integration(name, activity):
            if name == .nightscoutBackfill {
                switch activity {
                case .started: return "Nightscout started checking for missing readings."
                case let .succeeded(itemCount):
                    guard let itemCount else { return "Nightscout restored missing glucose readings." }
                    return "Nightscout restored \(itemCount) missing glucose reading\(itemCount == 1 ? "" : "s")."
                case .failed, .permissionDenied: return "Nightscout could not check for missing readings."
                case .noData: return "Nightscout found no missing readings."
                case .recovered: return "Nightscout can check for missing readings again."
                case .restarted: return "Nightscout restarted its missing-reading check."
                case .ended: return "Nightscout ended its missing-reading check."
                }
            }

            switch activity {
            case .started: return "\(name.name) started an update."
            case let .succeeded(itemCount):
                if let itemCount {
                    return "\(name.name) updated \(itemCount) item\(itemCount == 1 ? "" : "s") successfully."
                }
                return "\(name.name) updated successfully."
            case .failed: return "\(name.name) could not complete its update."
            case .noData: return "\(name.name) had no new information to update."
            case .permissionDenied:
                if name == .healthKit {
                    return "Apple Health is enabled, but permission has not been granted."
                }
                return "\(name.name) does not have the required permission."
            case .restarted: return "\(name.name) restarted."
            case .ended: return "\(name.name) ended."
            case .recovered: return "\(name.name) recovered and is updating again."
            }

        case .heartbeatReceived:
            return "Heartbeat received."

        case let .configuration(activity):
            switch activity {
            case let .modeChanged(isMaster):
                return "App mode changed to \(isMaster ? "Master" : "Follower")."
            case let .followerSourceChanged(source):
                return "Data source changed to \(source.name)."
            case let .cgmSourceChanged(source):
                return "CGM source changed to \(source.name)."
            case .cgmSourceDisconnected:
                return "The configured CGM was disconnected."
            case let .keepAliveChanged(mode):
                return "Background keep-alive changed to \(mode.name)."
            case let .dexcomConnectionModeChanged(mode):
                return "Dexcom connection mode changed to \(mode.name)."
            case let .dexcomBluetoothChannelChanged(channel):
                return "Dexcom Bluetooth channel changed to \(channel.name)."
            case let .therapySourceChanged(source):
                return "Pump & Treatments source changed to \(source.name)."
            case let .liveActivityChanged(mode):
                return "Live Activity changed to \(mode.name)."
            case let .aidFollowerChanged(mode):
                return "AID follower type changed to \(mode.name)."
            case let .patientAliasChanged(isSet):
                return "Patient alias was \(isSet ? "changed" : "removed")."
            case let .credentialChanged(source, field, isSet):
                let fieldName = field == .username ? "username" : "password"
                return "\(source.name) \(fieldName) was \(isSet ? "changed" : "removed")."
            case let .postProcessingSettings(settings):
                let adjustment: String
                if settings.adjustmentEnabled,
                   let slope = settings.adjustmentSlope,
                   let intercept = settings.adjustmentIntercept {
                    adjustment = "BG adjustment scale \(Self.compactDecimal(slope)), offset \(Self.compactDecimal(intercept)), emphasis \(settings.adjustmentEmphasis.name)"
                } else {
                    adjustment = "BG adjustment none"
                }

                let smoothing = settings.smoothingEnabled
                    ? "smoothing \(settings.smoothingAlgorithm.name), strength \(settings.smoothingStrength), \(settings.smoothingPeriodMinutes)-minute period"
                    : "smoothing none"
                let cadence = settings.fiveMinuteReadings == .notApplicable
                    ? "5-minute readings n/a"
                    : "5-minute readings \(settings.fiveMinuteReadings == .enabled ? "enabled" : "disabled")"
                var message = "Post-processing settings: \(adjustment); \(smoothing); \(cadence)."

                if let applyRange = settings.applyRange {
                    switch applyRange {
                    case .now:
                        message += " Applied from now."
                    case let .hoursAgo(hours):
                        message += " Applied from \(hours) hour\(hours == 1 ? "" : "s") ago."
                    }
                }
                return message
            }

        case let .dataManagement(activity):
            switch activity {
            case let .automaticCleanupChanged(enabled): return "Automatic data cleanup was \(enabled ? "enabled" : "disabled")."
            case let .retentionChanged(days): return "Data retention changed to \(days) days."
            case let .deletionCompleted(itemCount): return "Data deletion completed: \(itemCount) record\(itemCount == 1 ? "" : "s") removed."
            case let .cleanupCompleted(itemCount): return "Automatic data cleanup completed: \(itemCount) record\(itemCount == 1 ? "" : "s") removed."
            case .backupCreated: return "A data backup was created."
            case .backupRestored: return "A data backup was restored."
            case .operationFailed: return "A data management operation failed."
            }

        case let .glucoseManagement(activity):
            switch activity {
            case let .changed(previousMgDl, updatedMgDl, measuredAt):
                return "Reading changed from \(glucoseText(mgDl: previousMgDl)) to \(glucoseText(mgDl: updatedMgDl)) at \(measurementTimeText(measuredAt, recordedAt: entry.timestamp))."
            case let .deleted(mgDl, measuredAt):
                return "Reading deleted: \(glucoseText(mgDl: mgDl)) at \(measurementTimeText(measuredAt, recordedAt: entry.timestamp))."
            }

        case let .treatment(activity):
            // The leading row timestamp is when the user performed the action. `treatmentAt` is the
            // date assigned to the treatment, which may legitimately be earlier or later that day.
            switch activity {
            case let .added(kind, treatmentAt):
                return "\(kind.name) treatment added at \(measurementTimeText(treatmentAt, recordedAt: entry.timestamp))."
            case let .edited(kind, treatmentAt):
                return "\(kind.name) treatment edited at \(measurementTimeText(treatmentAt, recordedAt: entry.timestamp))."
            case let .deleted(kind, treatmentAt):
                return "\(kind.name) treatment deleted at \(measurementTimeText(treatmentAt, recordedAt: entry.timestamp))."
            }
        }
    }

    private func sensorLabelScanFailureText(_ failure: TroubleshootingSensorLabelScanFailure) -> String {
        switch failure {
        case .cameraPermissionDenied: return "camera permission denied"
        case .cameraUnavailable: return "camera unavailable"
        case .malformedLabel: return "malformed sensor label"
        case .multipleValidLabels: return "multiple valid sensor labels found"
        case .noValidLabel: return "no valid sensor label found"
        case .unreadableImage: return "selected image could not be read"
        }
    }

    func timeText(for entry: TroubleshootingLogEntry) -> String {
        Self.timeFormatter(timeZone: timeZone).string(from: entry.timestamp)
    }

    func dayText(for entry: TroubleshootingLogEntry) -> String {
        Self.dayFormatter(timeZone: timeZone).string(from: entry.timestamp)
    }

    private func glucoseText(mgDl: Double) -> String {
        // Persistence remains unit-neutral by storing canonical mg/dL. Conversion at presentation time
        // means an existing history follows the user's current display-unit preference immediately.
        let value = mgDl.mgDlToMmol(mgDl: usesMgDl).bgValueRounded(mgDl: usesMgDl).bgValueToString(mgDl: usesMgDl)
        return value + " " + (usesMgDl ? "mg/dL" : "mmol/L")
    }

    /// Keeps same-day measurement times compact while retaining the date when a reading was measured
    /// on another local day. The row's leading timestamp remains when xdripswift accepted the value.
    private func measurementTimeText(_ measuredAt: Date, recordedAt: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDate(measuredAt, inSameDayAs: recordedAt) {
            return Self.shortTimeFormatter(timeZone: timeZone).string(from: measuredAt)
        }
        return Self.shortDateTimeFormatter(timeZone: timeZone).string(from: measuredAt)
    }

    private static func alertName(rawValue: Int) -> String {
        // Convert the safe enum value to controlled wording; do not use custom alert or notification text.
        guard let kind = AlertKind(rawValue: rawValue) else { return "Glucose" }
        switch kind {
        case .verylow: return "Urgent low"
        case .low: return "Low"
        case .high: return "High"
        case .veryhigh: return "Urgent high"
        case .missedreading: return "Missed reading"
        case .calibration: return "Calibration"
        case .batterylow: return "Transmitter battery"
        case .fastdrop: return "Fast drop"
        case .fastrise: return "Fast rise"
        case .phonebatterylow: return "Phone battery"
        case .notlooping: return "Not looping"
        case .sensorTransmitterFailure: return "Sensor/Transmitter Failure"
        }
    }

    private static func compactDecimal(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }

    private static func timeFormatter(timeZone: TimeZone) -> DateFormatter {
        // Reports intentionally use a predictable English support vocabulary while respecting the
        // user's local time zone. POSIX locale also prevents device-language formatting surprises.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }

    private static func shortTimeFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }

    private static func shortDateTimeFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMMM 'at' HH:mm:ss"
        return formatter
    }

    private static func dayFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter
    }

    private static func fullDateFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMMM yyyy 'at' HH:mm:ss"
        return formatter
    }
}
