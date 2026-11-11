//
//  Libre3PatchControlCommand.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/DataPlane/PatchControlCommand.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

// Plaintext builders for patchControl writes.
//
// Each command is exactly 7 bytes before the post-auth AES-CCM data-plane
// wrapper turns it into an 11-byte encrypted body plus a 2-byte sequence.

struct Libre3PatchControlCommand: Equatable, Sendable {
    let label: String
    let plaintext: Data

    init(label: String, plaintext: Data) throws {
        guard plaintext.count == 7 else {
            throw Libre3PatchControlCommandError.wrongPlaintextSize(plaintext.count)
        }
        self.label = label
        self.plaintext = plaintext
    }

    static func historicalBackfillGreaterEqual(
        lifeCount: UInt16,
        selector: UInt8 = 0x01
    ) -> Libre3PatchControlCommand {
        backfillGreaterEqual(stream: .historical, lifeCount: lifeCount, selector: selector)
    }

    static func clinicalBackfillGreaterEqual(
        lifeCount: UInt16,
        selector: UInt8 = 0x01
    ) -> Libre3PatchControlCommand {
        backfillGreaterEqual(stream: .clinical, lifeCount: lifeCount, selector: selector)
    }

    static func backfillGreaterEqual(
        stream: Libre3BackfillStream,
        lifeCount: UInt16,
        selector: UInt8 = 0x01
    ) -> Libre3PatchControlCommand {
        makeRangeCommand(
            label: "\(stream.label) >= \(lifeCount)",
            command: 0x01,
            stream: stream.wireValue,
            selector: selector,
            lifeCount: lifeCount,
            aux: nil
        )
    }

    static func eventLog(index: UInt8) -> Libre3PatchControlCommand {
        Libre3PatchControlCommand(
            label: "event log >= \(index)",
            plaintext: Data([0x04, index, 0x00, 0x00, 0x00, 0x00, 0x00]),
            unchecked: ()
        )
    }

    static func factoryData() -> Libre3PatchControlCommand {
        Libre3PatchControlCommand(
            label: "factory data",
            plaintext: Data([0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
            unchecked: ()
        )
    }

    /// Request sensor shutdown/end-session.
    ///
    /// This is a terminal patch-control command. It is not needed for routine
    /// disconnect, reconnect, or backfill workflows.
    static func shutdownPatch() -> Libre3PatchControlCommand {
        Libre3PatchControlCommand(
            label: "shutdown patch",
            plaintext: Data([0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
            unchecked: ()
        )
    }

    private init(label: String, plaintext: Data, unchecked: Void) {
        self.label = label
        self.plaintext = plaintext
    }

    private static func makeRangeCommand(
        label: String,
        command: UInt8,
        stream: UInt8,
        selector: UInt8,
        lifeCount: UInt16,
        aux: UInt16?
    ) -> Libre3PatchControlCommand {
        var bytes = Data([
            command,
            stream,
            selector,
            UInt8(lifeCount & 0xff),
            UInt8((lifeCount >> 8) & 0xff),
            0x00,
            0x00,
        ])
        if let aux {
            bytes[5] = UInt8(aux & 0xff)
            bytes[6] = UInt8((aux >> 8) & 0xff)
        }
        return Libre3PatchControlCommand(label: label, plaintext: bytes, unchecked: ())
    }
}

enum Libre3PatchControlCommandError: Error, Equatable {
    case wrongPlaintextSize(Int)
}
