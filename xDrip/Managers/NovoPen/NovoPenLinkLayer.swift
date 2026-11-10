//
//  NovoPenLinkLayer.swift
//  xdrip
//
//  Ported from xDrip "OpenNov" by JamOrHam (NightscoutFoundation/xDrip, GPLv3).
//
//  NFC type 4 tag APDUs, capability container, PHD (IEEE 11073 over NDEF) framing and the transceiver for NovoPen.
//  All protocol fields are big-endian. No CoreNFC here, so everything is unit-testable.
//

import Foundation
import OSLog

enum NovoPenError: Error, Equatable {
    case truncated
    case status(UInt16)
    case badFrame(String)
    case sequence(expected: UInt8, got: UInt8)
    case nonTypicalSegments(String)
    case limitExceeded(String)
    case notAPen
}

/// Big-endian reader. A read past the end throws `.truncated` and consumes nothing.
struct NovoPenByteReader {
    private let data: Data
    private var position = 0

    /// Copies the data so slices (non-zero startIndex) are safe.
    init(_ data: Data) {
        self.data = Data(data)
    }

    var remaining: Int { data.count - position }

    mutating func u8() throws -> UInt8 { UInt8(try integer(1)) }
    mutating func u16() throws -> UInt16 { UInt16(try integer(2)) }
    mutating func u32() throws -> UInt32 { UInt32(try integer(4)) }

    mutating func bytes(_ n: Int) throws -> Data {
        guard n >= 0, n <= remaining else { throw NovoPenError.truncated }
        defer { position += n }
        return data.subdata(in: position..<position + n)
    }

    private mutating func integer(_ n: Int) throws -> UInt64 {
        try bytes(n).reduce(0) { $0 << 8 | UInt64($1) }
    }
}

/// Big-endian writer.
struct NovoPenByteWriter {
    private(set) var data = Data()

    mutating func u8(_ value: UInt8) { data.append(value) }
    mutating func u16(_ value: UInt16) { data.append(contentsOf: [UInt8(value >> 8), UInt8(value & 0xFF)]) }
    mutating func u32(_ value: UInt32) { u16(UInt16(value >> 16)); u16(UInt16(value & 0xFFFF)) }
    mutating func bytes(_ value: Data) { data.append(value) }
}

/// ISO 7816-4 command APDUs for an NFC forum type 4 tag.
enum T4 {
    private static let cla: UInt8 = 0x00
    private static let insSelect: UInt8 = 0xA4
    private static let insReadBinary: UInt8 = 0xB0
    private static let insUpdateBinary: UInt8 = 0xD6
    private static let selectByName: UInt8 = 0x04
    private static let selectFirstOnly: UInt8 = 0x0C
    /// Le is one byte
    private static let maxReadLength = 255

    static let statusOK: UInt16 = 0x9000

    private static let applicationID = Data([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01])
    private static let capabilityContainerFile = Data([0xE1, 0x03])
    private static let ndefFile = Data([0xE1, 0x04])

    /// 00 A4 04 00 07 D2760000850101 00
    static func selectApp() -> Data { select(p1: selectByName, p2: 0x00, file: applicationID, le: 0x00) }

    /// 00 A4 00 0C 02 E103
    static func selectCapabilityContainer() -> Data { select(p1: 0x00, p2: selectFirstOnly, file: capabilityContainerFile, le: nil) }

    /// 00 A4 00 0C 02 E104
    static func selectNDEF() -> Data { select(p1: 0x00, p2: selectFirstOnly, file: ndefFile, le: nil) }

    /// READ BINARY commands covering `length` bytes from `offset`, at most `min(mtu, 255)` bytes each.
    /// Every chunk's offset must fit in 16 bits, so callers bound `offset + length` by the tag's file size.
    static func reads(offset: Int, length: Int, mtu: Int) -> [Data] {
        let chunkSize = min(mtu, maxReadLength)
        guard chunkSize > 0 else { return [] }
        var commands: [Data] = []
        var nextOffset = offset
        var left = length
        while left > 0 {
            let chunk = min(left, chunkSize)
            var w = NovoPenByteWriter()
            w.u8(cla); w.u8(insReadBinary); w.u16(UInt16(nextOffset)); w.u8(UInt8(chunk))
            commands.append(w.data)
            nextOffset += chunk
            left -= chunk
        }
        return commands
    }

    /// Single UPDATE BINARY at offset 0 writing [length u16] payload: 00 D6 00 00 (len+2) [len u16] payload.
    /// Lc is one byte, so the payload is at most 253 bytes.
    static func update(_ payload: Data) -> Data {
        precondition(payload.count <= 253, "T4 update payload does not fit a single APDU")
        var w = NovoPenByteWriter()
        w.u8(cla); w.u8(insUpdateBinary); w.u16(0); w.u8(UInt8(payload.count + 2))
        w.u16(UInt16(payload.count)); w.bytes(payload)
        return w.data
    }

    private static func select(p1: UInt8, p2: UInt8, file: Data, le: UInt8?) -> Data {
        var w = NovoPenByteWriter()
        w.u8(cla); w.u8(insSelect); w.u8(p1); w.u8(p2); w.u8(UInt8(file.count)); w.bytes(file)
        if let le { w.u8(le) }
        return w.data
    }
}

/// The 15-byte capability container (file E103): CCLEN u16, mapping u8, MLe u16, MLc u16, then the NDEF file control TLV.
struct T4CapabilityContainer {
    static let size = 15

    /// maximum R-APDU data size the tag can return for one READ BINARY
    let mleMax: Int
    /// maximum C-APDU data size the tag accepts for one UPDATE BINARY
    let mlcMax: Int

    init(_ data: Data) throws {
        guard data.count == Self.size else { throw NovoPenError.badFrame("capability container is \(data.count) bytes, expected \(Self.size)") }
        var r = NovoPenByteReader(data)
        _ = try r.bytes(3)
        mleMax = Int(try r.u16())
        mlcMax = Int(try r.u16())
    }
}

/// PHD framing: a single short NDEF record of well-known type "PHD" whose payload is a sequence byte + the inner packet.
enum PHD {
    private static let type = Data("PHD".utf8)
    private static let messageBegin: UInt8 = 0x80
    private static let messageEnd: UInt8 = 0x40
    private static let shortRecord: UInt8 = 0x10
    private static let idLengthPresent: UInt8 = 0x08
    private static let wellKnown: UInt8 = 0x01
    private static let sequenceFlag: UInt8 = 0x80

    /// empty NDEF record, sent to acknowledge a packet
    static let emptyAck = Data([0xD0, 0x00, 0x00])

    /// D1 03 (inner+1) "PHD" (0x80 | sequence & 0x0F) inner. The inner packet is at most 254 bytes.
    static func encode(_ inner: Data, sequence: UInt8) -> Data {
        precondition(inner.count <= 254, "PHD inner packet does not fit a short record")
        var w = NovoPenByteWriter()
        w.u8(messageBegin | messageEnd | shortRecord | wellKnown)
        w.u8(UInt8(type.count))
        w.u8(UInt8(inner.count + 1))
        w.bytes(type)
        w.u8(sequenceFlag | (sequence & 0x0F))
        w.bytes(inner)
        return w.data
    }

    /// Accepts a record with the ID length field set (IL); its ID is skipped. Bytes after the payload are ignored.
    static func decode(_ record: Data) throws -> (sequence: UInt8, inner: Data) {
        var r = NovoPenByteReader(record)
        let header = try r.u8()
        let typeLength = Int(try r.u8())
        let payloadLength = Int(try r.u8())
        let idLength = header & idLengthPresent != 0 ? Int(try r.u8()) : 0
        guard header & shortRecord != 0 else { throw NovoPenError.badFrame("PHD record is not a short record") }
        guard typeLength == type.count, try r.bytes(typeLength) == type else { throw NovoPenError.badFrame("not a PHD record") }
        guard payloadLength >= 1 else { throw NovoPenError.badFrame("PHD payload has no sequence byte") }
        _ = try r.bytes(idLength)
        let sequence = try r.u8() & 0x0F
        return (sequence, try r.bytes(payloadLength - 1))
    }
}

/// Sends one command APDU to the tag and returns the response data and the trailing status word (SW1 SW2).
protocol NovoPenTagTransport {
    func send(_ apdu: Data) async throws -> (data: Data, status: UInt16)
}

/// Moves inner IEEE 11073 packets to and from the pen.
protocol NovoPenChannel: AnyObject {
    /// The inner 11073 bytes of the next packet from the pen. Empty Data = empty frame.
    func receive() async throws -> Data
    func send(_ inner: Data) async throws
}

/// Type 4 tag transceiver: selects the pen's NDEF file, reads and writes one PHD record at a time and tracks the PHD sequence.
final class NovoPenTransceiver: NovoPenChannel {
    private static let tries = 3
    private static let retryPause: UInt64 = 50_000_000 // 50 ms
    /// bytes a PHD record adds to its inner packet
    private static let phdOverhead = 7
    /// Android keeps this much of mlcMax free in every UPDATE BINARY (T4Update.encodeForMtu)
    private static let updateOverhead = 7
    /// UPDATE BINARY Lc is one byte and 2 of it are the NDEF length
    private static let maxUpdatePayload = 253
    private static let nlenSize = 2

    private let transport: NovoPenTagTransport
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNovoPen)

    /// Capability container limits. Zero until `select()` succeeds, which refuses every read and write.
    private var mleMax = 0
    private var mlcMax = 0

    /// Shared by both directions, as in Android: inbound frames must carry it, `send` consumes an odd one and moves on to the next even one.
    private var sequence: UInt8 = 0

    init(transport: NovoPenTagTransport) {
        self.transport = transport
    }

    /// App select, capability container select + read, NDEF select.
    func select() async throws {
        // iOS already selected the app when it connected to the tag, so any status will do
        _ = try await exchange(T4.selectApp())
        try await exchangeOK(T4.selectCapabilityContainer())
        let container = try T4CapabilityContainer(try await exchangeOK(T4.reads(offset: 0, length: T4CapabilityContainer.size, mtu: 255)[0]))
        try await exchangeOK(T4.selectNDEF())
        mleMax = container.mleMax
        mlcMax = container.mlcMax
    }

    func receive() async throws -> Data {
        let record = try await readRecord()
        let frame = try PHD.decode(record)
        guard frame.sequence == sequence else { throw NovoPenError.sequence(expected: sequence, got: frame.sequence) }
        try await exchangeOK(T4.update(PHD.emptyAck))
        return frame.inner
    }

    func send(_ inner: Data) async throws {
        // ponytail: single-packet writes; manager frames are < 60 bytes. Port T4Update.encodeForMtu fragmentation if a pen reports a tiny mlcMax.
        let limit = min(mlcMax - Self.updateOverhead, Self.maxUpdatePayload)
        guard inner.count + Self.phdOverhead <= limit else {
            throw NovoPenError.limitExceeded("\(inner.count) byte packet does not fit one write of at most \(limit) bytes")
        }
        let outbound = sequence + 1
        sequence = (outbound + 1) & 0x0F
        try await exchangeOK(T4.update(PHD.encode(inner, sequence: outbound)))
    }

    // MARK: - Reading

    /// Reads NLEN, then the NDEF message it announces. A failed try starts over, up to `tries` times.
    private func readRecord() async throws -> Data {
        var failure: Error = NovoPenError.truncated
        for _ in 0..<Self.tries {
            do {
                return try await readRecordOnce()
            } catch let error as NovoPenError {
                // a limit will not change on the next try; transport errors are not NovoPenErrors and propagate
                if case .limitExceeded = error { throw error }
                failure = error
            }
        }
        throw failure
    }

    private func readRecordOnce() async throws -> Data {
        let nlenReply = try await exchange(T4.reads(offset: 0, length: Self.nlenSize, mtu: Self.nlenSize)[0])
        guard nlenReply.status == T4.statusOK else { throw NovoPenError.status(nlenReply.status) }
        guard nlenReply.data.count == Self.nlenSize else { throw NovoPenError.truncated }
        var reader = NovoPenByteReader(nlenReply.data)
        let nlen = Int(try reader.u16())
        guard nlen > 0 else { throw NovoPenError.badFrame("pen has no NDEF message") }
        // every chunk offset must fit the 16 bit offset of READ BINARY
        guard Self.nlenSize + nlen - 1 <= 0xFFFF else { throw NovoPenError.limitExceeded("NDEF length \(nlen)") }
        let chunks = T4.reads(offset: Self.nlenSize, length: nlen, mtu: mleMax)
        guard !chunks.isEmpty else { throw NovoPenError.limitExceeded("tag reports mleMax \(mleMax)") }

        var record = Data()
        for chunk in chunks {
            record.append(try await readChunk(chunk))
        }
        return record
    }

    /// 3 tries with a pause. Only the data of a successful, complete reply is returned.
    private func readChunk(_ command: Data) async throws -> Data {
        let length = Int(command.last ?? 0) // Le is the last byte
        var failure = NovoPenError.truncated
        for attempt in 0..<Self.tries {
            if attempt > 0 { try await Task.sleep(nanoseconds: Self.retryPause) }
            let reply = try await exchange(command)
            if reply.status != T4.statusOK {
                failure = .status(reply.status)
            } else if reply.data.count != length {
                failure = .truncated
            } else {
                return reply.data
            }
        }
        throw failure
    }

    // MARK: - Transport

    private func exchange(_ apdu: Data) async throws -> (data: Data, status: UInt16) {
        trace("NovoPen: APDU out %{public}@", log: log, category: ConstantsLog.categoryNovoPen, type: .debug, apdu.hexEncodedString())
        let reply = try await transport.send(apdu)
        trace("NovoPen: APDU in %{public}@ status %{public}@", log: log, category: ConstantsLog.categoryNovoPen, type: .debug, reply.data.hexEncodedString(), String(format: "%04X", reply.status))
        return reply
    }

    /// Throws `.status` unless the tag answers 9000. Returns the response data.
    @discardableResult
    private func exchangeOK(_ apdu: Data) async throws -> Data {
        let reply = try await exchange(apdu)
        guard reply.status == T4.statusOK else { throw NovoPenError.status(reply.status) }
        return reply.data
    }
}
