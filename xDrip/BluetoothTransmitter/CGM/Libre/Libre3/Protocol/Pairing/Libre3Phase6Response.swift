//
//  Libre3Phase6Response.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

// Adapted from RoundWhiteDiscKit.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/Phase6Response.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

// Phase 6 sensor -> phone wire format on handle 0x002a.
//
// Ground truth from 2026-05-06 live iPhone and Android pristine runs:
//   [0..56)   ciphertext for plaintext56 = R2 || R1 || kEnc || ivEnc8
//   [56..60)  CCM tag, M=4
//   [60..67)  sensor nonce7
//

struct Libre3Phase6SessionMaterial: Equatable, Sendable {
    let phoneR2: Data
    let sensorR1: Data
    let kEnc: Data
    let ivEnc: Data

    init(phoneR2: Data, sensorR1: Data, kEnc: Data, ivEnc: Data) throws {
        guard phoneR2.count == 16 else { throw Libre3Phase6ResponseError.wrongR2Size(phoneR2.count) }
        guard sensorR1.count == 16 else { throw Libre3Phase6ResponseError.wrongR1Size(sensorR1.count) }
        guard kEnc.count == 16 else { throw Libre3Phase6ResponseError.wrongKEncSize(kEnc.count) }
        guard ivEnc.count == 8 else { throw Libre3Phase6ResponseError.wrongIVEncSize(ivEnc.count) }
        self.phoneR2 = phoneR2
        self.sensorR1 = sensorR1
        self.kEnc = kEnc
        self.ivEnc = ivEnc
    }
}

struct Libre3Phase6Response: Equatable, Sendable {
    static let plaintextSize: Int = 56
    static let ciphertextSize: Int = 56
    static let tagSize: Int = 4
    static let logicalSize: Int = 60
    static let wireSize: Int = 67

    let ciphertext: Data
    let tag: Data
    let nonce: Data

    init(ciphertext: Data, tag: Data, nonce: Data) throws {
        guard ciphertext.count == Self.ciphertextSize else {
            throw Libre3Phase6ResponseError.wrongCiphertextSize(ciphertext.count)
        }
        guard tag.count == Self.tagSize else { throw Libre3Phase6ResponseError.wrongTagSize(tag.count) }
        guard nonce.count == 7 else { throw Libre3ChallengeError.wrongNonceSize(nonce.count) }
        self.ciphertext = ciphertext
        self.tag = tag
        self.nonce = nonce
    }

    static func decode(_ raw: Data) throws -> Libre3Phase6Response {
        guard raw.count == Self.wireSize else { throw Libre3ChallengeError.wrongWireSize(raw.count) }
        return try Libre3Phase6Response(
            ciphertext: raw.subdata(in: 0..<Self.ciphertextSize),
            tag: raw.subdata(in: Self.ciphertextSize..<Self.logicalSize),
            nonce: raw.subdata(in: Self.logicalSize..<Self.wireSize)
        )
    }

    func decrypt(aes: Libre3AESBlockEncrypt, aad: Data = Data()) throws -> Libre3Phase6SessionMaterial {
        let plaintext = try Libre3AESCCM.decrypt(
            nonce: nonce,
            ciphertext: ciphertext,
            tag: tag,
            aad: aad,
            aes: aes
        )
        guard plaintext.count == Self.plaintextSize else {
            throw Libre3Phase6ResponseError.wrongPlaintextSize(plaintext.count)
        }
        return try Libre3Phase6SessionMaterial(
            phoneR2: plaintext.subdata(in: 0..<16),
            sensorR1: plaintext.subdata(in: 16..<32),
            kEnc: plaintext.subdata(in: 32..<48),
            ivEnc: plaintext.subdata(in: 48..<56)
        )
    }

    func decrypt(rawKey: Data, aad: Data = Data()) throws -> Libre3Phase6SessionMaterial {
        guard rawKey.count == 16 else { throw Libre3ChallengeError.wrongKeySize(rawKey.count) }
        let aes = Libre3AESCCM.commonCryptoBlockEncrypt(key: rawKey)
        return try decrypt(aes: aes, aad: aad)
    }
}

enum Libre3Phase6ResponseError: Error, Equatable {
    case wrongCiphertextSize(Int)
    case wrongTagSize(Int)
    case wrongPlaintextSize(Int)
    case wrongR2Size(Int)
    case wrongR1Size(Int)
    case wrongKEncSize(Int)
    case wrongIVEncSize(Int)
}
