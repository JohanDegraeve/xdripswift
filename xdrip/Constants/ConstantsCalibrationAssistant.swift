//
//  ConstantsCalibrationAssistant.swift
//  xdrip
//
//  Created by Paul Plant on 26/6/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation

/// constants used by the calibration assistant
enum ConstantsCalibrationAssistant {
    
    /// the number of minutes of readings that we should use for the calibration assistant calculations
    static let minutesToUseForCalculations: Double = 20
    
    // Delta
    /// the value over which we will consider that the delta change is significant to display as a concern to the user
    static let deltaResultLimit: Double = 90

    /// the weighting that will be applied to the delta change value to push the result up
    static let deltaMultiplier: Double = 30
    
    
    // Standard Deviation
    /// the value over which we will consider that the variation in change is significant to display as a concern to the user
    static let stdDeviationResultLimit: Double = 60
    
    /// the weighting that will be applied to the standard deviation value to push the result up
    static let stdDeviationMultiplier: Double = 50
    
    
    // Very high BG levels
    /// the upper higher BG level at which the user should never calibrate. A bigger multiplier will be used for values over this amount
    static let higherBgUpperLimit: Double = 160
    
    /// the weighting that will be applied to very high BG values to push the result up
    static let higherBgUpperMultiplier: Double = 15
    
    
    // Higher BG levels
    /// the higher BG level at which the user should be careful when calibrating. A smaller multiplier will be applied to values over this amount
    static let higherBgRecommendedLimit: Double = 130
    
    /// the weighting that will be applied to moderately high BG values to push the result up
    static let higherBgRecommendedMultiplier: Double = 10
    
    
    // Lower BG levels
    /// the lower BG level at which the user should be careful when calibrating. A smaller multiplier will be applied to values below this amount
    static let lowerBgRecommendedLimit: Double = 90
    
    /// the weight that will be applied to moderately low BG values to push the result up
    static let lowerBgRecommendedMultiplier: Double = 10
    
    
    // Very low BG levels
    /// the lower BG level at which the user should never calibrate. A bigger multiplier will be used for values under this amount
    static let lowerBgLowerLimit: Double = 75
    
    /// the weighting that will be applied to very low BG values to push the result up
    static let lowerBgLowerMultiplier: Double = 15
    
    
    // Limits
    /// the limit below which the calibration result will be considered as  OK
    static let okToCalibrateLimit: Double = 130
    
    /// the limit below which (and above okToCalibrateLimit) when the calibration result will be considered as "Not Ideal" and the user will be warned to be careful and calibrate later
    static let notIdealToCalibrateLimit: Double = 200
    
}
