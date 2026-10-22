//
//  Libre3NFCActivationModels.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

// Adapted from RoundWhiteDiscKit.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/NFCActivationModels.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

struct Libre3NFCPatchInfo: Sendable, Equatable {
    let inputRaw: Data
    let raw: Data
    let stateByte: UInt8
    let securityVersion: UInt16
    let region: UInt16
    let productType: UInt8
    let generation: UInt16
    let wearDurationMinutes: UInt16
    let warmupMinutes: UInt16
    let firmwareVersion: String
    let serialNumber: String

    init(raw: Data) throws {
        let frame = Self.normalizeResponse(raw)
        guard frame.count >= 29, frame[0] == 0x00, frame[1] == 0xa5 else {
            throw Libre3NFCError.invalidPatchInfo(raw)
        }
        self.inputRaw = raw
        self.raw = frame
        self.securityVersion = Self.u16(frame, 3)
        self.region = Self.u16(frame, 5)
        self.generation = Self.u16(frame, 7)
        self.wearDurationMinutes = Self.u16(frame, 9)
        self.firmwareVersion = "\(Self.byte(frame, 14)).\(Self.byte(frame, 13)).\(Self.byte(frame, 12)).\(Self.byte(frame, 11))"
        self.productType = Self.byte(frame, 15)
        self.warmupMinutes = UInt16(Self.byte(frame, 16)) * 5
        self.stateByte = Self.byte(frame, 17)
        let serialBytes = frame.subdata(in: (frame.startIndex + 18)..<(frame.startIndex + 27))
        self.serialNumber = String(data: serialBytes, encoding: .ascii) ?? Self.hex(serialBytes)
    }

    var recommendedCommandCode: Libre3NFCActivationCommandCode {
        stateByte == 0x01 ? .activate : .switchReceiver
    }
}

private extension Libre3NFCPatchInfo {
    static func normalizeResponse(_ raw: Data) -> Data {
        var frame = raw
        if frame.first == 0xa5 {
            frame = Data([0x00]) + frame
        }
        if frame.count >= 2, frame[0] == 0x00, frame[1] == 0xa5 {
            var bodyStart = 2
            while bodyStart < frame.count, frame[bodyStart] == 0xa5 {
                bodyStart += 1
            }
            if bodyStart > 2 {
                return Data([0x00, 0xa5]) + frame.suffix(from: bodyStart)
            }
            return frame
        }
        return raw
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    static func u16(_ data: Data, _ offset: Int) -> UInt16 {
        let i = data.startIndex + offset
        return UInt16(data[i]) | (UInt16(data[i + 1]) << 8)
    }

    static func byte(_ data: Data, _ offset: Int) -> UInt8 {
        data[data.startIndex + offset]
    }
}

struct Libre3NFCActivationResponse: Sendable, Equatable {
    let raw: Data
    let bleAddressLittleEndian: Data
    let blePIN: Data
    let activationTimeRaw: Data
    let trailingCRC: Data

    init(raw: Data) throws {
        let frame = Self.normalizeResponse(raw)
        guard frame.count == 19, frame[0] == 0x00, frame[1] == 0xa5, frame[2] == 0x00 else {
            throw Libre3NFCError.invalidActivationResponse(raw)
        }
        self.raw = frame
        self.bleAddressLittleEndian = frame.subdata(in: 3..<9)
        self.blePIN = frame.subdata(in: 9..<13)
        self.activationTimeRaw = frame.subdata(in: 13..<17)
        self.trailingCRC = frame.subdata(in: 17..<19)
    }

    var bleAddressDisplay: String {
        bleAddressLittleEndian.reversed()
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }

    func sensorState(
        serialNumber: String?,
        receiverID: Libre3ReceiverID? = nil,
        patchInfo: Libre3NFCPatchInfo? = nil,
        source: String? = "NFC activation response"
    ) throws -> Libre3SensorState {
        try Libre3SensorState(
            serialNumber: serialNumber,
            blePIN: blePIN,
            bleAddress: bleAddressDisplay,
            receiverID: receiverID,
            source: source,
            warmupDurationMinutes: patchInfo.map { Int($0.warmupMinutes) },
            wearDurationMinutes: patchInfo.map { Int($0.wearDurationMinutes) }
        )
    }
}

private extension Libre3NFCActivationResponse {
    static func normalizeResponse(_ raw: Data) -> Data {
        if raw.count >= 2, raw[0] == 0x00, raw[1] == 0xa5 {
            return raw
        }
        if raw.first == 0xa5 {
            return Data([0x00]) + raw
        }
        return raw
    }
}

struct Libre3NFCScanResult: Sendable, Equatable {
    let patchInfo: Libre3NFCPatchInfo
    let commandCode: Libre3NFCActivationCommandCode?
    let commandParameters: Data?
    let activationResponse: Libre3NFCActivationResponse?

    init(
        patchInfo: Libre3NFCPatchInfo,
        commandCode: Libre3NFCActivationCommandCode? = nil,
        commandParameters: Data? = nil,
        activationResponse: Libre3NFCActivationResponse? = nil
    ) {
        self.patchInfo = patchInfo
        self.commandCode = commandCode
        self.commandParameters = commandParameters
        self.activationResponse = activationResponse
    }
}

enum Libre3NFCScanMode: Sendable, Equatable {
    case readPatchInfo
    case activateFreshSensor(receiverID: UInt32, timeSeconds: UInt32? = nil)
    case switchReceiver(receiverID: UInt32, timeSeconds: UInt32? = nil)
    case activateOrSwitchReceiver(receiverID: UInt32, timeSeconds: UInt32? = nil)
    case forceActivationCommand(commandCode: Libre3NFCActivationCommandCode, receiverID: UInt32, timeSeconds: UInt32? = nil)
}

enum Libre3NFCError: Error, Sendable, Equatable {
    case readerUnavailable
    case sessionAlreadyActive
    case noTag
    case multipleTags
    case nonISO15693Tag
    case invalidPatchInfo(Data)
    case invalidActivationResponse(Data)
    case invalidActivationResponseForPatch(
        commandCode: Libre3NFCActivationCommandCode,
        patchInfo: Libre3NFCPatchInfo,
        raw: Data
    )
    case unexpectedSensorState(patchInfo: Libre3NFCPatchInfo)
}

extension Libre3NFCError: CustomStringConvertible, LocalizedError {
    var description: String {
        switch self {
        case .readerUnavailable:
            return "readerUnavailable"
        case .sessionAlreadyActive:
            return "sessionAlreadyActive"
        case .noTag:
            return "noTag"
        case .multipleTags:
            return "multipleTags"
        case .nonISO15693Tag:
            return "nonISO15693Tag"
        case .invalidPatchInfo(let data):
            return "invalidPatchInfo(\(data.count) bytes)"
        case .invalidActivationResponse(let data):
            return "invalidActivationResponse(\(data.count) bytes)"
        case .invalidActivationResponseForPatch(let commandCode, let patchInfo, let raw):
            return "invalidActivationResponse(command=\(commandCode.rawValue), state=\(patchInfo.stateByte), bytes=\(raw.count))"
        case .unexpectedSensorState(let patchInfo):
            return "unexpectedSensorState(\(patchInfo.stateByte))"
        }
    }

    var errorDescription: String? {
        switch self {
        case .readerUnavailable: return TextsLibre3.localized("NFC scanning is unavailable on this device.")
        case .sessionAlreadyActive: return TextsLibre3.localized("An NFC scan is already running.")
        default: return TextsLibre3.localized("The sensor scan failed. Hold the top of the phone close to the sensor and retry with the original Receiver ID.")
        }
    }

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

// Libre3SensorState and Libre3SensorStateError copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/Libre3SensorStateLoader.swift
// Licensed under MIT. See license.md in the Libre3 folder.
struct Libre3SensorState: Equatable, Sendable {
    let serialNumber: String?
    let bleAddress: String?
    let blePIN: Data
    let receiverID: Libre3ReceiverID?
    let source: String?
    let lastGlucoseLifeCount: UInt16?
    let lastGlucoseMgDL: UInt16?
    let warmupDurationMinutes: Int?
    let wearDurationMinutes: Int?

    init(
        serialNumber: String?,
        blePIN: Data,
        bleAddress: String? = nil,
        receiverID: Libre3ReceiverID? = nil,
        source: String? = nil,
        lastGlucoseLifeCount: UInt16? = nil,
        lastGlucoseMgDL: UInt16? = nil,
        warmupDurationMinutes: Int? = nil,
        wearDurationMinutes: Int? = nil
    ) throws {
        guard blePIN.count == 4 else {
            throw Libre3SensorStateError.wrongBlePINSize(blePIN.count)
        }
        self.serialNumber = serialNumber
        self.bleAddress = bleAddress
        self.blePIN = blePIN
        self.receiverID = receiverID
        self.source = source
        self.lastGlucoseLifeCount = lastGlucoseLifeCount
        self.lastGlucoseMgDL = lastGlucoseMgDL
        self.warmupDurationMinutes = warmupDurationMinutes.map { max(0, $0) }
        self.wearDurationMinutes = wearDurationMinutes.map { max(0, $0) }
    }

    func updatingLastGlucose(lifeCount: UInt16, mgDL: UInt16?) throws -> Libre3SensorState {
        try Libre3SensorState(
            serialNumber: serialNumber,
            blePIN: blePIN,
            bleAddress: bleAddress,
            receiverID: receiverID,
            source: source,
            lastGlucoseLifeCount: lifeCount,
            lastGlucoseMgDL: mgDL,
            warmupDurationMinutes: warmupDurationMinutes,
            wearDurationMinutes: wearDurationMinutes
        )
    }

    /// Persist the sensor's warmup/wear cycle taken from the NFC patch info, so
    /// reconnects (which do not re-scan NFC) can build lifecycle from the
    /// sensor's reported durations rather than the assumed defaults.
    func applyingSensorCycle(from patchInfo: Libre3NFCPatchInfo) throws -> Libre3SensorState {
        try Libre3SensorState(
            serialNumber: serialNumber,
            blePIN: blePIN,
            bleAddress: bleAddress,
            receiverID: receiverID,
            source: source,
            lastGlucoseLifeCount: lastGlucoseLifeCount,
            lastGlucoseMgDL: lastGlucoseMgDL,
            warmupDurationMinutes: Int(patchInfo.warmupMinutes),
            wearDurationMinutes: Int(patchInfo.wearDurationMinutes)
        )
    }

    func updatingLastAcceptedGlucose(from dataPlaneState: Libre3DataPlaneState) throws -> Libre3SensorState {
        guard let lifeCount = dataPlaneState.lastAcceptedGlucoseLifeCount else {
            return self
        }
        return try updatingLastGlucose(
            lifeCount: lifeCount,
            mgDL: dataPlaneState.lastAcceptedGlucoseMgDL
        )
    }
}

enum Libre3SensorStateError: Error, Equatable {
    case invalidJSON
    case missingBlePIN
    case invalidBlePIN(String)
    case invalidReceiverID(String)
    case wrongBlePINSize(Int)
}
