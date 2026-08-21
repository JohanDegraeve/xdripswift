//
//  CareLinkFollowerSettings.swift
//  xdripswift
//
//  Created by Paul Plant on 3/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import os
import SwiftUI

/// Builds the CareLink account screen from the same native rows as the other followers.
enum CareLinkFollowerSettingsScreen {
    static func make() -> SettingsScreen {
        SettingsScreen(title: FollowerDataSourceType.careLink.description, onlineHelpTopic: FollowerDataSourceType.careLink.onlineHelpTopic, toolbarActions: toolbarActions, providers: {
            CareLinkSettingsSection.allCases.map(CareLinkSettingsSectionProvider.init)
        })
    }

    private static func toolbarActions() -> [SettingsToolbarAction] {
        [
            SettingsToolbarAction(
                id: "careLink.refresh",
                title: Texts_SettingsView.followerRefresh,
                symbolName: "arrow.clockwise",
                tint: ConstantsAppColors.toolbarAction,
                isEnabled: {
                    let status = CareLinkAccountState.shared.snapshot.status
                    return status != .loginRequired && status != .connecting
                },
                action: { CareLinkAccountState.shared.refresh() }
            ),
            SettingsToolbarAction(
                id: "careLink.logout",
                title: Texts_SettingsView.followerLogOut,
                symbolName: "rectangle.portrait.and.arrow.right",
                tint: .red,
                isEnabled: {
                    let status = CareLinkAccountState.shared.snapshot.status
                    return status != .loginRequired && status != .connecting
                },
                action: { CareLinkAccountState.shared.logOut() }
            )
        ]
    }
}

private enum CareLinkSettingsSection: CaseIterable {
    case credentials
    case connection
    case profile
    case therapyDisplay
    case device
    case activity
}

/// Observes the shared manager snapshot. OAuth credentials never enter Settings.
private final class CareLinkSettingsSectionProvider: SettingsNativeSectionProvider {
    private let section: CareLinkSettingsSection
    private var stateObserver: AnyCancellable?
    private var sectionReloadClosure: (() -> Void)?
    private let log = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel
    )

    init(_ section: CareLinkSettingsSection) {
        self.section = section
        stateObserver = CareLinkAccountState.shared.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sectionReloadClosure?() }
    }

    func settingsSectionTitle() -> String? {
        switch section {
        case .credentials: return Texts_SettingsView.followerSectionAccount
        case .connection: return nil
        case .profile: return Texts_SettingsView.followerSectionProfile
        case .device: return Texts_SettingsView.careLinkDevice
        case .therapyDisplay: return Texts_SettingsView.careLinkTherapyDisplay
        case .activity: return Texts_SettingsView.followerSectionActivity
        }
    }

    func settingsSectionFooter() -> String? {
        switch section {
        case .credentials:
            return Texts_SettingsView.careLinkCredentialsFooter
        case .connection:
            return snapshot.detail
        case .therapyDisplay:
            return Texts_SettingsView.careLinkAutomaticBasalFooter
        case .profile, .device, .activity:
            return nil
        }
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        switch section {
        case .credentials: return credentialRows()
        case .connection: return connectionRows()
        case .profile: return profileRows()
        case .device: return deviceRows()
        case .therapyDisplay: return therapyDisplayRows()
        case .activity: return activityRows()
        }
    }

    private var snapshot: CareLinkStatusSnapshot {
        CareLinkAccountState.shared.snapshot
    }

    private func credentialRows() -> [SettingsRow] {
        [
            FollowerSettingsRows.textEntryRow(
                id: "careLink.username",
                title: Texts_Common.username,
                message: Texts_SettingsView.enterUsername,
                currentValue: { UserDefaults.standard.careLinkUsername },
                placeholder: ConstantsSettingsPlaceholders.usernamePlaceholder
            ) { username in
                guard username != UserDefaults.standard.careLinkUsername else { return }
                let removedPassword = UserDefaults.standard.careLinkPassword != nil
                UserDefaults.standard.careLinkUsername = username
                UserDefaults.standard.careLinkPassword = nil
                trace(
                    "CareLink username was changed",
                    log: self.log,
                    category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                    type: .info,
                    troubleshooting: .standard(.configuration(.credentialChanged(source: .careLink, field: .username, isSet: username != nil)))
                )
                if removedPassword {
                    trace(
                        "CareLink password was removed after the username changed",
                        log: self.log,
                        category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                        type: .info,
                        troubleshooting: .standard(.configuration(.credentialChanged(source: .careLink, field: .password, isSet: false)))
                    )
                }
            },
            FollowerSettingsRows.textEntryRow(
                id: "careLink.password",
                title: Texts_Common.password,
                message: Texts_SettingsView.enterPassword,
                currentValue: { UserDefaults.standard.careLinkPassword },
                placeholder: ConstantsSettingsPlaceholders.passwordPlaceholder
            ) { password in
                guard password != UserDefaults.standard.careLinkPassword else { return }
                UserDefaults.standard.careLinkPassword = password
                trace(
                    "CareLink password was changed",
                    log: self.log,
                    category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                    type: .info,
                    troubleshooting: .standard(.configuration(.credentialChanged(source: .careLink, field: .password, isSet: password != nil)))
                )
            },
            regionRow()
        ]
    }

    private func regionRow() -> SettingsRow {
        SettingsRow(
            id: "careLink.region",
            title: Texts_SettingsView.labelFollowerDataSourceRegion,
            control: .menuWithSelectionTitle(
                options: {
                    CareLinkRegion.allCases.map {
                        SettingsMenuOption(title: $0.settingsTitle, isSelected: $0 == CareLinkAccountState.shared.snapshot.region)
                    }
                },
                selectionTitle: { CareLinkAccountState.shared.snapshot.region.settingsTitle },
                selectOption: { index in
                    let regions = CareLinkRegion.allCases
                    guard regions.indices.contains(index) else { return }
                    CareLinkAccountState.shared.setRegion(regions[index])
                }
            )
        )
    }

    private func connectionRows() -> [SettingsRow] {
        let presentation = FollowerConnectionPresentation.resolve(source: .careLink)
        var rows = [
            FollowerConnectionPresentation.bannerRow(
                id: "careLink.connection.banner",
                presentation: presentation
            )
        ]
        if snapshot.status == .loginRequired {
            rows.append(SettingsRow(
                id: "careLink.connection.login",
                title: Texts_SettingsView.followerLogIn,
                icon: SettingsIcon(symbolName: "rectangle.portrait.and.arrow.right", color: .accentColor),
                titleColor: .accentColor,
                accessory: .none,
                isEnabled: true,
                action: .run { CareLinkAccountState.shared.logIn() }
            ))
        }
        return rows
    }

    private func profileRows() -> [SettingsRow] {
        var rows = [SettingsRow]()
        appendValue(Texts_SettingsView.careLinkAccount, snapshot.metadata.accountName, id: "account", to: &rows)
        appendValue(Texts_SettingsView.careLinkRole, roleTitle(snapshot.metadata.role), id: "role", to: &rows)

        switch snapshot.patients.count {
        case 0:
            rows.append(SettingsRow(id: "careLink.patient", title: Texts_SettingsView.careLinkPatient, detail: "-"))
        case 1:
            rows.append(SettingsRow(
                id: "careLink.patient",
                title: Texts_SettingsView.careLinkPatient,
                detail: snapshot.patients[0].displayName
            ))
        default:
            rows.append(patientPickerRow())
        }

        appendValue(
            Texts_SettingsView.careLinkAccountCountry,
            accountCountry(snapshot.metadata.countryCode),
            id: "accountCountry",
            to: &rows
        )
        return rows
    }

    /// The picker stays available after selection because Care Partner accounts can change patient.
    private func patientPickerRow() -> SettingsRow {
        SettingsRow(
            id: "careLink.patient",
            title: Texts_SettingsView.careLinkPatient,
            control: .menuWithSelectionTitle(
                options: {
                    CareLinkAccountState.shared.snapshot.patients.map { patient in
                        SettingsMenuOption(
                            title: patient.displayName,
                            isSelected: patient.id == CareLinkAccountState.shared.snapshot.selectedPatientID
                                || patient.username == CareLinkAccountState.shared.snapshot.selectedPatientID
                        )
                    }
                },
                selectionTitle: {
                    CareLinkAccountState.shared.snapshot.selectedPatient?.displayName
                        ?? Texts_SettingsView.followerSelectPatient
                },
                selectOption: { index in
                    let patients = CareLinkAccountState.shared.snapshot.patients
                    guard patients.indices.contains(index) else { return }
                    CareLinkAccountState.shared.selectPatient(patients[index].id)
                }
            )
        )
    }

    private func deviceRows() -> [SettingsRow] {
        var rows = [SettingsRow]()
        appendValue(Texts_SettingsView.careLinkPump, joined(snapshot.metadata.deviceFamily, snapshot.metadata.deviceModel), id: "pump", to: &rows)
        appendValue(Texts_SettingsView.careLinkSerialNumber, snapshot.metadata.deviceSerial, id: "serial", to: &rows)
        appendValue(Texts_HomeView.sensor, joined(snapshot.metadata.sensorType, snapshot.metadata.sensorState), id: "sensor", to: &rows)
        appendValue(Texts_SettingsView.careLinkDataRoute, snapshot.metadata.route?.rawValue.capitalized, id: "route", to: &rows)
        appendValue(Texts_SettingsView.careLinkPumpBattery, percent(snapshot.pump.batteryPercent), id: "pumpBattery", to: &rows)
        appendValue(Texts_SettingsView.careLinkReservoir, units(snapshot.pump.reservoirUnits), id: "reservoir", to: &rows)
        return rows
    }

    private func activityRows() -> [SettingsRow] {
        var rows = [SettingsRow]()
        appendValue(Texts_SettingsView.careLinkLastReading, formatted(snapshot.lastReadingAt), id: "lastReading", to: &rows)
        appendValue(Texts_SettingsView.careLinkLastCheck, formatted(snapshot.lastCheckAt), id: "lastCheck", to: &rows)
        appendValue(Texts_SettingsView.careLinkSessionRefresh, formatted(snapshot.lastTokenRefreshAt), id: "sessionRefresh", to: &rows)
        appendValue(Texts_SettingsView.careLinkTherapyImport, formatted(snapshot.lastTherapyImportAt), id: "therapyImport", to: &rows)
        appendValue(
            Texts_SettingsView.careLinkNewTreatments,
            snapshot.lastTherapyImportAt == nil ? nil : String(snapshot.importedTreatmentCount),
            id: "treatmentCount",
            to: &rows
        )
        appendValue(
            Texts_SettingsView.careLinkServiceReachable,
            snapshot.serviceReachable.map { $0 ? Texts_Common.yes : Texts_Common.no } ?? Texts_Common.unknown,
            id: "reachable",
            to: &rows
        )
        return rows
    }

    private func therapyDisplayRows() -> [SettingsRow] {
        let styles = AutomaticBasalRenderingStyle.allCases
        return [
            SettingsRow(
                id: "careLink.automaticBasalRenderingStyle",
                title: Texts_SettingsView.careLinkAutomaticBasal,
                control: .menuWithSelectionTitle(
                    options: {
                        styles.map {
                            SettingsMenuOption(
                                title: $0.title,
                                isSelected: $0 == UserDefaults.standard.automaticBasalRenderingStyle
                            )
                        }
                    },
                    selectionTitle: { UserDefaults.standard.automaticBasalRenderingStyle.title },
                    selectOption: { index in
                        guard styles.indices.contains(index) else { return }
                        UserDefaults.standard.automaticBasalRenderingStyle = styles[index]
                    }
                ),
                keepsControlLabelOnSingleLine: true
            )
        ]
    }

    /// Protocol fields that are not present are omitted instead of shown as placeholders.
    private func appendValue(_ title: String, _ detail: String?, id: String, to rows: inout [SettingsRow]) {
        guard let detail, !detail.isEmpty else { return }
        rows.append(SettingsRow(id: "careLink.\(id)", title: title, detail: detail))
    }

    private func formatted(_ date: Date?) -> String? {
        date?.formatted(date: .abbreviated, time: .standard)
    }

    private func joined(_ first: String?, _ second: String?) -> String? {
        let values = [first, second].compactMap { $0 }.filter { !$0.isEmpty }
        return values.isEmpty ? nil : values.joined(separator: " · ")
    }

    private func percent(_ value: Int?) -> String? {
        value.map { "\($0) %" }
    }

    private func units(_ value: Double?) -> String? {
        value.map { "\($0.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes) U" }
    }

    private func roleTitle(_ role: String?) -> String? {
        role?.replacingOccurrences(of: "_OUS", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func accountCountry(_ countryCode: String?) -> String? {
        guard let countryCode = countryCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !countryCode.isEmpty else { return nil }
        let code = countryCode.uppercased()
        guard let country = Locale.current.localizedString(forRegionCode: code) else { return code }
        return country
    }

    func storeSectionReloadClosure(sectionReloadClosure: @escaping () -> Void) {
        self.sectionReloadClosure = sectionReloadClosure
    }

    func sectionTitle() -> String? { settingsSectionTitle() }
    func sectionFooter() -> String? { settingsSectionFooter() }
    func settingsRowText(index: Int) -> String { "" }
    func accessoryType(index: Int) -> SettingsAccessory { .none }
    func detailedText(index: Int) -> String? { nil }
    func numberOfRows() -> Int { settingsRows(sectionID: 0).count }
    func onRowSelect(index: Int) -> SettingsSelectedRowAction { .nothing }
    func isEnabled(index: Int) -> Bool { true }
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool { section == .credentials }
    func storeMessageHandler(messageHandler: @escaping (String, String) -> Void) {}
    func storeRowReloadClosure(rowReloadClosure: @escaping (Int) -> Void) {}
}

private extension CareLinkRegion {
    var settingsTitle: String {
        switch self {
        case .unitedStates: return Texts_SettingsView.careLinkUnitedStates
        case .outsideUnitedStates: return Texts_SettingsView.careLinkOutsideUnitedStates
        }
    }
}
