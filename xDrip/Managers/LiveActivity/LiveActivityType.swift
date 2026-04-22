//
//  LiveActivityType.swift
//  xdrip
//
//  Created by Paul Plant on 1/1/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// type of live activity to be shown, if any
public enum LiveActivityType: Int, CaseIterable, Codable {
    
    // override the allCases property to define our own order.
    // this must then be handled with the forRowAt options
    public static var allCasesForList: [LiveActivityType] {
        return [.disabled, .minimal, .normal, .large]
    }
    
    // when adding to LiveActivityType, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    
    case disabled = 0 // default upon initialization
    case normal = 1
    case minimal = 2
    case large = 3
    
    var description: String {
        switch self {
        case .disabled:
            return Texts_SettingsView.liveActivityTypeDisabled
        case .normal:
            return Texts_SettingsView.liveActivityTypeNormal
        case .minimal:
            return Texts_SettingsView.liveActivityTypeMinimal
        case .large:
            return Texts_SettingsView.liveActivityTypeLarge
        }
    }
    
    var debugDescription: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .normal:
            return "Normal"
        case .minimal:
            return "Minimal"
        case .large:
            return "Large"
        }
    }
    
    /// this is used for presentation in list. It allows to order the types in the view, different than they case ordering, and so allows to add new cases
    init?(forRowAt row: Int) {
        switch row {
        case 0:
            self = .disabled
        case 1:
            self = .minimal
        case 2:
            self = .normal
        case 3:
            self = .large
        default:
            fatalError("in liveActivityType initializer init(forRowAt row: Int), there's no case for the rownumber")
        }
    }
    
}

