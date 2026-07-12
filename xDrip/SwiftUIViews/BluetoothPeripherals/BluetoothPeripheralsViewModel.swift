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

// MARK: - Navigation

/// Owns the typed path for the Bluetooth tab's native navigation stack.
final class BluetoothPeripheralsRouter: ObservableObject {
    @Published var path = [BluetoothPeripheralsRoute]()

    func openPeripheral(_ bluetoothPeripheral: BluetoothPeripheral?, type: BluetoothPeripheralType) {
        path.append(BluetoothPeripheralsRoute(.peripheral(bluetoothPeripheral, type)))
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
        case peripheral(BluetoothPeripheral?, BluetoothPeripheralType)
        case textEntry(BluetoothPeripheralTextEntry)
        case selectionList(BluetoothPeripheralSelectionList)
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

        sections = BluetoothPeripheralCategory.allCases.compactMap { category in
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
                                isScanningForNewPeripheral: bluetoothPeripheral.blePeripheral.shouldconnect
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

            guard !rows.isEmpty else { return nil }

            return BluetoothPeripheralsSection(id: category.rawValue, title: category.rawValue, category: category, rows: rows)
        }
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
    let title: String
    let category: BluetoothPeripheralCategory
    let rows: [BluetoothPeripheralListRow]

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

    // The selected transmitter belongs at the top even when Bluetooth is between
    // scanning and connected phases. The remaining rows keep the manager order.
    var sortPriority: Int {
        if shouldConnect {
            return 0
        }

        return connectionStatus.sortPriority
    }

    var typeTitle: String {
        bluetoothPeripheral.bluetoothPeripheralType().bluetoothPeripheralDisplayTitle
    }

}

enum BluetoothPeripheralDisplayStatus {
    case notScanning
    case scanning
    case connected

    init(bluetoothTransmitter: BluetoothTransmitter?, isScanningForNewPeripheral: Bool = false) {
        if bluetoothTransmitter?.getConnectionStatus() == .connected {
            self = .connected
        } else if bluetoothTransmitter?.getConnectionStatus() == .connecting ||
                    bluetoothTransmitter?.isScanning() == true ||
                    isScanningForNewPeripheral {
            self = .scanning
        } else {
            self = .notScanning
        }
    }

    // Active rows are handled by BluetoothPeripheralListRow. This only orders
    // the remaining live Bluetooth states.
    var sortPriority: Int {
        switch self {
        case .connected:
            return 1
        case .scanning:
            return 2
        case .notScanning:
            return 3
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
        default:
            return rawValue
        }
    }

    static let addFlowPreferredOrder: [BluetoothPeripheralCategory: [BluetoothPeripheralType]] = [
        .CGM: [
            .Libre2Type,
            .DexcomType,
            .DexcomG7Type,
            .MedtrumTouchCareNanoType,
            .MiaoMiaoType,
            .BubbleType
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
