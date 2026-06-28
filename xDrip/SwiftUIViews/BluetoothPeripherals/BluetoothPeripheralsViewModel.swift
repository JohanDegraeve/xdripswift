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

final class BluetoothPeripheralsRouter: ObservableObject {
    var openPeripheral: ((BluetoothPeripheral?, BluetoothPeripheralType) -> Void)?
    var showAddPeripheralCategories: (() -> Void)?
    var showPeripheralTypes: ((BluetoothPeripheralCategory) -> Void)?
}

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
                .map { bluetoothPeripheral in
                    BluetoothPeripheralListRow(
                        bluetoothPeripheral: bluetoothPeripheral,
                        title: bluetoothPeripheral.blePeripheral.alias ?? bluetoothPeripheral.blePeripheral.name,
                        connectionStatus: BluetoothPeripheralDisplayStatus(
                            bluetoothTransmitter: bluetoothPeripheralManager.getBluetoothTransmitter(
                                for: bluetoothPeripheral,
                                createANewOneIfNecesssary: false
                            )
                        )
                    )
                }

            guard !rows.isEmpty else { return nil }

            return BluetoothPeripheralsSection(id: category.rawValue, title: category.rawValue, category: category, rows: rows)
        }
    }

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

struct BluetoothPeripheralsSection: Identifiable {
    let id: String
    let title: String
    let category: BluetoothPeripheralCategory
    let rows: [BluetoothPeripheralListRow]

    var systemImage: String {
        category.systemImage()
    }
}

struct BluetoothPeripheralListRow: Identifiable {
    let bluetoothPeripheral: BluetoothPeripheral
    let title: String
    let connectionStatus: BluetoothPeripheralDisplayStatus

    var id: String {
        bluetoothPeripheral.blePeripheral.address
    }

    var typeTitle: String {
        bluetoothPeripheral.bluetoothPeripheralType().rawValue
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
}

struct BluetoothPeripheralsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension BluetoothPeripheralType {
    static let addFlowPreferredOrder: [BluetoothPeripheralCategory: [BluetoothPeripheralType]] = [
        .CGM: [
            .Libre2Type,
            .DexcomType,
            .DexcomG7Type,
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
