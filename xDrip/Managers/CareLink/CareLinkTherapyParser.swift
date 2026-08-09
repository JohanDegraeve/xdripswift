//
//  CareLinkTherapyParser.swift
//  xdripswift
//
//  Created by Paul Plant on 1/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK: - Pump and treatment normalization

/// Converts pump state and proven CareLink marker families into app-native values.
/// Patient-scoped stable identities make overlapping 48-hour responses safe to import repeatedly.
enum CareLinkTherapyParser {
    private static let markerDurationMinutes = 5.0

    /// Parses the periodic display-message shape and compatible legacy envelopes.
    /// Unsupported markers are ignored so new CareLink fields cannot create false treatments.
    static func payload(from data: Data, patientID: String, now: Date = .now) throws -> CareLinkTherapyPayload {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CareLinkError.malformedResponse
        }
        let root = (envelope["patientData"] as? [String: Any]) ?? envelope
        let offset = deviceOffset(root: root)
        let markers = root["markers"] as? [[String: Any]] ?? []
        let parsedMarkers = markers.compactMap { marker($0, patientID: patientID, offset: offset, now: now) }
            + autoBasalRecords(markers, patientID: patientID, offset: offset, now: now)
        let treatments = Dictionary(grouping: parsedMarkers, by: \.sourceIdentifier)
            .compactMap { $0.value.first }
            .sorted { $0.date > $1.date }
        let latestBasalRate = treatments
            .first(where: { $0.type == .AutomaticBasal })
            .flatMap { AutomaticBasalTreatmentMath.rate(amount: $0.value, durationSeconds: $0.durationMinutes * 60) }

        let activeInsulin = root["activeInsulin"] as? [String: Any]
        let algorithm = root["therapyAlgorithmState"] as? [String: Any]
        let pump = CareLinkPumpSnapshot(
            observedAt: deviceDate(root["medicalDeviceTime"], offset: offset),
            lastDataUpdateAt: date(root["lastMedicalDeviceDataUpdateServerTime"], offset: offset),
            activeInsulin: nonNegativeNumber(activeInsulin?["amount"]),
            activeInsulinAt: date(activeInsulin?["datetime"], offset: offset),
            currentBasalRate: latestBasalRate ?? nonNegativeNumber(root["basal"]),
            reservoirUnits: nonNegativeNumber(root["reservoirRemainingUnits"]) ?? nonNegativeNumber(root["reservoirAmount"]),
            reservoirPercent: percent(root["reservoirLevelPercent"]),
            batteryPercent: percent(root["pumpBatteryLevelPercent"]),
            isSuspended: boolean(root["pumpSuspended"]),
            isCommunicating: boolean(root["pumpCommunicationState"]),
            isInRange: boolean(root["conduitMedicalDeviceInRange"]),
            algorithmState: string(algorithm?["autoModeShieldState"]),
            algorithmReadiness: string(algorithm?["autoModeReadinessState"]),
            lowGlucoseSuspendState: string(algorithm?["plgmLgsState"]),
            maximumAutoBasalRate: nonNegativeNumber(root["maxAutoBasalRate"]),
            maximumBolusAmount: nonNegativeNumber(root["maxBolusAmount"])
        )
        return CareLinkTherapyPayload(pump: pump, treatments: treatments)
    }

    /// Converts only the three marker families that have unambiguous treatment semantics.
    private static func marker(_ marker: [String: Any], patientID: String, offset: TimeInterval, now: Date) -> CareLinkTherapyRecord? {
        guard let markerType = string(marker["type"]),
              markerType != "AUTO_BASAL_DELIVERY",
              let date = date(marker["timestamp"] ?? marker["dateTime"] ?? marker["displayTime"], offset: offset),
              date <= now.addingTimeInterval(5 * 60),
              date >= now.addingTimeInterval(-48 * 60 * 60)
        else {
            return nil
        }
        let data = marker["data"] as? [String: Any]
        let values = data?["dataValues"] as? [String: Any]
        let normalized: (TreatmentType, Double, Double, String, String?)?

        switch markerType {
        case "INSULIN":
            guard let amount = insulinAmount(marker: marker, values: values), amount > 0
            else {
                return nil
            }
            normalized = (.Insulin, amount, 0, "Bolus", insulinNotes(marker: marker, values: values))
        case "MEAL":
            guard let amount = number(values?["amount"] ?? marker["amount"] ?? marker["carbohydrates"]), amount > 0 else {
                return nil
            }
            normalized = (.Carbs, amount, 0, "Carbs", nil)
        default:
            return nil
        }

        guard let normalized, normalized.1.isFinite else { return nil }
        let timestamp = Int64(date.timeIntervalSince1970.rounded())
        let markerIdentity = number(marker["id"])
            .map { String(Int64($0)) }
            ?? [String(timestamp), normalized.1.description, normalized.2.description].joined(separator: ":")
        let identity = [patientID, markerType, markerIdentity].joined(separator: "|")
        return CareLinkTherapyRecord(
            sourceIdentifier: identity,
            date: date,
            type: normalized.0,
            value: normalized.1,
            durationMinutes: normalized.2,
            nightscoutEventType: normalized.3,
            notes: normalized.4
        )
    }

    /// Stores each native auto-basal amount and retains the interval to the next marker as metadata.
    ///
    /// The interval calculation was adapted from Nocturne's CareLink treatment mapper:
    /// https://github.com/nightscout/nocturne/blob/7df0daaabe59e3430c375272e86695423c885dfa/src/Connectors/Nocturne.Connectors.CareLink/Mappers/CareLinkTreatmentMapper.cs
    private static func autoBasalRecords(_ markers: [[String: Any]], patientID: String, offset: TimeInterval, now: Date) -> [CareLinkTherapyRecord] {
        var seen = Set<String>()
        let values = markers.compactMap { marker -> (date: Date, amount: Double, id: String?)? in
            guard string(marker["type"])?.caseInsensitiveCompare("AUTO_BASAL_DELIVERY") == .orderedSame,
                  let date = date(marker["timestamp"] ?? marker["dateTime"] ?? marker["displayTime"], offset: offset),
                  date <= now.addingTimeInterval(5 * 60),
                  date >= now.addingTimeInterval(-48 * 60 * 60),
                  let amount = number(field("bolusAmount", marker: marker)),
                  amount >= 0
            else {
                return nil
            }
            let id = number(marker["id"]).map { String(Int64($0)) }
            let identity = id ?? "\(Int64(date.timeIntervalSince1970.rounded()))|\(amount)"
            guard seen.insert(identity).inserted else { return nil }
            return (date, amount, id)
        }.sorted { $0.date < $1.date }

        return values.enumerated().map { index, value in
            let nextDate = values.indices.contains(index + 1) ? values[index + 1].date : nil
            let duration = nextDate.map { max(1, $0.timeIntervalSince(value.date) / 60) } ?? markerDurationMinutes
            let timestamp = Int64(value.date.timeIntervalSince1970.rounded())
            // The interval can change when the next marker arrives. Raw time and dose do not.
            let eventIdentity = value.id ?? [String(timestamp), value.amount.description].joined(separator: ":")
            return CareLinkTherapyRecord(
                sourceIdentifier: [patientID, "AUTO_BASAL_DELIVERY", eventIdentity].joined(separator: "|"),
                date: value.date,
                type: .AutomaticBasal,
                value: value.amount,
                durationMinutes: duration,
                nightscoutEventType: "Temp Basal",
                notes: nil
            )
        }
    }

    /// Prefers delivered insulin over programmed insulin and supports nested and legacy fields.
    private static func insulinAmount(marker: [String: Any], values: [String: Any]?) -> Double? {
        let deliveredFast = number(values?["deliveredFastAmount"] ?? marker["deliveredFastAmount"])
        let deliveredExtended = number(values?["deliveredExtendedAmount"] ?? marker["deliveredExtendedAmount"])
        if deliveredFast != nil || deliveredExtended != nil {
            return (deliveredFast ?? 0) + (deliveredExtended ?? 0)
        }
        let programmedFast = number(values?["programmedFastAmount"] ?? marker["programmedFastAmount"])
        let programmedExtended = number(values?["programmedExtendedAmount"] ?? marker["programmedExtendedAmount"])
        if programmedFast != nil || programmedExtended != nil {
            return (programmedFast ?? 0) + (programmedExtended ?? 0)
        }
        return number(marker["insulinUnits"] ?? values?["amount"] ?? marker["amount"])
    }

    /// Retains useful bolus context even though the existing treatment model stores one insulin value.
    private static func insulinNotes(marker: [String: Any], values: [String: Any]?) -> String? {
        var notes = [String]()
        if let activation = string(values?["activationType"] ?? marker["activationType"]) {
            notes.append(readable(activation))
        }
        if let bolusType = string(values?["bolusType"] ?? marker["bolusType"]),
           bolusType.caseInsensitiveCompare("FAST") != .orderedSame,
           bolusType.caseInsensitiveCompare("NORMAL") != .orderedSame {
            notes.append(readable(bolusType) + " bolus")
        }
        if let duration = number(values?["programmedDuration"] ?? marker["programmedDuration"]), duration > 0 {
            notes.append("\(Int(duration.rounded())) min")
        }
        return notes.isEmpty ? nil : notes.joined(separator: ", ")
    }

    private static func field(_ key: String, marker: [String: Any]) -> Any? {
        let data = marker["data"] as? [String: Any]
        let values = data?["dataValues"] as? [String: Any]
        return values?[key] ?? marker[key]
    }

    /// Derives the pump wall-clock offset using the same rule as glucose normalization.
    private static func deviceOffset(root: [String: Any]) -> TimeInterval {
        guard let server = date(root["currentServerTime"], offset: 0),
              let device = date(root["sMedicalDeviceTime"] ?? root["medicalDeviceTime"], offset: 0)
        else {
            return 0
        }
        return (device.timeIntervalSince(server) / 3600).rounded() * 3600
    }

    private static func date(_ value: Any?, offset: TimeInterval) -> Date? {
        if let value = number(value) {
            return Date(timeIntervalSince1970: value > 100_000_000_000 ? value / 1000 : value)
        }
        guard let text = string(value) else { return nil }
        let zoned = ISO8601DateFormatter()
        zoned.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = zoned.date(from: text) { return date }
        zoned.formatOptions = [.withInternetDateTime]
        if let date = zoned.date(from: text) { return date }
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date.addingTimeInterval(-offset) }
        }
        return nil
    }

    /// Numeric medical-device time represents a local wall clock encoded as an epoch value.
    private static func deviceDate(_ value: Any?, offset: TimeInterval) -> Date? {
        if number(value) != nil {
            return date(value, offset: 0)?.addingTimeInterval(-offset)
        }
        return date(value, offset: offset)
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    /// CareLink uses negative numbers when a current pump measurement is unavailable.
    /// Zero remains valid for empty reservoirs, inactive insulin and suspended basal delivery.
    private static func nonNegativeNumber(_ value: Any?) -> Double? {
        guard let value = number(value), value.isFinite, value >= 0 else { return nil }
        return value
    }

    /// Rejects CareLink sentinel and malformed percentage values before they reach app state.
    private static func percent(_ value: Any?) -> Int? {
        guard let value = nonNegativeNumber(value), value <= 100 else { return nil }
        return Int(value)
    }

    private static func boolean(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            if value.caseInsensitiveCompare("true") == .orderedSame { return true }
            if value.caseInsensitiveCompare("false") == .orderedSame { return false }
        }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func readable(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// Region-specific CareLink web host used by login and data requests.
