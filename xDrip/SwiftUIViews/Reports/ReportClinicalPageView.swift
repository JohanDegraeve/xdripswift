//
//  ReportClinicalPageView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct GlucoseReportClinicalPageView: View {
    let configuration: GlucoseReportConfiguration
    let analytics: GlucoseReportAnalytics
    let generatedAt: Date
    let pageNumber: Int
    let pageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if pageNumber == 1 {
                GlucoseReportMetricGridView(analytics: analytics, language: configuration.language)
                GlucoseReportTimeInRangeBarView(distribution: analytics.rangeDistribution, usesMgDl: analytics.usesMgDl, language: configuration.language)
                GlucoseReportTimeInRangeBarView(
                    title: "\(configuration.text(.timeInTightRange)) (TITR)",
                    distribution: analytics.tightRangeDistribution,
                    usesMgDl: analytics.usesMgDl,
                    buckets: analytics.tightRangeDistribution.tightRangeBuckets(usesMgDl: analytics.usesMgDl),
                    sourceText: configuration.text(.timeInTightRangeSource),
                    sourceURL: GlucoseReportRangeDistribution.timeInTightRangeSourceURL,
                    language: configuration.language
                )
                GlucoseReportAGPChartView(points: analytics.agpPoints, usesMgDl: analytics.usesMgDl, language: configuration.language)
            } else {
                GlucoseReportDailySummarySectionView(summaries: analytics.dailySummaries, usesMgDl: analytics.usesMgDl, language: configuration.language)
                GlucoseReportMetricTrendSectionView(trendPoints: analytics.trendPoints, language: configuration.language)
                // Event Analysis is intentionally hidden for now because it consumes too much
                // page space compared with the clinical value it currently adds.
                // eventAnalysis
                reportQuality
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .frame(
            width: configuration.paperSize.pageSize.width,
            height: configuration.paperSize.pageSize.height,
            alignment: .topLeading
        )
        .background(GlucoseReportColors.pageBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(configuration.text(.continuousGlucoseMonitoringReport))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(GlucoseReportColors.clinicalBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(configuration.period.clinicalTitle(language: configuration.language).uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(GlucoseReportColors.secondaryText)
                }

                Spacer()

                HStack(alignment: .center, spacing: 7) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(ConstantsHomeView.applicationName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(GlucoseReportColors.primaryText)
                        Text(configuration.text(.generatedFormat, GlucoseReportFormatting.dateTime(generatedAt, language: configuration.language)))
                            .font(.system(size: 8))
                            .foregroundStyle(GlucoseReportColors.secondaryText)
                    }

                    appIcon
                }
            }

            HStack(spacing: 12) {
                headerItem(configuration.text(.patient), configuration.patientName.isEmpty ? "-" : configuration.patientName)
                    .frame(width: headerPanelContentWidth * 0.24, alignment: .leading)
                headerItem(configuration.text(.patientID), configuration.patientID.isEmpty ? "-" : configuration.patientID)
                    .frame(width: headerPanelContentWidth * 0.18, alignment: .leading)
                headerItem(configuration.text(.dateRange), "\(GlucoseReportFormatting.date(analytics.periodStart, language: configuration.language)) - \(GlucoseReportFormatting.date(analytics.periodEnd, language: configuration.language))", lineLimit: 1)
                    .frame(width: headerPanelContentWidth * 0.40, alignment: .leading)
                headerItem(configuration.text(.units), analytics.usesMgDl ? "mg/dL" : "mmol/L")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(GlucoseReportColors.patientPanel)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Divider()
                .overlay(GlucoseReportColors.rule)
        }
    }

    private var appIcon: some View {
        Group {
            if let image = UIImage(named: "AppIconPreview") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var eventAnalysis: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Event Analysis")

            HStack(spacing: 8) {
                eventTile(title: "Hypoglycaemia", value: "\(analytics.lowEventCount)", detail: "<70 mg/dL events", rate: eventsPerWeek(analytics.lowEventCount), indicatorColor: GlucoseReportColors.low)
                eventTile(title: "Clinically Significant Low", value: "\(analytics.veryLowEventCount)", detail: "<54 mg/dL events", rate: eventsPerWeek(analytics.veryLowEventCount), indicatorColor: GlucoseReportColors.veryLow)
                eventTile(title: "Hyperglycaemia", value: "\(analytics.highEventCount)", detail: ">180 mg/dL events", rate: eventsPerWeek(analytics.highEventCount), indicatorColor: GlucoseReportColors.high)
                eventTile(title: "Marked Hyperglycaemia", value: "\(analytics.veryHighEventCount)", detail: ">250 mg/dL events", rate: eventsPerWeek(analytics.veryHighEventCount), indicatorColor: GlucoseReportColors.veryHigh)
            }

            Text("Events are counted as separated excursions when readings cross a threshold and are more than 15 minutes from the previous matching excursion.")
                .font(.system(size: 8))
                .foregroundStyle(GlucoseReportColors.secondaryText)
        }
    }

    private var reportQuality: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(configuration.text(.cgmSystemAndReportQuality))

            HStack(spacing: 8) {
                qualityRow(title: configuration.text(.cgmSource), value: cgmSourceText)
                qualityRow(title: configuration.text(.currentSensor), value: currentSensorText)
                qualityRow(
                    title: configuration.text(.sensorsInPeriod),
                    value: analytics.sensorCount > 0 ? "\(analytics.sensorCount)" : "-",
                    detail: averageSensorDurationText
                )
                qualityRow(title: configuration.text(.calibrations), value: "\(analytics.calibrationCount)")
            }

            HStack(spacing: 8) {
                qualityRow(title: configuration.text(.firstReading), value: analytics.firstReading.map { GlucoseReportFormatting.dateTime($0, language: configuration.language) } ?? "-")
                qualityRow(title: configuration.text(.lastReading), value: analytics.lastReading.map { GlucoseReportFormatting.dateTime($0, language: configuration.language) } ?? "-")
                qualityRow(title: configuration.text(.dataCapture), value: GlucoseReportFormatting.percentage(analytics.dataCapturePercentage))
            }

            Text(configuration.text(.reportInterpretationNote))
                .font(.system(size: 8))
                .foregroundStyle(GlucoseReportColors.secondaryText)

        }
    }

    private var cgmSourceText: String {
        guard !analytics.deviceNames.isEmpty else { return configuration.text(.storedCGMReadings) }
        return analytics.deviceNames.prefix(2).joined(separator: ", ")
    }

    private var currentSensorText: String {
        guard let description = UserDefaults.standard.activeSensorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty else {
            return "-"
        }

        return description
    }

    private var averageSensorDurationText: String? {
        guard let averageSensorDuration = analytics.averageSensorDuration else { return nil }

        return "(" + configuration.text(.averageSensorDurationFormat, GlucoseReportFormatting.compactDuration(averageSensorDuration)) + ")"
    }

    private var footer: some View {
        HStack {
            Text(configuration.text(.footerGeneratedFormat, ConstantsHomeView.applicationName, Bundle.main.glucoseReportAppVersion))
                .font(.system(size: 7.5))
                .foregroundStyle(GlucoseReportColors.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer()
            Text(configuration.text(.pageFormat, pageNumber, pageCount))
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(GlucoseReportColors.secondaryText)
        }
    }

    private var headerContentWidth: CGFloat {
        configuration.paperSize.pageSize.width - 68
    }

    private var headerPanelContentWidth: CGFloat {
        headerContentWidth - 20
    }

    private func headerItem(_ title: String, _ value: String, lineLimit: Int = 2) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(GlucoseReportColors.tertiaryText)
            Text(value)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(GlucoseReportColors.primaryText)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func eventTile(title: String, value: String, detail: String, rate: String, indicatorColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 5, height: 5)

                Text(title.uppercased())
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(GlucoseReportColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GlucoseReportColors.primaryText)
                .monospacedDigit()
            Text(detail)
                .font(.system(size: 8))
                .foregroundStyle(GlucoseReportColors.tertiaryText)
            Text(rate)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(GlucoseReportColors.secondaryText)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlucoseReportColors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func qualityRow(title: String, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(GlucoseReportColors.secondaryText)
            Text(value)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(GlucoseReportColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let detail {
                Text(detail)
                    .font(.system(size: 6.7))
                    .foregroundStyle(GlucoseReportColors.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlucoseReportColors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GlucoseReportColors.clinicalBlue)
    }

    private func eventsPerWeek(_ count: Int) -> String {
        let weeks = max(Double(configuration.period.rawValue) / 7.0, 1)
        let rate = Double(count) / weeks
        return "\(rate.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes)/week"
    }
}
