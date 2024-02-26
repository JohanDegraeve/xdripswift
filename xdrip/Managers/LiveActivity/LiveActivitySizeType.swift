//
//  LiveActivitySizeType.swift
//  xdrip
//
//  Created by Paul Plant on 14/1/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// holds and returns the different parameters used for creating the images for different widget types
public enum LiveActivitySizeType: Int, CaseIterable, Codable {
    
    // when adding LiveActivitySizeType, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    // the order of the data source types will in the uiview is determined by the initializer init(forRowAt row: Int)
    
    case normal = 0
    case minimal = 1
    case large = 2
    
    var description: String {
        switch self {
        case .normal:
            return "Normal"
        case .minimal:
            return "Minimal"
        case .large:
            return "Large"
        }
    }
    
    /// gives the raw value of the LiveActivitySizeType for a specific section in a uitableview, is the opposite of the initializer
    static func LiveActivitySizeTypeRawValue(rawValue: Int) -> Int {
        
        switch rawValue {
            
        case 0:// normal
            return 0
        case 1:// minimal
            return 1
        case 2:// large
            return 2
        default:
            fatalError("in LiveActivitySizeType, unknown case")
            
        }
        
    }
    
}
