//
//  Libre3DataPlaneCrypto.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/DataPlane/DataPlaneCrypto.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

// Post-authorization data-plane AES-CCM helper.
//
//   key      = Phase 6 kEnc (16B)
//   nonce13  = seq16_LE || packetDescriptor3 || ivEnc8
//   tag      = 4B CCM tag appended to ciphertext
//
// The packet descriptors are small static constants. Live validation can try
// all descriptors and accept only a valid CCM tag, which keeps the app useful
// while we finish pinning descriptor-to-characteristic ownership.

enum Libre3DataPlanePacketKind: UInt8, CaseIterable, Sendable {
    case kind0 = 0
    case handshake = 1
    case kind2 = 2
    case kind3 = 3
    case kind4 = 4
    case kind5 = 5
    case kind6 = 6
    case patchData = 7

    /// Outbound patchControl command writes.
    static let patchControlWrite: Libre3DataPlanePacketKind = .kind0

    var descriptor: Data {
        switch self {
        case .kind0: return Data([0x00, 0x00, 0x00])
        case .handshake: return Data([0x00, 0x00, 0x0f])
        case .kind2: return Data([0x00, 0x00, 0xf0])
        case .kind3: return Data([0x00, 0x0f, 0x00])
        case .kind4: return Data([0x00, 0xf0, 0x00])
        case .kind5: return Data([0x0f, 0x00, 0x00])
        case .kind6: return Data([0xf0, 0x00, 0x00])
        case .patchData: return Data([0x44, 0x00, 0x00])
        }
    }
}

struct Libre3DataPlaneDecryptResult: Equatable, Sendable {
    let kind: Libre3DataPlanePacketKind
    let plaintext: Data
}

struct Libre3DataPlaneCrypto: Sendable {
    static let tagSize = 4

    let kEnc: Data
    let ivEnc: Data

    init(kEnc: Data, ivEnc: Data) throws {
        guard kEnc.count == 16 else { throw Libre3DataPlaneCryptoError.wrongKEncSize(kEnc.count) }
        guard ivEnc.count == 8 else { throw Libre3DataPlaneCryptoError.wrongIVEncSize(ivEnc.count) }
        self.kEnc = kEnc
        self.ivEnc = ivEnc
    }

    init(sessionMaterial: Libre3Phase6SessionMaterial) throws {
        try self.init(kEnc: sessionMaterial.kEnc, ivEnc: sessionMaterial.ivEnc)
    }

    func nonce(sequence: UInt16, kind: Libre3DataPlanePacketKind) -> Data {
        var out = Data(capacity: 13)
        out.append(UInt8(sequence & 0xff))
        out.append(UInt8((sequence >> 8) & 0xff))
        out.append(kind.descriptor)
        out.append(ivEnc)
        return out
    }

    func decrypt(_ frame: Libre3DataFrame, kind: Libre3DataPlanePacketKind) throws -> Data {
        guard frame.encrypted.count >= Self.tagSize else {
            throw Libre3DataPlaneCryptoError.payloadTooShort(frame.encrypted.count)
        }
        let tagStart = frame.encrypted.count - Self.tagSize
        let ciphertext = frame.encrypted.subdata(in: 0..<tagStart)
        let tag = frame.encrypted.subdata(in: tagStart..<frame.encrypted.count)
        return try Libre3AESCCM.decrypt(
            nonce: nonce(sequence: frame.sequenceNumber, kind: kind),
            ciphertext: ciphertext,
            tag: tag,
            aes: Libre3AESCCM.commonCryptoBlockEncrypt(key: kEnc)
        )
    }

    func decryptTryingAllKinds(_ frame: Libre3DataFrame) throws -> Libre3DataPlaneDecryptResult {
        for kind in Libre3DataPlanePacketKind.allCases {
            if let plaintext = try? decrypt(frame, kind: kind) {
                return Libre3DataPlaneDecryptResult(kind: kind, plaintext: plaintext)
            }
        }
        throw Libre3DataPlaneCryptoError.noDescriptorMatched
    }

    func encrypt(
        plaintext: Data,
        sequence: UInt16,
        kind: Libre3DataPlanePacketKind
    ) throws -> Libre3DataFrame {
        let (ciphertext, tag) = try Libre3AESCCM.encrypt(
            nonce: nonce(sequence: sequence, kind: kind),
            plaintext: plaintext,
            tagLength: Self.tagSize,
            aes: Libre3AESCCM.commonCryptoBlockEncrypt(key: kEnc)
        )
        return Libre3DataFrame(
            encrypted: ciphertext + tag,
            seq: UInt8(sequence & 0xff),
            type: UInt8((sequence >> 8) & 0xff)
        )
    }
}

enum Libre3DataPlaneCryptoError: Error, Equatable {
    case wrongKEncSize(Int)
    case wrongIVEncSize(Int)
    case payloadTooShort(Int)
    case noDescriptorMatched
}
