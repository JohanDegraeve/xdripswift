//
//  TroubleshootingLogTests.swift
//  xdripTests
//
//  Created by Paul Plant on 14/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class TroubleshootingLogTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testIssueReportExistsOnlyInsideRevealedAdvancedRows() throws {
        let previousAdvancedVisibility = UserDefaults.standard.showDeveloperSettings
        UserDefaults.standard.showDeveloperSettings = false
        defer { UserDefaults.standard.showDeveloperSettings = previousAdvancedVisibility }

        let sections = SettingsListFactory.makeRootSections(
            coreDataManager: nil,
            selectedFollowerActions: .none,
            presenter: SettingsActionPresenter(router: SettingsRouter())
        )
        let troubleshootingID = SettingsRootSection.troubleshooting.rawValue * 10
        let aboutID = SettingsRootSection.about.rawValue * 10
        let advancedID = SettingsRootSection.advanced.rawValue * 10
        let troubleshootingIndex = try XCTUnwrap(sections.firstIndex { $0.id == troubleshootingID })
        let aboutIndex = try XCTUnwrap(sections.firstIndex { $0.id == aboutID })
        let advancedIndex = try XCTUnwrap(sections.firstIndex { $0.id == advancedID })

        XCTAssertLessThan(troubleshootingIndex, aboutIndex)
        XCTAssertLessThan(aboutIndex, advancedIndex)
        XCTAssertFalse(sections.contains { $0.id == troubleshootingID + 1 })

        let activityLogSection = sections[troubleshootingIndex].section()
        XCTAssertEqual(activityLogSection.title, Texts_SettingsView.troubleshootingTitle)
        XCTAssertEqual(activityLogSection.iconSymbolName, ConstantsSettingsIcons.troubleshootingSettingsIcon)
        XCTAssertEqual(activityLogSection.rows.map(\.id), ["trace.troubleshootingLog"])
        XCTAssertEqual(activityLogSection.rows.first?.title, Texts_SettingsView.viewActivityLog)
        XCTAssertNil(activityLogSection.footer)

        let advancedSectionModel = try XCTUnwrap(sections.first { $0.id == advancedID })
        let advancedSection = advancedSectionModel.section()
        XCTAssertEqual(
            advancedSection.rows.filter(\.isVisible).map(\.id),
            ["developer.showDeveloperSettings"]
        )

        UserDefaults.standard.showDeveloperSettings = true
        let revealedAdvancedSection = advancedSectionModel.section()
        let visibleRows = revealedAdvancedSection.rows.filter(\.isVisible)
        XCTAssertEqual(visibleRows.prefix(2).map(\.id), [
            "developer.showDeveloperSettings",
            "developer.issueReport"
        ])

        let issueReportRow = try XCTUnwrap(visibleRows.first { $0.id == "developer.issueReport" })
        XCTAssertEqual(issueReportRow.title, Texts_SettingsView.issueReportTitle)
        guard case let .settingsScreen(makeScreen)? = issueReportRow.action else {
            return XCTFail("Issue Report must open a child Settings screen")
        }

        let issueReportScreen = makeScreen()
        XCTAssertEqual(issueReportScreen.title, Texts_SettingsView.issueReportTitle)
        let reportSections = issueReportScreen.makeSections(SettingsActionPresenter(router: SettingsRouter()))
        XCTAssertEqual(reportSections.count, 1)
        let reportSection = try XCTUnwrap(reportSections.first?.section())
        XCTAssertNil(reportSection.title)
        XCTAssertEqual(reportSection.rows.map(\.id), ["trace.debugLevel", "trace.sendTraceFile"])
        XCTAssertEqual(reportSection.footer, Texts_SettingsView.issueReportSectionFooter)
    }

    func testTwentyFourHourRetentionRemovesOnlyOlderEntries() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(.app(.started), timestamp: referenceDate.addingTimeInterval(-24 * 60 * 60 - 1)))
        fixture.store.record(.standard(.app(.terminated), timestamp: referenceDate.addingTimeInterval(-24 * 60 * 60)))
        fixture.store.record(.standard(.app(.started), timestamp: referenceDate))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [.app(.started), .app(.terminated)])
    }

    func testProductionCapsFitOneDayOfHeartbeatsAndOneMinuteReadings() throws {
        XCTAssertEqual(TroubleshootingLogStore.retentionPeriod, 24 * 60 * 60)
        XCTAssertEqual(TroubleshootingLogStore.maximumEntryCount, 5_000)
        XCTAssertEqual(TroubleshootingLogStore.maximumFileSize, 1_024 * 1_024)

        let heartbeats = (0 ..< 2_880).map { offset in
            TroubleshootingLogEntry.standard(
                .heartbeatReceived,
                timestamp: referenceDate.addingTimeInterval(TimeInterval(offset * 30))
            )
        }
        let readings = (0 ..< 1_440).map { offset in
            let timestamp = referenceDate.addingTimeInterval(TimeInterval(offset * 60))
            return TroubleshootingLogEntry.standard(
                .glucoseAccepted(mgDl: 100, source: .nightscout, measuredAt: timestamp),
                timestamp: timestamp
            )
        }
        let encodedByteCount = try (heartbeats + readings).reduce(into: 0) { byteCount, entry in
            byteCount += try JSONEncoder.troubleshooting.encode(entry).count + 1
        }

        XCTAssertLessThan(heartbeats.count + readings.count, TroubleshootingLogStore.maximumEntryCount)
        XCTAssertLessThan(encodedByteCount, TroubleshootingLogStore.maximumFileSize)
    }

    func testEveryProcessLaunchIsRetainedWithoutRequiringTerminationCallback() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        // A force-close, jetsam or suspended-process eviction commonly has no termination callback.
        // `Trace.initialize` still emits exactly one start in the replacement process, and both
        // launches must remain visible so a reading gap cannot look like one uninterrupted session.
        fixture.store.record(.standard(.app(.started), timestamp: referenceDate))
        fixture.store.record(.standard(.app(.started), timestamp: referenceDate.addingTimeInterval(1)))
        fixture.store.record(.standard(.app(.terminated), timestamp: referenceDate.addingTimeInterval(60)))
        fixture.store.record(.standard(.app(.terminated), timestamp: referenceDate.addingTimeInterval(61)))
        fixture.store.record(.standard(.app(.started), timestamp: referenceDate.addingTimeInterval(120)))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .app(.started),
            .app(.terminated),
            .app(.started),
            .app(.started)
        ])
    }

    func testBluetoothKeepsOnlyMeaningfulFailureAndReconnection() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        // A direct CGM's normal radio cycle may connect and disconnect for every reading. Those
        // healthy transitions must not crowd out glucose values, while an actual failure and the
        // first connection that proves recovery must remain together.
        fixture.store.record(.detailed(.bluetooth(.disconnected), timestamp: referenceDate))
        fixture.store.record(.standard(.bluetooth(.connected), timestamp: referenceDate.addingTimeInterval(1)))
        fixture.store.record(.standard(.bluetooth(.connectionFailed), timestamp: referenceDate.addingTimeInterval(2)))
        fixture.store.record(.standard(.bluetooth(.connectionFailed), timestamp: referenceDate.addingTimeInterval(3)))
        fixture.store.record(.standard(.bluetooth(.connected), timestamp: referenceDate.addingTimeInterval(4)))
        fixture.store.record(.standard(.bluetooth(.connected), timestamp: referenceDate.addingTimeInterval(5)))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .bluetooth(.connectionRestored),
            .bluetooth(.connectionFailed)
        ])
    }

    func testNamedBluetoothDiscoveryMilestonesAreRetainedWithoutRoutineConnectionChurn() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        let addedName = try XCTUnwrap(TroubleshootingBluetoothDeviceName("  L3-HeartBeat\nDevice  "))
        let existingName = try XCTUnwrap(TroubleshootingBluetoothDeviceName("DXCM12"))

        fixture.store.record(.standard(
            .bluetoothDevice(name: addedName, activity: .added),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .bluetoothDevice(name: addedName, activity: .connected),
            timestamp: referenceDate.addingTimeInterval(1)
        ))
        fixture.store.record(.detailed(
            .bluetooth(.disconnected),
            timestamp: referenceDate.addingTimeInterval(2)
        ))
        fixture.store.record(.standard(
            .bluetoothDevice(name: existingName, activity: .reconnectedToExisting),
            timestamp: referenceDate.addingTimeInterval(3)
        ))

        let entries = fixture.store.snapshot()
        let report = makeReport(entries: entries)

        XCTAssertEqual(entries.map(report.message(for:)), [
            "Reconnected to existing Bluetooth device: DXCM12.",
            "Added new Bluetooth device: L3-HeartBeat Device."
        ])
    }

    func testNamedBluetoothRecoveryIsKeptOnlyAfterFailure() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        let heartbeatName = try XCTUnwrap(TroubleshootingBluetoothDeviceName("L3-HeartBeat"))

        fixture.store.record(.standard(
            .bluetoothDevice(name: heartbeatName, activity: .connected),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .bluetooth(.connectionFailed),
            timestamp: referenceDate.addingTimeInterval(1)
        ))
        fixture.store.record(.standard(
            .bluetoothDevice(name: heartbeatName, activity: .connected),
            timestamp: referenceDate.addingTimeInterval(2)
        ))
        fixture.store.record(.standard(
            .bluetoothDevice(name: heartbeatName, activity: .connected),
            timestamp: referenceDate.addingTimeInterval(3)
        ))

        let entries = fixture.store.snapshot()
        let report = makeReport(entries: entries)

        XCTAssertEqual(entries.map(report.message(for:)), [
            "Reconnected to existing Bluetooth device: L3-HeartBeat.",
            "Bluetooth could not connect and will try again."
        ])
    }

    func testNamedBluetoothUserLifecycleActionsAreRetainedWithOneConnectionOutcome() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        let heartbeatName = try XCTUnwrap(TroubleshootingBluetoothDeviceName("L3-HeartBeat"))

        fixture.store.record(.standard(
            .bluetoothDevice(name: heartbeatName, activity: .connectionRequested),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .bluetoothDevice(name: heartbeatName, activity: .connected),
            timestamp: referenceDate.addingTimeInterval(1)
        ))
        // The next healthy radio cycle is automatic and must not create another row.
        fixture.store.record(.standard(
            .bluetoothDevice(name: heartbeatName, activity: .connected),
            timestamp: referenceDate.addingTimeInterval(2)
        ))
        fixture.store.record(.standard(
            .bluetoothDevice(name: heartbeatName, activity: .disconnected),
            timestamp: referenceDate.addingTimeInterval(3)
        ))
        fixture.store.record(.standard(
            .bluetoothDevice(name: heartbeatName, activity: .removed),
            timestamp: referenceDate.addingTimeInterval(4)
        ))

        let entries = fixture.store.snapshot()
        let report = makeReport(entries: entries)

        XCTAssertEqual(entries.map(report.message(for:)), [
            "Removed Bluetooth device: L3-HeartBeat.",
            "Disconnected Bluetooth device: L3-HeartBeat.",
            "Bluetooth connected to device: L3-HeartBeat.",
            "Connection requested for Bluetooth device: L3-HeartBeat."
        ])
    }

    func testNamedConnectionOutcomeMustMatchTheUserRequestedDevice() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        let requestedName = try XCTUnwrap(TroubleshootingBluetoothDeviceName("L3-HeartBeat"))
        let unrelatedName = try XCTUnwrap(TroubleshootingBluetoothDeviceName("M5Stack"))

        fixture.store.record(.standard(
            .bluetoothDevice(name: requestedName, activity: .connectionRequested),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .bluetoothDevice(name: unrelatedName, activity: .connected),
            timestamp: referenceDate.addingTimeInterval(1)
        ))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .bluetoothDevice(name: requestedName, activity: .connectionRequested)
        ])
    }

    func testBluetoothDeviceNameIsBoundedForSharedReports() throws {
        let name = try XCTUnwrap(TroubleshootingBluetoothDeviceName(String(repeating: "A", count: 100)))

        XCTAssertEqual(name.value.count, TroubleshootingBluetoothDeviceName.maximumLength)
        XCTAssertNil(TroubleshootingBluetoothDeviceName(" \n\t "))
    }

    func testManualSensorStartAndTransmitterAcknowledgementProduceOneStartRow() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(.sensor(.started), timestamp: referenceDate))
        fixture.store.record(.standard(
            .sensor(.detected),
            timestamp: referenceDate.addingTimeInterval(1)
        ))
        fixture.store.record(.standard(
            .sensor(.stopped),
            timestamp: referenceDate.addingTimeInterval(2)
        ))
        fixture.store.record(.standard(
            .sensor(.stopped),
            timestamp: referenceDate.addingTimeInterval(3)
        ))

        let entries = fixture.store.snapshot()
        XCTAssertEqual(entries.map(\.kind), [
            .sensor(.stopped),
            .sensor(.started)
        ])
        let report = makeReport(entries: entries)
        XCTAssertEqual(entries.map(report.message(for:)), [
            "The sensor session stopped.",
            "A sensor session started."
        ])
    }

    func testSensorStartActivityRetainsSubmittedCode() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(
            .sensor(.startedWithCode(sensorCode: "0000")),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .sensor(.detected),
            timestamp: referenceDate.addingTimeInterval(1)
        ))

        let entries = fixture.store.snapshot()
        XCTAssertEqual(entries.map(\.kind), [
            .sensor(.startedWithCode(sensorCode: "0000"))
        ])

        let report = makeReport(entries: entries)
        XCTAssertEqual(
            entries.map(report.message(for:)),
            ["A sensor session started with sensor code 0000."]
        )

        let storedText = String(decoding: try Data(contentsOf: fixture.fileURL), as: UTF8.self)
        XCTAssertTrue(storedText.contains("0000"))
        XCTAssertTrue(report.reportText.contains("0000"))
    }

    func testSensorLabelScanActivityRetainsDecodedInformationAndFailures() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(.sensorLabelScan(.succeeded(
            source: .camera,
            sensorCode: "5937",
            lotNumber: "5336121",
            serialNumber: "821184A"
        )), timestamp: referenceDate))
        fixture.store.record(.standard(
            .sensorLabelScan(.failed(source: .photo, reason: .noValidLabel)),
            timestamp: referenceDate.addingTimeInterval(1)
        ))

        let entries = fixture.store.snapshot()
        let report = makeReport(entries: entries)
        XCTAssertEqual(entries.map(\.kind), [
            .sensorLabelScan(.failed(source: .photo, reason: .noValidLabel)),
            .sensorLabelScan(.succeeded(
                source: .camera,
                sensorCode: "5937",
                lotNumber: "5336121",
                serialNumber: "821184A"
            ))
        ])
        XCTAssertEqual(entries.map(report.message(for:)), [
            "Dexcom G6 sensor label photo scan failed: no valid sensor label found.",
            "Dexcom G6 sensor label camera scan succeeded: sensor code 5937, lot 5336121, serial 821184A."
        ])

        let storedText = String(decoding: try Data(contentsOf: fixture.fileURL), as: UTF8.self)
        let sharedText = report.reportText
        for decodedValue in ["5937", "5336121", "821184A"] {
            XCTAssertTrue(storedText.contains(decodedValue))
            XCTAssertTrue(sharedText.contains(decodedValue))
        }
    }

    func testCGMUserActionsKeepOneConnectionOutcomeWithoutRoutineRadioChurn() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(.cgm(source: .dexcomG6, activity: .addingStarted), timestamp: referenceDate))
        // An unrelated Bluetooth peripheral must not complete a pending Add CGM action.
        fixture.store.record(.standard(.bluetooth(.connected), timestamp: referenceDate.addingTimeInterval(1)))
        fixture.store.record(.standard(.cgm(source: .dexcomG6, activity: .connected), timestamp: referenceDate.addingTimeInterval(2)))
        // Healthy Dexcom-style connections between readings are offered but discarded.
        fixture.store.record(.standard(.cgm(source: .dexcomG6, activity: .connected), timestamp: referenceDate.addingTimeInterval(3)))
        fixture.store.record(.standard(.cgm(source: .dexcomG6, activity: .disconnected), timestamp: referenceDate.addingTimeInterval(4)))
        fixture.store.record(.standard(.cgm(source: .dexcomG6, activity: .connectionRequested), timestamp: referenceDate.addingTimeInterval(5)))
        fixture.store.record(.standard(.bluetooth(.connectionFailed), timestamp: referenceDate.addingTimeInterval(6)))
        fixture.store.record(.standard(.cgm(source: .dexcomG6, activity: .connected), timestamp: referenceDate.addingTimeInterval(7)))
        fixture.store.record(.standard(.cgm(source: .dexcomG6, activity: .connected), timestamp: referenceDate.addingTimeInterval(8)))
        fixture.store.record(.standard(.cgm(source: .dexcomG6, activity: .removed), timestamp: referenceDate.addingTimeInterval(9)))

        let entries = fixture.store.snapshot()
        XCTAssertEqual(entries.map(\.kind), [
            .cgm(source: .dexcomG6, activity: .removed),
            .cgm(source: .dexcomG6, activity: .connected),
            .bluetooth(.connectionFailed),
            .cgm(source: .dexcomG6, activity: .connectionRequested),
            .cgm(source: .dexcomG6, activity: .disconnected),
            .cgm(source: .dexcomG6, activity: .connected),
            .cgm(source: .dexcomG6, activity: .addingStarted)
        ])

        let report = makeReport(entries: entries, usesMgDl: true)
        XCTAssertEqual(entries.map(report.message(for:)), [
            "Dexcom G6 was removed.",
            "Dexcom G6 connected.",
            "Bluetooth could not connect and will try again.",
            "Reconnect requested for Dexcom G6.",
            "Dexcom G6 was disconnected.",
            "Dexcom G6 connected.",
            "Started adding Dexcom G6."
        ])

        // Only a whitelisted family is persisted. The setup transmitter ID is used as a selector
        // and can never enter the JSON-lines report itself.
        XCTAssertEqual(
            TroubleshootingLogSource(bluetoothPeripheralType: .DexcomType, transmitterID: "8SECRET"),
            .dexcomG6
        )
        XCTAssertEqual(
            TroubleshootingLogSource(bluetoothPeripheralType: .Libre2Type),
            .libre2
        )
        let json = String(
            decoding: try JSONEncoder.troubleshooting.encode(XCTUnwrap(entries.last)),
            as: UTF8.self
        )
        XCTAssertFalse(json.contains("8SECRET"))
    }

    func testNFCAndPairingOutcomesDescribeWhatActuallyHappened() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(.cgm(source: .libre2, activity: .nfcScanStarted), timestamp: referenceDate))
        fixture.store.record(.standard(.cgm(source: .libre2, activity: .nfcScanTimedOut), timestamp: referenceDate.addingTimeInterval(1)))
        fixture.store.record(.standard(.cgm(source: .libre2, activity: .nfcScanStarted), timestamp: referenceDate.addingTimeInterval(2)))
        fixture.store.record(.standard(.cgm(source: .libre2, activity: .nfcScanCancelled), timestamp: referenceDate.addingTimeInterval(3)))
        fixture.store.record(.standard(.cgm(source: .libre2, activity: .nfcScanStarted), timestamp: referenceDate.addingTimeInterval(4)))
        fixture.store.record(.standard(.cgm(source: .libre2, activity: .nfcScanFailed), timestamp: referenceDate.addingTimeInterval(5)))
        fixture.store.record(.standard(.cgm(source: .libre2, activity: .nfcScanStarted), timestamp: referenceDate.addingTimeInterval(6)))
        fixture.store.record(.standard(.cgm(source: .libre2, activity: .nfcScanSucceeded), timestamp: referenceDate.addingTimeInterval(7)))
        fixture.store.record(.standard(.bluetooth(.pairingRequested), timestamp: referenceDate.addingTimeInterval(8)))
        fixture.store.record(.standard(.bluetooth(.pairingRequested), timestamp: referenceDate.addingTimeInterval(9)))
        fixture.store.record(.standard(.bluetooth(.pairingFailed), timestamp: referenceDate.addingTimeInterval(10)))
        fixture.store.record(.standard(.bluetooth(.pairingSucceeded), timestamp: referenceDate.addingTimeInterval(11)))

        let entries = fixture.store.snapshot()
        let report = makeReport(entries: entries, usesMgDl: true)
        XCTAssertEqual(entries.map(report.message(for:)), [
            "The CGM transmitter paired successfully.",
            "The CGM transmitter did not complete Bluetooth pairing.",
            "The CGM transmitter requested Bluetooth pairing.",
            "The CGM transmitter requested Bluetooth pairing.",
            "Libre 2/2+ EU NFC sensor scan succeeded.",
            "Libre 2/2+ EU NFC sensor scan started.",
            "Libre 2/2+ EU NFC sensor scan failed.",
            "Libre 2/2+ EU NFC sensor scan started.",
            "Libre 2/2+ EU NFC sensor scan was cancelled.",
            "Libre 2/2+ EU NFC sensor scan started.",
            "Libre 2/2+ EU NFC sensor scan timed out.",
            "Libre 2/2+ EU NFC sensor scan started."
        ])
    }

    func testUnsuccessfulNFCScanCannotCompleteLaterWithAnUnrelatedConnection() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(
            .cgm(source: .libre2, activity: .addingStarted),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .cgm(source: .libre2, activity: .nfcScanStarted),
            timestamp: referenceDate.addingTimeInterval(1)
        ))
        fixture.store.record(.standard(
            .cgm(source: .libre2, activity: .nfcScanFailed),
            timestamp: referenceDate.addingTimeInterval(2)
        ))

        // A failed/cancelled/timed-out NFC session ends the pending Libre attempt. If another
        // transmitter connects later, that routine callback must not become "Libre connected."
        fixture.store.record(.standard(
            .cgm(source: .dexcomG7, activity: .connected),
            timestamp: referenceDate.addingTimeInterval(3)
        ))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .cgm(source: .libre2, activity: .nfcScanFailed),
            .cgm(source: .libre2, activity: .nfcScanStarted),
            .cgm(source: .libre2, activity: .addingStarted)
        ])
    }

    func testCountLimitKeepsNewestEntries() {
        let fixture = makeStore(maximumEntryCount: 3)
        defer { removeFixture(fixture.directory) }

        for offset in 0 ..< 8 {
            let timestamp = referenceDate.addingTimeInterval(TimeInterval(offset))
            fixture.store.record(.standard(.glucoseAccepted(
                mgDl: Double(100 + offset),
                source: .dexcomG6,
                measuredAt: timestamp
            ), timestamp: timestamp))
        }

        let values = fixture.store.snapshot().compactMap { entry -> Double? in
            guard case let .glucoseAccepted(mgDl, _, _) = entry.kind else { return nil }
            return mgDl
        }
        XCTAssertEqual(values, [107, 106, 105])
    }

    func testSizeLimitKeepsNewestCompleteJSONLines() throws {
        let fixture = makeStore(maximumFileSize: 700)
        defer { removeFixture(fixture.directory) }

        for offset in 0 ..< 20 {
            let timestamp = referenceDate.addingTimeInterval(TimeInterval(offset))
            fixture.store.record(.standard(.glucoseAccepted(
                mgDl: Double(100 + offset),
                source: .dexcomG6,
                measuredAt: timestamp
            ), timestamp: timestamp))
        }

        let entries = fixture.store.snapshot()
        let data = try Data(contentsOf: fixture.fileURL)
        XCTAssertLessThanOrEqual(data.count, 700)
        XCTAssertLessThan(entries.count, 20)
        XCTAssertEqual(entries.first?.kind, .glucoseAccepted(
            mgDl: 119,
            source: .dexcomG6,
            measuredAt: referenceDate.addingTimeInterval(19)
        ))
        XCTAssertNoThrow(try JSONDecoder.troubleshooting.decode(
            TroubleshootingLogEntry.self,
            from: XCTUnwrap(data.split(separator: 0x0A).first).data
        ))
    }

    func testConcurrentWritesAreSerializedWithoutLosingEntries() {
        let fixture = makeStore(maximumEntryCount: 2_000, maximumFileSize: 256 * 1_024)
        defer { removeFixture(fixture.directory) }

        DispatchQueue.concurrentPerform(iterations: 250) { index in
            fixture.store.record(.standard(.glucoseAccepted(
                mgDl: Double(index),
                source: .dexcomG6,
                measuredAt: referenceDate
            ), timestamp: referenceDate))
        }

        XCTAssertEqual(fixture.store.snapshot().count, 250)
    }

    func testEveryAcceptedReadingIsRetainedWithoutTimeSuppression() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        for minute in 0 ..< 30 {
            let timestamp = referenceDate.addingTimeInterval(TimeInterval(minute * 60))
            fixture.store.record(.standard(.glucoseAccepted(
                mgDl: Double(100 + minute),
                source: .nightscout,
                measuredAt: timestamp
            ), timestamp: timestamp))
        }

        XCTAssertEqual(fixture.store.snapshot().count, 30)
    }

    func testIndividualGlucoseChangesAndDeletionsAreRetainedAndUseMeasurementTime() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }
        let measurementTime = referenceDate.addingTimeInterval(-10 * 60)

        // A reading can be changed and then deleted. Both explicit user actions remain useful and
        // must not be collapsed merely because they refer to the same measurement timestamp.
        fixture.store.record(.standard(
            .glucoseManagement(.changed(
                previousMgDl: 90,
                updatedMgDl: 108,
                measuredAt: measurementTime
            )),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .glucoseManagement(.deleted(mgDl: 108, measuredAt: measurementTime)),
            timestamp: referenceDate.addingTimeInterval(60)
        ))

        let entries = fixture.store.snapshot()
        let mgDlReport = makeReport(entries: entries, usesMgDl: true)
        let mmolReport = makeReport(entries: entries, usesMgDl: false)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.map(mgDlReport.message(for:)), [
            "Reading deleted: 108 mg/dL at 07:50:00.",
            "Reading changed from 90 mg/dL to 108 mg/dL at 07:50:00."
        ])
        XCTAssertEqual(entries.map(mmolReport.message(for:)), [
            "Reading deleted: 6.0 mmol/L at 07:50:00.",
            "Reading changed from 5.0 mmol/L to 6.0 mmol/L at 07:50:00."
        ])

        // The persistence boundary accepts only values and a Date. It cannot absorb a Core Data
        // object ID, a Nightscout identifier or arbitrary developer-trace text.
        let encoded = try entries.map { try JSONEncoder.troubleshooting.encode($0) }
        for data in encoded {
            let json = String(decoding: data, as: UTF8.self)
            XCTAssertFalse(json.contains("private-reading-id"))
            XCTAssertFalse(json.contains("https://example.com"))
        }
    }

    func testTreatmentActionsRetainOnlyTypeAndTreatmentTime() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }
        let treatmentTime = referenceDate.addingTimeInterval(-10 * 60)

        fixture.store.record(.standard(
            .treatment(.added(kind: .insulin, treatmentAt: treatmentTime)),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .treatment(.edited(kind: .carbohydrates, treatmentAt: treatmentTime)),
            timestamp: referenceDate.addingTimeInterval(1)
        ))
        fixture.store.record(.standard(
            .treatment(.deleted(kind: .note, treatmentAt: treatmentTime)),
            timestamp: referenceDate.addingTimeInterval(2)
        ))

        let entries = fixture.store.snapshot()
        let report = makeReport(entries: entries, usesMgDl: true)
        XCTAssertEqual(entries.map(report.message(for:)), [
            "Note treatment deleted at 07:50:00.",
            "Carbohydrate treatment edited at 07:50:00.",
            "Insulin treatment added at 07:50:00."
        ])

        // The typed payload has no field capable of storing dose, carbohydrate amount, free-form
        // notes, entered-by names or Nightscout identifiers.
        let json = try entries.map {
            String(decoding: try JSONEncoder.troubleshooting.encode($0), as: UTF8.self)
        }.joined(separator: "\n")
        XCTAssertFalse(json.contains("private note"))
        XCTAssertFalse(json.contains("enteredBy"))
        XCTAssertFalse(json.contains("nightscout"))
        XCTAssertFalse(json.contains("dose"))
    }

    func testEveryHeartbeatIsRetainedWithoutSuppression() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        for offset in 0 ..< 12 {
            fixture.store.record(.standard(
                .heartbeatReceived,
                timestamp: referenceDate.addingTimeInterval(TimeInterval(offset * 30))
            ))
        }

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), Array(repeating: .heartbeatReceived, count: 12))
    }

    func testAuthenticationMilestonesRemainUsefulWithoutRepeatingSessionChecks() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(.follower(source: .careLink, activity: .loginStarted), timestamp: referenceDate))
        fixture.store.record(.standard(.follower(source: .careLink, activity: .loginStarted), timestamp: referenceDate.addingTimeInterval(1)))
        fixture.store.record(.standard(.follower(source: .careLink, activity: .loginSucceeded), timestamp: referenceDate.addingTimeInterval(2)))
        fixture.store.record(.detailed(.follower(source: .careLink, activity: .loginSucceeded), timestamp: referenceDate.addingTimeInterval(3)))
        fixture.store.record(.standard(.follower(source: .careLink, activity: .loggedOut), timestamp: referenceDate.addingTimeInterval(4)))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .follower(source: .careLink, activity: .loggedOut),
            .follower(source: .careLink, activity: .loginSucceeded),
            .follower(source: .careLink, activity: .loginStarted)
        ])
    }

    func testRoutineFollowerPollingDoesNotEnterTheUsefulHistory() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        for offset in 0 ..< 20 {
            let timestamp = referenceDate.addingTimeInterval(TimeInterval(offset * 15))
            fixture.store.record(.detailed(
                .follower(source: .nightscout, activity: .downloadStarted),
                timestamp: timestamp
            ))
            fixture.store.record(.standard(
                .follower(source: .nightscout, activity: .downloadSucceeded(readingCount: 1)),
                timestamp: timestamp
            ))
        }

        XCTAssertTrue(fixture.store.snapshot().isEmpty)
    }

    func testReloadRemovesPreviouslyPersistedRoutinePolling() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)

        // Simulate a file written by the first implementation, before routine successful polls were
        // suppressed. Reload must migrate it in place so the user does not need to wait 24 hours for
        // the unhelpful "returned 1 reading" rows to age out.
        let oldEntries = [
            TroubleshootingLogEntry.standard(
                .follower(source: .nightscout, activity: .downloadSucceeded(readingCount: 1)),
                timestamp: referenceDate.addingTimeInterval(-15)
            ),
            TroubleshootingLogEntry.standard(
                .glucoseAccepted(mgDl: 95, source: .nightscout, measuredAt: referenceDate),
                timestamp: referenceDate
            )
        ]
        let oldLines = try oldEntries.map {
            String(decoding: try JSONEncoder.troubleshooting.encode($0), as: UTF8.self)
        }
        // Reproduce the legacy writer exactly: each newline was followed by a null byte. The next
        // JSON record therefore began with null padding when the file was split into lines.
        let oldFile = Data((oldLines.joined(separator: "\n\0") + "\n\0").utf8)
        try oldFile.write(to: fixture.fileURL)
        XCTAssertEqual(try Data(contentsOf: fixture.fileURL).split(separator: 0x0A).count, 3)

        XCTAssertEqual(
            fixture.store.snapshot().map(\.kind),
            [.glucoseAccepted(mgDl: 95, source: .nightscout, measuredAt: referenceDate)]
        )
        let repairedFile = try Data(contentsOf: fixture.fileURL)
        XCTAssertEqual(repairedFile.split(separator: 0x0A).count, 1)
        XCTAssertFalse(repairedFile.contains(0))
    }

    func testReloadPreservesMultipleCompleteRecords() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(.app(.started), timestamp: referenceDate.addingTimeInterval(-1)))
        fixture.store.record(.standard(
            .glucoseAccepted(mgDl: 101, source: .dexcomG6, measuredAt: referenceDate),
            timestamp: referenceDate
        ))
        XCTAssertEqual(fixture.store.snapshot().count, 2)

        let reloadedStore = TroubleshootingLogStore(fileURL: fixture.fileURL, now: { self.referenceDate })
        XCTAssertEqual(reloadedStore.snapshot().map(\.kind), [
            .glucoseAccepted(mgDl: 101, source: .dexcomG6, measuredAt: referenceDate),
            .app(.started)
        ])
    }

    func testFollowerProblemIsCollapsedAndFollowedByOneRecovery() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(
            .follower(source: .nightscout, activity: .downloadFailed),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .follower(source: .nightscout, activity: .downloadFailed),
            timestamp: referenceDate.addingTimeInterval(15)
        ))
        fixture.store.record(.standard(
            .follower(source: .nightscout, activity: .downloadSucceeded(readingCount: 1)),
            timestamp: referenceDate.addingTimeInterval(30)
        ))
        fixture.store.record(.standard(
            .follower(source: .nightscout, activity: .downloadSucceeded(readingCount: 1)),
            timestamp: referenceDate.addingTimeInterval(45)
        ))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .follower(source: .nightscout, activity: .recovered),
            .follower(source: .nightscout, activity: .downloadFailed)
        ])
    }

    func testAcceptedFollowerReadingProvesRecoveryWithoutUsingItsMeasurementTimeForOrdering() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }
        let measurementTime = referenceDate.addingTimeInterval(60)
        let recordedTime = referenceDate.addingTimeInterval(120)

        fixture.store.record(.standard(
            .follower(source: .nightscout, activity: .downloadFailed),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .glucoseAccepted(mgDl: 123, source: .nightscout, measuredAt: measurementTime),
            timestamp: recordedTime
        ))

        let entries = fixture.store.snapshot()
        XCTAssertEqual(entries.map(\.kind), [
            .glucoseAccepted(mgDl: 123, source: .nightscout, measuredAt: measurementTime),
            .follower(source: .nightscout, activity: .recovered),
            .follower(source: .nightscout, activity: .downloadFailed)
        ])
        XCTAssertEqual(entries[0].timestamp, recordedTime)
    }

    func testIntegrationKeepsHourlySuccessAndImmediateFailureRecovery() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.detailed(
            .integration(name: .healthKit, activity: .succeeded(itemCount: 1)),
            timestamp: referenceDate
        ))
        fixture.store.record(.detailed(
            .integration(name: .healthKit, activity: .failed),
            timestamp: referenceDate.addingTimeInterval(1)
        ))
        fixture.store.record(.detailed(
            .integration(name: .healthKit, activity: .failed),
            timestamp: referenceDate.addingTimeInterval(2)
        ))
        fixture.store.record(.detailed(
            .integration(name: .healthKit, activity: .succeeded(itemCount: 1)),
            timestamp: referenceDate.addingTimeInterval(3)
        ))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .integration(name: .healthKit, activity: .recovered),
            .integration(name: .healthKit, activity: .failed),
            .integration(name: .healthKit, activity: .succeeded(itemCount: 1))
        ])
    }

    func testRoutineIntegrationSuccessIsLimitedToOnePerHour() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.detailed(
            .integration(name: .calendar, activity: .succeeded(itemCount: 1)),
            timestamp: referenceDate
        ))
        fixture.store.record(.detailed(
            .integration(name: .calendar, activity: .succeeded(itemCount: 2)),
            timestamp: referenceDate.addingTimeInterval(30 * 60)
        ))
        fixture.store.record(.detailed(
            .integration(name: .calendar, activity: .succeeded(itemCount: 3)),
            timestamp: referenceDate.addingTimeInterval(60 * 60)
        ))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .integration(name: .calendar, activity: .succeeded(itemCount: 3)),
            .integration(name: .calendar, activity: .succeeded(itemCount: 1))
        ])
    }

    func testAppleWatchFailureIsRetainedWithoutRoutineSuccessNoise() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.detailed(
            .integration(name: .watch, activity: .failed),
            timestamp: referenceDate
        ))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .integration(name: .watch, activity: .failed)
        ])
    }

    func testAppleHealthPermissionMessageExplainsEnabledState() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.detailed(
            .integration(name: .healthKit, activity: .permissionDenied),
            timestamp: referenceDate
        ))

        let entry = try XCTUnwrap(fixture.store.snapshot().first)
        XCTAssertEqual(
            makeReport(entries: [entry]).message(for: entry),
            "Apple Health is enabled, but permission has not been granted."
        )
    }

    func testContactImageSuccessHasCustomerFacingMessage() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.detailed(
            .integration(name: .contactImage, activity: .succeeded(itemCount: nil)),
            timestamp: referenceDate
        ))

        let entry = try XCTUnwrap(fixture.store.snapshot().first)
        XCTAssertEqual(makeReport(entries: [entry]).message(for: entry), "Contact Image updated successfully.")
    }

    func testReadingUsesRecordingTimeForOrderAndShowsMeasurementTimeInMessage() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }
        let measurementTime = referenceDate.addingTimeInterval(-10 * 60)
        let loginTime = referenceDate.addingTimeInterval(-2)
        let recordedTime = referenceDate
        fixture.store.record(.standard(
            .follower(source: .careLink, activity: .loginSucceeded),
            timestamp: loginTime
        ))
        fixture.store.record(.standard(
            .glucoseAccepted(mgDl: 75, source: .careLink, measuredAt: measurementTime),
            timestamp: recordedTime
        ))

        let entries = fixture.store.snapshot()
        let report = makeReport(entries: entries, timeZone: .gmt)

        XCTAssertEqual(entries[0].timestamp, recordedTime)
        XCTAssertEqual(
            report.message(for: entries[0]),
            "New reading: 75 mg/dL at 07:50:00."
        )
        XCTAssertTrue(report.reportText.contains(
            "08:00:00  New reading: 75 mg/dL at 07:50:00."
        ))
        let readingRange = try XCTUnwrap(report.reportText.range(of: "New reading:"))
        let loginRange = try XCTUnwrap(report.reportText.range(of: "CareLink signed in successfully."))
        XCTAssertLessThan(readingRange.lowerBound, loginRange.lowerBound)
    }

    func testNightscoutBackfillSummaryIsRetainedBecauseItExplainsHistoricalReadings() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.detailed(
            .integration(name: .nightscoutBackfill, activity: .started),
            timestamp: referenceDate
        ))
        fixture.store.record(.detailed(
            .integration(name: .nightscoutBackfill, activity: .succeeded(itemCount: 14)),
            timestamp: referenceDate.addingTimeInterval(1)
        ))

        let entries = fixture.store.snapshot()
        XCTAssertEqual(entries.map(\.kind), [
            .integration(name: .nightscoutBackfill, activity: .succeeded(itemCount: 14))
        ])
        XCTAssertEqual(
            makeReport(entries: entries).message(for: try XCTUnwrap(entries.first)),
            "Nightscout restored 14 missing glucose readings."
        )
    }

    func testNoOpNightscoutBackfillRemovesItsRoutineBookends() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)

        // Write the pair directly to reproduce a history created by the earlier policy. Reloading
        // must clean existing user files, not merely avoid adding noisy pairs in future sessions.
        let oldEntries = [
            TroubleshootingLogEntry.detailed(
                .integration(name: .nightscoutBackfill, activity: .started),
                timestamp: referenceDate
            ),
            TroubleshootingLogEntry.detailed(
                .integration(name: .nightscoutBackfill, activity: .noData),
                timestamp: referenceDate.addingTimeInterval(1)
            )
        ]
        let oldFile = try oldEntries.reduce(into: Data()) { data, entry in
            data.append(try JSONEncoder.troubleshooting.encode(entry))
            data.append(UInt8(0x0A))
        }
        try oldFile.write(to: fixture.fileURL)

        XCTAssertTrue(fixture.store.snapshot().isEmpty)
        XCTAssertTrue(try Data(contentsOf: fixture.fileURL).isEmpty)
    }

    func testNightscoutBackfillFailureAndRecoveryRemainWithoutRoutineBookends() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.detailed(
            .integration(name: .nightscoutBackfill, activity: .started),
            timestamp: referenceDate
        ))
        fixture.store.record(.detailed(
            .integration(name: .nightscoutBackfill, activity: .failed),
            timestamp: referenceDate.addingTimeInterval(1)
        ))
        fixture.store.record(.detailed(
            .integration(name: .nightscoutBackfill, activity: .started),
            timestamp: referenceDate.addingTimeInterval(2)
        ))
        fixture.store.record(.detailed(
            .integration(name: .nightscoutBackfill, activity: .noData),
            timestamp: referenceDate.addingTimeInterval(3)
        ))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .integration(name: .nightscoutBackfill, activity: .recovered),
            .integration(name: .nightscoutBackfill, activity: .failed)
        ])
        let entries = fixture.store.snapshot()
        XCTAssertEqual(makeReport(entries: entries).message(for: entries[0]), "Nightscout can check for missing readings again.")
        XCTAssertEqual(makeReport(entries: entries).message(for: entries[1]), "Nightscout could not check for missing readings.")
    }

    func testRepeatedAlertEvaluationKeepsOnlyMeaningfulStateChanges() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.high.rawValue,
            activity: .scheduled(minutes: 10)
        ), timestamp: referenceDate))
        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.high.rawValue,
            activity: .scheduled(minutes: 9)
        ), timestamp: referenceDate.addingTimeInterval(60)))
        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.high.rawValue,
            activity: .raised
        ), timestamp: referenceDate.addingTimeInterval(10 * 60)))
        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.high.rawValue,
            activity: .raised
        ), timestamp: referenceDate.addingTimeInterval(11 * 60)))
        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.high.rawValue,
            activity: .snoozed(minutes: 15)
        ), timestamp: referenceDate.addingTimeInterval(12 * 60)))
        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.high.rawValue,
            activity: .notificationDismissed
        ), timestamp: referenceDate.addingTimeInterval(13 * 60)))
        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.high.rawValue,
            activity: .preSnoozed(minutes: 30)
        ), timestamp: referenceDate.addingTimeInterval(14 * 60)))
        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.high.rawValue,
            activity: .suppressedBySnooze
        ), timestamp: referenceDate.addingTimeInterval(15 * 60)))
        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.high.rawValue,
            activity: .suppressedBySnooze
        ), timestamp: referenceDate.addingTimeInterval(16 * 60)))

        XCTAssertEqual(fixture.store.snapshot().map(\.kind), [
            .alert(kindRawValue: AlertKind.high.rawValue, activity: .suppressedBySnooze),
            .alert(kindRawValue: AlertKind.high.rawValue, activity: .preSnoozed(minutes: 30)),
            .alert(kindRawValue: AlertKind.high.rawValue, activity: .notificationDismissed),
            .alert(kindRawValue: AlertKind.high.rawValue, activity: .snoozed(minutes: 15)),
            .alert(kindRawValue: AlertKind.high.rawValue, activity: .raised),
            .alert(kindRawValue: AlertKind.high.rawValue, activity: .scheduled(minutes: 10))
        ])

        let suppressedEntry = fixture.store.snapshot()[0]
        XCTAssertEqual(
            makeReport(entries: [suppressedEntry]).message(for: suppressedEntry),
            "High alert condition was met, but the alert was pre-snoozed."
        )

        let report = makeReport(entries: fixture.store.snapshot())
        XCTAssertEqual(report.message(for: fixture.store.snapshot()[1]), "High alert was pre-snoozed for 30 minutes.")
        XCTAssertEqual(report.message(for: fixture.store.snapshot()[2]), "High alert notification was dismissed.")
        XCTAssertEqual(report.message(for: fixture.store.snapshot()[3]), "High alert was snoozed for 15 minutes.")
    }

    func testNotificationPermissionProblemIsRecordedOnceForAllAlerts() {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.high.rawValue,
            activity: .notificationsDenied
        ), timestamp: referenceDate))
        fixture.store.record(.standard(.alert(
            kindRawValue: AlertKind.low.rawValue,
            activity: .notificationsDenied
        ), timestamp: referenceDate.addingTimeInterval(1)))

        XCTAssertEqual(fixture.store.snapshot().count, 1)
        XCTAssertEqual(
            fixture.store.snapshot().first?.kind,
            .alert(kindRawValue: AlertKind.high.rawValue, activity: .notificationsDenied)
        )
    }

    func testReloadIgnoresAndRepairsMalformedFinalRecord() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(.app(.started), timestamp: referenceDate))
        XCTAssertEqual(fixture.store.snapshot().count, 1)

        let handle = try FileHandle(forWritingTo: fixture.fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"incomplete":true"#.utf8))

        let reloadedStore = TroubleshootingLogStore(fileURL: fixture.fileURL, now: { self.referenceDate })
        XCTAssertEqual(reloadedStore.snapshot().map(\.kind), [.app(.started)])

        let repairedData = try Data(contentsOf: fixture.fileURL)
        XCTAssertFalse(String(decoding: repairedData, as: UTF8.self).contains("incomplete"))
    }

    func testStorageFailureLeavesCurrentSessionSnapshotAvailable() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TroubleshootingLogTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { removeFixture(directory) }

        // A directory cannot be opened as the JSON-lines file. The store deliberately keeps its
        // in-memory snapshot useful and never lets this failure affect the caller of `trace`.
        let store = TroubleshootingLogStore(fileURL: directory, now: { self.referenceDate })
        store.record(.standard(.app(.started), timestamp: referenceDate))

        XCTAssertEqual(store.snapshot().map(\.kind), [.app(.started)])
    }

    func testStorageRecoveryRewritesEntriesRetainedDuringFailure() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TroubleshootingLogTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
        defer { removeFixture(fileURL) }

        // Using a directory as the file forces the first append to fail while the in-memory record
        // remains available. Replacing it with a writable file simulates storage becoming available.
        let store = TroubleshootingLogStore(fileURL: fileURL, now: { self.referenceDate })
        store.record(.standard(.app(.started), timestamp: referenceDate))
        XCTAssertEqual(store.snapshot().map(\.kind), [.app(.started)])

        try FileManager.default.removeItem(at: fileURL)
        try Data().write(to: fileURL, options: .atomic)
        store.record(.standard(.app(.terminated), timestamp: referenceDate.addingTimeInterval(1)))
        XCTAssertEqual(store.snapshot().map(\.kind), [.app(.terminated), .app(.started)])

        let reloadedStore = TroubleshootingLogStore(fileURL: fileURL, now: { self.referenceDate })
        XCTAssertEqual(reloadedStore.snapshot().map(\.kind), [.app(.terminated), .app(.started)])
    }

    func testReportAlwaysIncludesEveryRetainedEntryAndCompleteExportHeader() {
        let entries = [
            TroubleshootingLogEntry.standard(.app(.started), timestamp: referenceDate),
            TroubleshootingLogEntry.detailed(
                .integration(name: .healthKit, activity: .failed),
                timestamp: referenceDate.addingTimeInterval(-1)
            )
        ]

        let report = makeReport(entries: entries)

        XCTAssertEqual(report.entries.count, 2)
        XCTAssertTrue(report.reportText.contains("App started."))
        XCTAssertTrue(report.reportText.contains("Apple Health could not complete"))
        XCTAssertEqual(report.headerLines.first, "xdripswift Troubleshooting Log")
        XCTAssertFalse(report.headerLines.contains(where: { $0.hasPrefix("Project:") }))
        XCTAssertTrue(report.headerLines.contains("App Name: xDrip4iOS"))
        XCTAssertTrue(report.headerLines.contains("Version: 7.2.1"))
        XCTAssertTrue(report.headerLines.contains("Mode: Follower (Nightscout)"))
        XCTAssertTrue(report.headerLines.contains("Dexcom Bluetooth channel: Mobile App"))
        XCTAssertFalse(report.headerLines.contains(where: { $0.hasPrefix("Data source:") }))
        XCTAssertTrue(report.headerLines.contains("Background keep-alive: Normal"))
        XCTAssertTrue(report.headerLines.contains("BG adjustment: None"))
        XCTAssertTrue(report.headerLines.contains("Smoothing: None"))
        XCTAssertTrue(report.headerLines.contains("5-minute readings: Disabled"))
        XCTAssertTrue(report.headerLines.contains("Apple Health: Enabled"))
        XCTAssertFalse(report.reportText.contains("Log period:"))
        XCTAssertFalse(report.reportText.contains("This report includes glucose values."))
        XCTAssertFalse(report.reportText.contains("Detailed information:"))
    }

    func testCurrentExportHeaderDescribesProcessingAndFiveMinuteApplicability() {
        let suiteName = "TroubleshootingLogTests.Processing.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create isolated UserDefaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.isMaster = true
        defaults.activeSensorDescription = "Dexcom G6"
        defaults.enableAdjustment = true
        defaults.enableSmoothing = true
        defaults.bgSmoothingAlgorithm = .kalman
        defaults.bgSmoothingStrength = 2
        defaults.bgSmoothingPeriodInMinutes = 30
        defaults.useFiveMinuteReadings = true

        let fixedCadenceInfo = TroubleshootingLogAppInfo.current(defaults: defaults)
        XCTAssertTrue(fixedCadenceInfo.processingLines.contains("BG adjustment: Enabled"))
        XCTAssertTrue(fixedCadenceInfo.processingLines.contains("Smoothing: Kalman, strength 2, 30-minute period"))
        XCTAssertTrue(fixedCadenceInfo.processingLines.contains("5-minute readings: n/a"))

        defaults.activeSensorDescription = "MiaoMiao"
        let fasterSourceInfo = TroubleshootingLogAppInfo.current(defaults: defaults)
        XCTAssertTrue(fasterSourceInfo.processingLines.contains("5-minute readings: Enabled"))

        // A variable provider such as Nightscout must use measured cadence, not its source name.
        // Passing `false` mirrors a recent five-minute history from the production cadence detector.
        defaults.isMaster = false
        defaults.followerDataSourceType = .nightscout
        let fiveMinuteNightscoutInfo = TroubleshootingLogAppInfo.current(
            defaults: defaults,
            currentSourceCanUseFiveMinuteReadings: false
        )
        XCTAssertTrue(fiveMinuteNightscoutInfo.processingLines.contains("5-minute readings: n/a"))
    }

    func testReportUsesEnglishLocalDatesAndRequestedGlucoseUnit() {
        let entry = TroubleshootingLogEntry.standard(
            .glucoseAccepted(mgDl: 180, source: .dexcomG6, measuredAt: referenceDate),
            timestamp: referenceDate
        )
        let timeZone = TimeZone(secondsFromGMT: 3_600)!

        let mgDlReport = makeReport(entries: [entry], usesMgDl: true, timeZone: timeZone)
        let mmolReport = makeReport(entries: [entry], usesMgDl: false, timeZone: timeZone)

        XCTAssertTrue(mgDlReport.reportText.contains("180 mg/dL"))
        XCTAssertTrue(mmolReport.reportText.contains("10.0 mmol/L"))
        XCTAssertTrue(mgDlReport.reportText.contains("New reading: 180 mg/dL at 09:00:00."))
        XCTAssertTrue(mgDlReport.reportText.contains("Friday, 15 January 2027"))
    }

    func testDirectReadingSourceUsesOnlyWhitelistedCGMDescriptions() {
        XCTAssertEqual(
            TroubleshootingLogSource(
                directTransmitterType: .dexcom,
                detailedDescription: "Dexcom G6"
            ),
            .dexcomG6
        )
        XCTAssertEqual(
            TroubleshootingLogSource(
                directTransmitterType: .dexcomG7,
                detailedDescription: "Dexcom ONE+"
            ),
            .dexcomOnePlus
        )
        XCTAssertEqual(
            TroubleshootingLogSource(
                directTransmitterType: .Libre2,
                detailedDescription: "Libre 2 Plus EU"
            ),
            .libre2PlusEU
        )

        // An arbitrary string must never become persisted or shareable. Fall back to the safe broad
        // transmitter family instead of accepting text across the consumer-log privacy boundary.
        XCTAssertEqual(
            TroubleshootingLogSource(
                directTransmitterType: .dexcom,
                detailedDescription: "Dexcom G6 - transmitter 8ABC12"
            ),
            .dexcom
        )
    }

    func testObsoleteGenericDirectSensorRowIsIgnoredAndRemoved() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)

        let currentEntry = TroubleshootingLogEntry.standard(
            .glucoseAccepted(mgDl: 93, source: .dexcomG6, measuredAt: referenceDate),
            timestamp: referenceDate
        )
        let currentJSON = String(
            decoding: try JSONEncoder.troubleshooting.encode(currentEntry),
            as: UTF8.self
        )
        let obsoleteJSON = currentJSON.replacingOccurrences(of: "dexcomG6", with: "directSensor")
        try Data((obsoleteJSON + "\n").utf8).write(to: fixture.fileURL)

        // The obsolete source is not part of the typed model. Loading treats that complete row like
        // any unsupported record, omits it from the snapshot, and repairs the file immediately.
        XCTAssertTrue(fixture.store.snapshot().isEmpty)
        XCTAssertTrue(try Data(contentsOf: fixture.fileURL).isEmpty)
    }

    func testTypedRecordsCannotPersistPrivateDeveloperTraceArguments() throws {
        let privateTraceArgument = "https://user:secret@example.com/device/serial-123"
        let entry = TroubleshootingLogEntry.standard(.follower(
            source: .nightscout,
            activity: .downloadFailed
        ), timestamp: referenceDate)

        let encoded = try JSONEncoder.troubleshooting.encode(entry)
        let report = makeReport(entries: [entry]).reportText

        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains(privateTraceArgument))
        XCTAssertFalse(report.contains(privateTraceArgument))
        XCTAssertEqual(
            TroubleshootingLogReportBuilder(
                entries: [entry],
                usesMgDl: true,
                appInfo: appInfo,
                generatedAt: referenceDate,
                timeZone: .gmt
            ).message(for: entry),
            "Nightscout could not retrieve glucose information."
        )
    }

    func testConfigurationMessagesContainOnlyControlledValues() throws {
        let postProcessingSettings = TroubleshootingPostProcessingSettings(
            adjustmentEnabled: true,
            adjustmentSlope: 1.125,
            adjustmentIntercept: -4.5,
            adjustmentEmphasis: .normal,
            smoothingEnabled: true,
            smoothingAlgorithm: .kalman,
            smoothingPeriodMinutes: 30,
            smoothingStrength: 2,
            fiveMinuteReadings: .enabled,
            applyRange: .hoursAgo(3)
        )
        let entries: [TroubleshootingLogEntry] = [
            .standard(.configuration(.modeChanged(isMaster: false)), timestamp: referenceDate),
            .standard(.configuration(.followerSourceChanged(.libreLinkUp)), timestamp: referenceDate),
            .standard(.configuration(.cgmSourceChanged(.dexcomG7)), timestamp: referenceDate),
            .standard(.configuration(.cgmSourceDisconnected), timestamp: referenceDate),
            .standard(.configuration(.keepAliveChanged(.continuous)), timestamp: referenceDate),
            .standard(.configuration(.dexcomConnectionModeChanged(.coexistence)), timestamp: referenceDate),
            .standard(.configuration(.dexcomBluetoothChannelChanged(.receiverOrPump)), timestamp: referenceDate),
            .standard(.configuration(.dexcomBluetoothChannelChanged(.anubisExperimental)), timestamp: referenceDate),
            .standard(.configuration(.therapySourceChanged(.careLink)), timestamp: referenceDate),
            .standard(.configuration(.liveActivityChanged(.large)), timestamp: referenceDate),
            .standard(.configuration(.aidFollowerChanged(.openAPS)), timestamp: referenceDate),
            .standard(.configuration(.patientAliasChanged(isSet: true)), timestamp: referenceDate),
            .standard(.configuration(.credentialChanged(source: .careLink, field: .username, isSet: true)), timestamp: referenceDate),
            .standard(.configuration(.credentialChanged(source: .careLink, field: .password, isSet: false)), timestamp: referenceDate),
            .standard(.configuration(.postProcessingSettings(postProcessingSettings)), timestamp: referenceDate),
            .standard(.heartbeatReceived, timestamp: referenceDate)
        ]
        let report = makeReport(entries: entries)
        let messages = entries.map(report.message(for:))

        XCTAssertEqual(messages, [
            "App mode changed to Follower.",
            "Data source changed to LibreLinkUp.",
            "CGM source changed to Dexcom G7.",
            "The configured CGM was disconnected.",
            "Background keep-alive changed to Continuous.",
            "Dexcom connection mode changed to Co-existence.",
            "Dexcom Bluetooth channel changed to Receiver or Pump.",
            "Dexcom Bluetooth channel changed to Slot 3 (Anubis Experimental).",
            "Pump & Treatments source changed to CareLink.",
            "Live Activity changed to Large.",
            "AID follower type changed to Trio/iAPS/AAPS.",
            "Patient alias was changed.",
            "CareLink username was changed.",
            "CareLink password was removed.",
            "Post-processing settings: BG adjustment scale 1.12, offset -4.5, emphasis Normal; smoothing Kalman, strength 2, 30-minute period; 5-minute readings enabled. Applied from 3 hours ago.",
            "Heartbeat received."
        ])

        let encoded = try entries.map { try JSONEncoder.troubleshooting.encode($0) }
        let privateValues = ["patient@example.com", "secret-password", "A Patient Name"]
        for data in encoded {
            let json = String(decoding: data, as: UTF8.self)
            for value in privateValues { XCTAssertFalse(json.contains(value)) }
        }
    }

    func testSmoothingApplyReportsCompletePostProcessingStateWithoutInferringAdjustmentAction() {
        let settings = TroubleshootingPostProcessingSettings(
            adjustmentEnabled: false,
            adjustmentSlope: nil,
            adjustmentIntercept: nil,
            adjustmentEmphasis: .normal,
            smoothingEnabled: true,
            smoothingAlgorithm: .loess,
            smoothingPeriodMinutes: 30,
            smoothingStrength: 2,
            fiveMinuteReadings: .notApplicable,
            applyRange: .now
        )
        let entry = TroubleshootingLogEntry.standard(
            .configuration(.postProcessingSettings(settings)),
            timestamp: referenceDate
        )
        let message = makeReport(entries: [entry]).message(for: entry)

        XCTAssertEqual(
            message,
            "Post-processing settings: BG adjustment none; smoothing LOESS, strength 2, 30-minute period; 5-minute readings n/a. Applied from now."
        )
        XCTAssertFalse(message.contains("was disabled"))
    }

    func testSensorQualityMetricsAreRetainedAtMostOncePerHour() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }
        let firstTime = referenceDate.addingTimeInterval(-2 * 60 * 60)
        let suppressedTime = firstTime.addingTimeInterval(30 * 60)
        let nextHourlyTime = firstTime.addingTimeInterval(60 * 60)

        for timestamp in [firstTime, suppressedTime, nextHourlyTime] {
            fixture.store.record(.standard(
                .sensorNoise(shortTermMgDl: 2.25, longTermMgDl: 3.5, status: .low),
                timestamp: timestamp
            ))
            fixture.store.record(.standard(
                .transmitterReadSuccess(percent: 98, missedReadings: 2, expectedReadings: 100, windowHours: 24),
                timestamp: timestamp
            ))
        }

        let entries = fixture.store.snapshot()
        XCTAssertEqual(entries.filter {
            if case .sensorNoise = $0.kind { return true }
            return false
        }.count, 2)
        XCTAssertEqual(entries.filter {
            if case .transmitterReadSuccess = $0.kind { return true }
            return false
        }.count, 2)

        let report = makeReport(entries: entries)
        let noiseEntry = try XCTUnwrap(entries.first { if case .sensorNoise = $0.kind { return true }; return false })
        let readSuccessEntry = try XCTUnwrap(entries.first { if case .transmitterReadSuccess = $0.kind { return true }; return false })
        XCTAssertEqual(
            report.message(for: noiseEntry),
            "Sensor noise: 30-minute 2.25 mg/dL, 4-hour 3.5 mg/dL (status: Low)."
        )
        XCTAssertEqual(
            report.message(for: readSuccessEntry),
            "Transmitter read success: 98% over 24 hours (2 of 100 readings missed)."
        )
    }

    func testSensorNoiseAlertsAreNotSuppressedByHourlyMetricFiltering() throws {
        let fixture = makeStore()
        defer { removeFixture(fixture.directory) }

        fixture.store.record(.standard(
            .sensorNoise(shortTermMgDl: 8, longTermMgDl: 12, status: .veryHigh),
            timestamp: referenceDate
        ))
        fixture.store.record(.standard(
            .sensorHealthAlert(.persistentNoise),
            timestamp: referenceDate.addingTimeInterval(1)
        ))
        fixture.store.record(.standard(
            .sensorNoise(shortTermMgDl: 9, longTermMgDl: 13, status: .veryHigh),
            timestamp: referenceDate.addingTimeInterval(2)
        ))
        fixture.store.record(.standard(
            .sensorHealthAlert(.possibleFlatline),
            timestamp: referenceDate.addingTimeInterval(3)
        ))

        let entries = fixture.store.snapshot()
        XCTAssertEqual(entries.count, 3, "Only the repeated hourly metric should be suppressed")

        let report = makeReport(entries: entries)
        XCTAssertEqual(entries.map(report.message(for:)), [
            "Possible sensor flatline alert was triggered.",
            "Persistent sensor noise alert was triggered.",
            "Sensor noise: 30-minute 8 mg/dL, 4-hour 12 mg/dL (status: Very high)."
        ])
    }

    func testTransmitterSensorHealthConditionsUseControlledMessagesEvenWhenAlarmIsDisabled() {
        let sensorHealthAlerts: [TroubleshootingSensorHealthAlert] = [
            .dexcomExcessNoise,
            .dexcomTemporarySensorIssue,
            .dexcomQuestionMarks,
            .dexcomSensorFailure,
            .dexcomTransmitterFailure,
            .libreSensorFailure,
            .dexcomTransmitterBatteryFailure
        ]
        let entries = sensorHealthAlerts.enumerated().map { index, alert in
            TroubleshootingLogEntry.standard(
                .sensorHealthAlert(alert),
                timestamp: referenceDate.addingTimeInterval(TimeInterval(index))
            )
        } + [
            .standard(.alert(
                kindRawValue: AlertKind.sensorTransmitterFailure.rawValue,
                activity: .disabled
            ), timestamp: referenceDate.addingTimeInterval(10))
        ]
        let report = makeReport(entries: entries)

        XCTAssertEqual(entries.map(report.message(for:)), [
            "Dexcom reported excessive sensor noise.",
            "Dexcom reported a temporary sensor issue.",
            "Dexcom reported a sensor question-mark state.",
            "Dexcom reported a sensor failure.",
            "Dexcom reported a transmitter failure.",
            "Libre reported a sensor failure.",
            "Dexcom reported a transmitter battery failure.",
            "Sensor/Transmitter Failure alert condition was met, but the alert is disabled."
        ])
    }

    func testDataManagementMessagesContainOnlyOperationAndAggregateCount() throws {
        let entries: [TroubleshootingLogEntry] = [
            .standard(.dataManagement(.automaticCleanupChanged(enabled: true)), timestamp: referenceDate),
            .standard(.dataManagement(.retentionChanged(days: 90)), timestamp: referenceDate),
            .standard(.dataManagement(.deletionCompleted(itemCount: 42)), timestamp: referenceDate),
            .standard(.dataManagement(.cleanupCompleted(itemCount: 7)), timestamp: referenceDate),
            .standard(.dataManagement(.backupCreated), timestamp: referenceDate),
            .standard(.dataManagement(.backupRestored), timestamp: referenceDate),
            .standard(.dataManagement(.operationFailed), timestamp: referenceDate)
        ]
        let report = makeReport(entries: entries)

        XCTAssertEqual(entries.map(report.message(for:)), [
            "Automatic data cleanup was enabled.",
            "Data retention changed to 90 days.",
            "Data deletion completed: 42 records removed.",
            "Automatic data cleanup completed: 7 records removed.",
            "A data backup was created.",
            "A data backup was restored.",
            "A data management operation failed."
        ])

        // Data-management traces never accept file names, backup passwords or import endpoints.
        // This assertion protects that boundary if the typed payload is expanded in the future.
        let encoded = try entries.map { try JSONEncoder.troubleshooting.encode($0) }
        for data in encoded {
            let json = String(decoding: data, as: UTF8.self)
            XCTAssertFalse(json.contains("private-backup.xdripbackup"))
            XCTAssertFalse(json.contains("secret-password"))
            XCTAssertFalse(json.contains("https://example.com"))
        }
    }

    func testCalibrationActivityReportsTheSubmittedReadinessConditions() {
        let readiness = TroubleshootingCalibrationReadiness(
            calibrationValue: .bad,
            stableTrend: .good,
            sensorNoise: .caution,
            overall: .bad
        )
        let entry = TroubleshootingLogEntry.standard(
            .calibrationAccepted(mgDl: 55, readiness: readiness),
            timestamp: referenceDate
        )

        XCTAssertEqual(
            makeReport(entries: [entry]).message(for: entry),
            "Calibration accepted: 55 mg/dL. Guidance was red " +
                "(calibration value red, trend green, sensor noise orange)."
        )
    }

    func testLegacyCalibrationActivityDecodesWithoutReadiness() throws {
        let data = Data(#"{"calibrationAccepted":{"mgDl":100}}"#.utf8)

        let kind = try JSONDecoder().decode(TroubleshootingLogKind.self, from: data)

        XCTAssertEqual(kind, .calibrationAccepted(mgDl: 100, readiness: nil))
    }

    func testEmptyReportExplainsThatNoHistoryExists() {
        XCTAssertTrue(makeReport(entries: []).reportText.contains(
            "No troubleshooting information was recorded during this period."
        ))
    }

    func testActivityLogFilterMatchesRenderedMessagesAndRestoresFullListForBlankText() {
        let entries: [TroubleshootingLogEntry] = [
            .standard(.heartbeatReceived, timestamp: referenceDate),
            .standard(.app(.started), timestamp: referenceDate.addingTimeInterval(-1)),
            .standard(.glucoseAccepted(
                mgDl: 123,
                source: .careLink,
                measuredAt: referenceDate.addingTimeInterval(-2)
            ), timestamp: referenceDate.addingTimeInterval(-2))
        ]
        let report = makeReport(entries: entries)

        XCTAssertEqual(report.entries(matching: "HEARTbeat").map(\.kind), [
            .heartbeatReceived
        ])
        XCTAssertEqual(report.entries(matching: "123 mg/dL").map(\.kind), [
            entries[2].kind
        ])
        XCTAssertEqual(report.entries(matching: "no match"), [])
        XCTAssertEqual(report.entries(matching: "  \n "), entries)
    }

    private var appInfo: TroubleshootingLogAppInfo {
        makeAppInfo()
    }

    private func makeAppInfo() -> TroubleshootingLogAppInfo {
        TroubleshootingLogAppInfo(
            projectName: "xdripswift",
            appName: "xDrip4iOS",
            version: "7.2.1",
            deviceClass: "iPhone",
            systemVersion: "19.0",
            modeDescription: "Follower",
            dataSourceDescription: "Nightscout",
            dexcomBluetoothChannelDescription: "Mobile App",
            unitDescription: "mg/dL",
            keepAliveDescription: "Normal",
            processingLines: ["BG adjustment: None", "Smoothing: None", "5-minute readings: Disabled"],
            integrationLines: ["Apple Health: Enabled"]
        )
    }

    private func makeReport(
        entries: [TroubleshootingLogEntry],
        usesMgDl: Bool = true,
        timeZone: TimeZone = .gmt
    ) -> TroubleshootingLogReportBuilder {
        TroubleshootingLogReportBuilder(
            entries: entries,
            usesMgDl: usesMgDl,
            appInfo: appInfo,
            generatedAt: referenceDate,
            timeZone: timeZone
        )
    }

    private func makeStore(
        maximumEntryCount: Int = 5_000,
        maximumFileSize: Int = 1_024 * 1_024
    ) -> (store: TroubleshootingLogStore, directory: URL, fileURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TroubleshootingLogTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("log.jsonl")
        let store = TroubleshootingLogStore(
            fileURL: fileURL,
            maximumEntryCount: maximumEntryCount,
            maximumFileSize: maximumFileSize,
            now: { self.referenceDate }
        )
        return (store, directory, fileURL)
    }

    private func removeFixture(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
}

private extension JSONEncoder {
    static var troubleshooting: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var troubleshooting: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension Data.SubSequence {
    var data: Data { Data(self) }
}
