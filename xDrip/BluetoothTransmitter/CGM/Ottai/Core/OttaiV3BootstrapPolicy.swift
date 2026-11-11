//
//  OttaiV3BootstrapPolicy.swift
//  xdrip
//
//  Ottai / Syai CGM driver — how a connection starts when the sensor has no keyA yet.
//

import Foundation

enum OttaiAuthEntryMode {
    case storedMaterialAuth
    /// Activated through the server; only the bind (which gives keyA) is missing.
    case awaitingBind
    /// New sensor, the user asked to activate it: the server answers the login.
    case serverAssistedActivation
    case blocked
}

/// A sensor without keyA is only touched when the user asked for activation, the V3
/// check marked it (`bootstrapPending`) and the login is still there.
func ottaiAuthEntryMode(
    hasAuthKeys: Bool,
    pendingBind: Bool,
    bootstrapPending: Bool,
    sessionAvailable: Bool,
    activationRequested: Bool
) -> OttaiAuthEntryMode {
    if hasAuthKeys { return .storedMaterialAuth }
    if pendingBind { return .awaitingBind }
    if bootstrapPending, sessionAvailable, activationRequested { return .serverAssistedActivation }
    return .blocked
}

enum OttaiServerAuthRecovery: Equatable {
    case stop
    case retryConnection
    case scanNextSensor
}

/// An old sensor can advertise the same name as the replacement. Its challenge
/// cannot be verified against the replacement's Cloud ID. Retry with a fresh
/// challenge once before excluding that Bluetooth device for this transmitter.
func ottaiServerAuthRecovery(code: String, signatureFailures: Int, activateSent: Bool) -> OttaiServerAuthRecovery {
    guard !activateSent, code == "DEVICE_AUTH_SIGN_ERROR" else { return .stop }
    return signatureFailures >= 2 ? .scanNextSensor : .retryConnection
}

/// A server session can only override duration if `kb` actually reproduces the
/// server's encrypted activate command and decrypts its duration with zero padding.
/// SyaiKit documents these as AES-128 ECB frames; it does not define `kb` as a key.
/// Never assume that meaning without checking both frames for this connection.
struct OttaiServerDurationPlan {
    let keyHex: String
    let serverSeconds: Int64
    let candidates: [Int64]

    /// Stable diagnostic codes only: never include keys, ciphertext or decrypted bytes.
    enum VerificationFailure: String, Error {
        case missingKey = "kb-missing"
        case invalidKeyHex = "kb-invalid-hex"
        case invalidKeyLength = "kb-not-16-bytes"
        case invalidDurationLength = "duration-not-16-bytes"
        case invalidActivateLength = "activate-not-16-bytes"
        case activateEncryptionFailed = "activate-encryption-failed"
        case activateMismatch = "activate-frame-mismatch"
        case durationDecryptionFailed = "duration-decryption-failed"
        case invalidDurationPadding = "duration-padding-mismatch"
        case invalidDurationRange = "duration-outside-10-to-45-days"
    }

    static func verified(keyHex: String, duration: [UInt8], activate: [UInt8]) -> Self? {
        try? verification(keyHex: keyHex, duration: duration, activate: activate).get()
    }

    static func verification(keyHex: String, duration: [UInt8], activate: [UInt8]) -> Result<Self, VerificationFailure> {
        guard !keyHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failure(.missingKey) }
        guard let key = try? OttaiCrypto.hexToBytesStrict(keyHex) else { return .failure(.invalidKeyHex) }
        guard key.count == 16 else { return .failure(.invalidKeyLength) }
        guard duration.count == 16 else { return .failure(.invalidDurationLength) }
        guard activate.count == 16 else { return .failure(.invalidActivateLength) }
        guard let encryptedActivate = OttaiCrypto.encryptActivateCmd([3], sessionKeyHex: keyHex) else {
            return .failure(.activateEncryptionFailed)
        }
        guard encryptedActivate == activate else { return .failure(.activateMismatch) }
        guard let plain = OttaiCrypto.aesECB(.decrypt, key: key, data: duration, pkcs7Padded: false), plain.count == 16 else {
            return .failure(.durationDecryptionFailed)
        }
        guard plain.dropFirst(4).allSatisfy({ $0 == 0 }) else { return .failure(.invalidDurationPadding) }
        let seconds = (0..<4).reduce(Int64(0)) { $0 | (Int64(plain[$1]) << ($1 * 8)) }
        guard OttaiConstants.sanitizeActiveExpireMs(seconds * 1000) > 0 else { return .failure(.invalidDurationRange) }
        let candidates = OttaiConstants.activationMaxActiveCandidatesMs(cloudActiveExpireMs: seconds * 1000)
            .map { $0 / 1000 }.filter { $0 > seconds && $0 <= 30 * 86_400 }
        return .success(Self(keyHex: keyHex, serverSeconds: seconds, candidates: candidates + [seconds]))
    }

    func frame(at index: Int, original: [UInt8]) -> [UInt8]? {
        guard candidates.indices.contains(index) else { return nil }
        let seconds = candidates[index]
        if seconds == serverSeconds { return original }
        let payload = (0..<4).map { UInt8(truncatingIfNeeded: seconds >> ($0 * 8)) }
        return OttaiCrypto.encryptPayload(payload, sessionKeyHex: keyHex)
    }

    /// Only duration rejection (including a drop before the RTC acknowledgement)
    /// steps down. Never retry activation after the activate command was sent.
    func nextIndex(after index: Int, durationOrRTCFailed: Bool, activateSent: Bool) -> Int? {
        guard durationOrRTCFailed, !activateSent, candidates.indices.contains(index),
              candidates[index] > serverSeconds, candidates.indices.contains(index + 1) else { return nil }
        return index + 1
    }
}

/// Move the live start time back only when two accepted readings agree.
struct OttaiArrivalStartCorrection {
    private var lowest: Int64 = 0
    private var latestArrival: Int64 = 0
    private var pending: (start: Int64, counter: Int, received: Int64)?

    mutating func seed(start: Int64, arrivalStart: Int64) {
        lowest = start - 60_000
        latestArrival = max(0, arrivalStart)
        pending = nil
    }

    mutating func accept(anchor: Int64, counter: Int, received: Int64) -> Int64? {
        guard anchor > 0, counter >= 0, received > 0 else {
            pending = nil
            return nil
        }
        let implied = received - Int64(counter) * 60_000
        if latestArrival > 0 { latestArrival = max(latestArrival, implied) }
        guard implied < anchor else {
            pending = nil
            return nil
        }
        guard let previous = pending, counter > previous.counter,
              received > previous.received, received - previous.received <= 180_000,
              abs(previous.start - implied) <= 60_000 else {
            pending = (implied, counter, received)
            return nil
        }
        pending = nil
        let agreed = max(previous.start, implied)
        guard lowest > 0, latestArrival > 0, agreed >= max(lowest, latestArrival - 120_000) else { return nil }
        return agreed
    }
}
