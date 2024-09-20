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
    
    public var rawValue: Int {
        switch self {
        case .nightscout:
            return 0
        case .libreLinkUp:
            return 1
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
    
    // this is an alternate description to be used by the UI away from the "choose a data source" context.
    // it is basically a full description of "XXXX Follower Mode" and can be modified for available space
    var fullDescription: String {
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
    
    var secondsUntilFollowerDisconnectWarning: Int {
        switch self {
        case .nightscout:
            return ConstantsFollower.secondsUntilFollowerDisconnectWarningNightscout
        case .libreLinkUp:
            return ConstantsFollower.secondsUntilFollowerDisconnectWarningLibreLinkUp
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
