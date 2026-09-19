//
//  DexcomG6SensorLabel.swift
//  xdrip
//
//  Created by Paul Plant on 26/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK: - sensor label

/// Source-native values decoded from a Dexcom G6/ONE sensor-label GS1 Data Matrix.
struct DexcomG6SensorLabel: Equatable, Hashable {
    let sensorCode: String
    let lotNumber: String
    let serialNumber: String
    let productIdentifier: String?
    let manufactureDate: Date?
    let expirationDate: Date?

    init(
        sensorCode: String,
        lotNumber: String,
        serialNumber: String,
        productIdentifier: String? = nil,
        manufactureDate: Date? = nil,
        expirationDate: Date? = nil
    ) {
        self.sensorCode = sensorCode
        self.lotNumber = lotNumber
        self.serialNumber = serialNumber
        self.productIdentifier = productIdentifier
        self.manufactureDate = manufactureDate
        self.expirationDate = expirationDate
    }
}

enum DexcomG6SensorLabelParserError: Error, Equatable {
    case missingRequiredField
    case duplicateRequiredField
    case invalidLotNumber
    case invalidSerialNumber
    case invalidSensorCode
}

/// Decodes the GS1 Data Matrix printed on a Dexcom G7 applicator.
/// The observed production labels use fixed-width AIs without group separators:
/// 01 (GTIN), 21 (serial), 11 (manufacture date), 17 (expiry), and 240 (sensor code).
enum DexcomG7SensorLabelParser {
    static func parse(_ payload: String) throws -> DexcomG6SensorLabel {
        let digits = normalizedPayload(payload)
        guard digits.count == 53, digits.allSatisfy(\.isNumber) else {
            throw DexcomG6SensorLabelParserError.missingRequiredField
        }
        guard digits.count == 53,
              digits.hasPrefix("01"),
              String(digits.dropFirst(16)).hasPrefix("21"),
              String(digits.dropFirst(30)).hasPrefix("11"),
              String(digits.dropFirst(38)).hasPrefix("17"),
              String(digits.dropFirst(46)).hasPrefix("240") else {
            throw DexcomG6SensorLabelParserError.missingRequiredField
        }

        let gtin = substring(digits, 2 ..< 16)
        let serialNumber = substring(digits, 18 ..< 30)
        let manufactureDate = try date(substring(digits, 32 ..< 38))
        let expirationDate = try date(substring(digits, 40 ..< 46))
        let sensorCode = substring(digits, 49 ..< 53)

        guard sensorCode.count == 4, sensorCode.allSatisfy(\.isNumber) else {
            throw DexcomG6SensorLabelParserError.invalidSensorCode
        }

        return DexcomG6SensorLabel(
            sensorCode: sensorCode,
            lotNumber: "",
            serialNumber: serialNumber,
            productIdentifier: gtin,
            manufactureDate: manufactureDate,
            expirationDate: expirationDate
        )
    }

    /// Apple barcode APIs can expose the ISO symbology identifier and FNC1 separators while
    /// other decoders return only the encoded digits. Normalize those transport wrappers before
    /// validating the exact G7 application-identifier layout.
    private static func normalizedPayload(_ payload: String) -> String {
        var value = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("]d1") || value.hasPrefix("]d2") {
            value.removeFirst(3)
        }
        value.removeAll { $0 == "\u{001D}" || $0 == "\u{001E}" || $0 == "\u{0004}" }
        return value
    }

    private static func substring(_ value: String, _ range: Range<Int>) -> String {
        let start = value.index(value.startIndex, offsetBy: range.lowerBound)
        let end = value.index(value.startIndex, offsetBy: range.upperBound)
        return String(value[start ..< end])
    }

    private static func date(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyMMdd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else {
            throw DexcomG6SensorLabelParserError.missingRequiredField
        }
        return date
    }
}

struct DexcomSensorLabelScannerConfiguration {
    let parse: (String) throws -> DexcomG6SensorLabel

    static let g6 = DexcomSensorLabelScannerConfiguration(parse: DexcomG6SensorLabelParser.parse)
    static let g7 = DexcomSensorLabelScannerConfiguration(parse: DexcomG7SensorLabelParser.parse)
}

enum DexcomG6SensorLabelParser {
    private static let groupSeparator = "\u{001D}"

    static func parse(_ payload: String) throws -> DexcomG6SensorLabel {
        let fields = payload.components(separatedBy: groupSeparator)
        let lotValues = values(for: "10", in: fields)
        let serialValues = values(for: "21", in: fields)
        let codeValues = values(for: "240", in: fields)

        guard !lotValues.isEmpty, !serialValues.isEmpty, !codeValues.isEmpty else {
            throw DexcomG6SensorLabelParserError.missingRequiredField
        }
        guard lotValues.count == 1, serialValues.count == 1, codeValues.count == 1 else {
            throw DexcomG6SensorLabelParserError.duplicateRequiredField
        }

        let lotNumber = lotValues[0]
        let serialNumber = serialValues[0]
        let sensorCode = codeValues[0]

        guard (1...20).contains(lotNumber.count) else {
            throw DexcomG6SensorLabelParserError.invalidLotNumber
        }
        guard (1...20).contains(serialNumber.count) else {
            throw DexcomG6SensorLabelParserError.invalidSerialNumber
        }
        guard sensorCode.count == 4,
              sensorCode.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw DexcomG6SensorLabelParserError.invalidSensorCode
        }

        return DexcomG6SensorLabel(
            sensorCode: sensorCode,
            lotNumber: lotNumber,
            serialNumber: serialNumber
        )
    }

    private static func values(for applicationIdentifier: String, in fields: [String]) -> [String] {
        fields.compactMap { field in
            guard field.hasPrefix(applicationIdentifier) else { return nil }
            return String(field.dropFirst(applicationIdentifier.count))
        }
    }
}

// MARK: - sensor start metadata

/// Values captured when the user confirms a sensor start.
struct SensorStartRequest {
    let startDate: Date
    let requestedSensorCode: String?
    let sensorLabel: DexcomG6SensorLabel?

    init(startDate: Date, requestedSensorCode: String? = nil, sensorLabel: DexcomG6SensorLabel? = nil) {
        self.startDate = startDate
        self.requestedSensorCode = requestedSensorCode
        self.sensorLabel = sensorLabel
    }
}

// MARK: - persisted sensor metadata

/// Persisted values are append-only. Existing values must not be reordered.
enum SensorSessionOrigin: Int16 {
    case unknown = 0
    case startRequested = 1
    case startedByApp = 2
    case existingSessionAdopted = 3
    case transmitterDetected = 4
    case startRejected = 5
}

/// Persisted values are append-only. Existing values must not be reordered.
enum SensorCalibrationMode: Int16 {
    case unknown = 0
    case noCode = 1
    case factoryCoded = 2
}

/// Typed session-start response used to reconcile the local Sensor with the transmitter.
struct CGMSensorSessionStartResult {
    let response: DexcomSessionStartResponse
    let requestedStartDate: Date
    let sessionStartDate: Date

    var isSuccessful: Bool {
        switch response {
        case .manualCalibrationSessionStarted,
             .manualCalibrationSessionInProgress,
             .autoCalibrationSessionInProgress:
            return true
        case .staleStartComand, .error, .transmitterEndOfLife:
            return false
        }
    }

    var calibrationMode: SensorCalibrationMode {
        switch response {
        case .manualCalibrationSessionStarted, .manualCalibrationSessionInProgress:
            return .noCode
        case .autoCalibrationSessionInProgress:
            return .factoryCoded
        case .staleStartComand, .error, .transmitterEndOfLife:
            return .unknown
        }
    }

    func sessionOrigin(tolerance: TimeInterval) -> SensorSessionOrigin {
        guard isSuccessful else { return .startRejected }
        return abs(sessionStartDate.timeIntervalSince(requestedStartDate)) <= tolerance
            ? .startedByApp
            : .existingSessionAdopted
    }
}

// MARK: - sensor metadata

extension Sensor {
    var sensorSessionOrigin: SensorSessionOrigin {
        get { SensorSessionOrigin(rawValue: sensorSessionOriginRaw) ?? .unknown }
        set { sensorSessionOriginRaw = newValue.rawValue }
    }

    var sensorCalibrationMode: SensorCalibrationMode {
        get { SensorCalibrationMode(rawValue: sensorCalibrationModeRaw) ?? .unknown }
        set { sensorCalibrationModeRaw = newValue.rawValue }
    }

    var activeSensorCode: String? {
        SensorCodeState.activeCode(
            requestedSensorCode: requestedSensorCode,
            origin: sensorSessionOrigin,
            calibrationMode: sensorCalibrationMode
        )
    }

    func apply(startRequest: SensorStartRequest) {
        requestedSensorCode = startRequest.requestedSensorCode
        sensorLabelCode = startRequest.sensorLabel?.sensorCode
        sensorLotNumber = startRequest.sensorLabel?.lotNumber
        sensorSerialNumber = startRequest.sensorLabel?.serialNumber
        sensorSessionOrigin = startRequest.requestedSensorCode == nil ? .unknown : .startRequested
        sensorCalibrationMode = .unknown
    }

    func copyDexcomStartMetadata(from sensor: Sensor) {
        requestedSensorCode = sensor.requestedSensorCode
        sensorLabelCode = sensor.sensorLabelCode
        sensorLotNumber = sensor.sensorLotNumber
        sensorSerialNumber = sensor.sensorSerialNumber
    }

    /// replaces a provisional or rejected command result after validated glucose data confirms the matching session
    @discardableResult
    func confirmSessionStartedByApp() -> Bool {
        guard sensorSessionOrigin == .startRequested || sensorSessionOrigin == .startRejected else {
            return false
        }

        sensorSessionOrigin = .startedByApp

        if requestedSensorCode == "0000" {
            sensorCalibrationMode = .noCode
        } else if requestedSensorCode != nil {
            sensorCalibrationMode = .factoryCoded
        } else {
            sensorCalibrationMode = .unknown
        }

        return true
    }
}

/// Derives an active code only when the transmitter result makes that code safe to claim.
enum SensorCodeState {
    static func activeCode(
        requestedSensorCode: String?,
        origin: SensorSessionOrigin,
        calibrationMode: SensorCalibrationMode
    ) -> String? {
        switch calibrationMode {
        case .noCode:
            guard origin == .startedByApp || origin == .existingSessionAdopted else {
                return nil
            }
            return "0000"
        case .factoryCoded:
            guard origin == .startedByApp,
                  let requestedSensorCode,
                  requestedSensorCode != "0000" else {
                return nil
            }
            return requestedSensorCode
        case .unknown:
            return nil
        }
    }
}
