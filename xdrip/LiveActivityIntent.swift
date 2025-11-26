//
//  LiveActivityIntent.swift
//  xdrip
//
//  Created by Marian Dugaesescu on 13/10/2024 / Edited by Paul Plant on 06/02/2025.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import AppIntents
import Foundation

// https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities#Start-and-stop-Live-Activities-from-App-Intents
// https://developer.apple.com/documentation/appintents/liveactivityintent

/// App Intent used to restart the live activities via Apple Shortcuts automation
/// The user needs to add this as an Automation (for somebody who never opens the app, one automation set every 6 hours is needed,
/// although just one set at 03hrs could be enough for most people to ensure the live activity isn't cancelled during the night)
struct RestartLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Restart Live Activity"
    static var description = IntentDescription("Restarts the glucose monitoring live activity.", categoryName: "Live Activity")

    @MainActor
    func perform() async throws -> some IntentResult {
        // restart the live activity via the LiveActivityManager singleton
        LiveActivityManager.shared.restartFromIntent()
        return .result()
    }
}
