import Foundation

extension Aidex: BluetoothPeripheral {

    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        return .AidexType
    }

    func getAddress() -> String {
        return blePeripheral.address
    }

    func getDeviceName() -> String? {
        return blePeripheral.name
    }
}