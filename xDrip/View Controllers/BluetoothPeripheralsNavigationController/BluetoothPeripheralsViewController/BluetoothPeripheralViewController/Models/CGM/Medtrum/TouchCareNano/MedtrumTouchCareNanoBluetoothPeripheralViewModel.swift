import UIKit

class MedtrumTouchCareNanoBluetoothPeripheralViewModel {

    private enum Settings: Int, CaseIterable {
        case dependencyHint = 0
        case firmware = 1
    }

    private let sectionNumberForMedtrumSpecificSettings = 0

    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?

    private weak var tableView: UITableView?

    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?

    private var bluetoothPeripheral: BluetoothPeripheral?

    private var medtrumNano: MedtrumTouchCareNano? {
        return bluetoothPeripheral as? MedtrumTouchCareNano
    }

    deinit {
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager,
              let medtrumNano = medtrumNano,
              let transmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: medtrumNano, createANewOneIfNecesssary: false),
              let medtrumTransmitter = transmitter as? CGMMedtrumTouchCareNanoTransmitter else { return }
        medtrumTransmitter.cGMMedtrumTouchCareNanoTransmitterDelegate = bluetoothPeripheralManager as? CGMMedtrumTouchCareNanoTransmitterDelegate
    }
}

extension MedtrumTouchCareNanoBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {

    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        self.tableView = tableView
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        self.bluetoothPeripheral = bluetoothPeripheral

        if let bluetoothPeripheral = bluetoothPeripheral {
            if let medtrumNano = bluetoothPeripheral as? MedtrumTouchCareNano,
               let transmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: medtrumNano, createANewOneIfNecesssary: false),
               let medtrumTransmitter = transmitter as? CGMMedtrumTouchCareNanoTransmitter {
                medtrumTransmitter.cGMMedtrumTouchCareNanoTransmitterDelegate = self
            }
        }
    }

    func screenTitle() -> String {
        return BluetoothPeripheralType.MedtrumTouchCareNanoType.rawValue
    }

    func sectionTitle(forSection section: Int) -> String {
        return BluetoothPeripheralType.MedtrumTouchCareNanoType.rawValue
    }

    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        guard let medtrumNano = bluetoothPeripheral as? MedtrumTouchCareNano else {
            fatalError("MedtrumTouchCareNanoBluetoothPeripheralViewModel.update: peripheral is not MedtrumTouchCareNano")
        }
        cell.accessoryView = nil
        guard let setting = Settings(rawValue: rawValue) else {
            fatalError("MedtrumTouchCareNanoBluetoothPeripheralViewModel.update: unexpected row \(rawValue)")
        }

        switch setting {
        case .dependencyHint:
            cell.textLabel?.text = "Requires Medtrum EasyPatch"
            cell.detailTextLabel?.text = "EasyPatch must be installed and running for sensor data."
            cell.accessoryType = .none
        case .firmware:
            cell.textLabel?.text = Texts_Common.firmware
            cell.detailTextLabel?.text = medtrumNano.firmware
            cell.accessoryType = .none
        }
    }

    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        return .nothing
    }

    func numberOfSettings(inSection section: Int) -> Int {
        return Settings.allCases.count
    }

    func numberOfSections() -> Int {
        return 1
    }
}

extension MedtrumTouchCareNanoBluetoothPeripheralViewModel: CGMMedtrumTouchCareNanoTransmitterDelegate {

    func received(firmware: String, from cGMMedtrumTouchCareNanoTransmitter: CGMMedtrumTouchCareNanoTransmitter) {
        (bluetoothPeripheralManager as? CGMMedtrumTouchCareNanoTransmitterDelegate)?.received(firmware: firmware, from: cGMMedtrumTouchCareNanoTransmitter)
        reloadRow(row: Settings.firmware.rawValue)
    }

    private func reloadRow(row: Int) {
        DispatchQueue.main.async {
            guard let tableView = self.tableView,
                  let viewController = self.bluetoothPeripheralViewController else { return }
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
            let totalSections = tableView.numberOfSections
            let section = viewController.numberOfGeneralSections() + self.sectionNumberForMedtrumSpecificSettings
            guard section < totalSections else {
                tableView.reloadData()
                return
            }
            if row < tableView.numberOfRows(inSection: section) {
                tableView.reloadRows(at: [IndexPath(row: row, section: section)], with: .none)
            } else {
                tableView.reloadSections(IndexSet(integer: section), with: .none)
            }
        }
    }
}
