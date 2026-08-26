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
}

enum DexcomG6SensorLabelParserError: Error, Equatable {
    case missingRequiredField
    case duplicateRequiredField
    case invalidLotNumber
    case invalidSerialNumber
    case invalidSensorCode
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
