//
//  HKUnit.swift
//  Loop
//
//  Created by Bharat Mediratta on 12/2/16.
//  Copyright © 2016 LoopKit Authors. All rights reserved.
//
//  Adapted by Johan Degraeve for loopkit
//

import HealthKit

// Code in this extension is duplicated from:
//   https://github.com/LoopKit/LoopKit/blob/master/LoopKit/HKUnit.swift
// to avoid pulling in the LoopKit extension since it's not extension-API safe.
extension HKUnit {

    static let milligramsPerDeciliter: HKUnit = {
        return HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))
    }()
    
    static let millimolesPerLiter: HKUnit = {
        return HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.liter())
    }()
    
    /// The smallest value expected to be visible on a chart
    var chartableIncrement: Double {
        if unitString == "mg/dL" {
            return 1
        } else {
            return 1 / 25
        }
    }
}
