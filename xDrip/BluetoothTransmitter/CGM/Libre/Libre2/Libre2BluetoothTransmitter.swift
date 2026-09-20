import CoreBluetooth
import Foundation
import os

/// Storage and calibration differ between phone and Watch; the radio protocol does not.
protocol Libre2SensorDataSource: AnyObject {
    var sensorUID: Data? { get }
    var patchInfo: Data? { get }
    func reserveUnlock() throws -> Libre2StreamingUnlock
    func parseBLEFrame(_ decryptedFrame: Data, date: Date) -> (bleGlucose: [GlucoseData], sensorTimeInMinutes: UInt16)?
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

    let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMLibre2)
    private let sensor: Libre2SensorDataSource
    private var frameAssembler = Libre2FrameAssembler()
    private let frameAssemblyClock = ContinuousClock()

    init(addressAndName: DeviceAddressAndName, sensor: Libre2SensorDataSource, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, restorationIdentifier: String? = nil) {
        self.sensor = sensor
        #if os(watchOS)
        // Retain the prototype's service-filtered Watch scan; phone scanning is unchanged.
        let advertisementUUID: String? = CBUUID_Service_Libre2
        #else
        let advertisementUUID: String? = nil
        #endif
        super.init(addressAndName: addressAndName, CBUUID_Advertisement: advertisementUUID, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Libre2)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Libre2, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Libre2, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate, restorationIdentifier: restorationIdentifier)
    }

    /// Called on main. Platform adapters deliver readings to their own model.
    func received(glucoseData: [GlucoseData], sensorTimeInMinutes: UInt16) {}

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        recordDiagnostic("Libre callback allowed=\(isConnectionAllowed) characteristic=\(characteristic.uuid) error=\(Self.diagnosticError(error))")
        guard isConnectionAllowed else { return }
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        // Sensor credentials must already be available before notifications are processed.
        guard let libreSensorUID = sensor.sensorUID else {
            recordDiagnostic("Libre callback stopped: sensor UID missing")
            trace("in peripheral didUpdateValueFor but libreSensorUID is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)

            return
        }

        if let value = characteristic.value {
            processValue(value: value, sensorUID: libreSensorUID)

        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error)
        }
    }

    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        recordDiagnostic("Libre callback allowed=\(isConnectionAllowed) service=\(service.uuid) error=\(Self.diagnosticError(error))")
        guard isConnectionAllowed else { return }
        super.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)

        guard error == nil,
              service.characteristics?.contains(where: { $0.uuid == CBUUID(string: CBUUID_WriteCharacteristic_Libre2) }) == true,
              service.characteristics?.contains(where: { $0.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic_Libre2) }) == true else { return }

        // Sensor credentials must already be available before notifications are processed.
        guard let libreSensorUID = sensor.sensorUID else {
            recordDiagnostic("Libre callback stopped: sensor UID missing")
            trace("in peripheral didDiscoverCharacteristicsFor but libreSensorUID is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)

            return
        }

        // NFC patch information is needed to generate the streaming unlock.
        guard let librePatchInfo = sensor.patchInfo else {
            recordDiagnostic("Libre setup stopped: patch information missing")
            trace("in peripheral didDiscoverCharacteristicsFor but librePatchInfo is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)

            return
        }

        // the unlock algorithm reads 6 bytes directly, so invalid restored sensor metadata must be rejected before creating the payload
        guard libreSensorUID.count >= 6, librePatchInfo.count >= 6 else {
            recordDiagnostic("Libre setup stopped: invalid credential lengths")
            trace("in peripheral didDiscoverCharacteristicsFor but the stored sensor metadata is incomplete, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error)

            return
        }

        // Match phone upstream: queue F001 immediately after the subscription request.
        // Waiting for its notification-state callback can let the sensor disconnect.
        do {
            // The Watch data source saves the reservation before this method can write F001.
            // The phone data source retains its existing counter and suppression behaviour.
            recordDiagnostic("Unlock reservation requested")
            let unlock = try sensor.reserveUnlock()
            recordDiagnostic("Unlock reserved count=\(unlock.count) shouldWrite=\(unlock.shouldWrite); Watch persistence completed")
            let payload = Data(Libre2BLEUtilities.streamingUnlockPayload(sensorUID: libreSensorUID, info: librePatchInfo, enableTime: unlock.code, unlockCount: unlock.count))
            trace("in peripheral didDiscoverCharacteristicsFor, unlock counter = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, unlock.count.description)
            if unlock.shouldWrite {
                let accepted = writeDataToPeripheral(data: payload, type: .withResponse)
                recordDiagnostic("Unlock write enqueue accepted=\(accepted); acknowledgement pending")
            }
        } catch {
            recordDiagnostic("Unlock reservation failed: \(Self.diagnosticError(error))")
            trace("Unable to reserve Libre unlock counter: %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error, error.localizedDescription)
            DispatchQueue.main.async { [weak self] in
                self?.bluetoothTransmitterDelegate?.error(message: error.localizedDescription)
            }
        }
    }

    override func prepareForRelease() {
        super.prepareForRelease()
        runOnCentralQueue {
            self.recordDiagnostic("Frame buffer reset on release")
            self.frameAssembler.reset()
        }
    }

    /// Assembles on the Bluetooth queue, then parses and delivers on main, as on the phone.
    public func processValue(value: Data, sensorUID: Data) {
        let frameArrivalDate = Date()
        let result = frameAssembler.append(value, arrival: frameAssemblyClock.now)
        recordDiagnostic("Frame fragment bytes=\(value.count)")
        if let timeout = result.timedOutPartialFrame {
            recordDiagnostic("Partial frame timed out bytes=\(timeout.discardedByteCount) age=\(timeout.assemblyDuration)")
            trace("Libre 2 partial frame timed out: discardedBytes=%{public}@, assemblyElapsedSeconds=%{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error, timeout.discardedByteCount.description, timeout.assemblyDuration.description)
        }
        switch result.frameResult {
        case .incomplete:
            return
        case let .oversized(count):
            recordDiagnostic("Oversized frame discarded bytes=\(count)")
            trace("Libre 2 frame contains %{public}@ bytes instead of 46, discarding it", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error, count.description)
        case let .complete(frame, duration):
            do {
                let decrypted = Data(try Libre2BLEUtilities.decryptBLE(sensorUID: sensorUID, data: frame))
                recordDiagnostic("Frame decrypted assemblySeconds=\(duration); delivery queued")
                // Capture arrival before scheduling: queue delays must not make readings newer.
                // Parser history and application delivery are committed on the same queue.
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.isConnectionAllowed else {
                        self.recordDiagnostic("Frame delivery skipped: collection released")
                        return
                    }
                    guard let parsed = self.sensor.parseBLEFrame(decrypted, date: frameArrivalDate) else {
                        self.recordDiagnostic("Frame parser returned no result")
                        return
                    }
                    self.recordDiagnostic("Frame parsed readings=\(parsed.bleGlucose.count) sensorMinute=\(parsed.sensorTimeInMinutes); delivery executing on main")
                    self.received(glucoseData: parsed.bleGlucose, sensorTimeInMinutes: parsed.sensorTimeInMinutes)
                }
            } catch {
                recordDiagnostic("Frame parse/decrypt failed: \(Self.diagnosticError(error))")
                trace("Error parsing/decrypting Libre 2 frame: %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error, error.localizedDescription)
            }
        }
    }
}
