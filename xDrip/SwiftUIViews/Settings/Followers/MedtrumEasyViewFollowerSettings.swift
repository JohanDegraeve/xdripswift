//
//  MedtrumEasyViewFollowerSettings.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import os
import SwiftUI

/// Builds the Medtrum account screen and keeps caregiver patient selection in Profile.
enum MedtrumEasyViewFollowerSettingsScreen {
    private static let log = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel
    )
    static func make(actions: SelectedFollowerActions) -> SettingsScreen {
        SettingsScreen(
            title: FollowerDataSourceType.medtrumEasyView.description,
            onlineHelpTopic: FollowerDataSourceType.medtrumEasyView.onlineHelpTopic,
            toolbarActions: {
                FollowerSettingsRows.accountToolbarActions(source: .medtrumEasyView, logOut: actions.logOut)
            },
            providers: {
            [
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionAccount }) { _ in accountRows() },
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionConnection }, refreshEvery: 30) { _ in
                    connectionRows(logIn: actions.logIn)
                },
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionProfile }) { _ in profileRows() },
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionActivity }, refreshEvery: 30) { _ in
                    var rows = [FollowerSettingsRows.connectionActivityRow(id: "medtrum.activity.lastConnection")]
                    if UserDefaults.standard.medtrumEasyViewConnectionsFetchFailed {
                        rows.append(SettingsRow(
                            id: "medtrum.activity.cachedPatients",
                            title: Texts_SettingsView.medtrumPatientList,
                            detail: Texts_SettingsView.medtrumUsingCachedList,
                            detailIndicator: SettingsIndicator(color: ConstantsAppColors.warning)
                        ))
                    }
                    return rows
                }
            ]
        })
    }

    private static func accountRows() -> [SettingsRow] {
        [
            FollowerSettingsRows.textEntryRow(
                id: "medtrum.account.username",
                title: Texts_Common.username,
                message: Texts_SettingsView.enterUsername,
                currentValue: { UserDefaults.standard.medtrumEasyViewEmail },
                placeholder: ConstantsSettingsPlaceholders.usernamePlaceholder
            ) { value in
                guard value != UserDefaults.standard.medtrumEasyViewEmail else { return }
                let removedPassword = UserDefaults.standard.medtrumEasyViewPassword != nil
                UserDefaults.standard.medtrumEasyViewEmail = value
                UserDefaults.standard.medtrumEasyViewPassword = nil
                resetAccountState()
                trace(
                    "Medtrum EasyView username was changed",
                    log: log,
                    category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                    type: .info,
                    troubleshooting: .standard(.configuration(.credentialChanged(source: .medtrumEasyView, field: .username, isSet: value != nil)))
                )
                if removedPassword {
                    trace(
                        "Medtrum EasyView password was removed after the username changed",
                        log: log,
                        category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                        type: .info,
                        troubleshooting: .standard(.configuration(.credentialChanged(source: .medtrumEasyView, field: .password, isSet: false)))
                    )
                }
            },
            FollowerSettingsRows.textEntryRow(
                id: "medtrum.account.password",
                title: Texts_Common.password,
                message: Texts_SettingsView.enterPassword,
                currentValue: { UserDefaults.standard.medtrumEasyViewPassword },
                placeholder: ConstantsSettingsPlaceholders.passwordPlaceholder
            ) { value in
                guard value != UserDefaults.standard.medtrumEasyViewPassword else { return }
                UserDefaults.standard.medtrumEasyViewPassword = value
                resetAccountState()
                trace(
                    "Medtrum EasyView password was changed",
                    log: log,
                    category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                    type: .info,
                    troubleshooting: .standard(.configuration(.credentialChanged(source: .medtrumEasyView, field: .password, isSet: value != nil)))
                )
            }
        ]
    }

    private static func connectionRows(logIn: @escaping () -> Void) -> [SettingsRow] {
        let hasCredentials = UserDefaults.standard.medtrumEasyViewEmail?.isEmpty == false
            && UserDefaults.standard.medtrumEasyViewPassword?.isEmpty == false
        return FollowerSettingsRows.connectionRows(
            idPrefix: "medtrum",
            source: .medtrumEasyView,
            hasCredentials: hasCredentials,
            logIn: logIn
        )
    }

    private static func profileRows() -> [SettingsRow] {
        var rows = [SettingsRow]()
        if let userType = UserDefaults.standard.medtrumEasyViewUserType {
            rows.append(SettingsRow(
                id: "medtrum.profile.accountType",
                title: Texts_SettingsView.medtrumAccountType,
                detail: userType == "M" ? Texts_SettingsView.medtrumCaregiver : Texts_SettingsView.medtrumPatient
            ))
        }
        rows.append(FollowerSettingsRows.aliasRow(id: "medtrum.profile.alias"))
        if UserDefaults.standard.medtrumEasyViewUserType == "M" {
            rows.append(patientRow())
        }
        return rows
    }

    private static func patientRow() -> SettingsRow {
        let connections = cachedConnections()
        let selectedUid = UserDefaults.standard.medtrumEasyViewSelectedPatientUid
        let selectedIndex = connections.firstIndex { $0.uid == selectedUid }
        let detail = connections.first(where: { $0.uid == selectedUid })?.displayName
            ?? (selectedUid == 0 ? Texts_SettingsView.medtrumSelectPatient : Texts_SettingsView.medtrumPatientID(selectedUid))

        return SettingsRow(
            id: "medtrum.profile.patient",
            title: Texts_SettingsView.medtrumSelectedPatient,
            detail: detail,
            accessory: connections.isEmpty ? .none : .disclosure,
            isEnabled: !connections.isEmpty,
            reloadScope: .all,
            action: connections.isEmpty ? nil : .selectionList {
                SettingsSelectionListContent(
                    title: Texts_SettingsView.medtrumSelectPatientFromList,
                    data: connections.map(\.displayName),
                    selectedRow: selectedIndex,
                    actionTitle: Texts_Common.Ok,
                    cancelTitle: Texts_Common.Cancel,
                    action: { index in
                        guard connections.indices.contains(index) else { return }
                        let patient = connections[index]
                        let aliasChanged = UserDefaults.standard.followerPatientName != patient.displayName
                        UserDefaults.standard.medtrumEasyViewSelectedPatientUid = patient.uid
                        UserDefaults.standard.followerPatientName = patient.displayName
                        UserDefaults.standard.medtrumEasyViewPreventLogin = false
                        UserDefaults.standard.timeStampOfLastFollowerConnection = nil
                        if aliasChanged {
                            trace(
                                "patient selection changed the patient alias",
                                log: log,
                                category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                                type: .info,
                                troubleshooting: .standard(.configuration(.patientAliasChanged(isSet: true)))
                            )
                        }
                    },
                    cancel: nil,
                    didSelectRow: nil
                )
            }
        )
    }

    private static func cachedConnections() -> [MedtrumEasyViewPatientConnection] {
        guard let data = UserDefaults.standard.medtrumEasyViewCachedConnections else { return [] }
        return (try? JSONDecoder().decode([MedtrumEasyViewPatientConnection].self, from: data)) ?? []
    }

    private static func resetAccountState() {
        UserDefaults.standard.medtrumEasyViewPreventLogin = false
        UserDefaults.standard.medtrumEasyViewUserType = nil
        UserDefaults.standard.medtrumEasyViewCachedConnections = nil
        UserDefaults.standard.medtrumEasyViewSelectedPatientUid = 0
        UserDefaults.standard.medtrumEasyViewConnectionsFetchFailed = false
        UserDefaults.standard.timeStampOfLastFollowerConnection = nil
    }
}
