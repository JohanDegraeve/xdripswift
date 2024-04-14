//
//  AppShortcuts.swift
//  xdrip
//
//  Created by Guy Shaviv on 31/12/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import AppIntents

@available(iOS 16,*)
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
    }
}
