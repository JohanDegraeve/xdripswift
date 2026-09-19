import Foundation
import CoreBluetooth

/// defines functions that every cgm transmitter should conform to
protocol CGMTransmitter: AnyObject {
    
    /// to set nonFixedSlopeEnabled - called when user changes the setting
    ///
    /// for transmitters who don't support non fixed slopes, there's no need to implemented this function<br>
    /// ---  for transmitters who support non fixed (all Libre transmitters) this should be implemented
    func setNonFixedSlopeEnabled(enabled:Bool)
    
    /// - is the CGMTransmitter nonFixed enabled or not
    /// - default implementation returns false
    func isNonFixedSlopeEnabled() -> Bool

    /// to set webOOPEnabled - called when user changes the setting
    ///
    /// for transmitters who don't support webOOP, there's no need to implemented this function<br>
    /// ---  for transmitters who support webOOP (Bubble, MiaoMiao, ..) this should be implemented
    func setWebOOPEnabled(enabled:Bool)
    
    /// is the CGMTransmitter web oop enabled or not
    /// - webOOPEnabled means actually the transmitter sends calibrated data (which is the case also for Dexcom G6 firefly for example, and Libre 2 using Libre algorithm)
    /// - default implementation returns false
    func isWebOOPEnabled() -> Bool
    
    /// if true then the calibration is possible, even though the transmitter sends calibrated values (which is the case for Dexcom G6 firefly)
    /// - default false
    func overruleIsWebOOPEnabled() -> Bool
    
    /// is it allowed to set webOOPenabled to false
    /// - typicall for firefly, where webOOPEnabled false is not possible
    /// - default true
    func nonWebOOPAllowed() -> Bool
    
    /// is the transmitter a G6 Anubis with a 180 day expiry?
    /// - default false
    func isAnubisG6() -> Bool // append G6 to the protocol function name to avoid conflicts with the isAnubis public var of CGMG5Transmitter
    
    /// get cgmTransmitterType
    func cgmTransmitterType() -> CGMTransmitterType
    
    /// only applicable for Libre transmitters. To request a new reading.
    func requestNewReading()
    
    /// maximum sensor age in days, nil if no maximum
    /// - default implementation returns nil
    func maxSensorAgeInDays() -> Double?
    
    /// to send a start sensor command to the transmitter
    /// - only useful for Dexcom - firefly type of transmitters, other transmitter types will have an empty implementation
    /// - parameters:
    ///     - sensorCode : only to be filled in if code known, only applicable for Dexcom firefly
    ///     - startDate : sensor start timeStamp
    func startSensor(sensorCode: String?, startDate: Date)
    
    /// to send a stop sensor command to the transmitter
    /// - only useful for Dexcom type of transmitters, other transmitter types will have an empty implementation
    func stopSensor(stopDate: Date)
    
    /// - to send a calibration toe the transmitter
    /// - only useful for Dexcom type of transmitters, other transmitter types will have an empty implementation
    func calibrate(calibration: Calibration)

    /// Latest transmitter-side calibration state, when the active CGM exposes one.
    func transmitterCalibrationStatus() -> CGMTransmitterCalibrationStatus?
    
    /// - should user give sensor start time when starting a sensor
    /// - default true
    func needsSensorStartTime() -> Bool
    
    /// - should user give sensor start code when starting a sensor
    /// - default false
    func needsSensorStartCode() -> Bool
    
    /// if true, then the UI should ask the user to confirm a large one-step calibration change
    /// - default false
    func shouldWarnOnLargeCalibrationStep() -> Bool

    /// returns the service CBUUID
    func getCBUUID_Service() -> String
    
    /// returns the receive characteristic CBUUID
    func getCBUUID_Receive() -> String
    
}

enum CGMTransmitterCalibrationStatus: Equatable {
    case queued
    case sentAwaitingResponse
    case processing
    case completedHigh
    case completedLow
    case rejected(DexcomG7CalibrationRejectionReason)
    case notPermitted

    /// Groups detailed transmitter responses into the three states shown by the status indicator.
    var indicatorColor: DexcomSensorStatusIndicatorColor {
        switch self {
        case .queued, .sentAwaitingResponse, .processing:
            return .yellow
        case .completedHigh, .completedLow:
            return .green
        case .rejected, .notPermitted:
            return .red
        }
    }

    var shortDescription: String {
        switch self {
        case .queued:
            return Texts_HomeView.sensorManagementCalibrationQueued
        case .sentAwaitingResponse:
            return Texts_HomeView.sensorManagementCalibrationSentShort
        case .processing:
            return Texts_HomeView.sensorManagementCalibrationProcessing
        case .completedHigh, .completedLow:
            return Texts_HomeView.sensorManagementCalibrationCompletedShort
        case .rejected:
            return Texts_HomeView.sensorManagementCalibrationRejectedShort
        case .notPermitted:
            return Texts_HomeView.sensorManagementCalibrationErrorShort
        }
    }

    var preventsCalibrationSubmission: Bool {
        switch self {
        case .queued, .sentAwaitingResponse, .processing, .notPermitted:
            return true
        case .completedHigh, .completedLow, .rejected:
            return false
        }
    }

    var isInProgress: Bool {
        switch self {
        case .queued, .sentAwaitingResponse, .processing:
            return true
        case .completedHigh, .completedLow, .rejected, .notPermitted:
            return false
        }
    }

    var traceDescription: String {
        switch self {
        case .queued: return "queued"
        case .sentAwaitingResponse: return "sent, awaiting response"
        case .processing: return "processing"
        case .completedHigh: return "completed with high confidence"
        case .completedLow: return "completed with low confidence"
        case let .rejected(reason): return "rejected: \(reason.traceDescription)"
        case .notPermitted: return "calibration not permitted"
        }
    }
}

struct CGMTransmitterCalibrationStatusTracker {
    private(set) var status: CGMTransmitterCalibrationStatus?

    @discardableResult
    mutating func transition(to newStatus: CGMTransmitterCalibrationStatus) -> Bool {
        guard status != newStatus else { return false }
        status = newStatus
        return true
    }

    @discardableResult
    mutating func clear(if currentStatus: CGMTransmitterCalibrationStatus) -> Bool {
        guard status == currentStatus else { return false }
        status = nil
        return true
    }
}

/// cgm transmitter types
enum CGMTransmitterType:String, CaseIterable {
    
    /// 2026-08-13: Keep this legacy raw value because it is persisted in UserDefaults.
    /// User-facing setup labels omit G5, while existing G5 transmitters remain supported.
    case dexcom = "Dexcom G5/G6/ONE"
    
    /// dexcom G7
    case dexcomG7 = "Dexcom G7/ONE+/Stelo"
    
    /// miaomiao
    case miaomiao = "MiaoMiao"
    
    /// Bubble
    case Bubble = "Bubble"
    
    /// Libre2
    case Libre2 = "Libre2"

    /// Medtrum TouchCare Nano Pump with integrated CGM data relayed via the pump BLE session.
    /// Keep this raw value stable because it is persisted in UserDefaults.
    case medtrumTouchCareNano = "Medtrum Nano"

    /// Direct Medtrum Nano glucose is already consumed by the connected pump and must not be
    /// exported as an independent CGM source to another OS-AID system.
    var osAidSharingPolicy: OSAidSharingPolicy {
        switch self {
        case .medtrumTouchCareNano:
            return .blocked
        default:
            return .allowed
        }
    }

    /// what sensorType does this CGMTransmitter type support
    func sensorType() -> CGMSensorType {
        
        switch self {
            
        case .dexcom, .dexcomG7:
            return .Dexcom
            
        case .miaomiao, .Bubble, .Libre2:
            return .Libre

        case .medtrumTouchCareNano:
            return .Medtrum

        }
        
    }
    
    /// if true, then a class conforming to the protocol CGMTransmitterDelegate will call newSensorDetected if it detects a new sensor is placed. Means there's no need to let the user start and stop a sensor
    ///
    /// example MiaoMiao can detect new sensor, implementation should return true, Dexcom transmitter's can't
    ///
    /// if true, then transmitterType must also be able to give the sensor age, ie sensorAge
    func canDetectNewSensor() -> Bool {
        
        switch self {
            
        case .dexcom:
            // for dexcom in native algorithm mode, we receive the sensorStart time from the transmitter, this will be used to determine if a new sensor is received
            // the others will not send sensorStart and will also not send sensorAge
            return true
            
        case .miaomiao, .Bubble:
            return true
            
        case .Libre2:
            return true
            
        case .dexcomG7:
            return true

        case .medtrumTouchCareNano:
            // EasyPatch runs the actual sensor lifecycle, but we *can* infer sensor start by combining
            // packet timestamp with the reading-counter we decode. Returning true lets xDrip auto-start
            // its internal sensor record from the sensorAge we pass with each reading.
            return true

        }
    }
    
    /// this function says if the user should be able to manually start the sensor.
    ///
    /// Would normally not be required, because if canDetectNewSensor returns true, then manual start shouldn't e necessary.
    func allowManualSensorStart() -> Bool {
        
        switch self {
            
        case .dexcom:
            return true
            
        case .miaomiao, .Bubble, .Libre2:
            return true
            
        case .dexcomG7:
            return false

        case .medtrumTouchCareNano:
            // EasyPatch owns sensor lifecycle. xDrip should not offer a manual start UI.
            return false

        }
    }
        
    /// returns default battery alert level, below this level an alert should be generated - this default value will be used when changing transmittertype
    func defaultBatteryAlertLevel() -> Int {
        switch self {
            
        case .dexcom:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelDexcomG5
            
        case .miaomiao:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelMiaoMiao
            
        case .Bubble:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelBubble
            
        case .Libre2:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelLibre2
            
        case .dexcomG7:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelDexcomG7

        case .medtrumTouchCareNano:
            // No pump-battery surface in xDrip. Reuse the generic threshold so the UI has a sane default.
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelLibre2

        }
    }
    
    /// what unit to use for battery level, like '%', Volt, or nothing at all
    ///
    /// to be used for UI stuff
    func batteryUnit() -> String {
        
        switch self {
            
        case .dexcom:
            return "voltB"
            
        case .miaomiao, .Bubble:
            return "%"
            
        case .Libre2:
            return "%"
            
        case .dexcomG7:
            return "voltB"

        case .medtrumTouchCareNano:
            return ""

        }
    }
    
    func detailedDescription() -> String {
        detailedDescription(transmitterID: UserDefaults.standard.activeSensorTransmitterId)
    }

    /// Returns the product name for a specific transmitter rather than relying on global active
    /// sensor state. Configured-device lists use this overload so inactive rows remain accurate.
    func detailedDescription(transmitterID: String?) -> String {
        let normalizedTransmitterID = transmitterID?.uppercased()

        switch self {
            /// dexcom G5, G6
        case .dexcom:
            if let transmitterIdString = normalizedTransmitterID {
                
                if transmitterIdString.startsWith("4") {
                    
                    return "Dexcom G5"
                    
                } else if transmitterIdString.startsWith("8") {
                    
                    return "Dexcom G6"
                    
                } else if transmitterIdString.startsWith("5") {
                    
                    return "Dexcom ONE"
                    
                } else if transmitterIdString.startsWith("C") {
                    
                    return "Dexcom ONE"
                    
                }
                
            }
            
            return "Dexcom"
            
        case .dexcomG7:
            if let transmitterIdString = normalizedTransmitterID {
                if transmitterIdString.startsWith("DX01") {
                    return "Dexcom Stelo"
                } else if transmitterIdString.startsWith("DX02") {
                    return "Dexcom ONE+"
                } else {
                    return "Dexcom G7"
                }
            }
            return "Dexcom G7"
            
        case .Libre2:
            if let activeSensorMaxSensorAgeInDays = UserDefaults.standard.activeSensorMaxSensorAgeInDays, activeSensorMaxSensorAgeInDays >= 15 {
                return "Libre 2 Plus EU"
            } else {
                return "Libre 2 EU"
            }

        case .medtrumTouchCareNano:
            return "Medtrum Nano Pump CGM"
            
        default:
            return self.rawValue
            
        }
        
    }
    
}

/// Resolves the real Dexcom product name from the identifier that belongs to one saved device.
///
/// A normal G5/G6 transmitter stores its real transmitter ID before scanning starts. Automatic
/// G7 discovery is different because it initially stores `DX0000` only as a search placeholder.
/// Once Core Bluetooth finds the sensor, its advertised `DX...` name is the value that identifies
/// G7, ONE+, or Stelo. Keeping this choice in one place prevents the device list, detail view, and
/// Sensor Management from showing different product names for the same physical sensor.
enum DexcomProductNameResolver {
    // Display name for the UI and shared metadata. Keep stored source names and reporting unchanged.
    static let anubisTitle = "Anubis G6"

    static func title(
        transmitterType: CGMTransmitterType,
        transmitterID: String?,
        bluetoothName: String?,
        isAnubis: Bool = false
    ) -> String? {
        switch transmitterType {
        case .dexcom:
            if isAnubis { return anubisTitle }
            guard let transmitterID, !transmitterID.isEmpty else { return nil }

            let title = transmitterType.detailedDescription(transmitterID: transmitterID)
            return title == "Dexcom" ? nil : title

        case .dexcomG7:
            // `DX0000` and the shorter `DX` value mean "find a G7-family sensor". They do not
            // identify the product, so prefer the Bluetooth name learned during discovery.
            let storedID = transmitterID?.uppercased()
            let identifier = storedID == nil
                || storedID == ConstantsBluetoothPairing.dummyDexcomG7TypeTransmitterId
                || storedID == "DX"
                ? bluetoothName
                : transmitterID

            guard let identifier,
                  identifier.uppercased().hasPrefix("DX"),
                  identifier.count > 2
            else { return nil }

            return transmitterType.detailedDescription(transmitterID: identifier)

        default:
            return nil
        }
    }
}

extension CGMTransmitter {
    
    // empty implementation for transmitter types that don't need this
    func setNonFixedSlopeEnabled(enabled: Bool) {}

    // default implementation, false
    func isNonFixedSlopeEnabled() -> Bool { return false }
    
    // empty implementation for transmitter types that don't need this
    func setWebOOPEnabled(enabled:Bool) {}
    
    // default implementation, false
    func isWebOOPEnabled() -> Bool { return false }
    
    // default implementation, false
    func overruleIsWebOOPEnabled() -> Bool { return false }
    
    // default implementation, false
    func isAnubisG6() -> Bool { return false }
    
    // empty implementation for transmitter types that don't need this
    func requestNewReading() {}

    // default implementation, nil
    func maxSensorAgeInDays() -> Double? { return nil }
    
    // default implementation, does nothing
    func startSensor(sensorCode: String?, startDate: Date) {}
    
    // default implementation, does nothing
    func stopSensor(stopDate: Date) {}
    
    // default implementation, does nothing
    func calibrate(calibration: Calibration) {}

    func transmitterCalibrationStatus() -> CGMTransmitterCalibrationStatus? { return nil }
    
    // default implementation, returns true
    func needsSensorStartTime() -> Bool { return true }
    
    // default implementation, returns false
    func needsSensorStartCode() -> Bool { return false }
    
    // default implementation, returns false
    func shouldWarnOnLargeCalibrationStep() -> Bool { return false }

    // default implementation, returns true
    func nonWebOOPAllowed() -> Bool { return true }
    
}
