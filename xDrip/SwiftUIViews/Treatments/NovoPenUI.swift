//
//  NovoPenUI.swift
//  xdrip
//
//  The Treatments screen's NovoPen scan: read an added pen, import the doses and say what happened.
//  Pens are added, with what they are used for, in Treatment settings.
//

import Foundation
import OSLog

@MainActor
final class NovoPenScanModel: ObservableObject {
    enum State: Equatable {
        case idle
        case done(message: String)
    }

    @Published var state: State = .idle

    /// Drives the result alert. Dismissing it returns to `idle`.
    var isShowingResult: Bool {
        get { if case .done = state { return true } else { return false } }
        set { if !newValue { state = .idle } }
    }

    private let importer: NovoPenDoseImporter
    private let defaults: UserDefaults
    private let read: (_ isKnown: @escaping (String) -> Bool) async throws -> NovoPenReadResult
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNovoPen)

    /// A double tap must not start a second read: the NFC reader is per read, so its own guard does not see it.
    private var isScanning = false

    /// `read` gets whether a serial is an added pen, so it can stop before the doses of one that is not.
    /// It throws `CancellationError` for a scan the user backed out of, which ends quietly. Any other error shows `scanFailed`.
    init(importer: NovoPenDoseImporter, defaults: UserDefaults = .standard,
         read: @escaping (_ isKnown: @escaping (String) -> Bool) async throws -> NovoPenReadResult) {
        self.importer = importer
        self.defaults = defaults
        self.read = read
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }
        state = .idle
        let defaults = defaults
        do {
            let result = try await read { defaults.novoPenPenKinds[$0] != nil }
            // Pens are added in Treatment settings, where the user says what each one is for.
            guard let kind = defaults.novoPenPenKinds[result.serial].flatMap(NovoPenPenKind.init(rawValue:)) else {
                state = .done(message: String(format: Texts_NovoPen.penNotAdded, result.serial))
                return
            }
            finish(result, kind: kind)
        } catch is CancellationError {
            state = .idle
        } catch {
            trace("NovoPen: scan failed %{public}@", log: log, category: ConstantsLog.categoryNovoPen, type: .error, String(describing: error))
            state = .done(message: Texts_NovoPen.scanFailed)
        }
    }

    private func finish(_ result: NovoPenReadResult, kind: NovoPenPenKind) {
        do {
            let outcome = try importer.importDoses(result, kind: kind)
            var message = String.localizedStringWithFormat(Texts_NovoPen.importedDoses, outcome.created)
            if result.skipped > 0 { message += String.localizedStringWithFormat(Texts_NovoPen.skippedEntries, result.skipped) }
            if !result.completed { message += "\n" + Texts_NovoPen.readIncomplete }
            if outcome.heldBack > 0 { message += "\n" + Texts_NovoPen.heldBackAirShot }
            state = .done(message: message)
        } catch {
            trace("NovoPen: import of %{public}@ failed %{public}@", log: log, category: ConstantsLog.categoryNovoPen, type: .error, result.serial, String(describing: error))
            state = .done(message: Texts_NovoPen.scanFailed)
        }
    }
}

extension NovoPenScanModel {
    /// Reads a pen through the NFC sheet. With `isKnown` nil (adding a pen) only the serial is read.
    /// Otherwise a pen `isKnown` rejects ends the sheet with `penNotAddedShort`, before its doses.
    /// Where CoreNFC is missing there is no pen to read.
    nonisolated static func nfcRead(isKnown: ((String) -> Bool)?) async throws -> NovoPenReadResult {
        #if os(iOS) && canImport(CoreNFC)
        return try await NovoPenNFCReader().scan(failureMessage: { result in
            if !result.completed { return Texts_NovoPen.readIncomplete }
            if let isKnown, !isKnown(result.serial) { return Texts_NovoPen.penNotAddedShort }
            return nil
        }) { transport, setMessage in
            let transceiver = NovoPenTransceiver(transport: transport)
            try await transceiver.select()
            return try await NovoPenSession(channel: transceiver, wantsDoses: isKnown ?? { _ in false }, progress: {
                setMessage(String.localizedStringWithFormat(Texts_NovoPen.readingDoses, $0))
            }).run()
        }
        #else
        throw NovoPenError.notAPen
        #endif
    }
}

/// The NovoPen section of Treatment settings. Everything but the enable toggle is hidden while scanning is off.
/// A class so the message handler stored by the Settings screen outlives `storeMessageHandler`.
final class NovoPenSettingsProvider: SettingsNativeSectionProvider {
    private static let airShotMaxUnits: [Double] = [1, 2, 3, 4]
    private static let airShotWindowMinutes: [Double] = [1, 2, 5, 10]

    private let defaults: UserDefaults
    private let readSerial: () async throws -> NovoPenReadResult
    private var messageHandler: ((String, String) -> Void)?

    init(defaults: UserDefaults = .standard, readSerial: @escaping () async throws -> NovoPenReadResult = { try await NovoPenScanModel.nfcRead(isKnown: nil) }) {
        self.defaults = defaults
        self.readSerial = readSerial
    }

    /// Scans a pen for its serial only and remembers it as `kind`. A pen added again just gets the new kind.
    /// Showing the message also refreshes the section, so the new pen's row appears.
    @MainActor
    func addPen(_ kind: NovoPenPenKind) async {
        do {
            let result = try await readSerial()
            defaults.novoPenPenKinds[result.serial] = kind.rawValue
            messageHandler?(String(format: Texts_NovoPen.penAdded, result.serial, kind == .bolus ? Texts_NovoPen.penKindBolus : Texts_NovoPen.penKindBasal), "")
        } catch is CancellationError {
        } catch {
            trace("NovoPen: adding a pen failed %{public}@", log: OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNovoPen),
                  category: ConstantsLog.categoryNovoPen, type: .error, String(describing: error))
            messageHandler?(Texts_NovoPen.scanFailed, "")
        }
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let defaults = defaults
        let enabled = defaults.novoPenEnabled
        let ignoring = defaults.novoPenIgnoreAirShots
        var rows = [
            SettingsRow(id: "novoPen.enabled", title: Texts_NovoPen.settingEnabled,
                control: .toggle(isOn: { defaults.novoPenEnabled }, setIsOn: { defaults.novoPenEnabled = $0 })),
            SettingsRow(id: "novoPen.ignoreAirShots", title: Texts_NovoPen.settingIgnoreAirShots,
                control: .toggle(isOn: { defaults.novoPenIgnoreAirShots }, setIsOn: { defaults.novoPenIgnoreAirShots = $0 }),
                isVisible: enabled),
            SettingsRow(id: "novoPen.airShotMaxUnits", title: Texts_NovoPen.settingAirShotMaxUnits, accessory: .none,
                control: .menu(options: {
                    Self.airShotMaxUnits.map { SettingsMenuOption(title: String(format: Texts_NovoPen.units, Int($0)), isSelected: $0 == defaults.novoPenAirShotMaxUnits) }
                }, selectOption: { if Self.airShotMaxUnits.indices.contains($0) { defaults.novoPenAirShotMaxUnits = Self.airShotMaxUnits[$0] } }),
                isEnabled: ignoring, isVisible: enabled),
            SettingsRow(id: "novoPen.airShotWindow", title: Texts_NovoPen.settingAirShotWindow, accessory: .none,
                control: .menu(options: {
                    Self.airShotWindowMinutes.map { SettingsMenuOption(title: String(format: Texts_NovoPen.minutes, Int($0)), isSelected: $0 == defaults.novoPenAirShotWindowMinutes) }
                }, selectOption: { if Self.airShotWindowMinutes.indices.contains($0) { defaults.novoPenAirShotWindowMinutes = Self.airShotWindowMinutes[$0] } }),
                isEnabled: ignoring, isVisible: enabled)
        ]
        // Pick the kind first, then scan: nothing pops up over the NFC sheet.
        rows.append(SettingsRow(id: "novoPen.addPen", title: Texts_NovoPen.addPen, accessory: .none,
            control: .menu(options: {
                [SettingsMenuOption(title: Texts_NovoPen.penKindBolus, isSelected: false),
                 SettingsMenuOption(title: Texts_NovoPen.penKindBasal, isSelected: false)]
            }, selectOption: { [self] index in
                Task { await self.addPen(index == 0 ? .bolus : .basal) }
            }), isVisible: enabled))
        // Bolus / Basal / Forget: a forgotten pen has to be added again before its doses are read.
        for serial in defaults.novoPenPenKinds.keys.sorted() {
            rows.append(SettingsRow(id: "novoPen.pen.\(serial)", title: String(format: Texts_NovoPen.pen, serial), accessory: .none,
                control: .menu(options: {
                    let kind = defaults.novoPenPenKinds[serial]
                    return [SettingsMenuOption(title: Texts_NovoPen.penKindBolus, isSelected: kind == NovoPenPenKind.bolus.rawValue),
                            SettingsMenuOption(title: Texts_NovoPen.penKindBasal, isSelected: kind == NovoPenPenKind.basal.rawValue),
                            SettingsMenuOption(title: Texts_NovoPen.forgetPen, isSelected: false)]
                }, selectOption: { index in
                    switch index {
                    case 0: defaults.novoPenPenKinds[serial] = NovoPenPenKind.bolus.rawValue
                    case 1: defaults.novoPenPenKinds[serial] = NovoPenPenKind.basal.rawValue
                    case 2: defaults.novoPenPenKinds[serial] = nil
                    default: break
                    }
                }), isVisible: enabled))
        }
        return rows
    }

    func sectionTitle() -> String? { nil }
    func sectionFooter() -> String? { defaults.novoPenEnabled ? Texts_NovoPen.airShotFooter : nil }

    private func row(at index: Int) -> SettingsRow? {
        let rows = settingsRows(sectionID: 0)
        return rows.indices.contains(index) ? rows[index] : nil
    }
    func settingsRowText(index: Int) -> String { row(at: index)?.title ?? "" }
    func accessoryType(index: Int) -> SettingsAccessory { .none }
    func detailedText(index: Int) -> String? { row(at: index)?.detail }
    func numberOfRows() -> Int { settingsRows(sectionID: 0).count }
    func onRowSelect(index: Int) -> SettingsSelectedRowAction { .nothing }
    func isEnabled(index: Int) -> Bool { row(at: index)?.isEnabled ?? false }
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool { false }
    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) { self.messageHandler = messageHandler }
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
}
