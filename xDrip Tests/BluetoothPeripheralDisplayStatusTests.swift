//
//  BluetoothPeripheralDisplayStatusTests.swift
//  xdripTests
//

import XCTest
@testable import xdrip

final class BluetoothPeripheralDisplayStatusTests: XCTestCase {
    func testConnectedTakesPrecedenceOverEveryOtherInput() {
        XCTAssertEqual(status(isConnected: true), .connected)
    }

    func testExplicitNewDeviceDiscoveryTakesPrecedenceOverInactiveState() {
        XCTAssertEqual(status(isDiscovering: true), .discovering)
    }

    func testDisabledPeripheralIsNotScanning() {
        XCTAssertEqual(status(), .notScanning)
    }

    func testEnabledPeripheralConnectsUntilFirstSuccess() {
        XCTAssertEqual(status(isEnabled: true), .connecting)
    }

    func testPreviouslyConnectedIntermittentDexcomWaitsForNextReading() {
        XCTAssertEqual(
            status(isEnabled: true, hasConnected: true, isIntermittent: true),
            .waitingForNextReading
        )
    }

    func testRelaunchedIntermittentDexcomRetainsWaitingState() {
        XCTAssertEqual(
            status(isEnabled: true, hasConnected: true, isIntermittent: true),
            .waitingForNextReading
        )
    }

    func testHealthyDexcomWaitingShowsElapsedTimer() {
        XCTAssertTrue(BluetoothPeripheralDisplayStatus.waitingForNextReading.showsElapsedTime)
        XCTAssertFalse(BluetoothPeripheralDisplayStatus.connected.showsElapsedTime)
        XCTAssertFalse(BluetoothPeripheralDisplayStatus.notScanning.showsElapsedTime)
    }

    func testManualReactivationReturnsToConnectingUntilAnotherSuccess() {
        XCTAssertEqual(
            status(isEnabled: true, hasConnected: false, isIntermittent: true),
            .connecting
        )
    }

    func testPreviouslyConnectedContinuousPeripheralIsReconnecting() {
        XCTAssertEqual(
            status(isEnabled: true, hasConnected: true, isIntermittent: false),
            .reconnecting
        )
    }

    func testOnlyDirectAndHeartbeatDexcomTypesUseIntermittentPresentation() {
        XCTAssertTrue(BluetoothPeripheralType.DexcomType.usesIntermittentConnection)
        XCTAssertTrue(BluetoothPeripheralType.DexcomG7Type.usesIntermittentConnection)
        XCTAssertTrue(BluetoothPeripheralType.DexcomG7HeartBeatType.usesIntermittentConnection)

        XCTAssertFalse(BluetoothPeripheralType.Libre2Type.usesIntermittentConnection)
        XCTAssertFalse(BluetoothPeripheralType.MiaoMiaoType.usesIntermittentConnection)
        XCTAssertFalse(BluetoothPeripheralType.BubbleType.usesIntermittentConnection)
        XCTAssertFalse(BluetoothPeripheralType.Libre3HeartBeatType.usesIntermittentConnection)
        XCTAssertFalse(BluetoothPeripheralType.OmniPodHeartBeatType.usesIntermittentConnection)
        XCTAssertFalse(BluetoothPeripheralType.MedtrumTouchCareNanoType.usesIntermittentConnection)
        XCTAssertFalse(BluetoothPeripheralType.M5StackType.usesIntermittentConnection)
        XCTAssertFalse(BluetoothPeripheralType.M5StickCType.usesIntermittentConnection)
    }

    func testNewPeripheralPersistsFalseActivationSuccessByDefault() throws {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let dexcom = DexcomG5(
            address: "test-dexcom",
            name: "Dexcom",
            alias: nil,
            nsManagedObjectContext: coreDataManager.mainManagedObjectContext
        )

        XCTAssertTrue(dexcom.blePeripheral.shouldconnect)
        XCTAssertFalse(dexcom.blePeripheral.hasConnectedSinceActivation)

        coreDataManager.saveChanges()
        let objectID = dexcom.blePeripheral.objectID
        coreDataManager.mainManagedObjectContext.reset()

        let restored = try XCTUnwrap(
            coreDataManager.mainManagedObjectContext.existingObject(with: objectID) as? BLEPeripheral
        )
        XCTAssertFalse(restored.hasConnectedSinceActivation)
    }

    func testManagerRecordsDirectAndHeartbeatSuccessAndResetsOnlyOnActivationChange() {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let delegate = ConnectionStatusCGMDelegateStub()
        var presentationRefreshCount = 0
        let manager = BluetoothPeripheralManager(
            coreDataManager: coreDataManager,
            cgmTransmitterDelegate: delegate,
            messageHandler: { _, _ in },
            heartBeatFunction: nil,
            cgmTransmitterInfoChanged: {},
            connectionPresentationChanged: { presentationRefreshCount += 1 }
        )
        let context = coreDataManager.mainManagedObjectContext
        let g6 = DexcomG5(address: "test-g6", name: "Dexcom", alias: nil, nsManagedObjectContext: context)
        let g7 = DexcomG7(address: "test-g7", name: "Dexcom", alias: nil, nsManagedObjectContext: context)
        let heartbeat = DexcomG7HeartBeat(address: "test-heartbeat", name: "Dexcom", alias: nil, nsManagedObjectContext: context)

        manager.recordSuccessfulConnection(for: g6)
        manager.recordSuccessfulConnection(for: g7)
        manager.recordSuccessfulConnection(for: heartbeat)

        XCTAssertTrue(g6.blePeripheral.hasConnectedSinceActivation)
        XCTAssertTrue(g7.blePeripheral.hasConnectedSinceActivation)
        XCTAssertTrue(heartbeat.blePeripheral.hasConnectedSinceActivation)

        manager.recordDisconnection(for: g6)
        XCTAssertTrue(g6.blePeripheral.hasConnectedSinceActivation)
        manager.setConnectionEnabled(false, for: g6)
        XCTAssertFalse(g6.blePeripheral.hasConnectedSinceActivation)
        manager.setConnectionEnabled(true, for: g6)
        XCTAssertFalse(g6.blePeripheral.hasConnectedSinceActivation)
        XCTAssertEqual(presentationRefreshCount, 6)
    }

    func testManualDisconnectPreservesG6AndG7TransmitterSensorMetadata() {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let delegate = ConnectionStatusCGMDelegateStub()
        let manager = BluetoothPeripheralManager(
            coreDataManager: coreDataManager,
            cgmTransmitterDelegate: delegate,
            messageHandler: { _, _ in },
            heartBeatFunction: nil,
            cgmTransmitterInfoChanged: {}
        )
        let context = coreDataManager.mainManagedObjectContext
        let g6 = DexcomG5(address: "test-g6", name: "Dexcom", alias: nil, nsManagedObjectContext: context)
        let g7 = DexcomG7(address: "test-g7", name: "Dexcom", alias: nil, nsManagedObjectContext: context)
        let sensorStartDate = Date(timeIntervalSince1970: 1_800_000_000)
        g6.sensorStartDate = sensorStartDate
        g7.sensorStartDate = sensorStartDate

        manager.setConnectionEnabled(false, for: g6)
        manager.setConnectionEnabled(false, for: g7)

        XCTAssertEqual(g6.sensorStartDate, sensorStartDate)
        XCTAssertEqual(g7.sensorStartDate, sensorStartDate)
    }

    private func status(
        isConnected: Bool = false,
        isEnabled: Bool = false,
        hasConnected: Bool = false,
        isIntermittent: Bool = false,
        isDiscovering: Bool = false
    ) -> BluetoothPeripheralDisplayStatus {
        BluetoothPeripheralDisplayStatus(
            isConnected: isConnected,
            isEnabled: isEnabled,
            hasConnectedSinceActivation: hasConnected,
            usesIntermittentConnection: isIntermittent,
            isDiscoveringNewPeripheral: isDiscovering
        )
    }
}

final class StandardBluetoothBatteryLevelTests: XCTestCase {
    func testParsesValidStandardBatteryPercentages() {
        // EmaLink/OrangeLink-compatible Battery Service values include both boundary percentages.
        XCTAssertEqual(StandardBluetoothBatteryLevel.percentage(from: Data([0])), 0)
        XCTAssertEqual(StandardBluetoothBatteryLevel.percentage(from: Data([57])), 57)
        XCTAssertEqual(StandardBluetoothBatteryLevel.percentage(from: Data([100])), 100)
    }

    func testRejectsMissingMalformedAndOutOfRangeBatteryValues() {
        XCTAssertNil(StandardBluetoothBatteryLevel.percentage(from: nil))
        XCTAssertNil(StandardBluetoothBatteryLevel.percentage(from: Data()))
        XCTAssertNil(StandardBluetoothBatteryLevel.percentage(from: Data([50, 51])))
        XCTAssertNil(StandardBluetoothBatteryLevel.percentage(from: Data([101])))
    }

    func testPresentationIsInvisibleUntilAValidLevelExists() {
        // Absence stays invisible for normal heartbeat users, while a genuine empty battery must
        // remain distinguishable from an unsupported EmaLink or OrangeLink battery service.
        XCTAssertNil(BluetoothBatteryLevelPresentation.detail(for: nil))
        XCTAssertNil(BluetoothBatteryLevelPresentation.detail(for: -1))
        XCTAssertNil(BluetoothBatteryLevelPresentation.detail(for: 101))
        XCTAssertEqual(BluetoothBatteryLevelPresentation.detail(for: 0), "0 %")
        XCTAssertEqual(BluetoothBatteryLevelPresentation.detail(for: 57), "57 %")
    }
}

private final class ConnectionStatusCGMDelegateStub: CGMTransmitterDelegate {
    func newSensorDetected(sensorStartDate: Date?) {}
    func sensorStopDetected() {}
    func sensorNotDetected() {}
    func cgmTransmitterInfoReceived(glucoseData: inout [GlucoseData], transmitterBatteryInfo: TransmitterBatteryInfo?, sensorAge: TimeInterval?) {}
    func errorOccurred(xDripError: XdripError) {}
}
