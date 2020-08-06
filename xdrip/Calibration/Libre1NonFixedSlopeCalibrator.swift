//
//  Libre1NonFixedSlopeCalibrator.swift
//  xdrip
//
//  Created by Tudor-Andrei Vrabie on 05/07/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation

class Libre1NonFixedSlopeCalibrator:Calibrator {
    
    var rawValueDivider: Double = 1000.0
    
    let sParams: SlopeParameters = SlopeParameters(LOW_SLOPE_1: 0.55, LOW_SLOPE_2: 0.50, HIGH_SLOPE_1: 1.5, HIGH_SLOPE_2: 1.6, DEFAULT_LOW_SLOPE_LOW: 0.55, DEFAULT_LOW_SLOPE_HIGH: 0.50, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1.5, DEFAUL_HIGH_SLOPE_LOW: 1.4)
    
    let ageAdjustMentNeeded: Bool = false
 
    func description() -> String {
        return "Libre1NonFixedSlopeCalibrator"
    }

}
