//
//  Libre3SensorCert.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/SensorCert.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation
import CryptoKit

// Sensor certificate - 140 bytes, received in Phase 2 of the pairing
// handshake (notify on handle 0x002d, reassembled from sensor → phone
// notify fragments).
//
// Format (decoded from captures/fresh_pair_2026_04_26):
//
//   [0]       msg_type  (0x01 observed)
//   [1..11)   10B header
//   [11]      0x04 (P-256 uncompressed-point prefix)
//   [12..76)  X(32) || Y(32)      ← sensor STATIC pubkey
//   [76..140) ECDSA signature     (64B raw r || s)
//
// The signature verifies as ECDSA-P256(SHA-256) over raw[0..<76] using the
// Abbott patch-signing key for the cert family. CryptoKit's
// P256.Signing APIs accept this raw r||s signature representation directly.

enum Libre3PatchSigningKey {
    /// Abbott patch-signing key family 0, 65-byte X9.63/uncompressed
    /// P-256 point. This is verifier material, not a private key.
    static let level0 = Data([
        0x04,
        0xb6, 0x9d, 0x17, 0x34, 0xf5, 0xe4, 0x25, 0xbc,
        0xc0, 0x57, 0x6a, 0xd1, 0xf7, 0x27, 0xc1, 0x31,
        0x1c, 0x90, 0xb6, 0xea, 0x98, 0x6f, 0x00, 0x6e,
        0x7e, 0x9f, 0x90, 0x96, 0xf6, 0xa8, 0x28, 0x4f,
        0x12, 0xbf, 0x7d, 0xdf, 0xe1, 0x54, 0xa3, 0xf1,
        0xd4, 0x5a, 0x0f, 0x27, 0x34, 0xec, 0xab, 0xca,
        0x6b, 0x9e, 0xb5, 0x6e, 0xe4, 0xec, 0xca, 0x87,
        0x85, 0x3a, 0xd8, 0x53, 0xb6, 0xa6, 0x41, 0x80,
    ])

    /// Abbott patch-signing key family 1, 65-byte X9.63/uncompressed
    /// P-256 point. Observed fresh-pair cert fixtures verify with this key.
    static let level1 = Data([
        0x04,
        0xa2, 0xd8, 0x47, 0x89, 0x90, 0x94, 0x5f, 0x70,
        0xa9, 0x57, 0x0a, 0xde, 0x07, 0xb1, 0x55, 0xbc,
        0x90, 0x4d, 0x2d, 0x38, 0x06, 0x47, 0x58, 0x7b,
        0x12, 0x39, 0x17, 0x01, 0x30, 0x9b, 0xd1, 0x0b,
        0x59, 0x90, 0xc4, 0xc4, 0x7c, 0x47, 0xf1, 0xf0,
        0x80, 0x46, 0xcb, 0x6f, 0x2d, 0xe0, 0x74, 0x8d,
        0x1f, 0xa7, 0xf7, 0x37, 0x90, 0xec, 0x9d, 0x8d,
        0xd6, 0x37, 0x21, 0x27, 0x78, 0x52, 0x88, 0x38,
    ])

    static let known: [Data] = [level0, level1]
}

struct Libre3SensorCert: Equatable, Sendable {
    let raw: Data           // full 140B blob
    let staticPub: Data     // 65B uncompressed P-256 point (with 0x04 prefix)
    let signature: Data     // 64B raw r || s

    static let totalSize: Int = 140
    static let signedPayloadRange: Range<Int> = 0..<76
    static let headerRange: Range<Int> = 0..<11
    static let pubkeyRange: Range<Int> = 11..<76
    static let signatureRange: Range<Int> = 76..<140

    init(raw: Data) throws {
        guard raw.count == Self.totalSize else { throw Libre3SensorCertError.wrongSize(raw.count) }
        let pub = raw.subdata(in: Self.pubkeyRange)
        guard pub.first == 0x04 else { throw Libre3SensorCertError.notUncompressedPoint }
        self.raw = raw
        self.staticPub = pub
        self.signature = raw.subdata(in: Self.signatureRange)
    }

    var header: Data {
        raw.subdata(in: Self.headerRange)
    }

    var signedPayload: Data {
        raw.subdata(in: Self.signedPayloadRange)
    }

    func verifyECDSA(with signingPublicKey: Data) throws -> Bool {
        guard signingPublicKey.count == 65, signingPublicKey.first == 0x04 else {
            throw Libre3SensorCertError.invalidSigningPublicKey
        }
        let publicKey = try P256.Signing.PublicKey(x963Representation: signingPublicKey)
        let ecdsaSignature = try P256.Signing.ECDSASignature(rawRepresentation: signature)
        return publicKey.isValidSignature(ecdsaSignature, for: signedPayload)
    }

    func verifiedSigningKeyIndex(in signingKeys: [Data] = Libre3PatchSigningKey.known) throws -> Int? {
        for (index, signingKey) in signingKeys.enumerated() {
            if try verifyECDSA(with: signingKey) {
                return index
            }
        }
        return nil
    }
}

enum Libre3SensorCertError: Error, Equatable {
    case wrongSize(Int)
    case notUncompressedPoint
    case invalidSigningPublicKey
}
