import Foundation

class DexcomCalibrator:Calibrator {
    
    var rawValueDivider: Double = 1000.0
    
    let sParams = SlopeParameters(LOW_SLOPE_1: 0.95, LOW_SLOPE_2: 0.85, HIGH_SLOPE_1: 1.3, HIGH_SLOPE_2: 1.4, DEFAULT_LOW_SLOPE_LOW: 1.08, DEFAULT_LOW_SLOPE_HIGH: 1.15, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1.3, DEFAUL_HIGH_SLOPE_LOW: 1.2)
    
    var ageAdjustMentNeeded: Bool = true
    
    func description() -> String {
        return "DexcomCalibrator"
    }
    
}
