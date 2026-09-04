import XCTest
@testable import xdrip

final class DexcomG7CalibrationTests: XCTestCase {
    func testCalibrationCommandUsesG6WireFormatWithExplicitTransmitterTime() {
        let command = DexcomG7CalibrationCommand(glucose: 153, transmitterTime: 0x0008_840E)

        XCTAssertEqual(command.data.count, 9)
        XCTAssertEqual(command.data.prefix(7), Data([0x34, 0x99, 0x00, 0x0E, 0x84, 0x08, 0x00]))
        XCTAssertTrue(command.data.isCRCValid)
    }

    func testCapturedBoundsProgressFromInProgressToCompleteHigh() throws {
        let first = try bounds("3200017400000099000e840800020102a1840800")
        let second = try bounds("3200017400000099000e84080002010250850800")
        let third = try bounds("3200017400000099000e84080003010250850800")

        XCTAssertEqual(first.sessionNumber, 1)
        XCTAssertEqual(first.sessionSignature, 116)
        XCTAssertEqual(first.glucose, 153)
        XCTAssertEqual(first.calibrationTime, 0x0008_840E)
        XCTAssertEqual(first.processingState, .inProgress)
        XCTAssertTrue(first.calibrationsPermitted)
        XCTAssertEqual(first.originatingDisplay, .phone)
        XCTAssertEqual(first.lastProcessingUpdateTime, 0x0008_84A1)

        XCTAssertEqual(second.processingState, .inProgress)
        XCTAssertEqual(second.lastProcessingUpdateTime, 0x0008_8550)
        XCTAssertEqual(third.processingState, .completeHigh)
        XCTAssertEqual(third.lastProcessingUpdateTime, second.lastProcessingUpdateTime)
        XCTAssertTrue(third.matches(glucose: 153, transmitterTime: 0x0008_840E))
        XCTAssertFalse(third.matches(glucose: 152, transmitterTime: 0x0008_840E))
        XCTAssertFalse(third.matches(glucose: 153, transmitterTime: 0x0008_8420))
    }

    func testPreviousCalibrationBoundsDoNotMatchInFlightCalibration() throws {
        let previous = try bounds("3200015d0000006b00aaca0000030102ebcb0000")
        let inFlight = try bounds("3200015d0000006e0015df00000201024fe00000")

        XCTAssertFalse(previous.matches(glucose: 110, transmitterTime: 57109))
        XCTAssertTrue(inFlight.matches(glucose: 110, transmitterTime: 57109))
    }

    func testCalibrationCommandResponsesDecodeAcceptedRejectedAndUnknownStatuses() {
        XCTAssertEqual(response([0x34, 0, 0, 0])?.status, .acceptedHigh(.accepted))
        XCTAssertEqual(response([0x34, 0, 1, 0])?.status, .acceptedLow(.accepted))
        XCTAssertEqual(response([0x34, 0, 0, 1])?.status, .acceptedHigh(.error0))
        XCTAssertEqual(response([0x34, 0, 1, 2])?.status, .acceptedLow(.error1))
        XCTAssertEqual(response([0x34, 0, 2, 3])?.status, .rejected(.duplicate))
        XCTAssertEqual(response([0x34, 0, 2, 6])?.status, .rejected(.alreadyEntered))
        XCTAssertEqual(response([0x34, 0, 2, 8])?.status, .rejected(.notPermitted))
        XCTAssertEqual(response([0x34, 0, 3, 0])?.status, .factoryCalibrated)
        XCTAssertEqual(response([0x34, 0, 9, 7])?.status, .unknown(primary: 9, secondary: 7))
    }

    func testAllDocumentedRejectionReasonsRemainDistinct() {
        let expected: [DexcomG7CalibrationRejectionReason] = [
            .unspecified, .outsideRange, .timestampInFuture, .duplicate,
            .earlierThanSessionStart, .notInOrder, .alreadyEntered, .disabled,
            .notPermitted, .calibrationBoundsFailed, .extremeOutlier, .stale,
        ]

        XCTAssertEqual((0 ... 11).map { DexcomG7CalibrationRejectionReason(rawValue: UInt8($0)) }, expected)
        XCTAssertEqual(DexcomG7CalibrationRejectionReason(rawValue: 99), .unknown(99))
    }

    func testMalformedResponsesAreRejected() {
        XCTAssertNil(DexcomG7CalibrationCommandResponse(data: Data([0x34, 0, 0])))
        XCTAssertNil(DexcomG7CalibrationCommandResponse(data: Data([0x35, 0, 0, 0])))
        XCTAssertNil(DexcomG7CalibrationBounds(data: Data(repeating: 0, count: 20)))
        XCTAssertNil(DexcomG7CalibrationBounds(data: Data([0x32])))
    }

    func testClockReferenceConvertsWallClockWithoutSensorStartEstimate() {
        let receivedAt = Date(timeIntervalSince1970: 1000)
        let clock = DexcomG7TransmitterClockReference(transmitterTime: 10000, referenceDate: receivedAt)

        XCTAssertEqual(clock.transmitterTime(for: receivedAt.addingTimeInterval(-90)), 9910)
        XCTAssertEqual(clock.transmitterTime(for: receivedAt.addingTimeInterval(30)), 10030)
    }

    func testStatusTrackerDeduplicatesRepeatedBoundsTransitions() {
        var tracker = CGMTransmitterCalibrationStatusTracker()

        XCTAssertTrue(tracker.transition(to: .processing))
        XCTAssertFalse(tracker.transition(to: .processing))
        XCTAssertTrue(tracker.transition(to: .completedHigh))
        XCTAssertFalse(tracker.transition(to: .completedHigh))
        XCTAssertEqual(tracker.status, .completedHigh)
        XCTAssertFalse(tracker.clear(if: .notPermitted))
        XCTAssertTrue(tracker.clear(if: .completedHigh))
        XCTAssertNil(tracker.status)
    }

    func testCalibrationStatusShortDescriptionsAndSubmissionGating() {
        XCTAssertEqual(CGMTransmitterCalibrationStatus.queued.shortDescription, "Queued")
        XCTAssertEqual(CGMTransmitterCalibrationStatus.sentAwaitingResponse.shortDescription, "Sent")
        XCTAssertEqual(CGMTransmitterCalibrationStatus.processing.shortDescription, "Processing")
        XCTAssertEqual(CGMTransmitterCalibrationStatus.completedHigh.shortDescription, "Completed")
        XCTAssertEqual(CGMTransmitterCalibrationStatus.completedLow.shortDescription, "Completed")
        XCTAssertEqual(CGMTransmitterCalibrationStatus.rejected(.duplicate).shortDescription, "Rejected")
        XCTAssertEqual(CGMTransmitterCalibrationStatus.notPermitted.shortDescription, "Error")

        XCTAssertTrue(CGMTransmitterCalibrationStatus.queued.preventsCalibrationSubmission)
        XCTAssertTrue(CGMTransmitterCalibrationStatus.sentAwaitingResponse.preventsCalibrationSubmission)
        XCTAssertTrue(CGMTransmitterCalibrationStatus.processing.preventsCalibrationSubmission)
        XCTAssertTrue(CGMTransmitterCalibrationStatus.notPermitted.preventsCalibrationSubmission)
        XCTAssertFalse(CGMTransmitterCalibrationStatus.completedHigh.preventsCalibrationSubmission)
        XCTAssertFalse(CGMTransmitterCalibrationStatus.completedLow.preventsCalibrationSubmission)
        XCTAssertFalse(CGMTransmitterCalibrationStatus.rejected(.outsideRange).preventsCalibrationSubmission)
    }

    func testCalibrationStatusIndicatorColorsGroupTransmitterStates() {
        XCTAssertEqual(CGMTransmitterCalibrationStatus.queued.indicatorColor, .yellow)
        XCTAssertEqual(CGMTransmitterCalibrationStatus.sentAwaitingResponse.indicatorColor, .yellow)
        XCTAssertEqual(CGMTransmitterCalibrationStatus.processing.indicatorColor, .yellow)
        XCTAssertEqual(CGMTransmitterCalibrationStatus.completedHigh.indicatorColor, .green)
        XCTAssertEqual(CGMTransmitterCalibrationStatus.completedLow.indicatorColor, .green)
        XCTAssertEqual(CGMTransmitterCalibrationStatus.rejected(.outsideRange).indicatorColor, .red)
        XCTAssertEqual(CGMTransmitterCalibrationStatus.notPermitted.indicatorColor, .red)
    }

    func testCalibrationInProgressIncludesOnlyTransientStates() {
        XCTAssertTrue(CGMTransmitterCalibrationStatus.queued.isInProgress)
        XCTAssertTrue(CGMTransmitterCalibrationStatus.sentAwaitingResponse.isInProgress)
        XCTAssertTrue(CGMTransmitterCalibrationStatus.processing.isInProgress)

        XCTAssertFalse(CGMTransmitterCalibrationStatus.completedHigh.isInProgress)
        XCTAssertFalse(CGMTransmitterCalibrationStatus.completedLow.isInProgress)
        XCTAssertFalse(CGMTransmitterCalibrationStatus.rejected(.outsideRange).isInProgress)
        XCTAssertFalse(CGMTransmitterCalibrationStatus.notPermitted.isInProgress)
    }

    func testDexcomConnectionModeUsesStableProjectWideSymbols() {
        XCTAssertEqual(DexcomConnectionMode(useOtherApp: false), .primary)
        XCTAssertEqual(DexcomConnectionMode.primary.systemImage, "p.square.fill")
        XCTAssertEqual(DexcomConnectionMode(useOtherApp: true), .coexistence)
        XCTAssertEqual(DexcomConnectionMode.coexistence.systemImage, "c.square.fill")
    }

    func testDexcomProductDescriptionUsesTheSuppliedTransmitterID() {
        XCTAssertEqual(CGMTransmitterType.dexcom.detailedDescription(transmitterID: "812345"), "Dexcom G6")
        XCTAssertEqual(CGMTransmitterType.dexcom.detailedDescription(transmitterID: "C12345"), "Dexcom ONE")
        XCTAssertEqual(CGMTransmitterType.dexcomG7.detailedDescription(transmitterID: "dx01ab"), "Dexcom Stelo")
        XCTAssertEqual(CGMTransmitterType.dexcomG7.detailedDescription(transmitterID: "DX02zn"), "Dexcom ONE+")
        XCTAssertEqual(CGMTransmitterType.dexcomG7.detailedDescription(transmitterID: "DXCM12"), "Dexcom G7")
        XCTAssertEqual(CGMTransmitterType.dexcomG7.detailedDescription(transmitterID: nil), "Dexcom G7")
    }

    func testDexcomProductNameResolverUsesBluetoothNameForAutomaticG7Discovery() {
        // `DX0000` is only the value that asks Core Bluetooth to discover any G7-family sensor.
        // The advertised name is therefore the first value that can distinguish the product.
        XCTAssertEqual(
            DexcomProductNameResolver.title(
                transmitterType: .dexcomG7,
                transmitterID: ConstantsBluetoothPairing.dummyDexcomG7TypeTransmitterId,
                bluetoothName: "DX02AB"
            ),
            "Dexcom ONE+"
        )
        XCTAssertEqual(
            DexcomProductNameResolver.title(
                transmitterType: .dexcomG7,
                transmitterID: "DX",
                bluetoothName: "DX01CD"
            ),
            "Dexcom Stelo"
        )
        XCTAssertEqual(
            DexcomProductNameResolver.title(
                transmitterType: .dexcomG7,
                transmitterID: nil,
                bluetoothName: "DXCM12"
            ),
            "Dexcom G7"
        )
    }

    func testDexcomProductNameResolverPrefersARealSavedIdentifier() {
        XCTAssertEqual(
            DexcomProductNameResolver.title(
                transmitterType: .dexcomG7,
                transmitterID: "DX02AB",
                bluetoothName: "DX01CD"
            ),
            "Dexcom ONE+"
        )
        XCTAssertEqual(
            DexcomProductNameResolver.title(
                transmitterType: .dexcom,
                transmitterID: "812345",
                bluetoothName: "Dexcom45"
            ),
            "Dexcom G6"
        )
    }

    func testExtendedVersionDecodesTenDaySessionIncludingGracePeriod() throws {
        let message = try extendedVersion("5200c0d70d00540600020404ff0c00")

        XCTAssertEqual(message.sessionLength, TimeInterval(days: 10.5))
        XCTAssertEqual(message.warmupDuration, TimeInterval(minutes: 27))
        XCTAssertEqual(message.algorithmVersion, 67_371_520)
        XCTAssertEqual(message.hardwareVersion, 255)
        XCTAssertEqual(message.maxLifetimeDays, 12)
    }

    func testExtendedVersionDecodesFifteenDaySessionIncludingGracePeriod() throws {
        let message = try extendedVersion("5200406f1400880e00010a04ff1100")

        XCTAssertEqual(message.sessionLength, TimeInterval(days: 15.5))
        XCTAssertEqual(message.warmupDuration, TimeInterval(minutes: 62))
        XCTAssertEqual(message.algorithmVersion, 67_764_480)
        XCTAssertEqual(message.hardwareVersion, 255)
        XCTAssertEqual(message.maxLifetimeDays, 17)
    }

    func testExtendedVersionRejectsWrongOpcodeAndTruncatedPackets() {
        XCTAssertNil(DexcomG7ExtendedVersionMessage(data: Data([0x53] + Array(repeating: 0, count: 14))))
        XCTAssertNil(DexcomG7ExtendedVersionMessage(data: Data([0x52] + Array(repeating: 0, count: 13))))
    }

    func testReportedLifetimeOverridesNameFallbackAndUnknownValuesRemainConservative() {
        XCTAssertEqual(
            DexcomG7SensorLifetime.maximumSensorAgeInDays(
                reportedSessionLength: TimeInterval(days: 15.5),
                deviceName: "DXCM12"
            ),
            15.5
        )
        XCTAssertEqual(
            DexcomG7SensorLifetime.maximumSensorAgeInDays(
                reportedSessionLength: TimeInterval(days: 10.5),
                deviceName: "DX01AB"
            ),
            10.5
        )
        XCTAssertEqual(
            DexcomG7SensorLifetime.maximumSensorAgeInDays(
                reportedSessionLength: TimeInterval(days: 30),
                deviceName: "DXCM12"
            ),
            10.5
        )
        XCTAssertEqual(
            DexcomG7SensorLifetime.maximumSensorAgeInDays(
                reportedSessionLength: nil,
                deviceName: "dx01ab"
            ),
            15.5
        )
        XCTAssertEqual(
            DexcomG7SensorLifetime.diagnosticDescription(TimeInterval(days: 10.5)),
            "10-day sensor (+ 12-hour grace period)"
        )
        XCTAssertEqual(
            DexcomG7SensorLifetime.diagnosticDescription(TimeInterval(days: 15.5)),
            "15-day sensor (+ 12-hour grace period)"
        )
        XCTAssertEqual(DexcomG7SensorLifetime.diagnosticDescription(nil), "not detected")
    }

    func testRejectedSavedKeyStopsWithoutStartingOwnershipAgain() {
        XCTAssertEqual(DexcomG7AuthSession.authenticationStatusAction(
            usingFullBootstrap: false,
            authenticated: true,
            paired: true
        ), .continueAuthentication)
        XCTAssertEqual(DexcomG7AuthSession.authenticationStatusAction(
            usingFullBootstrap: false,
            authenticated: true,
            paired: false
        ), .startFullBootstrap)
        XCTAssertEqual(DexcomG7AuthSession.authenticationStatusAction(
            usingFullBootstrap: false,
            authenticated: false,
            paired: true
        ), .rejectPersistedKey)
        XCTAssertEqual(DexcomG7AuthSession.authenticationStatusAction(
            usingFullBootstrap: false,
            authenticated: false,
            paired: false
        ), .rejectPersistedKey)
        XCTAssertEqual(DexcomG7AuthSession.authenticationStatusAction(
            usingFullBootstrap: true,
            authenticated: true,
            paired: false
        ), .continueAuthentication)
        XCTAssertEqual(DexcomG7AuthSession.authenticationStatusAction(
            usingFullBootstrap: true,
            authenticated: false,
            paired: true
        ), .reject)
    }

    func testG7OwnershipCompletesOnObservedKeepAliveResponse() {
        XCTAssertEqual(
            DexcomG7AuthSession.ownershipKeepAliveAction(for: Data([0x06, 0x01])),
            .completeOwnership
        )
        XCTAssertEqual(
            DexcomG7AuthSession.ownershipKeepAliveAction(for: Data([0x06, 0x00])),
            .requestLegacyBond
        )
        XCTAssertEqual(
            DexcomG7AuthSession.ownershipKeepAliveAction(for: Data([0x06, 0x02])),
            .ignore
        )
    }

    func testG7CoexistenceDecodesObservedGlucoseAndClockPackets() throws {
        let glucoseData = try XCTUnwrap(Data(hexadecimalString: "31008eaf0000335bd7009900060582be"))
        let glucose = try XCTUnwrap(G7CoexistenceGlucoseMessage(data: glucoseData))

        XCTAssertEqual(glucose.calculatedValue, 153)
        XCTAssertEqual(glucose.transmitterTime, 14_113_587)
        XCTAssertEqual(glucose.algorithmStatus, .okay)

        let clockData = try XCTUnwrap(Data(hexadecimalString: "25003e5bd700f0ccd30001000000a0f2"))
        let clock = try XCTUnwrap(DexcomTransmitterTimeRxMessage(data: clockData))
        let sensorStartDate = try XCTUnwrap(clock.sensorStartDate)
        let readingDate = clock.transmitterStartDate.addingTimeInterval(TimeInterval(glucose.transmitterTime))

        XCTAssertEqual(readingDate.timeIntervalSince(sensorStartDate), 233_027, accuracy: 0.001)
    }

    func testDeletingG7AuthenticationStateClearsEverySlotKey() {
        let transmitterID = "DXTEST-\(UUID().uuidString)"
        let baseKey = "G7NativeAuthBridge.SharedKey.\(transmitterID)"
        let keys = [baseKey, "\(baseKey).01", "\(baseKey).02", "\(baseKey).03"]
        let defaults = UserDefaults.standard
        defer { keys.forEach { defaults.removeObject(forKey: $0) } }
        keys.forEach { defaults.set(Data(repeating: 0x55, count: 16), forKey: $0) }

        DexcomG7AuthBridge.clearPersistedSharedKeys(forTransmitterID: transmitterID)

        keys.forEach { XCTAssertNil(defaults.data(forKey: $0)) }
    }

    func testG7StatusResponseRetainsSensorFailureWithoutPublishingItAsCurrent() throws {
        let message = try XCTUnwrap(G7GlucoseMessage(data: Data(hexadecimalString: "4e80a26b0200e8010001793990001b04ab0000")!))

        XCTAssertEqual(message.responseStatus, 0x80)
        XCTAssertEqual(message.transmitterTime, 158_626)
        XCTAssertEqual(message.sensorAge, 173_339)
        XCTAssertEqual(message.calculatedValue, 144)
        XCTAssertEqual(message.algorithmStatus, .SensorFailed8)
        XCTAssertEqual(message.algorithmStatus.sensorHealthEvent, .terminal(source: .dexcom, reason: .dexcomSensorFailure))
    }

    func testCapturedG7BatteryResponseDecodesSharedWireValues() throws {
        let data = try XCTUnwrap(Data(hexadecimalString: "220020010b0106210000000001"))
        let message = try XCTUnwrap(DexcomG7BatteryStatusMessage(data: data))

        XCTAssertEqual(message.status, 0)
        XCTAssertEqual(message.voltageA, 288)
        XCTAssertEqual(message.voltageB, 267)
        XCTAssertEqual(message.resistance, 8_454)
        XCTAssertEqual(message.runtime, 0)
        XCTAssertEqual(message.temperature, 0)
        XCTAssertEqual(DexcomBatteryStatus.millivolts(fromRawVoltage: message.voltageB), 2_670)
    }

    func testDexcomBatteryClassificationUsesFamilyBoundaries() {
        // G5/G6/ONE retain their existing presentation without any threshold migration.
        XCTAssertEqual(DexcomBatteryStatus(voltageB: 0, family: .g5), .unknown)
        XCTAssertEqual(DexcomBatteryStatus(voltageB: 269, family: .g5), .red)
        XCTAssertEqual(DexcomBatteryStatus(voltageB: 270, family: .g5), .yellow)
        XCTAssertEqual(DexcomBatteryStatus(voltageB: 279, family: .g5), .yellow)
        XCTAssertEqual(DexcomBatteryStatus(voltageB: 280, family: .g5), .green)

        // G7/ONE+/Stelo use the initial family field mapping. Boundaries are exclusive, matching
        // the long-standing G5 implementation: exactly 215 is yellow and exactly 250 is green.
        XCTAssertEqual(DexcomBatteryStatus(voltageB: 0, family: .g7), .unknown)
        XCTAssertEqual(DexcomBatteryStatus(voltageB: 214, family: .g7), .red)
        XCTAssertEqual(DexcomBatteryStatus(voltageB: 215, family: .g7), .yellow)
        XCTAssertEqual(DexcomBatteryStatus(voltageB: 249, family: .g7), .yellow)
        XCTAssertEqual(DexcomBatteryStatus(voltageB: 250, family: .g7), .green)
    }

    func testDexcomBatteryInfoPreservesFamilyAndReadsLegacyG5Data() throws {
        let g7 = TransmitterBatteryInfo.dexcom(
            family: .g7,
            voltageA: 282,
            voltageB: 204,
            resist: 8_192,
            runtime: 0,
            temperature: 0
        )
        let savedG7 = g7.toData()
        XCTAssertEqual(savedG7.first, 3)
        XCTAssertEqual(TransmitterBatteryInfo(data: savedG7), g7)

        // Type 1 is the historical persisted representation. It must continue to decode as the
        // G5 battery family after the enum begins carrying family explicitly.
        var legacy = savedG7
        legacy[0] = 1
        XCTAssertEqual(
            TransmitterBatteryInfo(data: legacy),
            .dexcom(family: .g5, voltageA: 282, voltageB: 204, resist: 8_192, runtime: 0, temperature: 0)
        )
    }

    func testBatteryAlertsAcceptOnlyTheirOwnFamily() {
        let percentage = TransmitterBatteryInfo.percentage(percentage: 18)
        let g5 = TransmitterBatteryInfo.dexcom(
            family: .g5,
            voltageA: 290,
            voltageB: 269,
            resist: 0,
            runtime: 0,
            temperature: 0
        )
        let g7 = TransmitterBatteryInfo.dexcom(
            family: .g7,
            voltageA: 282,
            voltageB: 204,
            resist: 8_192,
            runtime: 0,
            temperature: 0
        )

        XCTAssertEqual(AlertKind.batterylow.matchingBatteryLevel(from: percentage), 18)
        XCTAssertNil(AlertKind.batterylow.matchingBatteryLevel(from: g5))
        XCTAssertNil(AlertKind.batterylow.matchingBatteryLevel(from: g7))
        XCTAssertEqual(AlertKind.dexcomG5BatteryLow.matchingBatteryLevel(from: g5), 269)
        XCTAssertNil(AlertKind.dexcomG5BatteryLow.matchingBatteryLevel(from: g7))
        XCTAssertEqual(AlertKind.dexcomG7BatteryLow.matchingBatteryLevel(from: g7), 204)
        XCTAssertNil(AlertKind.dexcomG7BatteryLow.matchingBatteryLevel(from: g5))
        XCTAssertEqual(AlertKind.dexcomG7BatteryLow.defaultAlertValue(), 215)
    }

    func testDexcomBatteryAlertsRejectZeroVoltageB() {
        let zeroG5 = TransmitterBatteryInfo.dexcom(
            family: .g5,
            voltageA: 290,
            voltageB: 0,
            resist: 0,
            runtime: 0,
            temperature: 0
        )
        let zeroG7 = TransmitterBatteryInfo.dexcom(
            family: .g7,
            voltageA: 282,
            voltageB: 0,
            resist: 0,
            runtime: 0,
            temperature: 0
        )

        XCTAssertNil(AlertKind.dexcomG5BatteryLow.matchingBatteryLevel(from: zeroG5))
        XCTAssertNil(AlertKind.dexcomG7BatteryLow.matchingBatteryLevel(from: zeroG7))

        // Zero is a genuine value for a percentage-based transmitter and must remain alertable.
        XCTAssertEqual(
            AlertKind.batterylow.matchingBatteryLevel(from: .percentage(percentage: 0)),
            0
        )
    }

    func testDexcomBatteryAlertSettlingPeriodUsesSixHourBoundary() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let suppressionInterval = TimeInterval(
            ConstantsAlerts.dexcomBatteryAlertSuppressionPeriodInHours * 60 * 60
        )

        XCTAssertEqual(ConstantsAlerts.dexcomBatteryAlertSuppressionPeriodInHours, 6)
        XCTAssertTrue(DexcomBatteryAlertPolicy.shouldSuppress(hardwareStartDate: nil, now: now))
        XCTAssertTrue(
            DexcomBatteryAlertPolicy.shouldSuppress(
                hardwareStartDate: now.addingTimeInterval(-suppressionInterval + 1),
                now: now
            )
        )
        XCTAssertFalse(
            DexcomBatteryAlertPolicy.shouldSuppress(
                hardwareStartDate: now.addingTimeInterval(-suppressionInterval),
                now: now
            )
        )
        XCTAssertFalse(
            DexcomBatteryAlertPolicy.shouldSuppress(
                hardwareStartDate: now.addingTimeInterval(-suppressionInterval - 1),
                now: now
            )
        )
    }

    func testBatteryAlertRoutingSelectsThePayloadFamilyConfiguration() {
        let percentage = TransmitterBatteryInfo.percentage(percentage: 18)
        let g5 = TransmitterBatteryInfo.dexcom(
            family: .g5,
            voltageA: 290,
            voltageB: 269,
            resist: 0,
            runtime: 0,
            temperature: 0
        )
        let g7 = TransmitterBatteryInfo.dexcom(
            family: .g7,
            voltageA: 282,
            voltageB: 204,
            resist: 8_192,
            runtime: 0,
            temperature: 0
        )

        // AlertManager uses this payload-derived kind to fetch exactly one AlertEntry. This is
        // intentionally independent of the configured CGM type during a device transition.
        XCTAssertEqual(AlertKind.batteryAlertKind(for: percentage), .batterylow)
        XCTAssertEqual(AlertKind.batteryAlertKind(for: g5), .dexcomG5BatteryLow)
        XCTAssertEqual(AlertKind.batteryAlertKind(for: g7), .dexcomG7BatteryLow)

        // The value is presented as mV but converted back to the raw 10 mV comparison unit.
        XCTAssertEqual(AlertKind.dexcomG7BatteryLow.displayedAlertValue(fromStoredValue: 215), 2_150)
        XCTAssertEqual(AlertKind.dexcomG7BatteryLow.storedAlertValue(fromDisplayedValue: 2_150), 215)
        XCTAssertNil(AlertKind.dexcomG7BatteryLow.storedAlertValue(fromDisplayedValue: 2_155))
    }

    func testAlarmPresentationShowsOnlyTheConfiguredBatteryFamily() {
        let g5Kinds = AlertKind.visibleAlertKinds(for: .dexcom)
        let g7Kinds = AlertKind.visibleAlertKinds(for: .dexcomG7)
        let percentageKinds = AlertKind.visibleAlertKinds(for: .Libre2)
        let unsupportedKinds = AlertKind.visibleAlertKinds(for: .medtrumTouchCareNano)

        XCTAssertEqual(g5Kinds.filter { $0.isTransmitterBatteryAlert }, [.dexcomG5BatteryLow])
        XCTAssertEqual(g7Kinds.filter { $0.isTransmitterBatteryAlert }, [.dexcomG7BatteryLow])
        XCTAssertEqual(percentageKinds.filter { $0.isTransmitterBatteryAlert }, [.batterylow])
        XCTAssertTrue(unsupportedKinds.filter { $0.isTransmitterBatteryAlert }.isEmpty)

        // Device alarms stay together and every internal battery kind shares one concise title.
        XCTAssertEqual(Array(g7Kinds.suffix(3)), [.sensorTransmitterFailure, .dexcomG7BatteryLow, .phonebatterylow])
        XCTAssertEqual(AlertKind.dexcomG5BatteryLow.alertTitle(), Texts_Alerts.batteryLowAlertTitle)
        XCTAssertEqual(AlertKind.dexcomG7BatteryLow.alertTitle(), Texts_Alerts.batteryLowAlertTitle)
        XCTAssertEqual(AlertKind.dexcomG5BatteryLow.configurationTitle(), Texts_Alerts.batteryLowAlertTitle + " (G6)")
        XCTAssertEqual(AlertKind.dexcomG7BatteryLow.configurationTitle(), Texts_Alerts.batteryLowAlertTitle + " (G7)")
        XCTAssertEqual(AlertKind.batterylow.configurationTitle(), Texts_Alerts.batteryLowAlertTitle)
        XCTAssertEqual(AlertKind.dexcomG5BatteryLow.configurationFamilySuffix(), " (G6)")
        XCTAssertEqual(AlertKind.dexcomG7BatteryLow.configurationFamilySuffix(), " (G7)")
        XCTAssertEqual(AlertKind.batterylow.configurationFamilySuffix(), "")
    }

    func testG7DiagnosticRequestsUseExpectedCRCFraming() {
        XCTAssertEqual(BatteryStatusTxMessage().data, Data([0x22, 0x20, 0x04]))
        XCTAssertEqual(TransmitterVersionTxMessage().data, Data([0x4A, 0x8E, 0xE9]))
        XCTAssertTrue(BatteryStatusTxMessage().data.isCRCValid)
        XCTAssertTrue(TransmitterVersionTxMessage().data.isCRCValid)
    }

    func testG7FullVersionResponseDecodesLittleEndianFieldsAndSixByteSerial() throws {
        let data = Data([
            0x4A, 0x00,
            0x01, 0x02, 0x03, 0x04,
            0x78, 0x56, 0x34, 0x12,
            0xEF, 0xCD, 0xAB, 0x90,
            0x01, 0x02, 0x03, 0x04, 0x05, 0x06
        ])
        let message = try XCTUnwrap(DexcomG7VersionMessage(data: data))

        XCTAssertEqual(message.status, 0)
        XCTAssertEqual(message.firmwareVersion, "1.2.3.4")
        XCTAssertEqual(message.buildVersion, 0x1234_5678)
        XCTAssertEqual(message.versionCode, 0x90AB_CDEF)
        XCTAssertEqual(message.serialNumber, 0x0605_0403_0201)
    }

    func testG7DiagnosticResponsesRejectShortAndWrongOpcodePackets() {
        XCTAssertNil(DexcomG7BatteryStatusMessage(data: Data(repeating: 0, count: 9)))
        XCTAssertNil(DexcomG7BatteryStatusMessage(data: Data([0x23]) + Data(repeating: 0, count: 9)))
        XCTAssertNil(DexcomG7VersionMessage(data: Data(repeating: 0, count: 19)))
        XCTAssertNil(DexcomG7VersionMessage(data: Data([0x4B]) + Data(repeating: 0, count: 19)))
    }

    func testG7BatteryCadenceIsPerSensorAndBecomesDueAtTwoHours() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertTrue(CGMG7Transmitter.batteryReadingIsDue(lastReadDate: nil, now: now))
        XCTAssertFalse(CGMG7Transmitter.batteryReadingIsDue(
            lastReadDate: now.addingTimeInterval(-ConstantsDexcomG5.batteryReadPeriod + 1),
            now: now
        ))
        XCTAssertTrue(CGMG7Transmitter.batteryReadingIsDue(
            lastReadDate: now.addingTimeInterval(-ConstantsDexcomG5.batteryReadPeriod),
            now: now
        ))
    }

    func testG7PostGlucoseCommandPrioritySelectsOnlyOneAction() {
        XCTAssertEqual(CGMG7Transmitter.postGlucoseCommand(
            hasCalibrationWork: true,
            lifetimeIsUnknown: true,
            firmwareIsUnknown: true,
            batteryIsDue: true
        ), .calibrationOrBounds)
        XCTAssertEqual(CGMG7Transmitter.postGlucoseCommand(
            hasCalibrationWork: false,
            lifetimeIsUnknown: true,
            firmwareIsUnknown: true,
            batteryIsDue: true
        ), .lifetime)
        XCTAssertEqual(CGMG7Transmitter.postGlucoseCommand(
            hasCalibrationWork: false,
            lifetimeIsUnknown: false,
            firmwareIsUnknown: true,
            batteryIsDue: true
        ), .firmware)
        XCTAssertEqual(CGMG7Transmitter.postGlucoseCommand(
            hasCalibrationWork: false,
            lifetimeIsUnknown: false,
            firmwareIsUnknown: false,
            batteryIsDue: true
        ), .battery)
        XCTAssertEqual(CGMG7Transmitter.postGlucoseCommand(
            hasCalibrationWork: false,
            lifetimeIsUnknown: false,
            firmwareIsUnknown: false,
            batteryIsDue: false
        ), .routineBounds)
    }

    @MainActor
    func testG7PositiveReadingsRemainSuppressedUntilWarmupCompletes() {
        let requiredMinutes = ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG7

        // These ages reproduce the positive 44, 71, 80, and 93 mg/dL packets from the field log.
        for sensorAgeInMinutes in [10.0, 15.0, 20.0, 25.0] {
            XCTAssertTrue(RootApplicationCoordinator.shouldSuppressReadingDuringWarmup(
                sensorAgeInSeconds: .minutes(sensorAgeInMinutes),
                minimumWarmUpRequiredInMinutes: requiredMinutes
            ))
        }

        XCTAssertFalse(RootApplicationCoordinator.shouldSuppressReadingDuringWarmup(
            sensorAgeInSeconds: .minutes(requiredMinutes),
            minimumWarmUpRequiredInMinutes: requiredMinutes
        ))
    }

    private func response(_ bytes: [UInt8]) -> DexcomG7CalibrationCommandResponse? {
        DexcomG7CalibrationCommandResponse(data: Data(bytes))
    }

    private func bounds(_ hex: String) throws -> DexcomG7CalibrationBounds {
        let data = try XCTUnwrap(Data(hexadecimalString: hex))
        return try XCTUnwrap(DexcomG7CalibrationBounds(data: data))
    }

    private func extendedVersion(_ hex: String) throws -> DexcomG7ExtendedVersionMessage {
        let data = try XCTUnwrap(Data(hexadecimalString: hex))
        return try XCTUnwrap(DexcomG7ExtendedVersionMessage(data: data))
    }
}
