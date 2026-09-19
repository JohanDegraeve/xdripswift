//
//  BluetoothPeripheralManager+CGMG7TransmitterDelegate.swift
//  xdrip
//
//  Created by Johan Degraeve on 15/02/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

extension BluetoothPeripheralManager: CGMG7TransmitterDelegate {
    
    func received(sensorStartDate: Date?, cGMG7Transmitter: CGMG7Transmitter) {
        guard let dexcomG7 = getDexcomG7(cGMG7Transmitter: cGMG7Transmitter) else {return}
        
        dexcomG7.sensorStartDate = sensorStartDate
        
        coreDataManager.saveChanges()
    }
    
    func received(sensorStatus: String?, cGMG7Transmitter: CGMG7Transmitter) {
        
        guard let dexcomG7 = getDexcomG7(cGMG7Transmitter: cGMG7Transmitter) else {return}
        
        dexcomG7.sensorStatus = sensorStatus
        
        coreDataManager.saveChanges()
        
    }

    func received(sensorSessionLength: TimeInterval, cGMG7Transmitter: CGMG7Transmitter) {
        guard let dexcomG7 = getDexcomG7(cGMG7Transmitter: cGMG7Transmitter),
              let supportedSessionLength = DexcomG7SensorLifetime.supportedSessionLength(sensorSessionLength)
        else { return }

        // The duration belongs to this disposable G7-family sensor, so Core Data is the source of
        // truth. The active-sensor UserDefaults value remains only the existing cross-view cache.
        dexcomG7.sensorSessionLength = NSNumber(value: supportedSessionLength)
        if dexcomG7.blePeripheral.shouldconnect {
            UserDefaults.standard.activeSensorMaxSensorAgeInDays = supportedSessionLength / TimeInterval(days: 1)
        }

        coreDataManager.saveChanges()
    }

    func received(version: DexcomG7VersionMessage, cGMG7Transmitter: CGMG7Transmitter) {
        guard let dexcomG7 = getDexcomG7(cGMG7Transmitter: cGMG7Transmitter) else { return }

        // Save the complete record together. If decoding failed, this method is never called and
        // all fields remain due for a clean retry on a later sensor wake.
        dexcomG7.firmwareVersion = version.firmwareVersion
        dexcomG7.firmwareBuildVersion = NSNumber(value: version.buildVersion)
        dexcomG7.firmwareVersionCode = NSNumber(value: version.versionCode)
        coreDataManager.saveChanges()
    }

    func received(
        battery: DexcomG7BatteryStatusMessage,
        readAt: Date,
        isFirstReading: Bool,
        cGMG7Transmitter: CGMG7Transmitter
    ) {
        guard let dexcomG7 = getDexcomG7(cGMG7Transmitter: cGMG7Transmitter) else { return }

        // Keep the raw protocol units in Core Data, exactly as the G5 and G6 entities do. Voltage
        // conversion belongs at presentation and export boundaries so the saved values remain
        // directly comparable with packets and reference-project traces.
        dexcomG7.batteryStatus = Int32(battery.status)
        dexcomG7.voltageA = Int32(battery.voltageA)
        dexcomG7.voltageB = Int32(battery.voltageB)
        dexcomG7.batteryResist = Int32(battery.resistance)
        dexcomG7.batteryRuntime = Int32(battery.runtime)
        dexcomG7.batteryTemperature = Int32(battery.temperature)
        dexcomG7.batteryLastReadDate = readAt
        coreDataManager.saveChanges()
        batteryHistoryManager.record(
            peripheralObjectID: dexcomG7.blePeripheral.objectID,
            observedAt: readAt,
            observation: .dexcom(
                family: .g7, status: Int(battery.status), voltageA: battery.voltageA,
                voltageB: battery.voltageB, resistance: battery.resistance,
                runtime: battery.runtime, temperature: battery.temperature, producer: .dexcomG7
            )
        )

        // Derive a controlled family name from the Bluetooth identity. The Activity Log may say
        // Dexcom G7, Dexcom ONE+, or Dexcom Stelo, but never includes the actual sensor identifier.
        let source = TroubleshootingLogSource(
            bluetoothPeripheralType: .DexcomG7Type,
            transmitterID: dexcomG7.blePeripheral.name.toNilIfLength0() ?? dexcomG7.blePeripheral.transmitterId
        ) ?? .dexcomG7
        let status = DexcomBatteryStatus(voltageB: battery.voltageB, family: .g7)
        // An unavailable Voltage B remains useful in the developer trace and Core Data diagnostics,
        // but Activity Log promises a concrete green, yellow, or red result. Do not invent a public
        // battery state when the sensor returned zero or no usable voltage.
        let activityEntry: TroubleshootingLogEntry? = status == .unknown ? nil : .detailed(.dexcomBattery(
            source: source,
            status: status,
            voltageBMillivolts: DexcomBatteryStatus.millivolts(fromRawVoltage: battery.voltageB),
            isFirstReading: isFirstReading
        ))
        trace(
            "G7 battery information persisted source=%{public}@ status=%{public}@ voltageB=%{public}@mV first=%{public}@",
            log: log,
            category: ConstantsLog.categoryBluetoothPeripheralManager,
            type: status == .red ? .error : .info,
            troubleshooting: activityEntry,
            source.name,
            status.rawValue,
            DexcomBatteryStatus.millivolts(fromRawVoltage: battery.voltageB).description,
            isFirstReading.description
        )
    }
    
    private func getDexcomG7(cGMG7Transmitter: CGMG7Transmitter) -> DexcomG7? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMG7Transmitter), let dexcomG7 = bluetoothPeripherals[index] as? DexcomG7 else {return nil}
        
        return dexcomG7
        
    }
    
}
