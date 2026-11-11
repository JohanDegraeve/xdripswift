//
//  Libre3DataPlaneDecoder.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

// Adapted from RoundWhiteDiscKit.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/DataPlane/DataPlaneDecoder.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

enum Libre3DataPlaneChannel: String, CaseIterable, Sendable {
    case patchControl
    case patchStatus
    case glucoseData
    case historicData
    case eventLog
    case clinicalData
    case factoryData

    init?(uuidString: String) {
        let lower = uuidString.lowercased()
        switch lower {
        case _ where lower.hasPrefix("08981338"):
            self = .patchControl
        case _ where lower.hasPrefix("08981482"):
            self = .patchStatus
        case _ where lower.hasPrefix("0898177a"):
            self = .glucoseData
        case _ where lower.hasPrefix("0898195a"):
            self = .historicData
        case _ where lower.hasPrefix("08981bee"):
            self = .eventLog
        case _ where lower.hasPrefix("08981ab8"):
            self = .clinicalData
        case _ where lower.hasPrefix("08981d24"):
            self = .factoryData
        default:
            return nil
        }
    }

    var preferredInboundKind: Libre3DataPlanePacketKind? {
        switch self {
        case .patchStatus:
            return .kind2
        case .glucoseData:
            return .kind3
        case .historicData:
            return .kind4
        case .patchControl, .eventLog, .clinicalData, .factoryData:
            return nil
        }
    }
}

enum Libre3DataPlaneDecodedPayload: Equatable, Sendable {
    case realtimeGlucose(Libre3RealtimeGlucoseReading)
    case patchStatus(Libre3PatchStatus)
    case historicalReadingPage(Libre3HistoricalReadingPage)
    case clinicalReadingRecord(Libre3ClinicalReadingRecord)
    case raw(Data)
}

struct Libre3DataPlaneDecodedPacket: Equatable, Sendable {
    let channel: Libre3DataPlaneChannel
    let frame: Libre3DataFrame
    let kind: Libre3DataPlanePacketKind
    let preferredKind: Libre3DataPlanePacketKind?
    let plaintext: Data
    let payload: Libre3DataPlaneDecodedPayload

    var usedPreferredKind: Bool {
        preferredKind == nil || preferredKind == kind
    }
}

struct Libre3DataPlaneDecoder: Sendable {
    let crypto: Libre3DataPlaneCrypto

    init(crypto: Libre3DataPlaneCrypto) {
        self.crypto = crypto
    }

    func decrypt(frame: Libre3DataFrame, channel: Libre3DataPlaneChannel) throws -> Libre3DataPlaneDecodedPacket {
        let preferredKind = channel.preferredInboundKind
        let result: Libre3DataPlaneDecryptResult
        if let preferredKind,
           let plaintext = try? crypto.decrypt(frame, kind: preferredKind) {
            result = Libre3DataPlaneDecryptResult(kind: preferredKind, plaintext: plaintext)
        } else {
            result = try crypto.decryptTryingAllKinds(frame)
        }

        return Libre3DataPlaneDecodedPacket(
            channel: channel,
            frame: frame,
            kind: result.kind,
            preferredKind: preferredKind,
            plaintext: result.plaintext,
            payload: Self.decodePayload(channel: channel, plaintext: result.plaintext)
        )
    }

    private static func decodePayload(channel: Libre3DataPlaneChannel, plaintext: Data) -> Libre3DataPlaneDecodedPayload {
        switch channel {
        case .glucoseData:
            if let reading = try? Libre3RealtimeGlucoseReading(plaintext: plaintext) {
                return .realtimeGlucose(reading)
            }
        case .patchStatus:
            if let status = try? Libre3PatchStatus(plaintext: plaintext) {
                return .patchStatus(status)
            }
        case .historicData:
            if let page = try? Libre3HistoricalReadingPage(plaintext: plaintext) {
                return .historicalReadingPage(page)
            }
        case .clinicalData:
            // Clinical pages have a different layout than historical
            // (single time-point record, not 6 samples at 5-min stride).
            // See Libre3ClinicalReadingRecord for field semantics.
            if let record = try? Libre3ClinicalReadingRecord(plaintext: plaintext) {
                return .clinicalReadingRecord(record)
            }
        case .patchControl, .eventLog, .factoryData:
            break
        }
        return .raw(plaintext)
    }
}

/// Reassembles post-auth notification bodies before `Libre3DataFrame.parse`.
///
/// `glucoseData` readings arrive as a 15-byte prefix followed by a 20-byte
/// suffix. The suffix contains the normal data-plane 2-byte sequence trailer, so
/// the two notifications must be concatenated before CCM tag verification.
final class Libre3DataPlaneNotificationAssembler: @unchecked Sendable {
    private let lock = NSLock()
    private var glucosePrefix: Data?

    init() {}

    func feed(fragment: Data, channel: Libre3DataPlaneChannel) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard channel == .glucoseData else {
            return fragment
        }

        if let prefix = glucosePrefix {
            glucosePrefix = nil
            if fragment.count == 20 { return prefix + fragment }
            // A new prefix replaces a lost suffix, never join arbitrary lengths.
            if fragment.count == 15 { glucosePrefix = fragment }
            return nil
        }
        if fragment.count == 15 {
            glucosePrefix = fragment
            return nil
        }
        return fragment.count == 35 ? fragment : nil
    }

    func reset() {
        lock.lock()
        glucosePrefix = nil
        lock.unlock()
    }
}
