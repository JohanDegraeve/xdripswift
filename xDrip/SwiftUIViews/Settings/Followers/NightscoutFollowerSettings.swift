//
//  NightscoutFollowerSettings.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Shows Nightscout connection and server state without duplicating Nightscout configuration.
enum NightscoutFollowerSettingsScreen {
    static func make() -> SettingsScreen {
        let monitor = FollowerServiceStatusMonitor(source: .nightscout)

        return SettingsScreen(title: FollowerDataSourceType.nightscout.description, onlineHelpTopic: FollowerDataSourceType.nightscout.onlineHelpTopic, providers: {
            [
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionConnection }, refreshEvery: 30) { _ in
                    let presentation = FollowerConnectionPresentation.resolve(source: .nightscout)
                    // Nightscout is configured in Sharing and Services, so an unconfigured banner leads there.
                    let setUp: SettingsRowAction? = presentation.state == .notConfigured
                        ? .settingsScreen { SettingsViewGroupedSettingsViewModel.nightscoutSettingsScreen() }
                        : nil
                    return [FollowerConnectionPresentation.bannerRow(id: "nightscout.connection.banner", presentation: presentation, action: setUp)]
                },
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionProfile }) { _ in
                    [FollowerSettingsRows.aliasRow(id: "nightscout.profile.alias")]
                },
                FollowerSettingsSectionProvider(
                    title: { Texts_SettingsView.followerSectionServer },
                    footer: { FollowerSettingsRows.serviceStatusFooter(monitor: monitor) },
                    monitor: monitor
                ) { _ in
                    [FollowerSettingsRows.serviceStatusRow(id: "nightscout.server.status", monitor: monitor)]
                }
            ]
        })
    }
}
