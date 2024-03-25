//
//  FollowerBackgroundKeepAliveType.swift
//  xdrip
//
//  Created by Paul Plant on 12/11/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
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
    
    var description: String {
        switch self {
        case .disabled:
            return Texts_SettingsView.followerKeepAliveTypeDisabled
        case .normal:
            return Texts_SettingsView.followerKeepAliveTypeNormal
        case .aggressive:
            return Texts_SettingsView.followerKeepAliveTypeAggressive
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
        }
    }
    
    // return true if in follower mode and if the keep-alive type should provoke a background keep-alive action
    // basically if not .disabled and if not .heartbeat
    var shouldKeepAlive: Bool {
        switch self {
        case .disabled, .heartbeat:
            return false
        default:
            return true
        }
    }
    
    // return the keep-alive image for UIKit views
    var keepAliveUIImage: UIImage {
        switch self {
        case .disabled:
            return UIImage(systemName: "d.circle") ?? UIImage()
        case .normal:
            return UIImage(systemName: "n.circle") ?? UIImage()
        case .aggressive:
            return UIImage(systemName: "a.circle") ?? UIImage()
        case .heartbeat:
            return UIImage(systemName: "heart.circle") ?? UIImage()
        }
    }
    
    // return the keep-alive image for SwiftUI views
    var keepAliveImage: Image {
        switch self {
        case .disabled:
            return Image(systemName: "d.circle")
        case .normal:
            return Image(systemName: "n.circle")
        case .aggressive:
            return Image(systemName: "a.circle")
        case .heartbeat:
            return Image(systemName: "heart.circle")
        }
    }
    
}
