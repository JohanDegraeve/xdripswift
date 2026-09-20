//
//  DexcomG7GlucoseDataRxMessage.swift
//  xdrip
//
//  Created by Johan Degraeve on 19/02/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// Decodes the 19-byte `0x4E` response requested directly by primary mode.
///
/// This packet normally contains the current reading, but its second byte is an independent
/// response status. A failed sensor can return a non-zero status together with a structurally valid
/// copy of its last reading. The parser therefore preserves both pieces of information and leaves
/// the publication decision to `CGMG7Transmitter`.
public struct G7GlucoseMessage {
    /// `0x00` identifies a current glucose response. Dexcom can also return a complete 19-byte
    /// frame with a non-zero status and the last cached glucose. Keep the status separate so the
    /// caller can report the sensor state without publishing that stale value as a new reading.
    let responseStatus: UInt8

    /// Wall-clock date reconstructed by subtracting the packet age from receipt time.
    let timeStamp: Date

    /// Glucose value after removing Dexcom's flag bits, expressed in mg/dL.
    let calculatedValue: Double

    /// Sensor algorithm state used by status, Activity Log, alert, and banner consumers.
    let algorithmStatus: DexcomAlgorithmState

    /// Seconds between sensor start and the reported reading.
    let sensorAge: TimeInterval

    /// Optional raw glucose after its upper flag bits have been removed.
    private let glucose: UInt16?

    /// Optional transmitter prediction. It is decoded for packet completeness but not published.
    private let predicted: UInt16?

    /// Timestamp of the reading in seconds since sensor start.
    let transmitterTime: UInt32

    /// Packet sequence number retained for protocol completeness.
    private let sequence: UInt16

    /// Signed Dexcom trend value in mg/dL per minute, or nil when the sentinel is present.
    private let trend: Double?

    /// Dexcom display-only flag decoded from the final calibration and flags byte.
    private let glucoseIsDisplayOnly: Bool

    init?(data: Data) {
        //    0  1  2 3 4 5  6 7  8  9 10 11 1213 14 15 1617 18
        //         TTTTTTTT SQSQ       AG    BGBG SS TR PRPR C
        // 0x4e 00 d5070000 0900 00 01 05 00 6100 06 01 ffff 0e
        // TTTTTTTT = timestamp
        //     SQSQ = sequence
        //       AG = age Amount of time elapsed (seconds) from sensor reading to BLE comms
        //     BGBG = glucose
        //       SS = algorithm state
        //       TR = trend
        //     PRPR = predicted
        //        C = calibration

        guard data.count >= 19, data.starts(with: .glucoseG6Tx) else {
            return nil
        }

        // Parse the response status before the glucose fields. A non-zero value does not make the
        // frame malformed, so rejecting it here would hide the algorithm failure state from the UI
        // and diagnostics.
        responseStatus = data[1]

        // The sequence is not needed by the current delivery pipeline, but parsing its exact field
        // documents the packet layout and keeps later diagnostics from guessing at byte offsets.
        sequence = data[6 ..< 8].to(UInt16.self)

        // This is the reading time measured from sensor start, not the age of the BLE packet.
        transmitterTime = data[2 ..< 6].toInt()

        // Time between the reading and receipt of the BLE message. This is a two-byte field. The
        // high byte becomes important for the old cached record returned after a sensor failure.
        let messageAge = data[10 ..< 12].to(UInt16.self)

        // Sensor age combines the reading's relative timestamp with the delay before transmission.
        sensorAge = TimeInterval(transmitterTime) + TimeInterval(messageAge)

        // Convert the packet delay into the wall-clock time used by Core Data and chart delivery.
        timeStamp = Date().addingTimeInterval(-TimeInterval(messageAge))

        // The upper bits carry flags. Mask them away only after recognising 0xFFFF as Dexcom's
        // unavailable sentinel. A cached value in a non-zero-status frame is still decoded for
        // diagnostics, although the transmitter layer will not publish it.
        let glucoseData = data[12 ..< 14].to(UInt16.self)
        if glucoseData != 0xFFFF {
            glucose = glucoseData & 0xFFF
            glucoseIsDisplayOnly = (data[18] & 0x10) > 0
            calculatedValue = Double(glucose!)
        } else {
            glucose = nil
            glucoseIsDisplayOnly = false
            calculatedValue = 0.0
        }

        // Prediction uses the same flag-bit layout and `0xFFFF` unavailable sentinel as glucose.
        let predictionData = data[16 ..< 18].to(UInt16.self)
        if predictionData != 0xFFFF {
            predicted = predictionData & 0xFFF
        } else {
            predicted = nil
        }

        // Preserve an unknown algorithm byte as the established neutral state rather than failing
        // the whole glucose packet and losing an otherwise valid reading.
        if let receivedState = DexcomAlgorithmState(rawValue: data[14]) {
            algorithmStatus = receivedState

        } else {
            algorithmStatus = DexcomAlgorithmState.None
        }

        // Trend is a signed value in tenths. `0x7F` means that no trend is currently available.
        if data[15] == 0x7F {
            trend = nil
        } else {
            trend = Double(Int8(bitPattern: data[15])) / 10
        }
    }
}

/// The official Dexcom app uses the older `0x31` glucose response while it owns the G7
/// connection. Its transmitter timestamp is combined with the following `0x25` response so
/// coexistence can recover the reading date and sensor age without sending another command.
///
/// This intentionally contains no pairing or authentication logic. It is merely the passive data
/// half observed after the other app has already established an authenticated session.
struct G7CoexistenceGlucoseMessage {
    /// Glucose value after removing the upper Dexcom flag bits.
    let calculatedValue: Double

    /// Sensor algorithm state observed from the other app's authenticated data stream.
    let algorithmStatus: DexcomAlgorithmState

    /// Relative reading timestamp that must be joined with a `0x25` clock response.
    let transmitterTime: UInt32

    init?(data: Data) {
        guard data.count >= 16, data.starts(with: .glucoseRx) else { return nil }

        // Unlike 0x4E, this packet does not carry the sensor-start reference needed to calculate
        // age. Preserve its relative transmitter time and let the caller join it with 0x25.
        calculatedValue = Double(data[10 ..< 12].to(UInt16.self) & 0x0FFF)
        algorithmStatus = DexcomAlgorithmState(rawValue: data[12]) ?? .None
        transmitterTime = data[6 ..< 10].to(UInt32.self)
    }
}
