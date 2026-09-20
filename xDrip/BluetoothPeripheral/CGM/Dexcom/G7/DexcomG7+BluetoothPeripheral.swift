import Foundation

/// Adapts the persisted G7 Core Data entity to the common Bluetooth peripheral contract.
extension DexcomG7: BluetoothPeripheral {

    /// Identifies the entity so the Bluetooth manager creates a `CGMG7Transmitter` for it.
    func bluetoothPeripheralType() -> BluetoothPeripheralType {
        return .DexcomG7Type
    }

    /// Pushes persisted settings into an existing live transmitter after a Core Data change.
    /// Each transition method owns the cleanup required when that setting changes, so this adapter
    /// must not mutate authentication or connection state directly.
    func sendSettings(to bluetoothTransmitter: BluetoothTransmitter) {
        guard let transmitter = bluetoothTransmitter as? CGMG7Transmitter else { return }

        // Apply the authentication secret and channel before the connection mode. If a restored
        // configuration requests primary mode, its prerequisites are therefore ready first.
        transmitter.transitionToPairingCode(sensorCode)
        transmitter.transitionToBluetoothSlot(resolvedDexcomG7BluetoothSlot())
        transmitter.transitionToUseOtherApp(useOtherApp)
    }
}
