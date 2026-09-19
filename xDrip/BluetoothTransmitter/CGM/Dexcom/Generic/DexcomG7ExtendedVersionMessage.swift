import Foundation

/// The Dexcom G7 family returns its configured session length in response to the single-byte
/// `0x52` extended-version request. The session length already includes the fixed 12-hour grace
/// period, so it is the value that xDrip4iOS should use for its final sensor-age limit.
///
/// This decoder follows the public G7SensorKit reference implementation and its captured 10-day
/// and 15-day test packets:
/// https://github.com/LoopKit/G7SensorKit/blob/main/G7SensorKit/Messages/ExtendedVersionMessage.swift
struct DexcomG7ExtendedVersionMessage: Equatable {
    /// Both the request and the G7 response use `0x52` as their first byte.
    static let opCode: UInt8 = 0x52

    /// The complete reported session length, including the 12-hour grace period.
    let sessionLength: TimeInterval

    /// The sensor warm-up duration reported by this specific product and firmware.
    let warmupDuration: TimeInterval

    /// The algorithm build identifier supplied by the sensor.
    let algorithmVersion: UInt32

    /// The hardware identifier supplied by the sensor.
    let hardwareVersion: UInt8

    /// A separate Dexcom upper-bound field. It is 12 for a 10.5-day sensor and 17 for a
    /// 15.5-day sensor, so it must not be mistaken for the actual session duration.
    let maxLifetimeDays: UInt16

    init?(data: Data) {
        // The known G7 response is 15 bytes. Accepting a longer response keeps the parser
        // forward-compatible while still requiring every field that we currently understand.
        guard data.count >= 15, data.first == Self.opCode else { return nil }

        // All multibyte fields in the G7 control response are little-endian.
        sessionLength = TimeInterval(Self.uint32(data, at: 2))
        warmupDuration = TimeInterval(Self.uint16(data, at: 6))
        algorithmVersion = Self.uint32(data, at: 8)
        hardwareVersion = data[12]
        maxLifetimeDays = Self.uint16(data, at: 13)
    }

    /// Reads a little-endian `UInt16` without depending on the CPU's native byte order.
    private static func uint16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset])
            | UInt16(data[offset + 1]) << 8
    }

    /// Reads a little-endian `UInt32` without making an alignment-sensitive raw-memory load.
    private static func uint32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}

/// Owns the one authoritative G7/ONE+/Stelo lifetime decision used by live readings, backfill,
/// sensor-expiry presentation and the active-sensor cache.
enum DexcomG7SensorLifetime {
    /// Exact session length returned by a 10-day sensor, including its 12-hour grace period.
    static let tenDaySessionLength = TimeInterval(days: ConstantsDexcomG7.maxSensorAgeInDays)

    /// Exact session length returned by a 15-day sensor, including its 12-hour grace period.
    static let fifteenDaySessionLength = TimeInterval(days: ConstantsDexcomG7.maxSensorAgeInDaysStelo)

    /// Returns only a session length that is currently understood and safe to use as an expiry
    /// boundary. An unknown future value is logged by the caller and must not silently extend the
    /// period during which repeated post-session glucose values are accepted.
    static func supportedSessionLength(_ sessionLength: TimeInterval?) -> TimeInterval? {
        switch sessionLength {
        case tenDaySessionLength: return tenDaySessionLength
        case fifteenDaySessionLength: return fifteenDaySessionLength
        default: return nil
        }
    }

    /// Converts the protocol duration into the product wording that a human expects to see in
    /// diagnostics. The extra 12 hours are stated separately because Dexcom describes these as
    /// 10-day and 15-day sensors rather than 10.5-day and 15.5-day sensors.
    static func diagnosticDescription(_ sessionLength: TimeInterval?) -> String {
        switch supportedSessionLength(sessionLength) {
        case tenDaySessionLength: return "10-day sensor (+ 12-hour grace period)"
        case fifteenDaySessionLength: return "15-day sensor (+ 12-hour grace period)"
        default: return "not detected"
        }
    }

    /// Uses the sensor-reported duration whenever it is available. Before the one-time response
    /// is received, Stelo's stable `DX01` family prefix provides a safe 15.5-day fallback and all
    /// other G7-family products retain the conservative 10.5-day default.
    static func maximumSensorAgeInDays(
        reportedSessionLength: TimeInterval?,
        deviceName: String?
    ) -> Double {
        if let supportedSessionLength = supportedSessionLength(reportedSessionLength) {
            return supportedSessionLength / TimeInterval(days: 1)
        }

        return deviceName?.uppercased().hasPrefix("DX01") == true
            ? ConstantsDexcomG7.maxSensorAgeInDaysStelo
            : ConstantsDexcomG7.maxSensorAgeInDays
    }
}
