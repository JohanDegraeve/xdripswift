//
//  FollowerDataSourceType.swift
//  xdrip
//
//  Created by Paul Plant on 25/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

/// Declares whether glucose from a source may be published to an OS-AID app group.
///
/// Most sources are allowed. Sources that need a safety exception can either require the
/// existing explicit Medtrum consent or be blocked completely.
enum OSAidSharingPolicy: Equatable {
    case allowed
    case requiresExplicitConsent
    case blocked

    func permitsSharing(hasExplicitConsent: Bool) -> Bool {
        switch self {
        case .allowed:
            return true
        case .requiresExplicitConsent:
            return hasExplicitConsent
        case .blocked:
            return false
        }
    }
}

/// To hide follower types at runtime, provide their stored raw values in the override file:
/// IGNORE_FOLLOWER_TYPES = [1,2]
private var disabledFollowerDataSources: Set<FollowerDataSourceType> {
    parseIgnoredFollowerTypes()
}

/// The build setting reaches the app as a JSON array stored in Info.plist.
private func parseIgnoredFollowerTypes() -> Set<FollowerDataSourceType> {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: "IgnoreFollowerTypes") as? String,
          !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let data = raw.data(using: .utf8),
          let ints = try? JSONDecoder().decode([Int].self, from: data) else {
        return []
    }
    // Nightscout is the safe fallback for a removed or invalid stored selection.
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
    case medtrumEasyView = 4
    case calendar = 5
    // Persisted raw values are append-only. Never move CareLink ahead of existing cases.
    case careLink = 6

    /// UI display order for the follower source picker.
    ///
    /// Keep the enum cases and raw values stable because they are stored.
    /// Change this list only when the visible picker order needs to change.
    static var allCasesForList: [FollowerDataSourceType] {
        [
            .nightscout,
            .dexcomShare,
            .calendar,
            .careLink,
            .libreLinkUp,
            .libreLinkUpRussia,
            .medtrumEasyView
        ]
    }

    /// Display-ordered cases available in the current build.
    static var allEnabledCases: [FollowerDataSourceType] {
        Self.allCasesForList.filter { $0.isEnabled }
    }

    /// Preserves valid stored values and falls back safely when a build hides that source.
    static func validatedSelection(
        storedRawValue: Int?,
        enabledCases: [FollowerDataSourceType] = FollowerDataSourceType.allEnabledCases
    ) -> FollowerDataSourceType {
        if let raw = storedRawValue,
           let type = FollowerDataSourceType(rawValue: raw),
           enabledCases.contains(type) {
            return type
        }
        return enabledCases.first ?? .nightscout
    }
    
    /// Whether this data source is enabled for use (controlled by disabledFollowerDataSources).
    var isEnabled: Bool {
        !disabledFollowerDataSources.contains(self)
    }

    /// EasyView can represent a CGM-only follower use case, so retain its existing warned consent
    /// path. All other follower sources remain allowed by default.
    var osAidSharingPolicy: OSAidSharingPolicy {
        switch self {
        case .medtrumEasyView:
            return .requiresExplicitConsent
        default:
            return .allowed
        }
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
        case .medtrumEasyView:
            return "Medtrum EasyView"
        case .calendar:
            return "Shared Calendar"
        case .careLink:
            return "CareLink"
        }
    }
    
    // shorter description for compact UI surfaces like the Watch app
    var shortDescription: String {
        switch self {
        case .nightscout:
            return "Nightscout"
        case .libreLinkUp, .libreLinkUpRussia:
            return "LibreLinkUp"
        case .dexcomShare:
            return "Dex Share"
        case .medtrumEasyView:
            return "Medtrum"
        case .calendar:
            return "Calendar"
        case .careLink:
            return "CareLink"
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
        case .medtrumEasyView:
            return "ME"
        case .calendar:
            return "CAL"
        case .careLink:
            return "CL"
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
        case .medtrumEasyView:
            return ConstantsFollower.secondsUntilFollowerDisconnectWarningMedtrumEasyView
        case .calendar:
            return ConstantsFollower.secondsUntilFollowerDisconnectWarningNightscout
        case .careLink:
            return 20 * 60
        }
    }

    /// description of the follower mode to be used for logging
    func descriptionForLogging() -> String {
        description + " Follower"
    }
}
