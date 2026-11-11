//
//  OttaiV3BootstrapPolicy.swift
//  xdrip
//
//  Ottai / Syai CGM driver — how a connection starts when the sensor has no keyA yet.
//

import Foundation

/// Use the same next step in the setup screen and its button handlers.
enum OttaiSetupStep: Equatable {
    case enterID, signIn, fetch, connect, activate, starting, finishingSetup, active, ended
    case warmup(minutes: Int)

    static func resolve(sensorID: String, signedIn: Bool, hasKeys: Bool, bootstrapPending: Bool,
                        pendingBind: Bool, activationRequested: Bool, activationStarted: Bool,
                        commandStatus: Int, savedCommandStatus: Int, startMs: Int64, nowMs: Int64) -> Self {
        guard OttaiConstants.looksLikeMac(sensorID) else { return .enterID }
        if commandStatus >= 4 || savedCommandStatus >= 4 { return .ended }
        if pendingBind { return signedIn ? .finishingSetup : .signIn }
        if activationStarted || commandStatus == 3 || savedCommandStatus == 3 {
            let warmupMs = Int64(ConstantsMaster.minimumSensorWarmUpRequiredInMinutesOttai * 60_000)
            if startMs > 0, nowMs < startMs + warmupMs {
                let remaining = min(warmupMs, startMs + warmupMs - nowMs)
                return .warmup(minutes: Int((remaining + 59_999) / 60_000))
            }
            return .active
        }
        if !hasKeys && !signedIn { return .signIn }
        if !hasKeys && !bootstrapPending { return .fetch }
        if activationRequested { return .starting }
        if hasKeys && commandStatus < 0 { return .connect }
        return .activate
    }

    var title: String {
        switch self {
        case .enterID: return "Add sensor"
        case .signIn: return "Sign in"
        case .fetch: return "Set up sensor"
        case .connect: return "Connect to sensor"
        case .activate: return "Start sensor"
        case .starting: return "Starting sensor…"
        case .finishingSetup: return "Finish sensor setup"
        case .warmup: return "Sensor warming up"
        case .active: return "Sensor active"
        case .ended: return "Sensor ended"
        }
    }

    var detail: String {
        switch self {
        case .enterID: return "Enter the ID from the sensor box."
        case .signIn: return "Use the account for your sensor region."
        case .fetch: return "Get the settings for this sensor."
        case .connect: return "Check the sensor before starting it."
        case .activate: return "Put the sensor on before starting."
        case .starting: return "Keep the phone nearby. Do not start again."
        case .finishingSetup: return "The sensor has started. Tap to retry setup."
        case .warmup(let minutes): return "About \(minutes) min left. No action needed."
        case .active: return "No action needed."
        case .ended: return "Replace the sensor to continue."
        }
    }

    var hasAction: Bool {
        switch self {
        case .starting, .warmup, .active, .ended: return false
        default: return true
        }
    }
}

/// A running sensor must never receive another activation sequence.
func ottaiCanWriteActivation(commandStatus: Int, activationStarted: Bool) -> Bool {
    (0...2).contains(commandStatus) && !activationStarted
}

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

/// Build factory settings before sending any activation commands.
enum OttaiPreparation {
    enum Failure: Error { case firmware, coefficients, calibration }

    static func minor(_ version: String) -> Int? {
        guard let range = version.range(of: "V1.", options: .caseInsensitive) else { return nil }
        return Int(version[range.upperBound...].prefix { $0.isNumber })
    }
    static func versionMatches(_ sensor: String, _ cloud: String) -> Bool {
        let a = sensor.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = cloud.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        if a.contains("("), b.contains("(") {
            return (!a.contains(",") || !b.contains(",")) && a.split(separator: ",").first == b.split(separator: ",").first
        }
        return OttaiCloudClient.deviceVersion(fromFirmware: a) == b || OttaiCloudClient.deviceVersion(fromFirmware: b) == a
    }
    static func packets(version: String, coefficients: String, k: Double?, b: Double?, session: String) throws -> [[UInt8]] {
        guard let minor = minor(version) else { throw Failure.firmware }
        var packets: [[UInt8]] = []
        if minor >= 6 {
            let fields = coefficients.split(separator: ",", omittingEmptySubsequences: false)
            let values = fields.compactMap { Float($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            guard values.count == fields.count, (1...255).contains(values.count),
                  values.allSatisfy({ $0.isFinite }) else { throw Failure.coefficients }
            var packet: [UInt8] = [0x09, UInt8(values.count)]
            for value in values {
                packet += (0..<4).map { UInt8(truncatingIfNeeded: value.bitPattern >> ($0 * 8)) }
            }
            let crc = coefficientCRC(packet)
            packet += [UInt8(truncatingIfNeeded: crc), UInt8(truncatingIfNeeded: crc >> 8)]
            packets.append(packet)
        }
        if minor >= 8 {
            guard let k = k, let b = b, k.isFinite, b.isFinite else { throw Failure.calibration }
            let plain = [k, b].flatMap { value in
                (0..<8).map { UInt8(truncatingIfNeeded: value.bitPattern >> ($0 * 8)) }
            }
            guard let encrypted = OttaiCrypto.encryptPayload(plain, sessionKeyHex: session), encrypted.count == 16 else {
                throw Failure.calibration
            }
            packets.append([0x0b] + encrypted)
        }
        return packets
    }

    private static func coefficientCRC(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xffff
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = crc & 1 != 0 ? (crc >> 1) ^ 0xa001 : crc >> 1
            }
        }
        return crc
    }
}
