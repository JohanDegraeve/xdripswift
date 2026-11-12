// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from JugglucoNG 11e6e29 SibionicsProtocol.kt / SibionicsConstants.kt.
// This module only parses raw sensor signals. They are NOT glucose readings.
import Foundation

public enum GS1ProtocolError: Error, Equatable {
    case invalidMAC, invalidSensorCode, unsupportedSensitivity, invalidIndex
    case wrongHeader, wrongLength, checksum, unsupportedTransport, bufferLimit
}

public struct GS1MAC: Equatable, Hashable, Sendable {
    public let bytes: [UInt8]
    public var string: String { bytes.map { String(format: "%02X", $0) }.joined(separator: ":") }
    public init(_ input: String) throws {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let compact: String
        if value.count == 12 { compact = value }
        else if value.count == 17 {
            let delimiter: Character = value.contains(":") ? ":" : "-"
            let groups = value.split(separator: delimiter, omittingEmptySubsequences: false)
            guard groups.count == 6, groups.allSatisfy({ $0.count == 2 }) else { throw GS1ProtocolError.invalidMAC }
            compact = groups.joined()
        } else { throw GS1ProtocolError.invalidMAC }
        let chars = Array(compact.utf8)
        guard chars.count == 12, chars.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) }) else { throw GS1ProtocolError.invalidMAC }
        var output = [UInt8]()
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let byte = UInt8(String(bytes: chars[i...i+1], encoding: .utf8)!, radix: 16) else { throw GS1ProtocolError.invalidMAC }
            output.append(byte)
        }
        guard !output.allSatisfy({ $0 == 0 }), !output.allSatisfy({ $0 == 255 }) else { throw GS1ProtocolError.invalidMAC }
        bytes = output
    }
}

/// The user must explicitly select the Chinese GS1 variant. A name or AA55
/// packet alone cannot distinguish the Chinese 115G algorithm from EU 116A.
public struct GS1CNIdentity: Equatable, Sendable {
    public let sensorCode: String
    public let mac: GS1MAC
    public let sensitivity: Float
    public init(sensorCode: String, mac: GS1MAC) throws {
        let code = sensorCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let bytes = Array(code.utf8)
        guard bytes.count == 8, bytes.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) }), !code.hasPrefix("P"), !code.hasPrefix("XPT") else { throw GS1ProtocolError.invalidSensorCode }
        guard let sensitivity = GS1Sensitivity.decode(code) else { throw GS1ProtocolError.unsupportedSensitivity }
        self.sensorCode = code; self.mac = mac; self.sensitivity = sensitivity
    }
    public func checkpointIdentity(peripheralID: UUID) -> String {
        "GS1-CN|\(sensorCode)|\(mac.string)|\(peripheralID.uuidString)"
    }
    /// Candidate filter only, not proof of MAC or sensor identity. First pairing
    /// requires explicit device selection; reconnect must bind the saved UUID.
    /// Known upstream names: GEPD802J -> LT2309GEPD; 46HU804E -> LT260346HU.
    public func matchesAdvertisedName(_ name: String?) -> Bool {
        guard let name else { return false }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean == sensorCode || (clean.count == 11 && clean.hasPrefix(sensorCode)) { return true }
        let bytes = Array(clean.utf8)
        return bytes.count == 10 && clean.hasPrefix("LT") && bytes[2..<6].allSatisfy({ (48...57).contains($0) }) && clean.suffix(4) == sensorCode.prefix(4)
    }
}

public enum GS1Sensitivity {
    /// Per-sensor code decoder. Deliberately omits upstream's default/fallback
    /// sensitivity; a different sensor's calibration must never be substituted.
    public static func decode(_ code: String) -> Float? {
        let value = code.uppercased()
        guard value.utf8.count >= 4, value.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) }) else { return nil }
        let token = Array(value.utf8.suffix(4)).map(Int.init)
        if token.allSatisfy({ (48...57).contains($0) }) {
            let n = token.reduce(0) { $0 * 10 + $1 - 48 }
            return supported(Float(n) / 1000)
        }
        for base in [65, 80] {
            if let n = decodedDigits(token, base: base), let result = supported(Float(n) / 100) { return result }
        }
        return nil
    }
    private static func supported(_ value: Float) -> Float? { value.isFinite && (0.8...2.5).contains(value) ? value : nil }
    private static func decodedDigits(_ source: [Int], base: Int) -> Int? {
        let t = source.map { $0 == 75 ? 73 : ($0 == 73 ? 33 : $0) }
        let out3 = base - t[3] + 57
        var w9 = t[3] - base + 48
        let w10: Int
        let out2: Int
        if t[2] >= base {
            let w11 = t[2] - base
            w10 = w11 + 48; w9 += 9 - w11; out2 = w9
        } else {
            let w11 = t[2] <= (w9 & 0xff) ? 48 : 57
            w10 = t[2]; w9 += w11 - t[2]; out2 = w9
        }
        let out1: Int
        let w11b: Int
        if t[1] >= base {
            let w12 = t[1] - base
            w11b = w12 + 48; out1 = 9 - w12 + w10
        } else {
            let w12 = (t[1] <= (w10 & 0xff) ? 48 : 57) - t[1]
            w11b = t[1]; out1 = w12 + w10
        }
        let out0 = t[0] >= base ? base - t[0] + 9 + w11b : (t[0] <= (w11b & 0xff) ? 48 : 57) - t[0] + w11b
        let sum = out0 + out1 + out2 - 0x90
        let checksum = ((sum % 10) + 10) % 10
        guard out3 - 48 == checksum else { return nil }
        // Kotlin String.toIntOrNull also accepts a leading '+'. These are
        // real decoded tokens (e.g. A32T -> +82), not a default sensitivity.
        if out0 == 43, (48...57).contains(out1), (48...57).contains(out2) {
            return (out1 - 48) * 10 + out2 - 48
        }
        guard [out0, out1, out2].allSatisfy({ (48...57).contains($0) }) else { return nil }
        return (out0 - 48) * 100 + (out1 - 48) * 10 + out2 - 48
    }
}

/// A chemical signal and temperature, requiring the full 115G stateful decoder.
/// No conversion to mg/dL is exposed on a raw packet.
public struct GS1RawSample: Equatable, Sendable {
    public let index: Int
    public let rawTemperature: Int
    public let impedance: Int
    public let chemicalSignal: Int
    public let opaqueStatus: Int
    public let remaining: Int
    public let addedSeconds: Int
    public var temperatureC: Float { Float(rawTemperature) / 10 }
    public var algorithmInput: Float { Float(chemicalSignal) / 10 }
    public var isLastInHistory: Bool { remaining == 0 }
    public func timestamp(receivedAt: Date) -> Date {
        receivedAt.addingTimeInterval(TimeInterval(min(addedSeconds - remaining * 60, 0)))
    }
}

public enum GS1Packet: Equatable, Sendable {
    case samples([GS1RawSample])
    case echo
    case encryptedProtocolRequired
}

public enum GS1ChineseProtocol {
    public static let serviceUUID = "0000FF30-0000-1000-8000-00805F9B34FB"
    public static let notifyUUID = "0000FF31-0000-1000-8000-00805F9B34FB"
    public static let writeUUID = "0000FF32-0000-1000-8000-00805F9B34FB"
    public static let authMarker: [UInt8] = [0x23, 0xf7, 0x6f, 0xd9, 0xf4]
    public static func checksum(_ bytes: [UInt8]) -> UInt8 { 0 &- bytes.reduce(UInt8(0), &+) }

    /// On an unused CN sensor this request may begin a sensor session. Call only
    /// after an explicit connection/start action, never during passive scanning.
    public static func request(index: Int, mac: GS1MAC) throws -> Data {
        guard (1...65535).contains(index) else { throw GS1ProtocolError.invalidIndex }
        var data: [UInt8] = [0xaa, 0x55, 0x07, UInt8(index & 255), UInt8(index >> 8)]
        data += mac.bytes.reversed(); data += Array(repeating: 0, count: 8)
        data.append(checksum(data)); return Data(data)
    }
    public static func parse(_ data: Data) throws -> GS1Packet {
        let bytes = [UInt8](data)
        if bytes == authMarker { return .encryptedProtocolRequired }
        guard bytes.count >= 3, bytes[0] == 0xaa, bytes[1] == 0x55 else { throw GS1ProtocolError.wrongHeader }
        if bytes[2] == 7 {
            guard bytes.count == 3 || (bytes.count == 20 && checksum(bytes) == 0) else { throw GS1ProtocolError.wrongLength }
            return .echo
        }
        guard bytes[2] == 9 else { throw GS1ProtocolError.wrongHeader }
        guard bytes.count >= 5 else { throw GS1ProtocolError.wrongLength }
        let count = Int(bytes[3])
        let compactLength = 5 + count * 14
        if bytes.count != compactLength {
            // This factory CN variant reserves ten record slots, even when only
            // some are filled. Its original checksum is the final byte of 145.
            guard bytes.count == 145, count <= 10,
                  bytes[(4 + count * 14)..<144].allSatisfy({ $0 == 0 }) else {
                throw GS1ProtocolError.wrongLength
            }
        }
        guard checksum(bytes) == 0 else { throw GS1ProtocolError.checksum }
        func u16(_ offset: Int) -> Int { Int(bytes[offset]) << 8 | Int(bytes[offset + 1]) }
        var entries = [GS1RawSample]()
        for n in 0..<count {
            let offset = 4 + n * 14
            let index = u16(offset)
            guard index > 0 else { throw GS1ProtocolError.invalidIndex }
            entries.append(.init(index: index, rawTemperature: u16(offset+2), impedance: u16(offset+4), chemicalSignal: u16(offset+6), opaqueStatus: u16(offset+8), remaining: u16(offset+10), addedSeconds: u16(offset+12)))
        }
        return .samples(entries)
    }
}

/// Reassembles AA55 response notifications without interpreting partial bytes
/// as a sample. Corruption discards the buffer, requiring an explicit retry.
public struct GS1PacketAssembler: Sendable {
    public enum Layout: Sendable { case compact, fixed10 }
    private let layout: Layout
    private var buffer = [UInt8]()
    public init(layout: Layout = .compact) { self.layout = layout }
    public mutating func reset() { buffer.removeAll(keepingCapacity: true) }
    public mutating func append(_ fragment: Data) throws -> [GS1Packet] {
        guard buffer.count + fragment.count <= 8192 else { reset(); throw GS1ProtocolError.bufferLimit }
        buffer += fragment
        var result = [GS1Packet]()
        do {
            while !buffer.isEmpty {
                if buffer[0] == GS1ChineseProtocol.authMarker[0] {
                    let prefixLength = min(buffer.count, 5)
                    guard Array(buffer.prefix(prefixLength)) == Array(GS1ChineseProtocol.authMarker.prefix(prefixLength)) else { throw GS1ProtocolError.wrongHeader }
                    if buffer.count < 5 { break }
                    result.append(.encryptedProtocolRequired); buffer.removeFirst(5); continue
                }
                guard buffer[0] == 0xaa else { throw GS1ProtocolError.wrongHeader }
                if buffer.count < 2 { break }
                guard buffer[1] == 0x55 else { throw GS1ProtocolError.wrongHeader }
                if buffer.count < 3 { break }
                // Three bytes may be a short echo or the beginning of a full
                // request echo. Only a checked next data frame proves that the
                // short echo ended; BLE notification boundaries are not proof.
                if buffer[2] == 7 {
                    let next = nextFrameAfterShortEcho()
                    let fullEcho = buffer.count >= 20 && (try? GS1ChineseProtocol.parse(Data(buffer.prefix(20)))) == .echo
                    if next == .pending || (next == .valid && fullEcho) { break }
                    if next == .valid { result.append(.echo); buffer.removeFirst(3); continue }
                    if fullEcho { result.append(.echo); buffer.removeFirst(20); continue }
                    // No proven boundary: keep bounded input pending. The BLE
                    // response watchdog may reset and request the missing index.
                    break
                }
                guard buffer[2] == 9 else { throw GS1ProtocolError.wrongHeader }
                if buffer.count < 4 { break }
                let length = try dataFrameLength(in: buffer)
                if buffer.count < length { break }
                result.append(try GS1ChineseProtocol.parse(Data(buffer.prefix(length))))
                buffer.removeFirst(length)
            }
            return result
        } catch { reset(); throw error }
    }
    private enum NextFrame { case absent, pending, valid, invalid }
    private func nextFrameAfterShortEcho() -> NextFrame {
        let tail = Array(buffer.dropFirst(3))
        guard let first = tail.first else { return .pending }
        if first == 0x23 {
            let count = min(tail.count, 5)
            guard Array(tail.prefix(count)) == Array(GS1ChineseProtocol.authMarker.prefix(count)) else { return .invalid }
            return tail.count >= 5 ? .valid : .pending
        }
        guard first == 0xaa else { return .absent }
        guard tail.count >= 2 else { return .pending }
        guard tail[1] == 0x55 else { return .invalid }
        guard tail.count >= 3 else { return .pending }
        guard tail[2] == 9 else { return .invalid }
        guard tail.count >= 4 else { return .pending }
        guard let size = try? dataFrameLength(in: tail) else { return .invalid }
        guard tail.count >= size else { return .pending }
        return (try? GS1ChineseProtocol.parse(Data(tail.prefix(size)))) == nil ? .invalid : .valid
    }
    private func dataFrameLength(in bytes: [UInt8]) throws -> Int {
        guard bytes.count >= 4 else { throw GS1ProtocolError.wrongLength }
        let count = Int(bytes[3])
        switch layout {
        case .compact:
            return 5 + count * 14
        case .fixed10:
            guard count <= 10 else { throw GS1ProtocolError.wrongLength }
            // An explicitly empty compact reply is unambiguous: fixed padding
            // starts with zero, whereas this canonical empty checksum is F8.
            if count == 0, bytes.count >= 5, bytes[4] == 0xf8 { return 5 }
            return 145
        }
    }
}

/// History order gate. A new decoder must replay from index1; reconnect uses a
/// validated, identity-bound checkpoint. A gap requests the missing index.
public struct GS1SequenceGate: Sendable {
    public enum Decision: Equatable { case accept, duplicate, requestMissing(Int) }
    public private(set) var nextIndex: Int
    public init(lastCheckpointIndex: Int? = nil) throws {
        if let index = lastCheckpointIndex {
            guard (1...65535).contains(index) else { throw GS1ProtocolError.invalidIndex }
            nextIndex = index + 1
        } else { nextIndex = 1 }
    }
    public func decision(for index: Int) -> Decision {
        index < nextIndex ? .duplicate : (index > nextIndex ? .requestMissing(nextIndex) : .accept)
    }
    /// Only after the decoder accepted the sample and its checkpoint was saved.
    public mutating func commit(index: Int) throws {
        guard index == nextIndex, (1...65535).contains(index) else { throw GS1ProtocolError.invalidIndex }
        nextIndex += 1
    }
}
