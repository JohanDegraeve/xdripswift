//
//  Libre3ChallengeMessage.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/ChallengeMessage.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

// Phase 5 phone -> sensor wire format on handle 0x002a.
//
// Ground truth as of 2026-05-06:
//   [0..36)   ciphertext for plaintext36 = R1 || R2 || tail4
//   [36..40)  CCM tag, M=4
//   [40..54)  zero pad so the fixed 3 x 18B BLE write shape lines up
//
// The CCM nonce is the 7-byte trailer from the sensor's 23B challenge notify:
//   sensor_A = R1(16) || nonce7(7)
//

struct Libre3Phase5Challenge: Equatable, Sendable {
    static let plaintextSize: Int = 36
    static let ciphertextSize: Int = 36
    static let tagSize: Int = 4
    static let logicalSize: Int = 40   // ct36 + tag4
    static let wireSize: Int    = 54   // 3 × 18B fragmented writes

    let ciphertext: Data   // 36B
    let tag: Data          // 4B

    init(ciphertext: Data, tag: Data) throws {
        guard ciphertext.count == Self.ciphertextSize else { throw Libre3ChallengeError.wrongCiphertextSize(ciphertext.count) }
        guard tag.count == Self.tagSize else { throw Libre3ChallengeError.wrongTagSize(tag.count) }
        self.ciphertext = ciphertext
        self.tag = tag
    }

    /// Encrypt the 36-byte R1 || R2 || BLE PIN using the authentication key.
    static func encrypt(
        plaintext: Data,
        sessionKey: Data,
        nonce: Data,
        aad: Data = Data()
    ) throws -> Libre3Phase5Challenge {
        guard sessionKey.count == 16 else { throw Libre3ChallengeError.wrongKeySize(sessionKey.count) }
        let aes = Libre3AESCCM.commonCryptoBlockEncrypt(key: sessionKey)
        return try encrypt(plaintext: plaintext, aes: aes, nonce: nonce, aad: aad)
    }

    static func encrypt(
        plaintext: Data,
        aes: Libre3AESBlockEncrypt,
        nonce: Data,
        aad: Data = Data()
    ) throws -> Libre3Phase5Challenge {
        guard plaintext.count == Self.plaintextSize else { throw Libre3ChallengeError.wrongPlaintextSize(plaintext.count) }
        guard nonce.count == 7 else { throw Libre3ChallengeError.wrongNonceSize(nonce.count) }
        let (ct, tag) = try Libre3AESCCM.encrypt(nonce: nonce, plaintext: plaintext, aad: aad, tagLength: Self.tagSize, aes: aes)
        return try Libre3Phase5Challenge(ciphertext: ct, tag: tag)
    }

    func decrypt(sessionKey: Data, nonce: Data, aad: Data = Data()) throws -> Data {
        guard sessionKey.count == 16 else { throw Libre3ChallengeError.wrongKeySize(sessionKey.count) }
        let aes = Libre3AESCCM.commonCryptoBlockEncrypt(key: sessionKey)
        return try decrypt(aes: aes, nonce: nonce, aad: aad)
    }

    func decrypt(aes: Libre3AESBlockEncrypt, nonce: Data, aad: Data = Data()) throws -> Data {
        guard nonce.count == 7 else { throw Libre3ChallengeError.wrongNonceSize(nonce.count) }
        return try Libre3AESCCM.decrypt(nonce: nonce, ciphertext: ciphertext, tag: tag, aad: aad, aes: aes)
    }

    /// Encode as the 40-byte logical message (ct36 || tag4).
    var logicalBytes: Data { ciphertext + tag }

    /// Encode as the 54-byte wire payload (logical + 14B zero pad).
    var wireBytes: Data {
        var out = Data(capacity: Self.wireSize)
        out.append(logicalBytes)
        out.append(Data(count: Self.wireSize - Self.logicalSize))
        return out
    }

    /// Parse the 54-byte wire payload (or accept the 40-byte logical form).
    static func decode(_ raw: Data) throws -> Libre3Phase5Challenge {
        guard raw.count == wireSize || raw.count == logicalSize else {
            throw Libre3ChallengeError.wrongWireSize(raw.count)
        }
        return try Libre3Phase5Challenge(
            ciphertext: raw.subdata(in: 0..<36),
            tag: raw.subdata(in: 36..<40)
        )
    }
}

enum Libre3ChallengeError: Error, Equatable {
    case wrongNonceSize(Int)
    case wrongCiphertextSize(Int)
    case wrongTagSize(Int)
    case wrongPlaintextSize(Int)
    case wrongKeySize(Int)
    case wrongWireSize(Int)
}
