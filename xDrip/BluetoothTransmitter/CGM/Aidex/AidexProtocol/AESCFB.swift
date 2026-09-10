import Foundation
import CommonCrypto

/// AES-128-CFB шифрование/дешифрование поверх AES-ECB блоков (CommonCrypto).
///
/// Режим CFB-128 (размер блока 16 байт):
/// ```
/// Для каждого 16-байтного блока:
///   encryptedFeedback = AES-ECB-ENCRYPT(key, feedback)
///   output[i] = input[i] XOR encryptedFeedback[i]
///   feedback = CIPHERTEXT (для шифрования и дешифрования)
/// ```
enum AESCFB {

    private static let blockSize = Int(kCCBlockSizeAES128)

    // MARK: - Core CFB

    /// AES-128-CFB дешифрование.
    static func decrypt(_ ciphertext: Data, key: Data, iv: Data) -> Data? {
        guard key.count == blockSize, iv.count == blockSize, !ciphertext.isEmpty else { return nil }

        var result = Data(count: ciphertext.count)
        var feedback = iv
        var offset = 0

        while offset < ciphertext.count {
            let chunkSize = min(blockSize, ciphertext.count - offset)
            let encryptedFeedback = ecbEncrypt(feedback, key: key)

            for i in 0..<chunkSize {
                result[offset + i] = ciphertext[offset + i] ^ encryptedFeedback[i]
            }

            if chunkSize == blockSize {
                feedback = ciphertext.subdata(in: offset..<offset + blockSize)
            }
            offset += chunkSize
        }
        return result
    }

    /// AES-128-CFB шифрование.
    static func encrypt(_ plaintext: Data, key: Data, iv: Data) -> Data? {
        guard key.count == blockSize, iv.count == blockSize, !plaintext.isEmpty else { return nil }

        var result = Data(count: plaintext.count)
        var feedback = iv
        var offset = 0

        while offset < plaintext.count {
            let chunkSize = min(blockSize, plaintext.count - offset)
            let encryptedFeedback = ecbEncrypt(feedback, key: key)

            for i in 0..<chunkSize {
                result[offset + i] = plaintext[offset + i] ^ encryptedFeedback[i]
            }

            if chunkSize == blockSize {
                feedback = result.subdata(in: offset..<offset + blockSize)
            }
            offset += chunkSize
        }
        return result
    }

    // MARK: - BOND

    /// Дешифрование 17-байтных BOND-данных в 16-байтный session key.
    ///
    /// 1. AES-CFB decrypt 17 байт используя PAIR key + SN IV
    /// 2. Проверить CRC-8/MAXIM: decrypted[16] == CRC8(decrypted[0..15])
    /// 3. Вернуть decrypted[0..15]
    static func decryptBondData(_ bondData: Data, pairKey: Data, iv: Data) -> Data? {
        guard bondData.count == 17, pairKey.count == 16, iv.count == 16 else { return nil }

        guard let decrypted = decrypt(bondData, key: pairKey, iv: iv) else { return nil }
        guard decrypted.count == 17 else { return nil }

        let sessionKey = decrypted.prefix(16)
        let checksumByte = decrypted[16]
        let computed = CRC8.checksum(sessionKey)

        guard checksumByte == computed else { return nil }
        return sessionKey
    }

    // MARK: - ECB building block

    private static func ecbEncrypt(_ block: Data, key: Data) -> Data {
        precondition(block.count == Int(kCCBlockSizeAES128), "ECB block must be exactly 16 bytes")
        let blockBytes = block.withUnsafeBytes { Data($0) }
        let keyBytes = key.withUnsafeBytes { Data($0) }
        var out = Data(count: Int(kCCBlockSizeAES128))
        var outLen = 0
        out.withUnsafeMutableBytes { outPtr in
            blockBytes.withUnsafeBytes { blockPtr in
                keyBytes.withUnsafeBytes { keyPtr in
                    _ = CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode),
                        keyPtr.baseAddress, Int(kCCKeySizeAES128),
                        nil,
                        blockPtr.baseAddress, Int(kCCBlockSizeAES128),
                        outPtr.baseAddress, Int(kCCBlockSizeAES128),
                        &outLen
                    )
                }
            }
        }
        return out
    }
}