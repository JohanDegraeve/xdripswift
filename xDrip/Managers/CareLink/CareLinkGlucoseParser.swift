//
//  CareLinkGlucoseParser.swift
//  xdripswift
//
//  Created by Paul Plant on 1/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK: - Glucose normalization

/// Privacy-safe facts about one CareLink glucose payload.
///
/// Counts and clock provenance are sufficient to diagnose a payload variant without recording
/// glucose values, medical timestamps, account identifiers or the response body.
struct CareLinkGlucoseParseDiagnostics: Equatable {
    enum ClockSource: String {
        case payload
        case retained
        case unavailable
    }

    var candidateCount = 0
    var acceptedCount = 0
    var invalidValueCount = 0
    var missingTimestampCount = 0
    var futureTimestampCount = 0
    var expiredTimestampCount = 0
    var duplicateTimestampCount = 0
    var hasLastSG = false
    var clockSource = ClockSource.unavailable
    var offsetMinutes: Int?
}

/// Normalized readings plus the clock evidence needed by the next overlapping response.
struct CareLinkGlucoseParseResult {
    var readings: [FollowerBgReading]
    var metadata: CareLinkMetadata
    let diagnostics: CareLinkGlucoseParseDiagnostics
    /// Only a payload-derived offset is returned for retention. A retained fallback cannot validate itself.
    let payloadDeviceOffset: TimeInterval?
}

/// Converts the shared shape of periodic and legacy Connect responses into the
/// existing follower reading type so the app's normal processing pipeline remains unchanged.
/// Parsing is intentionally independent of account and route discovery.
enum CareLinkGlucoseParser {
    /// Merges `sgs` and `lastSG`, rejects unsafe values/times, deduplicates equal seconds, and
    /// returns newest-first mg/dL readings together with any device metadata in the envelope.
    static func readings(
        from data: Data,
        now: Date = Date(),
        retainedDeviceOffset: TimeInterval? = nil
    ) throws -> CareLinkGlucoseParseResult {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CareLinkError.malformedResponse
        }
        let root = (envelope["patientData"] as? [String: Any]) ?? envelope

        var metadata = CareLinkMetadata(
            deviceFamily: string(root["medicalDeviceFamily"]) ?? string(envelope["medicalDeviceFamily"]),
            deviceModel: string(root["pumpModelNumber"]) ?? nestedString(root, "medicalDeviceInformation", "modelNumber") ?? nestedString(envelope, "medicalDeviceInformation", "modelNumber"),
            deviceSerial: string(root["medicalDeviceSerialNumber"]) ?? string(envelope["medicalDeviceSerialNumber"]),
            sensorType: nestedString(root, "cgmInfo", "sensorType"),
            sensorState: string(root["sensorState"]),
            sensorRemainingMinutes: sensorRemainingMinutes(root)
        )

        var values = (root["sgs"] as? [[String: Any]]) ?? []
        let hasLastSG = root["lastSG"] is [String: Any]
        if let last = root["lastSG"] as? [String: Any] { values.append(last) }

        // Some unzoned timestamps represent the device's local wall clock. Derive its whole-hour
        // offset from CareLink server time rather than silently interpreting it as the phone zone.
        let serverTime = number(root["currentServerTime"]).map { Date(timeIntervalSince1970: normalizedEpoch($0)) }
        let deviceTime = clockDate(root["sMedicalDeviceTime"])
            ?? clockDate(root["medicalDeviceTime"])
        let payloadDeviceOffset = validatedDeviceOffset(serverTime: serverTime, deviceTime: deviceTime)
        let retainedDeviceOffset = retainedDeviceOffset.flatMap(validatedDeviceOffset)
        let offset = payloadDeviceOffset ?? retainedDeviceOffset
        var diagnostics = CareLinkGlucoseParseDiagnostics(
            candidateCount: values.count,
            hasLastSG: hasLastSG,
            clockSource: payloadDeviceOffset != nil ? .payload : (retainedDeviceOffset != nil ? .retained : .unavailable),
            offsetMinutes: offset.map { Int($0 / 60) }
        )

        var deduplicated: [Int64: FollowerBgReading] = [:]
        for value in values {
            guard let sg = number(value["sg"]), sg > 0, sg.isFinite else {
                diagnostics.invalidValueCount += 1
                continue
            }
            guard let timestamp = timestamp(value) else {
                diagnostics.missingTimestampCount += 1
                continue
            }
            let date: Date
            switch timestamp {
            case let .absolute(value):
                date = value
            case let .deviceLocal(value):
                // A retained offset is used only when a previous payload proved the relationship
                // between this patient's device wall clock and CareLink server time.
                date = value.addingTimeInterval(-(offset ?? 0))
            }
            guard date <= now.addingTimeInterval(5 * 60) else {
                diagnostics.futureTimestampCount += 1
                continue
            }
            guard date >= now.addingTimeInterval(-48 * 60 * 60) else {
                diagnostics.expiredTimestampCount += 1
                continue
            }
            // CareLink often represents the same `lastSG` with millisecond epoch time and
            // an `sgs` entry truncated to an ISO-8601 second.
            let key = Int64(date.timeIntervalSince1970)
            if deduplicated[key] != nil { diagnostics.duplicateTimestampCount += 1 }
            deduplicated[key] = FollowerBgReading(timeStamp: date, sgv: sg)
        }

        let readings = deduplicated.values.sorted { $0.timeStamp > $1.timeStamp }
        diagnostics.acceptedCount = readings.count
        if metadata.sensorType == nil, metadata.deviceFamily?.localizedCaseInsensitiveContains("guardian") == true {
            metadata.sensorType = "Guardian"
        }
        return CareLinkGlucoseParseResult(
            readings: readings,
            metadata: metadata,
            diagnostics: diagnostics,
            payloadDeviceOffset: payloadDeviceOffset
        )
    }

    /// Keeps absolute timestamps separate from device-local wall-clock strings so only the latter
    /// can receive a proven CareLink clock offset.
    private enum ParsedTimestamp {
        case absolute(Date)
        case deviceLocal(Date)
    }

    /// Accepts the field names and epoch/ISO representations observed across all three routes.
    private static func timestamp(_ value: [String: Any]) -> ParsedTimestamp? {
        for key in ["timestamp", "date", "datetime", "dateTime", "sgTimestamp"] {
            if let rawValue = value[key] {
                if let number = rawValue as? NSNumber {
                    return .absolute(Date(timeIntervalSince1970: normalizedEpoch(number.doubleValue)))
                }
                if let text = rawValue as? String {
                    if let value = Double(text) {
                        return .absolute(Date(timeIntervalSince1970: normalizedEpoch(value)))
                    }
                    if let date = zonedDate(text) { return .absolute(date) }
                    if let date = unzonedDate(text) { return .deviceLocal(date) }
                }
            }
        }
        return nil
    }

    /// Parses a server/device clock without applying an offset. An unzoned device clock is a wall
    /// clock represented in UTC solely so its difference from the absolute server clock is stable.
    private static func clockDate(_ value: Any?) -> Date? {
        if let number = number(value) {
            return Date(timeIntervalSince1970: normalizedEpoch(number))
        }
        guard let text = string(value) else { return nil }
        return zonedDate(text) ?? unzonedDate(text)
    }

    private static func zonedDate(_ text: String) -> Date? {
        let withZone = ISO8601DateFormatter()
        withZone.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withZone.date(from: text) { return date }
        withZone.formatOptions = [.withInternetDateTime]
        return withZone.date(from: text)
    }

    private static func unzonedDate(_ text: String) -> Date? {
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// CareLink currently reports whole-hour device offsets. Rejecting impossible values prevents
    /// a malformed clock from becoming reusable evidence for a later payload.
    private static func validatedDeviceOffset(serverTime: Date?, deviceTime: Date?) -> TimeInterval? {
        guard let serverTime, let deviceTime else { return nil }
        return validatedDeviceOffset((deviceTime.timeIntervalSince(serverTime) / 3600).rounded() * 3600)
    }

    private static func validatedDeviceOffset(_ offset: TimeInterval) -> TimeInterval? {
        guard offset.isFinite, abs(offset) <= 14 * 60 * 60 else { return nil }
        return offset
    }

    /// CareLink uses both seconds and milliseconds. Values above this threshold are milliseconds.
    private static func normalizedEpoch(_ value: Double) -> TimeInterval {
        value > 100_000_000_000 ? value / 1000 : value
    }

    /// Accepts JSON numbers and numeric strings used by older CareLink routes.
    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func nestedString(_ root: [String: Any], _ object: String, _ key: String) -> String? {
        (root[object] as? [String: Any])?[key] as? String
    }

    /// Prefers the minute value reported by current routes and accepts the older hour value
    /// only when it is not CareLink's 255-hour unavailable sentinel.
    private static func sensorRemainingMinutes(_ root: [String: Any]) -> Int? {
        if let minutes = number(root["sensorDurationMinutes"]), minutes.isFinite, minutes >= 0 {
            return Int(minutes)
        }
        if let hours = number(root["sensorDurationHours"]), hours.isFinite, hours >= 0, hours < 255 {
            return Int(hours * 60)
        }
        return nil
    }
}
