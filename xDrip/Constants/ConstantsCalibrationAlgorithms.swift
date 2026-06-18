/// constants used in calibration algorithm
enum ConstantsCalibrationAlgorithms {
    // age adjustment constants, only for non Libre
    static let ageAdjustmentTime = 86400000 * 1.9
    static let ageAdjustmentFactor = 0.45
    
    // minimum and maxium values for a reading
    static let minimumBgReadingCalculatedValue = 39.0
    static let maximumBgReadingCalculatedValue = 400.0
    static let maximumBgReadingCalculatedValueLimit = 600.0
    static let bgReadingErrorValue = 38.0

    // recommended maximum difference between current glucose and a single calibration step
    // especially relevant for Dexcom native calibrations to avoid rejection
    static let maximumRecommendedCalibrationDifferenceInMgDl = 30.0
}
