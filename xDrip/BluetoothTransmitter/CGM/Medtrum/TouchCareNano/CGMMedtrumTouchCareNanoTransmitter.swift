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

    /// transmitter-specific delegate (settings UI)
    public weak var cGMMedtrumTouchCareNanoTransmitterDelegate: CGMMedtrumTouchCareNanoTransmitterDelegate?

    /// last reading counter we have already emitted — used to skip duplicates within one app run
    private var lastEmittedCounter: Int = -1

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMMedtrumTouchCareNano)

    // MARK: - Initialization

    init(address: String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMMedtrumTouchCareNanoTransmitterDelegate: CGMMedtrumTouchCareNanoTransmitterDelegate, cGMTransmitterDelegate: CGMTransmitterDelegate) {

        var newAddressAndName: BluetoothTransmitter.DeviceAddressAndName = .notYetConnected(expectedName: expectedDeviceNameMedtrum)
        if let address = address {
            newAddressAndName = .alreadyConnectedBefore(address: address, name: name)
        }

        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        self.cGMMedtrumTouchCareNanoTransmitterDelegate = cGMMedtrumTouchCareNanoTransmitterDelegate

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_MedtrumNano)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_MedtrumNano, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_MedtrumNano, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
    }

    // MARK: - overrides

    override func centralManagerDidUpdateState(_ central: CBCentralManager) {
        super.centralManagerDidUpdateState(central)

        // Patch pump never advertises while EasyPatch holds the connection. Hunt for it in the
        // system-connected list (works through bonded service multiplexing).
        if central.state == .poweredOn, getConnectionStatus() != .connected {
            _ = retrieveConnectedPeripheral(withServiceUUIDs: [CBUUID(string: CBUUID_Service_MedtrumNano)])
        }
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)

        guard error == nil else { return }
        guard let value = characteristic.value else { return }
        guard characteristic.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic_MedtrumNano) else { return }

        processGlucosePacket(value)
    }

    // MARK: - packet decoding

    private func processGlucosePacket(_ data: Data) {
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

        // Skip duplicate emissions of the same CGM cycle.
        if counter == lastEmittedCounter {
            return
        }
        lastEmittedCounter = counter

        let sensorAge = TimeInterval(counter * 2 * 60) // counter ticks every 2 min since sensor start
        trace("decoded glucose: %{public}.1f mg/dL (raw=%{public}d, calFactor=%{public}d, counter=%{public}d, sensorAge=%{public}.0fs)", log: log, category: ConstantsLog.categoryCGMMedtrumTouchCareNano, type: .info, mgDl, Int(rawCurrent), Int(calibrationFactor), counter, sensorAge)

        var readings = [GlucoseData(timeStamp: Date(), glucoseLevelRaw: mgDl)]

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &readings, transmitterBatteryInfo: nil, sensorAge: sensorAge)
        }
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
