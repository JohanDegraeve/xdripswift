//
//  Libre3EphemeralExchange.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

// Adapted from RoundWhiteDiscKit.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/EphemeralExchange.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation
import CryptoKit

struct Libre3EphemeralKeyPair: Sendable {
    let privateKey: P256.KeyAgreement.PrivateKey
    let publicKey65: Data   // 04 || X || Y

    init() {
        let priv = P256.KeyAgreement.PrivateKey()
        self.privateKey = priv
        self.publicKey65 = priv.publicKey.x963Representation
    }

    /// Construct from a previously-saved private key (e.g. for replay tests).
    init(privateKey: P256.KeyAgreement.PrivateKey) {
        self.privateKey = privateKey
        self.publicKey65 = privateKey.publicKey.x963Representation
    }

}

enum Libre3EphemeralExchange {

    /// Parse a 65-byte uncompressed P-256 point as a CryptoKit key.
    static func parsePeerPubkey(_ raw65: Data) throws -> P256.KeyAgreement.PublicKey {
        guard raw65.count == 65, raw65.first == 0x04 else {
            throw Libre3EphemeralExchangeError.invalidEncoding
        }
        return try P256.KeyAgreement.PublicKey(x963Representation: raw65)
    }

    /// Compute a single ECDH shared secret as raw 32 bytes.
    static func sharedSecret(
        privateKey: P256.KeyAgreement.PrivateKey,
        peer: P256.KeyAgreement.PublicKey
    ) throws -> Data {
        let s = try privateKey.sharedSecretFromKeyAgreement(with: peer)
        return s.withUnsafeBytes { Data($0) }
    }
}

enum Libre3EphemeralExchangeError: Error, Equatable {
    case invalidEncoding
}
