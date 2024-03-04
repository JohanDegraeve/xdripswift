//
//  LiveActivitySize.swift
//  xdrip
//
//  Created by Paul Plant on 14/1/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// what size should the live activity notification be?
public enum LiveActivitySize: Int, CaseIterable, Codable {
    
    // when adding liveActivitySize, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    // the order of the data source types will in the uiview is determined by the initializer init(forRowAt row: Int)
    
    // override the allCases property to define our own order.
    // this must then be handled with the forRowAt options
    public static var allCasesForList: [LiveActivitySize] {
        return [.minimal, .normal, .large]
    }
    
    case normal = 0 // default upon initialization
    case minimal = 1
    case large = 2
    
    var description: String {
        switch self {
        case .normal:
            return Texts_SettingsView.liveActivitySizeNormal
        case .minimal:
            return Texts_SettingsView.liveActivitySizeMinimal
        case .large:
            return Texts_SettingsView.liveActivitySizeLarge
        }
    }
    
    /// this is used for presentation in list. It allows to order the size kinds in the view, different than they case ordering, and so allows to add new cases
    init?(forRowAt row: Int) {
        switch row {
        case 0:
            self = .minimal
        case 1:
            self = .normal
        case 2:
            self = .large
        default:
            fatalError("in liveActivitySize initializer init(forRowAt row: Int), there's no case for the rownumber")
        }
    }
    
}
