//
//  BluetoothPeripheralDisplayStatusTests.swift
//  xdripTests
//

import XCTest
import CoreBluetooth
@testable import xdrip

/// Generic heartbeat policy tests need no sensor and never alter the app's real preferences.
final class GenericHeartbeatSubscriptionTests: XCTestCase {
    private func channel(_ uuid: String, _ properties: CBCharacteristicProperties = .notify, service: String = "1234") -> GenericHeartbeatChannel {
        GenericHeartbeatChannel(service: service, characteristic: uuid, properties: properties)
    }

    func testCapabilityFilteringAndDeterministicRanking() {
        // Standard measurements win over arbitrary notify channels, then indication-only channels.
        let candidates = [channel("3333", .indicate), channel("1111"), channel("2AA7"), channel("2222", .read), channel("2A19", [.read, .notify], service: "180F")]
        let expected = ["1234/2AA7", "1234/1111", "1234/3333"]
        XCTAssertEqual(GenericHeartbeatChannel.ordered(candidates).map(\.id), expected)
        XCTAssertEqual(GenericHeartbeatChannel.ordered(candidates.reversed()).map(\.id), expected)
    }

    func testDuplicateUUIDPairsAreExcluded() {
        // A UUID pair must identify one physical characteristic, even in All mode.
        XCTAssertTrue(GenericHeartbeatChannel.ordered([channel("2222"), channel("2222")]).isEmpty)
    }

    func testAutomaticFallbackRequiresExplicitFailureAndStopsAfterSuccess() {
        // Silence leaves the first request pending; only its explicit failure opens the next candidate.
        var state = GenericHeartbeatSubscriptions()
        XCTAssertEqual(state.next(["a", "b"], mode: .automatic), ["a"])
        XCTAssertTrue(state.next(["a", "b"], mode: .automatic).isEmpty)
        XCTAssertEqual(state.outcome, "pending")
        XCTAssertTrue(state.complete("a", success: false))
        XCTAssertEqual(state.next(["a", "b"], mode: .automatic), ["b"])
        // A duplicate failure must not abandon the channel currently awaiting confirmation.
        XCTAssertFalse(state.complete("a", success: false))
        XCTAssertTrue(state.complete("b", success: true))
        XCTAssertTrue(state.next(["a", "b", "c"], mode: .automatic).isEmpty)
        XCTAssertEqual(state.outcome, "subscribed")
    }

    func testExhaustionAndSessionResetAreBounded() {
        // Exhausted candidates stay exhausted for this connection, without a retry loop.
        var state = GenericHeartbeatSubscriptions()
        XCTAssertEqual(state.next(["a"], mode: .automatic), ["a"])
        state.complete("a", success: false)
        XCTAssertTrue(state.next(["a"], mode: .automatic).isEmpty)
        XCTAssertEqual(state.outcome, "failed")
        // A new connection discards the old pending confirmations before discovery resumes.
        state = GenericHeartbeatSubscriptions()
        XCTAssertFalse(state.complete("a", success: true))
        XCTAssertEqual(state.next(["a"], mode: .automatic), ["a"])
    }

    func testCompatibilityModeRequestsEachSupportedChannelOnlyOnce() {
        // All may request multiple channels, but repeated discovery must not request them again.
        var state = GenericHeartbeatSubscriptions()
        XCTAssertEqual(state.next(["a", "b"], mode: .all), ["a", "b"])
        state.complete("a", success: true)
        XCTAssertTrue(state.next(["a", "b"], mode: .all).isEmpty)
        state.complete("b", success: false)
        XCTAssertEqual(state.subscribed, ["a"])
    }

    func testPerDevicePersistenceDefaultsAndRemoval() throws {
        // Isolate storage and clean up even when an assertion fails.
        let suite = "GenericHeartbeatTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(GenericHeartbeatSettings.load("one", defaults: defaults), GenericHeartbeatSettings())
        var settings = GenericHeartbeatSettings()
        // Decode the old experimental format without reviving manual or battery controls.
        defaults.set(Data(#"{"mode":"selected","characteristic":"1234/2AA7","readBattery":false}"#.utf8), forKey: "genericHeartbeat.ONE")
        settings.mode = .automatic
        XCTAssertEqual(GenericHeartbeatSettings.load("ONE", defaults: defaults), settings)
        XCTAssertEqual(GenericHeartbeatSettings.load("one", defaults: defaults), settings)
        // Saving the simplified format must round-trip the existing Single choice.
        settings.save("one", defaults: defaults)
        XCTAssertEqual(GenericHeartbeatSettings.load("ONE", defaults: defaults), settings)
        XCTAssertEqual(GenericHeartbeatSettings.load("two", defaults: defaults), GenericHeartbeatSettings())
        GenericHeartbeatSettings.remove("one", defaults: defaults)
        XCTAssertEqual(GenericHeartbeatSettings.load("one", defaults: defaults), GenericHeartbeatSettings())
        defaults.set(Data("invalid".utf8), forKey: "genericHeartbeat.ONE")
        XCTAssertEqual(GenericHeartbeatSettings.load("one", defaults: defaults), GenericHeartbeatSettings())
    }

    func testSimplifiedPickerContainsOnlyCompatibleAndAutomaticModes() {
        // The persisted automatic value represents Single; no hidden third mode remains.
        XCTAssertEqual(GenericHeartbeatSettings.Mode.allCases, [.all, .automatic])
    }

    func testSupportLabelsMatchTheTwoSubscriptionChoices() {
        // Keep support files readable without renaming the persisted automatic preference.
        XCTAssertEqual(GenericHeartbeatSettings.Mode.automatic.rawValue, "automatic")
        XCTAssertEqual(GenericHeartbeatSettings.Mode.automatic.logDescription, "Single")
        XCTAssertEqual(GenericHeartbeatSettings.Mode.all.logDescription, "All")
    }

    func testUnexpectedStateChangesDoNotCompletePendingRequests() {
        var state = GenericHeartbeatSubscriptions()
        XCTAssertEqual(state.next(["a", "b"], mode: .automatic), ["a"])
        // An unsolicited channel may become active, but must not consume the pending request.
        state.observe("b", isNotifying: true)
        XCTAssertEqual(state.pending, ["a"])
        XCTAssertEqual(state.subscribed, ["b"])
        XCTAssertFalse(state.complete("b", success: false))
        state.observe("b", isNotifying: false)
        XCTAssertTrue(state.subscribed.isEmpty)
        XCTAssertEqual(state.pending, ["a"])
        XCTAssertTrue(state.next(["a", "b"], mode: .automatic).isEmpty)
    }
}

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
