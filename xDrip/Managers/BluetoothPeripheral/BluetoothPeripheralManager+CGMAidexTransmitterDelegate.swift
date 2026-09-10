//
//  BluetoothPeripheralManager+CGMAidexTransmitterDelegate.swift
//  xdrip
//

import Foundation

extension BluetoothPeripheralManager: CGMAidexTransmitterDelegate {

    func received(serialNumber: String, from cGMAidexTransmitter: CGMAidexTransmitter) {
        guard let aidex = getAidex(cGMAidexTransmitter: cGMAidexTransmitter) else { return }
        aidex.blePeripheral.sensorSerialNumber = serialNumber
        coreDataManager.saveChanges()
    }

    func received(sensorStartTimeMs: Int64, from cGMAidexTransmitter: CGMAidexTransmitter) {
        // Handled by CGMTransmitterDelegate path via cgmTransmitterInfoReceived
    }

    func received(wearDays: Int, from cGMAidexTransmitter: CGMAidexTransmitter) {
        // Informational — persisted by sensor lifecycle manager
    }

    func received(batteryMillivolts: Int, from cGMAidexTransmitter: CGMAidexTransmitter) {
        // Battery info is passed through transmitterBatteryInfo in cgmTransmitterInfoReceived
    }

    func aidexNeedsPairing(from cGMAidexTransmitter: CGMAidexTransmitter) {
        trace("Aidex needs pairing — presenting pairing UI if needed", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info)
    }

    func received(firmwareVersion: String, from cGMAidexTransmitter: CGMAidexTransmitter) {
        guard let aidex = getAidex(cGMAidexTransmitter: cGMAidexTransmitter) else { return }
        aidex.firmwareVersion = firmwareVersion
        coreDataManager.saveChanges()
    }

    func received(modelName: String, from cGMAidexTransmitter: CGMAidexTransmitter) {
        guard let aidex = getAidex(cGMAidexTransmitter: cGMAidexTransmitter) else { return }
        aidex.modelName = modelName
        coreDataManager.saveChanges()
    }

    func aidexDidFinishScanning(devices: [DiscoveredAidexSensor], from cGMAidexTransmitter: CGMAidexTransmitter) {
        trace("AidexManager: aidexDidFinishScanning, found %{public}d device(s)", log: log, category: ConstantsLog.categoryBluetoothPeripheralManager, type: .info, devices.count)
        
        guard devices.count > 0 else {
            // No sensors found — post notification so the UI can show an alert
            NotificationCenter.default.post(name: .aidexDidFinishScanning, object: nil, userInfo: [
                "devices": [DiscoveredAidexSensor](),
                "transmitter": cGMAidexTransmitter
            ])
            return
        }
        
        NotificationCenter.default.post(name: .aidexDidFinishScanning, object: nil, userInfo: [
            "devices": devices,
            "transmitter": cGMAidexTransmitter
        ])
    }

    func aidexDidConnect(_ sensor: AidexSensor, from cGMAidexTransmitter: CGMAidexTransmitter) {
        if let aidex = getAidex(cGMAidexTransmitter: cGMAidexTransmitter) {
            // Existing peripheral — update as before
            aidex.blePeripheral.shouldconnect = true
            aidex.blePeripheral.address = sensor.serial.isEmpty ? (cGMAidexTransmitter.deviceAddress ?? "") : sensor.serial
            guard let address = cGMAidexTransmitter.deviceAddress, !address.isEmpty else { return }
            currentCgmTransmitterAddress = address
            coreDataManager.saveChanges()
        } else {
            // New device discovered via Aidex scan — create Core Data entity
            let address = sensor.serial.isEmpty ? sensor.peripheral?.identifier.uuidString ?? "" : sensor.serial
            let name = sensor.peripheral?.name ?? "AiDex"
            
            // Update the temp transmitter's deviceAddress/deviceName so it can connect on next launch
            cGMAidexTransmitter.deviceAddress = address
            cGMAidexTransmitter.deviceName = name
            
            let aidex = Aidex(address: address, name: name, alias: nil, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            aidex.blePeripheral.address = address
            aidex.blePeripheral.shouldconnect = true
            aidex.blePeripheral.hasConnectedSinceActivation = true
            coreDataManager.saveChanges()
            
            let index = insertInBluetoothPeripherals(bluetoothPeripheral: aidex)
            bluetoothTransmitters.insert(cGMAidexTransmitter, at: index)
            currentCgmTransmitterAddress = address
            
            if let callback = callBackAfterDiscoveringDevice {
                callBackAfterDiscoveringDevice = nil
                callback(aidex)
            }
        }
    }

    func aidexDidDisconnect(_ sensor: AidexSensor, from cGMAidexTransmitter: CGMAidexTransmitter) {
        // Update the Core Data timestamp so the UI reflects the disconnect
        // (e.g. switches from "Connected" to "Reconnecting" / "Not Scanning").
        if let aidex = getAidex(cGMAidexTransmitter: cGMAidexTransmitter) {
            aidex.blePeripheral.lastConnectionStatusChangeTimeStamp = Date()
            coreDataManager.saveChanges()
        }
    }

    func received(snapShot: SensorSnapshot?, from cGMAidexTransmitter: CGMAidexTransmitter) {
        // Sensor state snapshot — consumed internally
    }

    // MARK: - Private helpers

    private func getAidex(cGMAidexTransmitter: CGMAidexTransmitter) -> Aidex? {
        guard let index = bluetoothTransmitters.firstIndex(of: cGMAidexTransmitter),
              let aidex = bluetoothPeripherals[index] as? Aidex else { return nil }
        return aidex
    }
}

extension Notification.Name {
    static let aidexDidFinishScanning = Notification.Name("aidexDidFinishScanning")
}