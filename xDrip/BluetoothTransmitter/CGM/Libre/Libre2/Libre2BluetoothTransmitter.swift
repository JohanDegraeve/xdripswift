import CoreBluetooth
import Foundation
import os

/// Storage and calibration differ between phone and Watch; the radio protocol does not.
protocol Libre2SensorDataSource: AnyObject {
    var sensorUID: Data? { get }
    var patchInfo: Data? { get }
    func reserveUnlock() throws -> Libre2StreamingUnlock
    func parseBLEFrame(_ frame: Data, sensorUID: Data) throws -> (bleGlucose: [GlucoseData], sensorTimeInMinutes: UInt16)?
}

struct Libre2StreamingUnlock {
    let code: UInt32
    let count: UInt16
    var shouldWrite = true
}

/// Shared F001/F002 protocol, using the app's existing Bluetooth connection lifecycle.
class Libre2BluetoothTransmitter: BluetoothTransmitter {
    /// service to be discovered
    let CBUUID_Service_Libre2: String = "FDE3"

    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_Libre2: String = "F002"

    /// write characteristic
    let CBUUID_WriteCharacteristic_Libre2: String = "F001"

    /// how many bytes should we receive from Libre 2
    private let expectedBufferSize = 46

    let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMLibre2)
    private let sensor: Libre2SensorDataSource
    private var rxBuffer = Data()
    private var startDate = Date()
    private static let maxWaitForpacketInSeconds = 3.0

    init(addressAndName: DeviceAddressAndName, sensor: Libre2SensorDataSource, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {
        self.sensor = sensor
        super.init(addressAndName: addressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Libre2)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Libre2, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Libre2, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
    }

    /// Called on main. Platform adapters deliver readings to their own model.
    func received(glucoseData: [GlucoseData], sensorTimeInMinutes: UInt16) {}

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard isConnectionAllowed else { return }
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        // Sensor credentials must already be available before notifications are processed.
        guard let libreSensorUID = sensor.sensorUID else {
            trace("in peripheral didUpdateValueFor but libreSensorUID is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)

            return
        }

        if let value = characteristic.value {
            processValue(value: value, sensorUID: libreSensorUID)

        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error)
        }
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard isConnectionAllowed else { return }
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)

        // Sensor credentials must already be available before notifications are processed.
        guard let libreSensorUID = sensor.sensorUID else {
            trace("in peripheral didUpdateNotificationStateFor but libreSensorUID is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)

            return
        }

        // NFC patch information is needed to generate the streaming unlock.
        guard let librePatchInfo = sensor.patchInfo else {
            trace("in peripheral didUpdateNotificationStateFor but librePatchInfo is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)

            return
        }

        // the unlock algorithm reads 6 bytes directly, so invalid restored sensor metadata must be rejected before creating the payload
        guard libreSensorUID.count >= 6, librePatchInfo.count >= 6 else {
            trace("in peripheral didUpdateNotificationStateFor but the stored sensor metadata is incomplete, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error)

            return
        }

        if error == nil && characteristic.isNotifying {
            do {
                // The Watch data source saves the reservation before this method can write F001.
                // The phone data source retains its existing counter and suppression behaviour.
                let unlock = try sensor.reserveUnlock()
                let payload = Data(Libre2BLEUtilities.streamingUnlockPayload(sensorUID: libreSensorUID, info: librePatchInfo, enableTime: unlock.code, unlockCount: unlock.count))
                trace("in peripheral didUpdateNotificationStateFor, unlock counter = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, unlock.count.description)
                if unlock.shouldWrite {
                    _ = writeDataToPeripheral(data: payload, type: .withResponse)
                }
            } catch {
                trace("Unable to reserve Libre unlock counter: %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error, error.localizedDescription)
                DispatchQueue.main.async { [weak self] in
                    self?.bluetoothTransmitterDelegate?.error(message: error.localizedDescription)
                }
            }
        }
    }

    override func prepareForRelease() {
        super.prepareForRelease()
        if Thread.isMainThread {
            resetRxBuffer()
        } else {
            DispatchQueue.main.sync { self.resetRxBuffer() }
        }
    }

    private func resetRxBuffer() {
        rxBuffer = Data()
        startDate = Date()
    }

    /// process value received from transmitter
    public func processValue(value: Data, sensorUID: Data) {
        // check if buffer needs to be reset
        if Date() > startDate.addingTimeInterval(Libre2BluetoothTransmitter.maxWaitForpacketInSeconds) {
            trace("in peripheral didUpdateValueFor, more than %{public}@ seconds since last update - or first update since app launch, resetting buffer", log: log, category: ConstantsLog.categoryCGMLibre2, type: .debug, Libre2BluetoothTransmitter.maxWaitForpacketInSeconds.description)

            resetRxBuffer()
        }

        // add new value to rxBuffer
        rxBuffer.append(value)

        // check if enough bytes are received, and if yes start processing
        if rxBuffer.count == expectedBufferSize {
            do {
                guard let parsedBLEData = try sensor.parseBLEFrame(rxBuffer, sensorUID: sensorUID) else { return }

                // Deliver readings and sensor age to the platform adapter on main.
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.received(glucoseData: parsedBLEData.bleGlucose, sensorTimeInMinutes: parsedBLEData.sensorTimeInMinutes)
                }

            } catch {
                trace("in peripheral didUpdateValueFor, error while parsing/decrypting data =  %{public}@ ", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, error.localizedDescription)

                resetRxBuffer()
            }
        }
    }

}
