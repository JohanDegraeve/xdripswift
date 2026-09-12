//
//  TherapyMetrics.swift
//  xdrip
//
//  Created by Paul Plant on 12/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Display-only therapy amounts travel independently of pump and AID operating state.
enum TherapyMetricSource: String, Codable, Hashable, Sendable {
    case local, nightscout, careLink
}

enum TherapyMetricUnavailableReason: String, Codable, Hashable, Sendable {
    case disabled, noTreatments, missingExternalData, stale, readFailed, invalidSettings
}

struct TherapyMetricState: Codable, Hashable, Sendable {
    var amount: Double?
    var source: TherapyMetricSource
    var referenceDate: Date
    var expiresAt: Date?
    var visibilityDeadline: Date?
    var reason: TherapyMetricUnavailableReason?

    func isVisible(at date: Date = .now) -> Bool {
        if let visibilityDeadline, date >= visibilityDeadline { return false }
        return reason != .disabled && reason != .noTreatments
    }

    func value(at date: Date = .now) -> Double? {
        guard isVisible(at: date), reason == nil,
              date >= referenceDate.addingTimeInterval(-60),
              expiresAt.map({ date < $0 }) ?? false else { return nil }
        return amount.flatMap { $0.isFinite ? $0 : nil }
    }

    func accessibilityName(isIOB: Bool) -> String {
        guard source == .local else { return isIOB ? "IOB" : "COB" }
        return NSLocalizedString(isIOB ? "therapy.estimatedIOB" : "therapy.estimatedCOB", tableName: "Common",
            value: isIOB ? "Estimated insulin on board" : "Estimated carbohydrates on board", comment: "Local therapy estimate")
    }

    func formatted(isIOB: Bool, at date: Date = .now) -> String {
        "\(number(isIOB: isIOB, at: date)) \(isIOB ? "U" : "g")"
    }

    func number(isIOB: Bool, at date: Date = .now) -> String {
        guard let value = value(at: date) else { return "-" }
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = isIOB ? 2 : 0
        formatter.minimumFractionDigits = 0
        let text = formatter.string(from: NSNumber(value: value)) ?? "-"
        return text
    }
}

struct TherapyMetricsSnapshot: Codable, Hashable, Sendable {
    var iob: TherapyMetricState
    var cob: TherapyMetricState
    var hasVisibleMetrics: Bool { iob.isVisible() || cob.isVisible() }

    static func external(_ status: AIDStatus?, at date: Date = .now) -> Self {
        let source: TherapyMetricSource = status?.style == .loop ? .nightscout : .careLink
        func metric(_ amount: Double?, supported: Bool) -> TherapyMetricState {
            // Invalid imported values must not make the entire companion payload unencodable.
            let amount = amount.flatMap { $0.isFinite ? $0 : nil }
            let fresh = status?.presentation(referenceDate: date).hasFreshData == true
            return TherapyMetricState(amount: amount, source: source,
                referenceDate: status?.statusUpdatedAt ?? date,
                expiresAt: status?.statusUpdatedAt?.addingTimeInterval(TherapyModelSettings.freshnessInterval),
                reason: !supported ? .disabled : !fresh ? .stale : amount == nil ? .missingExternalData : nil)
        }
        return Self(iob: metric(status?.iob, supported: status != nil),
                    cob: metric(status?.cob, supported: status?.supportsCOB == true))
    }
}

extension UserDefaults {
    /// Therapy curves are shown by default. An explicit user choice is preserved.
    var showIOBCOB: Bool {
        get {
            if object(forKey: "showIOBCOB") != nil { return bool(forKey: "showIOBCOB") }
            return true
        }
        set { set(newValue, forKey: "showIOBCOB") }
    }
}

/// Named display-model presets. Peaks follow Trio's documented rapid/ultra-rapid
/// defaults and its Lyumjev guidance. All presets use the shared DIA below.
/// https://triodocs.org/configuration/settings/algorithm/additionals/
enum TherapyInsulinPreset: String, CaseIterable {
    case novoRapid = "NovoRapid", fiasp = "Fiasp", lyumjev = "Lyumjev"
    var peak: Double {
        switch self {
        case .novoRapid: return 75
        case .fiasp: return 55
        case .lyumjev: return 45
        }
    }
    static func nearest(to peak: Double) -> Self {
        guard peak.isFinite else { return .novoRapid }
        return allCases.min { abs($0.peak - peak) < abs($1.peak - peak) } ?? .novoRapid
    }
}

struct TherapyModelSettings: Equatable, Sendable {
    // Match Trio's 10-hour DIA so the exponential model includes insulin's long, low-level tail.
    // https://triodocs.org/configuration/settings/algorithm/additionals/#duration-of-insulin-action
    static let defaultInsulinDuration = 10.0 * 60
    var insulinDuration = Self.defaultInsulinDuration
    var insulinPeak = 75.0
    var carbDuration = 240.0
    static let carbDurationChoices = [120.0, 180.0, 240.0, 300.0, 360.0, 420.0, 480.0]
    static func supportedCarbDuration(_ duration: Double) -> Double {
        guard duration.isFinite else { return 240 }
        return carbDurationChoices.min { abs($0 - duration) < abs($1 - duration) } ?? 240
    }
    static let carbDelay = 10.0
    // Historical interpolation only. Current values retain the 17-minute freshness limit.
    static let externalChartJoinInterval: TimeInterval = 32 * 60
    static let freshnessInterval: TimeInterval = 17 * 60
    static let visibilityInterval: TimeInterval = 24 * 60 * 60
    var validInsulin: Bool {
        insulinDuration.isFinite && insulinPeak.isFinite &&
        (180...Self.defaultInsulinDuration).contains(insulinDuration) && (35...120).contains(insulinPeak) &&
        insulinPeak * 2 < insulinDuration && insulinDuration.truncatingRemainder(dividingBy: 30) == 0 &&
        insulinPeak.truncatingRemainder(dividingBy: 5) == 0
    }
    var validCarbs: Bool {
        carbDuration.isFinite && (60...480).contains(carbDuration) && carbDuration.truncatingRemainder(dividingBy: 30) == 0
    }

    init(defaults: UserDefaults) {
        insulinDuration = Self.defaultInsulinDuration
        insulinPeak = TherapyInsulinPreset.nearest(to: defaults.object(forKey: "localInsulinPeak") as? Double ?? 75).peak
        carbDuration = Self.supportedCarbDuration(defaults.object(forKey: "localCarbDuration") as? Double ?? 240)
    }
    init() {}
}

/// Pure functions use minutes continuously, unlike oref0's rounded-minute input.
/// OpenAPS/oref0 88cf032aa74ff25f69464a7d9cd601ee3940c0b3, lib/iob/calculate.js (MIT).
/// Original exponential formula: https://github.com/LoopKit/Loop/issues/388#issuecomment-317938473
/// LoopKit 421c1a256e76a7166ab2848cedba53162d34fda1, CarbKit/CarbMath.swift (MIT).
/// Copyright (c) 2016 Nathan Racklyeft. See docs/local-therapy-metrics.md for notices.
enum TherapyCalculations {
    static func insulinRemaining(units: Double, minutes: Double, duration: Double, peak: Double) -> Double {
        guard units.isFinite, units > 0, minutes.isFinite, duration.isFinite, peak.isFinite,
              duration > 0, peak > 0, peak * 2 < duration, minutes >= 0, minutes < duration else { return 0 }
        if minutes == 0 { return units }
        let tau = peak * (1 - peak / duration) / (1 - 2 * peak / duration)
        let a = 2 * tau / duration
        let scale = 1 / (1 - a + (1 + a) * exp(-duration / tau))
        // Expanded form avoids division by (1-a), including the removable singularity at a=1.
        let polynomial = minutes * minutes / (tau * duration) - (1 - a) * (minutes / tau + 1)
        let fraction = 1 - scale * (polynomial * exp(-minutes / tau) + 1 - a)
        return min(units, max(0, units * fraction))
    }

    static func carbsRemaining(grams: Double, minutes: Double, duration: Double) -> Double {
        guard grams.isFinite, grams > 0, minutes.isFinite, duration.isFinite, duration > 0, minutes >= 0 else { return 0 }
        let t = (minutes - TherapyModelSettings.carbDelay) / duration
        if t <= 0 { return grams }
        if t >= 1 { return 0 }
        let rise = 0.15, fall = 0.5
        let scale = 2 / (1 + fall - rise)
        let absorbed: Double
        if t < rise {
            absorbed = 0.5 * scale * t * t / rise
        } else if t < fall {
            absorbed = scale * (t - 0.5 * rise)
        } else {
            absorbed = scale * (fall - 0.5 * rise + (t - fall) * (1 - 0.5 * (t - fall) / (1 - fall)))
        }
        return min(grams, max(0, grams * (1 - absorbed)))
    }
}

/// Retained in the app’s license information as well as the source distribution.
enum TherapyModelAttribution {
    static let notice = """
The MIT License (MIT)

Copyright (c) 2015-2019 OpenAPS Contributors
Copyright (c) 2015 Nathan Racklyeft
Copyright (c) 2016 LoopKit Authors
Copyright (c) 2016 Nathan Racklyeft

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

"""
}

struct TherapyChartPoint: Identifiable, Sendable {
    let date: Date
    let amount: Double
    let segment: Int
    var id: String { "\(date.timeIntervalSince1970)-\(segment)-\(amount)" }
}

struct TherapyChartSeries: Sendable {
    var iob: [TherapyChartPoint] = []
    var cob: [TherapyChartPoint] = []

    /// Clip buffered curves at the viewport edges, preserving existing segment gaps.
    func clipped(from start: Date, to end: Date) -> Self {
        guard start < end else { return Self() }
        func clip(_ points: [TherapyChartPoint]) -> [TherapyChartPoint] {
            var result = points.filter { $0.date >= start && $0.date <= end }
            for (left, right) in zip(points, points.dropFirst()) where left.segment == right.segment {
                for edge in [start, end] where left.date < edge && right.date > edge {
                    let fraction = edge.timeIntervalSince(left.date) / right.date.timeIntervalSince(left.date)
                    let point = TherapyChartPoint(date: edge, amount: left.amount + (right.amount - left.amount) * fraction, segment: left.segment)
                    if edge == start { result.insert(point, at: 0) } else { result.append(point) }
                }
            }
            return result
        }
        return Self(iob: clip(iob), cob: clip(cob))
    }
}

/// Maps both metrics onto the glucose coordinates using one common scale.
struct TherapyChartScale {
    let baseline: Double
    let reduction: Double

    init(series: TherapyChartSeries, baseline: Double) {
        self.baseline = baseline
        reduction = max(1,
            (series.iob.map(\.amount).max() ?? 0) / ConstantsGlucoseChartSwiftUI.therapyPlotMaximumIOB,
            (series.cob.map(\.amount).max() ?? 0) / ConstantsGlucoseChartSwiftUI.therapyPlotMaximumCOB)
    }

    func glucoseValue(amount: Double, isIOB: Bool) -> Double {
        let units = isIOB ? amount : amount / ConstantsGlucoseChartSwiftUI.therapyPlotCarbsPerInsulinUnit
        return baseline + (ConstantsGlucoseChartSwiftUI.therapyPlotReferenceHeightInMgDl - baseline)
            * units / ConstantsGlucoseChartSwiftUI.therapyPlotMaximumIOB / reduction
    }
}
