//
//  OttaiCrypto.swift
//  xdrip
//
//  Ottai / Syai CGM driver — encryption helpers.
//
//  This is a Swift copy of OttaiCrypto.kt from JugglucoNG.
//
//  The account has a secret key called `glucoseSecretKey`. The cloud sends three
//  encrypted fields for each sensor:
//    - keyA        -> six 16-byte keys for the Bluetooth login (192 hex chars)
//    - method      -> the glucose formula (see OttaiFormula)
//    - coefficient -> the numbers used by that formula
//
//  Each field has its own AES key:
//    fieldKey = glucoseSecretKey + last 10 chars of <time> + last 6 chars of <mac>
//  The cipher is AES in ECB mode with PKCS5 padding. There is no IV.
//
//  Bluetooth data uses AES ECB with "zero byte padding". We do the same thing with
//  AES ECB "no padding" and add the zero bytes ourselves.
//
//  No network, no Bluetooth here. AES comes from CommonCrypto, which is the only
//  system API that offers ECB (CryptoKit deliberately does not).
//

import CommonCrypto
import Foundation

enum OttaiCrypto {

    /// Six 16-byte Bluetooth login keys come out of one decrypted keyA.
    static let authKeyCount = 6
    static let authKeyBytes = 16
    static let authKeyHexLen = authKeyCount * authKeyBytes * 2 // 192

    // MARK: - cloud secret chain

    /// The last [n] characters of [s].
    static func takeLast(_ n: Int, _ s: String) -> String {
        if n <= 0 { return "" }
        if s.count <= n { return s }
        return String(s.suffix(n))
    }

    /// Build the AES key text for one cloud field.
    ///
    /// - Parameters:
    ///   - glucoseSecretKey: the account secret from login (never log it)
    ///   - fieldTimestamp: produceTime, methodUpdateTime or coeffUpdateTime
    ///   - mac: the sensor MAC. Only the last 6 characters are used, as in the app.
    static func deriveFieldKey(glucoseSecretKey: String, fieldTimestamp: String, mac: String) -> String {
        glucoseSecretKey + takeLast(10, fieldTimestamp) + takeLast(6, mac)
    }

    static func deriveFieldKey(glucoseSecretKey: String, fieldTimestamp: Int64, mac: String) -> String {
        deriveFieldKey(glucoseSecretKey: glucoseSecretKey, fieldTimestamp: String(fieldTimestamp), mac: mac)
    }

    /// Decrypt one base64 cloud field with AES ECB PKCS5.
    /// - Returns: the text, or nil if anything fails.
    static func decryptCloudField(base64Cipher: String, fieldKey: String) -> String? {
        guard let cipherBytes = base64Decode(base64Cipher) else { return nil }
        guard let plain = aesECB(.decrypt, key: Array(fieldKey.utf8), data: cipherBytes, pkcs7Padded: true) else { return nil }
        return String(bytes: plain, encoding: .utf8)
    }

    /// Encrypt text with AES ECB PKCS5 and return base64. Only used in tests.
    static func encryptCloudField(plaintext: String, fieldKey: String) -> String? {
        guard let out = aesECB(.encrypt, key: Array(fieldKey.utf8), data: Array(plaintext.utf8), pkcs7Padded: true) else { return nil }
        return Data(out).base64EncodedString()
    }

    /// Decrypt keyA. The time is produceTime.
    static func decryptKeyA(base64KeyA: String, glucoseSecretKey: String, produceTime: String, mac: String) -> String? {
        decryptCloudField(base64Cipher: base64KeyA,
                          fieldKey: deriveFieldKey(glucoseSecretKey: glucoseSecretKey, fieldTimestamp: produceTime, mac: mac))
    }

    /// Decrypt the method. The time is methodUpdateTime.
    static func decryptMethod(base64Method: String, glucoseSecretKey: String, methodUpdateTime: String, mac: String) -> String? {
        decryptCloudField(base64Cipher: base64Method,
                          fieldKey: deriveFieldKey(glucoseSecretKey: glucoseSecretKey, fieldTimestamp: methodUpdateTime, mac: mac))
    }

    /// Decrypt the coefficients. The time is coeffUpdateTime.
    static func decryptCoefficient(base64Coeff: String, glucoseSecretKey: String, coeffUpdateTime: String, mac: String) -> String? {
        decryptCloudField(base64Cipher: base64Coeff,
                          fieldKey: deriveFieldKey(glucoseSecretKey: glucoseSecretKey, fieldTimestamp: coeffUpdateTime, mac: mac))
    }

    /// Split a decrypted keyA (192 hex chars) into six 16-byte keys.
    /// Returns nil if the text is not exactly 192 hex chars.
    static func parseAuthKeys(_ keyAHexPlain: String) -> [[UInt8]]? {
        let hex = keyAHexPlain.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.count != authKeyHexLen { return nil }
        if !hex.allSatisfy({ $0.isHexChar }) { return nil }
        let chars = Array(hex)
        var out: [[UInt8]] = []
        for i in 0 ..< authKeyCount {
            let sub = String(chars[(i * 32) ..< (i * 32 + 32)])
            out.append(hexToBytes(sub))
        }
        return out
    }

    // MARK: - Bluetooth data (session key)
    //
    // The app uses AES ECB with zero byte padding and the session key as bytes.
    // Encrypt: add zero bytes up to a multiple of 16. Decrypt: if the length is
    // even and the last 8 bytes are all zero, drop those 8 bytes.

    /// Decrypt a live or history packet with the session key (hex text).
    static func decryptPayload(_ cipher: [UInt8], sessionKeyHex: String) -> [UInt8]? {
        guard let key = try? hexToBytesStrict(sessionKeyHex) else { return nil }
        if cipher.isEmpty || cipher.count % 16 != 0 { return nil }
        guard let plain = aesECB(.decrypt, key: key, data: cipher, pkcs7Padded: false) else { return nil }
        return trimTrailingZeroBlock(plain)
    }

    static func decryptPayload(_ cipher: Data, sessionKeyHex: String) -> [UInt8]? {
        decryptPayload([UInt8](cipher), sessionKeyHex: sessionKeyHex)
    }

    /// Drop the last 8 bytes only when the length is even and they are all zero.
    private static func trimTrailingZeroBlock(_ data: [UInt8]) -> [UInt8] {
        if data.count >= 8 && data.count % 2 == 0 {
            var allZero = true
            for i in (data.count - 8) ..< data.count where data[i] != 0 {
                allZero = false
                break
            }
            if allZero { return Array(data[0 ..< (data.count - 8)]) }
        }
        return data
    }

    /// Build the "activate" command: pad [cmd] with zeros to 16 bytes, then encrypt
    /// with the session key.
    static func encryptActivateCmd(_ cmd: [UInt8], sessionKeyHex: String) -> [UInt8]? {
        guard let key = try? hexToBytesStrict(sessionKeyHex) else { return nil }
        return aesECB(.encrypt, key: key, data: zeroPad16(cmd), pkcs7Padded: false)
    }

    /// Encrypt any bytes with zero padding and the session key.
    static func encryptPayload(_ plain: [UInt8], sessionKeyHex: String) -> [UInt8]? {
        guard let key = try? hexToBytesStrict(sessionKeyHex) else { return nil }
        return aesECB(.encrypt, key: key, data: zeroPad16(plain), pkcs7Padded: false)
    }

    private static func zeroPad16(_ data: [UInt8]) -> [UInt8] {
        if data.isEmpty { return [UInt8](repeating: 0, count: 16) }
        let rem = data.count % 16
        if rem == 0 { return data }
        return data + [UInt8](repeating: 0, count: 16 - rem)
    }

    // MARK: - AES ECB

    enum AESOperation {
        case encrypt
        case decrypt

        var ccOperation: CCOperation {
            CCOperation(self == .encrypt ? kCCEncrypt : kCCDecrypt)
        }
    }

    /// AES in ECB mode, with or without PKCS7 padding. There is no IV.
    ///
    /// - Returns: the result, or nil when the key length is not an AES key length, when unpadded
    ///   data is not a whole number of blocks, or when CommonCrypto reports a failure.
    static func aesECB(_ operation: AESOperation, key: [UInt8], data: [UInt8], pkcs7Padded: Bool) -> [UInt8]? {
        guard key.count == kCCKeySizeAES128 || key.count == kCCKeySizeAES192 || key.count == kCCKeySizeAES256 else { return nil }
        guard pkcs7Padded || (!data.isEmpty && data.count % kCCBlockSizeAES128 == 0) else { return nil }
        if data.isEmpty && operation == .decrypt { return [] }

        var options = CCOptions(kCCOptionECBMode)
        if pkcs7Padded { options |= CCOptions(kCCOptionPKCS7Padding) }

        var out = [UInt8](repeating: 0, count: data.count + kCCBlockSizeAES128)
        let outCapacity = out.count
        var outLength = 0

        let status = out.withUnsafeMutableBytes { outBytes in
            key.withUnsafeBytes { keyBytes in
                data.withUnsafeBytes { dataBytes in
                    CCCrypt(
                        operation.ccOperation,
                        CCAlgorithm(kCCAlgorithmAES),
                        options,
                        keyBytes.baseAddress, key.count,
                        nil,
                        dataBytes.baseAddress, data.count,
                        outBytes.baseAddress, outCapacity,
                        &outLength
                    )
                }
            }
        }

        guard status == CCCryptorStatus(kCCSuccess) else { return nil }
        return Array(out[0 ..< outLength])
    }

    // MARK: - hex

    static func hexToBytes(_ hex: String) -> [UInt8] {
        (try? hexToBytesStrict(hex)) ?? []
    }

    /// Same as hexToBytes, but throws on bad text. Used for the session key.
    static func hexToBytesStrict(_ hex: String) throws -> [UInt8] {
        let chars = Array(hex)
        guard chars.count % 2 == 0 else { throw OttaiCryptoError.oddHexLength }
        var out = [UInt8]()
        out.reserveCapacity(chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let hi = chars[i].hexDigitValue, let lo = chars[i + 1].hexDigitValue else {
                throw OttaiCryptoError.badHexChar
            }
            out.append(UInt8((hi << 4) | lo))
            i += 2
        }
        return out
    }

    static func bytesToHex(_ bytes: [UInt8]) -> String {
        var s = String()
        s.reserveCapacity(bytes.count * 2)
        for b in bytes {
            s.append(hexDigits[Int(b >> 4)])
            s.append(hexDigits[Int(b & 0x0F)])
        }
        return s
    }

    static func bytesToHex(_ data: Data) -> String { bytesToHex([UInt8](data)) }

    private static let hexDigits = Array("0123456789abcdef")

    // MARK: - base64

    static func base64Decode(_ s: String) -> [UInt8]? {
        let clean = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return [] }
        guard let data = Data(base64Encoded: clean) else { return nil }
        return [UInt8](data)
    }

    enum OttaiCryptoError: Error {
        case oddHexLength
        case badHexChar
    }
}

private extension Character {
    var isHexChar: Bool {
        ("0" ... "9").contains(self) || ("a" ... "f").contains(self) || ("A" ... "F").contains(self)
    }
}
