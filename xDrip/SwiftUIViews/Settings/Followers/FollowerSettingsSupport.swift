//
//  FollowerSettingsSupport.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import Foundation
import os
import SwiftUI

/// Small observable provider used by follower child sections whose rows depend on live state.
final class FollowerSettingsSectionProvider: SettingsNativeSectionProvider {
    private let titleProvider: () -> String?
    private let footerProvider: () -> String?
    private let rowsProvider: (Int) -> [SettingsRow]
    private var sectionReloadClosure: (() -> Void)?
    private var defaultsObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    init(
        title: @escaping () -> String? = { nil },
        footer: @escaping () -> String? = { nil },
        observeDefaults: Bool = true,
        refreshEvery: TimeInterval? = nil,
        monitor: FollowerServiceStatusMonitor? = nil,
        rows: @escaping (Int) -> [SettingsRow]
    ) {
        titleProvider = title
        footerProvider = footer
        rowsProvider = rows

        if observeDefaults {
            defaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: UserDefaults.standard,
                queue: .main
            ) { [weak self] _ in self?.sectionReloadClosure?() }
        }
        if let refreshEvery {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshEvery, repeats: true) { [weak self] _ in
                self?.sectionReloadClosure?()
            }
        }
        monitor?.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sectionReloadClosure?() }
            .store(in: &cancellables)
        FollowerSessionState.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sectionReloadClosure?() }
            .store(in: &cancellables)
    }

    deinit {
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
        refreshTimer?.invalidate()
    }

    func settingsSectionTitle() -> String? { titleProvider() }
    func settingsSectionFooter() -> String? { footerProvider() }
    func settingsRows(sectionID: Int) -> [SettingsRow] { rowsProvider(sectionID) }
    func sectionTitle() -> String? { titleProvider() }
    func sectionFooter() -> String? { footerProvider() }
    func settingsRowText(index: Int) -> String { "" }
    func accessoryType(index: Int) -> SettingsAccessory { .none }
    func detailedText(index: Int) -> String? { nil }
    func numberOfRows() -> Int { rowsProvider(0).count }
    func onRowSelect(index: Int) -> SettingsSelectedRowAction { .nothing }
    func isEnabled(index: Int) -> Bool { true }
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool { false }
    func storeMessageHandler(messageHandler: @escaping (String, String) -> Void) {}
    func storeRowReloadClosure(rowReloadClosure: @escaping (Int) -> Void) {}
    func storeSectionReloadClosure(sectionReloadClosure: @escaping () -> Void) {
        self.sectionReloadClosure = sectionReloadClosure
    }
}

enum FollowerSettingsRows {
    private static let log = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel
    )
    static func accountToolbarActions(
        source: FollowerDataSourceType,
        logOut: @escaping () -> Void
    ) -> [SettingsToolbarAction] {
        [
            SettingsToolbarAction(
                id: "\(source.rawValue).logout",
                title: Texts_SettingsView.followerLogOut,
                symbolName: "rectangle.portrait.and.arrow.right",
                tint: .red,
                isEnabled: { FollowerSessionState.shared.status(for: source) == .loggedIn },
                action: logOut
            )
        ]
    }

    static func loginRow(
        id: String,
        source: FollowerDataSourceType,
        hasCredentials: Bool,
        action: @escaping () -> Void
    ) -> SettingsRow? {
        guard FollowerSessionState.shared.status(for: source) == .loggedOut else { return nil }
        return SettingsRow(
            id: id,
            title: Texts_SettingsView.followerLogIn,
            icon: SettingsIcon(symbolName: "rectangle.portrait.and.arrow.right", color: .accentColor),
            titleColor: .accentColor,
            accessory: .none,
            isEnabled: hasCredentials,
            action: .run(action)
        )
    }

    static func connectionRows(
        idPrefix: String,
        source: FollowerDataSourceType,
        hasCredentials: Bool,
        logIn: @escaping () -> Void
    ) -> [SettingsRow] {
        let presentation = FollowerConnectionPresentation.resolve(source: source)
        var rows = [FollowerConnectionPresentation.bannerRow(
            id: "\(idPrefix).connection.banner",
            presentation: presentation
        )]
        if let login = loginRow(
            id: "\(idPrefix).connection.login",
            source: source,
            hasCredentials: hasCredentials,
            action: logIn
        ) {
            rows.append(login)
        }
        return rows
    }

    static func serviceStatusRow(id: String, monitor: FollowerServiceStatusMonitor) -> SettingsRow {
        SettingsRow(
            id: id,
            title: Texts_SettingsView.followerServiceStatusTitle,
            detail: monitor.status.title,
            detailIndicator: SettingsIndicator(color: monitor.status.color),
            accessory: monitor.statusPageURL == nil ? .none : .disclosure,
            action: monitor.statusPageURL.map { url in .run { UIApplication.shared.open(url) } }
        )
    }

    static func serviceStatusFooter(monitor: FollowerServiceStatusMonitor) -> String? {
        monitor.lastCheckedAt.map {
            "\(Texts_SettingsView.followerLastChecked) \($0.formatted(date: .omitted, time: .shortened))"
        }
    }

    static func textEntryRow(
        id: String,
        title: String,
        message: String,
        currentValue: @escaping () -> String?,
        placeholder: String?,
        obscuresDetail: Bool = true,
        onSave: @escaping (String?) -> Void
    ) -> SettingsRow {
        let value = currentValue()
        return SettingsRow(
            id: id,
            title: title,
            detail: value.map { obscuresDetail ? $0.obscured() : $0 } ?? Texts_SettingsView.valueIsRequired,
            accessory: .disclosure,
            reloadScope: .all,
            action: .textEntry {
                SettingsTextEntryContent(
                    title: title,
                    message: message,
                    keyboardType: .default,
                    text: currentValue(),
                    placeholder: placeholder,
                    fieldTitle: nil,
                    unitText: nil,
                    actionTitle: Texts_Common.Ok,
                    cancelTitle: Texts_Common.Cancel,
                    action: { value in
                        onSave(value.trimmingCharacters(in: .whitespacesAndNewlines).toNilIfLength0())
                    },
                    cancel: nil,
                    validator: nil
                )
            }
        )
    }

    static func aliasRow(id: String = "follower.profile.alias") -> SettingsRow {
        SettingsRow(
            id: id,
            title: Texts_SettingsView.followerPatientName,
            detail: UserDefaults.standard.followerPatientName ?? Texts_SettingsView.followerOptional,
            accessory: .disclosure,
            reloadScope: .all,
            action: .textEntry {
                SettingsTextEntryContent(
                    title: Texts_SettingsView.followerPatientName,
                    message: Texts_SettingsView.followerPatientNameMessage,
                    keyboardType: .default,
                    text: UserDefaults.standard.followerPatientName,
                    placeholder: nil,
                    fieldTitle: nil,
                    unitText: nil,
                    actionTitle: Texts_Common.Ok,
                    cancelTitle: Texts_Common.Cancel,
                    action: { value in
                        let alias = value
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .toNilIfLength0()
                        guard alias != UserDefaults.standard.followerPatientName else { return }
                        UserDefaults.standard.followerPatientName = alias
                        // The alias itself is private and may identify a patient. Record only whether
                        // it was set or removed; never pass the entered text to trace or troubleshooting.
                        trace(
                            "patient alias was %{public}@",
                            log: log,
                            category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel,
                            type: .info,
                            troubleshooting: .standard(.configuration(.patientAliasChanged(isSet: alias != nil))),
                            alias == nil ? "removed" : "changed"
                        )
                    },
                    cancel: nil,
                    validator: nil
                )
            }
        )
    }

    static func connectionActivityRow(id: String = "follower.activity.lastConnection") -> SettingsRow {
        let date = UserDefaults.standard.timeStampOfLastFollowerConnection
        return SettingsRow(
            id: id,
            title: Texts_HomeView.lastConnection,
            detail: date.flatMap { $0 > .distantPast ? $0.daysAndHoursAgo(appendAgo: true) : nil }
                ?? Texts_SettingsView.followerNever,
            detailIndicator: SettingsIndicator(
                color: date.map { $0 > .distantPast ? ConstantsAppColors.normal : ConstantsAppColors.urgent } ?? .gray
            )
        )
    }
}
