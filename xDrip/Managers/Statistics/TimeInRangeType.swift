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

    /// Lower boundary in the canonical unit used by stored glucose readings and shared analytics.
    ///
    /// Statistics used to convert every reading into the display unit and compare it with rounded
    /// mmol/L limits such as 3.9. That can classify a stored value of exactly 70 mg/dL differently
    /// from report and landscape analytics, which compare in mg/dL. Calculations now remain in the
    /// canonical unit. `lowerLimit` above is retained solely for user-facing text.
    var lowerLimitInMgDl: Double {
        switch self {
        case .standardRange, .tightRange:
            return ConstantsStatistics.standardisedLowValueForTIRInMgDl
        case .userDefinedRange:
            let storedValue = UserDefaults.standard.lowMarkValue
            return storedValue > 0 ? storedValue : ConstantsBGGraphBuilder.defaultLowMarkInMgdl
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

    /// Upper boundary in canonical mg/dL. See `lowerLimitInMgDl` for why range calculations must
    /// not be performed against rounded display-unit limits.
    var higherLimitInMgDl: Double {
        switch self {
        case .standardRange:
            return ConstantsStatistics.standardisedHighValueForTIRInMgDl
        case .tightRange:
            return ConstantsStatistics.standardisedHighValueForTITRInMgDl
        case .userDefinedRange:
            let storedValue = UserDefaults.standard.highMarkValue
            return storedValue > 0 ? storedValue : ConstantsBGGraphBuilder.defaultHighMarkInMgdl
        }
    }
    
    func rangeString() -> String {
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        return " (" + self.lowerLimit.bgValueToString(mgDl: isMgDl) + "-" + self.higherLimit.bgValueToString(mgDl: isMgDl) + ")"
        
    }
    
}
