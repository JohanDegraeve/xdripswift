import Foundation

class Libre1Calibrator:Calibrator {
    
    var rawValueDivider: Double = 1000.0
    
    let sParams: SlopeParameters = SlopeParameters(LOW_SLOPE_1: 1, LOW_SLOPE_2: 1, HIGH_SLOPE_1: 1, HIGH_SLOPE_2: 1, DEFAULT_LOW_SLOPE_LOW: 1, DEFAULT_LOW_SLOPE_HIGH: 1, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1, DEFAUL_HIGH_SLOPE_LOW: 1)
    
    let ageAdjustMentNeeded: Bool = false
    
    func description() -> String {
        return "Libre1Calibrator"
    }
    
}
