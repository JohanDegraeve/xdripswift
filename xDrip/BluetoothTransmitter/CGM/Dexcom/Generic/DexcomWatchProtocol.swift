//
//  DexcomWatchProtocol.swift
//  xDrip
//
//  Created by Paul Plant on 13/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CommonCrypto

enum DexcomWatchProtocol {
    /// Dexcom counters are little-endian. Check bounds before indexing notification bytes.
    static func uint32(_ data: Data, at index: Int) -> UInt32? {
        guard index >= 0, data.count >= index + 4 else { return nil }
        return (0..<4).reduce(0) { $0 | UInt32(data[index + $1]) << (8 * $1) }
    }

}

/// G6 authentication and packet checks shared by the phone and Watch.
enum DexcomG6WatchProtocol {
    /// G6 challenges use the existing transmitter-ID key and duplicated eight-byte challenge.
    /// This implements authentication only. Watch collection never starts/stops the sensor.
    static func challengeHash(transmitterID: String, challenge: Data) -> Data? {
        guard transmitterID.utf8.count == 6, challenge.count == 8,
              let key = "00\(transmitterID)00\(transmitterID)".data(using: .utf8) else { return nil }
        let input = challenge + challenge
        var output = [UInt8](repeating: 0, count: 16)
        var moved = 0
        let result = key.withUnsafeBytes { keyBytes in
            input.withUnsafeBytes { inputBytes in
                CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode),
                        keyBytes.baseAddress, key.count, nil, inputBytes.baseAddress, input.count,
                        &output, output.count, &moved)
            }
        }
        return result == kCCSuccess ? Data(output.prefix(8)) : nil
    }

    static func command(_ opcode: UInt8) -> Data {
        let data = Data([opcode])
        let crc = checksum(data)
        return data + Data([UInt8(truncatingIfNeeded: crc), UInt8(truncatingIfNeeded: crc >> 8)])
    }

    static func checksum(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0
        for byte in data {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 { crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1 }
        }
        return crc
    }

    /// The final two bytes are the CRC in little-endian order, separate from the payload.
    static func hasValidCRC(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        return checksum(Data(data.dropLast(2))) == UInt16(data[data.count - 2]) | UInt16(data[data.count - 1]) << 8
    }


    static func glucose(_ data: Data) -> (seconds: UInt32, value: Double, state: UInt8)? {
        guard data.count >= 16, data.first == 0x31 || data.first == 0x4f, hasValidCRC(data),
              let seconds = DexcomWatchProtocol.uint32(data, at: 6) else { return nil }
        return (seconds, Double(UInt16(data[10]) | UInt16(data[11] & 0x0f) << 8), data[12])
    }
}

/// The Watch's primary G7 collector uses the same 0x4E packet layout as the iPhone parser.
/// Returning a complete reading here keeps family and session checks common to both devices.
enum DexcomG7WatchProtocol {
    /// G7 includes the reading's age, allowing measurement time to remain distinct from BLE
    /// receipt. Family/session validation below prevents cached or unusable values being shown.
    static func reading(_ data: Data, configuration: DirectWatchConfiguration, receivedAt: Date = .now) -> DirectWatchReading? {
        guard configuration.transmitterFamily == .g7, data.count >= 19,
              data[0] == 0x4E, data[1] == 0 else { return nil }
        let transmitterTime = DexcomWatchProtocol.uint32(data, at: 2) ?? 0
        let age = UInt32(data[10]) | UInt32(data[11]) << 8
        let raw = UInt16(data[12]) | UInt16(data[13]) << 8
        guard transmitterTime >= age, raw != 0xFFFF else { return nil }
        let sensorAge = transmitterTime - age
        let measuredAt = receivedAt.addingTimeInterval(-Double(age))
        let reading = DirectWatchReading(transmitterID: configuration.transmitterID,
                                     sensorStartCounter: 1,
                                     sensorStartDate: measuredAt.addingTimeInterval(-Double(sensorAge)),
                                     transmitterSeconds: sensorAge, measuredAt: measuredAt,
                                     mgDl: Double(raw & 0x0FFF), state: data[14], family: .g7)
        return reading.belongs(to: configuration, now: receivedAt) ? reading : nil
    }
}
