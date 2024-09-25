//
//  CalibrationType.swift
//  xdrip
//
//  Created by Paul Plant on 22/8/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// types of live activity, namely when we should show the live activities
public enum CalibrationType: Int, CaseIterable {
    
    // when adding to LiveActivityType, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    
    case singlePoint = 0
    case multiPoint = 1
    
    var description: String {
        switch self {
        case .singlePoint:
            return Texts_Calibrations.singlePointCalibration
        case .multiPoint:
            return Texts_Calibrations.multiPointCalibration
        }
    }
    
}


