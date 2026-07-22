//
//  ReportMetricGridView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct GlucoseReportMetricGridView: View {
    let analytics: GlucoseReportAnalytics
    let language: GlucoseReportLanguage

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            metric(title: language.text(.averageGlucose), value: GlucoseReportFormatting.glucose(analytics.averageMgDl, usesMgDl: analytics.usesMgDl), target: "")
            metric(title: "GMI", value: "\(analytics.gmiPercentage.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes)%", target: language.text(.consensusEstimate))
            metric(title: language.text(.cv), value: GlucoseReportFormatting.percentage(analytics.coefficientOfVariation), target: language.text(.targetLessThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.coefficientOfVariationTargetPercentage)))
            metric(title: language.text(.dataCapture), value: GlucoseReportFormatting.percentage(analytics.dataCapturePercentage), target: language.text(.targetGreaterThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.minimumDataCapturePercentage)))
            metric(title: language.text(.readings), value: "\(analytics.sampleCount)", target: "\(analytics.readingsPerDay.round(toDecimalPlaces: 0).stringWithoutTrailingZeroes)/day")
            metric(title: language.text(.timeBelowRange), value: GlucoseReportFormatting.percentage(analytics.rangeDistribution.veryLow + analytics.rangeDistribution.low), target: language.text(.targetLessThan, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.dailyLowTargetPercentage)), indicatorColor: GlucoseReportColors.low)
            metric(title: language.text(.timeInRange), value: GlucoseReportFormatting.percentage(analytics.rangeDistribution.target), target: language.text(.targetGreaterThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.dailyTimeInRangeTargetPercentage)), indicatorColor: GlucoseReportColors.target)
            metric(title: language.text(.timeAboveRange), value: GlucoseReportFormatting.percentage(analytics.rangeDistribution.high + analytics.rangeDistribution.veryHigh), target: language.text(.targetLessThan, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.dailyHighTargetPercentage)), indicatorColor: GlucoseReportColors.high)
        }
    }

    private func metric(title: String, value: String, target: String, indicatorColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                if let indicatorColor {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 5, height: 5)
                }

                Text(title.uppercased())
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(GlucoseReportColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(GlucoseReportColors.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(target.isEmpty ? " " : target)
                .font(.system(size: 7.5))
                .foregroundStyle(GlucoseReportColors.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlucoseReportColors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
