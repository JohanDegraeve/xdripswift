//
//  ConstantsDirectWatch.swift
//  xDrip
//
//  Created by Paul Plant on 13/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

/// Shared collection limits and presentation rules for the phone and Watch.
/// Reading freshness, BLE connection age and phone delivery are deliberately separate clocks.
enum ConstantsDirectWatch {
    static let readingDelayedAfter: TimeInterval = 7 * 60
    static let readingOverdueAfter: TimeInterval = 17 * 60

    // Missed-reading notifications are an opt-in preference stored only on the Watch.
    // Keep this independent of the shorter orange/red presentation thresholds above.
    static let missedReadingNotificationDelay: TimeInterval = 21 * 60
    static let lastPhoneContactKey = "directWatch.lastLivePhoneContact"
    static let lastUrgentLowAlertKey = "directWatch.lastUrgentLowAlert"
    static let lastLowAlertKey = "directWatch.lastLowAlert"
    static let glucoseAlertRepeatInterval: TimeInterval = 15 * 60
    static let urgentLowNotificationsKey = "directWatch.urgentLowNotificationsEnabled"
    static let lowNotificationsKey = "directWatch.lowNotificationsEnabled"
    // Include legacy identifiers when cancelling alerts across an app update.
    static let glucoseNotificationIDs = ["directWatch.glucose", "directWatch.urgentLow", "directWatch.low", "g6Watch.glucose"]
    static let sensorNotificationIDs = ["directWatch.sensor", "g6Watch.sensor"]
    static var notificationIDs: [String] {
        glucoseNotificationIDs + sensorNotificationIDs + DirectWatchCompatibility.missedReadingNotificationIDs
    }
    static let missedReadingNotificationsKey = "directWatch.missedReadingNotificationsEnabled"

    // The two collectors can timestamp the same five-minute cycle a few seconds apart.
    // Use one window for merging, duplicate suppression and phone acknowledgements.
    static let nativeReadingDuplicateWindow: TimeInterval = 2.5 * 60
    static let localReadingRetention: TimeInterval = 12 * 3600
    static let maximumSyncBatchReadings = 72
    static let maximumRecentCollectionSessions = 200
    static let minimumWatchBackfillAge: TimeInterval = 5 * 60

    static let pauseSymbol = "pause.circle"
    static let resumeSymbol = "play.circle"
    static let buttonBackground = Color(.sRGB, red: 20 / 255, green: 52 / 255, blue: 74 / 255, opacity: 1)

    static func watchSymbol(for status: DirectWatchReadingStatus) -> String {
        switch status {
        case .paused: "applewatch.slash"
        default: "applewatch"
        }
    }

    static func statusColor(for status: DirectWatchReadingStatus) -> Color {
        switch status {
        case .current: .green
        case .connecting, .delayed, .suspended: .orange
        case .waiting, .overdue: .red
        case .off, .paused: Color("colorSecondary")
        }
    }
}
