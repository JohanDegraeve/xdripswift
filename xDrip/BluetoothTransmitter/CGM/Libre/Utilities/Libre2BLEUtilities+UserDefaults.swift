import Foundation

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
