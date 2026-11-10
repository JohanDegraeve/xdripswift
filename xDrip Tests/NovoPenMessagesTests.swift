//
//  NovoPenMessagesTests.swift
//  xdripTests
//
//  Ported from xDrip "OpenNov" by JamOrHam (NightscoutFoundation/xDrip, GPLv3).
//

import XCTest
@testable import xdrip

final class NovoPenMessagesTests: XCTestCase {
    /// segmentInfo with one more attribute (type 0x7FFF, 2 bytes) in front of the others.
    private func segmentInfoWithUnknownAttribute() -> Data {
        var frame = NovoPenFixtures.segmentInfo
        XCTAssertEqual(frame[25], 6, "attribute count of the segment")
        frame[25] = 7
        frame.insert(contentsOf: [0x7F, 0xFF, 0x00, 0x02, 0xAB, 0xCD], at: 28)   // 28 = first attribute
        return frame
    }

    // MARK: - Association and configuration

    func testAssociationRequest() throws {
        guard case .associationRequest(let r) = try NovoPenMessage.parse(NovoPenFixtures.aRequest).message else { return XCTFail() }
        XCTAssertTrue(r.isValid)
        XCTAssertEqual(r.systemId, Data(hexadecimalString: "001465004507b951"))
        XCTAssertEqual(r.configId, 0x400A)
        XCTAssertEqual(r.raw.count, 38)
    }

    func testAssociationRequestWithoutAPOEPElementIsNotValid() throws {
        // AARQ with one element of another protocol (0x1234, 2 bytes)
        let frame = Data(hexadecimalString: "e200000e" + "80000000" + "0001" + "0006" + "1234" + "0002" + "abcd")!
        guard case .associationRequest(let r) = try NovoPenMessage.parse(frame).message else { return XCTFail() }
        XCTAssertFalse(r.isValid)
    }

    func testConfiguration() throws {
        let parsed = try NovoPenMessage.parse(NovoPenFixtures.configReport)
        guard case .configuration(let c) = parsed.message else { return XCTFail() }
        XCTAssertEqual(parsed.invokeId, 0)
        XCTAssertTrue(c.isAsExpected)
        XCTAssertEqual(c.capacity, 800)
        XCTAssertEqual(c.configId, 0x400A)
        XCTAssertEqual(c.handle, 0, "the event report's handle, which the device info request needs")
        XCTAssertEqual(c.numberOfSegments, 1)
        XCTAssertEqual(c.storedEntries, 2)
        XCTAssertEqual(c.unitCode, 5472)
    }

    func testConfigurationWithOtherUnitIsNotAsExpected() throws {
        var frame = NovoPenFixtures.configReport
        let unit = frame.firstRange(of: Data([0x09, 0x96, 0x00, 0x02, 0x15, 0x60]))!   // unit code 5472
        frame[unit.upperBound - 1] = 0x61
        guard case .configuration(let c) = try NovoPenMessage.parse(frame).message else { return XCTFail() }
        XCTAssertFalse(c.isAsExpected)
    }

    // MARK: - Device info

    func testDeviceInfo() throws {
        let parsed = try NovoPenMessage.parse(NovoPenFixtures.deviceInfo)
        guard case .deviceInfo(let d) = parsed.message else { return XCTFail() }
        XCTAssertEqual(parsed.invokeId, 0)
        XCTAssertEqual(d.serial, "EGDO2U")
        XCTAssertEqual(d.model, "Novo Nordisk A/S NovoPen")
    }

    // MARK: - Segment info

    func testSegmentInfoTypical() throws {
        guard case .segmentInfo(let s) = try NovoPenMessage.parse(NovoPenFixtures.segmentInfo).message else { return XCTFail() }
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s[0].instance, 16)
        XCTAssertEqual(s[0].usage, 3)
        XCTAssertTrue(s[0].isTypical)
    }

    func testSegmentInfoUnknownAttributeDoesNotCrash() throws {
        guard case .segmentInfo(let s) = try NovoPenMessage.parse(segmentInfoWithUnknownAttribute()).message else { return XCTFail() }
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s[0].usage, 3)
        XCTAssertTrue(s[0].isTypical)
    }

    func testSegmentInfoWithOtherLayoutIsNotTypical() throws {
        var frame = NovoPenFixtures.segmentInfo
        let otype = frame.firstRange(of: Data([0x34, 0x01]))!   // first entry's object type 13313
        frame[otype.upperBound - 1] = 0x02
        guard case .segmentInfo(let s) = try NovoPenMessage.parse(frame).message else { return XCTFail() }
        XCTAssertFalse(s[0].isTypical)
    }

    func testTransferResult() throws {
        let parsed = try NovoPenMessage.parse(NovoPenFixtures.triggerResponse)
        guard case .transferResult(let segment, let response) = parsed.message else { return XCTFail() }
        XCTAssertEqual(segment, 16)
        XCTAssertEqual(response, 0)
        XCTAssertEqual(parsed.invokeId, 2)
    }

    // MARK: - Doses

    func testDoseReport() throws {
        let parsed = try NovoPenMessage.parse(NovoPenFixtures.doseReport)
        guard case .segmentData(let d) = parsed.message else { return XCTFail() }
        XCTAssertEqual(parsed.invokeId, 0x8001)
        XCTAssertEqual(d.instance, 16)
        XCTAssertEqual(d.index, 0)
        XCTAssertEqual(d.count, 3)
        XCTAssertEqual(d.eventRelativeTime, 116243)
        XCTAssertEqual(d.doses.map(\.units), [3.0, 2.0, nil])
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let records = d.doses.compactMap { $0.record(eventRelativeTime: d.eventRelativeTime, now: now) }
        XCTAssertEqual(records.map(\.units), [3.0, 2.0])   // dose 3: flags 0x04000008 -> skipped
        XCTAssertEqual(records[0].date, now.addingTimeInterval(-66))
        XCTAssertEqual(records[0].identifier(serial: "EGDO2U"), "EGDO2U:Open116177:3.0")
        XCTAssertEqual(records[1].identifier(serial: "EGDO2U"), "EGDO2U:Open331:2.0")
    }

    func testDoseNewerThanPenClockIsInvalid() {
        XCTAssertNil(NovoPenDose(relativeTime: 200, rawUnits: 0xFF00001E, flags: 0x08000000).record(eventRelativeTime: 100, now: Date()))
    }

    func testDoseOlderThanTwelveTimesThirtyDaysIsInvalid() {
        let limit: UInt32 = 12 * 30 * 24 * 3600
        let now = Date()
        let dose = NovoPenDose(relativeTime: 0, rawUnits: 0xFF00001E, flags: 0x08000000)
        XCTAssertNotNil(dose.record(eventRelativeTime: limit, now: now))
        XCTAssertNil(dose.record(eventRelativeTime: limit + 1, now: now))
    }

    func testUnitsAbove60AreInvalid() {
        XCTAssertNil(NovoPenDose(relativeTime: 0, rawUnits: 0xFF000262, flags: 0x08000000).units)   // 61.0
        XCTAssertEqual(NovoPenDose(relativeTime: 0, rawUnits: 0xFF000258, flags: 0x08000000).units, 60.0)
    }

    func testUnitsThatDoNotDecodeAreInvalid() {
        XCTAssertNil(NovoPenDose(relativeTime: 0, rawUnits: 0xFF000000, flags: 0x08000000).units, "0 U")
        XCTAssertNil(NovoPenDose(relativeTime: 0, rawUnits: 0x007FFFFF, flags: 0x08000000).units, "no 0xFF marker")
        XCTAssertEqual(NovoPenDose(relativeTime: 0, rawUnits: 0xFF000005, flags: 0x08000000).units, 0.5)
    }

    func testErrorEntryIsSkippedNotThrown() {
        XCTAssertNil(NovoPenDose(relativeTime: 0, rawUnits: 0xFF00001E, flags: 0x04000008).record(eventRelativeTime: 10, now: Date()))
    }

    func testTruncatedDoseListKeepsCompleteEntries() throws {
        guard case .segmentData(let d) = try NovoPenMessage.parse(NovoPenFixtures.doseReport.dropLast(4)).message else { return XCTFail() }
        XCTAssertEqual(d.doses.count, 2)
        XCTAssertEqual(d.count, 3)
    }

    func testDoseCountBeyondTheDataDoesNotRunAway() throws {
        var frame = NovoPenFixtures.doseReport
        frame.replaceSubrange(20..<24, with: [0xFF, 0xFF, 0xFF, 0xFF])   // count 4294967295
        guard case .segmentData(let d) = try NovoPenMessage.parse(frame).message else { return XCTFail() }
        XCTAssertEqual(d.doses.count, 3)
    }

    // MARK: - Frames without data

    func testReleaseAndEmpty() throws {
        func parse(_ hex: String) throws -> NovoPenMessage { try NovoPenMessage.parse(Data(hexadecimalString: hex)!).message }
        guard case .empty = try NovoPenMessage.parse(Data()).message else { return XCTFail("empty") }
        guard case .empty = try parse("e70000") else { return XCTFail("too short for an APDU") }
        guard case .releaseRequest = try parse("e40000020000") else { return XCTFail("release request") }
        guard case .releaseResponse = try parse("e50000020000") else { return XCTFail("release response") }
        guard case .abort = try parse("e6000002") else { return XCTFail("abort") }
        XCTAssertThrowsError(try NovoPenMessage.parse(Data(count: 4))) {
            guard case .badFrame? = $0 as? NovoPenError else { return XCTFail("\($0)") }
        }
    }

    func testFramesWeSendOrEchoAreNotInteresting() throws {
        for frame in [NovoPenFixtures.aResponse, NovoPenFixtures.acceptConfig, NovoPenFixtures.askInfo, NovoPenFixtures.getSegmentInfo,
                      NovoPenFixtures.triggerTransfer, NovoPenFixtures.segmentAck] {
            guard case .other = try NovoPenMessage.parse(frame).message else { return XCTFail(frame.hexEncodedString()) }
        }
    }

    // MARK: - Encoding

    func testAssociationResponseMatchesFixture() throws {
        guard case .associationRequest(let request) = try NovoPenMessage.parse(NovoPenFixtures.aRequest).message else { return XCTFail() }
        XCTAssertEqual(NovoPenEncoder.associationResponse(to: request), NovoPenFixtures.aResponse)
    }

    func testAssociationResponseEchoesTheAgentsSystemId() throws {
        let penId = Data(hexadecimalString: "001465004507b951")!, otherId = Data(hexadecimalString: "0102030405060708")!
        func replacingId(_ frame: Data) -> Data {
            var frame = frame
            frame.replaceSubrange(frame.firstRange(of: penId)!, with: otherId)
            return frame
        }
        guard case .associationRequest(let request) = try NovoPenMessage.parse(replacingId(NovoPenFixtures.aRequest)).message else { return XCTFail() }
        XCTAssertEqual(NovoPenEncoder.associationResponse(to: request), replacingId(NovoPenFixtures.aResponse))
    }

    func testEncodedFramesMatchFixtures() {
        XCTAssertEqual(NovoPenEncoder.acceptConfiguration(invokeId: 0, configId: 0x400A), NovoPenFixtures.acceptConfig)
        XCTAssertEqual(NovoPenEncoder.askInformation(invokeId: 0, handle: 0), NovoPenFixtures.askInfo)
        XCTAssertEqual(NovoPenEncoder.getSegmentInfo(invokeId: 1), NovoPenFixtures.getSegmentInfo)
        XCTAssertEqual(NovoPenEncoder.triggerTransfer(invokeId: 2, segment: 16), NovoPenFixtures.triggerTransfer)
        XCTAssertEqual(NovoPenEncoder.confirmSegmentData(invokeId: 0x8001, instance: 16, index: 0, count: 2), NovoPenFixtures.segmentAck)
        XCTAssertEqual(NovoPenEncoder.releaseRequest, Data(hexadecimalString: "e40000020000"))
    }

    func testEncodedFramesCarryTheirArguments() {
        // ask information addresses the event report's handle; the segment ack carries index and count as 32 bit numbers
        XCTAssertEqual(NovoPenEncoder.askInformation(invokeId: 7, handle: 0x1234).hexEncodedString(), "e700" + "000e" + "000c" + "0007" + "0103" + "0006" + "1234" + "0000" + "0000")
        XCTAssertEqual(NovoPenEncoder.confirmSegmentData(invokeId: 1, instance: 2, index: 0x0001_0203, count: 0x0405_0607).suffix(12).hexEncodedString(),
                       "0002" + "00010203" + "04050607" + "0080")
    }

    func testEncodedFramesParseAsFramesWeSend() throws {
        let frames: [(Data, UInt16?)] = [(NovoPenEncoder.acceptConfiguration(invokeId: 5, configId: 1), 5), (NovoPenEncoder.askInformation(invokeId: 6, handle: 0), 6),
                                         (NovoPenEncoder.getSegmentInfo(invokeId: 7), 7), (NovoPenEncoder.triggerTransfer(invokeId: 8, segment: 16), 8),
                                         (NovoPenEncoder.confirmSegmentData(invokeId: 9, instance: 16, index: 0, count: 2), 9)]
        for (frame, invokeId) in frames {
            let parsed = try NovoPenMessage.parse(frame)
            guard case .other = parsed.message else { return XCTFail(frame.hexEncodedString()) }
            XCTAssertEqual(parsed.invokeId, invokeId)
        }
        guard case .releaseRequest = try NovoPenMessage.parse(NovoPenEncoder.releaseRequest).message else { return XCTFail("release") }
    }

    func testTruncatedFramesThrowTruncated() {
        for frame in [Data(hexadecimalString: "e7000002")!, NovoPenFixtures.deviceInfo.dropLast(20), NovoPenFixtures.configReport.dropLast(20),
                      NovoPenFixtures.segmentInfo.dropLast(20), NovoPenFixtures.aRequest.dropLast(30)] {
            XCTAssertThrowsError(try NovoPenMessage.parse(frame)) { XCTAssertEqual($0 as? NovoPenError, .truncated) }
        }
    }
}
