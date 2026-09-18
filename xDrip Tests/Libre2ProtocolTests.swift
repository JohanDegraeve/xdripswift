import Foundation
import XCTest
@testable import xdrip

final class Libre2ProtocolTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
    private let uid = Data(hexadecimalString: "e3a18e0100a407e0")!
    private let encryptedFrame = Data(hexadecimalString: "ebb86eb952942ce055278df46b68ba1eacd3c78c7e800ea3890c61116679c2a3fcc220a95571ff760207682942f0")!

    private var calibration: Libre1DerivedAlgorithmParameters {
        Libre1DerivedAlgorithmParameters(slope_slope: 0, slope_offset: 0,
            offset_slope: 0.1, offset_offset: 0, isValidForFooterWithReverseCRCs: 0,
            extraSlope: 1, extraOffset: 0, sensorSerialNumber: "test")
    }

    // Seven sparse samples from a rising signal; temperature is constant at 6000.
    private func frame(age: Int, latest: Int? = nil) -> Data {
        var data = Data(repeating: 0, count: 44)
        for (sample, offset) in [0, 2, 4, 6, 7, 12, 15].enumerated() {
            let raw = sample == 0 ? latest ?? (1000 + age) : 1000 + age - offset
            let word = UInt32(raw) | (UInt32(6000 / 4) << 14)
            for byte in 0..<4 {
                data[sample * 4 + byte] = UInt8(truncatingIfNeeded: word >> (8 * byte))
            }
        }
        data[40] = UInt8(truncatingIfNeeded: age)
        data[41] = UInt8(truncatingIfNeeded: age >> 8)
        return data
    }

    private func parse(_ data: Data, state: inout Libre2BLEUtilities.ParserState) -> [GlucoseData] {
        Libre2BLEUtilities.parseBLEData(data, libre1DerivedAlgorithmParameters: calibration,
            state: &state, date: date).bleGlucose
    }

    func testDecryptsCapturedUpstreamFrame() throws {
        XCTAssertEqual(Data(try Libre2BLEUtilities.decryptBLE(sensorUID: uid, data: encryptedFrame)),
            Data(hexadecimalString: "8802ee85a082f485ab420086bac21786c80217860903e38529c3b78121c3b781e8c2af812643b2851b03168b"))
        var corrupt = encryptedFrame
        corrupt[12] ^= 1
        XCTAssertThrowsError(try Libre2BLEUtilities.decryptBLE(sensorUID: uid, data: corrupt))
    }

    func testUnlockMatchesUpstreamVector() {
        XCTAssertEqual(Data(Libre2BLEUtilities.streamingUnlockPayload(sensorUID: uid,
            info: Data(hexadecimalString: "9d0830017317")!, enableTime: 42, unlockCount: 18)),
            Data(hexadecimalString: "3c00000073e808168a009e02"))
    }

    func testSparseFrameKeepsOnlyShortInterpolatedGaps() {
        var state = Libre2BLEUtilities.ParserState()
        let result = Libre2BLEUtilities.parseBLEData(frame(age: 100),
            libre1DerivedAlgorithmParameters: calibration, state: &state, date: date)
        XCTAssertEqual(result.sensorTimeInMinutes, 100)
        XCTAssertEqual(result.bleGlucose.map { Int(date.timeIntervalSince($0.timeStamp) / 60) },
            [0, 1, 2, 3, 4, 5, 6, 7, 12, 15])
        for reading in result.bleGlucose {
            let age = date.timeIntervalSince(reading.timeStamp) / 60
            XCTAssertEqual(reading.glucoseLevelRaw, (1100 - age) * 0.1, accuracy: 0.000001)
        }
    }

    func testRepeatedFrameLeavesHistoryUnchanged() {
        var state = Libre2BLEUtilities.ParserState()
        XCTAssertFalse(parse(frame(age: 100), state: &state).isEmpty)
        let previous = state
        XCTAssertTrue(parse(frame(age: 100), state: &state).isEmpty)
        XCTAssertEqual(state, previous)
    }

    func testOverlapExtendsHistoryAndRemainsBounded() {
        var state = Libre2BLEUtilities.ParserState()
        for age in 100..<140 {
            XCTAssertFalse(parse(frame(age: age), state: &state).isEmpty)
            XCTAssertLessThanOrEqual(state.previousRawGlucoseValues!.count, 24)
            XCTAssertEqual(state.previousRawGlucoseValues!.count, state.previousRawTemperatureValues!.count)
            XCTAssertEqual(state.previousRawGlucoseValues!.count, state.previousTemperatureAdjustmentValues!.count)
        }
        XCTAssertGreaterThan(state.previousRawGlucoseValues!.count, 16)
    }

    func testParserStateDoesNotLeakBetweenSensors() {
        var first = Libre2BLEUtilities.ParserState()
        var second = Libre2BLEUtilities.ParserState()
        _ = parse(frame(age: 100), state: &first)
        XCTAssertTrue(parse(frame(age: 100), state: &first).isEmpty)
        XCTAssertFalse(parse(frame(age: 100), state: &second).isEmpty)
    }

    func testInconsistentCachedArraysAreNotUsedForOverlap() {
        var invalid = Libre2BLEUtilities.ParserState(previousRawGlucoseValues: [1, 2, 3],
            previousRawTemperatureValues: [4], previousTemperatureAdjustmentValues: nil)
        var empty = Libre2BLEUtilities.ParserState()
        XCTAssertEqual(parse(frame(age: 100), state: &invalid).map(\.glucoseLevelRaw),
            parse(frame(age: 100), state: &empty).map(\.glucoseLevelRaw))
        XCTAssertEqual(invalid, empty)
    }

    func testMissingLatestPreservesUpstreamHistoryUpdate() {
        var state = Libre2BLEUtilities.ParserState()
        XCTAssertTrue(parse(frame(age: 100, latest: 0), state: &state).isEmpty)
        XCTAssertEqual(state.previousRawGlucoseValues?.first, 0)
    }

    func testUncalibratedPathUsesOriginalRawMultiplier() {
        var state = Libre2BLEUtilities.ParserState()
        let result = Libre2BLEUtilities.parseBLEData(frame(age: 100),
            libre1DerivedAlgorithmParameters: nil, state: &state, date: date)
        XCTAssertEqual(result.bleGlucose.first!.glucoseLevelRaw, 1100 * ConstantsBloodGlucose.libreMultiplier)
    }

    func testPhonePersistenceMatchesExplicitStateAcrossRecreation() throws {
        let suite = "Libre2ProtocolTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var state = Libre2BLEUtilities.ParserState()
        for age in [100, 101, 102, 102, 109] {
            // Recreate the preferences object to exercise the existing persistent history keys.
            let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
            let phone = Libre2BLEUtilities.parseBLEData(frame(age: age),
                libre1DerivedAlgorithmParameters: calibration, defaults: reopened, date: date)
            let shared = parse(frame(age: age), state: &state)
            XCTAssertEqual(phone.bleGlucose.map(\.glucoseLevelRaw), shared.map(\.glucoseLevelRaw))
            XCTAssertEqual(phone.bleGlucose.map(\.timeStamp), shared.map(\.timeStamp))
            XCTAssertEqual(reopened.previousRawGlucoseValues, state.previousRawGlucoseValues)
            XCTAssertEqual(reopened.previousRawTemperatureValues, state.previousRawTemperatureValues)
            XCTAssertEqual(reopened.previousTemperatureAdjustmentValues, state.previousTemperatureAdjustmentValues)
        }
    }
}
