import Foundation

extension MedtrumTouchCareNano: BluetoothPeripheral {

    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        return .MedtrumTouchCareNanoType
    }

}
