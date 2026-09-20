//
//  Libre3HeartBeat+BluetoothPeripheral.swift
//  xdrip
//
//  Created by Johan Degraeve on 06/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import os
import CoreBluetooth
import AVFoundation

enum StandardBluetoothBatteryLevel {
    // EmaLink and OrangeLink can expose battery percentage through the standard BLE Battery
    // Service. Keeping the UUIDs and validation here also lets compatible generic heartbeat
    // devices opt in without adding device-name checks or vendor-specific parsing.
    static let serviceUUID = CBUUID(string: "180F")
    static let characteristicUUID = CBUUID(string: "2A19")

    static func percentage(from data: Data?) -> Int? {
        // Battery Level is defined as one unsigned byte from 0 through 100. Rejecting every other
        // shape prevents malformed or vendor-specific data from creating a misleading UI row.
        guard let data, data.count == 1 else { return nil }

        let percentage = Int(data[0])
        return (0 ... 100).contains(percentage) ? percentage : nil
    }
}

/// A heartbeat transmitter that exposes a readable standard BLE Battery Level characteristic.
protocol StandardBatteryLevelProviding: AnyObject {
    var batteryLevel: Int? { get }
    func updateBatteryLevel()
}

@objcMembers
class Libre3HeartBeatBluetoothTransmitter: BluetoothTransmitter, StandardBatteryLevelProviding {

    // MARK: - properties

    /// advertisement UUID unknown
    private let CBUUID_Advertisement_Libre3: String? = nil

    /// receive characteristic - this is the characteristic for the one minute reading
    private let CBUUID_ReceiveCharacteristic_Libre3: String = "0898177A-EF89-11E9-81B4-2A2AE2DBCCE4"

    /// write characteristic - we will not write, but the parent class needs a write characteristic, use the same as the one used for Libre 3
    private let CBUUID_WriteCharacteristic_Libre3: String = "F001"

    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHeartBeatLibre3)

    /// when was the last heartbeat
    private var timeStampOfLastHeartBeat: Date

    /// Cached only after an EmaLink, OrangeLink or another compatible heartbeat device returns a
    /// valid standard BLE Battery Level. `nil` deliberately means that the UI remains unchanged.
    @nonobjc private(set) var batteryLevel: Int?

    /// Retain the discovered standard characteristic so an EmaLink/OrangeLink battery can be read
    /// again when its detail screen opens, without rediscovering services or starting a new link.
    private var batteryLevelCharacteristic: CBCharacteristic?

    // Discovery and subscription state stay on centralQueue; no diagnostic UI observers are needed.
    @nonobjc private var settings = GenericHeartbeatSettings()
    private weak var sessionPeripheral: CBPeripheral?
    @nonobjc private var pendingServices = Set<ObjectIdentifier>()
    @nonobjc private var channels: [String: CBCharacteristic] = [:]
    @nonobjc private var subscriptions = GenericHeartbeatSubscriptions()
    private var subscriptionRequestCount = 0
    @nonobjc private var discoveredChannels: [GenericHeartbeatChannel] = []
    private var subscriptionOutcome = "disconnected"

    /// Begin one discovery/subscription lifecycle, including restoration of an existing OS link.
    private func beginSession(_ peripheral: CBPeripheral) {
        sessionPeripheral = peripheral
        // Freeze the configured mode for this session. Later settings changes must not make
        // the trace describe a new choice while the existing subscriptions still use the old one.
        settings = GenericHeartbeatSettings.load(peripheral.identifier.uuidString)
        pendingServices.removeAll()
        channels.removeAll()
        subscriptions = GenericHeartbeatSubscriptions()
        subscriptionRequestCount = 0
        batteryLevelCharacteristic = nil
        discoveredChannels.removeAll()
        subscriptionOutcome = "discovering"
        trace("Generic heartbeat session device=%{public}@ address=%{public}@ mode=%{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .info, peripheral.name ?? "unknown", peripheral.identifier.uuidString, settings.mode.logDescription)
        traceSubscriptions("session started")
    }

    /// Log OS-reported local subscriptions, not just successful requests made by this instance.
    /// This also exposes subscriptions retained during restoration, without touching the link.
    private func traceSubscriptions(_ event: String) {
        let active = (sessionPeripheral?.services ?? []).flatMap { $0.characteristics ?? [] }
            .filter(\.isNotifying).map { channelID($0) }.sorted()

        trace("Generic heartbeat %{public}@ device=%{public}@ active=[%{public}@] pending=[%{public}@] outcome=%{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .info, event, deviceAddress ?? "unknown", active.joined(separator: ","), subscriptions.pending.sorted().joined(separator: ","), subscriptionOutcome)
    }

    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - transmitterID: should be the name of the libre 3 transmitter as seen in the iOS settings, doesn't need to be the full name, 3-5 characters should be ok
    ///     - bluetoothTransmitterDelegate : a bluetoothTransmitterDelegate
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {

        // if it's a new device being scanned for, then use name ABBOTT. It will connect to anything that starts with name ABBOTT
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: transmitterID)

        // if address not nil, then it's about connecting to a device that was already connected to before. We don't know the exact device name, so better to set it to nil. It will be assigned the real value during connection process
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: nil)
        }

        // initially last heartbeat was never (ie 1 1 1970)
        self.timeStampOfLastHeartBeat = Date(timeIntervalSince1970: 0)
        self.batteryLevel = nil
        self.batteryLevelCharacteristic = nil

        // using nil as servicesCBUUIDs, that works.
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_Libre3, servicesCBUUIDs: nil, CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Libre3, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Libre3, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)

    }

    // MARK: CBCentralManager overriden functions

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        beginSession(peripheral)
        super.centralManager(central, didConnect: peripheral)
        traceSubscriptions("connected")

        // this is the trigger for calling the heartbeat
        if (Date()).timeIntervalSince(timeStampOfLastHeartBeat) > ConstantsHeartBeat.minimumTimeBetweenTwoHeartBeats {
            timeStampOfLastHeartBeat = Date()

            traceSubscriptions("heartbeat source=connection")

            let timeStamp = timeStampOfLastHeartBeat
            if Thread.isMainThread {
                UserDefaults.standard.timeStampOfLastHeartBeat = timeStamp
            } else {
                DispatchQueue.main.async {
                    UserDefaults.standard.timeStampOfLastHeartBeat = timeStamp
                }
            }

            // wait for a second to allow the official app to upload to LibreView before triggering the heartbeat announcement to the delegate
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.bluetoothTransmitterDelegate?.heartBeat()
            }
        }
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Failed or obsolete callbacks must not create a successful heartbeat.
        guard peripheral === sessionPeripheral, error == nil, characteristic.value != nil else { return }
        let key = channelID(characteristic)
        guard channels[key] === characteristic || batteryLevelCharacteristic === characteristic else { return }
        // This override bypasses the base value callback, so share its RSSI cadence explicitly.
        requestSignalStrengthForTraceIfNeeded(from: peripheral)

        // trace the received value and uuid
        if let value = characteristic.value {
            trace("in peripheralDidUpdateValueFor, characteristic = %{public}@, data = %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, String(describing: characteristic.uuid), value.hexEncodedString())
        }

        // An EmaLink or OrangeLink battery response is status metadata, not heartbeat traffic.
        // Keep it out of the heartbeat cadence and publish it only after the standard one-byte
        // percentage validates, including a genuine 0% value.
        if characteristic.service?.uuid == StandardBluetoothBatteryLevel.serviceUUID,
           characteristic.uuid == StandardBluetoothBatteryLevel.characteristicUUID {
            guard let batteryLevel = StandardBluetoothBatteryLevel.percentage(from: characteristic.value)
            else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                self.batteryLevel = batteryLevel
                self.bluetoothTransmitterDelegate?.didUpdateBatteryLevel(batteryLevel, bluetoothTransmitter: self)
            }
            return
        }
        // this is the trigger for calling the heartbeat
        if (Date()).timeIntervalSince(timeStampOfLastHeartBeat) > ConstantsHeartBeat.minimumTimeBetweenTwoHeartBeats {
            timeStampOfLastHeartBeat = Date()

            traceSubscriptions("heartbeat source=" + key)

            let ts = timeStampOfLastHeartBeat
            if Thread.isMainThread {
                UserDefaults.standard.timeStampOfLastHeartBeat = ts
            } else {
                DispatchQueue.main.async {
                    UserDefaults.standard.timeStampOfLastHeartBeat = ts
                }
            }

            // wait for a second to allow the official app to upload to LibreView before triggering the heartbeat announcement to the delegate
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.bluetoothTransmitterDelegate?.heartBeat()
            }
        }
    }

    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral === sessionPeripheral,
              pendingServices.remove(ObjectIdentifier(service)) != nil else { return }

        trace("didDiscoverCharacteristicsFor for peripheral with name %{public}@, for service with uuid %{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .info, deviceName ?? "'unknown'", String(describing:service.uuid))

        if let error = error {
            trace("    didDiscoverCharacteristicsFor error: %{public}@", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .error , error.localizedDescription)
        }

        if error == nil, let characteristics = service.characteristics {
            for characteristic in characteristics {
                trace("Generic heartbeat discovered channel=%{public}@ properties=%{public}@ notifying=%{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .info, channelID(characteristic), String(characteristic.properties.rawValue), String(characteristic.isNotifying))
                // EmaLink and OrangeLink expose Battery Level as a read-only value. Read it once
                // when discovered instead of subscribing, while all ordinary heartbeat
                // characteristics retain their existing notification behaviour.
                if service.uuid == StandardBluetoothBatteryLevel.serviceUUID,
                   characteristic.uuid == StandardBluetoothBatteryLevel.characteristicUUID {
                    if characteristic.properties.contains(.read) {
                        batteryLevelCharacteristic = characteristic
                        peripheral.readValue(for: characteristic)
                        traceSubscriptions("battery read requested; excluded from subscriptions")
                    } else {
                        traceSubscriptions("battery read skipped; excluded from subscriptions")
                    }
                    continue
                }

                let channel = GenericHeartbeatChannel(service: service.uuid.uuidString, characteristic: characteristic.uuid.uuidString, properties: characteristic.properties)
                discoveredChannels.append(channel)
                channels[channel.id] = characteristic
            }
        } else {
            trace("    Did discover characteristics, but no characteristics listed. There must be some error.", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .error)
        }
        // Single-channel selection must see all services before choosing, not discovery order.
        if pendingServices.isEmpty { requestSubscriptions(peripheral) }
    }

    override func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral === sessionPeripheral else { return }
        pendingServices = error == nil ? Set((peripheral.services ?? []).map(ObjectIdentifier.init)) : []
        super.peripheral(peripheral, didDiscoverServices: error)
        if error != nil || pendingServices.isEmpty {
            subscriptionOutcome = "unavailable"
            traceSubscriptions("service discovery unavailable")
        }
    }

    override func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        // The superclass restores a connected peripheral by discovery rather than didConnect.
        if let peripheral = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first,
           deviceAddress == nil || deviceAddress == peripheral.identifier.uuidString {
            beginSession(peripheral)
            traceSubscriptions("restored")
        }
        super.centralManager(central, willRestoreState: dict)
    }

    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        trace("Generic heartbeat disconnected device=%{public}@ error=%{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .info, peripheral.identifier.uuidString, error.map { String(describing: $0 as NSError) } ?? "none")
        if peripheral === sessionPeripheral {
            sessionPeripheral = nil
            pendingServices.removeAll()
            channels.removeAll()
            subscriptions = GenericHeartbeatSubscriptions()
            batteryLevelCharacteristic = nil

            subscriptionOutcome = "disconnected"
            traceSubscriptions("local subscription state cleared")
        }
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }

    private func channelID(_ characteristic: CBCharacteristic) -> String {
        (characteristic.service?.uuid.uuidString ?? "") + "/" + characteristic.uuid.uuidString
    }

    /// Attempt each eligible channel at most once per connection. Only explicit failure advances
    /// automatic mode; a silent but accepted subscription never starts a retry timer.
    private func requestSubscriptions(_ peripheral: CBPeripheral) {
        let candidates = GenericHeartbeatChannel.ordered(discoveredChannels)
        let counts = Dictionary(grouping: discoveredChannels, by: \.id)
        let nextCandidate = candidates.first { !subscriptions.attempted.contains($0.id) }?.id
        for channel in discoveredChannels {
            // Explain policy decisions explicitly so a missing channel is not mistaken for a failure.
            let reason: String
            if !channel.eligible {
                reason = "skip: no notify/indicate support"
            } else if counts[channel.id]?.count != 1 {
                reason = "skip: ambiguous UUID pair"
            } else if subscriptions.attempted.contains(channel.id) {
                reason = "skip: already attempted this connection"
            } else if settings.mode == .automatic && channel.id != nextCandidate {
                reason = "reserve: explicit-failure fallback only"
            } else {
                reason = "eligible for subscription"
            }
            trace("Generic heartbeat channel=%{public}@ decision=%{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .info, channel.id, reason)
        }
        // Restoration can retain the previous local subscriptions. Do not silently unsubscribe
        // live channels to enforce a newly saved reduced mode; trace that a reconnect is needed.
        let existing = channels.filter { $0.value.isNotifying }.map(\.key).sorted()
        if settings.mode != .all, existing.contains(where: { $0 != candidates.first?.id }) {
            subscriptionOutcome = "reconnect"
            traceSubscriptions("restored subscriptions require user reconnect for reduced mode")

            return
        }
        for key in subscriptions.next(candidates.map(\.id), mode: settings.mode) {
            guard let characteristic = channels[key] else { continue }
            if characteristic.isNotifying {
                subscriptions.complete(key, success: true)
                traceSubscriptions("already active " + key)
            } else {
                subscriptionRequestCount += 1
                peripheral.setNotifyValue(true, for: characteristic)
                traceSubscriptions("requested " + key)
            }
            trace("Generic heartbeat subscription mode=%{public}@ channel=%{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .info, settings.mode.logDescription, key)
        }

        subscriptionOutcome = subscriptions.outcome
        trace("Generic heartbeat eligible=%{public}@ requested=%{public}@ skipped=%{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .info, String(candidates.count), String(subscriptionRequestCount), String(discoveredChannels.count - candidates.count))
        traceSubscriptions("selection complete")
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let key = channelID(characteristic)
        // Trace every callback, even ones that cannot legitimately advance our request sequence.
        trace("Generic heartbeat notification state device=%{public}@ channel=%{public}@ notifying=%{public}@ error=%{public}@", log: log, category: ConstantsLog.categoryHeartBeatLibre3, type: .info, peripheral.identifier.uuidString, key, String(characteristic.isNotifying), error.map { String(describing: $0 as NSError) } ?? "none")
        guard peripheral === sessionPeripheral, channels[key] === characteristic else {
            traceSubscriptions("ignored obsolete or untracked callback " + key)
            return
        }
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        let completedRequest = subscriptions.complete(key, success: error == nil && characteristic.isNotifying)
        subscriptions.observe(key, isNotifying: characteristic.isNotifying)

        subscriptionOutcome = subscriptions.outcome
        traceSubscriptions((completedRequest ? (error == nil && characteristic.isNotifying ? "confirmed " : "failed ") : "unsolicited or duplicate state ") + key)
        // Only an explicit response to our pending request may try another channel.
        if completedRequest && settings.mode == .automatic && subscriptionOutcome == "failed" {
            traceSubscriptions("automatic fallback after " + key)
            requestSubscriptions(peripheral)
            if subscriptionOutcome == "failed" { traceSubscriptions("automatic candidates exhausted") }
        }
        // Confirmation is not received data and must never advance the heartbeat timestamp.
    }

    /// Requests a fresh value from an already-connected EmaLink, OrangeLink or compatible generic
    /// heartbeat device. Discovery remains responsible for the first read. This method is a no-op
    /// when the device does not expose the standard Battery Level characteristic.
    func updateBatteryLevel() {
        runOnCentralQueue { [weak self] in
            // Preserve the normal on-demand battery read, without the old experimental switch.
            guard let self, let batteryLevelCharacteristic = self.batteryLevelCharacteristic else { return }
            self.readValueForCharacteristic(for: batteryLevelCharacteristic)
        }
    }

    override func prepareForRelease() {
        // Characteristic and cadence state belong to the Core Bluetooth queue. Queue cleanup
        // without introducing a synchronous main-to-Bluetooth dependency during device removal.
        runOnCentralQueue {
            self.sessionPeripheral = nil
            self.channels.removeAll()
            self.pendingServices.removeAll()
            self.subscriptions = GenericHeartbeatSubscriptions()
            self.timeStampOfLastHeartBeat = Date(timeIntervalSince1970: 0)
            self.batteryLevelCharacteristic = nil
            // Removal can detach the delegate before iOS delivers a disconnect callback.
            self.subscriptionOutcome = "disconnected"
            self.traceSubscriptions("released; local subscription state cleared")
        }
        super.prepareForRelease()
        let clearPublishedState = { self.batteryLevel = nil }
        if Thread.isMainThread {
            clearPublishedState()
        } else {
            DispatchQueue.main.async(execute: clearPublishedState)
        }
    }
}
