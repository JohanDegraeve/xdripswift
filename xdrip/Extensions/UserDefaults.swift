import Foundation

extension UserDefaults {
    private enum Key: String {
        // active BluetoothTransmitter address and name
        case bluetoothDeviceAddress = "bluetoothDeviceAddress"
        case bluetoothDeviceName = "bluetoothDeviceName"
    }
    
    // MARK: - active BluetoothTransmitter address and name
    
    var bluetoothDeviceAddress: String? {
        get {
            return string(forKey: Key.bluetoothDeviceAddress.rawValue)
        }
        set {
            set(newValue, forKey: Key.bluetoothDeviceAddress.rawValue)
        }
    }

    var bluetoothDeviceName: String? {
        get {
            return string(forKey: Key.bluetoothDeviceName.rawValue)
        }
        set {
            set(newValue, forKey: Key.bluetoothDeviceName.rawValue)
        }
    }
}

