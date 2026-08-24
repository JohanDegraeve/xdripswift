//
//  BackupCrypto.swift
//  xdrip
//
//  Created by Paul Plant on 13/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CommonCrypto
import CryptoKit
import Foundation
import Security

// Password-protected backups use PBKDF2 key derivation and authenticated AES-GCM encryption.
enum BackupCrypto {
    private static let keyLength = 32
    private static let saltLength = 16
    private static let iterations = 200_000

    static func encrypt(_ plaintext: Data, passphrase: String) throws -> BackupEncryptedData {
        let salt = try randomBytes(count: saltLength)
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        let sealedBox = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key))

        return BackupEncryptedData(
            salt: Data(salt),
            iv: sealedBox.nonce.withUnsafeBytes { Data($0) },
            ciphertextAndTag: sealedBox.ciphertext + sealedBox.tag,
            iterations: iterations
        )
    }

    static func decrypt(_ encrypted: BackupEncryptedData, passphrase: String) throws -> Data {
        do {
            guard encrypted.iterations == iterations else { throw BackupError.invalidFile }
            let key = try deriveKey(
                passphrase: passphrase,
                salt: Array(encrypted.salt),
                iterations: encrypted.iterations
            )
            guard encrypted.ciphertextAndTag.count >= 16 else { throw BackupError.invalidFile }
            let tagStart = encrypted.ciphertextAndTag.index(encrypted.ciphertextAndTag.endIndex, offsetBy: -16)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: encrypted.iv),
                ciphertext: encrypted.ciphertextAndTag[..<tagStart],
                tag: encrypted.ciphertextAndTag[tagStart...]
            )
            return try AES.GCM.open(sealedBox, using: SymmetricKey(data: key))
        } catch {
            throw BackupError.incorrectPassphrase
        }
    }

    private static func deriveKey(passphrase: String, salt: [UInt8], iterations: Int) throws -> [UInt8] {
        let password = Array(passphrase.utf8)
        var derivedKey = [UInt8](repeating: 0, count: keyLength)
        let status = password.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.bindMemory(to: Int8.self).baseAddress,
                    password.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derivedKey,
                    derivedKey.count
                )
            }
        }
        guard status == kCCSuccess else {
            throw BackupError.invalidFile
        }
        return derivedKey
    }

    private static func randomBytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw BackupError.invalidFile
        }
        return bytes
    }
}
