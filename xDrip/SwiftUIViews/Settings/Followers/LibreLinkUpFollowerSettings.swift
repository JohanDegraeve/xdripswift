//
//  LibreLinkUpFollowerSettings.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import os
import SwiftUI

/// Builds the shared LibreLinkUp account screen for the standard and Russia variants.
enum LibreLinkUpFollowerSettingsScreen {
    private static let log = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel
    )
    static func make(
        source: FollowerDataSourceType,
        actions: SelectedFollowerActions
    ) -> SettingsScreen {
        precondition(source == .libreLinkUp || source == .libreLinkUpRussia)
        let monitor = FollowerServiceStatusMonitor(source: source)

        return SettingsScreen(
            title: source.description,
            onlineHelpTopic: source.onlineHelpTopic,
            toolbarActions: { FollowerSettingsRows.accountToolbarActions(source: source, logOut: actions.logOut) },
            providers: {
            [
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionAccount }) { _ in accountRows(source: source) },
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionConnection }, refreshEvery: 30) { _ in
                    connectionRows(source: source, logIn: actions.logIn)
                },
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionProfile }) { _ in
                    [
                        FollowerSettingsRows.aliasRow(id: "libreLinkUp.profile.alias"),
                        SettingsRow(
                            id: "libreLinkUp.profile.region",
                            title: Texts_SettingsView.labelFollowerDataSourceRegion,
                            detail: regionText(source: source)
                        )
                    ]
                },
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionSensor }) { _ in sensorRows() },
                FollowerSettingsSectionProvider(
                    title: { Texts_SettingsView.followerSectionService },
                    footer: { FollowerSettingsRows.serviceStatusFooter(monitor: monitor) },
                    monitor: monitor
                ) { _ in
                    [FollowerSettingsRows.serviceStatusRow(id: "libreLinkUp.service.status", monitor: monitor)]
                }
            ]
        })
    }

    private static func accountRows(source: FollowerDataSourceType) -> [SettingsRow] {
        [
            FollowerSettingsRows.textEntryRow(
                id: "libreLinkUp.account.username",
                title: Texts_Common.username,
                message: Texts_SettingsView.enterUsername,
                currentValue: { UserDefaults.standard.libreLinkUpEmail },
                placeholder: ConstantsSettingsPlaceholders.usernamePlaceholder
            ) { value in
                guard value != UserDefaults.standard.libreLinkUpEmail else { return }
                let removedPassword = UserDefaults.standard.libreLinkUpPassword != nil
                UserDefaults.standard.libreLinkUpEmail = value
                UserDefaults.standard.libreLinkUpPassword = nil
                resetConnectionState()
                trace(
                    "LibreLinkUp username was changed",
                    log: log,
                    category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                    type: .info,
                    troubleshooting: .standard(.configuration(.credentialChanged(source: TroubleshootingLogSource(source), field: .username, isSet: value != nil)))
                )
                if removedPassword {
                    trace(
                        "LibreLinkUp password was removed after the username changed",
                        log: log,
                        category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                        type: .info,
                        troubleshooting: .standard(.configuration(.credentialChanged(source: TroubleshootingLogSource(source), field: .password, isSet: false)))
                    )
                }
            },
            FollowerSettingsRows.textEntryRow(
                id: "libreLinkUp.account.password",
                title: Texts_Common.password,
                message: Texts_SettingsView.enterPassword,
                currentValue: { UserDefaults.standard.libreLinkUpPassword },
                placeholder: ConstantsSettingsPlaceholders.passwordPlaceholder
            ) { value in
                guard value != UserDefaults.standard.libreLinkUpPassword else { return }
                UserDefaults.standard.libreLinkUpPassword = value
                resetConnectionState()
                trace(
                    "LibreLinkUp password was changed",
                    log: log,
                    category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                    type: .info,
                    troubleshooting: .standard(.configuration(.credentialChanged(source: TroubleshootingLogSource(source), field: .password, isSet: value != nil)))
                )
            }
        ]
    }

    private static func connectionRows(
        source: FollowerDataSourceType,
        logIn: @escaping () -> Void
    ) -> [SettingsRow] {
        let hasCredentials = UserDefaults.standard.libreLinkUpEmail?.isEmpty == false
            && UserDefaults.standard.libreLinkUpPassword?.isEmpty == false
        return FollowerSettingsRows.connectionRows(
            idPrefix: "libreLinkUp",
            source: source,
            hasCredentials: hasCredentials,
            logIn: logIn
        )
    }

    private static func sensorRows() -> [SettingsRow] {
        let serial = UserDefaults.standard.activeSensorSerialNumber
        let sensorDescription: String
        if UserDefaults.standard.libreLinkUpReAcceptNeeded {
            sensorDescription = Texts_SettingsView.libreLinkUpReAcceptNeeded
        } else if let serial {
            sensorDescription = formattedSensor(serial)
        } else {
            sensorDescription = Texts_SettingsView.libreLinkUpNoActiveSensor
        }

        let startDateText: String
        if let startDate = UserDefaults.standard.activeSensorStartDate {
            startDateText = startDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short)
                + " (" + startDate.daysAndHoursAgo() + ")"
        } else {
            startDateText = "-"
        }

        return [
            SettingsRow(id: "libreLinkUp.sensor.identity", title: Texts_HomeView.sensor, detail: sensorDescription),
            SettingsRow(id: "libreLinkUp.sensor.startDate", title: Texts_BluetoothPeripheralView.sensorStartDate, detail: startDateText),
            SettingsRow(
                id: "libreLinkUp.sensor.fifteenDay",
                title: Texts_SettingsView.labelFollowerIs15DaySensor,
                control: .toggle(
                    isOn: { UserDefaults.standard.libreLinkUpIs15DaySensor },
                    setIsOn: { isOn in
                        UserDefaults.standard.libreLinkUpIs15DaySensor = isOn
                        UserDefaults.standard.activeSensorMaxSensorAgeInDays = isOn
                            ? ConstantsLibreLinkUp.libreLinkUpMaxSensorAgeInDaysLibrePlus
                            : ConstantsLibreLinkUp.libreLinkUpMaxSensorAgeInDays
                    }
                )
            )
        ]
    }

    private static func resetConnectionState() {
        UserDefaults.standard.libreLinkUpRegion = nil
        UserDefaults.standard.activeSensorStartDate = nil
        UserDefaults.standard.activeSensorSerialNumber = nil
        UserDefaults.standard.libreLinkUpCountry = nil
        UserDefaults.standard.libreLinkUpPreventLogin = false
        UserDefaults.standard.timeStampOfLastFollowerConnection = nil
    }

    private static func regionText(source: FollowerDataSourceType) -> String {
        if source == .libreLinkUpRussia { return Texts_SettingsView.followerRussia }
        let region = UserDefaults.standard.libreLinkUpRegion?.description ?? "-"
        if let country = UserDefaults.standard.libreLinkUpCountry, !country.isEmpty {
            return "\(region) (\(country))"
        }
        return region
    }

    private static func formattedSensor(_ serial: String) -> String {
        if serial.range(of: #"^MH"#, options: .regularExpression) != nil {
            return "Libre 2 " + (UserDefaults.standard.libreLinkUpIs15DaySensor ? "Plus " : "") + "(3\(serial))"
        }
        if serial.range(of: #"^0[D-F]"#, options: .regularExpression) != nil {
            return "Libre 3 " + (UserDefaults.standard.libreLinkUpIs15DaySensor ? "Plus " : "") + "(\(serial.dropLast()))"
        }
        return serial
    }
}
