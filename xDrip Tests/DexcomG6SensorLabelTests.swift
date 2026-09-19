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

    func testDecodesObservedDexcomG7ApplicatorLabels() throws {
        let samples = [
            ("01003862700039352196980078534311240901172602282405069", "969800785343", "5069"),
            ("01003862700039352174508337707911240901172602282408782", "745083377079", "8782"),
            ("01003862700039352145042249669611240901172602282407614", "450422496696", "7614")
        ]

        for (payload, serial, code) in samples {
            let label = try DexcomG7SensorLabelParser.parse(payload)
            XCTAssertEqual(label.productIdentifier, "00386270003935")
            XCTAssertEqual(label.serialNumber, serial)
            XCTAssertEqual(label.sensorCode, code)
            XCTAssertEqual(label.manufactureDate, utcDate(year: 2024, month: 9, day: 1))
            XCTAssertEqual(label.expirationDate, utcDate(year: 2026, month: 2, day: 28))
            XCTAssertTrue(label.lotNumber.isEmpty)
        }
    }

    func testRejectsMalformedDexcomG7ApplicatorLabel() {
        XCTAssertThrowsError(
            try DexcomG7SensorLabelParser.parse("0100386270003935219698007853431124090117260228240506")
        )
    }

    func testDexcomG7ParserAcceptsAppleBarcodeTransportWrappers() throws {
        let payload = "01003862700039352196980078534311240901172602282405069"
        let symbologyWrapped = try DexcomG7SensorLabelParser.parse("]d2\(payload)")
        let separatorWrapped = try DexcomG7SensorLabelParser.parse(
            "]d2\(String(payload.prefix(30)))\u{001D}\(String(payload.dropFirst(30)))\u{0004}"
        )

        XCTAssertEqual(symbologyWrapped.sensorCode, "5069")
        XCTAssertEqual(separatorWrapped, symbologyWrapped)
    }

    func testFormatsDexcomG7ApplicatorDatesWithoutShiftingToPreviousDay() throws {
        // This observed Stelo label contains manufacture date 1 August 2025 and expiry date 31 January 2027.
        // Both dates previously appeared one day early in a US time zone because midnight UTC was formatted locally.
        let label = try DexcomG7SensorLabelParser.parse(
            "01003862700043382169268597267111250801172701312406772"
        )
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let pacific = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))

        let expectedFormatter = DateFormatter()
        expectedFormatter.timeZone = utc
        expectedFormatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy")

        for date in [try XCTUnwrap(label.manufactureDate), try XCTUnwrap(label.expirationDate)] {
            // The production UI explicitly uses UTC for these date-only values while retaining the user's date order.
            let displayedDate = date.toStringInUserLocale(
                timeStyle: .none,
                dateStyle: .short,
                timeZone: utc
            )
            XCTAssertEqual(displayedDate, expectedFormatter.string(from: date))

            // Confirm the regression is meaningful. Formatting the same midnight value in Pacific time changes its day.
            let incorrectlyLocalizedDate = date.toStringInUserLocale(
                timeStyle: .none,
                dateStyle: .short,
                timeZone: pacific
            )
            XCTAssertNotEqual(displayedDate, incorrectlyLocalizedDate)
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

    func testV27ToV28LightweightMappingCanBeInferred() throws {
        let modelDirectory = try XCTUnwrap(
            Bundle.main.url(forResource: ConstantsCoreData.modelName, withExtension: "momd")
        )
        let v27 = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v27.mom"))
        )
        let v28 = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v28.mom"))
        )

        XCTAssertNoThrow(try NSMappingModel.inferredMappingModel(forSourceModel: v27, destinationModel: v28))
        let dexcomG7 = try XCTUnwrap(v28.entitiesByName["DexcomG7"])
        XCTAssertNotNil(dexcomG7.attributesByName["sensorCode"])
        XCTAssertNotNil(dexcomG7.attributesByName["sensorSerialNumber"])
        XCTAssertNotNil(dexcomG7.attributesByName["sensorProductIdentifier"])
        XCTAssertNotNil(dexcomG7.attributesByName["useOtherAppValue"])
        XCTAssertNotNil(dexcomG7.attributesByName["bluetoothSlot"])
    }

    func testV28ToV29LightweightMappingCanBeInferred() throws {
        let modelDirectory = try XCTUnwrap(
            Bundle.main.url(forResource: ConstantsCoreData.modelName, withExtension: "momd")
        )
        let v28 = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v28.mom"))
        )
        let v29 = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v29.mom"))
        )

        XCTAssertNoThrow(try NSMappingModel.inferredMappingModel(forSourceModel: v28, destinationModel: v29))
        let dexcomG7 = try XCTUnwrap(v29.entitiesByName["DexcomG7"])
        XCTAssertNotNil(dexcomG7.attributesByName["sensorSessionLength"])
    }

    func testV29ToV30LightweightMappingCanBeInferred() throws {
        let modelDirectory = try XCTUnwrap(
            Bundle.main.url(forResource: ConstantsCoreData.modelName, withExtension: "momd")
        )
        let v29 = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v29.mom"))
        )
        let v30 = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("xdrip v30.mom"))
        )

        XCTAssertNoThrow(try NSMappingModel.inferredMappingModel(forSourceModel: v29, destinationModel: v30))
        let dexcomG7 = try XCTUnwrap(v30.entitiesByName["DexcomG7"])
        let newAttributes = [
            "firmwareVersion", "firmwareBuildVersion", "firmwareVersionCode",
            "batteryStatus", "batteryResist", "batteryRuntime", "batteryTemperature",
            "voltageA", "voltageB", "batteryLastReadDate"
        ]
        newAttributes.forEach { XCTAssertNotNil(dexcomG7.attributesByName[$0]) }
    }

    func testRoundTripsDexcomG7LabelAndConnectionSettingsThroughCoreData() throws {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let context = coreDataManager.mainManagedObjectContext
        let dexcomG7 = DexcomG7(
            address: "test-g7",
            name: "DXCM01",
            alias: nil,
            nsManagedObjectContext: context
        )
        let label = try DexcomG7SensorLabelParser.parse(
            "01003862700039352196980078534311240901172602282405069"
        )

        dexcomG7.useOtherApp = false
        dexcomG7.setBluetoothSlot(DexcomG7BluetoothSlot.smartWatch)
        dexcomG7.sensorSessionLength = NSNumber(value: TimeInterval(days: 15.5))
        dexcomG7.firmwareVersion = "1.2.3.4"
        dexcomG7.firmwareBuildVersion = NSNumber(value: 123_456)
        dexcomG7.firmwareVersionCode = NSNumber(value: 789)
        dexcomG7.batteryStatus = 0
        dexcomG7.voltageA = 288
        dexcomG7.voltageB = 267
        dexcomG7.batteryResist = 8_454
        dexcomG7.batteryRuntime = 10
        dexcomG7.batteryTemperature = 25
        dexcomG7.batteryLastReadDate = Date(timeIntervalSince1970: 2_000_000_000)
        dexcomG7.apply(sensorLabel: label)
        coreDataManager.saveChanges()
        let objectID = dexcomG7.objectID
        context.reset()

        let restored = try XCTUnwrap(context.existingObject(with: objectID) as? DexcomG7)
        XCTAssertFalse(restored.useOtherApp)
        XCTAssertEqual(restored.resolvedDexcomG7BluetoothSlot(), .smartWatch)
        XCTAssertEqual(restored.sensorSessionLength?.doubleValue, TimeInterval(days: 15.5))
        XCTAssertEqual(restored.firmwareVersion, "1.2.3.4")
        XCTAssertEqual(restored.firmwareBuildVersion?.uint32Value, 123_456)
        XCTAssertEqual(restored.firmwareVersionCode?.uint32Value, 789)
        XCTAssertEqual(restored.voltageA, 288)
        XCTAssertEqual(restored.voltageB, 267)
        XCTAssertEqual(restored.batteryResist, 8_454)
        XCTAssertEqual(restored.batteryRuntime, 10)
        XCTAssertEqual(restored.batteryTemperature, 25)
        XCTAssertEqual(restored.batteryLastReadDate, Date(timeIntervalSince1970: 2_000_000_000))
        XCTAssertEqual(restored.sensorCode, "5069")
        XCTAssertEqual(restored.sensorSerialNumber, "969800785343")
        XCTAssertEqual(restored.sensorProductIdentifier, "00386270003935")
        XCTAssertEqual(restored.sensorManufactureDate, utcDate(year: 2024, month: 9, day: 1))
        XCTAssertEqual(restored.sensorExpirationDate, utcDate(year: 2026, month: 2, day: 28))
        XCTAssertNil(restored.sensorLotNumber)
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

    func testValidatedMatchingSessionRepairsRejectedCodedStart() {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let sensor = Sensor(startDate: Date(), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        sensor.apply(startRequest: SensorStartRequest(startDate: sensor.startDate, requestedSensorCode: "5937"))
        sensor.sensorSessionOrigin = .startRejected

        XCTAssertTrue(sensor.confirmSessionStartedByApp())
        XCTAssertEqual(sensor.sensorSessionOrigin, .startedByApp)
        XCTAssertEqual(sensor.sensorCalibrationMode, .factoryCoded)
        XCTAssertEqual(sensor.activeSensorCode, "5937")
    }

    func testValidatedMatchingSessionConfirmsPendingNoCodeStart() {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let sensor = Sensor(startDate: Date(), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        sensor.apply(startRequest: SensorStartRequest(startDate: sensor.startDate, requestedSensorCode: "0000"))

        XCTAssertTrue(sensor.confirmSessionStartedByApp())
        XCTAssertEqual(sensor.sensorSessionOrigin, .startedByApp)
        XCTAssertEqual(sensor.sensorCalibrationMode, .noCode)
        XCTAssertEqual(sensor.activeSensorCode, "0000")
    }

    func testValidatedMatchingSessionDoesNotReplaceAdoptedOrigin() {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let sensor = Sensor(startDate: Date(), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        sensor.apply(startRequest: SensorStartRequest(startDate: sensor.startDate, requestedSensorCode: "5937"))
        sensor.sensorSessionOrigin = .existingSessionAdopted
        sensor.sensorCalibrationMode = .factoryCoded

        XCTAssertFalse(sensor.confirmSessionStartedByApp())
        XCTAssertEqual(sensor.sensorSessionOrigin, .existingSessionAdopted)
        XCTAssertNil(sensor.activeSensorCode)
    }

    private func utcDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
