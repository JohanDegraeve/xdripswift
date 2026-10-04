//
//  BatteryHistoryManager.swift
//  xdrip
//
//  Created by Paul Plant on 1/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation
import os

/// Identifies the unit and chart semantics of a persisted observation.
enum BatteryMeasurementKind: Int16, Codable {
    case percentage = 0
    case dexcomVoltage = 1
}

/// Identifies the callback that produced a sample. Raw values are persisted and must remain stable.
enum BatteryProducerKind: Int16, Codable {
    case unknown = 0
    case bubble = 1
    case miaoMiao = 2
    case m5Stack = 3
    case genericHeartbeat = 4
    case dexcomG5 = 5
    case dexcomG7 = 6
    case dexcomG7Heartbeat = 7
}

/// A genuine battery callback ready to be persisted against its exact saved peripheral.
enum BatteryHistoryObservation {
    case percentage(value: Int, producer: BatteryProducerKind)
    case dexcom(family: DexcomBatteryFamily, status: Int, voltageA: Int, voltageB: Int, resistance: Int, runtime: Int, temperature: Int, producer: BatteryProducerKind)
}

/// A value-only chart point read from Core Data.
struct BatteryHistoryPoint: Identifiable, Equatable {
    let id: String
    let observedAt: Date
    let kind: BatteryMeasurementKind
    let family: DexcomBatteryFamily?
    let percentage: Int?
    let voltageA: Int?
    let voltageB: Int?
}

/// The dominant current value shown in the information section and chart pill.
enum BatteryHistoryCurrentReading: Equatable {
    case percentage(Int)
    case voltageB(rawValue: Int)
}

/// Value-only device metadata used by the history screen. Keeping managed objects out of the view
/// means the screen remains safe if its saved peripheral is removed while it is open.
struct BatteryHistoryInformation: Equatable {
    let transmitterDescription: String
    let bluetoothName: String
    let transmitterLifetime: TimeInterval?
    let currentReading: BatteryHistoryCurrentReading?
}

extension Notification.Name {
    static let batteryHistoryDidChange = Notification.Name("batteryHistoryDidChange")
}

/// Owns battery-history persistence. It never invents samples from a live cache: callers must pass
/// a genuine producer callback and the permanent object ID of the peripheral that emitted it.
final class BatteryHistoryManager {
    static let retentionInterval = TimeInterval(days: 400)
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCoreDataManager)
    private let coreDataManager: CoreDataManager

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    func record(peripheralObjectID: NSManagedObjectID, observedAt: Date = Date(), observation: BatteryHistoryObservation) {
        let context = coreDataManager.mainManagedObjectContext
        var didPrepareSample = false
        context.performAndWait {
            guard !peripheralObjectID.isTemporaryID,
                  let peripheral = try? context.existingObject(with: peripheralObjectID) as? BLEPeripheral,
                  !peripheral.isDeleted else {
                trace("Battery history write rejected: unavailable peripheral %{public}@", log: log, category: ConstantsLog.categoryCoreDataManager, type: .error, peripheralObjectID.uriRepresentation().absoluteString)
                return
            }

            if case .percentage(let value, _) = observation, !(0 ... 100).contains(value) { return }

            let sample: BatteryHistorySample
            // Percentage devices can report frequently, so retain only their newest genuine value
            // in each UTC hour. Dexcom packets keep their exact controlled observation timestamp.
            if case .percentage = observation,
               let existing = percentageSample(peripheral: peripheral, observedAt: observedAt, context: context) {
                guard observedAt >= existing.observedAt else { return }
                sample = existing
            } else if let existing = exactSample(peripheral: peripheral, observedAt: observedAt, context: context) {
                sample = existing
            } else {
                sample = BatteryHistorySample(context: context)
                sample.id = UniqueId.createEventId()
            }

            sample.blePeripheral = peripheral
            sample.peripheralAddress = peripheral.address
            sample.observedAt = observedAt
            switch observation {
            case .percentage(let value, let producer):
                sample.measurementKindRaw = BatteryMeasurementKind.percentage.rawValue
                sample.producerKindRaw = producer.rawValue
                sample.percentage = NSNumber(value: value)
                sample.utcHourBucketStart = Self.utcHourStart(for: observedAt)
            case .dexcom(let family, let status, let voltageA, let voltageB, let resistance, let runtime, let temperature, let producer):
                sample.measurementKindRaw = BatteryMeasurementKind.dexcomVoltage.rawValue
                sample.producerKindRaw = producer.rawValue
                sample.dexcomFamilyRaw = NSNumber(value: family.rawValue)
                sample.batteryStatusRaw = NSNumber(value: status)
                sample.voltageARaw = NSNumber(value: voltageA)
                sample.voltageBRaw = NSNumber(value: voltageB)
                sample.resistanceRaw = NSNumber(value: resistance)
                sample.runtimeRaw = NSNumber(value: runtime)
                sample.temperatureRaw = NSNumber(value: temperature)
            }

            prune(before: observedAt.addingTimeInterval(-Self.retentionInterval), context: context)
            didPrepareSample = true
        }

        // Leave the main-context mutation block before flushing both contexts. Battery callbacks
        // are sparse and may be followed by an immediate process replacement during development,
        // so reporting success before SQLite has committed the sample would silently lose history.
        guard didPrepareSample else { return }
        guard coreDataManager.saveChangesSynchronously() else {
            trace("Battery history write failed for %{public}@", log: log, category: ConstantsLog.categoryCoreDataManager, type: .error, peripheralObjectID.uriRepresentation().absoluteString)
            return
        }
        trace("Battery history committed peripheral=%{public}@ observedAt=%{public}@", log: log, category: ConstantsLog.categoryCoreDataManager, type: .info, peripheralObjectID.uriRepresentation().absoluteString, observedAt.description)
        NotificationCenter.default.post(name: .batteryHistoryDidChange, object: peripheralObjectID)
    }

    /// Returns whether this exact saved peripheral has at least one retained observation.
    func hasHistory(peripheralObjectID: NSManagedObjectID) -> Bool {
        var result = false
        let context = coreDataManager.mainManagedObjectContext
        context.performAndWait {
            guard !peripheralObjectID.isTemporaryID,
                  let peripheral = try? context.existingObject(with: peripheralObjectID) as? BLEPeripheral,
                  !peripheral.isDeleted else { return }
            let request: NSFetchRequest<BatteryHistorySample> = BatteryHistorySample.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "blePeripheral == %@ OR (blePeripheral == nil AND peripheralAddress ==[c] %@)", peripheral, peripheral.address)
            result = ((try? context.count(for: request)) ?? 0) > 0
        }
        return result
    }

    /// Returns chronologically ordered, value-only samples for the requested saved peripheral.
    func history(peripheralObjectID: NSManagedObjectID) -> [BatteryHistoryPoint] {
        var result: [BatteryHistoryPoint] = []
        let context = coreDataManager.mainManagedObjectContext
        context.performAndWait {
            guard !peripheralObjectID.isTemporaryID,
                  let peripheral = try? context.existingObject(with: peripheralObjectID) as? BLEPeripheral,
                  !peripheral.isDeleted else {
                trace("Battery history fetch rejected: unavailable peripheral %{public}@", log: log, category: ConstantsLog.categoryCoreDataManager, type: .error, peripheralObjectID.uriRepresentation().absoluteString)
                return
            }
            let request: NSFetchRequest<BatteryHistorySample> = BatteryHistorySample.fetchRequest()
            request.predicate = NSPredicate(format: "blePeripheral == %@ OR (blePeripheral == nil AND peripheralAddress ==[c] %@)", peripheral, peripheral.address)
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(BatteryHistorySample.observedAt), ascending: true)]
            do {
                let samples = try context.fetch(request)
                result = samples.compactMap { sample in
                    // Producer is provenance only. A newer producer must not hide a measurement
                    // whose units this build can already display.
                    guard let kind = BatteryMeasurementKind(rawValue: sample.measurementKindRaw) else { return nil }
                    return BatteryHistoryPoint(
                        id: sample.id,
                        observedAt: sample.observedAt,
                        kind: kind,
                        family: sample.dexcomFamilyRaw.flatMap { DexcomBatteryFamily(rawValue: $0.int16Value) },
                        percentage: sample.percentage?.intValue,
                        voltageA: sample.voltageARaw?.intValue,
                        voltageB: sample.voltageBRaw?.intValue
                    )
                }
                // Compare store-wide and exact-device counts only when the chart requests history.
                // This distinguishes absent rows from a changed peripheral relationship.
                request.predicate = nil
                let total = try context.count(for: request)
                trace("Battery history fetched peripheral=%{public}@ total=%{public}d matched=%{public}d decoded=%{public}d oldest=%{public}@", log: log, category: ConstantsLog.categoryCoreDataManager, type: .info, peripheralObjectID.uriRepresentation().absoluteString, total, samples.count, result.count, result.first?.observedAt.description ?? "none")
            } catch {
                trace("Battery history fetch failed peripheral=%{public}@ error=%{public}@", log: log, category: ConstantsLog.categoryCoreDataManager, type: .error, peripheralObjectID.uriRepresentation().absoluteString, error.localizedDescription)
            }
        }
        return result
    }

    /// Builds the current device information without exposing managed objects to SwiftUI.
    func information(peripheralObjectID: NSManagedObjectID, now: Date = Date()) -> BatteryHistoryInformation? {
        var result: BatteryHistoryInformation?
        let context = coreDataManager.mainManagedObjectContext
        context.performAndWait {
            guard !peripheralObjectID.isTemporaryID,
                  let peripheral = try? context.existingObject(with: peripheralObjectID) as? BLEPeripheral,
                  !peripheral.isDeleted else { return }

            let transmitterDescription: String
            let transmitterLifetime: TimeInterval?
            let currentReading: BatteryHistoryCurrentReading?

            if let dexcomG5 = peripheral.dexcomG5 {
                transmitterDescription = DexcomProductNameResolver.title(
                    transmitterType: .dexcom,
                    transmitterID: peripheral.transmitterId,
                    bluetoothName: peripheral.name,
                    isAnubis: dexcomG5.isAnubis
                ) ?? BluetoothPeripheralType.DexcomType.bluetoothPeripheralDisplayTitle
                transmitterLifetime = dexcomG5.transmitterStartDate.map { max(0, now.timeIntervalSince($0)) }
                currentReading = dexcomG5.voltageB > 0 ? .voltageB(rawValue: Int(dexcomG5.voltageB)) : nil
            } else if let dexcomG7 = peripheral.dexcomG7 {
                transmitterDescription = DexcomProductNameResolver.title(
                    transmitterType: .dexcomG7,
                    transmitterID: peripheral.transmitterId,
                    bluetoothName: peripheral.name
                ) ?? BluetoothPeripheralType.DexcomG7Type.bluetoothPeripheralDisplayTitle
                transmitterLifetime = dexcomG7.sensorStartDate.map { max(0, now.timeIntervalSince($0)) }
                currentReading = dexcomG7.voltageB > 0 ? .voltageB(rawValue: Int(dexcomG7.voltageB)) : nil
            } else if let m5Stack = peripheral.m5Stack {
                transmitterDescription = m5Stack.bluetoothPeripheralType().bluetoothPeripheralDisplayTitle
                transmitterLifetime = nil
                currentReading = m5Stack.batteryLevel > 0 ? .percentage(Int(m5Stack.batteryLevel)) : latestReading(peripheral: peripheral, context: context)
            } else if let bubble = peripheral.bubble {
                transmitterDescription = bubble.bluetoothPeripheralType().bluetoothPeripheralDisplayTitle
                transmitterLifetime = nil
                currentReading = bubble.batteryLevel > 0 ? .percentage(Int(bubble.batteryLevel)) : latestReading(peripheral: peripheral, context: context)
            } else if let miaoMiao = peripheral.miaoMiao {
                transmitterDescription = miaoMiao.bluetoothPeripheralType().bluetoothPeripheralDisplayTitle
                transmitterLifetime = nil
                currentReading = miaoMiao.batteryLevel > 0 ? .percentage(Int(miaoMiao.batteryLevel)) : latestReading(peripheral: peripheral, context: context)
            } else if let heartbeat = peripheral.libre2heartbeat {
                transmitterDescription = heartbeat.bluetoothPeripheralType().bluetoothPeripheralDisplayTitle
                transmitterLifetime = nil
                currentReading = latestReading(peripheral: peripheral, context: context)
            } else if let heartbeat = peripheral.dexcomG7HeartBeat {
                transmitterDescription = DexcomProductNameResolver.title(
                    transmitterType: .dexcomG7,
                    transmitterID: peripheral.transmitterId,
                    bluetoothName: peripheral.name
                ) ?? heartbeat.bluetoothPeripheralType().bluetoothPeripheralDisplayTitle
                transmitterLifetime = nil
                currentReading = latestReading(peripheral: peripheral, context: context)
            } else {
                return
            }

            result = BatteryHistoryInformation(
                transmitterDescription: transmitterDescription,
                bluetoothName: peripheral.name,
                transmitterLifetime: transmitterLifetime,
                currentReading: currentReading
            )
        }
        return result
    }

    private func latestReading(peripheral: BLEPeripheral, context: NSManagedObjectContext) -> BatteryHistoryCurrentReading? {
        let request: NSFetchRequest<BatteryHistorySample> = BatteryHistorySample.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "blePeripheral == %@ OR (blePeripheral == nil AND peripheralAddress ==[c] %@)", peripheral, peripheral.address)
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(BatteryHistorySample.observedAt), ascending: false)]
        guard let sample = try? request.execute().first,
              let kind = BatteryMeasurementKind(rawValue: sample.measurementKindRaw) else { return nil }

        switch kind {
        case .percentage:
            return sample.percentage.map { .percentage($0.intValue) }
        case .dexcomVoltage:
            return sample.voltageBRaw.map { .voltageB(rawValue: $0.intValue) }
        }
    }

    private func percentageSample(peripheral: BLEPeripheral, observedAt: Date, context: NSManagedObjectContext) -> BatteryHistorySample? {
        let request: NSFetchRequest<BatteryHistorySample> = BatteryHistorySample.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "(blePeripheral == %@ OR (blePeripheral == nil AND peripheralAddress ==[c] %@)) AND measurementKindRaw == %d AND utcHourBucketStart == %@", peripheral, peripheral.address, BatteryMeasurementKind.percentage.rawValue, Self.utcHourStart(for: observedAt) as NSDate)
        return try? request.execute().first
    }

    private func exactSample(peripheral: BLEPeripheral, observedAt: Date, context: NSManagedObjectContext) -> BatteryHistorySample? {
        let request: NSFetchRequest<BatteryHistorySample> = BatteryHistorySample.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "(blePeripheral == %@ OR (blePeripheral == nil AND peripheralAddress ==[c] %@)) AND observedAt == %@", peripheral, peripheral.address, observedAt as NSDate)
        return try? request.execute().first
    }

    private func prune(before cutoff: Date, context: NSManagedObjectContext) {
        // Retention is global because every saved peripheral uses the same fixed 400-day policy.
        let request: NSFetchRequest<BatteryHistorySample> = BatteryHistorySample.fetchRequest()
        request.predicate = NSPredicate(format: "observedAt < %@", cutoff as NSDate)
        (try? request.execute())?.forEach(context.delete)
    }

    static func utcHourStart(for date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 3600) * 3600)
    }
}
