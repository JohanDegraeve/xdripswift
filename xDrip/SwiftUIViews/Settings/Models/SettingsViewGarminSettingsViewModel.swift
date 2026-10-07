import Foundation
import SwiftUI

final class SettingsViewGarminSettingsViewModel: NSObject, SettingsViewModelProtocol, SettingsNativeSectionProvider {
    private var sectionReloadClosure: (() -> Void)?
    private var observer: NSObjectProtocol?

    override init() {
        super.init()
        observer = NotificationCenter.default.addObserver(
            forName: .garminWatchStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sectionReloadClosure?()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let manager = GarminManager.shared
        let selected = manager.selectedDevice
        let lastError = manager.lastError
        let devices = manager.devices

        return [
            SettingsRow(
                id: "garminWatch.enabled",
                title: Texts_SettingsView.garminWatchEnabled,
                accessory: .none,
                control: .toggle(
                    isOn: { UserDefaults.standard.garminWatchEnabled },
                    setIsOn: { isOn in
                        GarminManager.shared.setEnabled(isOn)
                    }
                )
            ),
            SettingsRow(
                id: "garminWatch.device",
                title: Texts_SettingsView.garminWatchDevice,
                detail: selected?.name ?? Texts_SettingsView.garminWatchNoDevice,
                accessory: .none,
                control: .menu(options: {
                    devices.map { SettingsMenuOption(title: $0.name, isSelected: $0.id == selected?.id) }
                }, selectOption: { index in
                    guard devices.indices.contains(index) else { return }
                    GarminManager.shared.select(devices[index])
                }),
                isEnabled: UserDefaults.standard.garminWatchEnabled && !devices.isEmpty
            ),
            SettingsRow(
                id: "garminWatch.status",
                title: Texts_SettingsView.garminWatchStatus,
                detail: manager.statusText,
                detailIndicator: statusIndicator(manager: manager),
                accessory: .none
            ),
            SettingsRow(
                id: "garminWatch.findWatch",
                title: Texts_SettingsView.garminWatchFindWatch,
                accessory: .disclosure,
                isEnabled: UserDefaults.standard.garminWatchEnabled,
                action: .run {
                    GarminManager.shared.requestDevices()
                }
            ),
            SettingsRow(
                id: "garminWatch.lastReadingSent",
                title: Texts_SettingsView.garminWatchLastReadingSent,
                detail: manager.lastSentAt.map(Self.formattedTime) ?? Texts_SettingsView.garminWatchNoReadingSent,
                accessory: .none
            ),
            SettingsRow(
                id: "garminWatch.lastError",
                title: Texts_SettingsView.garminWatchLastError,
                detail: lastError?.userFacingDescription,
                detailColor: ConstantsAppColors.urgent,
                accessory: .none,
                isVisible: lastError != nil
            ),
            SettingsRow(
                id: "garminWatch.sendTest",
                title: Texts_SettingsView.garminWatchSendTest,
                centerTitle: true,
                isEnabled: manager.isConnected,
                action: .run {
                    GarminManager.shared.sendLatestReading(force: true)
                }
            )
        ]
    }

    func sectionTitle() -> String? {
        Texts_SettingsView.garminWatchConnectionSectionTitle
    }

    func numberOfRows() -> Int { 7 }
    func settingsRowText(index: Int) -> String { "" }
    func accessoryType(index: Int) -> SettingsAccessory { .none }
    func detailedText(index: Int) -> String? { nil }
    func onRowSelect(index: Int) -> SettingsSelectedRowAction { .nothing }
    func isEnabled(index: Int) -> Bool { true }
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool { false }
    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {}
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}

    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }

    private func statusIndicator(manager: GarminManager) -> SettingsIndicator? {
        guard UserDefaults.standard.garminWatchEnabled else { return nil }
        return SettingsIndicator(
            color: manager.isConnected ? ConstantsAppColors.normal : ConstantsAppColors.urgent
        )
    }

    private static func formattedTime(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}
