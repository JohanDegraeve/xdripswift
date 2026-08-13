//
//  FollowerBackgroundKeepAliveType.swift
//  xdrip
//
//  Created by Paul Plant on 12/11/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

/// types of background keep-alive
public enum FollowerBackgroundKeepAliveType: Int, CaseIterable {
    
    // when adding to FollowerBackgroundKeepAliveType, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    // the order of the returned enum can be defined in allCases below
    
    case disabled = 0
    case normal = 1
    case aggressive = 2
    case heartbeat = 3
    case continuous = 4

    /// The menu order groups the three silent-audio choices together without changing persisted
    /// raw values. `continuous` remains appended as raw value 4 for storage compatibility.
    public static let allCases: [FollowerBackgroundKeepAliveType] = [
        .disabled,
        .normal,
        .aggressive,
        .continuous,
        .heartbeat
    ]
    
    var description: String {
        switch self {
        case .disabled:
            return Texts_SettingsView.followerKeepAliveTypeDisabled
        case .normal:
            return Texts_SettingsView.followerKeepAliveTypeNormal
        case .aggressive:
            return Texts_SettingsView.followerKeepAliveTypeAggressive
        case .continuous:
            return Texts_SettingsView.followerKeepAliveTypeContinuous
        case .heartbeat:
            return Texts_SettingsView.followerKeepAliveTypeHeartbeat
        }
    }
    
    public var rawValue: Int {
        switch self {
        case .disabled:
            return 0
        case .normal:
            return 1
        case .aggressive:
            return 2
        case .heartbeat:
            return 3
        case .continuous:
            return 4
        }
    }
    
    // return the keep-alive image for SwiftUI views
    var keepAliveImageString: String {
        switch self {
        case .disabled:
            return "d.circle"
        case .normal:
            return "n.circle"
        case .aggressive:
            return "a.circle"
        case .continuous:
            return "c.circle"
        case .heartbeat:
            return "heart.circle"
        }
    }
    
    // return the keep-alive image for SwiftUI views
    var keepAliveImage: Image {
        return Image(systemName: keepAliveImageString)
    }
    
}
