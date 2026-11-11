//
//  Libre3PairingFlow.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

// Adapted from RoundWhiteDiscKit.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/PairingFlow.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation
import CryptoKit
import Security

/// Command-gated certificate exchange and authenticated challenge response.
struct Libre3PairingHandshakeResult: Sendable {
    let phoneCert: Libre3PhoneCert
    let sensorCert: Libre3SensorCert
    let sensorCertSigningKeyIndex: Int?
    let phoneEph: Libre3EphemeralKeyPair
    let sensorEphPub: P256.KeyAgreement.PublicKey
    /// ECDH(phone_eph_priv, sensor_eph_pub).
    let sharedEphEph: Data
}

struct Libre3FirstPairPreambleResult: Sendable {
    let phaseHandshake: Libre3PairingHandshakeResult
    let sensorR1Wire: Data
    let sensorR1: Data
    let nonce7: Data
}

/// The command-gated authorization preamble is the same wire operation used by
/// first-pair and reconnect after a sensor is already known. The older
/// `Libre3FirstPairPreambleResult` name is kept for source compatibility.
typealias Libre3CommandGatedAuthorizationPreambleResult = Libre3FirstPairPreambleResult

/// Result of the command-gated fresh-pair handshake through Phase 6. The
/// Phase 5 raw key is supplied by the caller so the BLE state machine remains
/// decoupled from source-builder policy and entropy generation.
struct Libre3FirstPairHandshakeResult: Sendable {
    let preamble: Libre3FirstPairPreambleResult
    let phase5Sent: Libre3Phase5Challenge
    let phase6Raw: Data
    let phase6: Libre3Phase6Response
    let sessionMaterial: Libre3Phase6SessionMaterial
}

/// The Phase 5/6 command-gated authorization result. This is typealiased to the
/// historical first-pair result shape because the bytes and returned material
/// are identical once the caller supplies the accepted 4-byte Phase 5 tail.
typealias Libre3CommandGatedAuthorizationHandshakeResult = Libre3FirstPairHandshakeResult

/// Result of the pristine-style cached/direct reconnect preamble. This starts
/// at `StartAuthorization` and intentionally skips certificate and ephemeral
/// exchange.
struct Libre3CachedReconnectPreambleResult: Sendable {
    let sensorR1Wire: Data
    let sensorR1: Data
    let nonce7: Data
}

/// Result of the cached/direct reconnect handshake through Phase 6.
struct Libre3CachedReconnectHandshakeResult: Sendable {
    let preamble: Libre3CachedReconnectPreambleResult
    let phase5Sent: Libre3Phase5Challenge
    let phase6Raw: Data
    let phase6: Libre3Phase6Response
    let sessionMaterial: Libre3Phase6SessionMaterial
}

enum Libre3PairingFlowError: Error {
    case commandTransportRequired
    case phoneCertRequired
    case unexpectedCommandResponse(label: String, expectedPrefix: Data, actual: Data)
    case sensorR1WrongSize(Int)
    case blePINWrongSize(Int)
    case tail4WrongSize(Int)
    /// Credential-shaped: Phase 6 verification failed. Use a generous re-pair
    /// threshold before requiring an explicit NFC re-pair.
    case phase6VerificationFailed(String)
    case randomFailed(OSStatus)
    /// Transport: a GATT write timed out during the handshake. Retry , this is a
    /// link fault, NOT a credential failure, despite living in this enum.
    case writeTimeout(label: String, seconds: TimeInterval)
    /// Credential-shaped: the sensor certificate failed verification.
    case sensorCertificateVerificationFailed
}


func Libre3DefaultPhase5R2() throws -> Data {
    try Libre3SecureRandomData(count: 16)
}


func Libre3SecureRandomData(count: Int) throws -> Data {
    guard count >= 0 else {
        throw Libre3PairingFlowError.randomFailed(errSecParam)
    }
    var bytes = [UInt8](repeating: 0, count: count)
    let status = bytes.withUnsafeMutableBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else { return errSecParam }
        return SecRandomCopyBytes(kSecRandomDefault, rawBuffer.count, baseAddress)
    }
    guard status == errSecSuccess else {
        throw Libre3PairingFlowError.randomFailed(status)
    }
    return Data(bytes)
}

actor Libre3PairingFlow {
    let transport: Libre3PairingTransport
    let phoneCert: Libre3PhoneCert?
    let phoneEph: Libre3EphemeralKeyPair
    let sensorCertSigningKeys: [Data]
    private let eventLogger: (@Sendable (String) -> Void)?

    /// Create a flow for cached/direct reconnects that do not send a phone
    /// certificate or ephemeral key. Calling full cert/ephemeral
    /// authorization methods on this instance throws `phoneCertRequired`.
    init(
        transport: Libre3PairingTransport,
        sensorCertSigningKeys: [Data] = Libre3PatchSigningKey.known,
        eventLogger: (@Sendable (String) -> Void)? = nil
    ) {
        self.transport = transport
        self.phoneCert = nil
        self.phoneEph = Libre3EphemeralKeyPair()
        self.sensorCertSigningKeys = sensorCertSigningKeys
        self.eventLogger = eventLogger
    }

    init(
        transport: Libre3PairingTransport,
        phoneCert: Libre3PhoneCert,
        phoneEph: Libre3EphemeralKeyPair = Libre3EphemeralKeyPair(),
        sensorCertSigningKeys: [Data] = Libre3PatchSigningKey.known,
        eventLogger: (@Sendable (String) -> Void)? = nil
    ) {
        self.transport = transport
        self.phoneCert = phoneCert
        self.phoneEph = phoneEph
        self.sensorCertSigningKeys = sensorCertSigningKeys
        self.eventLogger = eventLogger
    }

    func runCommandGatedFirstPairPreamble(
        commandTimeout: TimeInterval = 2
    ) async throws -> Libre3FirstPairPreambleResult {
        guard let phoneCert else {
            throw Libre3PairingFlowError.phoneCertRequired
        }
        guard let commandTransport = transport as? Libre3CommandPairingTransport else {
            throw Libre3PairingFlowError.commandTransportRequired
        }

        func waitFor(_ expectedPrefix: Data, label: String) async throws {
            let actual = try await commandTransport.awaitCommandResponse(timeout: commandTimeout)
            guard actual.starts(with: expectedPrefix) else {
                throw Libre3PairingFlowError.unexpectedCommandResponse(
                    label: label,
                    expectedPrefix: expectedPrefix,
                    actual: actual
                )
            }
        }

        let writeTimeout: TimeInterval = 2

        log("preamble start")
        log("send StartAuthentication 0x01")
        try await withWriteTimeout(writeTimeout, label: "StartAuthentication") {
            try await commandTransport.writeCommand(0x01)
        }
        log("send LoadCertificate 0x02")
        try await withWriteTimeout(writeTimeout, label: "LoadCertificate") {
            try await commandTransport.writeCommand(0x02)
        }

        log("send phone cert len=\(phoneCert.raw.count)")
        try await withWriteTimeout(writeTimeout, label: "phoneCertWrite") {
            try await self.transport.write(phoneCert.raw, to: .certHandshake)
        }

        log("send SendCertificateLoadDone 0x03")
        try await withWriteTimeout(writeTimeout, label: "SendCertificateLoadDone") {
            try await commandTransport.writeCommand(0x03)
        }
        try await waitFor(Data([0x04]), label: "CertificateAccepted")

        log("send GetCertificate 0x09")
        try await withWriteTimeout(writeTimeout, label: "GetCertificate") {
            try await commandTransport.writeCommand(0x09)
        }
        try await waitFor(Data([0x0a]), label: "CertificateReady")

        log("await sensor cert")
        let sensorCertRaw = try await transport.awaitNotify(on: .certHandshake, exactly: Libre3SensorCert.totalSize)
        let sensorCert = try Libre3SensorCert(raw: sensorCertRaw)
        let sensorCertSigningKeyIndex = try verifySensorCertificate(sensorCert)
        log("parsed sensor cert len=\(sensorCertRaw.count)")

        log("send ValidateCertificate 0x0d")
        try await withWriteTimeout(writeTimeout, label: "ValidateCertificate") {
            try await commandTransport.writeCommand(0x0d)
        }

        let phase3Wire = padTo(phoneEph.publicKey65, length: 72)
        log("send phone ephemeral len=\(phase3Wire.count)")
        try await withWriteTimeout(writeTimeout, label: "phoneEphemeralWrite") {
            try await self.transport.write(phase3Wire, to: .certHandshake)
        }

        log("send SendEphemeralDone 0x0e")
        try await withWriteTimeout(writeTimeout, label: "SendEphemeralDone") {
            try await commandTransport.writeCommand(0x0e)
        }
        try await waitFor(Data([0x0f]), label: "EphemeralReady")

        log("await sensor ephemeral")
        let sensorEphRaw = try await transport.awaitNotify(on: .certHandshake, exactly: 65)
        let sensorEphPub = try Libre3EphemeralExchange.parsePeerPubkey(sensorEphRaw)
        let sharedEphEph = try Libre3EphemeralExchange.sharedSecret(
            privateKey: phoneEph.privateKey,
            peer: sensorEphPub
        )
        let p4 = Libre3PairingHandshakeResult(
            phoneCert: phoneCert,
            sensorCert: sensorCert,
            sensorCertSigningKeyIndex: sensorCertSigningKeyIndex,
            phoneEph: phoneEph,
            sensorEphPub: sensorEphPub,
            sharedEphEph: sharedEphEph
        )
        log("ephemeral key agreement complete")

        log("send StartAuthorization 0x11")
        try await withWriteTimeout(writeTimeout, label: "StartAuthorization") {
            try await commandTransport.writeCommand(0x11)
        }
        try await waitFor(Data([0x08]), label: "ChallengeLoadDone")

        log("await R1 challenge")
        let r1Wire = try await transport.awaitNotify(on: .challenge, exactly: 23)
        guard r1Wire.count == 23 else {
            throw Libre3PairingFlowError.sensorR1WrongSize(r1Wire.count)
        }
        let sensorR1 = r1Wire.subdata(in: 0..<16)
        let nonce7 = r1Wire.subdata(in: 16..<23)
        return Libre3FirstPairPreambleResult(
            phaseHandshake: p4,
            sensorR1Wire: r1Wire,
            sensorR1: sensorR1,
            nonce7: nonce7
        )
    }

    /// Semantic alias for the command-gated cert/ephemeral/challenge preamble
    /// used by both first-pair candidates and saved-state reconnect/recovery.
    func runCommandGatedAuthorizationPreamble(
        commandTimeout: TimeInterval = 2
    ) async throws -> Libre3CommandGatedAuthorizationPreambleResult {
        try await runCommandGatedFirstPairPreamble(commandTimeout: commandTimeout)
    }

    /// Run the cached/direct reconnect preamble observed in pristine
    /// post-pairing reconnects.
    ///
    /// Wire shape:
    ///   `0x11 StartAuthorization`
    ///   → command notify prefix `0x08`
    ///   → challenge notify `R1_16 || nonce7`.
    ///
    /// This path skips `StartAuthentication`, phone certificate, sensor
    /// certificate, phone ephemeral, and sensor ephemeral. It only succeeds
    /// when the caller already has cached Phase 5 material accepted by the
    /// sensor for the saved receiver/session state.
    func runCachedReconnectPreamble(
        commandTimeout: TimeInterval = 2
    ) async throws -> Libre3CachedReconnectPreambleResult {
        guard let commandTransport = transport as? Libre3CommandPairingTransport else {
            throw Libre3PairingFlowError.commandTransportRequired
        }

        func waitFor(_ expectedPrefix: Data, label: String) async throws {
            let actual = try await commandTransport.awaitCommandResponse(timeout: commandTimeout)
            guard actual.starts(with: expectedPrefix) else {
                throw Libre3PairingFlowError.unexpectedCommandResponse(
                    label: label,
                    expectedPrefix: expectedPrefix,
                    actual: actual
                )
            }
        }

        log("cached reconnect preamble start")
        log("send StartAuthorization 0x11")
        try await withWriteTimeout(2, label: "StartAuthorization") {
            try await commandTransport.writeCommand(0x11)
        }
        try await waitFor(Data([0x08]), label: "ChallengeLoadDone")

        log("await cached reconnect R1 challenge")
        let r1Wire = try await transport.awaitNotify(on: .challenge, exactly: 23)
        guard r1Wire.count == 23 else {
            throw Libre3PairingFlowError.sensorR1WrongSize(r1Wire.count)
        }
        let sensorR1 = r1Wire.subdata(in: 0..<16)
        let nonce7 = r1Wire.subdata(in: 16..<23)
        return Libre3CachedReconnectPreambleResult(
            sensorR1Wire: r1Wire,
            sensorR1: sensorR1,
            nonce7: nonce7
        )
    }

    /// Run pristine-style cached/direct reconnect through Phase 6.
    ///
    /// This is the shortest observed successful post-pairing reconnect path:
    /// it starts at `StartAuthorization`, sends a Phase 5 response derived from
    /// cached/saved state, then verifies the Phase 6 session material. If the
    /// sensor rejects this path, integrations should fall back to the full
    /// command-gated authorization path.
    func runCachedReconnectHandshake(
        tail4: Data,
        phase5RawKeyProvider: (Libre3CachedReconnectPreambleResult) throws -> Data,
        r2Provider: () throws -> Data = Libre3DefaultPhase5R2,
        commandTimeout: TimeInterval = 2
    ) async throws -> Libre3CachedReconnectHandshakeResult {
        guard tail4.count == 4 else {
            throw Libre3PairingFlowError.tail4WrongSize(tail4.count)
        }

        let preamble = try await runCachedReconnectPreamble(commandTimeout: commandTimeout)
        let phase5R2 = try r2Provider()
        guard phase5R2.count == 16 else {
            throw Libre3ChallengeError.wrongPlaintextSize(preamble.sensorR1.count + phase5R2.count + tail4.count)
        }

        let phase5RawKey = try phase5RawKeyProvider(preamble)
        guard phase5RawKey.count == 16 else {
            throw Libre3ChallengeError.wrongKeySize(phase5RawKey.count)
        }
        let phase5Block = Libre3AESCCM.commonCryptoBlockEncrypt(key: phase5RawKey)
        let phase5Plaintext = preamble.sensorR1 + phase5R2 + tail4
        let phase5 = try Libre3Phase5Challenge.encrypt(
            plaintext: phase5Plaintext,
            aes: phase5Block,
            nonce: preamble.nonce7
        )
        try await withWriteTimeout(2, label: "cachedReconnectPhase5Write") {
            try await self.transport.write(phase5.wireBytes, to: .challenge)
        }
        try await sendChallengeLoadDoneIfAvailable(commandTimeout: commandTimeout)

        log("await cached reconnect Phase 6")
        let phase6Raw = try await transport.awaitNotify(on: .challenge, exactly: Libre3Phase6Response.wireSize)
        let phase6 = try Libre3Phase6Response.decode(phase6Raw)
        let sessionMaterial = try phase6.decrypt(aes: phase5Block)
        guard sessionMaterial.phoneR2 == phase5R2 else {
            throw Libre3PairingFlowError.phase6VerificationFailed("Phase 6 R2 echo mismatch")
        }
        guard sessionMaterial.sensorR1 == preamble.sensorR1 else {
            throw Libre3PairingFlowError.phase6VerificationFailed("Phase 6 R1 echo mismatch")
        }

        return Libre3CachedReconnectHandshakeResult(
            preamble: preamble,
            phase5Sent: phase5,
            phase6Raw: phase6Raw,
            phase6: phase6,
            sessionMaterial: sessionMaterial
        )
    }

    /// Reconnect using the sensor-scoped authentication key saved at pairing.
    func runCachedReconnectHandshake(
        tail4: Data,
        phase5RawKey: Data,
        r2Provider: () throws -> Data = Libre3DefaultPhase5R2,
        commandTimeout: TimeInterval = 2
    ) async throws -> Libre3CachedReconnectHandshakeResult {
        try await runCachedReconnectHandshake(
            tail4: tail4,
            phase5RawKeyProvider: { _ in phase5RawKey },
            r2Provider: r2Provider,
            commandTimeout: commandTimeout
        )
    }

    /// Run the command-gated authorization handshake through Phase 6 using an
    /// injected Phase 5 raw key.
    ///
    /// This is the reusable full authorization wire driver for initial pairing
    /// candidates and saved-state reconnect/recovery fallback. For the shorter
    /// pristine-style saved-state reconnect attempt, use
    /// `runCachedReconnectHandshake(...)`.
    ///
    /// The key provider is called after the cert/ephemeral preamble and the
    /// sensor's `R1 || nonce7` notify, so source derivation can use the sensor
    /// cert, both ECDH secrets, R1, nonce, and the accepted 4-byte Phase 5 tail
    /// without changing this wire driver.
    func runCommandGatedAuthorizationHandshake(
        tail4: Data,
        phase5RawKeyProvider: (Libre3CommandGatedAuthorizationPreambleResult) throws -> Data,
        r2Provider: () throws -> Data = Libre3DefaultPhase5R2,
        commandTimeout: TimeInterval = 2
    ) async throws -> Libre3CommandGatedAuthorizationHandshakeResult {
        guard tail4.count == 4 else {
            throw Libre3PairingFlowError.tail4WrongSize(tail4.count)
        }

        let preamble = try await runCommandGatedFirstPairPreamble(commandTimeout: commandTimeout)
        let phase5R2 = try r2Provider()
        guard phase5R2.count == 16 else {
            throw Libre3ChallengeError.wrongPlaintextSize(preamble.sensorR1.count + phase5R2.count + tail4.count)
        }

        let phase5RawKey = try phase5RawKeyProvider(preamble)
        guard phase5RawKey.count == 16 else {
            throw Libre3ChallengeError.wrongKeySize(phase5RawKey.count)
        }
        let phase5Block = Libre3AESCCM.commonCryptoBlockEncrypt(key: phase5RawKey)
        let phase5Plaintext = preamble.sensorR1 + phase5R2 + tail4
        let phase5 = try Libre3Phase5Challenge.encrypt(
            plaintext: phase5Plaintext,
            aes: phase5Block,
            nonce: preamble.nonce7
        )
        try await withWriteTimeout(2, label: "authorizationPhase5Write") {
            try await self.transport.write(phase5.wireBytes, to: .challenge)
        }
        try await sendChallengeLoadDoneIfAvailable(commandTimeout: commandTimeout)

        log("await Phase 6")
        let phase6Raw = try await transport.awaitNotify(on: .challenge, exactly: Libre3Phase6Response.wireSize)
        let phase6 = try Libre3Phase6Response.decode(phase6Raw)
        let sessionMaterial = try phase6.decrypt(aes: phase5Block)
        guard sessionMaterial.phoneR2 == phase5R2 else {
            throw Libre3PairingFlowError.phase6VerificationFailed("Phase 6 R2 echo mismatch")
        }
        guard sessionMaterial.sensorR1 == preamble.sensorR1 else {
            throw Libre3PairingFlowError.phase6VerificationFailed("Phase 6 R1 echo mismatch")
        }

        return Libre3FirstPairHandshakeResult(
            preamble: preamble,
            phase5Sent: phase5,
            phase6Raw: phase6Raw,
            phase6: phase6,
            sessionMaterial: sessionMaterial
        )
    }

    /// Backward-compatible first-pair spelling for callers that supply the NFC
    /// BLE PIN as the 4-byte Phase 5 tail.
    func runCommandGatedFirstPairHandshake(
        blePIN: Data,
        phase5RawKeyProvider: (Libre3FirstPairPreambleResult) throws -> Data,
        r2Provider: () throws -> Data = Libre3DefaultPhase5R2,
        commandTimeout: TimeInterval = 2
    ) async throws -> Libre3FirstPairHandshakeResult {
        guard blePIN.count == 4 else {
            throw Libre3PairingFlowError.blePINWrongSize(blePIN.count)
        }
        return try await runCommandGatedAuthorizationHandshake(
            tail4: blePIN,
            phase5RawKeyProvider: phase5RawKeyProvider,
            r2Provider: r2Provider,
            commandTimeout: commandTimeout
        )
    }

    private func log(_ message: @autoclosure () -> String) { eventLogger?(message()) }

    /// Races `work` against a wall-clock timeout. Used to bound BLE
    /// `writeCommand` / `write` calls , those await CoreBluetooth's
    /// didWriteValueFor callback, which never fires on a half-dead link.
    /// Libre3Field log captured 10 minutes of foreground silence after
    /// `send StartAuthentication 0x01` was written but the sensor never
    /// acknowledged, without this the awaits park indefinitely.
    private func withWriteTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        label: String,
        _ work: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        let box = WriteTimeoutBox<T>()
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<T, Error>) in
            let workTask = Task.detached {
                do {
                    let value = try await work()
                    box.resume(.success(value), with: cont)
                } catch {
                    box.resume(.failure(error), with: cont)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                if box.timeout(with: cont, label: label, seconds: seconds) {
                    workTask.cancel()
                }
            }
        }
    }

    private func verifySensorCertificate(_ sensorCert: Libre3SensorCert) throws -> Int? {
        guard !sensorCertSigningKeys.isEmpty else {
            throw Libre3PairingFlowError.sensorCertificateVerificationFailed
        }
        guard let index = try sensorCert.verifiedSigningKeyIndex(in: sensorCertSigningKeys) else {
            throw Libre3PairingFlowError.sensorCertificateVerificationFailed
        }
        log("sensor cert verified signingKeyIndex=\(index)")
        return index
    }

    /// Atomic single-resume guard for `withWriteTimeout`. Earlier
    /// `withThrowingTaskGroup` + `Task.sleep` implementation didn't fire
    /// reliably in production logs , possibly an actor-isolation
    /// interaction when called from this actor. This version uses
    /// `Task.detached` + `DispatchQueue.asyncAfter`, both well-tested
    /// primitives that race independently of the cooperative scheduler.
    private final class WriteTimeoutBox<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var resumed = false

        func resume(_ result: Result<T, Error>, with cont: CheckedContinuation<T, Error>) {
            lock.lock()
            let already = resumed
            resumed = true
            lock.unlock()
            guard !already else { return }
            switch result {
            case .success(let v): cont.resume(returning: v)
            case .failure(let e): cont.resume(throwing: e)
            }
        }

        /// Returns true if this is the side that actually resumed (caller
        /// cancels the still-running work task in that case).
        func timeout(
            with cont: CheckedContinuation<T, Error>,
            label: String,
            seconds: TimeInterval
        ) -> Bool {
            lock.lock()
            let already = resumed
            resumed = true
            lock.unlock()
            guard !already else { return false }
            cont.resume(throwing: Libre3PairingFlowError.writeTimeout(label: label, seconds: seconds))
            return true
        }
    }

    private func sendChallengeLoadDoneIfAvailable(commandTimeout: TimeInterval = 2) async throws {
        guard let commandTransport = transport as? Libre3CommandPairingTransport else {
            return
        }
        log("send SendChallengeLoadDone 0x08")
        try await withWriteTimeout(commandTimeout, label: "SendChallengeLoadDone") {
            try await commandTransport.writeCommand(0x08)
        }
        let actual = try await commandTransport.awaitCommandResponse(timeout: commandTimeout)
        guard actual.starts(with: Data([0x08])) else {
            throw Libre3PairingFlowError.unexpectedCommandResponse(
                label: "PatchChallengeLoadDone",
                expectedPrefix: Data([0x08]),
                actual: actual
            )
        }
    }

}

@inline(__always) func padTo(_ data: Data, length: Int) -> Data {
    if data.count >= length { return data }
    var out = Data(capacity: length)
    out.append(data)
    out.append(Data(count: length - data.count))
    return out
}
