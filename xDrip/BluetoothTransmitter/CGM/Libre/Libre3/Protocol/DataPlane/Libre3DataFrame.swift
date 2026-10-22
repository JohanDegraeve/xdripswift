//
//  Libre3DataFrame.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/DataPlane/DataFrame.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

// Post-pairing data plane wire format.
//
// Decoded from live BLE captures: encrypted post-authorization notifications
// share the same outer framing:
//
//     [ encrypted_payload | seq_byte | type_byte (often 0x00) ]
//
// `seq_byte` is a per-channel monotonic counter advancing 0x01..0x0n.
//
// `type_byte` distinguishes record kinds within a channel, for the
// realtime/backfill streams it has been observed as 0x00.
//
// The `encrypted_payload` is AES-CCM-128 ciphertext under the session
// key derived during pairing. The CCM nonce is per-channel + seq,
// exact construction is still under investigation (see
// `findings/IPHONE_POC_PLAN.md` Gap #1).
//
// `Libre3DataFrame` parses the OUTER framing, it does NOT decrypt. Callers
// pass the parsed `encrypted` bytes to `Libre3DataPlaneCrypto` once a session key is
// available.

struct Libre3DataFrame: Equatable, Sendable {
    let encrypted: Data
    let seq: UInt8
    let type: UInt8

    static func parse(_ raw: Data) throws -> Libre3DataFrame {
        guard raw.count >= 3 else { throw Libre3DataFrameError.tooShort(raw.count) }
        let trailerStart = raw.endIndex - 2
        let encrypted = raw.subdata(in: raw.startIndex..<trailerStart)
        let seq = raw[trailerStart]
        let type = raw[trailerStart + 1]
        return Libre3DataFrame(encrypted: encrypted, seq: seq, type: type)
    }

    /// The final two bytes are carried on the wire little-endian. Earlier
    /// notes called them `[seq, type]`, data-plane CCM nonce construction uses
    /// them as the 16-bit packet sequence.
    var sequenceNumber: UInt16 {
        UInt16(seq) | (UInt16(type) << 8)
    }

    /// Encode for the wire , useful for round-trip tests and for any
    /// path that builds frames on the phone side (e.g. session-control
    /// writes on handle 0x0011).
    var raw: Data {
        var out = Data(capacity: encrypted.count + 2)
        out.append(encrypted)
        out.append(seq)
        out.append(type)
        return out
    }
}

enum Libre3DataFrameError: Error, Equatable {
    case tooShort(Int)
}
