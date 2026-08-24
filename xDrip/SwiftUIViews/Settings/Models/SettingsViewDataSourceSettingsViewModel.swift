//
//  SettingsViewDataSourceSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 25/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Combine
import os
import SwiftUI

/// Stable legacy indices are retained for Settings refresh and action routing.
/// Follower-specific rows live in their typed child screens.
private enum DataSourceSetting: Int, CaseIterable {
    case bloodGlucoseUnit = 0
    case masterFollower = 1
    case masterUploadToNightscout = 2
    case followerKeepAlive = 3
    case followerDataSource = 4
    case followerStatus = 5
    case followerUploadToNightscout = 6
    case therapyDataSource = 13
}

final class SettingsViewDataSourceSettingsViewModel: NSObject, SettingsViewModelProtocol {
    private let coreDataManager: CoreDataManager?
    private let selectedFollowerActions: SelectedFollowerActions
    private let log = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel
    )
    private let warningPrefix = "⚠️ "

    private var messageHandler: ((String, String) -> Void)?
    private var sectionReloadClosure: (() -> Void)?
    private var defaultsObserver: NSObjectProtocol?
    private var careLinkStateObserver: AnyCancellable?
    private var followerSessionStateObserver: AnyCancellable?

    init(
        coreDataManager: CoreDataManager?,
        selectedFollowerActions: SelectedFollowerActions = .none
    ) {
        self.coreDataManager = coreDataManager
        self.selectedFollowerActions = selectedFollowerActions
        super.init()

        let stored = UserDefaults.standard.followerDataSourceType
        let validated = FollowerDataSourceType.validatedSelection(storedRawValue: stored.rawValue)
        if stored != validated {
            UserDefaults.standard.followerDataSourceType = validated
            UserDefaults.standard.timeStampOfLastFollowerConnection = nil
        }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            self?.sectionReloadClosure?()
        }

        careLinkStateObserver = CareLinkAccountState.shared.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sectionReloadClosure?() }
        followerSessionStateObserver = FollowerSessionState.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sectionReloadClosure?() }
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    // MARK: - Native layout

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        settingsSections(sectionIDBase: sectionID).flatMap(\.rows)
    }

    func settingsSections(sectionIDBase: Int) -> [SettingsSection] {
        let defaults = UserDefaults.standard
        let source = validatedFollowerSource()
        let primarySectionID = sectionIDBase
        let followerSectionID = sectionIDBase + 1
        let hasNoStoredDevices = coreDataManager.map {
            BLEPeripheralAccessor(coreDataManager: $0).getBLEPeripherals().isEmpty
        } ?? false

        var masterFollowerRow = nativeSettingsRow(
            id: "dataSource.masterFollower",
            index: DataSourceSetting.masterFollower.rawValue,
            sectionID: primarySectionID
        )
        masterFollowerRow.accessory = .none
        masterFollowerRow.control = .menu(options: {
            [
                SettingsMenuOption(title: Texts_SettingsView.master, isSelected: defaults.isMaster),
                SettingsMenuOption(title: Texts_SettingsView.follower, isSelected: !defaults.isMaster)
            ]
        })

        let therapySources = defaults.dataFlowPolicy.availableTherapyDataSources
        var therapyRow = nativeSettingsRow(
            id: "dataSource.therapyDataSource",
            index: DataSourceSetting.therapyDataSource.rawValue,
            sectionID: primarySectionID
        )
        therapyRow.accessory = .none
        therapyRow.control = .menuWithSelectionTitle(
            options: {
                let stored = defaults.therapyDataSourceType
                let displayed = therapySources.contains(stored) ? stored : .automatic
                return therapySources.map { candidate in
                    let title = candidate == .automatic
                        ? "\(candidate.description) (\(defaults.dataFlowPolicy.therapyDataSource.description))"
                        : candidate.description
                    return SettingsMenuOption(title: title, isSelected: candidate == displayed)
                }
            },
            selectionTitle: {
                let selected = defaults.therapyDataSourceType
                if selected == .automatic { return TherapyDataSourceType.automatic.description }
                if selected == .nightscout && !defaults.nightscoutEnabled {
                    return TherapyDataSourceType.none.description
                }
                return defaults.dataFlowPolicy.therapyDataSource.description
            },
            selectOption: { [weak self] index in
                guard therapySources.indices.contains(index) else { return }
                self?.applyTherapyDataSourceType(therapySources[index])
            }
        )

        let keepAliveTypes = FollowerBackgroundKeepAliveType.allCases
        var keepAliveRow = nativeSettingsRow(
            id: "dataSource.followerKeepAlive",
            index: DataSourceSetting.followerKeepAlive.rawValue,
            sectionID: primarySectionID,
            isVisible: !defaults.isMaster
        )
        keepAliveRow.accessory = .none
        keepAliveRow.control = .menu(
            options: {
                keepAliveTypes.map {
                    SettingsMenuOption(
                        title: $0.description,
                        symbolName: $0.keepAliveImageString,
                        isSelected: $0 == defaults.followerBackgroundKeepAliveType
                    )
                }
            },
            selectOption: { [weak self] index in
                guard keepAliveTypes.indices.contains(index) else { return }
                self?.applyFollowerBackgroundKeepAliveType(keepAliveTypes[index])
            }
        )

        let masterUploadRow = nativeSettingsRow(
            id: "dataSource.masterUploadToNightscout",
            index: DataSourceSetting.masterUploadToNightscout.rawValue,
            sectionID: primarySectionID,
            isVisible: defaults.isMaster
        )
        let followerUploadRow = nativeSettingsRow(
            id: "dataSource.followerUploadToNightscout",
            index: DataSourceSetting.followerUploadToNightscout.rawValue,
            sectionID: primarySectionID,
            isVisible: !defaults.isMaster && source != .nightscout
        )

        let enabledSources = FollowerDataSourceType.allEnabledCases
        var sourceRow = nativeSettingsRow(
            id: "dataSource.followerDataSource",
            index: DataSourceSetting.followerDataSource.rawValue,
            sectionID: followerSectionID,
            isVisible: !defaults.isMaster
        )
        sourceRow.accessory = .none
        sourceRow.control = .menu(
            options: {
                enabledSources.map { SettingsMenuOption(title: $0.description, isSelected: $0 == source) }
            },
            selectOption: { [weak self] index in
                guard enabledSources.indices.contains(index) else { return }
                self?.applyFollowerDataSourceType(enabledSources[index])
            }
        )

        let statusRow = followerStatusRow(source: source, sectionID: followerSectionID, isVisible: !defaults.isMaster)

        return [
            SettingsSection(
                title: sectionTitle(),
                footer: defaults.isMaster && hasNoStoredDevices
                    ? warningPrefix + Texts_SettingsView.dataSourceMasterDevicesFooter
                    : nil,
                rows: [masterFollowerRow, therapyRow, keepAliveRow, masterUploadRow, followerUploadRow]
            ),
            SettingsSection(rows: [sourceRow, statusRow])
        ]
    }

    private func followerStatusRow(source: FollowerDataSourceType, sectionID: Int, isVisible: Bool) -> SettingsRow {
        let presentation = FollowerConnectionPresentation.resolve(source: source)
        return SettingsRow(
            id: "dataSource.followerStatus",
            title: Texts_SettingsView.followerServiceStatus,
            detail: presentation.title,
            detailIndicator: SettingsIndicator(color: presentation.color),
            accessory: .disclosure,
            isVisible: isVisible,
            action: .settingsScreen { [selectedFollowerActions] in
                FollowerSettingsScreenFactory.make(
                    source: source,
                    actions: selectedFollowerActions
                )
            }
        )
    }

    private func validatedFollowerSource() -> FollowerDataSourceType {
        let stored = UserDefaults.standard.followerDataSourceType
        return FollowerDataSourceType.validatedSelection(storedRawValue: stored.rawValue)
    }

    // MARK: - Mutations

    private func applyFollowerDataSourceType(_ newType: FollowerDataSourceType) {
        let oldType = UserDefaults.standard.followerDataSourceType
        guard newType != oldType else { return }

        UserDefaults.standard.followerDataSourceType = newType
        UserDefaults.standard.timeStampOfLastFollowerConnection = nil

        trace(
            "follower source data type was changed from '%{public}@' to '%{public}@'",
            log: log,
            category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
            type: .info,
            troubleshooting: .standard(.configuration(.followerSourceChanged(TroubleshootingLogSource(newType)))),
            oldType.description,
            newType.description
        )

        if newType == .dexcomShare && UserDefaults.standard.uploadReadingstoDexcomShare {
            showMessage(
                title: FollowerDataSourceType.dexcomShare.description,
                message: Texts_SettingsView.warningChangeToFollowerDexcomShare
            )
            UserDefaults.standard.uploadReadingstoDexcomShare = false
        }
        if newType == .calendar && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled {
            UserDefaults.standard.followerBackgroundKeepAliveType = .normal
            trace(
                "background keep-alive was automatically changed from Disabled to Normal for Calendar",
                log: log,
                category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                type: .info,
                troubleshooting: .standard(.configuration(.keepAliveChanged(.normal)))
            )
        }
    }

    private func applyFollowerBackgroundKeepAliveType(_ newType: FollowerBackgroundKeepAliveType) {
        let oldType = UserDefaults.standard.followerBackgroundKeepAliveType
        guard newType != oldType else { return }
        UserDefaults.standard.followerBackgroundKeepAliveType = newType
        trace(
            "background keep-alive was changed from '%{public}@' to '%{public}@'",
            log: log,
            category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
            type: .info,
            troubleshooting: .standard(.configuration(.keepAliveChanged(TroubleshootingKeepAliveMode(newType)))),
            oldType.description,
            newType.description
        )

        let message: String
        switch newType {
        case .disabled: message = Texts_SettingsView.followerKeepAliveTypeDisabledMessage
        case .normal: message = Texts_SettingsView.followerKeepAliveTypeNormalMessage
        case .aggressive: message = Texts_SettingsView.followerKeepAliveTypeAggressiveMessage
        case .continuous: message = Texts_SettingsView.followerKeepAliveTypeContinuousMessage
        case .heartbeat: message = Texts_SettingsView.followerKeepAliveTypeHeartbeatMessage
        }
        showMessage(title: Texts_SettingsView.labelfollowerKeepAliveType, message: "\n" + message)
    }

    private func applyTherapyDataSourceType(_ newType: TherapyDataSourceType) {
        let oldType = UserDefaults.standard.therapyDataSourceType
        guard newType != oldType else { return }
        UserDefaults.standard.therapyDataSourceType = newType
        trace(
            "pump and treatment source was changed from '%{public}@' to '%{public}@'",
            log: log,
            category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
            type: .info,
            troubleshooting: .standard(.configuration(.therapySourceChanged(TroubleshootingTherapySource(newType)))),
            oldType.description,
            newType.description
        )
    }

    private func switchMasterFollower() -> SettingsSelectedRowAction {
        guard UserDefaults.standard.isMaster else {
            return .callFunction { [weak self] in self?.applyMode(isMaster: true) }
        }

        let dexcomUploadNeedsDisabling = validatedFollowerSource() == .dexcomShare
            && UserDefaults.standard.uploadReadingstoDexcomShare
        let hasActiveSensor = coreDataManager.map {
            SensorsAccessor(coreDataManager: $0).fetchActiveSensor() != nil
        } ?? false

        let change = { [weak self] in
            if dexcomUploadNeedsDisabling {
                UserDefaults.standard.uploadReadingstoDexcomShare = false
            }
            self?.applyMode(isMaster: false)
        }

        if hasActiveSensor || dexcomUploadNeedsDisabling {
            let message = dexcomUploadNeedsDisabling
                ? Texts_SettingsView.warningChangeFromMasterToFollowerDexcomShare
                : Texts_SettingsView.warningChangeFromMasterToFollower
            return .askConfirmation(
                title: Texts_Common.warning,
                message: message,
                actionHandler: change,
                cancelHandler: nil
            )
        }
        return .callFunction(function: change)
    }

    /// Applies the mode and records only the resulting role. No source credentials, patient alias or
    /// active-sensor details are allowed into the consumer log when this high-impact setting changes.
    private func applyMode(isMaster: Bool) {
        guard UserDefaults.standard.isMaster != isMaster else { return }
        UserDefaults.standard.isMaster = isMaster
        trace(
            "app mode was changed to %{public}@",
            log: log,
            category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
            type: .info,
            troubleshooting: .standard(.configuration(.modeChanged(isMaster: isMaster))),
            isMaster ? "Master" : "Follower"
        )
    }

    private func showMessage(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in self?.messageHandler?(title, message) }
    }

    // MARK: - SettingsViewModelProtocol

    func sectionTitle() -> String? { Texts_SettingsView.sectionTitleDataSource }
    func sectionFooter() -> String? { nil }

    func numberOfRows() -> Int {
        settingsSections(sectionIDBase: 0).flatMap(\.rows).filter(\.isVisible).count
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = DataSourceSetting(rawValue: index) else { fatalError("Unexpected Section") }
        switch setting {
        case .bloodGlucoseUnit: return Texts_SettingsView.labelSelectBgUnit
        case .masterFollower: return Texts_SettingsView.labelMasterOrFollower
        case .masterUploadToNightscout, .followerUploadToNightscout:
            return Texts_SettingsView.labelUploadDataToNightscout
        case .followerKeepAlive: return Texts_SettingsView.labelfollowerKeepAliveType
        case .followerDataSource: return Texts_SettingsView.labelFollowerDataSourceType
        case .followerStatus: return Texts_SettingsView.followerServiceStatus
        case .therapyDataSource: return Texts_SettingsView.labelTherapyDataSourceType
        }
    }

    func accessoryType(index: Int) -> SettingsAccessory {
        guard let setting = DataSourceSetting(rawValue: index) else { fatalError("Unexpected Section") }
        return setting == .followerStatus ? .disclosure : .none
    }

    func detailedText(index: Int) -> String? {
        guard let setting = DataSourceSetting(rawValue: index) else { fatalError("Unexpected Section") }
        switch setting {
        case .bloodGlucoseUnit:
            return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
        case .masterFollower:
            return UserDefaults.standard.isMaster ? Texts_SettingsView.master : Texts_SettingsView.follower
        case .masterUploadToNightscout, .followerUploadToNightscout:
            return UserDefaults.standard.nightscoutEnabled ? nil : Texts_SettingsView.nightscoutNotEnabledRowText
        case .followerKeepAlive:
            return UserDefaults.standard.followerBackgroundKeepAliveType.description
        case .followerDataSource:
            return validatedFollowerSource().description
        case .followerStatus:
            return FollowerConnectionPresentation.resolve(source: validatedFollowerSource()).title
        case .therapyDataSource:
            let policy = UserDefaults.standard.dataFlowPolicy
            if UserDefaults.standard.therapyDataSourceType == .automatic {
                return "\(policy.therapyDataSource.description) (\(Texts_SettingsView.therapyDataSourceAutomatic))"
            }
            if UserDefaults.standard.therapyDataSourceType == .nightscout && !UserDefaults.standard.nightscoutEnabled {
                return "\(Texts_SettingsView.therapyDataSourceNone) (\(Texts_SettingsView.nightscoutNotEnabledRowText))"
            }
            return policy.therapyDataSource.description
        }
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = DataSourceSetting(rawValue: index) else { fatalError("Unexpected Section") }
        switch setting {
        case .masterUploadToNightscout:
            guard UserDefaults.standard.isMaster, UserDefaults.standard.nightscoutEnabled else { return nil }
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.masterUploadDataToNightscout },
                setIsOn: { UserDefaults.standard.masterUploadDataToNightscout = $0 }
            )
        case .followerUploadToNightscout:
            guard UserDefaults.standard.nightscoutEnabled else { return nil }
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.followerUploadDataToNightscout },
                setIsOn: { UserDefaults.standard.followerUploadDataToNightscout = $0 }
            )
        case .bloodGlucoseUnit, .masterFollower, .followerKeepAlive, .followerDataSource, .followerStatus, .therapyDataSource:
            return nil
        }
    }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = DataSourceSetting(rawValue: index) else { fatalError("Unexpected Section") }
        switch setting {
        case .bloodGlucoseUnit:
            return .callFunction { UserDefaults.standard.bloodGlucoseUnitIsMgDl.toggle() }
        case .masterFollower:
            return switchMasterFollower()
        case .masterUploadToNightscout, .followerUploadToNightscout:
            return UserDefaults.standard.nightscoutEnabled
                ? .nothing
                : .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.nightscoutNotEnabled)
        case .followerKeepAlive, .followerDataSource, .followerStatus, .therapyDataSource:
            return .nothing
        }
    }

    func isEnabled(index: Int) -> Bool { true }

    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        index == DataSourceSetting.bloodGlucoseUnit.rawValue
            || index == DataSourceSetting.masterFollower.rawValue
            || index == DataSourceSetting.masterUploadToNightscout.rawValue
            || index == DataSourceSetting.therapyDataSource.rawValue
    }

    func storeMessageHandler(messageHandler: @escaping (String, String) -> Void) {
        self.messageHandler = messageHandler
    }

    func storeRowReloadClosure(rowReloadClosure: @escaping (Int) -> Void) {}

    func storeSectionReloadClosure(sectionReloadClosure: @escaping () -> Void) {
        self.sectionReloadClosure = sectionReloadClosure
    }
}
