//
//  Libre3ClinicalReadingRecord.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/DataPlane/ClinicalReadingRecord.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

/// Decoded clinical-stream record (0x08981ab8). Distinct from
/// `Libre3HistoricalReadingPage`: clinical pages are NOT six samples at
/// 5-minute stride , each page is a single time-point record with seven
/// 16-bit fields, emitted once per minute while the sensor is connected.
///
/// The clinical stream mirrors two values from the realtime stream at the
/// same sensor life count: word[5] is the current-minute glucose, and word[6]
/// is the most recent 5-minute committed historical glucose. That fixes the
/// currently modeled field mapping:
///
/// | word | bytes | meaning                                              |
/// | ---- | ----- | ---------------------------------------------------- |
/// |  0   | 0–1   | `lifeCount` , current minute (page emitted per minute)|
/// |  1   | 2–3   | raw sensor channel (rises with glucose)              |
/// |  2   | 4–5   | raw sensor channel                                   |
/// |  3   | 6–7   | raw sensor channel (high byte pinned 0x0e, temp?)    |
/// |  4   | 8–9   | reserved / zero (only 0x0000 observed)               |
/// |  5   | 10–11 | current-minute glucose , equals realtime current     |
/// |  6   | 12–13 | most recent 5-min committed glucose , equals realtime|
/// |      |       | embedded historical                                  |
///
/// `currentGlucoseRaw` (word[5]) is the same per-minute value the
/// realtime stream emits, keyed at this record's own `lifeCount` (no
/// offset). `historicGlucoseRaw` (word[6]) is the same 5-minute committed
/// value the realtime stream carries as its embedded historical, its
/// lifeCount is the most recent 5-minute boundary, which this record does
/// not itself carry (the realtime frame's `historicalLifeCount` does).
///
/// **5-min-boundary finalization for word[6]:** the historic value steps
/// forward at `lifeCount ≡ 2 (mod 5)` and lands on the boundary
/// `lifeCount - 17` (snapped down to a multiple of 5). The 17-minute lag is
/// modeled as a protocol parameter paired with the 5-minute historical
/// interval. Even so, authoritative pairing of `historicGlucoseRaw` to a
/// lifeCount should prefer the realtime frame's own `historicalLifeCount`
/// field when available, the helper below is provided for cases where only
/// the clinical record is in hand.
///
/// **Gap-fill behavior:** the clinical
/// CCCD buffers records sensor-side while the host is disconnected and
/// replays the buffered window in a burst on resubscribe. This makes the
/// clinical stream the currently modeled way to recover minute-resolution
/// glucose for a disconnect window. Historical paged backfill commits only at
/// 5-minute boundaries and lags current by about 17 minutes. Apps that care
/// about gap-fill should subscribe to the clinical CCCD and forward
/// `currentGlucose` keyed at `lifeCount`, deduping against samples already
/// received via the realtime stream.
///
/// Apps integrating this should consume `currentGlucose` keyed by
/// `lifeCount` (offset 0). `historicGlucoseRaw` is redundant with the
/// realtime embedded historical and should not be keyed at this
/// record's `lifeCount` , use `historicLifeCountEstimate` (or the
/// realtime frame's `historicalLifeCount`) instead.
struct Libre3ClinicalReadingRecord: Equatable, Sendable {
    static let plaintextSize = 14

    /// LifeCount of this clinical record (per-minute granularity).
    let lifeCount: UInt16

    /// Raw sensor channels (words 1–3). Not glucose, exposed for
    /// diagnostics. Word 3's high byte is pinned at 0x0e and is the
    /// suspected temperature channel.
    let rawSensorWord1: UInt16
    let rawSensorWord2: UInt16
    let rawSensorWord3: UInt16

    /// Word 4 , only 0x0000 observed.
    let reservedWord: UInt16

    /// Raw 16-bit current-minute glucose value, keyed at `lifeCount`.
    /// Equals the realtime stream's current value at the same lifeCount.
    /// Feed to `Libre3GlucoseValueStatus(rawSensorValue:)` for mg/dL.
    let currentGlucoseRaw: UInt16

    /// Raw 16-bit most-recent 5-minute committed glucose value. Equals
    /// the realtime stream's embedded historical value, its lifeCount is
    /// the most recent 5-minute boundary, NOT this record's `lifeCount`.
    let historicGlucoseRaw: UInt16

    init(plaintext: Data) throws {
        guard plaintext.count == Self.plaintextSize else {
            throw Libre3ClinicalReadingRecordError.wrongPlaintextSize(plaintext.count)
        }
        let words = stride(from: 0, to: plaintext.count, by: 2).map { offset -> UInt16 in
            UInt16(plaintext[offset]) | (UInt16(plaintext[offset + 1]) << 8)
        }
        self.lifeCount = words[0]
        self.rawSensorWord1 = words[1]
        self.rawSensorWord2 = words[2]
        self.rawSensorWord3 = words[3]
        self.reservedWord = words[4]
        self.currentGlucoseRaw = words[5]
        self.historicGlucoseRaw = words[6]
    }

    var currentGlucose: Libre3GlucoseValueStatus {
        Libre3GlucoseValueStatus(rawSensorValue: currentGlucoseRaw)
    }

    var currentGlucoseMgDL: UInt16? {
        currentGlucose.displayMgDL
    }

    var historicGlucose: Libre3GlucoseValueStatus {
        Libre3GlucoseValueStatus(rawSensorValue: historicGlucoseRaw)
    }

    var historicGlucoseMgDL: UInt16? {
        historicGlucose.displayMgDL
    }

    /// Best-effort estimate of the `lifeCount` that `historicGlucoseRaw`
    /// represents: snap to the last 5-min boundary at `lifeCount − 17`.
    /// The 17-count offset is Abbott's `HISTORIC_POINT_LATENCY` and the
    /// 5-count snap is `LIBRE3_HISTORIC_LIFECOUNT_INTERVAL`, both fixed
    /// constants in `MSLibre3Constants`. Returns `nil` when the
    /// arithmetic underflows (e.g. very early in sensor life). Prefer
    /// the realtime frame's own `historicalLifeCount` field when you
    /// have both records in hand , that's authoritative, this helper
    /// only exists for callers consuming clinical records in isolation.
    var historicLifeCountEstimate: UInt16? {
        let lagged = Int(lifeCount) - 17
        guard lagged >= 0 else { return nil }
        return UInt16(lagged - (lagged % 5))
    }
}

enum Libre3ClinicalReadingRecordError: Error, Equatable {
    case wrongPlaintextSize(Int)
}
