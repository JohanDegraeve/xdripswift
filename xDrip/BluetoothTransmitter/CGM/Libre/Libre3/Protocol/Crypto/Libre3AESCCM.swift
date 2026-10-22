//
//  Libre3AESCCM.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

// Adapted from RoundWhiteDiscKit.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Crypto/AESCCM.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation
import CommonCrypto

/// AES-128-CCM per NIST SP 800-38C. Authentication uses M=4,
/// notification channels use their separately defined tag lengths.
typealias Libre3AESBlockEncrypt = (Data) throws -> Data

private func xor(_ a: Data, _ b: Data) -> Data {
    Data(zip(a, b).map { $0 ^ $1 })
}

enum Libre3AESCCMError: Error, Equatable {
    case invalidParameters
    case macMismatch
    case backendFailure(Int32)
}

enum Libre3AESCCM {

    /// Returns (ciphertext, tag).
    static func encrypt(
        nonce: Data,
        plaintext: Data,
        aad: Data = Data(),
        tagLength: Int = 8,
        aes: Libre3AESBlockEncrypt
    ) throws -> (ciphertext: Data, tag: Data) {
        try checkParameters(nonce: nonce, tagLength: tagLength, plaintextLen: plaintext.count)
        let mac = try cbcMAC(nonce: nonce, aad: aad, plaintext: plaintext, tagLength: tagLength, aes: aes)
        let (ctOut, S0) = try ctrApply(plaintext, nonce: nonce, aes: aes)
        let tag = xor(mac.prefix(tagLength), S0.prefix(tagLength))
        return (ctOut, Data(tag))
    }

    /// Verifies and returns plaintext, or throws macMismatch.
    static func decrypt(
        nonce: Data,
        ciphertext: Data,
        tag: Data,
        aad: Data = Data(),
        aes: Libre3AESBlockEncrypt
    ) throws -> Data {
        try checkParameters(nonce: nonce, tagLength: tag.count, plaintextLen: ciphertext.count)
        let (ptCandidate, S0) = try ctrApply(ciphertext, nonce: nonce, aes: aes)
        let mac = try cbcMAC(nonce: nonce, aad: aad, plaintext: ptCandidate, tagLength: tag.count, aes: aes)
        let expected = xor(mac.prefix(tag.count), S0.prefix(tag.count))
        guard constantTimeEqual(expected, tag) else { throw Libre3AESCCMError.macMismatch }
        return ptCandidate
    }

    /// CBC-MAC over B_0 || formatted_AAD || zero-padded_plaintext per SP 800-38C.
    private static func cbcMAC(nonce: Data, aad: Data, plaintext: Data,
                                tagLength: Int, aes: Libre3AESBlockEncrypt) throws -> Data {
        var B = formatHeader(nonce: nonce, aad: aad, plaintextLen: plaintext.count, tagLength: tagLength)
        B.append(plaintext)
        if B.count % 16 != 0 {
            B.append(Data(count: 16 - (B.count % 16)))
        }
        var Y = Data(count: 16)
        for i in 0..<(B.count / 16) {
            let block = B.subdata(in: (i * 16)..<((i + 1) * 16))
            Y = try aes(xor(Y, block))
        }
        return Y
    }

    // MARK: - CCM internals

    private static func checkParameters(nonce: Data, tagLength: Int, plaintextLen: Int) throws {
        // L = 15 - len(nonce). Must be in [2, 8].
        let L = 15 - nonce.count
        guard L >= 2, L <= 8 else { throw Libre3AESCCMError.invalidParameters }
        // Tag length M ∈ {4, 6, 8, 10, 12, 14, 16}.
        guard [4, 6, 8, 10, 12, 14, 16].contains(tagLength) else { throw Libre3AESCCMError.invalidParameters }
        guard plaintextLen >= 0 else { throw Libre3AESCCMError.invalidParameters }
        // plaintextLen must fit in L bytes
        if L < 8 {
            let max = (UInt64(1) << (UInt64(L) * 8)) - 1
            if UInt64(plaintextLen) > max { throw Libre3AESCCMError.invalidParameters }
        }
    }

    /// Build the CBC-MAC header: B_0 || formatted_AAD (zero-padded to 16-byte boundary).
    private static func formatHeader(nonce: Data, aad: Data, plaintextLen: Int, tagLength: Int) -> Data {
        let L = 15 - nonce.count
        var B0 = Data(count: 16)
        let aFlag: UInt8 = aad.isEmpty ? 0 : 0x40
        let M = (UInt8(tagLength) - 2) / 2
        let Lflag = UInt8(L - 1)
        B0[0] = aFlag | (M << 3) | Lflag
        B0.replaceSubrange(1..<(1 + nonce.count), with: nonce)
        // Q (plaintext length) encoded as L-byte BE in last L bytes
        var q = UInt64(plaintextLen)
        for i in 0..<L {
            B0[15 - i] = UInt8(q & 0xff)
            q >>= 8
        }

        var out = B0

        if !aad.isEmpty {
            // Encode AAD length per SP 800-38C §A.2.2
            var enc = Data()
            let a = aad.count
            if a < 0xFF00 {
                enc.append(UInt8((a >> 8) & 0xff))
                enc.append(UInt8(a & 0xff))
            // Fix compilation failure with watchOS where Int is an Int32
            // } else if a <= 0xFFFFFFFF {
            } else if UInt64(a) <= 0xFFFFFFFF {
                enc.append(0xFF)
                enc.append(0xFE)
                let v = UInt32(a)
                enc.append(UInt8((v >> 24) & 0xff))
                enc.append(UInt8((v >> 16) & 0xff))
                enc.append(UInt8((v >> 8) & 0xff))
                enc.append(UInt8(v & 0xff))
            } else {
                enc.append(0xFF)
                enc.append(0xFF)
                let v = UInt64(a)
                for s in stride(from: 56, through: 0, by: -8) {
                    enc.append(UInt8((v >> s) & 0xff))
                }
            }
            enc.append(aad)
            // Pad to 16
            if enc.count % 16 != 0 {
                enc.append(Data(count: 16 - (enc.count % 16)))
            }
            out.append(enc)
        }

        return out
    }

    /// CTR mode: returns (output, S_0) where S_0 = AES(A_0).
    private static func ctrApply(_ inputData: Data, nonce: Data, aes: Libre3AESBlockEncrypt) throws -> (Data, Data) {
        let L = 15 - nonce.count
        // A_i = flags(L-1) || nonce || ctr_BE(L)
        var A = Data(count: 16)
        A[0] = UInt8(L - 1)
        A.replaceSubrange(1..<(1 + nonce.count), with: nonce)
        // S_0 keystream block
        var S0Block = A
        for i in (16 - L)..<16 { S0Block[i] = 0 }
        let S0 = try aes(S0Block)
        // Encrypt input in 16-byte chunks with ctr starting at 1
        var out = Data(capacity: inputData.count)
        var ctr: UInt64 = 1
        var idx = 0
        while idx < inputData.count {
            var Ai = A
            // Write counter big-endian into last L bytes
            var c = ctr
            for j in 0..<L {
                Ai[15 - j] = UInt8(c & 0xff)
                c >>= 8
            }
            let S = try aes(Ai)
            let take = min(16, inputData.count - idx)
            for k in 0..<take {
                out.append(inputData[inputData.startIndex + idx + k] ^ S[k])
            }
            idx += take
            ctr &+= 1
        }
        return (out, S0)
    }

    // MARK: - Convenience: AES_K via CommonCrypto

    /// Returns an `Libre3AESBlockEncrypt` closure backed by AES-128 ECB under `key`.
    /// All encryption uses the system AES implementation.
    static func commonCryptoBlockEncrypt(key: Data) -> Libre3AESBlockEncrypt {
        precondition(key.count == 16, "AES-128 requires a 16-byte key")
        let keyBytes = [UInt8](key)
        return { input in
            precondition(input.count == 16)
            var out = Data(count: 16)
            var moved: size_t = 0
            let inBytes = [UInt8](input)
            let status = out.withUnsafeMutableBytes { outPtr -> CCCryptorStatus in
                CCCrypt(
                    CCOperation(kCCEncrypt),
                    CCAlgorithm(kCCAlgorithmAES128),
                    CCOptions(kCCOptionECBMode),
                    keyBytes, keyBytes.count,
                    nil,
                    inBytes, inBytes.count,
                    outPtr.baseAddress, 16,
                    &moved
                )
            }
            guard status == kCCSuccess else { throw Libre3AESCCMError.backendFailure(Int32(status)) }
            return out
        }
    }
}

@inline(__always) func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
    guard a.count == b.count else { return false }
    var diff: UInt8 = 0
    for i in 0..<a.count { diff |= a[i] ^ b[i] }
    return diff == 0
}
