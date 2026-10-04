import Foundation

/// Follows the transmitter's actual calibration stage, never the code used to request a session.
/// In particular, a `0000` start request can adopt an existing factory-calibrated session.
struct DexcomG6InitialCalibrationPolicy {
    private(set) var sensorStartDate: Date?
    private(set) var requiredState: DexcomAlgorithmState?
    private(set) var hasPendingPrompt = false
    private var firstCalibration: (valueInMgDl: Double, enteredAt: Date)?

    var secondCalibrationPrefill: (valueInMgDl: Double, enteredAt: Date)? {
        requiredState == .SecondofTwoBGsNeeded ? firstCalibration : nil
    }

    mutating func update(state: DexcomAlgorithmState, sensorStartDate: Date) -> Bool {
        let sameSession = self.sensorStartDate.map {
            abs($0.timeIntervalSince(sensorStartDate)) <= CGMG5Transmitter.sensorStartDateTolerance
        } ?? false
        let nextState = state == .FirstofTwoBGsNeeded || state == .SecondofTwoBGsNeeded ? state : nil
        let shouldPrompt = nextState != nil && (!sameSession || nextState != requiredState)
        if !sameSession || nextState == nil {
            firstCalibration = nil
        }
        self.sensorStartDate = sensorStartDate
        requiredState = nextState
        if shouldPrompt || nextState == nil {
            hasPendingPrompt = shouldPrompt
        }
        return shouldPrompt
    }

    mutating func calibrationSubmitted(valueInMgDl: Double? = nil, enteredAt: Date = Date()) {
        if requiredState == .FirstofTwoBGsNeeded, hasPendingPrompt,
           let valueInMgDl, (40.0...400.0).contains(valueInMgDl) {
            firstCalibration = (valueInMgDl, enteredAt)
        }
        hasPendingPrompt = false
    }

    func matches(sensorStartDate: Date) -> Bool {
        guard let expectedDate = self.sensorStartDate, requiredState != nil else { return false }
        return abs(expectedDate.timeIntervalSince(sensorStartDate)) <= CGMG5Transmitter.sensorStartDateTolerance
    }

    static func canEnterCalibration(canCalibrate: Bool, hasReading: Bool, isNativeG6: Bool) -> Bool {
        canCalibrate && (hasReading || isNativeG6)
    }
}
