//
//  TimeInRangeType.swift
//  xdrip
//
//  Created by Paul Plant on 23/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation


/// types of background keep-alive
public enum TimeInRangeType: Int, CaseIterable {
    
    // when adding to TimeInRangeType, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    // the order of the returned enum can be defined in allCases below
    
    case standardRange = 0
    case tightRange = 1
    case userDefinedRange = 2
    
    var description: String {
        switch self {
        case .standardRange:
            return Texts_SettingsView.timeInRangeTypeStandardRange
        case .tightRange:
            return Texts_SettingsView.timeInRangeTypeTightRange
        case .userDefinedRange:
            return Texts_SettingsView.timeInRangeTypeUserDefinedRange
        }
    }
    
    var title: String {
        switch self {
        case .standardRange:
            return Texts_Common.inRangeStatistics
        case .tightRange:
            return Texts_Common.inTightRangeStatistics
        case .userDefinedRange:
            return Texts_Common.userRangeStatistics
        }
    }
    
    var lowerLimit: Double {
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        switch self {
        case .standardRange:
            return isMgDl ? ConstantsStatistics.standardisedLowValueForTIRInMgDl : ConstantsStatistics.standardisedLowValueForTIRInMmol
        case .tightRange:
            return isMgDl ? ConstantsStatistics.standardisedLowValueForTITRInMgDl : ConstantsStatistics.standardisedLowValueForTITRInMmol
        case .userDefinedRange:
            return UserDefaults.standard.lowMarkValueInUserChosenUnit
        }
    }
    
    var higherLimit: Double {
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        switch self {
        case .standardRange:
            return isMgDl ? ConstantsStatistics.standardisedHighValueForTIRInMgDl : ConstantsStatistics.standardisedHighValueForTIRInMmol
        case .tightRange:
            return isMgDl ? ConstantsStatistics.standardisedHighValueForTITRInMgDl : ConstantsStatistics.standardisedHighValueForTITRInMmol
        case .userDefinedRange:
            return UserDefaults.standard.highMarkValueInUserChosenUnit
        }
    }
    
    func rangeString() -> String {
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        return " (" + self.lowerLimit.bgValueToString(mgDl: isMgDl) + "-" + self.higherLimit.bgValueToString(mgDl: isMgDl) + ")"
        
    }
    
}
