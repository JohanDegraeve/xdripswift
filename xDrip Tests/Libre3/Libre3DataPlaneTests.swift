//
//  Libre3DataPlaneTests.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Tests/RoundWhiteDiscKitTests/DataPlaneTests.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import XCTest
@testable import xdrip

final class Libre3DataPlaneTests: XCTestCase {

    private func raw(_ hex: String) -> Data {
        Data(
            (0..<hex.count / 2).map { i in
                UInt8(hex[hex.index(hex.startIndex, offsetBy: i * 2)..<hex.index(hex.startIndex, offsetBy: i * 2 + 2)], radix: 16)!
            })
    }

    private func settingU16(_ data: Data, offset: Int, to value: UInt16) -> Data {
        var copy = data
        let i = copy.startIndex + offset
        copy[i] = UInt8(value & 0xff)
        copy[i + 1] = UInt8(value >> 8)
        return copy
    }

    func testDataFrameRoundTrip() throws {
        let body = Data([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0x07, 0x00])
        let frame = try Libre3DataFrame.parse(body)
        XCTAssertEqual(frame.encrypted, Data([0xaa, 0xbb, 0xcc, 0xdd, 0xee]))
        XCTAssertEqual(frame.seq, 0x07)
        XCTAssertEqual(frame.type, 0x00)
        XCTAssertEqual(frame.raw, body)
    }

    func testDataFrameTooShort() {
        XCTAssertThrowsError(try Libre3DataFrame.parse(Data([0x01]))) { err in
            guard case Libre3DataFrameError.tooShort(let n) = err else {
                XCTFail("wrong error \(err)")
                return
            }
            XCTAssertEqual(n, 1)
        }
    }

    func testRealtimeReadingFrameStructure() throws {
        // Captured 0x0014 notify from fresh_pair (rec 432, 18B body).
        let body = raw("9d7476cb096253cc0d492755b1caa0ad0100")
        let frame = try Libre3DataFrame.parse(body)
        XCTAssertEqual(frame.encrypted.count, 16, "realtime reading body is 16B encrypted")
        XCTAssertEqual(frame.seq, 0x01)
        XCTAssertEqual(frame.type, 0x00)
    }

    func testDataPlaneChannelMappingPinsLiveDescriptors() throws {
        XCTAssertEqual(
            Libre3DataPlaneChannel(uuidString: "08981482-EF89-11E9-81B4-2A2AE2DBCCE4"),
            .patchStatus
        )
        XCTAssertEqual(
            Libre3DataPlaneChannel(uuidString: "0898177A-EF89-11E9-81B4-2A2AE2DBCCE4"),
            .glucoseData
        )
        XCTAssertEqual(
            Libre3DataPlaneChannel(uuidString: "0898195A-EF89-11E9-81B4-2A2AE2DBCCE4"),
            .historicData
        )
        XCTAssertEqual(Libre3DataPlaneChannel.patchStatus.preferredInboundKind, .kind2)
        XCTAssertEqual(Libre3DataPlaneChannel.glucoseData.preferredInboundKind, .kind3)
        XCTAssertEqual(Libre3DataPlaneChannel.historicData.preferredInboundKind, .kind4)
    }

    func testLiveGlucoseDataFragmentsReassembleAndDecrypt() throws {
        let crypto = try Libre3DataPlaneCrypto(
            kEnc: raw("7c536d2ec3c76c741a776de85596959d"),
            ivEnc: raw("00000000bcc696a2")
        )
        let decoder = Libre3DataPlaneDecoder(crypto: crypto)
        let assembler = Libre3DataPlaneNotificationAssembler()
        let prefix = raw("3c937752c72e2dfdcfe05a5dce315b")
        let suffix = raw("6f3785f23dbc85066856d60027c5a41f45c90100")
        XCTAssertNil(assembler.feed(fragment: prefix, channel: .glucoseData))
        let rawFrame = try XCTUnwrap(assembler.feed(fragment: suffix, channel: .glucoseData))
        let frame = try Libre3DataFrame.parse(rawFrame)
        let packet = try decoder.decrypt(frame: frame, channel: .glucoseData)

        XCTAssertEqual(frame.sequenceNumber, 0x0001)
        XCTAssertEqual(packet.kind, .kind3)
        XCTAssertTrue(packet.usedPreferredKind)
        XCTAssertEqual(
            packet.plaintext.hex,
            "da386700e3ff0000ac26c73871000b670071001a0abf03f33c59100000"
        )
        guard case .realtimeGlucose(let reading) = packet.payload else {
            XCTFail("expected realtime glucose payload")
            return
        }
        XCTAssertEqual(reading.lifeCount, 14554)
        XCTAssertEqual(reading.currentGlucoseMgDL, .some(103))
    }

    func testLivePatchStatusDecryptsThroughChannelDecoder() throws {
        let crypto = try Libre3DataPlaneCrypto(
            kEnc: raw("7c536d2ec3c76c741a776de85596959d"),
            ivEnc: raw("00000000bcc696a2")
        )
        let frame = try Libre3DataFrame.parse(raw("4e6fe9573b6365476193e9c42009acd20100"))
        let packet = try Libre3DataPlaneDecoder(crypto: crypto).decrypt(frame: frame, channel: .patchStatus)

        XCTAssertEqual(frame.sequenceNumber, 0x0001)
        XCTAssertEqual(packet.kind, .kind2)
        XCTAssertEqual(packet.plaintext.hex, "9d280000e0000704db381607")
        guard case .patchStatus(let status) = packet.payload else {
            XCTFail("expected patch status payload")
            return
        }
        XCTAssertEqual(status.lifeCount, 10397)
        XCTAssertEqual(status.currentLifeCount, 14555)
        XCTAssertEqual(status.stackDisconnectReason, 22)
        XCTAssertEqual(status.appDisconnectReason, 7)
    }

    func testLiveHistoricalDataDecryptsThroughChannelDecoder() throws {
        let crypto = try Libre3DataPlaneCrypto(
            kEnc: raw("7c536d2ec3c76c741a776de85596959d"),
            ivEnc: raw("00000000bcc696a2")
        )
        let frame = try Libre3DataFrame.parse(raw("4637aa722274876d69a34f20096c49adced70100"))
        let packet = try Libre3DataPlaneDecoder(crypto: crypto).decrypt(frame: frame, channel: .historicData)

        XCTAssertEqual(frame.sequenceNumber, 0x0001)
        XCTAssertEqual(packet.kind, .kind4)
        XCTAssertEqual(packet.plaintext.hex, "98036d006b0069006e006a006500")
        guard case .historicalReadingPage(let page) = packet.payload else {
            XCTFail("expected historical page payload")
            return
        }
        XCTAssertEqual(page.startLifeCount, 920)
        XCTAssertEqual(page.values, [109, 107, 105, 110, 106, 101])
    }

    func testRealtimeGlucoseReadingParsesLivePlaintext() throws {
        let cases:
            [(
                hex: String,
                lifeCount: UInt16,
                glucose: UInt16,
                rateRaw: Int16,
                temp: UInt16,
                fastData: String,
                fastDataWords: [UInt16]
            )] = [
                ("e3386200d6ff0000f023d1386c000b62006c00200a9e03113d03100000", 14563, 98, -42, 2592, "9e03113d03100000", [0x039e, 0x3d11, 0x1003, 0x0000]),
                ("e4386200d6ff0000f023d1386c000b62006c001f0a9b03093d0b100000", 14564, 98, -42, 2591, "9b03093d0b100000", [0x039b, 0x3d09, 0x100b, 0x0000]),
                ("e5386100d9ff00008c23d1386c000b61006c001e0a9403053d12100000", 14565, 97, -39, 2590, "9403053d12100000", [0x0394, 0x3d05, 0x1012, 0x0000]),
                ("e6386100daff00008c23d1386c000b61006c001d0a9203003dfb0f0000", 14566, 97, -38, 2589, "9203003dfb0f0000", [0x0392, 0x3d00, 0x0ffb, 0x0000]),
            ]

        for c in cases {
            let reading = try Libre3RealtimeGlucoseReading(plaintext: raw(c.hex))
            XCTAssertEqual(reading.lifeCount, c.lifeCount)
            XCTAssertEqual(reading.currentWord, c.glucose)
            XCTAssertEqual(reading.readingMgDL, c.glucose)
            XCTAssertEqual(reading.dqErrorRaw, 0)
            XCTAssertEqual(reading.dqError, .good)
            XCTAssertEqual(reading.sensorConditionRaw, 0)
            XCTAssertEqual(reading.sensorCondition, .ok)
            XCTAssertEqual(reading.currentGlucoseMgDL, .some(c.glucose))
            XCTAssertTrue(reading.isCurrentGlucoseValid)
            XCTAssertTrue(reading.isCurrentDQGood)
            XCTAssertTrue(reading.isCurrentGlucoseUsable)
            XCTAssertEqual(reading.rateOfChangeRaw, c.rateRaw)
            XCTAssertEqual(
                try XCTUnwrap(reading.rateOfChangeMgDLPerMinute),
                Float(c.rateRaw) / 100.0,
                accuracy: 0.0001
            )
            XCTAssertEqual(reading.esaDuration, 0)
            XCTAssertEqual(reading.temperatureStatus, 0)
            XCTAssertEqual(reading.projectedGlucose, c.glucose == 98 ? 9200 : 9100)
            XCTAssertEqual(reading.historicalLifeCount, 14545)
            XCTAssertEqual(reading.historicalWord, 108)
            XCTAssertEqual(reading.historicalReading, 108)
            XCTAssertEqual(reading.historicalReadingDQErrorRaw, 0)
            XCTAssertEqual(reading.historicalReadingDQError, .good)
            XCTAssertEqual(reading.historicResultRangeStatusRaw, 0)
            XCTAssertEqual(reading.historicResultRangeStatus, .inRange)
            XCTAssertEqual(reading.historicalGlucoseMgDL, .some(108))
            XCTAssertTrue(reading.isHistoricalGlucoseValid)
            XCTAssertTrue(reading.isHistoricalDQGood)
            XCTAssertEqual(reading.trendAndStatusByte, 0x0b)
            XCTAssertEqual(reading.trendRaw, 3)
            XCTAssertEqual(reading.trend, 3)
            XCTAssertEqual(reading.trendKind, .stable)
            XCTAssertEqual(reading.rest, 1)
            XCTAssertEqual(reading.actionableStatus, 1)
            XCTAssertEqual(reading.actionability, .actionable)
            XCTAssertEqual(reading.uncappedCurrentMgDL, c.glucose)
            XCTAssertEqual(reading.uncappedHistoricMgDL, 108)
            XCTAssertEqual(reading.temperature, c.temp)
            XCTAssertEqual(reading.fastData.hex, c.fastData)
            XCTAssertEqual(reading.fastDataWordsLE, c.fastDataWords)
            XCTAssertEqual(reading.qualityEvidence.dqErrorRaw, 0)
            XCTAssertEqual(reading.qualityEvidence.dqError, .good)
            XCTAssertEqual(reading.qualityEvidence.historicalReadingDQErrorRaw, 0)
            XCTAssertEqual(reading.qualityEvidence.historicalReadingDQError, .good)
            XCTAssertEqual(reading.qualityEvidence.sensorConditionRaw, 0)
            XCTAssertEqual(reading.qualityEvidence.sensorCondition, .ok)
            XCTAssertEqual(reading.qualityEvidence.historicResultRangeStatusRaw, 0)
            XCTAssertEqual(reading.qualityEvidence.historicResultRangeStatus, .inRange)
            XCTAssertEqual(reading.qualityEvidence.actionableStatus, 1)
            XCTAssertEqual(reading.qualityEvidence.actionability, .actionable)
            XCTAssertEqual(reading.qualityEvidence.fastDataWordsLE, c.fastDataWords)
            XCTAssertEqual(reading.qualityEvidence.statusBits, 1)
            XCTAssertEqual(reading.qualityEvidence.trend, .stable)
            XCTAssertEqual(reading.qualityEvidence.currentGlucose, .valid(mgDL: c.glucose))
            XCTAssertEqual(reading.wordsLE[0], c.lifeCount)
            XCTAssertEqual(reading.wordsLE[1], c.glucose)
            XCTAssertEqual(reading.trailingByte, 0)
        }
    }

    func testRealtimeGlucoseReadingUsesCurrentNormalization() throws {
        let base = raw("e3386200d6ff0000f023d1386c000b62006c00200a9e03113d03100000")

        let low = try Libre3RealtimeGlucoseReading(plaintext: settingU16(base, offset: 15, to: 38))
        XCTAssertEqual(low.readingMgDL, 98)
        XCTAssertEqual(low.uncappedCurrentMgDL, 38)
        XCTAssertEqual(low.currentGlucoseMgDL, .some(39))
        XCTAssertEqual(low.currentGlucoseStatus, .belowDisplayRange(raw: 38, displayMgDL: 39))
        XCTAssertTrue(low.isCurrentGlucoseValid)

        let high = try Libre3RealtimeGlucoseReading(plaintext: settingU16(base, offset: 15, to: 600))
        XCTAssertEqual(high.uncappedCurrentMgDL, 600)
        XCTAssertEqual(high.currentGlucoseMgDL, .some(501))
        XCTAssertEqual(high.currentGlucoseStatus, .aboveDisplayRange(raw: 600, displayMgDL: 501))
        XCTAssertTrue(high.isCurrentGlucoseValid)

        let invalidZero = try Libre3RealtimeGlucoseReading(plaintext: settingU16(base, offset: 15, to: 0))
        XCTAssertNil(invalidZero.currentGlucoseMgDL)
        XCTAssertEqual(invalidZero.currentGlucoseStatus, .unavailable(raw: 0))
        XCTAssertFalse(invalidZero.isCurrentGlucoseValid)

        let invalidHigh = try Libre3RealtimeGlucoseReading(plaintext: settingU16(base, offset: 15, to: 1000))
        XCTAssertNil(invalidHigh.currentGlucoseMgDL)
        XCTAssertEqual(invalidHigh.currentGlucoseStatus, .unavailable(raw: 1000))
        XCTAssertFalse(invalidHigh.isCurrentGlucoseValid)
    }

    func testRealtimeGlucoseReadingParsesAbbottDQAndStatusBits() throws {
        let base = raw("e3386200d6ff0000f023d1386c000b62006c00200a9e03113d03100000")

        let currentDQ = try Libre3RealtimeGlucoseReading(plaintext: settingU16(base, offset: 2, to: 0x8062))
        XCTAssertEqual(currentDQ.readingMgDL, 98)
        XCTAssertEqual(currentDQ.dqErrorRaw, 0x8062)
        XCTAssertEqual(currentDQ.dqError, .notDisplayable(rawValue: 0x8062))
        XCTAssertEqual(currentDQ.sensorConditionRaw, 0)
        XCTAssertEqual(currentDQ.sensorCondition, .ok)
        XCTAssertFalse(currentDQ.isCurrentDQGood)
        XCTAssertFalse(currentDQ.isCurrentGlucoseUsable)

        let currentSensorCondition = try Libre3RealtimeGlucoseReading(plaintext: settingU16(base, offset: 2, to: 0x2062))
        XCTAssertEqual(currentSensorCondition.readingMgDL, 98)
        XCTAssertEqual(currentSensorCondition.dqErrorRaw, 0)
        XCTAssertEqual(currentSensorCondition.dqError, .good)
        XCTAssertEqual(currentSensorCondition.sensorConditionRaw, 1)
        XCTAssertEqual(currentSensorCondition.sensorCondition, .invalid)
        XCTAssertFalse(currentSensorCondition.isCurrentDQGood)

        let historicalDQ = try Libre3RealtimeGlucoseReading(plaintext: settingU16(base, offset: 12, to: 0x806c))
        XCTAssertEqual(historicalDQ.historicalReading, 108)
        XCTAssertEqual(historicalDQ.historicalReadingDQErrorRaw, 0x806c)
        XCTAssertEqual(historicalDQ.historicalReadingDQError, .notDisplayable(rawValue: 0x806c))
        XCTAssertEqual(historicalDQ.historicResultRangeStatusRaw, 0)
        XCTAssertEqual(historicalDQ.historicResultRangeStatus, .inRange)
        XCTAssertFalse(historicalDQ.isHistoricalDQGood)

        let historicalRange = try Libre3RealtimeGlucoseReading(plaintext: settingU16(base, offset: 12, to: 0x406c))
        XCTAssertEqual(historicalRange.historicalReading, 108)
        XCTAssertEqual(historicalRange.historicalReadingDQErrorRaw, 0)
        XCTAssertEqual(historicalRange.historicalReadingDQError, .good)
        XCTAssertEqual(historicalRange.historicResultRangeStatusRaw, 2)
        XCTAssertEqual(historicalRange.historicResultRangeStatus, .aboveRange)
        XCTAssertFalse(historicalRange.isHistoricalDQGood)

        var notActionablePayload = base
        notActionablePayload[notActionablePayload.startIndex + 14] = 0x03
        let notActionable = try Libre3RealtimeGlucoseReading(plaintext: notActionablePayload)
        XCTAssertEqual(notActionable.trend, 3)
        XCTAssertEqual(notActionable.trendKind, .stable)
        XCTAssertEqual(notActionable.actionableStatus, 0)
        XCTAssertEqual(notActionable.actionability, .notActionable)
        // Actionability is advisory: an otherwise-clean non-actionable reading
        // stays usable.
        XCTAssertTrue(notActionable.isCurrentGlucoseUsable)

        let temperatureStatus = try Libre3RealtimeGlucoseReading(plaintext: settingU16(base, offset: 6, to: 0x0201))
        XCTAssertEqual(temperatureStatus.temperatureStatus, 0x0201)
    }

    func testPatchStatusParsesLivePlaintext() throws {
        let status = try Libre3PatchStatus(plaintext: raw("9d280000e0000704e4381300"))

        XCTAssertEqual(status.lifeCount, 10397)
        XCTAssertEqual(status.errorData, 0)
        XCTAssertEqual(status.eventDataRaw, 224)
        XCTAssertEqual(status.eventData, 4224)
        XCTAssertEqual(status.index, 7)
        XCTAssertEqual(status.totalEvents, 8)
        XCTAssertEqual(status.patchState, 4)
        XCTAssertEqual(status.patchStateKind, .active)
        XCTAssertEqual(status.currentLifeCount, 14564)
        XCTAssertEqual(status.stackDisconnectReason, 19)
        XCTAssertEqual(status.appDisconnectReason, 0)
        XCTAssertFalse(status.hasErrorData)
        XCTAssertTrue(status.hasDisconnectReason)
        XCTAssertEqual(status.sensorError, .none)
        XCTAssertFalse(status.isShutdownTerminated)
        XCTAssertFalse(status.isInsertionFailure)

        let lifecycle = status.lifecycle(wearDurationMinutes: 20160)
        XCTAssertEqual(lifecycle.phase, .active)
        XCTAssertTrue(lifecycle.isWarmupComplete)
        XCTAssertFalse(lifecycle.isExpired)
        XCTAssertEqual(lifecycle.remainingWearMinutes, 5596)
    }

    func testPatchStatusDecodesSensorErrorCodes() throws {
        // Synthetic frames: the healthy live frame with only the errorData
        // word (offset 2-3, LE) swapped.
        func status(errorWord hex: String) throws -> Libre3PatchStatus {
            try Libre3PatchStatus(plaintext: raw("9d28" + hex + "e0000704e4381300"))
        }

        XCTAssertEqual(try status(errorWord: "0000").sensorError, .none)
        XCTAssertEqual(try status(errorWord: "0300").sensorError, .insertionFailure)
        XCTAssertEqual(try status(errorWord: "0500").sensorError, .expired)
        XCTAssertEqual(try status(errorWord: "0600").sensorError, .terminated)
        XCTAssertEqual(try status(errorWord: "0700").sensorError, .transmissionError)
        XCTAssertEqual(try status(errorWord: "0800").sensorError, .terminated)
        XCTAssertEqual(try status(errorWord: "0900").sensorError, .unknown(9))

        XCTAssertEqual(try status(errorWord: "0000").sensorAttention, .none)
        XCTAssertEqual(try status(errorWord: "0300").sensorAttention, .checkSensor)
        XCTAssertEqual(try status(errorWord: "0500").sensorAttention, .sensorEnded)
        XCTAssertEqual(try status(errorWord: "0600").sensorAttention, .sensorEnded)
        XCTAssertEqual(try status(errorWord: "0700").sensorAttention, .checkSensor)
        XCTAssertEqual(try status(errorWord: "0800").sensorAttention, .replaceSensor)
        XCTAssertEqual(try status(errorWord: "0900").sensorAttention, .unknown(9))
        // Code 7 is a transient transmission error: notifies the user (soft
        // check-sensor) but is NOT a replace condition. Code 8 is the terminal replace.
        XCTAssertFalse(try status(errorWord: "0700").shouldNotifyReplaceSensor)
        XCTAssertTrue(try status(errorWord: "0700").shouldNotifyUser)
        XCTAssertTrue(try status(errorWord: "0800").shouldNotifyReplaceSensor)
        XCTAssertFalse(try status(errorWord: "0500").shouldNotifyReplaceSensor)
        XCTAssertTrue(try status(errorWord: "0300").shouldNotifyUser)
        XCTAssertFalse(try status(errorWord: "0000").shouldNotifyUser)

        // Expiry remains BLE-visible until shutdown, terminated is the
        // post-shutdown/no-advertising state. Insertion failure is separate.
        XCTAssertTrue(try status(errorWord: "0300").isInsertionFailure)
        XCTAssertFalse(try status(errorWord: "0000").isInsertionFailure)
        XCTAssertFalse(try status(errorWord: "0500").isInsertionFailure)
        XCTAssertFalse(try status(errorWord: "0600").isInsertionFailure)
        XCTAssertFalse(try status(errorWord: "0700").isInsertionFailure)
        XCTAssertFalse(try status(errorWord: "0800").isInsertionFailure)
        XCTAssertFalse(try status(errorWord: "0900").isInsertionFailure)

        XCTAssertTrue(try status(errorWord: "0600").isShutdownTerminated)
        XCTAssertTrue(try status(errorWord: "0800").isShutdownTerminated)
        XCTAssertFalse(try status(errorWord: "0000").isShutdownTerminated)
        XCTAssertFalse(try status(errorWord: "0300").isShutdownTerminated)
        XCTAssertFalse(try status(errorWord: "0500").isShutdownTerminated)
        XCTAssertFalse(try status(errorWord: "0700").isShutdownTerminated)
        XCTAssertFalse(try status(errorWord: "0900").isShutdownTerminated)
    }

    func testPatchStatusExposesPatchStateGroups() throws {
        func status(patchState: UInt8) throws -> Libre3PatchStatus {
            var bytes = raw("9d280000e0000704e4381300")
            bytes[bytes.startIndex + 7] = patchState
            return try Libre3PatchStatus(plaintext: bytes)
        }

        let active = try status(patchState: 4)
        XCTAssertEqual(active.patchStateKind, .active)
        XCTAssertEqual(active.patchStateKind.rawValue, 4)
        XCTAssertTrue(active.isPatchStateActive)
        XCTAssertFalse(active.isPatchStateExpiredOrError)
        XCTAssertFalse(active.isPatchStateTerminated)

        for state in [UInt8(3), 5, 7] {
            let value = try status(patchState: state)
            XCTAssertEqual(value.patchStateKind, .raw(Int8(bitPattern: state)))
            XCTAssertFalse(value.isPatchStateActive)
            XCTAssertTrue(value.isPatchStateExpiredOrError)
            XCTAssertFalse(value.isPatchStateTerminated)
        }

        XCTAssertEqual(try status(patchState: 3).sensorAttention, .checkSensor)
        XCTAssertEqual(try status(patchState: 5).sensorAttention, .sensorEnded)
        XCTAssertEqual(try status(patchState: 6).sensorAttention, .sensorEnded)
        XCTAssertEqual(try status(patchState: 7).sensorAttention, .replaceSensor)
        XCTAssertEqual(try status(patchState: 8).sensorAttention, .replaceSensor)
        XCTAssertTrue(try status(patchState: 7).shouldNotifyReplaceSensor)

        for state in [UInt8(6), 8] {
            let value = try status(patchState: state)
            XCTAssertEqual(value.patchStateKind, .raw(Int8(bitPattern: state)))
            XCTAssertFalse(value.isPatchStateActive)
            XCTAssertFalse(value.isPatchStateExpiredOrError)
            XCTAssertTrue(value.isPatchStateTerminated)
        }

        let unknown = try status(patchState: 9)
        XCTAssertEqual(unknown.patchStateKind, .raw(9))
        XCTAssertFalse(unknown.isPatchStateActive)
        XCTAssertFalse(unknown.isPatchStateExpiredOrError)
        XCTAssertFalse(unknown.isPatchStateTerminated)
    }

    func testLifecycleTakesWarmupAndWearFromPatchInfo() throws {
        // 12-minute-old sensor: still in warmup when warmup is the patchInfo
        // value of 60 (would already be "active" under a smaller default).
        let status = try Libre3PatchStatus(plaintext: raw("0c000000000000040c000000"))
        XCTAssertEqual(status.currentLifeCount, 12)

        let patchInfo = try Libre3NFCPatchInfo(
            raw: raw("00a50001000200010060541e020401040c04305252433938394151c6ca")
        )
        XCTAssertEqual(patchInfo.warmupMinutes, 60)
        XCTAssertEqual(patchInfo.wearDurationMinutes, 21600)

        let lifecycle = status.lifecycle(patchInfo: patchInfo)
        XCTAssertEqual(lifecycle.warmupDurationMinutes, 60)
        XCTAssertEqual(lifecycle.wearDurationMinutes, 21600)
        XCTAssertEqual(lifecycle.phase, .warmup)
        XCTAssertTrue(lifecycle.isWarmingUp)
        XCTAssertEqual(lifecycle.remainingWarmupMinutes, 48)
        XCTAssertEqual(lifecycle.remainingWearMinutes, 21588)

        let state = Libre3DataPlaneState(patchInfo: patchInfo, latestPatchStatus: status)
        XCTAssertEqual(state.warmupDurationMinutes, 60)
        XCTAssertEqual(state.wearDurationMinutes, 21600)
        XCTAssertEqual(state.lifecyclePhase, .warmup)
        XCTAssertTrue(state.isInWarmup)
        XCTAssertEqual(state.latestLifecycle?.remainingWarmupMinutes, 48)
        XCTAssertEqual(state.latestSensorAttention, .none)
        XCTAssertFalse(state.shouldNotifyUser)
        XCTAssertFalse(state.shouldNotifyReplaceSensor)

        // errorData 8 (terminated) is a genuine terminal replace. Code 7 is a
        // transient transmission error and maps to checkSensor, not replace.
        let replaceStatus = try Libre3PatchStatus(plaintext: raw("0c000800000000040c000000"))
        let replaceState = Libre3DataPlaneState(patchInfo: patchInfo, latestPatchStatus: replaceStatus)
        XCTAssertEqual(replaceState.latestSensorAttention, .replaceSensor)
        XCTAssertTrue(replaceState.shouldNotifyUser)
        XCTAssertTrue(replaceState.shouldNotifyReplaceSensor)

        // errorData 7 is a transient transmission error: a soft check-sensor
        // attention that notifies but is NOT a replace condition.
        let transientStatus = try Libre3PatchStatus(plaintext: raw("0c000700000000040c000000"))
        let transientState = Libre3DataPlaneState(patchInfo: patchInfo, latestPatchStatus: transientStatus)
        XCTAssertEqual(transientState.latestSensorAttention, .checkSensor)
        XCTAssertTrue(transientState.shouldNotifyUser)
        XCTAssertFalse(transientState.shouldNotifyReplaceSensor)
    }

    func testSessionControlFrames() throws {
        // 0x0011 traffic from fresh_pair (recs 433, 437, 438, 453).
        // Variable encrypted length but consistent (seq, type) trailer.
        let cases: [(hex: String, expectedEnc: Int, expectedSeq: UInt8, expectedType: UInt8)] = [
            ("ed7df1f64812b45afa57010100", 11, 0x01, 0x00),
            ("665f5b31bd9f9add0100", 8, 0x01, 0x00),
            ("0fdf3ccfe55e0045cb71920200", 11, 0x02, 0x00),
            ("d4d552d97bd404680200", 8, 0x02, 0x00),
        ]
        for c in cases {
            let frame = try Libre3DataFrame.parse(raw(c.hex))
            XCTAssertEqual(frame.encrypted.count, c.expectedEnc, "case \(c.hex)")
            XCTAssertEqual(frame.seq, c.expectedSeq, "case \(c.hex)")
            XCTAssertEqual(frame.type, c.expectedType, "case \(c.hex)")
        }
    }

    func testDataPlaneNonceUsesSequenceDescriptorAndPhase6IV() throws {
        let crypto = try Libre3DataPlaneCrypto(
            kEnc: raw("4bbce496a63cc9a435adeeb4f78e1617"),
            ivEnc: raw("0000000067c72c01")
        )

        XCTAssertEqual(
            crypto.nonce(sequence: 0x0001, kind: .patchData).hex,
            "01004400000000000067c72c01"
        )
    }

    func testDataPlaneCryptoRoundTripsAndFindsDescriptor() throws {
        let crypto = try Libre3DataPlaneCrypto(
            kEnc: raw("4bbce496a63cc9a435adeeb4f78e1617"),
            ivEnc: raw("0000000067c72c01")
        )
        let plaintext = raw("00112233445566778899aabb")
        let frame = try crypto.encrypt(
            plaintext: plaintext,
            sequence: 0x0201,
            kind: .patchData
        )

        XCTAssertEqual(frame.seq, 0x01)
        XCTAssertEqual(frame.type, 0x02)
        XCTAssertEqual(frame.sequenceNumber, 0x0201)
        XCTAssertEqual(try crypto.decrypt(frame, kind: .patchData), plaintext)

        let found = try crypto.decryptTryingAllKinds(frame)
        XCTAssertEqual(found.kind, .patchData)
        XCTAssertEqual(found.plaintext, plaintext)

        XCTAssertThrowsError(try crypto.decrypt(frame, kind: .kind0)) { error in
            guard case Libre3AESCCMError.macMismatch = error else {
                XCTFail("expected macMismatch, got \(error)")
                return
            }
        }
    }

    func testPatchControlCommandPlaintextsMatchIOSBuilders() throws {
        XCTAssertEqual(
            Libre3PatchControlCommand.historicalBackfillGreaterEqual(lifeCount: 5).plaintext.hex,
            "01000105000000"
        )
        XCTAssertEqual(
            Libre3PatchControlCommand.clinicalBackfillGreaterEqual(lifeCount: 1).plaintext.hex,
            "01010101000000"
        )
        XCTAssertEqual(
            Libre3PatchControlCommand.backfillGreaterEqual(stream: .historical, lifeCount: 907).plaintext.hex,
            "0100018b030000"
        )
        XCTAssertEqual(
            Libre3PatchControlCommand.eventLog(index: 1).plaintext.hex,
            "04010000000000"
        )
        XCTAssertEqual(
            Libre3PatchControlCommand.factoryData().plaintext.hex,
            "06000000000000"
        )
        XCTAssertEqual(
            Libre3PatchControlCommand.shutdownPatch().plaintext.hex,
            "05000000000000"
        )
        XCTAssertThrowsError(try Libre3PatchControlCommand(label: "bad", plaintext: Data([0x01]))) { error in
            guard case Libre3PatchControlCommandError.wrongPlaintextSize(let size) = error else {
                XCTFail("expected wrongPlaintextSize, got \(error)")
                return
            }
            XCTAssertEqual(size, 1)
        }
    }

    func testPatchControlCommandEncryptsTo13ByteWriteFrame() throws {
        let crypto = try Libre3DataPlaneCrypto(
            kEnc: raw("4bbce496a63cc9a435adeeb4f78e1617"),
            ivEnc: raw("0000000067c72c01")
        )
        let command = Libre3PatchControlCommand.historicalBackfillGreaterEqual(lifeCount: 5)
        let frame = try crypto.encrypt(
            plaintext: command.plaintext,
            sequence: 0x0001,
            kind: .patchControlWrite
        )

        XCTAssertEqual(frame.raw.count, 13)
        XCTAssertEqual(frame.encrypted.count, 11)
        XCTAssertEqual(frame.seq, 0x01)
        XCTAssertEqual(frame.type, 0x00)
        XCTAssertEqual(try crypto.decrypt(frame, kind: .patchControlWrite), command.plaintext)
    }

    func testHistoricalReadingPageParsesLivePlaintext() throws {
        let page = try Libre3HistoricalReadingPage(plaintext: raw("8e0369006b006d006b0069006e00"))

        XCTAssertEqual(page.startLifeCount, 910)
        XCTAssertEqual(page.endLifeCount, 935)
        XCTAssertEqual(page.values, [105, 107, 109, 107, 105, 110])
        XCTAssertEqual(
            page.samples,
            [
                Libre3HistoricalReadingSample(lifeCount: 910, rawValue: 105),
                Libre3HistoricalReadingSample(lifeCount: 915, rawValue: 107),
                Libre3HistoricalReadingSample(lifeCount: 920, rawValue: 109),
                Libre3HistoricalReadingSample(lifeCount: 925, rawValue: 107),
                Libre3HistoricalReadingSample(lifeCount: 930, rawValue: 105),
                Libre3HistoricalReadingSample(lifeCount: 935, rawValue: 110),
            ]
        )
        XCTAssertEqual(page.samples[0].glucoseMgDL, 105)
        XCTAssertEqual(page.samples[0].glucoseStatus, .valid(mgDL: 105))
    }

    func testHistoricalBackfillSummarizesCoverageAndGaps() throws {
        let first = try Libre3HistoricalReadingPage(plaintext: raw("8e0369006b006d006b0069006e00"))
        let second = try Libre3HistoricalReadingPage(plaintext: raw("ac036f00710070006c006a006b00"))
        let third = try Libre3HistoricalReadingPage(plaintext: raw("e803780079007a007b007c007d00"))

        var backfill = Libre3HistoricalBackfill()
        backfill.append(second)
        backfill.append(first)

        XCTAssertEqual(backfill.firstLifeCount, 910)
        XCTAssertEqual(backfill.lastLifeCount, 965)
        XCTAssertTrue(backfill.isContiguous)
        XCTAssertEqual(backfill.gaps, [])
        XCTAssertEqual(backfill.samples.map(\.lifeCount), [910, 915, 920, 925, 930, 935, 940, 945, 950, 955, 960, 965])

        backfill.append(third)
        XCTAssertFalse(backfill.isContiguous)
        XCTAssertEqual(backfill.gaps, [Libre3HistoricalBackfillGap(afterLifeCount: 965, beforeLifeCount: 1000)])
    }
}
