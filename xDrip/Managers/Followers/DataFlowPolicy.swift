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

/// Identifies the configured source that can build the AID-enhanced Statistics and report data.
///
/// This deliberately describes an analytics capability, not the live AID status shown on Home.
/// Nightscout publishes an external Loop/OpenAPS device-status stream, while CareLink publishes
/// native pump, treatment and proven SmartGuard automatic-basal history. Both can support clinical
/// analytics, but their available fields and calculations are different.
///
/// Keeping the source typed prevents report code from reconstructing the decision from several
/// UserDefaults values and prevents CareLink from being mistaken for a Nightscout loop by alerts,
/// Watch status or other real-time consumers of `showsAIDData`.
enum AIDAnalyticsSource: Hashable, Sendable {
    case nightscout(NightscoutFollowType)
    case careLink

    /// Nightscout AID device status can contain the loop algorithm's calculated COB series.
    /// CareLink contributes meal-treatment entries only, so reports can show carb announcements
    /// but must not claim that the remaining active carbohydrates or their decay are known.
    var supportsCOB: Bool {
        switch self {
        case .nightscout:
            return true
        case .careLink:
            return false
        }
    }

    /// Scheduled-basal analytics require an imported basal profile. Nightscout provides that
    /// profile and delivered temp-basal values, so reports can show the scheduled profile and the
    /// delta between scheduled and delivered basal. CareLink provides automatic-basal deliveries
    /// but no scheduled basal profile, so neither chart can be calculated accurately.
    var supportsScheduledBasalAnalytics: Bool {
        switch self {
        case .nightscout:
            return true
        case .careLink:
            return false
        }
    }

    /// Device-status history shares one normalized Core Data store. Source ownership must therefore
    /// be applied whenever analytics are read, especially after a user changes therapy source.
    func ownsDeviceStatus(with identifier: String?) -> Bool {
        let isCareLink = identifier?.hasPrefix("carelink://") == true

        switch self {
        case .nightscout:
            return !isCareLink
        case .careLink:
            return isCareLink
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

    /// The one effective provider for AID-enhanced Statistics and clinical reports.
    ///
    /// This decision is intentionally based on resolved import ownership rather than the raw
    /// therapy picker selection:
    /// - Nightscout qualifies only when it owns therapy imports and an AID follow type is selected.
    /// - CareLink qualifies only in follower mode when it owns both CareLink glucose and therapy.
    /// - A disabled or unavailable selection resolves through `therapyDataSource` before arriving
    ///   here, so presentation and analytics cannot disagree with the managers doing the import.
    ///
    /// A non-nil source means the configuration can provide AID-related information. Individual
    /// metrics must still require enough persisted evidence before they are displayed or reported.
    var aidAnalyticsSource: AIDAnalyticsSource? {
        if importsTherapyFromCareLink {
            return .careLink
        }

        if importsStatusFromNightscout {
            return .nightscout(nightscoutFollowType)
        }

        return nil
    }

    /// Convenience for UI that only needs eligibility. Analytics code should retain the typed
    /// source so it can select the correct status, treatment and profile calculations.
    var supportsAIDEnhancedAnalytics: Bool {
        aidAnalyticsSource != nil
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
