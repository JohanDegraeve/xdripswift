//
//  AppShortcuts.swift
//  xdrip
//
//  Created by Guy Shaviv on 31/12/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import AppIntents
import Foundation

struct AppsShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GlucoseIntent(),
            phrases: [
                "What is my glucose in \(.applicationName)",
                "What's my glucose in \(.applicationName)",
                "What is my glucose level in \(.applicationName)",
                "What's my glucose level in \(.applicationName)",
                "What is my \(.applicationName) glucose",
                "What's my \(.applicationName) glucose",
                "What is my \(.applicationName) glucose level",
                "What's my \(.applicationName) glucose level",
          ],
            shortTitle: "Blood Glucose",
            systemImageName: "drop"
        )
        AppShortcut(
            intent: EnableSpeakReadingsIntent(),
            phrases: ["Enable Speak Readings in \(.applicationName)"],
            shortTitle: "Enable Speak Readings",
            systemImageName: "speaker.wave.2"
        )
        AppShortcut(
            intent: DisableSpeakReadingsIntent(),
            phrases: ["Disable Speak Readings in \(.applicationName)"],
            shortTitle: "Disable Speak Readings",
            systemImageName: "speaker.slash"
        )
    }
}

/// Sets an explicit state so repeating an exercise automation never reverses its intended effect.
/// Runs without opening the app or requiring unlock, and returns without a dialog so the next
/// Shortcuts action can proceed. The shared preference also updates Settings and Home Screen actions.
struct EnableSpeakReadingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable Speak Readings"
    static var description = IntentDescription("Enable automatic speech for subsequent glucose readings using your existing speech settings.", categoryName: "Speech")
    static var openAppWhenRun = false
    static var authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed

    @MainActor
    func perform() async throws -> some IntentResult {
        // Set only the master switch. BGReadingSpeaker still applies the daily schedule and
        // existing speech settings to new readings; this does not announce the current value.
        UserDefaults.standard.speakReadings = true
        return .result()
    }
}

/// The matching background action for ending an automation; repeated calls leave speech disabled.
/// Like the existing Settings toggle, this prevents future announcements rather than cancelling
/// an utterance already in progress. No dialog or foreground presentation interrupts the sequence.
struct DisableSpeakReadingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Speak Readings"
    static var description = IntentDescription("Disable automatic speech for subsequent glucose readings without changing your other speech settings.", categoryName: "Speech")
    static var openAppWhenRun = false
    static var authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.speakReadings = false
        return .result()
    }
}
