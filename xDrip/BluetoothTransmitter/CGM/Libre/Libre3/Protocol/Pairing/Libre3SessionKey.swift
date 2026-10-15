//
//  Libre3SessionKey.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CryptoKit

// App identity validation and authentication-key derivation adapted from RoundWhiteDiscKit.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/AppIdentity.swift
// MIT applies to Libre3AppIdentity and Libre3SessionKey. See license.md in the Libre3 folder.

/// Runtime app identity. Private scalars and certificates must never be logged or bundled.
struct Libre3AppIdentity: Sendable {
    let label: String
    let privateKey: P256.KeyAgreement.PrivateKey
    let certificate: Libre3PhoneCert

    init(label: String, privateKey: Data, certificate: Data) throws {
        let key = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        let cert = try Libre3PhoneCert(raw: certificate)
        guard !label.isEmpty, key.publicKey.x963Representation == cert.staticPub else {
            throw Libre3IdentityError.invalidFile
        }
        self.label = label
        self.privateKey = key
        self.certificate = cert
    }

    func authenticationKey(for handshake: Libre3PairingHandshakeResult) throws -> Data {
        let sensorStatic = try Libre3EphemeralExchange.parsePeerPubkey(handshake.sensorCert.staticPub)
        let staticSecret = try Libre3EphemeralExchange.sharedSecret(privateKey: privateKey, peer: sensorStatic)
        return Libre3SessionKey.derive(ephemeralSecret: handshake.sharedEphEph, staticSecret: staticSecret)
    }
}

// Authentication-key derivation shares the RoundWhiteDiscKit attribution above Libre3AppIdentity.
enum Libre3SessionKey {
    /// Counter-mode concatenation KDF: ephemeral agreement followed by static agreement.
    static func derive(ephemeralSecret: Data, staticSecret: Data) -> Data {
        Data(SHA256.hash(data: Data([0, 0, 0, 1]) + ephemeralSecret + staticSecret).prefix(16))
    }
}

enum Libre3IdentityError: LocalizedError {
    case invalidFile, unavailable
    var errorDescription: String? {
        TextsLibre3.localized(self == .invalidFile
            ? "Libre 3 credentials failed validation. The previous version has been kept."
            : "Libre 3 credentials could not be downloaded. Check your internet connection and retry before scanning.")
    }
}
