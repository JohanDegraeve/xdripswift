//
//  BluetoothPeripheralsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 19/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import CoreBluetooth
import Foundation
import CoreData

// MARK: - Navigation

/// Owns the typed path for the Bluetooth tab's native navigation stack.
final class BluetoothPeripheralsRouter: ObservableObject {
    @Published var path = [BluetoothPeripheralsRoute]()

    func openPeripheral(
        _ bluetoothPeripheral: BluetoothPeripheral?,
        type: BluetoothPeripheralType,
        dexcomConfiguration: DexcomAddConfiguration? = nil
    ) {
        // Return directly to the peripheral list when leaving this detail screen.
        path = [BluetoothPeripheralsRoute(.peripheral(bluetoothPeripheral, type, dexcomConfiguration))]
    }

    func showDexcomConnectionMode(type: BluetoothPeripheralType) {
        path.append(BluetoothPeripheralsRoute(.dexcomConnectionMode(type)))
    }

    func showSensorCodeCapture(_ capture: DexcomSensorCodeCapture) {
        path.append(BluetoothPeripheralsRoute(.sensorCodeCapture(capture)))
    }

    func showManualSensorCodeEntry(_ entry: DexcomManualSensorCodeEntry) {
        path.append(BluetoothPeripheralsRoute(.manualSensorCodeEntry(entry)))
    }

    // Collect the identifier before creating the detail screen. See README.md for the full flow.
    func showDexcomTransmitterID(type: BluetoothPeripheralType, configuration: DexcomAddConfiguration) {
        let isG6 = type == .DexcomType
        var entry = BluetoothPeripheralTextEntry(
            title: Texts_SettingsView.labelTransmitterId,
            message: isG6 ? Texts_SettingsView.labelGiveTransmitterId : Texts_SettingsView.dexcomG7Message,
            keyboardType: .alphabet,
            textInputAutocapitalization: isG6 ? .characters : .words,
            text: nil,
            placeholder: isG6 ? "000000" : "DX0000",
            actionTitle: Texts_HomeView.sensorCodeContinue,
            cancelTitle: Texts_Common.Cancel,
            actionHandler: { [weak self] transmitterID in
                var updatedConfiguration = configuration
                let identifier = isG6 ? transmitterID.uppercased() : transmitterID
                updatedConfiguration.transmitterID = identifier.toNilIfLength0()
                    ?? ConstantsBluetoothPairing.dummyDexcomG7TypeTransmitterId
                // Keep the setup screen in the stack to avoid a back-and-forward transition.
                self?.path.append(BluetoothPeripheralsRoute(.peripheral(nil, type, updatedConfiguration)))
            },
            actionIsEnabled: { !isG6 || $0.count == 6 },
            inputValidator: { type.validateTransmitterId(transmitterId: $0) }
        )
        entry.dismissAfterSubmit = false
        showTextEntry(entry)
    }

    func showAddPeripheralCategories() {
        path.append(BluetoothPeripheralsRoute(.categories))
    }

    func showPeripheralTypes(category: BluetoothPeripheralCategory) {
        path.append(BluetoothPeripheralsRoute(.types(category)))
    }

    func showTextEntry(_ textEntry: BluetoothPeripheralTextEntry) {
        path.append(BluetoothPeripheralsRoute(.textEntry(textEntry)))
    }

    func showSelectionList(_ selectionList: BluetoothPeripheralSelectionList) {
        path.append(BluetoothPeripheralsRoute(.selectionList(selectionList)))
    }

    func showBatteryHistory(peripheralObjectID: NSManagedObjectID) {
        path.append(BluetoothPeripheralsRoute(.batteryHistory(peripheralObjectID)))
    }

    func showReadSuccess(_ display: TransmitterReadSuccessDisplay, transmitterTitle: String) {
        path.append(BluetoothPeripheralsRoute(.readSuccess(display, transmitterTitle)))
    }

    func closeCurrentView() {
        guard !path.isEmpty else { return }

        path.removeLast()
    }
}

/// Typed route stored by the Bluetooth tab's native NavigationStack.
///
/// Route identity is intentionally independent of its payload because several existing editor
/// models contain action closures and therefore cannot conform to Hashable themselves.
struct BluetoothPeripheralsRoute: Hashable {
    enum Destination {
        case categories
        case types(BluetoothPeripheralCategory)
        case dexcomConnectionMode(BluetoothPeripheralType)
        case sensorCodeCapture(DexcomSensorCodeCapture)
        case manualSensorCodeEntry(DexcomManualSensorCodeEntry)
        case peripheral(BluetoothPeripheral?, BluetoothPeripheralType, DexcomAddConfiguration?)
        case textEntry(BluetoothPeripheralTextEntry)
        case selectionList(BluetoothPeripheralSelectionList)
        case readSuccess(TransmitterReadSuccessDisplay, String)
        case batteryHistory(NSManagedObjectID)
    }

    let id = UUID()
    let destination: Destination

    init(_ destination: Destination) {
        self.destination = destination
    }

    static func == (lhs: BluetoothPeripheralsRoute, rhs: BluetoothPeripheralsRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct DexcomAddConfiguration {
    let useOtherApp: Bool
    // Nil means it has not been entered. G7 stores the scan placeholder when left blank.
    var transmitterID: String?
    var sensorLabel: DexcomG6SensorLabel?
    var g6BluetoothSlot: DexcomG6BluetoothSlot = .defaultSlot
    var g7BluetoothSlot: DexcomG7BluetoothSlot = .defaultSlot
}

struct DexcomSensorCodeCapture {
    let configuration: SensorStartCodeView.Configuration
    let initialCode: String
    let initialLabel: DexcomG6SensorLabel?
    let dismissAfterSubmit: Bool
    let onSubmit: (String, DexcomG6SensorLabel?) -> Void
}

struct DexcomManualSensorCodeEntry {
    let title: String
    let message: String
    let placeholder: String
    let onSelect: (String) -> Void
}

// MARK: - List State

/// Builds Bluetooth list sections from the existing peripheral manager and refreshes live status.
@MainActor final class BluetoothPeripheralsViewModel: ObservableObject {
    @Published private(set) var sections: [BluetoothPeripheralsSection] = []
    @Published var pendingAlert: BluetoothPeripheralsAlert?

    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    private var statusRefreshTimer: AnyCancellable?

    init(bluetoothPeripheralManager: BluetoothPeripheralManaging) {
        self.bluetoothPeripheralManager = bluetoothPeripheralManager

        initializeBluetoothTransmitterDelegates()
        reload()
    }

    func initializeBluetoothTransmitterDelegates() {
        bluetoothPeripheralManager?.getBluetoothTransmitters().forEach { bluetoothTransmitter in
            bluetoothTransmitter.bluetoothTransmitterDelegate = self
        }
    }

    func reload() {
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            sections = []
            return
        }

        sections = BluetoothPeripheralCategory.allCases.flatMap { category -> [BluetoothPeripheralsSection] in
            let rows = bluetoothPeripheralManager.getBluetoothPeripherals()
                .filter { $0.bluetoothPeripheralType().category() == category }
                .enumerated()
                .map { index, bluetoothPeripheral in
                    (
                        index: index,
                        row: BluetoothPeripheralListRow(
                            bluetoothPeripheral: bluetoothPeripheral,
                            title: bluetoothPeripheral.blePeripheral.alias ?? bluetoothPeripheral.blePeripheral.name,
                            shouldConnect: bluetoothPeripheral.blePeripheral.shouldconnect,
                            connectionStatus: BluetoothPeripheralDisplayStatus(
                                bluetoothTransmitter: bluetoothPeripheralManager.getBluetoothTransmitter(
                                    for: bluetoothPeripheral,
                                    createANewOneIfNecesssary: false
                                ),
                                bluetoothPeripheral: bluetoothPeripheral
                            )
                        )
                    )
                }
                .sorted {
                    if $0.row.sortPriority != $1.row.sortPriority {
                        return $0.row.sortPriority < $1.row.sortPriority
                    }

                    return $0.index < $1.index
                }
                .map(\.row)

            guard !rows.isEmpty else { return [] }

            return makeSections(for: category, rows: rows)
        }
    }

    private func makeSections(for category: BluetoothPeripheralCategory, rows: [BluetoothPeripheralListRow]) -> [BluetoothPeripheralsSection] {
        let activeRows = rows.filter(\.isActive)
        guard !activeRows.isEmpty else {
            return [
                BluetoothPeripheralsSection(
                    id: category.rawValue,
                    title: category.rawValue,
                    category: category,
                    rows: rows
                )
            ]
        }

        let inactiveRows = rows.filter { !$0.isActive }
        var categorySections = [
            BluetoothPeripheralsSection(
                id: category.rawValue + "-active",
                title: category.rawValue,
                category: category,
                rows: activeRows
            )
        ]

        if !inactiveRows.isEmpty {
            categorySections.append(
                BluetoothPeripheralsSection(
                    id: category.rawValue + "-inactive",
                    title: nil,
                    category: category,
                    rows: inactiveRows
                )
            )
        }

        return categorySections
    }

    /// Starts the lightweight status refresh used while the Bluetooth list is visible.
    func startStatusUpdates() {
        initializeBluetoothTransmitterDelegates()
        reload()

        guard statusRefreshTimer == nil else { return }

        statusRefreshTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reload()
                }
            }
    }

    func stopStatusUpdates() {
        statusRefreshTimer?.cancel()
        statusRefreshTimer = nil
    }

    func bluetoothPeripheralTypes(for category: BluetoothPeripheralCategory) -> [BluetoothPeripheralType] {
        let categoryTypes = BluetoothPeripheralType.allCases.filter { $0.category() == category }

        guard let preferredOrder = BluetoothPeripheralType.addFlowPreferredOrder[category] else {
            return categoryTypes
        }

        let preferredTypes = preferredOrder.filter { categoryTypes.contains($0) }
        let remainingTypes = categoryTypes.filter { !preferredTypes.contains($0) }

        return preferredTypes + remainingTypes
    }

    func validateCanAdd(category: BluetoothPeripheralCategory) -> Bool {
        guard category == .CGM else { return true }

        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else { return true }

        let alreadyHasActiveCGM = bluetoothPeripheralManager.getBluetoothPeripherals().contains {
            $0.bluetoothPeripheralType().category() == .CGM && $0.blePeripheral.shouldconnect
        }

        if alreadyHasActiveCGM {
            pendingAlert = BluetoothPeripheralsAlert(
                title: Texts_Common.warning,
                message: Texts_BluetoothPeripheralsView.noMultipleActiveCGMsAllowed
            )
            return false
        }

        if !UserDefaults.standard.isMaster {
            pendingAlert = BluetoothPeripheralsAlert(
                title: Texts_Common.warning,
                message: Texts_BluetoothPeripheralView.cannotActiveCGMInFollowerMode
            )
            return false
        }

        return true
    }
}

extension BluetoothPeripheralsViewModel: @preconcurrency BluetoothTransmitterDelegate {
    func heartBeat() {
        bluetoothPeripheralManager?.heartBeat()
    }

    func transmitterNeedsPairing(bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralManager?.transmitterNeedsPairing(bluetoothTransmitter: bluetoothTransmitter)
    }

    func successfullyPaired() {
        bluetoothPeripheralManager?.successfullyPaired()
    }

    func pairingFailed() {
        bluetoothPeripheralManager?.pairingFailed()
    }

    func error(message: String) {
        bluetoothPeripheralManager?.error(message: message)
        pendingAlert = BluetoothPeripheralsAlert(title: Texts_Common.warning, message: message)
    }

    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralManager?.didConnectTo(bluetoothTransmitter: bluetoothTransmitter)
        reload()
    }

    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralManager?.didDisconnectFrom(bluetoothTransmitter: bluetoothTransmitter)
        reload()
    }

    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralManager?.deviceDidUpdateBluetoothState(
            state: state,
            bluetoothTransmitter: bluetoothTransmitter
        )
        reload()
    }
}

// MARK: - Row Models

/// One Bluetooth category and its currently configured peripherals.
struct BluetoothPeripheralsSection: Identifiable {
    let id: String
    let title: String?
    let category: BluetoothPeripheralCategory
    let rows: [BluetoothPeripheralListRow]

    var showsHeader: Bool {
        title != nil
    }

    var systemImage: String {
        category.systemImage()
    }
}

/// Value presentation for one configured Bluetooth peripheral.
struct BluetoothPeripheralListRow: Identifiable {
    let bluetoothPeripheral: BluetoothPeripheral
    let title: String
    let shouldConnect: Bool
    let connectionStatus: BluetoothPeripheralDisplayStatus

    var id: String {
        bluetoothPeripheral.blePeripheral.address
    }

    // Selected peripherals are promoted into the first category section.
    // This keeps the active device visually separate from saved inactive devices.
    var isActive: Bool {
        if shouldConnect {
            return true
        }

        switch connectionStatus {
        case .connected:
            return true
        case .discovering, .connecting, .reconnecting, .waitingForNextReading:
            return shouldConnect
        case .notScanning:
            return false
        }
    }

    // The selected transmitter belongs at the top even when Bluetooth is between
    // scanning and connected phases. The remaining rows keep the manager order.
    var sortPriority: Int {
        if shouldConnect {
            return 0
        }

        return connectionStatus.sortPriority
    }

    var typeTitle: String {
        // Resolve configured Dexcom rows from their own transmitter ID. The global active sensor
        // can belong to another row and must not determine this device's product name.
        if let dexcomG5 = bluetoothPeripheral as? DexcomG5 {
            return DexcomProductNameResolver.title(
                transmitterType: .dexcom,
                transmitterID: dexcomG5.blePeripheral.transmitterId,
                bluetoothName: dexcomG5.blePeripheral.name,
                isAnubis: dexcomG5.isAnubis
            ) ?? bluetoothPeripheral.bluetoothPeripheralType().bluetoothPeripheralDisplayTitle
        }
        if let dexcomG7 = bluetoothPeripheral as? DexcomG7 {
            // Automatic G7 discovery stores `DX0000` in Core Data before the real Bluetooth name
            // is known. Use the same resolver as the detail screen so the list does not fall back
            // to Dexcom G7 when the connected device is actually ONE+ or Stelo.
            return DexcomProductNameResolver.title(
                transmitterType: .dexcomG7,
                transmitterID: dexcomG7.blePeripheral.transmitterId,
                bluetoothName: dexcomG7.blePeripheral.name
            ) ?? bluetoothPeripheral.bluetoothPeripheralType().bluetoothPeripheralDisplayTitle
        }
        return bluetoothPeripheral.bluetoothPeripheralType().bluetoothPeripheralDisplayTitle
    }

    var dexcomConnectionMode: DexcomConnectionMode? {
        if let dexcomG5 = bluetoothPeripheral as? DexcomG5 {
            return DexcomConnectionMode(useOtherApp: dexcomG5.useOtherApp)
        }
        if let dexcomG7 = bluetoothPeripheral as? DexcomG7 {
            return DexcomConnectionMode(useOtherApp: dexcomG7.useOtherApp)
        }
        return nil
    }

}

enum BluetoothPeripheralDisplayStatus: Equatable {
    case notScanning
    case discovering
    case connecting
    case reconnecting
    case waitingForNextReading
    case connected

    init(
        bluetoothTransmitter: BluetoothTransmitter?,
        bluetoothPeripheral: BluetoothPeripheral?,
        isDiscoveringNewPeripheral: Bool = false
    ) {
        self.init(
            isConnected: bluetoothTransmitter?.getConnectionStatus() == .connected,
            isEnabled: bluetoothPeripheral?.blePeripheral.shouldconnect == true,
            hasConnectedSinceActivation: bluetoothPeripheral?.blePeripheral.hasConnectedSinceActivation == true,
            usesIntermittentConnection: bluetoothPeripheral?.bluetoothPeripheralType().usesIntermittentConnection == true,
            isDiscoveringNewPeripheral: isDiscoveringNewPeripheral
        )
    }

    /// Pure resolver used by every UI surface and by the state-matrix tests.
    init(
        isConnected: Bool,
        isEnabled: Bool,
        hasConnectedSinceActivation: Bool,
        usesIntermittentConnection: Bool,
        isDiscoveringNewPeripheral: Bool = false
    ) {
        if isConnected {
            self = .connected
            return
        }

        if isDiscoveringNewPeripheral {
            self = .discovering
            return
        }

        guard isEnabled else {
            self = .notScanning
            return
        }

        guard hasConnectedSinceActivation else {
            self = .connecting
            return
        }

        self = usesIntermittentConnection
            ? .waitingForNextReading
            : .reconnecting
    }

    // Active rows are handled by BluetoothPeripheralListRow. This only orders
    // the remaining live Bluetooth states.
    var sortPriority: Int {
        switch self {
        case .connected:
            return 1
        case .waitingForNextReading:
            return 2
        case .discovering, .connecting, .reconnecting:
            return 3
        case .notScanning:
            return 4
        }
    }

    var fullStatusText: String {
        switch self {
        case .notScanning:
            return Texts_BluetoothPeripheralView.notTryingToConnect
        case .discovering:
            return Texts_BluetoothPeripheralView.scanningForTransmitter
        case .connecting:
            return Texts_BluetoothPeripheralView.connectingToTransmitter
        case .reconnecting:
            return Texts_BluetoothPeripheralView.reconnectingToTransmitter
        case .waitingForNextReading:
            return Texts_BluetoothPeripheralView.waiting
        case .connected:
            return Texts_BluetoothPeripheralView.connected
        }
    }

    var compactStatusText: String {
        switch self {
        case .notScanning:
            return Texts_BluetoothPeripheralView.notTryingToConnect
        case .discovering:
            return Texts_BluetoothPeripheralView.scanning
        case .connecting:
            return Texts_BluetoothPeripheralView.connecting
        case .reconnecting:
            return Texts_BluetoothPeripheralView.reconnecting
        case .waitingForNextReading:
            return Texts_BluetoothPeripheralView.waiting
        case .connected:
            return Texts_BluetoothPeripheralView.connected
        }
    }

    var showsElapsedTime: Bool {
        switch self {
        case .discovering, .connecting, .reconnecting, .waitingForNextReading:
            return true
        case .notScanning, .connected:
            return false
        }
    }
}

/// Alert requested while validating or adding a Bluetooth peripheral.
struct BluetoothPeripheralsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension BluetoothPeripheralType {
    // DexcomG7Type shares the same user-facing label as DexcomG7HeartBeatType,
    // but its synthesized raw value is the enum case name.
    var bluetoothPeripheralDisplayTitle: String {
        switch self {
        case .DexcomG7Type:
            return BluetoothPeripheralType.DexcomG7HeartBeatType.rawValue
        case .BubbleType:
            return "Bubble/Mini/Nano"
        case .MedtrumTouchCareNanoType:
            return "Medtrum Nano Pump"
        default:
            return rawValue
        }
    }

    static let addFlowPreferredOrder: [BluetoothPeripheralCategory: [BluetoothPeripheralType]] = [
        .CGM: [
            .Libre2Type,
            .DexcomType,
            .DexcomG7Type,
            .MiaoMiaoType,
            .BubbleType,
            .MedtrumTouchCareNanoType
        ]
    ]
}

extension BluetoothPeripheralCategory {
    func systemImage(for connectionStatus: BluetoothPeripheralDisplayStatus = .notScanning) -> String {
        switch self {
        case .CGM:
            return connectionStatus == .connected
                ? "sensor.radiowaves.left.and.right.fill"
                : "sensor.radiowaves.left.and.right"
        case .M5Stack:
            return connectionStatus == .connected ? "tv.fill" : "tv"
        case .HeartBeat:
            return connectionStatus == .connected ? "heart.fill" : "heart"
        }
    }
}
