//
//  OttaiBleAuth.swift
//  xdrip
//
//  Ottai / Syai CGM driver — the math for the Bluetooth login ("Auth V2").
//  It uses secp256r1 ECDH key exchange, SHA-256 signatures, and a small rule to
//  pick the session key out of the shared secret.
//
//  This is a Swift copy of OttaiBleAuth.kt from JugglucoNG. No Bluetooth here.
//

import Foundation
import CryptoKit

enum OttaiBleAuth {

    /// Size of one number on the P-256 curve, in bytes.
    static let fieldLen = 32

    // MARK: - key pair

    /// A new P-256 key pair for one login.
    struct KeyPair {
        let privateKey: P256.KeyAgreement.PrivateKey
        /// X of our public key, 32 bytes, big-endian.
        let pubX: [UInt8]
        /// Y of our public key, 32 bytes, big-endian.
        let pubY: [UInt8]
    }

    /// Make a new secp256r1 key pair.
    static func generateKeyPair() -> KeyPair {
        let priv = P256.KeyAgreement.PrivateKey()
        let raw = [UInt8](priv.publicKey.rawRepresentation) // 64 bytes: X(32) || Y(32)
        let x = Array(raw[0 ..< 32])
        let y = Array(raw[32 ..< 64])
        return KeyPair(privateKey: priv, pubX: x, pubY: y)
    }

    // MARK: - little-endian helpers

    /// Read a 32-bit number from the first 4 bytes, little-endian.
    static func bytesToIntLE(_ b: [UInt8]) -> Int32 {
        precondition(b.count >= 4, "need >=4 bytes")
        return Int32(bitPattern:
            UInt32(b[0]) |
            (UInt32(b[1]) << 8) |
            (UInt32(b[2]) << 16) |
            (UInt32(b[3]) << 24))
    }

    /// Write a 32-bit number as 4 bytes, little-endian.
    static func intToBytesLE(_ i: Int32) -> [UInt8] {
        let u = UInt32(bitPattern: i)
        return [
            UInt8(u & 0xFF),
            UInt8((u >> 8) & 0xFF),
            UInt8((u >> 16) & 0xFF),
            UInt8((u >> 24) & 0xFF),
        ]
    }

    /// Make the 3-byte "app time" from the sensor's time bytes.
    /// Read the bytes as one big-endian number, add 1, and keep bits 24..8.
    static func appTime3(_ deviceTimeBytes: [UInt8]) -> [UInt8] {
        // big-endian parse of the raw bytes, +1
        var value: UInt64 = 0
        for b in deviceTimeBytes { value = (value << 8) | UInt64(b) }
        value = value &+ 1
        return [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
        ]
    }

    /// The value we write to characteristic 1756ef6e:
    /// `index(1 byte) || time3(3 bytes) || pubX || pubY`.
    static func appAuthParameter(selectedIndex: Int, time3: [UInt8], pubX: [UInt8], pubY: [UInt8]) -> [UInt8] {
        [UInt8(selectedIndex & 0xFF)] + time3 + pubX + pubY
    }

    // MARK: - signatures

    /// Signature = SHA256( authKey || mac || pubX || pubY || time3 ).
    /// We write ours to characteristic 785022c6, and we check the sensor's with it too.
    static func authSign(authKey: [UInt8], mac: [UInt8], pubX: [UInt8], pubY: [UInt8], time3: [UInt8]) -> [UInt8] {
        var hasher = SHA256()
        hasher.update(data: Data(authKey))
        hasher.update(data: Data(mac))
        hasher.update(data: Data(pubX))
        hasher.update(data: Data(pubY))
        hasher.update(data: Data(time3))
        return Array(hasher.finalize())
    }

    /// Same as authSign, but the key and the mac are hex text.
    static func authSignHex(authKeyHex: String, macHex: String, pubX: [UInt8], pubY: [UInt8], time3: [UInt8]) -> [UInt8] {
        authSign(authKey: OttaiCrypto.hexToBytes(authKeyHex),
                 mac: OttaiCrypto.hexToBytes(macHex),
                 pubX: pubX, pubY: pubY, time3: time3)
    }

    /// Check the signature the sensor sent (characteristic 785022c6).
    static func verifyDeviceSign(
        deviceSign: [UInt8],
        authKeyHex: String,
        macHex: String,
        devPubX: [UInt8],
        devPubY: [UInt8],
        devTime: [UInt8]
    ) -> Bool {
        let expect = authSign(
            authKey: OttaiCrypto.hexToBytes(authKeyHex),
            mac: OttaiCrypto.hexToBytes(macHex),
            pubX: devPubX, pubY: devPubY, time3: devTime
        )
        return expect == deviceSign
    }

    // MARK: - ECDH session key

    /// Make the session key. We combine our private key with the sensor's public
    /// key (ECDH), turn the shared X into hex, and pick characters from it.
    /// Returns nil if the sensor key is bad or the result is too short.
    static func deriveSessionKey(devPubXHex: String, devPubYHex: String, ourPrivate: P256.KeyAgreement.PrivateKey) -> String? {
        let x = OttaiCrypto.hexToBytes(devPubXHex)
        let y = OttaiCrypto.hexToBytes(devPubYHex)
        return deriveSessionKey(devPubX: x, devPubY: y, ourPrivate: ourPrivate)
    }

    static func deriveSessionKey(devPubX: [UInt8], devPubY: [UInt8], ourPrivate: P256.KeyAgreement.PrivateKey) -> String? {
        let xField = fixedFieldBytes(devPubX, fieldLen: fieldLen)
        let yField = fixedFieldBytes(devPubY, fieldLen: fieldLen)
        // A public key without the 0x04 prefix is just X(32) || Y(32).
        guard let devPub = try? P256.KeyAgreement.PublicKey(rawRepresentation: Data(xField + yField)) else {
            return nil
        }
        guard let shared = try? ourPrivate.sharedSecretFromKeyAgreement(with: devPub) else {
            return nil
        }
        // The shared secret is the full 32-byte X, with leading zeros kept.
        let sharedBytes = shared.withUnsafeBytes { [UInt8]($0) }
        let sharedHex = OttaiCrypto.bytesToHex(fixedFieldBytes(sharedBytes, fieldLen: fieldLen))
        return sessionKeyPick(sharedHex)
    }

    /// Make the value exactly [fieldLen] bytes: add zeros at the front, never cut.
    static func fixedFieldBytes(_ value: [UInt8], fieldLen: Int) -> [UInt8] {
        if value.count == fieldLen { return value }
        var out = [UInt8](repeating: 0, count: fieldLen)
        if value.count < fieldLen {
            for i in 0 ..< value.count { out[fieldLen - value.count + i] = value[i] }
        } else {
            // too long means an extra sign byte at the front: keep the last bytes
            for i in 0 ..< fieldLen { out[i] = value[value.count - fieldLen + i] }
        }
        return out
    }

    /// Pick the session key characters from the shared secret hex.
    /// Start at position 2, take one character, then move +1, +3, +1, +3 ...
    /// (positions 2,3,6,7,10,11,...). The result must be at least 32 characters.
    static func sessionKeyPick(_ sharedHex: String) -> String? {
        if sharedHex.isEmpty { return nil }
        let chars = Array(sharedHex)
        var out = String()
        var pos = 2
        var toggle = 1
        var i = 2
        while i < chars.count {
            if pos < chars.count {
                out.append(chars[pos])
                pos += (toggle != 0) ? 1 : 3
                toggle ^= 1
            }
            i += 1
        }
        return out.count >= 32 ? out : nil
    }
}
