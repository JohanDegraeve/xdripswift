//
//  Libre3PatchStatus.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/DataPlane/PatchStatus.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

struct Libre3PatchStatus: Equatable, Sendable {
    static let plaintextSize = 12

    let lifeCount: Int16
    let errorData: Int16
    let eventDataRaw: Int16
    let eventData: Int
    let index: Int8
    let totalEvents: Int
    let patchState: Int8
    let currentLifeCount: Int16
    let stackDisconnectReason: Int8
    let appDisconnectReason: Int8

    var patchStateKind: Libre3PatchState {
        Libre3PatchState(rawValue: patchState)
    }

    var isPatchStateActive: Bool {
        patchStateKind.isActive
    }

    var isPatchStateExpiredOrError: Bool {
        patchStateKind.isExpiredOrError
    }

    var isPatchStateTerminated: Bool {
        patchStateKind.isTerminated
    }

    var hasErrorData: Bool {
        errorData != 0
    }

    /// Sensor error/condition decoded from `errorData`.
    ///
    /// Distinguishes normal end-of-wear `.expired` from post-shutdown
    /// `.terminated` and from per-reading data-quality flags. See
    /// `Libre3SensorError` for the inference caveat on the mapping.
    var sensorError: Libre3SensorError {
        Libre3SensorError(code: errorData)
    }

    /// User-facing attention/action inferred from `errorData`, with
    /// patch-state fallback when no error code is present.
    ///
    /// This is intended for app notification routing. The raw fields remain
    /// authoritative for logging and for future compatibility: Abbott's
    /// Android app has overlapping "sensor ended", "replace sensor", and
    /// "check sensor" response layers, and the exact native alarm-engine
    /// `replaceSensorError` producer is not public. Current compatibility
    /// evidence maps error code 7 to the replace-sensor alarm flag and code 8
    /// to immediate replacement/termination.
    var sensorAttention: Libre3SensorAttention {
        Libre3SensorAttention(errorData: errorData, patchState: patchState)
    }

    /// `true` when clients should show a prompt/notification about this
    /// sensor condition as soon as practical.
    var shouldNotifyUser: Bool {
        sensorAttention.shouldNotifyUser
    }

    /// `true` for conditions that match Abbott's replace-sensor handling.
    var shouldNotifyReplaceSensor: Bool {
        sensorAttention.isReplaceSensor
    }

    /// `true` when `errorData` reports Abbott's `SENSOR_TERMINATED`
    /// condition. This is the post-shutdown/end-session state, the matching
    /// patch-control shutdown command is `05 00 00 00 00 00 00`.
    ///
    /// Deliberately `false` for `.expired`: end-of-wear state `5` can
    /// still advertise over BLE until a later shutdown/end-session transition.
    var isShutdownTerminated: Bool {
        sensorError.isShutdownTerminated
    }

    /// `true` when the sensor reports a start/insertion failure.
    var isInsertionFailure: Bool {
        sensorError.isInsertionFailure
    }

    /// Original combined "terminal" check. Stays `true` for both a
    /// start/insertion failure and a post-shutdown termination, preserving
    /// its prior union semantics so existing callers do not silently lose the
    /// terminated signal. Migrate to the split `isInsertionFailure` /
    /// `isShutdownTerminated` flags, which separate a start failure from a
    /// normal shutdown.
    @available(
        *,
        deprecated,
        message: "Split into `isInsertionFailure` and `isShutdownTerminated`: `terminated` is a shutdown state, not a start failure. This property stays true for both to preserve prior behavior."
    )
    var isTerminalFailure: Bool {
        isInsertionFailure || isShutdownTerminated
    }

    /// Diagnostic disconnect evidence from the patch-status record.
    ///
    /// These bytes are kept separate from patch-state and sensor-error terminal
    /// decoding, non-zero values do not by themselves indicate shutdown.
    var hasDisconnectReason: Bool {
        stackDisconnectReason != 0 || appDisconnectReason != 0
    }

    var defaultLifecycle: Libre3SensorLifecycle {
        lifecycle()
    }

    var defaultLifecyclePhase: Libre3SensorLifecyclePhase {
        defaultLifecycle.phase
    }

    var isInDefaultWarmup: Bool {
        defaultLifecycle.isWarmingUp
    }

    func lifecycle(
        warmupDurationMinutes: Int = Libre3SensorLifecycle.defaultWarmupDurationMinutes,
        wearDurationMinutes: Int? = nil
    ) -> Libre3SensorLifecycle {
        Libre3SensorLifecycle(
            currentLifeCountMinutes: Int(currentLifeCount),
            warmupDurationMinutes: warmupDurationMinutes,
            wearDurationMinutes: wearDurationMinutes
        )
    }

    /// Lifecycle whose warmup and wear durations are taken from the NFC
    /// patch info rather than the assumed defaults.
    func lifecycle(patchInfo: Libre3NFCPatchInfo) -> Libre3SensorLifecycle {
        lifecycle(
            warmupDurationMinutes: Int(patchInfo.warmupMinutes),
            wearDurationMinutes: Int(patchInfo.wearDurationMinutes)
        )
    }

    init(plaintext: Data) throws {
        guard plaintext.count == Self.plaintextSize else {
            throw Libre3PatchStatusError.wrongPlaintextSize(plaintext.count)
        }
        self.lifeCount = Self.s16(plaintext, 0)
        self.errorData = Self.s16(plaintext, 2)
        self.eventDataRaw = Self.s16(plaintext, 4)
        self.eventData = 4000 + Int(self.eventDataRaw)
        self.index = Int8(bitPattern: plaintext[plaintext.startIndex + 6])
        self.totalEvents = Int(self.index) + 1
        self.patchState = Int8(bitPattern: plaintext[plaintext.startIndex + 7])
        self.currentLifeCount = Self.s16(plaintext, 8)
        self.stackDisconnectReason = Int8(bitPattern: plaintext[plaintext.startIndex + 10])
        self.appDisconnectReason = Int8(bitPattern: plaintext[plaintext.startIndex + 11])
    }

    private static func s16(_ data: Data, _ offset: Int) -> Int16 {
        Int16(bitPattern: u16(data, offset))
    }

    private static func u16(_ data: Data, _ offset: Int) -> UInt16 {
        let i = data.startIndex + offset
        return UInt16(data[i]) | (UInt16(data[i + 1]) << 8)
    }
}

enum Libre3PatchStatusError: Error, Equatable {
    case wrongPlaintextSize(Int)
}

/// Product-facing user action inferred from the patch-status record.
///
/// This intentionally sits above `Libre3SensorError`: the app can present a
/// replacement notification for conditions that are not simply the
/// post-shutdown `.terminated` state. Current Abbott-app compatibility:
/// `3 -> checkSensor`, `5/6 -> sensorEnded`, `7 -> checkSensor` (transient
/// transmission error), `8 -> replaceSensor`.
/// When `errorData == 0`, patch-state fallback treats state `3` as
/// check-sensor, states `5`/`6` as sensor-ended, and states `7`/`8` as
/// replace-sensor.
enum Libre3SensorAttention: Equatable, Sendable, CustomStringConvertible {
    case none
    case checkSensor
    case sensorEnded
    case replaceSensor
    case unknown(Int16)

    init(errorData: Int16, patchState: Int8? = nil) {
        switch errorData {
        case 0:
            break
        case 3:
            self = .checkSensor
            return
        case 5, 6:
            self = .sensorEnded
            return
        case 7:
            // Code 7 is a transient transmission/comms error (see
            // `Libre3SensorError.transmissionError`), not a terminal replace
            // condition , the sensor keeps producing valid glucose. Surface it
            // as a soft check-sensor attention rather than replaceSensor so
            // clients don't latch the sensor inoperable on a recoverable fault.
            self = .checkSensor
            return
        case 8:
            self = .replaceSensor
            return
        default:
            self = .unknown(errorData)
            return
        }

        switch patchState {
        case 3:
            self = .checkSensor
        case 7, 8:
            self = .replaceSensor
        case 5, 6:
            self = .sensorEnded
        default:
            self = .none
        }
    }

    var shouldNotifyUser: Bool {
        self != .none
    }

    var isReplaceSensor: Bool {
        self == .replaceSensor
    }

    var description: String {
        switch self {
        case .none:
            return "none"
        case .checkSensor:
            return "checkSensor"
        case .sensorEnded:
            return "sensorEnded"
        case .replaceSensor:
            return "replaceSensor"
        case .unknown(let code):
            return "unknown(\(code))"
        }
    }
}

/// Sensor error/status code carried in the patch-status / event-log
/// `errorData` field. Current compatibility mapping:
/// `3 → insertionFailure`, `5 → expired`, `6 → terminated`,
/// `7 → transmissionError`, `8 → terminated`, everything else is
/// treated as no error or preserved as unknown.
///
/// Keep code 5 and codes 6/8 separate: expiry can remain BLE-visible, while
/// terminated is a shutdown/end-session state. Unknown non-zero codes should
/// be surfaced rather than coerced into a named state.
enum Libre3SensorError: Equatable, Sendable, CustomStringConvertible {
    /// No error (code 0) , the healthy steady state.
    case none
    /// Sensor failed to start / bad insertion (code 3).
    case insertionFailure
    /// Normal end-of-wear (code 5). Libre 3 sensors can still advertise
    /// after expiry until shutdown.
    case expired
    /// Sensor terminated / shut down (codes 6 and 8). Exhausted sensors
    /// can reach this after the shutdown patch command.
    case terminated
    /// Transmission-error vocabulary (code 7). Abbott's Android app also
    /// treats this code as a replace-sensor UI condition, use
    /// `Libre3PatchStatus.sensorAttention` for notification routing.
    case transmissionError
    /// Any other non-zero code we don't yet have evidence to name.
    case unknown(Int16)

    init(code: Int16) {
        switch code {
        case 0:
            self = .none
        case 3:
            self = .insertionFailure
        case 5:
            self = .expired
        case 6, 8:
            self = .terminated
        case 7:
            self = .transmissionError
        default:
            self = .unknown(code)
        }
    }

    /// `true` for the post-shutdown terminated state.
    var isShutdownTerminated: Bool {
        self == .terminated
    }

    /// `true` for a start/insertion failure.
    var isInsertionFailure: Bool {
        self == .insertionFailure
    }

    var description: String {
        switch self {
        case .none:
            return "none"
        case .insertionFailure:
            return "insertionFailure"
        case .expired:
            return "expired"
        case .terminated:
            return "terminated"
        case .transmissionError:
            return "transmissionError"
        case .unknown(let code):
            return "unknown(\(code))"
        }
    }
}

enum Libre3PatchState: Equatable, Sendable, CustomStringConvertible {
    case active
    case raw(Int8)

    init(rawValue: Int8) {
        switch rawValue {
        case 4:
            self = .active
        default:
            self = .raw(rawValue)
        }
    }

    var rawValue: Int8 {
        switch self {
        case .active:
            return 4
        case .raw(let value):
            return value
        }
    }

    var isActive: Bool {
        rawValue == 4
    }

    /// States handled as expired/error states by known Libre 3 clients.
    ///
    /// These states may be followed by backfill and then an explicit shutdown
    /// command. They are distinct from the already-terminated states 6 and 8.
    var isExpiredOrError: Bool {
        rawValue == 3 || rawValue == 5 || rawValue == 7
    }

    /// States handled as already terminated/shut down by known Libre 3 clients.
    var isTerminated: Bool {
        rawValue == 6 || rawValue == 8
    }

    var description: String {
        switch self {
        case .active:
            return "active"
        case .raw(let value):
            return "raw(\(value))"
        }
    }
}
