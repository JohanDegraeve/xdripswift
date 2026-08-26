//
//  DexcomG6SensorLabelTests.swift
//  xdripTests
//
//  Created by Paul Plant on 26/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import XCTest
@testable import xdrip

final class DexcomG6SensorLabelTests: XCTestCase {
    private let separator = "\u{001D}"

    // MARK: - Parser

    func testDecodesAllObservedSensorLabels() throws {
        let samples: [(payload: String, lot: String, serial: String, code: String)] = [
            ("105336121\(separator)21821184A\(separator)2405937", "5336121", "821184A", "5937"),
            ("105337765\(separator)21856224B\(separator)2409311", "5337765", "856224B", "9311"),
            ("105337765\(separator)21122084H\(separator)2405917", "5337765", "122084H", "5917"),
            ("105337765\(separator)21122084G\(separator)2405955", "5337765", "122084G", "5955"),
            ("105337765\(separator)21928983G\(separator)2409117", "5337765", "928983G", "9117"),
            ("105337765\(separator)21873252D\(separator)2409311", "5337765", "873252D", "9311"),
            ("105337765\(separator)21153812F\(separator)2405937", "5337765", "1153812F", "5937"),
            ("105337765\(separator)21151019D\(separator)2409311", "5337765", "1151019D", "9311"),
            ("105337765\(separator)21806736E\(separator)2409311", "5337765", "806736E", "9311"),
            ("105337765\(separator)21133322H\(separator)2409159", "5337765", "1133322H", "9159")
        ]

        for sample in samples {
            let label = try DexcomG6SensorLabelParser.parse(sample.payload)
            XCTAssertEqual(label.lotNumber, sample.lot)
            XCTAssertEqual(label.serialNumber, sample.serial)
            XCTAssertEqual(label.sensorCode, sample.code)
        }
    }

    func testAllowsAdditionalSeparatedFields() throws {
        let label = try DexcomG6SensorLabelParser.parse(
            "10LOT1\(separator)21SERIAL1\(separator)99EXTRA\(separator)2405937"
        )
        XCTAssertEqual(label.sensorCode, "5937")
    }

    func testDoesNotTreat240InsideSerialAsApplicationIdentifier() {
        XCTAssertThrowsError(
            try DexcomG6SensorLabelParser.parse("10LOT1\(separator)21SER240IAL")
        )
    }

    func testRejectsMalformedRequiredFields() {
        let invalidPayloads = [
            "10LOT121SERIAL12405937",
            "21SERIAL1\(separator)2405937",
            "10LOT1\(separator)2405937",
            "10LOT1\(separator)21SERIAL1",
            "10LOT1\(separator)21SERIAL1\(separator)240123",
            "10LOT1\(separator)21SERIAL1\(separator)24012A4",
            "10\(separator)21SERIAL1\(separator)2405937",
            "10LOT1\(separator)21\(separator)2405937",
            "10LOT1\(separator)10LOT2\(separator)21SERIAL1\(separator)2405937",
            "10LOT1\(separator)21SERIAL1\(separator)21SERIAL2\(separator)2405937",
            "10LOT1\(separator)21SERIAL1\(separator)2405937\(separator)2409311"
        ]

        for payload in invalidPayloads {
            XCTAssertThrowsError(try DexcomG6SensorLabelParser.parse(payload), payload)
        }
    }

    // MARK: - Persistence

    func testRoundTripsSensorStartMetadataThroughCoreData() throws {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let context = coreDataManager.mainManagedObjectContext
        let sensor = Sensor(startDate: Date(timeIntervalSince1970: 2_000_000_000), nsManagedObjectContext: context)
        sensor.apply(
            startRequest: SensorStartRequest(
                startDate: sensor.startDate,
                requestedSensorCode: "5937",
                sensorLabel: DexcomG6SensorLabel(
                    sensorCode: "5937",
                    lotNumber: "5336121",
                    serialNumber: "821184A"
                )
            )
        )
        sensor.sensorSessionOrigin = .startedByApp
        sensor.sensorCalibrationMode = .factoryCoded

        coreDataManager.saveChanges()
        let objectID = sensor.objectID
        context.reset()

        let restored = try XCTUnwrap(context.existingObject(with: objectID) as? Sensor)
        XCTAssertEqual(restored.requestedSensorCode, "5937")
        XCTAssertEqual(restored.sensorLabelCode, "5937")
        XCTAssertEqual(restored.sensorLotNumber, "5336121")
        XCTAssertEqual(restored.sensorSerialNumber, "821184A")
        XCTAssertEqual(restored.sensorSessionOrigin, .startedByApp)
        XCTAssertEqual(restored.sensorCalibrationMode, .factoryCoded)
        XCTAssertEqual(restored.activeSensorCode, "5937")
    }

    func testV26ToV27LightweightMappingCanBeInferred() throws {
        let modelDirectory = try XCTUnwrap(
            Bundle.main.url(forResource: ConstantsCoreData.modelName, withExtension: "momd")
        )
        let v26 = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v26.mom"))
        )
        let v27 = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v27.mom"))
        )

        XCTAssertNoThrow(try NSMappingModel.inferredMappingModel(forSourceModel: v26, destinationModel: v27))

        let sensor = try XCTUnwrap(v27.entitiesByName["Sensor"])
        XCTAssertNotNil(sensor.attributesByName["requestedSensorCode"])
        XCTAssertEqual((sensor.attributesByName["sensorSessionOriginRaw"]?.defaultValue as? NSNumber)?.int16Value, 0)
        XCTAssertEqual((sensor.attributesByName["sensorCalibrationModeRaw"]?.defaultValue as? NSNumber)?.int16Value, 0)
    }

    func testMigratesExistingSensorFromV26ToV27() throws {
        let modelDirectory = try XCTUnwrap(
            Bundle.main.url(forResource: ConstantsCoreData.modelName, withExtension: "momd")
        )
        let v26 = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v26.mom"))
        )
        let v27 = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v27.mom"))
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("migration.sqlite")
        let sensorID = UUID().uuidString
        let startDate = Date(timeIntervalSince1970: 2_000_000_000)

        let sourceCoordinator = NSPersistentStoreCoordinator(managedObjectModel: v26)
        let sourceStore = try sourceCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL
        )
        let sourceContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        sourceContext.persistentStoreCoordinator = sourceCoordinator
        let sourceSensor = NSEntityDescription.insertNewObject(forEntityName: "Sensor", into: sourceContext)
        sourceSensor.setValue(sensorID, forKey: "id")
        sourceSensor.setValue(startDate, forKey: "startDate")
        try sourceContext.save()
        try sourceCoordinator.remove(sourceStore)

        let destinationCoordinator = NSPersistentStoreCoordinator(managedObjectModel: v27)
        let migrationOptions = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        _ = try destinationCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: migrationOptions
        )
        let destinationContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        destinationContext.persistentStoreCoordinator = destinationCoordinator
        let request = NSFetchRequest<NSManagedObject>(entityName: "Sensor")
        let migratedSensor = try XCTUnwrap(destinationContext.fetch(request).first)

        XCTAssertEqual(migratedSensor.value(forKey: "id") as? String, sensorID)
        XCTAssertEqual(migratedSensor.value(forKey: "startDate") as? Date, startDate)
        XCTAssertNil(migratedSensor.value(forKey: "requestedSensorCode"))
        XCTAssertEqual((migratedSensor.value(forKey: "sensorSessionOriginRaw") as? NSNumber)?.int16Value, 0)
        XCTAssertEqual((migratedSensor.value(forKey: "sensorCalibrationModeRaw") as? NSNumber)?.int16Value, 0)
    }

    func testCopiesStartMetadataWhenExistingSessionIsAdopted() {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let context = coreDataManager.mainManagedObjectContext
        let provisionalSensor = Sensor(startDate: Date(), nsManagedObjectContext: context)
        provisionalSensor.apply(
            startRequest: SensorStartRequest(
                startDate: provisionalSensor.startDate,
                requestedSensorCode: "5937",
                sensorLabel: DexcomG6SensorLabel(
                    sensorCode: "5937",
                    lotNumber: "5336121",
                    serialNumber: "821184A"
                )
            )
        )

        let adoptedSensor = Sensor(
            startDate: provisionalSensor.startDate.addingTimeInterval(-3_600),
            nsManagedObjectContext: context
        )
        adoptedSensor.copyDexcomStartMetadata(from: provisionalSensor)
        adoptedSensor.sensorSessionOrigin = .existingSessionAdopted
        adoptedSensor.sensorCalibrationMode = .factoryCoded

        XCTAssertEqual(adoptedSensor.requestedSensorCode, "5937")
        XCTAssertEqual(adoptedSensor.sensorLabelCode, "5937")
        XCTAssertEqual(adoptedSensor.sensorLotNumber, "5336121")
        XCTAssertEqual(adoptedSensor.sensorSerialNumber, "821184A")
        XCTAssertEqual(adoptedSensor.sensorSessionOrigin, .existingSessionAdopted)
        XCTAssertNil(adoptedSensor.activeSensorCode)
    }

    // MARK: - Session classification

    func testSessionResultClassification() {
        let requested = Date(timeIntervalSince1970: 2_000_000_000)

        let started = CGMSensorSessionStartResult(
            response: .autoCalibrationSessionInProgress,
            requestedStartDate: requested,
            sessionStartDate: requested.addingTimeInterval(15)
        )
        XCTAssertEqual(started.sessionOrigin(tolerance: 15), .startedByApp)
        XCTAssertEqual(started.calibrationMode, .factoryCoded)

        let noCodeStarted = CGMSensorSessionStartResult(
            response: .manualCalibrationSessionStarted,
            requestedStartDate: requested,
            sessionStartDate: requested
        )
        XCTAssertEqual(noCodeStarted.sessionOrigin(tolerance: 15), .startedByApp)
        XCTAssertEqual(noCodeStarted.calibrationMode, .noCode)

        let adopted = CGMSensorSessionStartResult(
            response: .autoCalibrationSessionInProgress,
            requestedStartDate: requested,
            sessionStartDate: requested.addingTimeInterval(-3_600)
        )
        XCTAssertEqual(adopted.sessionOrigin(tolerance: 15), .existingSessionAdopted)

        let noCodeAdopted = CGMSensorSessionStartResult(
            response: .manualCalibrationSessionInProgress,
            requestedStartDate: requested,
            sessionStartDate: requested.addingTimeInterval(-3_600)
        )
        XCTAssertEqual(noCodeAdopted.sessionOrigin(tolerance: 15), .existingSessionAdopted)
        XCTAssertEqual(noCodeAdopted.calibrationMode, .noCode)

        let rejected = CGMSensorSessionStartResult(
            response: .error,
            requestedStartDate: requested,
            sessionStartDate: requested
        )
        XCTAssertEqual(rejected.sessionOrigin(tolerance: 15), .startRejected)
        XCTAssertEqual(rejected.calibrationMode, .unknown)
    }

    func testActiveCodeNeverUsesRequested0000ForAdoptedFactoryCodedSession() {
        XCTAssertNil(
            SensorCodeState.activeCode(
                requestedSensorCode: "0000",
                origin: .existingSessionAdopted,
                calibrationMode: .factoryCoded
            )
        )
        XCTAssertEqual(
            SensorCodeState.activeCode(
                requestedSensorCode: "0000",
                origin: .startedByApp,
                calibrationMode: .noCode
            ),
            "0000"
        )
        XCTAssertEqual(
            SensorCodeState.activeCode(
                requestedSensorCode: "5937",
                origin: .startedByApp,
                calibrationMode: .factoryCoded
            ),
            "5937"
        )
        XCTAssertEqual(
            SensorCodeState.activeCode(
                requestedSensorCode: "0000",
                origin: .existingSessionAdopted,
                calibrationMode: .noCode
            ),
            "0000"
        )
        XCTAssertNil(
            SensorCodeState.activeCode(
                requestedSensorCode: "5937",
                origin: .startRejected,
                calibrationMode: .unknown
            )
        )
    }
}
