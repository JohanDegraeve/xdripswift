import Foundation

/// for use with Libre in combination web oop, goal is to recalibrate values received from oop webserver
class LibreReCalibrator: Calibrator {
    
    // as the values are already calibrated, there's no need to divide, so value 1
    var rawValueDivider: Double = 1.0
    
    // using non-fixed slope parameters
    let sParams: SlopeParameters = SlopeParameters(LOW_SLOPE_1: 0.55, LOW_SLOPE_2: 0.50, HIGH_SLOPE_1: 1.5, HIGH_SLOPE_2: 1.6, DEFAULT_LOW_SLOPE_LOW: 0.55, DEFAULT_LOW_SLOPE_HIGH: 0.50, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1.5, DEFAUL_HIGH_SLOPE_LOW: 1.4)
    
    let ageAdjustMentNeeded: Bool = false
    
}
