import SwiftUI

struct CalibrationReadinessReading {
    let timeStamp: Date
    let valueInMgDl: Double
}

struct CalibrationReadinessEvaluator {
    let now: Date

    func evaluate(
        hasActiveSensor: Bool,
        recentReadings: [CalibrationReadinessReading],
        noiseState: SensorNoiseState
    ) -> CalibrationReadiness {
        guard hasActiveSensor else {
            let unavailable = CalibrationReadinessCheck(level: .caution, detail: Texts_HomeView.sensorManagementNoSensor)
            return CalibrationReadiness(inRange: unavailable, stableTrend: unavailable, sensorNoise: unavailable)
        }

        return CalibrationReadiness(
            inRange: inRangeReadiness(latestReading: recentReadings.first),
            stableTrend: stableTrendReadiness(recentReadings: recentReadings),
            sensorNoise: sensorNoiseReadiness(noiseState: noiseState)
        )
    }

    private func inRangeReadiness(latestReading: CalibrationReadinessReading?) -> CalibrationReadinessCheck {
        guard let latestReading else {
            return CalibrationReadinessCheck(level: .caution, detail: Texts_HomeView.sensorManagementCalibrationNoReading)
        }

        let value = latestReading.valueInMgDl

        if value < CalibrationReadinessConstants.minimumInRangeValueInMgDl {
            return CalibrationReadinessCheck(level: .bad, detail: Texts_Common.lowStatistics)
        }
        if value < CalibrationReadinessConstants.minimumGoodValueInMgDl {
            return CalibrationReadinessCheck(level: .caution, detail: Texts_HomeView.sensorManagementCalibrationSlightlyLow)
        }
        if value > CalibrationReadinessConstants.maximumInRangeValueInMgDl {
            return CalibrationReadinessCheck(level: .bad, detail: Texts_Common.highStatistics)
        }
        if value > CalibrationReadinessConstants.maximumGoodValueInMgDl {
            return CalibrationReadinessCheck(level: .caution, detail: Texts_HomeView.sensorManagementCalibrationSlightlyHigh)
        }

        return CalibrationReadinessCheck(level: .good, detail: Texts_HomeView.sensorManagementCalibrationGood)
    }

    private func stableTrendReadiness(recentReadings: [CalibrationReadinessReading]) -> CalibrationReadinessCheck {
        guard let latestReading = recentReadings.first else {
            return CalibrationReadinessCheck(level: .caution, detail: Texts_HomeView.sensorManagementCalibrationNoTrend)
        }

        if now.timeIntervalSince(latestReading.timeStamp) > CalibrationReadinessConstants.maximumLatestReadingAge {
            return CalibrationReadinessCheck(level: .bad, detail: Texts_HomeView.sensorManagementCalibrationStale)
        }

        let readings = recentReadings
            .filter { latestReading.timeStamp.timeIntervalSince($0.timeStamp) <= CalibrationReadinessConstants.trendLookback }
            .sorted { $0.timeStamp < $1.timeStamp }

        guard readings.count >= CalibrationReadinessConstants.minimumTrendReadings,
              let firstReading = readings.first,
              let lastReading = readings.last else {
            return CalibrationReadinessCheck(level: .caution, detail: Texts_HomeView.sensorManagementNoiseCollecting)
        }

        let span = lastReading.timeStamp.timeIntervalSince(firstReading.timeStamp)
        guard span >= CalibrationReadinessConstants.minimumTrendSpan else {
            return CalibrationReadinessCheck(level: .caution, detail: Texts_HomeView.sensorManagementNoiseCollecting)
        }

        let slope = trendSlopeInMgDlPerMinute(readings: readings)
        let endpointSlope = (lastReading.valueInMgDl - firstReading.valueInMgDl) / (span / 60)
        let effectiveSlope = abs(slope) > abs(endpointSlope) ? slope : endpointSlope
        let absoluteSlope = abs(effectiveSlope)

        if absoluteSlope <= CalibrationReadinessConstants.stableTrendSlopeLimit {
            return CalibrationReadinessCheck(level: .good, detail: Texts_HomeView.sensorManagementCalibrationStable)
        }

        let detail = trendDetail(for: effectiveSlope)
        if absoluteSlope <= CalibrationReadinessConstants.cautionTrendSlopeLimit {
            return CalibrationReadinessCheck(level: .caution, detail: detail)
        }

        return CalibrationReadinessCheck(level: .bad, detail: detail)
    }

    private func trendSlopeInMgDlPerMinute(readings: [CalibrationReadinessReading]) -> Double {
        guard let firstDate = readings.first?.timeStamp else { return 0 }

        let points = readings.map { reading in
            (x: reading.timeStamp.timeIntervalSince(firstDate) / 60, y: reading.valueInMgDl)
        }
        let meanX = points.map(\.x).reduce(0, +) / Double(points.count)
        let meanY = points.map(\.y).reduce(0, +) / Double(points.count)
        let numerator = points.reduce(0) { $0 + (($1.x - meanX) * ($1.y - meanY)) }
        let denominator = points.reduce(0) { $0 + pow($1.x - meanX, 2) }

        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    private func trendDetail(for slope: Double) -> String {
        if slope < 0 {
            return abs(slope) > CalibrationReadinessConstants.cautionTrendSlopeLimit
                ? Texts_HomeView.sensorManagementCalibrationFallingFast
                : Texts_HomeView.sensorManagementCalibrationFalling
        }
        return slope > CalibrationReadinessConstants.cautionTrendSlopeLimit
            ? Texts_HomeView.sensorManagementCalibrationRisingFast
            : Texts_HomeView.sensorManagementCalibrationRising
    }

    private func sensorNoiseReadiness(noiseState: SensorNoiseState) -> CalibrationReadinessCheck {
        switch noiseState {
        case .low:
            return CalibrationReadinessCheck(level: .good, detail: Texts_HomeView.sensorManagementNoiseLow)
        case .collecting:
            return CalibrationReadinessCheck(level: .caution, detail: Texts_HomeView.sensorManagementNoiseCollecting)
        case .elevated:
            return CalibrationReadinessCheck(level: .caution, detail: Texts_HomeView.sensorManagementNoiseElevated)
        case .veryHigh:
            return CalibrationReadinessCheck(level: .bad, detail: Texts_HomeView.sensorManagementNoiseVeryHigh)
        case .extreme:
            return CalibrationReadinessCheck(level: .bad, detail: Texts_HomeView.sensorManagementNoiseExtreme)
        case .flatlineSuspected:
            return CalibrationReadinessCheck(level: .bad, detail: Texts_HomeView.sensorManagementCalibrationFlatline)
        }
    }
}

enum CalibrationReadinessLevel {
    case good
    case caution
    case bad

    var color: Color {
        switch self {
        case .good:
            return Color(.systemGreen)
        case .caution:
            return Color(.systemOrange)
        case .bad:
            return Color(.systemRed)
        }
    }

    var systemImage: String {
        switch self {
        case .good:
            return "checkmark.circle.fill"
        case .caution:
            return "exclamationmark.triangle.fill"
        case .bad:
            return "xmark.octagon.fill"
        }
    }

    var traceValue: String {
        switch self {
        case .good:
            return "good"
        case .caution:
            return "caution"
        case .bad:
            return "bad"
        }
    }
}

struct CalibrationReadinessCheck {
    let level: CalibrationReadinessLevel
    let detail: String

    var traceDescription: String {
        level.traceValue + " (" + detail + ")"
    }
}

struct CalibrationReadiness {
    let inRange: CalibrationReadinessCheck
    let stableTrend: CalibrationReadinessCheck
    let sensorNoise: CalibrationReadinessCheck

    var summary: String {
        let levels = [inRange.level, stableTrend.level, sensorNoise.level]
        if levels.contains(.bad) { return Texts_HomeView.sensorManagementCalibrationReadinessBad }
        if levels.contains(.caution) { return Texts_HomeView.sensorManagementCalibrationReadinessCaution }
        return Texts_HomeView.sensorManagementCalibrationReadinessGood
    }
}

enum CalibrationReadinessConstants {
    static let trendLookback: TimeInterval = 30 * 60
    static let minimumTrendSpan: TimeInterval = 20 * 60
    static let maximumLatestReadingAge: TimeInterval = 15 * 60
    static let minimumTrendReadings = 5
    static let stableTrendSlopeLimit = 1.0
    static let cautionTrendSlopeLimit = 2.0
    static let minimumInRangeValueInMgDl = 70.0
    static let minimumGoodValueInMgDl = 80.0
    static let maximumGoodValueInMgDl = 170.0
    static let maximumInRangeValueInMgDl = 180.0
}
