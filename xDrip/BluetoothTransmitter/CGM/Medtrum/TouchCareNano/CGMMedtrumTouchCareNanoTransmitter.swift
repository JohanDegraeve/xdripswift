//
//  CGMMedtrumTouchCareNanoTransmitter.swift
//  xdrip
//
//  Created by Tatu on 8/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreBluetooth
import os
import UIKit

private final class MedtrumBackgroundTask {
    private let lock = NSLock()
    private var identifier = UIBackgroundTaskIdentifier.invalid

    func begin() {
        let newIdentifier = UIApplication.shared.beginBackgroundTask(
            withName: "Medtrum glucose delivery",
            expirationHandler: { [weak self] in self?.end() }
        )

        lock.lock()
        identifier = newIdentifier
        lock.unlock()
    }

    func end() {
        lock.lock()
        let identifierToEnd = identifier
        identifier = .invalid
        lock.unlock()

        guard identifierToEnd != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifierToEnd)
    }
}

/// Passive co-listener for the Medtrum TouchCare Nano CGM.
///
/// Architecture: the CGM patch sensor talks to the Medtrum patch *pump* over a proprietary RF
/// link; the pump then broadcasts pump status and CGM readings over BLE on service
/// `669A9001-…`. The official Medtrum EasyPatch app pairs/authenticates with the pump and
/// holds the BLE link. iOS's CoreBluetooth multiplexes a single ACL link across multiple
/// apps once a bond exists: we subscribe to the same notification characteristics, and the
/// raw glucose packets are delivered to us alongside EasyPatch — no auth required on our side.
///
/// Glucose source: notifications on characteristic `669A9141`. The packet layout (decoded
/// empirically against EasyPatch ground-truth readings):
/// ```
/// offset 0:  packet type (0xb3 0x02)
/// offset 2:  status/flag byte + constant (0x?? 0x5b)
/// offset 4:  uint16 LE — reading counter (+1 per 2-min CGM cycle since sensor start)
/// offset 6:  constant (0x07 0x14 0x00)
/// offset 8:  uint16 LE — current glucose (raw)
/// offset 10: uint16 LE — glucose 2 min ago
/// offset 12: uint16 LE — glucose 4 min ago
/// offset 14: uint16 LE — glucose 6 min ago
/// offset 16: uint16 LE — small varying counter (observed 0x0000 ... 0x0400); unused
/// offset 18: uint16 LE — per-sensor calibration factor (updates on each EasyPatch calibration)
/// ```
/// Conversion: `mg/dL = raw × 1000 / calibrationFactor`.
/// Confirmed across two distinct calibrations (factor 8932 and 10333) against EasyPatch ground truth.
@objcMembers
class CGMMedtrumTouchCareNanoTransmitter: BluetoothTransmitter, CGMTransmitter {

    private enum DefaultsKey {
        static let sensorStartDate = "medtrumTouchCareNano.sensorStartDate"
        static let lastDeliveredCounter = "medtrumTouchCareNano.lastDeliveredCounter"
    }

    // MARK: - properties

    /// Medtrum custom service exposed by the patch pump
    private let CBUUID_Service_MedtrumNano = "669A9001-0008-968F-E311-6050405558B3"

    /// notification characteristic that carries CGM glucose packets
    private let CBUUID_ReceiveCharacteristic_MedtrumNano = "669A9141-0008-968F-E311-6050405558B3"

    /// we never write — base class requires a write UUID, supply the same UUID as receive (it's harmless because we never call writeDataToPeripheral)
    private let CBUUID_WriteCharacteristic_MedtrumNano = "669A9141-0008-968F-E311-6050405558B3"

    /// expected name pattern; Medtrum pumps advertise as "MT"
    private let expectedDeviceNameMedtrum = "MT"

    /// pump (= MD0201 etc) sensor system lifetime is 14 days
    private let sensorLifeDays: Double = 14

    /// CGM delegate (xDrip pipeline)
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?

    /// last reading counter we have already emitted — used to skip duplicates within one app run
    private var lastEmittedCounter: Int = -1

    /// EasyPatch owns the physical session. Back off repeated retries so a rejected passive
    /// listener cannot enter the rapid, battery-intensive connect/disconnect loops seen in logs.
    private let reconnectDelays: [TimeInterval] = [5, 10, 15]
    private let reconnectSchedulingQueue = DispatchQueue(label: "medtrum.reconnect", qos: .utility)
    private var reconnectAttempt = 0
    private var reconnectGeneration = 0
    private var reconnectBackgroundTask: MedtrumBackgroundTask?
    private weak var reconnectPeripheral: CBPeripheral?
    private let connectionProgressTimeout: TimeInterval = 5
    private var connectionProgressGeneration = 0

    /// A healthy sensor notifies every two minutes. If three cycles pass without a valid packet,
    /// recycle the apparently connected session instead of waiting indefinitely for a callback.
    private let packetInactivityTimeout: TimeInterval = 7 * 60
    private var packetWatchdogGeneration = 0

    /// Packet receipt time varies by a few seconds, while a real session change moves the inferred
    /// start by hours or days. Keep the comparison tolerant to normal BLE delivery jitter.
    private let sensorSessionTolerance: TimeInterval = 10 * 60

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMMedtrumTouchCareNano)

    // MARK: - Initialization

    init(address: String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMTransmitterDelegate: CGMTransmitterDelegate) {

        var newAddressAndName: BluetoothTransmitter.DeviceAddressAndName = .notYetConnected(expectedName: expectedDeviceNameMedtrum)
        if let address = address {
            newAddressAndName = .alreadyConnectedBefore(address: address, name: name)
        }

        self.cgmTransmitterDelegate = cGMTransmitterDelegate

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_MedtrumNano)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_MedtrumNano, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_MedtrumNano, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
    }

    // MARK: - overrides

    override func centralManagerDidUpdateState(_ central: CBCentralManager) {
        trace("in centralManagerDidUpdateState, for Medtrum peripheral with name %{public}@, new state is %{public}@", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info, deviceName ?? "'unknown'", central.state.toString())

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.bluetoothTransmitterDelegate?.deviceDidUpdateBluetoothState(state: central.state, bluetoothTransmitter: self)
        }

        guard central.state == .poweredOn else { return }

        if getConnectionStatus() == .connected, let reconnectPeripheral {
            // Restoration can report an existing ACL connection before Bluetooth is powered on.
            // Repeat the normal setup path now so service discovery and notifications cannot stall.
            trace("restored Medtrum peripheral is connected; restarting service discovery", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info)
            reconnectPeripheral.delegate = self
            centralManager(central, didConnect: reconnectPeripheral)
            return
        }

        // Do not issue a duplicate connect while CoreBluetooth is still completing restoration.
        if getConnectionStatus() == .connecting {
            if let reconnectPeripheral {
                armConnectionProgressTimeout(for: reconnectPeripheral)
            }
            return
        }

        _ = connectToPreferredPeripheral(using: central)
    }

    override func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        super.centralManager(central, willRestoreState: dict)

        guard let restoredPeripheral = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first,
              deviceAddress == nil || restoredPeripheral.identifier.uuidString == deviceAddress else { return }
        reconnectPeripheral = restoredPeripheral
    }

    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        cancelConnectionProgressTimeout()
        cancelPacketWatchdog()
        reconnectPeripheral = peripheral
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        cancelConnectionProgressTimeout()
        reconnectPeripheral = peripheral
        super.centralManager(central, didConnect: peripheral)
        armPacketWatchdog(for: peripheral)
    }

    override func reconnectAfterDisconnect(_ central: CBCentralManager) {
        guard let reconnectPeripheral else { return }
        attemptReconnect(using: central, peripheral: reconnectPeripheral)
    }

    override func shouldTimeoutStalledConnectionSetup() -> Bool {
        true
    }

    override func stopConnectAndRestartScanning(forgetDeviceOnTimeout: Bool) {
        cancelConnectionTimer()
        cancelConnectionSetupTimeout()
        trace("Medtrum connection timed out, disconnecting before a backed-off retry", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info)
        disconnect()
    }

    override func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        cancelConnectionTimer()
        cancelConnectionProgressTimeout()

        if let error {
            trace("in didFailToConnect, failed to connect to Medtrum peripheral with error: %{public}@", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .error, error.localizedDescription)
        } else {
            trace("in didFailToConnect, failed to connect to Medtrum peripheral", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .error)
        }

        attemptReconnect(using: central, peripheral: peripheral)
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        guard error == nil else { return }
        guard let value = characteristic.value else { return }
        guard characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic_MedtrumNano) else { return }

        reconnectPeripheral = peripheral
        processGlucosePacket(value, from: peripheral)
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)

        guard characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic_MedtrumNano), error == nil else { return }
        trace("Medtrum glucose notifications enabled=%{public}@", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info, characteristic.isNotifying.description)
        if characteristic.isNotifying {
            armPacketWatchdog(for: peripheral)
        }
    }

    override func prepareForRelease() {
        cancelConnectionProgressTimeout()
        cancelPacketWatchdog()
        resetReconnectBackoff()
        super.prepareForRelease()
    }

    // MARK: - packet decoding

    private func processGlucosePacket(_ data: Data, from peripheral: CBPeripheral) {
        // CGM notifications are 20 bytes. Ignore other shapes that may appear on this characteristic.
        guard data.count == 20 else {
            trace("unexpected packet length (len=%{public}d), ignoring", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .debug, data.count)
            return
        }
        // Single fingerprint byte: byte 1 (0x02) is the packet-type marker that distinguishes CGM
        // glucose packets from any other 20-byte message on this characteristic. All other bytes
        // are either status flags whose bit layout we have not fully mapped, or session/calibration
        // values that may legitimately change (e.g. between sensors). The 40–400 mg/dL plausibility
        // gate below provides defence-in-depth against any false-positive that slips through.
        guard data[1] == 0x02 else {
            trace("packet header does not match expected CGM marker, ignoring (hex=%{public}@)", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .debug, data.hexEncodedString())
            return
        }

        let counter = Int(uint16LE(data, offset: 4))
        let rawCurrent = uint16LE(data, offset: 8)
        let calibrationFactor = uint16LE(data, offset: 18)

        // Calibration factor is required to interpret the raw value; rare safety guard against div-by-zero / corruption.
        guard calibrationFactor > 0 else {
            trace("invalid calibration factor (0) in packet, ignoring (hex=%{public}@)", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .error, data.hexEncodedString())
            return
        }

        let mgDl = Double(rawCurrent) * 1000.0 / Double(calibrationFactor)

        // Plausibility guard — values outside a CGM-meaningful range get dropped (alarms must never fire on garbage).
        guard mgDl >= 40, mgDl <= 400 else {
            trace("rejected implausible glucose=%{public}.1f mg/dL (raw=%{public}d, calFactor=%{public}d, counter=%{public}d)", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .error, mgDl, Int(rawCurrent), Int(calibrationFactor), counter)
            return
        }

        resetReconnectBackoff()
        armPacketWatchdog(for: peripheral)

        let receiptDate = Date()
        let sensorAge = TimeInterval(counter * 2 * 60) // counter ticks every 2 min since sensor start
        let inferredSensorStartDate = receiptDate.addingTimeInterval(-sensorAge)
        let storedSensorStartDate = UserDefaults.standard.object(forKey: DefaultsKey.sensorStartDate) as? Date
        let isSameSensorSession = storedSensorStartDate.map {
            abs($0.timeIntervalSince(inferredSensorStartDate)) <= sensorSessionTolerance
        } ?? false
        let persistedCounter = isSameSensorSession
            ? UserDefaults.standard.object(forKey: DefaultsKey.lastDeliveredCounter) as? Int
            : nil

        // State restoration can recreate this object for a packet that was already delivered.
        if persistedCounter == counter {
            return
        }

        if storedSensorStartDate != nil, !isSameSensorSession {
            lastEmittedCounter = -1
        }

        // Skip duplicate emissions of the same CGM cycle.
        if counter == lastEmittedCounter {
            return
        }

        var previousDeliveredCounter: Int?
        if lastEmittedCounter >= 0, lastEmittedCounter < counter {
            previousDeliveredCounter = lastEmittedCounter
        }
        if let persistedCounter, persistedCounter < counter {
            previousDeliveredCounter = max(previousDeliveredCounter ?? persistedCounter, persistedCounter)
        }
        lastEmittedCounter = counter

        trace("decoded glucose: %{public}.1f mg/dL (raw=%{public}d, calFactor=%{public}d, counter=%{public}d, sensorAge=%{public}.0fs)", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info, mgDl, Int(rawCurrent), Int(calibrationFactor), counter, sensorAge)

        var readings = [GlucoseData(timeStamp: receiptDate, glucoseLevelRaw: mgDl)]

        if let previousDeliveredCounter {
            let availableMissingReadingCount = min(3, counter - previousDeliveredCounter - 1)
            if availableMissingReadingCount > 0 {
                for readingOffset in 1...availableMissingReadingCount {
                    let historicalRaw = uint16LE(data, offset: 8 + readingOffset * 2)
                    let historicalMgDl = Double(historicalRaw) * 1000.0 / Double(calibrationFactor)
                    let historicalCounter = counter - readingOffset

                    guard historicalMgDl >= 40, historicalMgDl <= 400 else {
                        trace("rejected implausible Medtrum backfill glucose=%{public}.1f mg/dL (counter=%{public}d)", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .error, historicalMgDl, historicalCounter)
                        continue
                    }

                    readings.append(
                        GlucoseData(
                            timeStamp: receiptDate.addingTimeInterval(TimeInterval(-readingOffset * 2 * 60)),
                            glucoseLevelRaw: historicalMgDl,
                            backfilledAt: receiptDate
                        )
                    )
                }

                trace("decoded %{public}d available Medtrum backfill reading(s) after counter %{public}d", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info, readings.count - 1, previousDeliveredCounter)
            }
        }

        let backgroundTask: MedtrumBackgroundTask? = UserDefaults.standard.appInForeGround ? nil : MedtrumBackgroundTask()
        backgroundTask?.begin()

        DispatchQueue.main.async { [weak self] in
            defer { backgroundTask?.end() }
            guard let self = self else { return }

            // Evaluate this on main so queued packets cannot all decide to reset the same sensor.
            if let activeSensorStartDate = UserDefaults.standard.activeSensorStartDate,
               abs(activeSensorStartDate.timeIntervalSince(inferredSensorStartDate)) > self.sensorSessionTolerance {
                trace("Medtrum sensor session changed, reconciling inferred start %{public}@", log: self.log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info, inferredSensorStartDate.description(with: .current))
                self.cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: inferredSensorStartDate)
            }

            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &readings, transmitterBatteryInfo: nil, sensorAge: sensorAge)
            UserDefaults.standard.set(inferredSensorStartDate, forKey: DefaultsKey.sensorStartDate)
            UserDefaults.standard.set(counter, forKey: DefaultsKey.lastDeliveredCounter)
        }
    }

    private func attemptReconnect(using central: CBCentralManager, peripheral: CBPeripheral) {
        let backgroundTask: MedtrumBackgroundTask? = UserDefaults.standard.appInForeGround ? nil : MedtrumBackgroundTask()
        backgroundTask?.begin()

        reconnectSchedulingQueue.async { [weak self] in
            guard let self else {
                backgroundTask?.end()
                return
            }

            self.reconnectGeneration += 1
            let generation = self.reconnectGeneration
            let delay = self.reconnectDelays[min(self.reconnectAttempt, self.reconnectDelays.count - 1)]
            self.reconnectAttempt += 1

            self.reconnectBackgroundTask?.end()
            self.reconnectBackgroundTask = backgroundTask

            trace("scheduling Medtrum reconnect attempt %{public}d in %{public}d seconds", log: self.log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info, self.reconnectAttempt, Int(delay))

            self.reconnectSchedulingQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else {
                    backgroundTask?.end()
                    return
                }

                guard self.reconnectGeneration == generation else {
                    backgroundTask?.end()
                    return
                }

                self.reconnectBackgroundTask = nil
                trace("executing Medtrum reconnect attempt %{public}d", log: self.log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info, self.reconnectAttempt)
                self.armConnectionProgressTimeout(for: peripheral)
                central.connect(
                    peripheral,
                    options: [
                        CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                        CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
                    ]
                )
                backgroundTask?.end()
            }
        }
    }

    private func armConnectionProgressTimeout(for peripheral: CBPeripheral) {
        reconnectSchedulingQueue.async { [weak self, weak peripheral] in
            guard let self, let peripheral else { return }

            self.connectionProgressGeneration += 1
            let generation = self.connectionProgressGeneration

            self.reconnectSchedulingQueue.asyncAfter(deadline: .now() + self.connectionProgressTimeout) { [weak self, weak peripheral] in
                guard let self,
                      let peripheral,
                      self.connectionProgressGeneration == generation,
                      peripheral.state == .connecting else { return }

                trace("Medtrum connection remained in connecting state for %{public}d seconds; recycling connection", log: self.log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .error, Int(self.connectionProgressTimeout))
                self.disconnect()
            }
        }
    }

    private func cancelConnectionProgressTimeout() {
        reconnectSchedulingQueue.async { [weak self] in
            self?.connectionProgressGeneration += 1
        }
    }

    private func resetReconnectBackoff() {
        reconnectSchedulingQueue.async { [weak self] in
            self?.reconnectBackgroundTask?.end()
            self?.reconnectBackgroundTask = nil
            self?.reconnectAttempt = 0
            self?.reconnectGeneration += 1
        }
    }

    private func armPacketWatchdog(for peripheral: CBPeripheral) {
        reconnectSchedulingQueue.async { [weak self, weak peripheral] in
            guard let self, let peripheral else { return }

            self.packetWatchdogGeneration += 1
            let generation = self.packetWatchdogGeneration

            self.reconnectSchedulingQueue.asyncAfter(deadline: .now() + self.packetInactivityTimeout) { [weak self, weak peripheral] in
                guard let self,
                      let peripheral,
                      self.packetWatchdogGeneration == generation,
                      peripheral.state == .connected else { return }

                trace("no valid Medtrum glucose packet for %{public}d seconds; recycling stale connection", log: self.log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .error, Int(self.packetInactivityTimeout))
                self.disconnect()
            }
        }
    }

    private func cancelPacketWatchdog() {
        reconnectSchedulingQueue.async { [weak self] in
            self?.packetWatchdogGeneration += 1
        }
    }

    /// Reconnect only to the stored pump. Service-based discovery is used only before the first
    /// successful connection, when there is no identifier to distinguish one Medtrum pump from another.
    private func connectToPreferredPeripheral(using central: CBCentralManager) -> Bool {
        if let deviceAddress, let identifier = UUID(uuidString: deviceAddress) {
            guard !central.retrievePeripherals(withIdentifiers: [identifier]).isEmpty else {
                trace("stored Medtrum peripheral is unavailable; broad scanning is intentionally disabled", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info)
                return false
            }

            connect()
            return true
        }

        return retrieveConnectedPeripheral(withServiceUUIDs: [CBUUID(string: CBUUID_Service_MedtrumNano)])
    }

    private func uint16LE(_ data: Data, offset: Int) -> UInt16 {
        let lo = UInt16(data[offset])
        let hi = UInt16(data[offset + 1])
        return (hi << 8) | lo
    }

    // MARK: - CGMTransmitter

    func cgmTransmitterType() -> CGMTransmitterType {
        return .medtrumTouchCareNano
    }

    func maxSensorAgeInDays() -> Double? {
        return sensorLifeDays
    }

    func getCBUUID_Service() -> String { return CBUUID_Service_MedtrumNano }

    func getCBUUID_Receive() -> String { return CBUUID_ReceiveCharacteristic_MedtrumNano }

    // EasyPatch handles sensor lifecycle — we deliberately implement these as no-ops.
    func needsSensorStartTime() -> Bool { return false }

    // Glucose values delivered to xDrip are already in mg/dL after applying the Medtrum per-sensor
    // calibration factor decoded from the packet. Returning true here tells xDrip "treat these as
    // calibrated readings"; it skips the user-calibration prompt and uses NoCalibrator (matches the
    // RootViewController.getCalibrator switch).
    func isWebOOPEnabled() -> Bool { return true }

    func nonWebOOPAllowed() -> Bool { return false }
}
