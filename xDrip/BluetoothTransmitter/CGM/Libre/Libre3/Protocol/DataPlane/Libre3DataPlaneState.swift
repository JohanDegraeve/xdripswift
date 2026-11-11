//
//  Libre3DataPlaneState.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/DataPlane/Libre3DataPlaneState.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

enum Libre3DataPlaneStateUpdate: Equatable, Sendable {
    case patchStatus(Libre3PatchStatus, lifecycle: Libre3SensorLifecycle)
    case realtimeGlucose(Libre3RealtimeGlucoseReading, assessment: Libre3GlucoseQualityAssessment)
    case historicalReadingPage(Libre3HistoricalReadingPage)
    case clinicalReadingRecord(Libre3ClinicalReadingRecord)
    case raw(Libre3DataPlaneDecodedPacket)
}

struct Libre3DataPlaneState: Equatable, Sendable {
    let warmupDurationMinutes: Int
    let wearDurationMinutes: Int?
    private(set) var latestPatchStatus: Libre3PatchStatus?
    private(set) var latestLifecycle: Libre3SensorLifecycle?
    private(set) var latestRealtimeGlucose: Libre3RealtimeGlucoseReading?
    private(set) var latestQualityAssessment: Libre3GlucoseQualityAssessment?
    private(set) var lastAcceptedGlucoseLifeCount: UInt16?
    private(set) var lastAcceptedGlucoseMgDL: UInt16?
    private(set) var historicalBackfill: Libre3HistoricalBackfill

    init(
        warmupDurationMinutes: Int = Libre3SensorLifecycle.defaultWarmupDurationMinutes,
        wearDurationMinutes: Int? = nil,
        latestPatchStatus: Libre3PatchStatus? = nil,
        lastAcceptedGlucoseLifeCount: UInt16? = nil,
        lastAcceptedGlucoseMgDL: UInt16? = nil,
        historicalBackfill: Libre3HistoricalBackfill = Libre3HistoricalBackfill()
    ) {
        self.warmupDurationMinutes = max(0, warmupDurationMinutes)
        self.wearDurationMinutes = wearDurationMinutes.map { max(0, $0) }
        self.latestPatchStatus = latestPatchStatus
        self.latestLifecycle = latestPatchStatus.map {
            $0.lifecycle(
                warmupDurationMinutes: max(0, warmupDurationMinutes),
                wearDurationMinutes: wearDurationMinutes.map { max(0, $0) }
            )
        }
        self.latestRealtimeGlucose = nil
        self.latestQualityAssessment = nil
        self.lastAcceptedGlucoseLifeCount = lastAcceptedGlucoseLifeCount
        self.lastAcceptedGlucoseMgDL = lastAcceptedGlucoseMgDL
        self.historicalBackfill = historicalBackfill
    }

    /// Seed reconnect state from persisted sensor state. When `warmup`/`wear`
    /// are not supplied, fall back to the sensor's persisted cycle (captured at
    /// pairing) and only then to the assumed default, so reconnects reflect the
    /// sensor's reported warmup/wear without re-scanning NFC.
    init(
        sensorState: Libre3SensorState,
        warmupDurationMinutes: Int? = nil,
        wearDurationMinutes: Int? = nil,
        latestPatchStatus: Libre3PatchStatus? = nil,
        historicalBackfill: Libre3HistoricalBackfill = Libre3HistoricalBackfill()
    ) {
        self.init(
            warmupDurationMinutes: warmupDurationMinutes
                ?? sensorState.warmupDurationMinutes
                ?? Libre3SensorLifecycle.defaultWarmupDurationMinutes,
            wearDurationMinutes: wearDurationMinutes ?? sensorState.wearDurationMinutes,
            latestPatchStatus: latestPatchStatus,
            lastAcceptedGlucoseLifeCount: sensorState.lastGlucoseLifeCount,
            lastAcceptedGlucoseMgDL: sensorState.lastGlucoseMgDL,
            historicalBackfill: historicalBackfill
        )
    }

    /// Seed the data-plane state with warmup/wear durations taken from the NFC
    /// patch info, so lifecycle reflects the sensor's reported cycle rather
    /// than the assumed defaults.
    init(
        patchInfo: Libre3NFCPatchInfo,
        latestPatchStatus: Libre3PatchStatus? = nil,
        lastAcceptedGlucoseLifeCount: UInt16? = nil,
        lastAcceptedGlucoseMgDL: UInt16? = nil,
        historicalBackfill: Libre3HistoricalBackfill = Libre3HistoricalBackfill()
    ) {
        self.init(
            warmupDurationMinutes: Int(patchInfo.warmupMinutes),
            wearDurationMinutes: Int(patchInfo.wearDurationMinutes),
            latestPatchStatus: latestPatchStatus,
            lastAcceptedGlucoseLifeCount: lastAcceptedGlucoseLifeCount,
            lastAcceptedGlucoseMgDL: lastAcceptedGlucoseMgDL,
            historicalBackfill: historicalBackfill
        )
    }

    init(
        sensorState: Libre3SensorState,
        patchInfo: Libre3NFCPatchInfo,
        latestPatchStatus: Libre3PatchStatus? = nil,
        historicalBackfill: Libre3HistoricalBackfill = Libre3HistoricalBackfill()
    ) {
        self.init(
            patchInfo: patchInfo,
            latestPatchStatus: latestPatchStatus,
            lastAcceptedGlucoseLifeCount: sensorState.lastGlucoseLifeCount,
            lastAcceptedGlucoseMgDL: sensorState.lastGlucoseMgDL,
            historicalBackfill: historicalBackfill
        )
    }

    var lifecyclePhase: Libre3SensorLifecyclePhase? {
        latestLifecycle?.phase
    }

    var isInWarmup: Bool {
        latestLifecycle?.isWarmingUp ?? false
    }

    var latestSensorAttention: Libre3SensorAttention {
        latestPatchStatus?.sensorAttention ?? .none
    }

    var shouldNotifyUser: Bool {
        latestSensorAttention.shouldNotifyUser
    }

    var shouldNotifyReplaceSensor: Bool {
        latestSensorAttention.isReplaceSensor
    }

    mutating func record(_ packet: Libre3DataPlaneDecodedPacket) -> Libre3DataPlaneStateUpdate {
        switch packet.payload {
        case .patchStatus(let status):
            let lifecycle = status.lifecycle(
                warmupDurationMinutes: warmupDurationMinutes,
                wearDurationMinutes: wearDurationMinutes
            )
            latestPatchStatus = status
            latestLifecycle = lifecycle
            if let latestRealtimeGlucose {
                let assessment = latestRealtimeGlucose.currentGlucoseQualityAssessment(lifecycle: lifecycle)
                latestQualityAssessment = assessment
                recordAcceptedGlucoseIfUsable(latestRealtimeGlucose, assessment: assessment)
            }
            return .patchStatus(status, lifecycle: lifecycle)

        case .realtimeGlucose(let reading):
            let assessment = assess(reading)
            latestRealtimeGlucose = reading
            latestQualityAssessment = assessment
            recordAcceptedGlucoseIfUsable(reading, assessment: assessment)
            return .realtimeGlucose(reading, assessment: assessment)

        case .historicalReadingPage(let page):
            historicalBackfill.append(page)
            return .historicalReadingPage(page)

        case .clinicalReadingRecord(let record):
            // Pass through unchanged. Apps that want minute-resolution
            // backfill consume the record's currentGlucose at its
            // lifeCount, we don't fold clinical records into
            // historicalBackfill because the two streams have different
            // commit cadences and different per-value semantics.
            return .clinicalReadingRecord(record)

        case .raw:
            return .raw(packet)
        }
    }

    func assess(_ reading: Libre3RealtimeGlucoseReading) -> Libre3GlucoseQualityAssessment {
        reading.currentGlucoseQualityAssessment(lifecycle: latestLifecycle)
    }

    private mutating func recordAcceptedGlucoseIfUsable(
        _ reading: Libre3RealtimeGlucoseReading,
        assessment: Libre3GlucoseQualityAssessment
    ) {
        guard assessment.isUsable, let mgDL = reading.currentGlucoseMgDL else {
            return
        }
        lastAcceptedGlucoseLifeCount = reading.lifeCount
        lastAcceptedGlucoseMgDL = mgDL
    }

    var reconnectBackfillLowerBoundLifeCount: UInt16? {
        lastAcceptedGlucoseLifeCount
    }

    func reconnectBackfillCommands(
        selector: UInt8 = 0x01,
        includeClinical: Bool = true
    ) -> [Libre3PatchControlCommand] {
        guard let lifeCount = reconnectBackfillLowerBoundLifeCount else {
            return []
        }

        var commands = [
            Libre3PatchControlCommand.historicalBackfillGreaterEqual(
                lifeCount: lifeCount,
                selector: selector
            )
        ]
        if includeClinical {
            commands.append(
                Libre3PatchControlCommand.clinicalBackfillGreaterEqual(
                    lifeCount: lifeCount,
                    selector: selector
                )
            )
        }
        return commands
    }
}
