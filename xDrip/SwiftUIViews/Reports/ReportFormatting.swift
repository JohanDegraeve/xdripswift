//
//  ReportFormatting.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Shared unit, number and date formatting for on-screen and PDF reports.
enum GlucoseReportFormatting {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    static func glucose(_ mgDlValue: Double, usesMgDl: Bool) -> String {
        mgDlValue.mgDlToMmolAndToString(mgDl: usesMgDl) + " " + (usesMgDl ? "mg/dL" : "mmol/L")
    }

    static func axisGlucose(_ mgDlValue: Double, usesMgDl: Bool) -> String {
        mgDlValue.mgDlToMmolAndToString(mgDl: usesMgDl)
    }

    static func percentage(_ value: Double, decimals: Int = 0) -> String {
        "\(value.round(toDecimalPlaces: decimals).stringWithoutTrailingZeroes)%"
    }

    /// Formats a percentage that has already been allocated as part of a complete distribution.
    /// Callers displaying several mutually exclusive buckets must use this overload rather than
    /// independently rounding their exact `Double` values.
    static func percentage(_ value: Int) -> String {
        "\(value)%"
    }

    static func number(_ value: Double, decimalPlaces: Int, locale: Locale = .current) -> String {
        value.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(decimalPlaces))
        )
    }

    static func date(_ date: Date, language: GlucoseReportLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func dateTime(_ date: Date, language: GlucoseReportLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func day(_ date: Date, language: GlucoseReportLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    static func compactDuration(_ duration: TimeInterval) -> String {
        (duration / 60).minutesToDaysAndHours()
    }

    /// Formats one bucket from a jointly allocated 1,440-minute day.
    /// Accepting minutes rather than a percentage prevents each report bucket from rounding its
    /// duration independently and guarantees that the three displayed durations total 24 hours.
    static func hoursPerDay(minutes totalMinutes: Int, language: GlucoseReportLanguage) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let daySuffix = language == .spanish ? "día" : "day"

        if hours == 0 {
            return "\(minutes)m/\(daySuffix)"
        }

        return "\(hours)h \(minutes)m/\(daySuffix)"
    }
}
