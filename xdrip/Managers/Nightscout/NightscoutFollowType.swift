//
//  NightscoutFollowType.swift
//  xdrip
//
//  Created by Paul Plant on 24/10/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// type of nightscout follower to be used/displayed
/// for most users, this will just be basic
/// for users with AID, this choice will pull the correct data we need and adjust the UI to show the main available information
@objc public enum NightscoutFollowType: Int, CaseIterable, Codable {
    
    // override the allCases property to define our own order.
    // this must then be handled with the forRowAt options
    public static var allCasesForList: [NightscoutFollowType] {
        return [.none, .loop, .openAPS]
    }
    
    // when adding to nightscoutFollowType, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    
    case none = 0 // default upon initialization
    case loop = 1
    case openAPS = 2
    
    var description: String {
        switch self {
        case .none:
            return Texts_SettingsView.nightscoutFollowTypeNone
        case .loop:
            return Texts_SettingsView.nightscoutFollowTypeLoop
        case .openAPS:
            return Texts_SettingsView.nightscoutFollowTypeOpenAPS
        }
    }
    
    var descriptionExpanded: String {
        switch self {
        case .none:
            return Texts_SettingsView.nightscoutFollowTypeNoneExpanded
        case .loop:
            return Texts_SettingsView.nightscoutFollowTypeLoopExpanded
        case .openAPS:
            return Texts_SettingsView.nightscoutFollowTypeOpenAPSExpanded
        }
    }
    
    /// this is used for presentation in list. It allows to order the types in the view, different than they case ordering, and so allows to add new cases
    init?(forRowAt row: Int) {
        switch row {
        case 0:
            self = .none
        case 1:
            self = .loop
        case 2:
            self = .openAPS
        default:
            fatalError("in nightscoutFollowType initializer init(forRowAt row: Int), there's no case for the rownumber")
        }
    }
}
    
