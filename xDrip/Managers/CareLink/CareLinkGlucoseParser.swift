//
//  CareLinkGlucoseParser.swift
//  xdripswift
//
//  Created by Paul Plant on 1/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK: - Glucose normalization

/// Converts the shared shape of periodic and legacy Connect responses into the
/// existing follower reading type so the app's normal processing pipeline remains unchanged.
/// Parsing is intentionally independent of account and route discovery.
enum CareLinkGlucoseParser {
    /// Merges `sgs` and `lastSG`, rejects unsafe values/times, deduplicates equal seconds, and
    /// returns newest-first mg/dL readings together with any device metadata in the envelope.
    static func readings(from data: Data, now: Date = Date()) throws -> (readings: [FollowerBgReading], metadata: CareLinkMetadata) {
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
        if let last = root["lastSG"] as? [String: Any] { values.append(last) }

        // Some unzoned timestamps represent the device's local wall clock. Derive its whole-hour
        // offset from CareLink server time rather than silently interpreting it as the phone zone.
        let serverTime = number(root["currentServerTime"]).map { Date(timeIntervalSince1970: normalizedEpoch($0)) }
        let deviceTime = parseDate(string(root["sMedicalDeviceTime"]), offset: 0)
            ?? number(root["medicalDeviceTime"]).map { Date(timeIntervalSince1970: normalizedEpoch($0)) }
        let offset: TimeInterval
        if let serverTime, let deviceTime {
            offset = (deviceTime.timeIntervalSince(serverTime) / 3600).rounded() * 3600
        } else {
            offset = 0
        }

        var deduplicated: [Int64: FollowerBgReading] = [:]
        for value in values {
            guard let sg = number(value["sg"]), sg > 0, sg.isFinite,
                  let date = timestamp(value, offset: offset),
                  date <= now.addingTimeInterval(5 * 60),
                  date >= now.addingTimeInterval(-48 * 60 * 60) else { continue }
            // CareLink often represents the same `lastSG` with millisecond epoch time and
            // an `sgs` entry truncated to an ISO-8601 second.
            let key = Int64(date.timeIntervalSince1970)
            deduplicated[key] = FollowerBgReading(timeStamp: date, sgv: sg)
        }

        let readings = deduplicated.values.sorted { $0.timeStamp > $1.timeStamp }
        if metadata.sensorType == nil, metadata.deviceFamily?.localizedCaseInsensitiveContains("guardian") == true {
            metadata.sensorType = "Guardian"
        }
        return (readings, metadata)
    }

    /// Accepts the field names and epoch/ISO representations observed across all three routes.
    private static func timestamp(_ value: [String: Any], offset: TimeInterval) -> Date? {
        for key in ["timestamp", "date", "datetime", "dateTime", "sgTimestamp"] {
            if let n = number(value[key]) { return Date(timeIntervalSince1970: normalizedEpoch(n)) }
            if let text = string(value[key]), let date = parseDate(text, offset: offset) { return date }
        }
        return nil
    }

    /// Parses zoned values directly and applies the derived device offset only to unzoned values.
    private static func parseDate(_ text: String?, offset: TimeInterval) -> Date? {
        guard let text else { return nil }
        if let value = Double(text) { return Date(timeIntervalSince1970: normalizedEpoch(value)) }
        let withZone = ISO8601DateFormatter()
        withZone.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withZone.date(from: text) { return date }
        withZone.formatOptions = [.withInternetDateTime]
        if let date = withZone.date(from: text) { return date }
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let localAsUTC = formatter.date(from: text) { return localAsUTC.addingTimeInterval(-offset) }
        }
        return nil
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
