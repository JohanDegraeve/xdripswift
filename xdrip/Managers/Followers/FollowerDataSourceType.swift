//
//  FollowerDataSourceType.swift
//  xdrip
//
//  Created by Paul Plant on 25/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

/// To hide/ignore follower types at runtime, provide a key in the override file using rawValues in an array:
/// IGNORE_FOLLOWER_TYPES = [1,2]

/// Resolved disabled set (Info.plist wins, falls back to default, i.e. nothing ignored)
private var disabledFollowerDataSources: Set<FollowerDataSourceType> {
    let followerTypeArray = parseIgnoredFollowerTypes()
    return !followerTypeArray.isEmpty ? followerTypeArray : []
}

/// Read IgnoreFollowerTypes from Info.plist. Expects a JSON array of integer raw values (e.g. [1,3]).
private func parseIgnoredFollowerTypes() -> Set<FollowerDataSourceType> {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: "IgnoreFollowerTypes") as? String,
          !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let data = raw.data(using: .utf8),
          let ints = try? JSONDecoder().decode([Int].self, from: data) else {
        return []
    }
    // ensure that Nightscout cannot be disabled ever - we need to have one fallback FollowerDataSourceType
    return Set(ints.compactMap { FollowerDataSourceType(rawValue: $0) }).filter { $0 != .nightscout }
}

/// Note: Use FollowerDataSourceType.allEnabledCases to respect disabled sources when presenting choices in the picker list.
public enum FollowerDataSourceType: Int, CaseIterable {
    
    // when adding followerDataSourceTypes, add new cases at the end (ie 3, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    // the order of the data source types will in the uiview is determined by the initializer init(forRowAt row: Int)

    case nightscout = 0
    case libreLinkUp = 1
    case libreLinkUpRussia = 2
    case dexcomShare = 3

    /// All cases filtered to those currently enabled. Prefer this over 'allCases' when populating UI.
    static var allEnabledCases: [FollowerDataSourceType] {
        Self.allCases.filter { $0.isEnabled }
    }
    
    /// Validate a stored selection against current enabled cases. If invalid, return the first enabled case
    /// or fall back to the first declared case.
    static func validatedSelection(storedRawValue: Int?) -> FollowerDataSourceType {
        if let raw = storedRawValue, let type = FollowerDataSourceType(rawValue: raw), type.isEnabled {
            return type
        }
        return Self.allEnabledCases.first ?? Self.allCases.first!
    }
    
    /// Whether this data source is enabled for use (controlled by disabledFollowerDataSources).
    var isEnabled: Bool {
        !disabledFollowerDataSources.contains(self)
    }
    
    var description: String {
        switch self {
        case .nightscout:
            return "Nightscout"
        case .libreLinkUp:
            return "LibreLinkUp"
        case .libreLinkUpRussia:
            return "LibreLinkUp Russia"
        case .dexcomShare:
            return "Dexcom Share"
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
        case .libreLinkUpRussia:
            return "LibreLinkUp Russia"
        case .dexcomShare:
            return "Dexcom Share"
        }
    }
    
    var abbreviation: String {
        switch self {
        case .nightscout:
            return "NS"
        case .libreLinkUp, .libreLinkUpRussia:
            return "LL"
        case .dexcomShare:
            return "DS"
        }
    }
    
    var secondsUntilFollowerDisconnectWarning: Int {
        switch self {
        case .nightscout:
            return ConstantsFollower.secondsUntilFollowerDisconnectWarningNightscout
        case .libreLinkUp, .libreLinkUpRussia:
            return ConstantsFollower.secondsUntilFollowerDisconnectWarningLibreLinkUp
        case .dexcomShare:
            return ConstantsFollower.secondsUntilFollowerDisconnectWarningDexcomShare
        }
    }

    /// does this follower mode need a username and password?
    func needsUserNameAndPassword() -> Bool {
        switch self {
        case .nightscout:
            return false
        case .libreLinkUp, .libreLinkUpRussia, .dexcomShare:
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
        case .libreLinkUpRussia:
            return "LibreLinkUp Russia Follower"
        case .dexcomShare:
            return "Dexcom Share Follower"
        }
    }
    
}
