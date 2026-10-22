//
//  Libre3AESCCMTests.swift
//  xdrip
//
// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Tests/RoundWhiteDiscKitTests/AESCCMTests.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import XCTest
@testable import xdrip

final class Libre3AESCCMTests: XCTestCase {
    // RFC 3610 Packet Vector #1
    //   Key:    C0 C1 C2 C3 C4 C5 C6 C7 C8 C9 CA CB CC CD CE CF
    //   Nonce:  00 00 00 03 02 01 00 A0 A1 A2 A3 A4 A5     (13 bytes)
    //   AAD:    00 01 02 03 04 05 06 07                     (8 bytes)
    //   PT:     08 09 0A 0B 0C 0D 0E 0F 10 11 12 13 14 15 16 17
    //           18 19 1A 1B 1C 1D 1E 1F 20 21 22 23
    //   CT:     58 8C 97 9A 61 C6 63 D2 F0 66 D0 C2 C0 F9 89 80
    //           6D 5F 6B 61 DA C3 84
    //   Tag:    17 E8 D1 2C FD F9 26 E0  (M=8)

    func testRFC3610Vector1RoundTrip() throws {
        let key = Data([
            0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7,
            0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF,
        ])
        let nonce = Data([
            0x00, 0x00, 0x00, 0x03, 0x02, 0x01, 0x00,
            0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5,
        ])
        let aad = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        let pt = Data([
            0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
            0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
            0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E,
        ])
        let expectedCT = Data([
            0x58, 0x8C, 0x97, 0x9A, 0x61, 0xC6, 0x63, 0xD2,
            0xF0, 0x66, 0xD0, 0xC2, 0xC0, 0xF9, 0x89, 0x80,
            0x6D, 0x5F, 0x6B, 0x61, 0xDA, 0xC3, 0x84,
        ])
        let expectedTag = Data([0x17, 0xE8, 0xD1, 0x2C, 0xFD, 0xF9, 0x26, 0xE0])

        let aes = Libre3AESCCM.commonCryptoBlockEncrypt(key: key)
        let (ct, tag) = try Libre3AESCCM.encrypt(nonce: nonce, plaintext: pt, aad: aad, tagLength: 8, aes: aes)
        XCTAssertEqual(ct, expectedCT)
        XCTAssertEqual(tag, expectedTag)

        let recovered = try Libre3AESCCM.decrypt(nonce: nonce, ciphertext: ct, tag: tag, aad: aad, aes: aes)
        XCTAssertEqual(recovered, pt)
    }

    func testTamperFailsAuth() throws {
        let key = Data(count: 16)
        let nonce = Data(count: 13)
        let aes = Libre3AESCCM.commonCryptoBlockEncrypt(key: key)
        let (ct, tag) = try Libre3AESCCM.encrypt(
            nonce: nonce, plaintext: Data("hello world".utf8),
            aad: Data(), tagLength: 8, aes: aes)
        var tampered = ct
        tampered[0] ^= 1
        XCTAssertThrowsError(try Libre3AESCCM.decrypt(nonce: nonce, ciphertext: tampered, tag: tag, aad: Data(), aes: aes)) { e in
            XCTAssertTrue((e as? Libre3AESCCMError) == Libre3AESCCMError.macMismatch)
        }
    }
}
