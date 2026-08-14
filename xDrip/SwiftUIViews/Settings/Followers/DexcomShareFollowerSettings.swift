//
//  DexcomShareFollowerSettings.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import os
import SwiftUI

/// Builds the Dexcom Share account, connection, profile, activity and service sections.
enum DexcomShareFollowerSettingsScreen {
    private static let log = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel
    )
    static func make(actions: SelectedFollowerActions) -> SettingsScreen {
        let monitor = FollowerServiceStatusMonitor(source: .dexcomShare)
        return SettingsScreen(
            title: FollowerDataSourceType.dexcomShare.description,
            onlineHelpTopic: FollowerDataSourceType.dexcomShare.onlineHelpTopic,
            toolbarActions: {
                FollowerSettingsRows.accountToolbarActions(source: .dexcomShare, logOut: actions.logOut)
            },
            providers: {
            [
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionAccount }) { _ in accountRows() },
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionConnection }, refreshEvery: 30) { _ in
                    connectionRows(logIn: actions.logIn)
                },
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionProfile }) { _ in
                    [
                        FollowerSettingsRows.aliasRow(id: "dexcomShare.profile.alias"),
                        SettingsRow(
                            id: "dexcomShare.profile.region",
                            title: Texts_SettingsView.labelFollowerDataSourceRegion,
                            detail: regionText(),
                            accessory: UserDefaults.standard.dexcomShareRegion == .none ? .none : .info,
                            action: regionAction()
                        )
                    ]
                },
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionActivity }, refreshEvery: 30) { _ in
                    [FollowerSettingsRows.connectionActivityRow(id: "dexcomShare.activity.lastConnection")]
                },
                FollowerSettingsSectionProvider(
                    title: { Texts_SettingsView.followerSectionService },
                    footer: { FollowerSettingsRows.serviceStatusFooter(monitor: monitor) },
                    monitor: monitor
                ) { _ in
                    [FollowerSettingsRows.serviceStatusRow(id: "dexcomShare.service.status", monitor: monitor)]
                }
            ]
        })
    }

    private static func accountRows() -> [SettingsRow] {
        [
            FollowerSettingsRows.textEntryRow(
                id: "dexcomShare.account.username",
                title: Texts_Common.username,
                message: Texts_SettingsView.enterUsername,
                currentValue: { UserDefaults.standard.dexcomShareAccountName },
                placeholder: ConstantsSettingsPlaceholders.usernamePlaceholder
            ) { value in
                guard value != UserDefaults.standard.dexcomShareAccountName else { return }
                UserDefaults.standard.dexcomShareAccountName = value
                UserDefaults.standard.dexcomShareRegion = .none
                UserDefaults.standard.dexcomShareLoginFailedTimestamp = nil
                UserDefaults.standard.timeStampOfLastFollowerConnection = nil
                trace(
                    "Dexcom Share username was changed",
                    log: log,
                    category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                    type: .info,
                    troubleshooting: .standard(.configuration(.credentialChanged(source: .dexcomShare, field: .username, isSet: value != nil)))
                )
            },
            FollowerSettingsRows.textEntryRow(
                id: "dexcomShare.account.password",
                title: Texts_Common.password,
                message: Texts_SettingsView.enterPassword,
                currentValue: { UserDefaults.standard.dexcomSharePassword },
                placeholder: ConstantsSettingsPlaceholders.passwordPlaceholder
            ) { value in
                guard value != UserDefaults.standard.dexcomSharePassword else { return }
                UserDefaults.standard.dexcomSharePassword = value
                UserDefaults.standard.dexcomShareRegion = .none
                UserDefaults.standard.dexcomShareLoginFailedTimestamp = nil
                UserDefaults.standard.timeStampOfLastFollowerConnection = nil
                trace(
                    "Dexcom Share password was changed",
                    log: log,
                    category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                    type: .info,
                    troubleshooting: .standard(.configuration(.credentialChanged(source: .dexcomShare, field: .password, isSet: value != nil)))
                )
            },
        ]
    }

    private static func connectionRows(logIn: @escaping () -> Void) -> [SettingsRow] {
        let hasCredentials = UserDefaults.standard.dexcomShareAccountName?.isEmpty == false
            && UserDefaults.standard.dexcomSharePassword?.isEmpty == false
        return FollowerSettingsRows.connectionRows(
            idPrefix: "dexcomShare",
            source: .dexcomShare,
            hasCredentials: hasCredentials,
            logIn: logIn
        )
    }

    private static func regionText() -> String {
        let region = UserDefaults.standard.dexcomShareRegion
        if region == .none { return "-" }
        return region.description
    }

    private static func regionAction() -> SettingsRowAction? {
        let region = UserDefaults.standard.dexcomShareRegion
        guard region != .none else { return nil }
        return .showMessage(
            title: Texts_SettingsView.dexcomServer(region.regionServerNumber),
            message: "\n" + region.regionCountriesDescription
        )
    }
}
