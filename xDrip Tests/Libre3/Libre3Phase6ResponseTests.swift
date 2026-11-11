//
//  Libre3Phase6ResponseTests.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
import CryptoKit
import Security
@testable import xdrip

final class Libre3Phase6ResponseTests: XCTestCase {
    private let key = Data(repeating: 0x42, count: 16)

    private func wire() throws -> Data {
        let plaintext =
            Data(repeating: 1, count: 16) + Data(repeating: 2, count: 16)
            + Data(repeating: 3, count: 16) + Data(repeating: 4, count: 8)
        let nonce = Data(repeating: 5, count: 7)
        let (ciphertext, tag) = try Libre3AESCCM.encrypt(
            nonce: nonce, plaintext: plaintext,
            tagLength: 4, aes: Libre3AESCCM.commonCryptoBlockEncrypt(key: key))
        return ciphertext + tag + nonce
    }

    func testStandardAESResponseDecryptsSessionMaterial() throws {
        let material = try Libre3Phase6Response.decode(wire()).decrypt(rawKey: key)
        XCTAssertEqual(material.phoneR2, Data(repeating: 1, count: 16))
        XCTAssertEqual(material.sensorR1, Data(repeating: 2, count: 16))
        XCTAssertEqual(material.kEnc, Data(repeating: 3, count: 16))
        XCTAssertEqual(material.ivEnc, Data(repeating: 4, count: 8))
    }

    func testTamperingAndWrongKeyFailAuthentication() throws {
        var data = try wire()
        data[0] ^= 1
        XCTAssertThrowsError(try Libre3Phase6Response.decode(data).decrypt(rawKey: key))
        XCTAssertThrowsError(try Libre3Phase6Response.decode(wire()).decrypt(rawKey: Data(repeating: 0x43, count: 16)))
    }

    func testDownloadedIdentityMustMatchCertificate() throws {
        let key = P256.KeyAgreement.PrivateKey()
        let certificate = Data(count: 33) + key.publicKey.x963Representation + Data(count: 64)
        let entry: [String: String] = [
            "label": "synthetic", "privateKeyHex": key.rawRepresentation.hex,
            "certificateHex": certificate.hex,
        ]
        let json = try JSONSerialization.data(withJSONObject: ["format": 1, "curve": "P-256", "identities": [entry]])
        let digest = SHA256.hash(data: json).map { String(format: "%02x", $0) }.joined()
        let identities = try Libre3IdentityStore.validate(json: json, digest: digest)
        XCTAssertEqual(identities.count, 1)
        XCTAssertEqual(identities.first?.certificate.raw, certificate)
        XCTAssertThrowsError(try Libre3IdentityStore.validate(json: json, digest: String(repeating: "0", count: 64)))
        XCTAssertThrowsError(
            try Libre3AppIdentity(
                label: "mismatch", privateKey: P256.KeyAgreement.PrivateKey().rawRepresentation,
                certificate: certificate))
    }

    func testKDFMatchesIndependentHashVectorAndUsesStaticSecret() {
        let ephemeral = Data(repeating: 1, count: 32), staticSecret = Data(repeating: 2, count: 32)
        XCTAssertEqual(
            Libre3SessionKey.derive(ephemeralSecret: ephemeral, staticSecret: staticSecret).hex,
            "e97f08effaff1721038aa5cd96ffbe1e")
        XCTAssertNotEqual(
            Libre3SessionKey.derive(ephemeralSecret: ephemeral, staticSecret: staticSecret),
            Libre3SessionKey.derive(ephemeralSecret: staticSecret, staticSecret: ephemeral))
    }
}

final class Libre3PairingFlowTests: XCTestCase {
    func testFreshPairingAndOfflineCachedReconnect() async throws {
        let sensor = try SimulatedLibre3Sensor()
        let identity = try await sensor.appIdentity()
        let verifier = await sensor.verifier()
        let flow = Libre3PairingFlow(transport: sensor, phoneCert: identity.certificate, sensorCertSigningKeys: [verifier])
        let result = try await flow.runCommandGatedFirstPairHandshake(
            blePIN: Data(repeating: 7, count: 4),
            phase5RawKeyProvider: { try identity.authenticationKey(for: $0.phaseHandshake) })
        XCTAssertEqual(result.sessionMaterial.kEnc, Data(repeating: 9, count: 16))
        let commands = await sensor.commandHistory()
        XCTAssertEqual(commands, [1, 2, 3, 9, 13, 14, 17, 8])
        let key = try identity.authenticationKey(for: result.preamble.phaseHandshake)
        await sensor.beginCached(key: key)
        let cached = try await Libre3PairingFlow(transport: sensor).runCachedReconnectHandshake(
            tail4: Data(repeating: 7, count: 4), phase5RawKey: key)
        XCTAssertEqual(cached.sessionMaterial.kEnc, result.sessionMaterial.kEnc)
        let reconnectCommands = await sensor.commandHistory()
        XCTAssertEqual(reconnectCommands, [17, 8])
    }

    func testInvalidSensorCertificateAndChallengeEchoAreRejected() async throws {
        let sensor = try SimulatedLibre3Sensor()
        let identity = try await sensor.appIdentity()
        let unrelated = P256.Signing.PrivateKey().publicKey.x963Representation
        do {
            _ = try await Libre3PairingFlow(
                transport: sensor, phoneCert: identity.certificate,
                sensorCertSigningKeys: [unrelated]
            ).runCommandGatedFirstPairPreamble()
            XCTFail("Untrusted sensor certificate must fail")
        } catch {
            guard case Libre3PairingFlowError.sensorCertificateVerificationFailed = error else {
                return XCTFail("Unexpected error type")
            }
        }
        let other = try SimulatedLibre3Sensor()
        let otherIdentity = try await other.appIdentity()
        let verifier = await other.verifier()
        await other.corruptEcho()
        do {
            _ = try await Libre3PairingFlow(
                transport: other, phoneCert: otherIdentity.certificate,
                sensorCertSigningKeys: [verifier]
            ).runCommandGatedFirstPairHandshake(
                blePIN: Data(repeating: 7, count: 4),
                phase5RawKeyProvider: { try otherIdentity.authenticationKey(for: $0.phaseHandshake) })
            XCTFail("Authenticated but incorrect challenge echo must fail")
        } catch {
            guard case Libre3PairingFlowError.phase6VerificationFailed = error else {
                return XCTFail("Unexpected error type")
            }
        }
    }
}

/// Entirely synthetic certificates and secrets, no sensor capture or vendor app identity.
private actor SimulatedLibre3Sensor: Libre3CommandPairingTransport {
    private let app = P256.KeyAgreement.PrivateKey()
    private let sensorStatic = P256.KeyAgreement.PrivateKey()
    private let sensorEphemeral = P256.KeyAgreement.PrivateKey()
    private let signing = P256.Signing.PrivateKey()
    private var commands: [UInt8] = []
    private var response = Data()
    private var phoneEphemeral: Data?
    private var phase5: Data?
    private var cachedKey: Data?
    private var badEcho = false
    private let r1 = Data(repeating: 6, count: 16)
    private let nonce = Data(repeating: 8, count: 7)

    init() throws {}
    func appIdentity() throws -> Libre3AppIdentity {
        try Libre3AppIdentity(
            label: "generated", privateKey: app.rawRepresentation,
            certificate: Data(count: 33) + app.publicKey.x963Representation + Data(count: 64))
    }
    func verifier() -> Data { signing.publicKey.x963Representation }
    func commandHistory() -> [UInt8] { commands }
    func corruptEcho() { badEcho = true }
    func beginCached(key: Data) {
        cachedKey = key
        commands = []
        phase5 = nil
    }

    func write(_ message: Data, to characteristic: Libre3BleCharRef) async throws {
        if characteristic == .certHandshake, message.count == 72 { phoneEphemeral = Data(message.prefix(65)) }
        if characteristic == .challenge { phase5 = message }
    }
    func writeCommand(_ command: UInt8) async throws {
        commands.append(command)
        switch command {
        case 3: response = Data([4])
        case 9: response = Data([10])
        case 14: response = Data([15])
        case 17, 8: response = Data([8])
        default: break
        }
    }
    func awaitCommandResponse(timeout: TimeInterval) async throws -> Data { response }
    func awaitNotify(on characteristic: Libre3BleCharRef, exactly n: Int) async throws -> Data {
        if characteristic == .certHandshake {
            if n == 140 {
                let payload = Data(count: 11) + sensorStatic.publicKey.x963Representation
                return payload + (try signing.signature(for: payload)).rawRepresentation
            }
            return sensorEphemeral.publicKey.x963Representation
        }
        if n == 23 { return r1 + nonce }
        let key: Data
        if let cachedKey {
            key = cachedKey
        } else {
            let phone = try P256.KeyAgreement.PublicKey(x963Representation: XCTUnwrap(phoneEphemeral))
            let ze = try sensorEphemeral.sharedSecretFromKeyAgreement(with: phone).withUnsafeBytes { Data($0) }
            let zs = try sensorStatic.sharedSecretFromKeyAgreement(with: app.publicKey).withUnsafeBytes { Data($0) }
            key = Data(SHA256.hash(data: Data([0, 0, 0, 1]) + ze + zs).prefix(16))
        }
        let challenge = try Libre3Phase5Challenge.decode(XCTUnwrap(phase5)).decrypt(sessionKey: key, nonce: nonce)
        guard challenge.prefix(16) == r1, challenge.suffix(4) == Data(repeating: 7, count: 4) else {
            throw Libre3ConnectionError.malformed
        }
        var r2 = challenge.subdata(in: 16..<32)
        if badEcho { r2[0] ^= 1 }
        let plaintext = r2 + r1 + Data(repeating: 9, count: 16) + Data(repeating: 10, count: 8)
        let (ciphertext, tag) = try Libre3AESCCM.encrypt(
            nonce: nonce, plaintext: plaintext, tagLength: 4,
            aes: Libre3AESCCM.commonCryptoBlockEncrypt(key: key))
        return ciphertext + tag + nonce
    }
}

extension Libre3Phase6ResponseTests {
    func testCredentialVersionSelectionIsOfflineAndImmutable() async throws {
        let service = "xdrip.libre3.version-tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: service))
        let storage = Libre3CredentialStore(service: service)
        defer {
            try? storage.removeAll()
            defaults.removePersistentDomain(forName: service)
        }
        let probe = SecItemAdd(
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service, kSecAttrAccount as String: "probe",
                kSecValueData as String: Data([1]),
            ] as CFDictionary, nil)
        if probe == errSecMissingEntitlement {
            throw XCTSkip("Unsigned simulator has no Keychain entitlement, requires signed-device validation.")
        }
        XCTAssertEqual(probe, errSecSuccess)
        let store = Libre3IdentityStore(service: service, defaults: defaults)
        func payload(label: String) throws -> (Data, Libre3IdentitySource) {
            let key = P256.KeyAgreement.PrivateKey()
            let certificate = Data(count: 33) + key.publicKey.x963Representation + Data(count: 64)
            let json = try JSONSerialization.data(withJSONObject: [
                "format": 1, "curve": "P-256",
                "identities": [
                    ["label": label, "privateKeyHex": key.rawRepresentation.hex, "certificateHex": certificate.hex]
                ],
            ])
            return (
                json,
                Libre3IdentitySource(
                    version: label, transaction: "synthetic",
                    digest: SHA256.hash(data: json).map { String(format: "%02x", $0) }.joined())
            )
        }
        let (first, source1) = try payload(label: "v1")
        let version1 = try await store.saveValidated(json: first, source: source1)
        let (second, source2) = try payload(label: "v2")
        _ = try await store.saveValidated(json: second, source: source2)
        let stillSelected = try await store.ensureAvailable()
        XCTAssertEqual(stillSelected, version1, "Downloading another version must not change the default")
        try await store.select("v2")
        let relaunched = Libre3IdentityStore(service: service, defaults: defaults)
        let selected = try await relaunched.ensureAvailable()
        XCTAssertEqual(selected.id, "v2", "Selected cached credentials must survive process restart offline")
        do {
            _ = try await store.saveValidated(
                json: second,
                source: Libre3IdentitySource(version: "v1", transaction: "synthetic", digest: source2.digest))
            XCTFail("A different payload must not overwrite a pinned version")
        } catch {}
        do {
            _ = try await store.saveValidated(json: first, source: source2)
            XCTFail("Bad digest must not alter published credentials")
        } catch {}
        let old = try await store.identities(version: "v1")
        XCTAssertEqual(old.first?.label, "v1")
        let all = try await store.versions()
        XCTAssertEqual(all.count, 2)
    }

    func testLegacySensorRecordsDecodeWithoutPretendingNewCryptoCompatibility() throws {
        let record = Libre3PairingRecord(
            serial: "synthetic", receiverID: 123,
            firmware: "1.0", generation: 1, wearMinutes: 21600, warmupMinutes: 60)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(Libre3PairingRecord.self, from: data)
        XCTAssertNil(decoded.cryptoVersion)
        XCTAssertNil(decoded.identityVersion)
        XCTAssertEqual(decoded.wearMinutes, 21600)
    }
}
