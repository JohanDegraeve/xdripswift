//
//  Libre3FrameAssembler.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/BLE/FrameAssembler.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

// Wire framing for the Libre 3 GATT layer (decoded from
// captures/fresh_pair_2026_04_26/btsnoop_hci.log, see
// findings/generateKAuth/BLE_PAIRING_TRANSCRIPT.md).
//
//   Writes  (phone → sensor):  2-byte LE byte-offset prefix + payload chunk
//   Notifies (sensor → phone): 1-byte sequence prefix + payload chunk
//
// Effective payload per fragment is 18 bytes for writes and 19 bytes for
// notifies (set by ATT MTU). The receiver reassembles fragments into the
// original logical message, the caller drives reassembly by either polling
// "do we have N bytes yet" or awaiting on `receive(exactly:)`.
//
// Both helpers below are pure functions and CoreBluetooth-free, so they
// unit-test cleanly.

enum Libre3BleFraming {

    /// Default ATT-MTU-derived chunk sizes for the Libre 3 protocol.
    static let writeChunkPayload: Int = 18
    static let notifyChunkPayload: Int = 19

    // MARK: - Write fragmenter

    /// Splits a logical message into ATT-write fragments. Each fragment is
    /// `[offset_lo, offset_hi, chunk_bytes...]`. The last fragment is whatever
    /// remains, the caller may pre-pad the message if the protocol requires it.
    static func fragmentForWrite(
        _ message: Data,
        chunkSize: Int = writeChunkPayload
    ) -> [Data] {
        precondition(chunkSize > 0)
        var out: [Data] = []
        var offset = 0
        while offset < message.count {
            let end = min(offset + chunkSize, message.count)
            var frag = Data(capacity: 2 + (end - offset))
            frag.append(UInt8(offset & 0xff))
            frag.append(UInt8((offset >> 8) & 0xff))
            frag.append(message.subdata(in: offset..<end))
            out.append(frag)
            offset = end
        }
        return out
    }

    /// Inverse of `fragmentForWrite`, used in tests + for any future write-back path.
    static func reassembleWrite(_ fragments: [Data]) throws -> Data {
        // Sort by offset, then concatenate. Validate continuity.
        let parsed: [(offset: Int, body: Data)] = try fragments.map { f in
            guard f.count >= 2 else { throw Libre3BleFramingError.fragmentTooShort }
            let offset = Int(f[0]) | (Int(f[1]) << 8)
            return (offset, f.subdata(in: 2..<f.count))
        }.sorted { $0.offset < $1.offset }
        var out = Data()
        for piece in parsed {
            guard piece.offset == out.count else { throw Libre3BleFramingError.discontinuousOffsets }
            out.append(piece.body)
        }
        return out
    }

    // MARK: - Notify reassembler

    /// Streaming reassembler for sensor → phone notifies. Each fragment must
    /// carry a 1-byte sequence number followed by the payload chunk. The
    /// reassembler verifies sequence monotonicity and concatenates payloads.
    /// Use `take(_ n: Int)` to consume the first N reassembled bytes.
    final class NotifyReassembler {
        private var buffer = Data()
        private var nextExpectedSeq: UInt8?  // unset until first fragment

        init() {}

        var availableBytes: Int { buffer.count }

        /// Append a single notify fragment. Returns the new total reassembled length.
        @discardableResult
        func feed(_ fragment: Data) throws -> Int {
            guard !fragment.isEmpty else { throw Libre3BleFramingError.fragmentTooShort }
            let seq = fragment[fragment.startIndex]
            if let expected = nextExpectedSeq {
                guard seq == expected else { throw Libre3BleFramingError.sequenceGap(expected: expected, got: seq) }
            }
            nextExpectedSeq = seq &+ 1
            buffer.append(fragment.subdata(in: (fragment.startIndex + 1)..<fragment.endIndex))
            return buffer.count
        }

        /// Consume the first `n` bytes of the reassembled stream. Throws if
        /// fewer than `n` bytes have been received.
        func take(_ n: Int) throws -> Data {
            guard buffer.count >= n else { throw Libre3BleFramingError.notEnoughBytes(have: buffer.count, want: n) }
            let head = buffer.prefix(n)
            buffer.removeSubrange(0..<n)
            return Data(head)
        }

        /// Discard everything, reset the seq counter.
        func reset() {
            buffer.removeAll(keepingCapacity: false)
            nextExpectedSeq = nil
        }
    }
}

enum Libre3BleFramingError: Error, Equatable {
    case fragmentTooShort
    case discontinuousOffsets
    case sequenceGap(expected: UInt8, got: UInt8)
    case notEnoughBytes(have: Int, want: Int)
}
