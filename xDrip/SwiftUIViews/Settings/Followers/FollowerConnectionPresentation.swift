//
//  FollowerConnectionPresentation.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import EventKit
import Foundation
import SwiftUI

/// Connection state shown by both the parent Status row and the child banner.
/// Public service availability is separate and never changes this state.
enum FollowerConnectionState: Equatable {
    case notConfigured
    case loginRequired
    case checking
    case acceptTerms
    case selectPatient
    case connected
    case stale
    case failed

    var title: String {
        switch self {
        case .notConfigured: return Texts_SettingsView.followerNotConfigured
        case .loginRequired: return Texts_SettingsView.followerLogInRequired
        case .checking: return Texts_Common.checking
        case .acceptTerms: return Texts_SettingsView.followerAcceptTerms
        case .selectPatient: return Texts_SettingsView.followerSelectPatient
        case .connected: return Texts_SettingsView.followerConnected
        case .stale: return Texts_SettingsView.followerStale
        case .failed: return Texts_SettingsView.followerConnectionFailed
        }
    }

    var color: Color {
        switch self {
        case .notConfigured, .loginRequired: return .gray
        case .checking, .selectPatient: return ConstantsAppColors.warning
        case .connected: return ConstantsAppColors.normal
        case .stale: return .orange
        case .acceptTerms, .failed: return ConstantsAppColors.urgent
        }
    }

    /// Connecting is normal activity. Only its indicator changes colour while it is in progress.
    var titleColor: Color {
        self == .checking ? .primary : color
    }

    var symbolName: String {
        switch self {
        case .notConfigured, .loginRequired: return "person.crop.circle.badge.questionmark"
        case .checking: return "arrow.triangle.2.circlepath"
        case .acceptTerms: return "exclamationmark.triangle.fill"
        case .selectPatient: return "person.2.badge.gearshape.fill"
        case .connected: return "checkmark.circle.fill"
        case .stale: return "clock.badge.exclamationmark.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .connected: return ConstantsUI.normalSectionBackgroundColor
        case .selectPatient, .stale: return ConstantsUI.cautionSectionBackgroundColor
        case .notConfigured, .loginRequired, .checking: return Color(.secondarySystemGroupedBackground)
        case .acceptTerms, .failed: return ConstantsUI.warningSectionBackgroundColor
        }
    }
}

struct FollowerConnectionPresentation: Equatable {
    let state: FollowerConnectionState
    let message: String

    var title: String { state.title }
    var color: Color { state.color }

    static func resolve(
        source: FollowerDataSourceType,
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        sessionStatus: FollowerSessionStatus? = nil
    ) -> FollowerConnectionPresentation {
        switch source {
        case .nightscout:
            guard defaults.nightscoutEnabled,
                  let url = defaults.nightscoutUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !url.isEmpty,
                  let components = URLComponents(string: url),
                  components.scheme != nil,
                  components.host != nil else {
                return .init(state: .notConfigured, message: Texts_SettingsView.followerNightscoutConfigurationRequired)
            }
            return connectionAgePresentation(source: source, defaults: defaults, now: now)

        case .libreLinkUp, .libreLinkUpRussia:
            guard hasValue(defaults.libreLinkUpEmail), hasValue(defaults.libreLinkUpPassword) else {
                return .init(state: .loginRequired, message: Texts_HomeView.followerAccountCredentialsMissing)
            }
            if defaults.libreLinkUpReAcceptNeeded {
                return .init(state: .acceptTerms, message: Texts_SettingsView.libreLinkUpReAcceptNeeded)
            }
            if defaults.libreLinkUpPreventLogin {
                return .init(state: .failed, message: Texts_HomeView.followerAccountCredentialsInvalid)
            }
            if defaults.libreLinkUpManuallyLoggedOut {
                return .init(state: .loginRequired, message: Texts_SettingsView.followerLogInRequired)
            }
            switch resolvedSessionStatus(for: source, supplied: sessionStatus) {
            case .loggedOut:
                return .init(state: .loginRequired, message: Texts_SettingsView.followerLogInRequired)
            case .loggingIn:
                return .init(state: .checking, message: Texts_SettingsView.followerWaitingForFirstConnection)
            case .loggedIn:
                return connectionAgePresentation(source: source, defaults: defaults, now: now)
            }

        case .dexcomShare:
            guard hasValue(defaults.dexcomShareAccountName), hasValue(defaults.dexcomSharePassword) else {
                return .init(state: .loginRequired, message: Texts_HomeView.followerAccountCredentialsMissing)
            }
            if defaults.dexcomShareLoginFailedTimestamp != nil {
                return .init(state: .failed, message: Texts_HomeView.followerAccountCredentialsInvalid)
            }
            if defaults.dexcomShareManuallyLoggedOut {
                return .init(state: .loginRequired, message: Texts_SettingsView.followerLogInRequired)
            }
            switch resolvedSessionStatus(for: source, supplied: sessionStatus) {
            case .loggedOut:
                return .init(state: .loginRequired, message: Texts_SettingsView.followerLogInRequired)
            case .loggingIn:
                return .init(state: .checking, message: Texts_SettingsView.followerWaitingForFirstConnection)
            case .loggedIn:
                return connectionAgePresentation(source: source, defaults: defaults, now: now)
            }

        case .medtrumEasyView:
            guard hasValue(defaults.medtrumEasyViewEmail), hasValue(defaults.medtrumEasyViewPassword) else {
                return .init(state: .loginRequired, message: Texts_HomeView.followerAccountCredentialsMissing)
            }
            if defaults.medtrumEasyViewPreventLogin {
                return .init(state: .failed, message: Texts_HomeView.followerAccountCredentialsInvalid)
            }
            if defaults.medtrumEasyViewManuallyLoggedOut {
                return .init(state: .loginRequired, message: Texts_SettingsView.followerLogInRequired)
            }
            switch resolvedSessionStatus(for: source, supplied: sessionStatus) {
            case .loggedOut:
                return .init(state: .loginRequired, message: Texts_SettingsView.followerLogInRequired)
            case .loggingIn:
                return .init(state: .checking, message: Texts_SettingsView.followerWaitingForFirstConnection)
            case .loggedIn:
                if defaults.medtrumEasyViewUserType == "M", defaults.medtrumEasyViewSelectedPatientUid == 0 {
                    return .init(state: .selectPatient, message: Texts_SettingsView.medtrumSelectPatient)
                }
                return connectionAgePresentation(source: source, defaults: defaults, now: now)
            }

        case .calendar:
            guard calendarIsAuthorized else {
                return .init(state: .notConfigured, message: Texts_SettingsView.infoCalendarAccessDeniedByUser)
            }
            guard hasValue(defaults.calendarFollowCalendarId) else {
                return .init(state: .notConfigured, message: Texts_SettingsView.followerCalendarSelectionRequired)
            }
            switch CalendarShareStatus(rawValue: defaults.calendarFollowStatus) ?? .notConfigured {
            case .active: return .init(state: .connected, message: Texts_SettingsView.followerCalendarConnected)
            case .waiting: return .init(state: .checking, message: Texts_SettingsView.followerCalendarWaiting)
            case .noData: return .init(state: .checking, message: Texts_SettingsView.followerCalendarNoData)
            case .stale: return .init(state: .stale, message: Texts_SettingsView.followerCalendarStale)
            case .error: return .init(state: .failed, message: Texts_SettingsView.followerCalendarReadError)
            case .notConfigured: return .init(state: .notConfigured, message: Texts_SettingsView.followerCalendarSelectionRequired)
            }

        case .careLink:
            let snapshot = CareLinkAccountState.shared.snapshot
            let state: FollowerConnectionState
            switch snapshot.status {
            case .loginRequired: state = .loginRequired
            case .connecting, .noData: state = .checking
            case .selectPatient: state = .selectPatient
            case .active: state = .connected
            case .stale, .rateLimited: state = .stale
            case .error: state = .failed
            }
            return .init(state: state, message: snapshot.detail ?? snapshot.status.title)
        }
    }

    static func bannerRow(id: String, presentation: FollowerConnectionPresentation) -> SettingsRow {
        SettingsRow(
            id: id,
            title: presentation.title,
            control: .statusBanner(
                message: presentation.message,
                symbolName: presentation.state.symbolName,
                symbolColor: presentation.color,
                titleColor: presentation.state.titleColor,
                backgroundColor: presentation.state.backgroundColor
            )
        )
    }

    private static func connectionAgePresentation(
        source: FollowerDataSourceType,
        defaults: UserDefaults,
        now: Date
    ) -> FollowerConnectionPresentation {
        guard let lastConnection = defaults.timeStampOfLastFollowerConnection else {
            return .init(state: .checking, message: Texts_SettingsView.followerWaitingForFirstConnection)
        }
        guard lastConnection > .distantPast else {
            return .init(state: .failed, message: Texts_SettingsView.followerLastAttemptFailed)
        }
        let state: FollowerConnectionState = now.timeIntervalSince(lastConnection) <= Double(source.secondsUntilFollowerDisconnectWarning)
            ? .connected
            : .stale
        return .init(
            state: state,
            message: Texts_SettingsView.followerLastConnected(lastConnection.daysAndHoursAgo(appendAgo: true))
        )
    }

    private static func hasValue(_ value: String?) -> Bool {
        !(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private static func resolvedSessionStatus(
        for source: FollowerDataSourceType,
        supplied: FollowerSessionStatus?
    ) -> FollowerSessionStatus {
        supplied ?? FollowerSessionState.shared.status(for: source)
    }

    private static var calendarIsAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        }
        return EKEventStore.authorizationStatus(for: .event) == .authorized
    }
}
