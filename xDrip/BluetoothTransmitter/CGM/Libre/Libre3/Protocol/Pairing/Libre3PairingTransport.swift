//
//  Libre3PairingTransport.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/PairingTransport.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

// Transport abstraction for the pairing state machine. This decouples
// `Libre3PairingFlow` from CoreBluetooth so we can drive it from a captured-
// bytes replay harness in unit tests AND from a real `SensorSession` on
// device, with the same code path.
//
// The protocol exposes the two operations the pairing flow uses:
//   - `write(_:to:)`   , write a logical message (already framed if needed)
//                         to a characteristic UUID, resolves once the peer
//                         ACKs the underlying ATT writes.
//   - `awaitNotify(on:exactly:)` , read exactly N reassembled bytes from
//                         a notify characteristic.
//
// The wire-level fragmentation (write byte-offset prefix, notify seq
// prefix) lives in `Libre3BleFraming`, the transport does the framing.

protocol Libre3PairingTransport: Sendable {
    /// Write a logical message (will be framed into 18B chunks with
    /// 2B LE byte-offset prefix per `Libre3BleFraming.fragmentForWrite`).
    func write(_ message: Data, to characteristic: Libre3BleCharRef) async throws

    /// Reassemble notify fragments on the given characteristic and
    /// return the first `n` bytes (per `Libre3BleFraming.NotifyReassembler`).
    func awaitNotify(on characteristic: Libre3BleCharRef, exactly n: Int) async throws -> Data
}

/// Optional extension for the command-gated security state machine on the
/// single-byte command/response characteristic.
protocol Libre3CommandPairingTransport: Libre3PairingTransport {
    func writeCommand(_ command: UInt8) async throws
    func awaitCommandResponse(timeout: TimeInterval) async throws -> Data
}

/// Opaque identifier for a GATT characteristic from the pairing flow's
/// perspective. The transport layer knows how to map this to the actual
/// BLE handle / `CBCharacteristic`.
enum Libre3BleCharRef: String, Sendable, Hashable, CaseIterable {
    /// Cert + ephemeral exchange (handle 0x002d in observed captures).
    case certHandshake
    /// Challenge / response (handle 0x002a in observed captures).
    case challenge
}
