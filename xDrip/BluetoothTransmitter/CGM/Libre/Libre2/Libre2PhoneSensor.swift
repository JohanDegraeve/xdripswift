import Foundation
import os

/// Keeps ordinary phone collection on its existing preferences and native-algorithm setting.
final class Libre2PhoneSensor: Libre2SensorDataSource {
    var serialNumber: String?
    var webOOPEnabled: Bool
    /// Observed on main for Watch transfer readiness; never controls ordinary phone BLE.
    var transferReadiness = Libre2PhoneTransferReadiness()
    private let defaults: UserDefaults
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMLibre2)

    init(serialNumber: String?, webOOPEnabled: Bool, defaults: UserDefaults = .standard) {
        self.serialNumber = serialNumber
        self.webOOPEnabled = webOOPEnabled
        self.defaults = defaults
    }

    var sensorUID: Data? { defaults.libreSensorUID }
    var patchInfo: Data? { defaults.librePatchInfo }

    func reserveUnlock() throws -> Libre2StreamingUnlock {
        // Preserve phone behaviour, including advancing when unlock transmission is suppressed.
        defaults.libreActiveSensorUnlockCount += 1
        let unlock = Libre2StreamingUnlock(code: defaults.libreActiveSensorUnlockCode, count: defaults.libreActiveSensorUnlockCount, shouldWrite: !defaults.suppressUnLockPayLoad)
        let uid = sensorUID
        DispatchQueue.main.async {
            self.transferReadiness = Libre2PhoneTransferReadiness(sensorUID: uid, unlockCode: unlock.shouldWrite ? unlock.code : nil)
        }
        return unlock
    }

    func parseBLEFrame(_ decryptedFrame: Data, date: Date) -> (bleGlucose: [GlucoseData], sensorTimeInMinutes: UInt16)? {
        let parameters = defaults.libre1DerivedAlgorithmParameters
        if webOOPEnabled {
            guard let parameters = parameters, parameters.serialNumber == serialNumber else {
                trace("web oop enabled but libre1DerivedAlgorithmParameters is nil or libre1DerivedAlgorithmParameters.serialNumber != sensorSerialNumber, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
                return nil
            }
        }
        return Libre2BLEUtilities.parseBLEData(decryptedFrame, libre1DerivedAlgorithmParameters: webOOPEnabled ? parameters : nil, defaults: defaults, date: date)
    }
}

/// Evidence from one phone connection. A toggle or an old reading cannot establish readiness.
struct Libre2PhoneTransferReadiness {
    static let recentReadingInterval: TimeInterval = 180
    private let sensorUID: Data?
    private let unlockCode: UInt32?
    private var unlockWritten = false
    private var lastReading: Date?

    init(sensorUID: Data? = nil, unlockCode: UInt32? = nil) {
        self.sensorUID = sensorUID
        self.unlockCode = unlockCode
    }

    mutating func didWriteUnlock(success: Bool) {
        unlockWritten = success && sensorUID != nil && unlockCode != nil
        lastReading = nil
    }

    mutating func receivedReading(at date: Date, unlockEnabled: Bool) {
        lastReading = unlockWritten && unlockEnabled ? date : nil
    }

    func isReady(sensorUID: Data?, unlockCode: UInt32, at now: Date = Date()) -> Bool {
        guard self.sensorUID == sensorUID, self.unlockCode == unlockCode, let lastReading else { return false }
        let age = now.timeIntervalSince(lastReading)
        return age >= 0 && age < Self.recentReadingInterval
    }
}

/// The phone keeps its existing history keys; the shared parser does not depend on preferences.
extension Libre2BLEUtilities {
    static func parseBLEData(_ data: Data, libre1DerivedAlgorithmParameters: Libre1DerivedAlgorithmParameters?, defaults: UserDefaults = .standard, date: Date = Date()) -> (bleGlucose: [GlucoseData], sensorTimeInMinutes: UInt16) {
        var state = ParserState(
            previousRawGlucoseValues: defaults.previousRawGlucoseValues,
            previousRawTemperatureValues: defaults.previousRawTemperatureValues,
            previousTemperatureAdjustmentValues: defaults.previousTemperatureAdjustmentValues)
        let previousState = state
        let result = parseBLEData(data, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters, state: &state, date: date)

        // Repeated/expired frames leave history untouched, as in the original parser.
        if state != previousState {
            defaults.previousRawGlucoseValues = state.previousRawGlucoseValues
            defaults.previousRawTemperatureValues = state.previousRawTemperatureValues
            defaults.previousTemperatureAdjustmentValues = state.previousTemperatureAdjustmentValues
        }
        return result
    }
}
