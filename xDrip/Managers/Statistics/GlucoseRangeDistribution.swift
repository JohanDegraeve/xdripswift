//
//  GlucoseRangeDistribution.swift
//  xdrip
//
//  Created by Paul Plant on 01/09/2026.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Converts proportional floating-point values into integers with an exact requested total.
///
/// Rounding each percentage independently is not safe for a distribution: values such as
/// `3.6, 87.6, 8.8` become `4, 88, 9`, which misleadingly adds up to 101%. This allocator uses the
/// largest-remainder method instead. It floors every normalized value, then gives the unallocated
/// units to the largest fractional remainders. The result is deterministic and, whenever at least
/// one valid input value exists, adds up to `total` exactly.
///
/// The allocator is deliberately generic. TIR labels request 100 units, while clinical report
/// durations request 1,440 units so their independently displayed hours and minutes total one day.
enum ProportionalIntegerAllocator {
    /// Allocates `total` integer units proportionally across `values`.
    ///
    /// - Parameters:
    ///   - values: Relative non-negative weights. They do not need to already add up to 100.
    ///   - total: Integer total to distribute. A non-positive total produces zero for every input.
    /// - Returns: One integer per input value. Invalid, infinite and negative weights are treated as
    ///   zero. An empty or entirely zero distribution returns zeroes because there is no meaningful
    ///   category to which a percentage or duration can be assigned.
    static func allocate(_ values: [Double], total: Int = 100) -> [Int] {
        guard !values.isEmpty else { return [] }
        guard total > 0 else { return Array(repeating: 0, count: values.count) }

        let sanitizedValues = values.map { value in
            value.isFinite && value > 0 ? value : 0
        }
        let valueTotal = sanitizedValues.reduce(0, +)
        guard valueTotal > 0 else { return Array(repeating: 0, count: values.count) }

        let scaledValues = sanitizedValues.map { $0 / valueTotal * Double(total) }
        var allocatedValues = scaledValues.map { Int(floor($0)) }
        let unitsStillToAllocate = total - allocatedValues.reduce(0, +)

        // Stable index ordering makes exact fractional ties deterministic. In a TIR distribution
        // this means identical input always produces identical display output on every surface.
        let indicesByLargestRemainder = scaledValues.indices.sorted { leftIndex, rightIndex in
            let leftRemainder = scaledValues[leftIndex] - floor(scaledValues[leftIndex])
            let rightRemainder = scaledValues[rightIndex] - floor(scaledValues[rightIndex])

            if leftRemainder == rightRemainder {
                return leftIndex < rightIndex
            }

            return leftRemainder > rightRemainder
        }

        for index in indicesByLargestRemainder.prefix(max(0, unitsStillToAllocate)) {
            allocatedValues[index] += 1
        }

        return allocatedValues
    }
}

/// Exact and display-ready percentages for a mutually exclusive three-part glucose range.
///
/// All Home, Statistics, report and landscape TIR/TITR presentations use this value type. Keeping
/// the range boundaries and proportional allocation here prevents one screen from truncating values
/// while another rounds them independently.
struct GlucoseRangeDistribution: Equatable {
    let belowPercentage: Double
    let inRangePercentage: Double
    let abovePercentage: Double

    /// Creates a normalized distribution from three relative weights.
    ///
    /// Report analytics already provide percentages, while direct glucose calculations naturally
    /// provide counts. Treating both as weights lets the same initializer safely normalize either.
    init(below: Double, inRange: Double, above: Double) {
        let values = [below, inRange, above].map { value in
            value.isFinite && value > 0 ? value : 0
        }
        let total = values.reduce(0, +)

        guard total > 0 else {
            belowPercentage = 0
            inRangePercentage = 0
            abovePercentage = 0
            return
        }

        belowPercentage = values[0] / total * 100
        inRangePercentage = values[1] / total * 100
        abovePercentage = values[2] / total * 100
    }

    /// Calculates the distribution for glucose values expressed in the same unit as both limits.
    /// Values exactly on either boundary are in range, matching the app's established TIR policy.
    init(values: [Double], lowLimit: Double, highLimit: Double) {
        guard lowLimit <= highLimit else {
            self.init(below: 0, inRange: 0, above: 0)
            return
        }

        let validValues = values.filter(\.isFinite)
        self.init(
            below: Double(validValues.lazy.filter { $0 < lowLimit }.count),
            inRange: Double(validValues.lazy.filter { $0 >= lowLimit && $0 <= highLimit }.count),
            above: Double(validValues.lazy.filter { $0 > highLimit }.count)
        )
    }

    /// Exact normalized percentages in the visual order used throughout the app.
    var percentages: [Double] {
        [belowPercentage, inRangePercentage, abovePercentage]
    }

    /// Whole display percentages guaranteed to total 100 whenever this distribution contains data.
    var wholePercentages: [Int] {
        ProportionalIntegerAllocator.allocate(percentages)
    }

    /// Allocates another integer total using the same exact proportions.
    /// Clinical reports use this to divide exactly 1,440 minutes between their three TIR buckets.
    func allocatedUnits(total: Int) -> [Int] {
        ProportionalIntegerAllocator.allocate(percentages, total: total)
    }
}

/// Standard and tight clinical distributions calculated from one canonical glucose sample set.
///
/// Landscape presents both modes from the same selected calendar day. Keeping the pair together
/// prevents either mode from falling back to the chart renderer's deliberately wider cache window.
struct GlucoseClinicalRangeSummary: Equatable {
    let timeInRange: GlucoseRangeDistribution
    let timeInTightRange: GlucoseRangeDistribution

    init(valuesMgDl: [Double]) {
        timeInRange = GlucoseRangeDistribution(
            values: valuesMgDl,
            lowLimit: GlucoseReportClinicalConstants.timeInRangeLowMgDl,
            highLimit: GlucoseReportClinicalConstants.timeInRangeHighMgDl
        )
        timeInTightRange = GlucoseRangeDistribution(
            values: valuesMgDl,
            lowLimit: GlucoseReportClinicalConstants.timeInTightRangeLowMgDl,
            highLimit: GlucoseReportClinicalConstants.timeInTightRangeHighMgDl
        )
    }

    static let empty = GlucoseClinicalRangeSummary(valuesMgDl: [])
}
