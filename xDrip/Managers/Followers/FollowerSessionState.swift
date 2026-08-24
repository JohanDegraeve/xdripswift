//
//  FollowerSessionState.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import Foundation

/// Process-local account state reported by follower managers that maintain login sessions.
enum FollowerSessionStatus: Equatable {
    case loggedOut
    case loggingIn
    case loggedIn
}

/// Authentication state published by the long-lived follower managers.
/// Credentials and tokens remain owned by UserDefaults and each manager.
final class FollowerSessionState: ObservableObject {
    static let shared = FollowerSessionState()

    @Published private var statuses: [FollowerDataSourceType: FollowerSessionStatus] = [:]

    func status(for source: FollowerDataSourceType) -> FollowerSessionStatus {
        statuses[source] ?? .loggedOut
    }

    func update(_ status: FollowerSessionStatus, for source: FollowerDataSourceType) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.update(status, for: source) }
            return
        }
        guard statuses[source] != status else { return }
        statuses[source] = status
    }
}

extension UserDefaults {
    /// Returns the explicit logout flag for follower services that maintain a login session.
    func followerWasManuallyLoggedOut(_ source: FollowerDataSourceType) -> Bool {
        switch source {
        case .libreLinkUp, .libreLinkUpRussia:
            return libreLinkUpManuallyLoggedOut
        case .dexcomShare:
            return dexcomShareManuallyLoggedOut
        case .medtrumEasyView:
            return medtrumEasyViewManuallyLoggedOut
        case .nightscout, .calendar, .careLink:
            return false
        }
    }
}
