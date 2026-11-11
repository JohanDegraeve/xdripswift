//
//  Libre3IntegrationTests.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
import CoreData
import CoreNFC
import Security
@testable import xdrip

final class Libre3IntegrationTests: XCTestCase {
    func testNFCScanCallbackOwnershipIsSafeDuringCancellationAndReplacement() {
        let reader = Libre3NFCActivationReader()
        // No NFC hardware is needed to reproduce the closure ownership race between
        // setup replacing its callbacks and an older asynchronous scan reading them.
        DispatchQueue.concurrentPerform(iterations: 2000) { index in
            if index.isMultiple(of: 2) {
                let captured = Data(repeating: UInt8(truncatingIfNeeded: index), count: 32)
                reader.prepare = { _ in XCTAssertEqual(captured.count, 32) }
                reader.saveResponse = { _, _ in XCTAssertEqual(captured.count, 32) }
            } else {
                _ = reader.prepare
                _ = reader.saveResponse
                reader.cancel()
            }
        }
        reader.prepare = nil
        reader.saveResponse = nil
        XCTAssertNil(reader.prepare)
        XCTAssertNil(reader.saveResponse)
    }

    func testProductNamesUseDeclaredWearDurationAndKeepUnknownVariantsGeneric() {
        XCTAssertEqual(Libre3ProductNameResolver.title(wearMinutes: 14 * 24 * 60), "Libre 3")
        XCTAssertEqual(Libre3ProductNameResolver.title(wearMinutes: 15 * 24 * 60), "Libre 3 Plus")
        for minutes: Int? in [nil, 0, -1, 60, 16 * 24 * 60] {
            XCTAssertEqual(Libre3ProductNameResolver.title(wearMinutes: minutes), "Libre 3/3 Plus")
        }
    }

    func testReceiverIDRejectsAccidentalTextAndInvalidCharacters() {
        XCTAssertNil(Libre3ReceiverID.parseLittleEndianHex("c7f9!5683"))
        XCTAssertNil(Libre3ReceiverID.parseLittleEndianHex("Receiver ID c7f95683"))
        XCTAssertEqual(Libre3ReceiverID.parseLittleEndianHex(" 0xc7f95683 \n"), 2203515335)
    }

    func testGlucoseAssemblerDropsOrphanSuffixAndReplacesIncompletePrefix() {
        let assembler = Libre3DataPlaneNotificationAssembler()
        XCTAssertNil(assembler.feed(fragment: Data(repeating: 1, count: 20), channel: .glucoseData))
        XCTAssertNil(assembler.feed(fragment: Data(repeating: 2, count: 15), channel: .glucoseData))
        XCTAssertNil(assembler.feed(fragment: Data(repeating: 3, count: 15), channel: .glucoseData))
        XCTAssertEqual(
            assembler.feed(fragment: Data(repeating: 4, count: 20), channel: .glucoseData),
            Data(repeating: 3, count: 15) + Data(repeating: 4, count: 20))
        assembler.reset()
        XCTAssertNil(assembler.feed(fragment: Data(repeating: 5, count: 20), channel: .glucoseData))
    }

    func testHistoricalLifeCountCannotOverflow() {
        var bytes = Data(repeating: 0, count: 14)
        bytes[0] = 0xff
        bytes[1] = 0xff
        XCTAssertThrowsError(try Libre3HistoricalReadingPage(plaintext: bytes))
    }

    func testEarlyNotificationsAreBufferedAndSequenceResetsForNextMessage() async throws {
        let transport = Libre3AuthTransport { _, _ in }
        await transport.receive(Data([0, 1, 2]), on: .certificate)
        await transport.receive(Data([1, 3]), on: .certificate)
        let first = try await transport.awaitNotify(on: .certHandshake, exactly: 3)
        XCTAssertEqual(first, Data([1, 2, 3]))
        await transport.receive(Data([0, 4]), on: .certificate)
        let second = try await transport.awaitNotify(on: .certHandshake, exactly: 1)
        XCTAssertEqual(second, Data([4]))
    }

    func testDisconnectedTransportCannotUseBufferedResponses() async {
        let transport = Libre3AuthTransport { _, _ in }
        await transport.receive(Data([8]), on: .command)
        await transport.finish()
        do {
            _ = try await transport.awaitCommandResponse(timeout: 0.1)
            XCTFail("Old connection response must not be accepted")
        } catch {}
    }

    func testCommandTimeoutCompletesPendingOperation() async {
        let transport = Libre3AuthTransport { _, _ in }
        do {
            _ = try await transport.awaitCommandResponse(timeout: 0.1)
            XCTFail("Expected timeout")
        } catch {
            guard case Libre3ConnectionError.timeout = error else { return XCTFail("Wrong error") }
        }
    }

}

extension Libre3IntegrationTests {
    func testCoreDataMigrationRetainsPreviousModelAndSupportsLibre3Inverse() throws {
        let directory = try XCTUnwrap(Bundle.main.url(forResource: "xdrip", withExtension: "momd"))
        let previous = try XCTUnwrap(NSManagedObjectModel(contentsOf: directory.appendingPathComponent("xdrip v32.mom")))
        let current = try XCTUnwrap(NSManagedObjectModel(contentsOf: directory.appendingPathComponent("xdrip v35.mom")))
        _ = try NSMappingModel.inferredMappingModel(forSourceModel: previous, destinationModel: current)
        XCTAssertEqual(current.entitiesByName["Libre3"]?.relationshipsByName["blePeripheral"]?.inverseRelationship?.name, "libre3")
    }

    func testLibre3StoreMigratesToCombinedWatchModelWithPairingAndValuesPreserved() throws {
        let models = try XCTUnwrap(Bundle.main.url(forResource: "xdrip", withExtension: "momd"))
        let source = try XCTUnwrap(NSManagedObjectModel(contentsOf: models.appendingPathComponent("xdrip v33.mom")))
        let target = try XCTUnwrap(NSManagedObjectModel(contentsOf: models.appendingPathComponent("xdrip v35.mom")))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Libre3.sqlite")
        let oldCoordinator = NSPersistentStoreCoordinator(managedObjectModel: source)
        let oldStore = try oldCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let oldContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        oldContext.persistentStoreCoordinator = oldCoordinator
        try oldContext.performAndWait {
            let peripheral = NSEntityDescription.insertNewObject(forEntityName: "BLEPeripheral", into: oldContext)
            peripheral.setValue("saved-address", forKey: "address")
            peripheral.setValue("Libre 3", forKey: "name")
            peripheral.setValue(false, forKey: "parameterUpdateNeededAtNextConnect")
            peripheral.setValue(true, forKey: "shouldconnect")
            peripheral.setValue(false, forKey: "webOOPEnabled")
            let sensor = NSEntityDescription.insertNewObject(forEntityName: "Libre3", into: oldContext)
            sensor.setValue(peripheral, forKey: "blePeripheral")
            sensor.setValue("retained-status", forKey: "status")
            let reading = NSEntityDescription.insertNewObject(forEntityName: "BgReading", into: oldContext)
            reading.setValue("libre3-reading", forKey: "id")
            reading.setValue(Date(timeIntervalSince1970: 1_790_000_000), forKey: "timeStamp")
            reading.setValue(123.0, forKey: "calculatedValue")
            reading.setValue(false, forKey: "calibrationFlag")
            reading.setValue(false, forKey: "hideSlope")
            try oldContext.save()
        }
        try oldCoordinator.remove(oldStore)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: target)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url,
            options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            let sensor = try XCTUnwrap(context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Libre3")).first)
            let peripheral = try XCTUnwrap(sensor.value(forKey: "blePeripheral") as? NSManagedObject)
            XCTAssertEqual(sensor.value(forKey: "status") as? String, "retained-status")
            XCTAssertEqual(peripheral.value(forKey: "address") as? String, "saved-address")
            XCTAssertEqual(peripheral.value(forKey: "libre3") as? NSManagedObject, sensor)
            let reading = try XCTUnwrap(context.fetch(NSFetchRequest<NSManagedObject>(entityName: "BgReading")).first)
            XCTAssertEqual(reading.value(forKey: "id") as? String, "libre3-reading")
            XCTAssertEqual(reading.value(forKey: "calculatedValue") as? Double, 123)
            XCTAssertEqual(reading.value(forKey: "valueIsFromWatch") as? Bool, false)
            XCTAssertNil(reading.value(forKey: "watchCollectedAt"))
        }
    }

}

extension Libre3IntegrationTests {
    func testCredentialStoreKeepsAppIdentitySeparateFromImportedSensor() throws {
        let service = "xdrip.libre3.tests." + UUID().uuidString
        defer { SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary) }
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "probe",
            kSecValueData as String: Data([0]),
        ]
        let availability = SecItemAdd(probe as CFDictionary, nil)
        if availability == errSecMissingEntitlement { throw XCTSkip("Unsigned simulator cannot access Keychain, requires a signed host.") }
        XCTAssertEqual(availability, errSecSuccess)
        let store = Libre3CredentialStore(service: service)
        let appIdentity = try store.appReceiverID()
        var imported = Libre3PairingRecord.unavailable(serial: "TEST00001")
        imported.receiverID = appIdentity &+ 1
        imported.blePIN = Data([1, 2, 3, 4])
        imported.phase5Key = Data(repeating: 5, count: 16)
        imported.rejectedMinutes = [62, 63]
        try store.save(imported)
        XCTAssertEqual(try store.appReceiverID(), appIdentity)
        XCTAssertEqual(try store.load(serial: imported.serial), imported)
        XCTAssertEqual(try store.pending(), imported)
    }

    func testCorruptedAppIdentityIsNotSilentlyReplaced() throws {
        let service = "xdrip.libre3.tests." + UUID().uuidString
        defer { SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "receiver",
            kSecValueData as String: Data([1, 2, 3]),
        ]
        let result = SecItemAdd(query as CFDictionary, nil)
        if result == errSecMissingEntitlement { throw XCTSkip("Unsigned simulator cannot access Keychain, requires a signed host.") }
        XCTAssertEqual(result, errSecSuccess)
        XCTAssertThrowsError(try Libre3CredentialStore(service: service).appReceiverID())
    }
}

extension Libre3IntegrationTests {
    func testBackfillIncludesTheWholeKnownInterruption() {
        // Reproduce the five-hour gap from the overnight test without limiting it to three hours.
        XCTAssertEqual(Libre3BackfillWindow.startMinute(currentAge: 7171, lastKnownAge: 6851, warmupMinutes: 60), 6851)
        XCTAssertEqual(Libre3BackfillWindow.startMinute(currentAge: 7171, lastKnownAge: 7170, warmupMinutes: 60), 6991)
    }

    func testBackfillKeepsUnknownHistoryBoundedAndExcludesWarmup() {
        XCTAssertEqual(Libre3BackfillWindow.startMinute(currentAge: 7171, lastKnownAge: nil, warmupMinutes: 60), 6991)
        XCTAssertEqual(Libre3BackfillWindow.startMinute(currentAge: 100, lastKnownAge: 0, warmupMinutes: 60), 60)
        XCTAssertEqual(Libre3BackfillWindow.startMinute(currentAge: 7171, lastKnownAge: 8000, warmupMinutes: 60), 6991)
        XCTAssertNil(Libre3BackfillWindow.startMinute(currentAge: 60, lastKnownAge: 0, warmupMinutes: 60))
        XCTAssertNil(Libre3BackfillWindow.startMinute(currentAge: -1, lastKnownAge: nil, warmupMinutes: 60))
        XCTAssertNil(Libre3BackfillWindow.startMinute(currentAge: 65536, lastKnownAge: nil, warmupMinutes: 60))
        XCTAssertNil(Libre3BackfillWindow.startMinute(currentAge: 100, lastKnownAge: nil, warmupMinutes: -1))
    }

    func testBackfillSummaryKeepsStreamCountsAndOutOfOrderRange() {
        var summary = Libre3BackfillSummary()
        summary.append(minutes: [7000, 6990], stream: .historical)
        summary.append(minutes: [6998], stream: .clinical)
        summary.append(minutes: [6989], stream: .clinical)
        summary.append(minutes: [], stream: .historical)
        XCTAssertEqual(summary.historicalCount, 2)
        XCTAssertEqual(summary.clinicalCount, 2)
        XCTAssertEqual(summary.firstMinute, 6989)
        XCTAssertEqual(summary.lastMinute, 7000)
        let empty = Libre3BackfillSummary()
        XCTAssertNil(empty.firstMinute)
        XCTAssertNil(empty.lastMinute)
    }
}

extension Libre3IntegrationTests {
    func testNFCCancellationTimeoutAndFailureKeepDistinctOutcomes() {
        XCTAssertEqual(Libre3NFCActivationReader.scanOutcome(for: CancellationError()), .nfcScanCancelled)
        XCTAssertEqual(Libre3NFCActivationReader.scanOutcome(for: NSError(domain: NFCErrorDomain, code: NFCReaderError.Code.readerSessionInvalidationErrorUserCanceled.rawValue)), .nfcScanCancelled)
        XCTAssertEqual(Libre3NFCActivationReader.scanOutcome(for: NSError(domain: NFCErrorDomain, code: NFCReaderError.Code.readerSessionInvalidationErrorSessionTimeout.rawValue)), .nfcScanTimedOut)
        XCTAssertEqual(Libre3NFCActivationReader.scanOutcome(for: Libre3NFCError.readerUnavailable), .nfcUnavailable)
        XCTAssertEqual(Libre3NFCActivationReader.scanOutcome(for: Libre3NFCError.noTag), .nfcScanFailed)
    }
}
