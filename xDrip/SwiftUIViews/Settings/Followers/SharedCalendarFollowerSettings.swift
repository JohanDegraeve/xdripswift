//
//  SharedCalendarFollowerSettings.swift
//  xdrip
//
//  Created by Paul Plant on 8/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import EventKit
import SwiftUI

/// Owns all Calendar follower configuration, status and historical-reading rows.
enum SharedCalendarFollowerSettingsScreen {
    static func make(refresh: @escaping () -> Void) -> SettingsScreen {
        SettingsScreen(title: FollowerDataSourceType.calendar.description, onlineHelpTopic: FollowerDataSourceType.calendar.onlineHelpTopic, providers: {
            [
                SharedCalendarSelectionProvider(),
                FollowerSettingsSectionProvider(title: { Texts_SettingsView.followerSectionConnection }, refreshEvery: 30) { _ in
                    let presentation = FollowerConnectionPresentation.resolve(source: .calendar)
                    return [
                        FollowerConnectionPresentation.bannerRow(id: "calendarFollow.connection.banner", presentation: presentation),
                        SettingsRow(
                            id: "calendarFollow.connection.refresh",
                            title: Texts_SettingsView.followerRefresh,
                            icon: SettingsIcon(symbolName: "arrow.clockwise", color: .accentColor),
                            titleColor: .accentColor,
                            accessory: .none,
                            isEnabled: UserDefaults.standard.calendarFollowCalendarId != nil,
                            action: .run(refresh)
                        )
                    ]
                },
                FollowerSettingsSectionProvider(
                    title: { Texts_SettingsView.followerSectionLatestData },
                    footer: { Texts_SettingsView.calendarFollowStatusFooter },
                    refreshEvery: 30
                ) { _ in latestDataRows() },
                FollowerSettingsSectionProvider(
                    title: { Texts_SettingsView.calendarFollowHistoricalReadings },
                    footer: { Texts_SettingsView.calendarFollowHistoricalReadingsFooter },
                    refreshEvery: 30
                ) { _ in historicalRows() }
            ]
        })
    }

    private static func latestDataRows() -> [SettingsRow] {
        guard let payload = latestPayload() else {
            return [
                SettingsRow(id: "calendarFollow.latest.value", title: Texts_SettingsView.calendarShareLastValue, detail: "-"),
                SettingsRow(id: "calendarFollow.latest.timestamp", title: Texts_BgReadings.timestamp, detail: "-")
            ]
        }
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        return [
            SettingsRow(
                id: "calendarFollow.latest.value",
                title: Texts_SettingsView.calendarShareLastValue,
                detail: payload.bgMgDl.mgDlToMmolAndToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
            ),
            SettingsRow(
                id: "calendarFollow.latest.timestamp",
                title: Texts_BgReadings.timestamp,
                detail: payload.followerBgReading.timeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
            )
        ]
    }

    private static func historicalRows() -> [SettingsRow] {
        let readings = latestPayload()?.historicalFollowerBgReadings ?? []
        guard !readings.isEmpty else {
            return [SettingsRow(id: "calendarFollow.history.none", title: Texts_SettingsView.calendarFollowNoHistoricalData)]
        }
        return [
            SettingsRow(id: "calendarFollow.history.count", title: Texts_SettingsView.calendarFollowHistoricalCount, detail: readings.count.description),
            SettingsRow(
                id: "calendarFollow.history.first",
                title: Texts_SettingsView.calendarFollowFirstHistoricalReading,
                detail: readings.last.map { $0.timeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .short) + " (" + $0.timeStamp.daysAndHoursAgo() + ")" }
            )
        ]
    }

    private static func latestPayload() -> CalendarSharePayload? {
        guard calendarAccessIsAuthorized(),
              let selected = UserDefaults.standard.calendarFollowCalendarId else { return nil }
        let store = EKEventStore()
        guard let calendar = store.calendars(for: .event).first(where: { $0.title == selected }) else { return nil }
        let predicate = store.predicateForEvents(
            withStart: Date(timeIntervalSinceNow: -24 * 3600),
            end: Date(timeIntervalSinceNow: 30 * 60),
            calendars: [calendar]
        )
        return store.events(matching: predicate)
            .compactMap { CalendarSharePayload.decode(from: $0.notes) }
            .max { $0.timestampMillis < $1.timestampMillis }
    }

    private static func calendarAccessIsAuthorized() -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized: return true
        case .fullAccess: return true
        default: return false
        }
    }
}

private final class SharedCalendarSelectionProvider: SettingsNativeSectionProvider {
    private let eventStore = EKEventStore()

    func settingsSectionTitle() -> String? { Texts_SettingsView.followerSectionCalendar }
    func settingsSectionFooter() -> String? { Texts_SettingsView.calendarFollowCalendarFooter }
    func settingsRows(sectionID: Int) -> [SettingsRow] {
        [SettingsRow(
            id: "calendarFollow.calendar.selection",
            title: Texts_SettingsView.calenderId,
            detail: UserDefaults.standard.calendarFollowCalendarId ?? Texts_SettingsView.valueIsRequired,
            accessory: .disclosure,
            reloadScope: .all,
            action: .legacy(action: { [weak self] in self?.selectionAction() ?? .nothing }, rowIndex: 0, viewModel: self)
        )]
    }

    private func selectionAction() -> SettingsSelectedRowAction {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { _, _ in }
            } else {
                eventStore.requestAccess(to: .event) { _, _ in }
            }
            return .nothing
        case .denied:
            return .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoCalendarAccessDeniedByUser)
        case .restricted:
            return .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoCalendarAccessRestricted)
        case .writeOnly:
            return .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.infoCalendarAccessWriteOnly)
        case .authorized, .fullAccess:
            let calendars = eventStore.calendars(for: .event).map(\.title)
            return .selectFromList(
                title: Texts_SettingsView.calenderId,
                data: calendars,
                selectedRow: calendars.firstIndex(of: UserDefaults.standard.calendarFollowCalendarId ?? ""),
                actionTitle: nil,
                cancelTitle: nil,
                actionHandler: { index in
                    guard calendars.indices.contains(index) else { return }
                    UserDefaults.standard.calendarFollowCalendarId = calendars[index]
                    UserDefaults.standard.calendarFollowStatus = CalendarShareStatus.noData.rawValue
                    UserDefaults.standard.timeStampOfLastFollowerConnection = nil
                },
                cancelHandler: nil,
                didSelectRowHandler: nil
            )
        @unknown default:
            return .nothing
        }
    }

    func sectionTitle() -> String? { settingsSectionTitle() }
    func sectionFooter() -> String? { settingsSectionFooter() }
    func settingsRowText(index: Int) -> String { Texts_SettingsView.calenderId }
    func accessoryType(index: Int) -> SettingsAccessory { .disclosure }
    func detailedText(index: Int) -> String? { UserDefaults.standard.calendarFollowCalendarId }
    func numberOfRows() -> Int { 1 }
    func onRowSelect(index: Int) -> SettingsSelectedRowAction { selectionAction() }
    func isEnabled(index: Int) -> Bool { true }
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool { false }
    func storeMessageHandler(messageHandler: @escaping (String, String) -> Void) {}
    func storeRowReloadClosure(rowReloadClosure: @escaping (Int) -> Void) {}
}
