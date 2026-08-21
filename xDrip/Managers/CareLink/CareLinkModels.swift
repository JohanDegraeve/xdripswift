//
//  CareLinkModels.swift
//  xdripswift
//
//  Created by Paul Plant on 1/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//
//  CareLink follower protocol and state models.
//

import Foundation

// MARK: - Authentication and region

/// Thread-safe gate for UI and navigation callbacks that may discover login completion together.
final class CareLinkOneShot {
    private let lock = NSLock()
    private var hasRun = false

    /// Runs `action` only for the first caller and returns whether that caller won the race.
    @discardableResult func run(_ action: () -> Void) -> Bool {
        lock.lock()
        guard !hasRun else {
            lock.unlock()
            return false
        }
        hasRun = true
        lock.unlock()
        action()
        return true
    }
}

/// Selects Medtronic's independently hosted US or Outside-US CareLink environment.
enum CareLinkRegion: String, Codable, CaseIterable {
    case unitedStates
    case outsideUnitedStates

    /// Provides a first-login default only. A persisted user selection is authoritative afterward.
    static var inferred: CareLinkRegion {
        Locale.current.region?.identifier.uppercased() == "US" ? .unitedStates : .outsideUnitedStates
    }

    /// User-facing region label used consistently in Settings and recovery messages.
    var title: String {
        switch self {
        case .unitedStates: return Texts_SettingsView.careLinkUnitedStates
        case .outsideUnitedStates: return Texts_SettingsView.careLinkOutsideUnitedStatesLong
        }
    }

    /// Account and legacy fallback routes use the regional CareLink web host.
    var webBaseURL: URL {
        URL(string: self == .unitedStates ? "https://carelink.minimed.com" : "https://carelink.minimed.eu")!
    }
}

// MARK: - Observable connection state

/// Stable states presented in the follower row and the detailed CareLink status screen.
enum CareLinkConnectionStatus: String, Codable {
    case loginRequired
    case connecting
    case selectPatient
    case noData
    case active
    case stale
    case rateLimited
    case error

    /// Concise label for the parent follower Status row.
    var title: String {
        switch self {
        case .loginRequired: return Texts_SettingsView.followerLogInRequired
        case .connecting: return Texts_SettingsView.careLinkConnecting
        case .selectPatient: return Texts_SettingsView.followerSelectPatient
        case .noData: return Texts_SettingsView.careLinkNoData
        case .active: return Texts_SettingsView.careLinkActive
        case .stale: return Texts_SettingsView.followerStale
        case .rateLimited: return Texts_SettingsView.careLinkRateLimited
        case .error: return Texts_SettingsView.careLinkError
        }
    }
}

/// Optional convenience values for Medtronic's page; OAuth never uses them in API requests.
struct CareLinkLoginPrefill: Equatable {
    let username: String?
    let password: String?

    static func stored(in defaults: UserDefaults = .standard) -> CareLinkLoginPrefill {
        let username = defaults.careLinkUsername?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CareLinkLoginPrefill(
            username: username?.isEmpty == false ? username : nil,
            password: defaults.careLinkPassword?.isEmpty == false ? defaults.careLinkPassword : nil
        )
    }
}

/// Central timing policy shared by the manager and deterministic scheduler tests.
enum CareLinkPollingPolicy {
    /// Calculates the next data request using the xDrip+ CareLink Follow strategy.
    ///
    /// Initial testing of the fixed request cadence triggered CareLink server throttling, so the
    /// scheduler now follows the xDrip+ strategy and waits for the next expected sample.
    /// CareLink can return a glucose value before its nominal five-minute timestamp, which was
    /// observed during initial live testing. `lastMedicalDeviceDataUpdateServerTime` therefore
    /// becomes the preferred anchor. The glucose timestamp is only the fallback and is clamped to
    /// `now`, so a future nominal glucose time cannot postpone the next expected update. When the
    /// chosen timestamp does not advance, the scheduler naturally moves to one-minute retries.
    static func nextPollDate(latestReadingAt: Date?, lastDataUpdateAt: Date?, now: Date) -> Date {
        let anchor = lastDataUpdateAt.map { min($0, now) }
            ?? latestReadingAt.map { min($0, now) }

        guard let anchor else {
            return now.addingTimeInterval(ConstantsCareLink.missedDataPollingInterval)
        }

        let firstExpectedPoll = anchor.addingTimeInterval(
            ConstantsCareLink.samplePeriod + ConstantsCareLink.pollingGracePeriod
        )
        let candidate: Date
        if firstExpectedPoll > now {
            candidate = firstExpectedPoll
        } else {
            let elapsed = now.timeIntervalSince(firstExpectedPoll)
            let missedIntervals = floor(elapsed / ConstantsCareLink.missedDataPollingInterval) + 1
            candidate = firstExpectedPoll.addingTimeInterval(
                missedIntervals * ConstantsCareLink.missedDataPollingInterval
            )
        }
        return max(candidate, now.addingTimeInterval(ConstantsCareLink.minimumPollingInterval))
    }

    /// Evaluates reading age even when the most recent network request succeeded.
    static func isStale(lastReadingAt: Date?, now: Date) -> Bool {
        guard let lastReadingAt else { return true }
        return now.timeIntervalSince(lastReadingAt) > ConstantsCareLink.staleReadingAge
    }

    /// Bounds transient network/server backoff at five minutes so recovery remains automatic.
    static func backoff(failureCount: Int) -> TimeInterval {
        min(
            ConstantsCareLink.initialRetryBackoff * pow(2, Double(max(0, failureCount - 1))),
            ConstantsCareLink.maximumRetryBackoff
        )
    }
}

/// Resolves a retained or unambiguous patient without depending on UI state.
enum CareLinkPatientSelection {
    /// Retains a valid selection, auto-selects exactly one patient, otherwise requires a choice.
    static func resolve(patients: [CareLinkPatient], savedID: String?) -> String? {
        if let savedID, patients.contains(where: { $0.id == savedID || $0.username == savedID }) {
            return savedID
        }
        return patients.count == 1 ? patients[0].id : nil
    }
}

/// Normalizes the role names observed in the two CareLink regional environments.
enum CareLinkAccountRole {
    static func isCarePartner(_ role: String?) -> Bool {
        role == "CARE_PARTNER" || role == "CARE_PARTNER_OUS"
    }

    static func isPatient(_ role: String?) -> Bool {
        role == "PATIENT" || role == "PATIENT_OUS"
    }

    /// Family/caregiver followers and professional followers share Medtronic's Care Partner role.
    static func isSupportedFollower(_ role: String?) -> Bool {
        isPatient(role) || isCarePartner(role)
    }
}

/// Maps protocol failures onto the small user-facing connection-state vocabulary.
enum CareLinkStatePolicy {
    /// Keeps pure state mapping reusable by the manager and unit tests.
    static func status(for error: CareLinkError) -> CareLinkConnectionStatus {
        switch error {
        case .notAuthenticated, .reconnectRequired, .regionMismatch, .accountRejected: return .loginRequired
        case .rateLimited: return .rateLimited
        case .noGlucoseData: return .noData
        default: return .error
        }
    }

    /// Distinguishes a healthy service response from a pump that has lost its phone relay.
    /// Historical glucose remains importable, but the follower must not advertise live delivery.
    static func status(hasGlucose: Bool, lastReadingAt: Date?, pump: CareLinkPumpSnapshot, now: Date) -> CareLinkConnectionStatus {
        if pump.isCommunicating == false || pump.isInRange == false { return .noData }
        guard hasGlucose else { return .noData }
        return CareLinkPollingPolicy.isStale(lastReadingAt: lastReadingAt, now: now) ? .stale : .active
    }

    /// Gives a successful but disconnected pump response a clear recovery explanation.
    static func detail(hasGlucose: Bool, pump: CareLinkPumpSnapshot) -> String? {
        if pump.isCommunicating == false || pump.isInRange == false {
            return Texts_SettingsView.careLinkPumpNotCommunicating
        }
        return hasGlucose ? nil : Texts_SettingsView.careLinkNoGlucoseReadings
    }
}

// MARK: - Account and protocol models

/// Glucose API families shared by patient and Care Partner accounts.
enum CareLinkDataRoute: String, Codable {
    case monitor
    case periodic
    case guardianM2M
    case legacyConnect
}

/// A patient represented either by the authenticated account or by a Care Partner link.
struct CareLinkPatient: Codable, Equatable, Identifiable {
    let id: String
    let username: String
    let firstName: String?
    let lastName: String?

    /// Uses returned names when available and falls back to the stable CareLink username.
    var displayName: String {
        let name = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? username : name
    }
}

/// Best-effort account, device and sensor facts displayed for troubleshooting.
/// Fields remain optional because payload content differs by pump and CGM generation.
struct CareLinkMetadata: Codable, Equatable {
    var accountName: String?
    var role: String?
    var countryCode: String?
    var patientName: String?
    var deviceFamily: String?
    var deviceModel: String?
    var deviceSerial: String?
    var sensorType: String?
    var sensorState: String?
    var sensorRemainingMinutes: Int?
    var route: CareLinkDataRoute?
}

/// Normalized pump information shared by Settings, Home and the CareLink detail screen.
///
/// CareLink payloads use different names across pump generations. Keeping that protocol detail
/// out of the views prevents each screen from interpreting the same response differently.
struct CareLinkPumpSnapshot: Equatable {
    var observedAt: Date?
    var lastDataUpdateAt: Date?
    var activeInsulin: Double?
    var activeInsulinAt: Date?
    var currentBasalRate: Double?
    var reservoirUnits: Double?
    var reservoirPercent: Int?
    var batteryPercent: Int?
    var isSuspended: Bool?
    var isCommunicating: Bool?
    var isInRange: Bool?
    var algorithmState: String?
    var algorithmReadiness: String?
    var lowGlucoseSuspendState: String?
    var maximumAutoBasalRate: Double?
    var maximumBolusAmount: Double?

    /// Medtronic uses the shield for active SmartGuard automatic basal states.
    /// Unknown and disabled states remain ordinary pump status rather than inferred automation.
    var reportsActiveSmartGuard: Bool {
        guard let state = algorithmState?.uppercased() else { return false }
        return state == "AUTO_BASAL" || state == "SAFE_BASAL"
    }

    /// Uses CareLink's pump communication flags for the status shown and stored by the app.
    /// A suspended pump remains the more clinically useful state when both conditions are reported.
    var pumpStatusTitle: String {
        if isSuspended == true { return Texts_SettingsView.careLinkSuspended }
        if isCommunicating == false || isInRange == false { return Texts_SettingsView.careLinkDisconnected }
        return Texts_SettingsView.careLinkActive
    }
}

/// One CareLink treatment ready for the app's existing treatment pipeline.
///
/// `value` is insulin units, carbohydrate grams or basal units per hour according to `type`.
/// Basal `durationMinutes` is stored in `TreatmentEntry.valueSecondary` for Nightscout export.
struct CareLinkTherapyRecord: Equatable {
    let sourceIdentifier: String
    let date: Date
    let type: TreatmentType
    let value: Double
    let durationMinutes: Double
    let nightscoutEventType: String
    let notes: String?
}

/// Parsing result produced from the same response that carries CareLink glucose readings.
struct CareLinkTherapyPayload: Equatable {
    var pump = CareLinkPumpSnapshot()
    var treatments: [CareLinkTherapyRecord] = []
}

/// One immutable-at-publication view of the manager's account and polling state.
/// `CareLinkAccountState` publishes this value on the main actor for SwiftUI and Settings.
struct CareLinkStatusSnapshot: Equatable {
    var status: CareLinkConnectionStatus = .connecting
    var region: CareLinkRegion = .inferred
    var patients: [CareLinkPatient] = []
    var selectedPatientID: String?
    var metadata = CareLinkMetadata()
    var lastReadingAt: Date?
    var lastCheckAt: Date?
    var lastTokenRefreshAt: Date?
    var rateLimitedUntil: Date?
    var serviceReachable: Bool?
    var detail: String?
    var pump = CareLinkPumpSnapshot()
    var importedTreatmentCount = 0
    var lastTherapyImportAt: Date?
    var importedPumpStatusCount = 0
    var lastPumpHistoryImportAt: Date?

    /// Resolves both modern IDs and legacy username-based saved selections.
    var selectedPatient: CareLinkPatient? {
        patients.first { $0.id == selectedPatientID || $0.username == selectedPatientID }
    }
}

extension CareLinkStatusSnapshot {
    /// CareLink has no Nightscout device-status record. Its server/pump update time is also the
    /// freshness anchor because nominal glucose timestamps were observed ahead of server delivery.
    var aidStatus: AIDStatus {
        let observedAt = pump.observedAt ?? pump.lastDataUpdateAt
        let condition: AIDStatusCondition

        if status == .connecting && observedAt == nil {
            condition = .checking
        } else if pump.isSuspended == true {
            condition = .suspended
        } else if pump.isCommunicating == false || pump.isInRange == false {
            condition = .disconnected
        } else {
            condition = .active
        }

        let activeTitle = pump.algorithmState.map {
            $0.replacingOccurrences(of: "_", with: " ").capitalized
        } ?? Texts_SettingsView.careLinkActive

        let statusTitle: String
        switch condition {
        case .checking: statusTitle = Texts_Common.checking
        case .suspended: statusTitle = Texts_SettingsView.careLinkSuspended
        case .disconnected: statusTitle = Texts_SettingsView.careLinkDisconnected
        case .active: statusTitle = activeTitle
        }

        return AIDStatus(
            condition: condition,
            style: pump.reportsActiveSmartGuard ? .careLinkSmartGuard : .careLinkPump,
            statusUpdatedAt: observedAt,
            lastActivityAt: observedAt,
            iob: pump.activeInsulin,
            // CareLink's periodic response provides active insulin and discrete MEAL markers, but
            // not a remaining active-carbohydrate value. A meal amount cannot safely stand in for
            // COB because the response provides no absorption/decay calculation for those grams.
            cob: nil,
            statusTitle: statusTitle,
            staleStatusTitle: Texts_SettingsView.careLinkNoData
        )
    }
}

struct CareLinkAPIConfiguration: Equatable {
    let careLinkBaseURL: URL
}

/// Public configuration selected from Medtronic's CarePartner discovery documents.
struct CareLinkOAuthConfiguration: Codable, Equatable {
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let revocationEndpoint: URL
    let clientID: String
    let scope: String
    let redirectURI: URL
    let audience: String
}

/// Secrets that exist only while one browser authorization is in progress.
struct CareLinkAuthorizationTransaction: Equatable {
    let authorizationURL: URL
    let configuration: CareLinkOAuthConfiguration
    let state: String
    let codeVerifier: String
}

/// CarePartner OAuth credential persisted in Keychain for background token rotation.
struct CareLinkToken: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var region: CareLinkRegion
    var countryCode: String?
    var oauthConfiguration: CareLinkOAuthConfiguration

    func needsRefresh(at date: Date) -> Bool {
        expiresAt.timeIntervalSince(date) < ConstantsCareLink.oauthRefreshMargin
    }
}

/// Typed failures used to preserve actionable UI state without exposing session credentials.
/// Debug builds may trace non-secret response bodies to support closed protocol testing.
enum CareLinkError: LocalizedError, Equatable {
    case invalidConfiguration
    case invalidCallback
    case cancelled
    case notAuthenticated
    case unsupportedRole(CareLinkMetadata)
    case patientIdentityMissing
    case patientSelectionRequired
    case reconnectRequired
    case regionMismatch(selected: CareLinkRegion, authenticated: CareLinkRegion)
    case accountRejected(CareLinkRegion)
    case rateLimited(Date)
    case noGlucoseData
    case http(Int)
    case malformedResponse
    case offline

    /// Provides actionable, non-sensitive copy suitable for the native status screen.
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return Texts_SettingsView.careLinkLoginOpenFailed
        case .invalidCallback: return Texts_SettingsView.careLinkInvalidLoginResponse
        case .cancelled: return Texts_SettingsView.careLinkLoginCancelled
        case .notAuthenticated: return Texts_SettingsView.careLinkLoginToContinue
        case .unsupportedRole: return Texts_SettingsView.careLinkUnsupportedAccount
        case .patientIdentityMissing: return Texts_SettingsView.careLinkPatientIdentityMissing
        case .patientSelectionRequired: return Texts_SettingsView.careLinkSelectPatient
        case .reconnectRequired: return Texts_SettingsView.careLinkSessionExpired
        case let .regionMismatch(selected, authenticated):
            return Texts_SettingsView.careLinkRegionMismatch(authenticated: authenticated.title, selected: selected.title)
        case let .accountRejected(region):
            let alternative = region == .unitedStates ? CareLinkRegion.outsideUnitedStates : .unitedStates
            return Texts_SettingsView.careLinkAccountRejected(region: region.title, alternative: alternative.title)
        case .rateLimited: return Texts_SettingsView.careLinkTemporarilyRateLimited
        case .noGlucoseData: return Texts_SettingsView.careLinkNoAccountGlucose
        case let .http(code): return Texts_SettingsView.careLinkHTTPError(code)
        case .malformedResponse: return Texts_SettingsView.careLinkMalformedResponse
        case .offline: return Texts_SettingsView.careLinkOffline
        }
    }
}
