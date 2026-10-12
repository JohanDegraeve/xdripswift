import Foundation

extension Ottai: BluetoothPeripheral {

    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        return .OttaiType
    }
}
