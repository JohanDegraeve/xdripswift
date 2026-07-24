import Foundation

extension BgReading {

    /// Value to share with OS-AID app groups.
    /// Defaults to unsmoothed data because OS-AID apps perform their own processing.
    var loopShareValue: Double {
        if UserDefaults.standard.loopShareSmoothedData {
            return finalValue
        }

        return adjustedValue?.doubleValue ?? calculatedValue
    }
}
