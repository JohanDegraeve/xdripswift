//
//  NovoPenLinkLayerTests.swift
//  xdripTests
//
//  Ported from xDrip "OpenNov" by JamOrHam (NightscoutFoundation/xDrip, GPLv3).
//

import XCTest
@testable import xdrip

final class NovoPenLinkLayerTests: XCTestCase {
    /// Hex with spaces, as written in the Android tests.
    private func hex(_ string: String) -> Data {
        Data(hexadecimalString: string.filter { !$0.isWhitespace })!
    }

    // MARK: - Byte helpers

    func testByteReaderIsBigEndianAndBounded() throws {
        var r = NovoPenByteReader(Data([0x12, 0x34, 0x56]))
        XCTAssertEqual(try r.u16(), 0x1234)
        XCTAssertThrowsError(try r.u16()) { XCTAssertEqual($0 as? NovoPenError, .truncated) }
        XCTAssertEqual(r.remaining, 1, "a failed read must not consume")
        XCTAssertEqual(try r.u8(), 0x56)
        XCTAssertThrowsError(try r.u8())
    }

    func testByteReaderU32AndBytesOnSlice() throws {
        // a slice has a non-zero startIndex, the reader must not care
        let slice = Data([0xFF, 0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02]).dropFirst()
        var r = NovoPenByteReader(slice)
        XCTAssertEqual(try r.u32(), 0xDEADBEEF)
        XCTAssertEqual(try r.bytes(2), Data([0x01, 0x02]))
        XCTAssertEqual(r.remaining, 0)
        XCTAssertThrowsError(try r.bytes(1))
        XCTAssertThrowsError(try r.bytes(-1))
    }

    func testByteWriterIsBigEndian() {
        var w = NovoPenByteWriter()
        w.u8(0x01); w.u16(0x0203); w.u32(0x04050607); w.bytes(Data([0x08, 0x09]))
        XCTAssertEqual(w.data, hex("01 0203 04050607 0809"))
    }

    // MARK: - T4 APDUs (T4SelectTest, T4ReadTest, T4UpdateTest)

    func testSelects() {
        XCTAssertEqual(T4.selectApp(), Data(hexadecimalString: "00A4040007D276000085010100"))
        XCTAssertEqual(T4.selectCapabilityContainer(), Data(hexadecimalString: "00A4000C02E103"))
        XCTAssertEqual(T4.selectNDEF(), Data(hexadecimalString: "00A4000C02E104"))
    }

    func testReadsChunkByMtu() {
        XCTAssertEqual(T4.reads(offset: 2, length: 259, mtu: 255),
                       ["00B00002FF", "00B0010104"].map { Data(hexadecimalString: $0)! })
    }

    func testReadsEdgeCases() {
        XCTAssertEqual(T4.reads(offset: 0, length: 2, mtu: 255), [hex("00B0000002")])
        XCTAssertEqual(T4.reads(offset: 0, length: 0, mtu: 255), [])
        XCTAssertEqual(T4.reads(offset: 0, length: 10, mtu: 0), [], "a zero mtu must not loop forever")
        // the Le byte can never exceed 255, whatever mtu the tag claims
        XCTAssertEqual(T4.reads(offset: 0, length: 300, mtu: 1000), [hex("00B00000FF"), hex("00B000FF2D")])
    }

    func testUpdateSinglePacket() {
        let payload = Data((0..<200).map { UInt8($0) })
        XCTAssertEqual(T4.update(payload), hex("00D60000CA00C8") + payload)
        XCTAssertEqual(T4.update(Data()), hex("00D6000002" + "0000"))
    }

    // MARK: - Capability container

    func testCapabilityContainer() throws {
        let cc = try T4CapabilityContainer(Data(hexadecimalString: "000F2000FF00F60406E10400FF00FF")!)
        XCTAssertEqual(cc.mleMax, 0xFF)
        XCTAssertEqual(cc.mlcMax, 0xF6)
        XCTAssertThrowsError(try T4CapabilityContainer(Data(count: 14)))
        XCTAssertThrowsError(try T4CapabilityContainer(Data(count: 16)))
    }

    // MARK: - PHD framing (PHDllTest)

    func testPHDEncode() {
        XCTAssertEqual(PHD.encode(Data(hexadecimalString: "0E0F1011121314")!, sequence: 7),
                       Data(hexadecimalString: "D10308504844870E0F1011121314"))
        XCTAssertEqual(PHD.encode(Data(), sequence: 0x17), hex("D1 03 01 50 48 44 87"), "sequence is masked to 4 bits")
    }

    func testPHDEmptyAck() {
        XCTAssertEqual(PHD.emptyAck, hex("D00000"))
    }

    func testPHDRoundTrip() throws {
        let inner = Data([14, 15, 16, 17, 18, 19, 20])
        let decoded = try PHD.decode(PHD.encode(inner, sequence: 7))
        XCTAssertEqual(decoded.sequence, 7)
        XCTAssertEqual(decoded.inner, inner)
    }

    func testPHDDecodeLongRecord() throws {
        let inner = hex("""
            E7 00 00 F8 00 F6 80 01 01 01 00 F0 01 00 00 09
            04 52 0D 21 00 E6 00 10 00 00 00 00 00 00 00 12
            80 00 00 D8 00 08 88 F2 FF 00 00 0A 08 00 00 00
            00 08 83 E3 FF 00 00 0A 08 00 00 00 00 08 83 E1
            FF 00 00 0A 08 00 00 00 00 08 83 DE FF 00 00 0A
            08 00 00 00 00 08 83 DC FF 00 00 0A 08 00 00 00
            00 08 83 DB FF 00 00 0A 08 00 00 00 00 08 78 15
            FF 00 00 0A 08 00 00 00 00 08 78 13 FF 00 00 0A
            08 00 00 00 00 08 78 10 FF 00 00 0A 08 00 00 00
            00 08 78 0E FF 00 00 0A 08 00 00 00 00 08 78 0C
            FF 00 00 0A 08 00 00 00 00 08 74 D5 FF 00 00 0A
            08 00 00 00 00 08 74 D3 FF 00 00 0A 08 00 00 00
            00 08 74 D0 FF 00 00 0A 08 00 00 00 00 08 74 CE
            FF 00 00 0A 08 00 00 00 00 08 73 14 FF 00 00 1E
            08 00 00 00 00 08 73 10 FF 00 00 1E 08 00 00 00
            00 08 73 0D FF 00 00 1E 08 00 00 00
            """)
        let record = hex("D1 03 FD 50 48 44 8E") + inner
        XCTAssertEqual(inner.count, 252)
        let decoded = try PHD.decode(record)
        XCTAssertEqual(decoded.sequence, 14)
        XCTAssertEqual(decoded.inner, inner)
    }

    func testPHDDecodeAcceptsIdLength() throws {
        // IL set: id length byte after the payload length, id bytes after the type
        let decoded = try PHD.decode(hex("D9 03 03 02 50 48 44 AA BB 85 0A0B"))
        XCTAssertEqual(decoded.sequence, 5)
        XCTAssertEqual(decoded.inner, hex("0A0B"))
    }

    func testPHDDecodeRejectsNonPHDType() {
        XCTAssertThrowsError(try PHD.decode(Data(hexadecimalString: "D1030158595A80")!)) {
            guard case .badFrame = $0 as? NovoPenError else { return XCTFail("expected badFrame, got \($0)") }
        }
    }

    func testPHDDecodeRejectsMalformedRecords() {
        XCTAssertThrowsError(try PHD.decode(PHD.emptyAck), "no PHD type")
        XCTAssertThrowsError(try PHD.decode(hex("D1 03 00 50 48 44 80")), "payload length 0 cannot hold the sequence byte")
        XCTAssertThrowsError(try PHD.decode(hex("C1 03 03 50 48 44 80 01 02")), "short-record bit clear")
        XCTAssertThrowsError(try PHD.decode(hex("D1 03 04 50 48 44 80 01 02")), "inner shorter than declared") {
            XCTAssertEqual($0 as? NovoPenError, .truncated)
        }
        XCTAssertThrowsError(try PHD.decode(Data()))
    }

    // MARK: - Transceiver

    private struct ScriptExhausted: Error {}

    /// Queues replies and records the APDUs it is sent. An unexpected extra APDU fails the test.
    private final class ScriptedTransport: NovoPenTagTransport {
        private var replies: [(data: Data, status: UInt16)]
        private(set) var sent: [Data] = []

        init(_ replies: [(data: Data, status: UInt16)]) { self.replies = replies }

        func send(_ apdu: Data) async throws -> (data: Data, status: UInt16) {
            sent.append(apdu)
            guard !replies.isEmpty else { throw ScriptExhausted() }
            return replies.removeFirst()
        }
    }

    private func reply(_ hexString: String = "", _ status: UInt16 = 0x9000) -> (data: Data, status: UInt16) {
        (hex(hexString), status)
    }

    private func capabilityContainer(mle: UInt16 = 0xFF, mlc: UInt16 = 0xF6) -> Data {
        hex("000F 20" + String(format: "%04X", mle) + String(format: "%04X", mlc) + "0406 E104 00FF 00FF")
    }

    /// Replies to app select, CC select, CC read and NDEF select.
    private func selectReplies(mle: UInt16 = 0xFF, mlc: UInt16 = 0xF6) -> [(data: Data, status: UInt16)] {
        [reply("", 0x6A82), reply(), (capabilityContainer(mle: mle, mlc: mlc), 0x9000), reply()]
    }

    /// A transceiver that went through `select()`. The transport has only seen the 4 select APDUs.
    private func selectedTransceiver(mle: UInt16 = 0xFF, mlc: UInt16 = 0xF6, then replies: [(data: Data, status: UInt16)]) async throws -> (NovoPenTransceiver, ScriptedTransport) {
        let transport = ScriptedTransport(selectReplies(mle: mle, mlc: mlc) + replies)
        let transceiver = NovoPenTransceiver(transport: transport)
        try await transceiver.select()
        return (transceiver, transport)
    }

    private let nlenRead = Data(hexadecimalString: "00B0000002")!
    private let ack = T4.update(PHD.emptyAck)
    /// PHD record, sequence 0, inner 0E0F1011121314
    private let record0 = "D10308504844800E0F1011121314"

    func testSelectSequenceAndToleratesRepeatedAppSelect() async throws {
        let transport = ScriptedTransport(selectReplies())
        try await NovoPenTransceiver(transport: transport).select()
        XCTAssertEqual(transport.sent, [T4.selectApp(), T4.selectCapabilityContainer(), hex("00B000000F"), T4.selectNDEF()])
    }

    func testSelectFailsWhenCapabilityContainerSelectFails() async {
        let transport = ScriptedTransport([reply("", 0x6A82), reply("", 0x6A82)])
        do {
            try await NovoPenTransceiver(transport: transport).select()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? NovoPenError, .status(0x6A82))
        }
        XCTAssertEqual(transport.sent.count, 2, "select stops at the first failure")
    }

    func testSelectFailsOnShortCapabilityContainer() async {
        let transport = ScriptedTransport([reply(), reply(), reply("000F2000FF"), reply()])
        do {
            try await NovoPenTransceiver(transport: transport).select()
            XCTFail("expected an error")
        } catch {
            guard case .badFrame = error as? NovoPenError else { return XCTFail("expected badFrame, got \(error)") }
        }
        XCTAssertEqual(transport.sent.count, 3, "NDEF is not selected after a bad capability container")
    }

    func testReceiveReadsNlenThenChunksAndAcks() async throws {
        let (transceiver, transport) = try await selectedTransceiver(then: [reply("000E"), reply(record0), reply()])
        let inner = try await transceiver.receive()
        XCTAssertEqual(inner, hex("0E0F1011121314"))
        XCTAssertEqual(Array(transport.sent.dropFirst(4)), [nlenRead, hex("00B000020E"), ack])
    }

    func testReceiveReadsInMleSizedChunks() async throws {
        // 14 byte record, 4 bytes per read
        let (transceiver, transport) = try await selectedTransceiver(mle: 4, then: [
            reply("000E"), reply("D1030850"), reply("4844800E"), reply("0F101112"), reply("1314"), reply()])
        let inner = try await transceiver.receive()
        XCTAssertEqual(inner, hex("0E0F1011121314"))
        XCTAssertEqual(Array(transport.sent.dropFirst(4)), [nlenRead, hex("00B0000204"), hex("00B0000604"), hex("00B0000A04"), hex("00B0000E02"), ack])
    }

    func testReceiveRetriesChunkThenSucceeds() async throws {
        // the bytes of the failed reply must not end up in the record
        let (transceiver, transport) = try await selectedTransceiver(then: [reply("000E"), reply("D1030850", 0x6700), reply(record0), reply()])
        let inner = try await transceiver.receive()
        XCTAssertEqual(inner, hex("0E0F1011121314"))
        XCTAssertEqual(Array(transport.sent.dropFirst(4)), [nlenRead, hex("00B000020E"), hex("00B000020E"), ack])
    }

    func testReceiveRetriesShortChunkReply() async throws {
        let (transceiver, _) = try await selectedTransceiver(then: [reply("000E"), reply("D1030850"), reply(record0), reply()])
        let inner = try await transceiver.receive()
        XCTAssertEqual(inner, hex("0E0F1011121314"))
    }

    func testReceiveGivesUpWhenAChunkFailsThreeTimesInThreeReads() async throws {
        // 3 outer tries x (NLEN + 3 chunk tries)
        let failedRead = [reply("000E"), reply("", 0x6700), reply("", 0x6700), reply("", 0x6700)]
        let (transceiver, transport) = try await selectedTransceiver(then: failedRead + failedRead + failedRead)
        do {
            _ = try await transceiver.receive()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? NovoPenError, .status(0x6700))
        }
        XCTAssertEqual(transport.sent.dropFirst(4).count, 12)
    }

    func testReceiveWithZeroNlenFailsAfterThreeTries() async throws {
        let (transceiver, transport) = try await selectedTransceiver(then: [reply("0000"), reply("0000"), reply("0000")])
        do {
            _ = try await transceiver.receive()
            XCTFail("expected an error")
        } catch {
            guard case .badFrame = error as? NovoPenError else { return XCTFail("expected badFrame, got \(error)") }
        }
        XCTAssertEqual(Array(transport.sent.dropFirst(4)), [nlenRead, nlenRead, nlenRead])
    }

    func testReceiveWithShortNlenReplyFailsAfterThreeTries() async throws {
        let (transceiver, transport) = try await selectedTransceiver(then: [reply("00"), reply("00"), reply("")])
        do {
            _ = try await transceiver.receive()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? NovoPenError, .truncated)
        }
        XCTAssertEqual(Array(transport.sent.dropFirst(4)), [nlenRead, nlenRead, nlenRead])
    }

    func testReceiveRetriesNlenThenSucceeds() async throws {
        let (transceiver, _) = try await selectedTransceiver(then: [reply("", 0x6700), reply("000E"), reply(record0), reply()])
        let inner = try await transceiver.receive()
        XCTAssertEqual(inner, hex("0E0F1011121314"))
    }

    func testReceiveRejectsNlenWhoseChunkOffsetsDoNotFitSixteenBits() async throws {
        let (transceiver, transport) = try await selectedTransceiver(then: [reply("FFFF")])
        do {
            _ = try await transceiver.receive()
            XCTFail("expected an error")
        } catch {
            guard case .limitExceeded = error as? NovoPenError else { return XCTFail("expected limitExceeded, got \(error)") }
        }
        XCTAssertEqual(Array(transport.sent.dropFirst(4)), [nlenRead], "no retry and no chunk read")
    }

    func testReceiveWithZeroMleMaxFailsWithoutReadingChunks() async throws {
        let (transceiver, transport) = try await selectedTransceiver(mle: 0, then: [reply("000E")])
        do {
            _ = try await transceiver.receive()
            XCTFail("expected an error")
        } catch {
            guard case .limitExceeded = error as? NovoPenError else { return XCTFail("expected limitExceeded, got \(error)") }
        }
        XCTAssertEqual(Array(transport.sent.dropFirst(4)), [nlenRead])
    }

    func testReceiveBeforeSelectFailsInsteadOfCrashing() async {
        let transceiver = NovoPenTransceiver(transport: ScriptedTransport([reply("0000"), reply("0000"), reply("0000")]))
        do {
            _ = try await transceiver.receive()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error is NovoPenError)
        }
    }

    func testUnexpectedSequenceThrows() async throws {
        let (transceiver, transport) = try await selectedTransceiver(then: [reply("000E"), reply("D10308504844820E0F1011121314")])
        do {
            _ = try await transceiver.receive()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? NovoPenError, .sequence(expected: 0, got: 2))
        }
        XCTAssertEqual(transport.sent.count, 6, "a frame with the wrong sequence is not acknowledged")
    }

    func testTransportErrorPropagatesWithoutRetry() async throws {
        let (transceiver, transport) = try await selectedTransceiver(then: [])
        do {
            _ = try await transceiver.receive()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error is ScriptExhausted)
        }
        XCTAssertEqual(transport.sent.count, 5, "the NLEN read is not repeated when the transport fails")
    }

    func testSendUsesOddSequences() async throws {
        let (transceiver, transport) = try await selectedTransceiver(then: [reply(), reply()])
        try await transceiver.send(hex("AABBCC"))
        try await transceiver.send(hex("AABBCC"))
        XCTAssertEqual(Array(transport.sent.dropFirst(4)), [hex("00D600000C000AD1030450484481AABBCC"), hex("00D600000C000AD1030450484483AABBCC")])
    }

    func testReceiveExpectsTheNextEvenSequenceAfterASend() async throws {
        // one counter for both directions: send used 1 and moved on to 2
        let (transceiver, _) = try await selectedTransceiver(then: [reply(), reply("000E"), reply("D10308504844820E0F1011121314"), reply()])
        try await transceiver.send(hex("AABBCC"))
        let inner = try await transceiver.receive()
        XCTAssertEqual(inner, hex("0E0F1011121314"))
    }

    func testSendRejectsPayloadLargerThanMlcMax() async throws {
        // mlcMax 0xF6: the PHD record may be 0xF6 - 7 = 239 bytes, so the inner packet 232
        let (transceiver, transport) = try await selectedTransceiver(then: [reply(), reply()])
        do {
            try await transceiver.send(Data(count: 233))
            XCTFail("expected an error")
        } catch {
            guard case .limitExceeded = error as? NovoPenError else { return XCTFail("expected limitExceeded, got \(error)") }
        }
        XCTAssertEqual(transport.sent.count, 4, "nothing is sent")
        try await transceiver.send(Data(count: 232))
        XCTAssertEqual(transport.sent.last?[13], 0x81, "the rejected send did not use up a sequence number")
    }

    func testSendNeverExceedsOneApdu() async throws {
        // a huge mlcMax still leaves a one byte Lc: at most 253 bytes of record, so 246 of inner packet
        let (transceiver, _) = try await selectedTransceiver(mlc: 0xFFFF, then: [reply()])
        do {
            try await transceiver.send(Data(count: 247))
            XCTFail("expected an error")
        } catch {
            guard case .limitExceeded = error as? NovoPenError else { return XCTFail("expected limitExceeded, got \(error)") }
        }
        try await transceiver.send(Data(count: 246))
    }

    func testSendFailsWhenTheTagRejectsTheWrite() async throws {
        let (transceiver, _) = try await selectedTransceiver(then: [reply("", 0x6700)])
        do {
            try await transceiver.send(hex("AABBCC"))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? NovoPenError, .status(0x6700))
        }
    }
}
