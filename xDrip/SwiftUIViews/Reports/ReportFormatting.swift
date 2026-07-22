//
//  ReportFormatting.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

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
        if usesMgDl {
            return "\(Int(mgDlValue.rounded())) mg/dL"
        }

        return "\((mgDlValue * ConstantsBloodGlucose.mgDlToMmoll).round(toDecimalPlaces: 1).stringWithoutTrailingZeroes) mmol/L"
    }

    static func axisGlucose(_ mgDlValue: Double, usesMgDl: Bool) -> String {
        if usesMgDl {
            return "\(Int(mgDlValue.rounded()))"
        }

        return "\((mgDlValue * ConstantsBloodGlucose.mgDlToMmoll).round(toDecimalPlaces: 1).stringWithoutTrailingZeroes)"
    }

    static func percentage(_ value: Double, decimals: Int = 0) -> String {
        "\(value.round(toDecimalPlaces: decimals).stringWithoutTrailingZeroes)%"
    }

    static func hoursPerDay(from percentage: Double) -> String {
        hoursPerDay(from: percentage, language: .english)
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

    static func hoursPerDay(from percentage: Double, language: GlucoseReportLanguage) -> String {
        let totalMinutes = Int((percentage / 100 * 24 * 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let daySuffix = language == .spanish ? "día" : "day"

        if hours == 0 {
            return "\(minutes)m/\(daySuffix)"
        }

        return "\(hours)h \(minutes)m/\(daySuffix)"
    }
}
