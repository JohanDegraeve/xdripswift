//
//  Libre3ReceiverID.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

// Adapted from RoundWhiteDiscKit.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/Libre3ReceiverID.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

struct Libre3ReceiverID: Equatable, Hashable, Sendable, Codable {
    let value: UInt32

    init(_ value: UInt32) {
        self.value = value
    }

    init(accountlessUniqueID: String) {
        self.value = Self.accountlessValue(from: accountlessUniqueID)
    }

    init(littleEndianHex: String) throws {
        guard let value = Self.parseLittleEndianHex(littleEndianHex) else {
            throw Libre3ReceiverIDError.invalidLittleEndianHex(littleEndianHex)
        }
        self.value = value
    }

    var littleEndianData: Data {
        Data([
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff),
        ])
    }

    var littleEndianHex: String {
        littleEndianData.map { String(format: "%02x", $0) }.joined()
    }

    var displayString: String {
        String(format: "0x%08x / %@", value, littleEndianHex)
    }

    static func accountlessValue(from uniqueID: String) -> UInt32 {
        var value: UInt32 = 0
        for unit in uniqueID.utf16 {
            value = (value &* 0x811c9dc5) ^ UInt32(unit)
        }
        return value
    }

    static func parseLittleEndianHex(_ raw: String) -> UInt32? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let unprefixed = trimmed.lowercased().hasPrefix("0x") ? String(trimmed.dropFirst(2)) : trimmed
        let parts = unprefixed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 1 || (parts.count == 4 && parts.allSatisfy({ $0.count == 2 })) else { return nil }
        let cleaned = parts.joined()
        guard cleaned.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        guard cleaned.count == 8 else { return nil }

        var bytes = [UInt8]()
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }

        return UInt32(bytes[0]) |
            (UInt32(bytes[1]) << 8) |
            (UInt32(bytes[2]) << 16) |
            (UInt32(bytes[3]) << 24)
    }
}

// LibreView Account ID → receiver ID folds.
//
// Abbott ships two phone apps that pair Libre 3 sensors, and both take the
// same LibreView Account ID (a lowercase dashed UUID) but fold it differently.
// A sensor stores the receiver ID that activated it and answers a later
// `0xA0`/`0xA8` carrying a different one with NFC error `0xB1`, so an app that
// mirrors an Abbott account has to pick the fold belonging to the app that
// activated the sensor.
//
// The `libreByAbbott` fold was reverse-engineered and confirmed on live
// hardware on 2026-08-19: a US Libre 3 Plus (firmware 1.4.2.30) activated in
// "Libre by Abbott", paired in Parallel mode, completed the full first-pair
// handshake through Phase 6 and streamed. The existing `03 03` v1 certificate
// path covers these sensors unchanged.
extension Libre3ReceiverID {
    enum Derivation: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
        /// The classic "FreeStyle Libre 3" app. Applies the same fold as
        /// `accountlessValue(from:)`.
        case freeStyleLibre3

        /// The newer US "Libre by Abbott" app.
        ///
        /// Because the fold sums four-byte words, permutations of complete
        /// four-byte chunks collide, byte order *within* a word still matters.
        /// This weak structure suggests the observed sum is an intermediate
        /// from a larger routine rather than the app's final value. It is
        /// nevertheless what the sensor accepts.
        case libreByAbbott

        /// A LibreView Account ID is issued as a lowercase dashed UUID, so both
        /// folds run over the lowercased string. `accountlessValue(from:)` and
        /// `init(accountlessUniqueID:)` deliberately do not normalize: they fold
        /// whatever string they are handed, byte for byte, and stay that way
        /// because they are the long-validated path.
        func value(forAccountID accountID: String) -> UInt32 {
            let normalized = accountID.lowercased()
            switch self {
            case .freeStyleLibre3:
                return Libre3ReceiverID.accountlessValue(from: normalized)
            case .libreByAbbott:
                return Self.wordSumValue(from: normalized)
            }
        }

        /// UTF-8 bytes read as consecutive 4-byte big-endian words, summed with
        /// 32-bit wraparound. A trailing partial word is left-padded, matching
        /// `int.from_bytes` over a short slice, a 36-character account ID never
        /// reaches that path. Reading the words as signed rather than unsigned
        /// makes no difference: the two interpretations differ by a multiple of
        /// 2^32, which vanishes once the running sum wraps to 32 bits.
        private static func wordSumValue(from accountID: String) -> UInt32 {
            var sum: UInt32 = 0
            var word: UInt32 = 0
            var filled = 0

            for byte in accountID.utf8 {
                word = (word << 8) | UInt32(byte)
                filled += 1
                if filled == 4 {
                    sum &+= word
                    word = 0
                    filled = 0
                }
            }

            if filled > 0 {
                sum &+= word
            }

            return sum
        }
    }

    /// The receiver ID the given Abbott app derives from a LibreView Account ID.
    ///
    /// There is no default derivation: the caller has to know which app
    /// activated the sensor, and guessing produces a receiver ID the sensor
    /// rejects.
    init(accountID: String, derivation: Derivation) {
        self.init(derivation.value(forAccountID: accountID))
    }
}

enum Libre3ReceiverIDError: Error, Equatable {
    case invalidLittleEndianHex(String)
}
