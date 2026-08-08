//
//  DataFlowPolicy.swift
//  xdripswift
//
//  Created by Paul Plant on 2/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Selects the one remote service that is allowed to import treatments and pump information.
///
/// Glucose ownership remains controlled by Master/Follower mode and `FollowerDataSourceType`.
/// Keeping therapy ownership separate allows, for example, Dexcom Share glucose with Nightscout
/// treatments, or CareLink glucose with either CareLink pump data or Nightscout OS-AID data.
/// Raw values are persisted, so new cases must only be appended.
enum TherapyDataSourceType: Int, CaseIterable {
    case automatic = 0
    case none = 1
    case nightscout = 2
    case careLink = 3

    var description: String {
        switch self {
        case .automatic:
            return Texts_SettingsView.therapyDataSourceAutomatic
        case .none:
            return Texts_SettingsView.therapyDataSourceNone
        case .nightscout:
            return "Nightscout"
        case .careLink:
            return "CareLink"
        }
    }
}

/// Immutable inputs used to resolve every cross-service data-flow decision.
///
/// Managers receive the resulting policy instead of independently interpreting the same settings.
/// This makes loop prevention and CareLink pump import testable without network requests.
struct DataFlowPolicy {
    let isMaster: Bool
    let followerDataSource: FollowerDataSourceType
    let therapyDataSourceSelection: TherapyDataSourceType
    let nightscoutEnabled: Bool
    let masterUploadsGlucoseToNightscout: Bool
    let followerUploadsGlucoseToNightscout: Bool
    let nightscoutFollowType: NightscoutFollowType

    /// The effective therapy source after applying availability and Automatic-mode rules.
    ///
    /// CareLink is valid only while CareLink supplies glucose, which prevents pump and glucose data
    /// from silently referring to different patients. Nightscout remains available in every mode.
    var therapyDataSource: TherapyDataSourceType {
        switch therapyDataSourceSelection {
        case .automatic:
            return automaticTherapyDataSource
        case .careLink:
            return !isMaster && followerDataSource == .careLink ? .careLink : automaticTherapyDataSource
        case .nightscout:
            return nightscoutEnabled ? .nightscout : .none
        case .none:
            return .none
        }
    }

    /// Sources that make sense in the current mode. Automatic and None are always retained so the
    /// user can either accept the safe default or explicitly disable remote therapy imports.
    var availableTherapyDataSources: [TherapyDataSourceType] {
        var sources: [TherapyDataSourceType] = [.automatic]

        if nightscoutEnabled {
            sources.append(.nightscout)
        }

        if !isMaster && followerDataSource == .careLink {
            sources.append(.careLink)
        }

        sources.append(.none)
        return sources
    }

    /// A Nightscout follower reads glucose from Nightscout and must never write those readings back.
    var importsGlucoseFromNightscout: Bool {
        nightscoutEnabled && !isMaster && followerDataSource == .nightscout
    }

    /// Nightscout glucose export is independent of therapy import ownership.
    var exportsGlucoseToNightscout: Bool {
        guard nightscoutEnabled else { return false }

        if isMaster {
            return masterUploadsGlucoseToNightscout
        }

        return followerDataSource != .nightscout && followerUploadsGlucoseToNightscout
    }

    /// Treatments are downloaded only when Nightscout is the authoritative therapy source.
    var importsTreatmentsFromNightscout: Bool {
        nightscoutEnabled && therapyDataSource == .nightscout
    }

    /// Local treatments can continue to be exported regardless of which service supplied them.
    /// Authentication and URL checks remain the responsibility of `NightscoutSyncManager`.
    var exportsTreatmentsToNightscout: Bool {
        nightscoutEnabled
    }

    /// Profile and device-status requests are the optional OS-AID layer on top of treatment sync.
    var importsStatusFromNightscout: Bool {
        importsTreatmentsFromNightscout && nightscoutFollowType != .none
    }

    /// CareLink treatment and pump parsing uses this gate before creating local records.
    var importsTherapyFromCareLink: Bool {
        !isMaster && followerDataSource == .careLink && therapyDataSource == .careLink
    }

    /// Pump surfaces are meaningful for either CareLink pump data or Nightscout OS-AID status.
    var showsPumpData: Bool {
        importsTherapyFromCareLink || importsStatusFromNightscout
    }

    /// CareLink supplies pump data but not an external OS-AID loop record.
    var showsAIDData: Bool {
        importsStatusFromNightscout
    }

    /// The compact Home therapy strip opens either OS-AID status or CareLink pump details.
    var showsTherapyStatus: Bool {
        importsStatusFromNightscout || importsTherapyFromCareLink
    }

    private var automaticTherapyDataSource: TherapyDataSourceType {
        if !isMaster && followerDataSource == .careLink {
            return .careLink
        }

        return nightscoutEnabled ? .nightscout : .none
    }
}
