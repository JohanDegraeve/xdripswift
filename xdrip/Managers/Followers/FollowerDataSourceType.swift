//
//  FollowerDataSourceType.swift
//  xdrip
//
//  Created by Paul Plant on 25/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

/// data source types such as nightscout, librelink, carelink, dexcom share etc...
public enum FollowerDataSourceType: Int, CaseIterable {
    
    // when adding followerDataSourceTypes, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    // the order of the data source types will in the uiview is determined by the initializer init(forRowAt row: Int)

    case nightscout = 0
    case libreLinkUp = 1

    /// this is used for presentation in UI table view. It allows to order the alert kinds in the view, different than they case ordering, and so allows to add new cases
    init?(forSection section: Int) {
        
        switch section {
            
        case 0:
            self = .nightscout
        case 1:
            self = .libreLinkUp
            
        default:
            fatalError("in FollowerDataSourceType initializer init(forRowAt row: Int), there's no case for the rownumber")
        }
        
    }
    
    var description: String {
        switch self {
        case .nightscout:
            return "Nightscout"
        case .libreLinkUp:
            return "LibreLinkUp"
        }
    }
    
    var abbreviation: String {
        switch self {
        case .nightscout:
            return "NS"
        case .libreLinkUp:
            return "LL"
        }
    }
    
    /// gives the raw value of the alertkind for a specific section in a uitableview, is the opposite of the initializer
    static func followerDataSourceTypeRawValue(forSection section: Int) -> Int {
        
        switch section {
        case 0:// nightscout
            return 0
        case 1:// libreLinkUp
            return 1
        default:
            fatalError("in dataSourceRawValue, unknown case")
        }
    }

    /// does this follower mode need a username and password?
    func needsUserNameAndPassword() -> Bool {
        switch self {
        case .nightscout:
            return false
        case .libreLinkUp:
            return true
        }
    }
    
    /// description of the follower mode to be used for logging
    func descriptionForLogging() -> String {
        switch self {
            
        case .nightscout:
            return "Nightscout Follower"
        case .libreLinkUp:
            return "LibreLinkUp Follower"
        }
    }
    
}
