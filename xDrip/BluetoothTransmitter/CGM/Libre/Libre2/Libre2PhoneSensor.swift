import Foundation
import os

/// Keeps ordinary phone collection on its existing preferences and native-algorithm setting.
final class Libre2PhoneSensor: Libre2SensorDataSource {
    var serialNumber: String?
    var webOOPEnabled: Bool
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
        return Libre2StreamingUnlock(code: defaults.libreActiveSensorUnlockCode, count: defaults.libreActiveSensorUnlockCount, shouldWrite: !defaults.suppressUnLockPayLoad)
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
