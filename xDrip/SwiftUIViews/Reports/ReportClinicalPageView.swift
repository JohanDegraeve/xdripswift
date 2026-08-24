//
//  ReportClinicalPageView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

/// Renders the clinical summary pages used by the PDF generator.
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
            } else if pageNumber == 2 {
                GlucoseReportDailyGlucoseProfilesPageView(analytics: analytics, language: configuration.language)
            } else if pageNumber == 3 {
                GlucoseReportDailySummarySectionView(summaries: analytics.dailySummaries, usesMgDl: analytics.usesMgDl, language: configuration.language)
                GlucoseReportMetricTrendSectionView(trendPoints: analytics.trendPoints, language: configuration.language)
                // Event Analysis is intentionally hidden for now because it consumes too much
                // page space compared with the clinical value it currently adds.
                // eventAnalysis
            } else if let aidAnalytics = analytics.aidAnalytics {
                GlucoseReportAIDSectionView(aidAnalytics: aidAnalytics, usesMgDl: analytics.usesMgDl, language: configuration.language)
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
                    .frame(width: headerPanelAvailableItemWidth * 0.20, alignment: .leading)
                headerItem(configuration.text(.patientID), configuration.patientID.isEmpty ? "-" : configuration.patientID)
                    .frame(width: headerPanelAvailableItemWidth * 0.14, alignment: .leading)
                headerItem(configuration.text(.dateRange), "\(GlucoseReportFormatting.date(analytics.periodStart, language: configuration.language)) - \(GlucoseReportFormatting.date(analytics.periodEnd, language: configuration.language))", lineLimit: 1)
                    .frame(width: headerPanelAvailableItemWidth * 0.30, alignment: .leading)
                headerItem(configuration.text(.cgmSource), dataSourceDescription, lineLimit: 1)
                    .frame(width: headerPanelAvailableItemWidth * 0.23, alignment: .leading)
                headerItem(configuration.text(.units), analytics.usesMgDl ? "mg/dL" : "mmol/L", lineLimit: 1)
                    .frame(width: headerPanelAvailableItemWidth * 0.13, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(height: 44)
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

    private var headerPanelAvailableItemWidth: CGFloat {
        headerPanelContentWidth - 48
    }

    private var dataSourceDescription: String {
        if UserDefaults.standard.isMaster {
            return UserDefaults.standard.cgmTransmitterType?.rawValue ?? configuration.text(.storedCGMReadings)
        }
        return UserDefaults.standard.followerDataSourceType.description
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

private struct GlucoseReportDailyGlucoseProfilesPageView: View {
    let analytics: GlucoseReportAnalytics
    let language: GlucoseReportLanguage

    private let chartHeight: CGFloat = 62

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(titleText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(GlucoseReportColors.clinicalBlue)

                Spacer()

                Text(lastDaysText)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(GlucoseReportColors.secondaryText)
            }

            Text(standardizedRangeNoteText)
                .font(.system(size: 7.5))
                .foregroundStyle(GlucoseReportColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 7) {
                ForEach(displayProfiles) { profile in
                    dailyChart(profile)
                }
            }
        }
    }

    private var displayProfiles: [GlucoseReportDailyGlucoseProfile] {
        analytics.dailyGlucoseProfiles.suffix(7)
    }

    private var titleText: String {
        switch language {
        case .spanish:
            return "Glucosa día a día"
        case .french:
            return "Glycémie jour par jour"
        case .dutch:
            return "Glucose per dag"
        case .german:
            return "Glukose Tag für Tag"
        case .italian:
            return "Glucosio giorno per giorno"
        case .portuguese:
            return "Glicose dia a dia"
        case .english:
            return "Day-by-Day Glucose"
        }
    }

    private var lastDaysText: String {
        switch language {
        case .spanish:
            return "Últimos \(displayProfiles.count) días"
        case .french:
            return "\(displayProfiles.count) derniers jours"
        case .dutch:
            return "Laatste \(displayProfiles.count) dagen"
        case .german:
            return "Letzte \(displayProfiles.count) Tage"
        case .italian:
            return "Ultimi \(displayProfiles.count) giorni"
        case .portuguese:
            return "Últimos \(displayProfiles.count) dias"
        case .english:
            return "Last \(displayProfiles.count) days"
        }
    }

    private var standardizedRangeNoteText: String {
        let low = GlucoseReportFormatting.glucose(GlucoseReportClinicalConstants.timeInRangeLowMgDl, usesMgDl: analytics.usesMgDl)
        let high = GlucoseReportFormatting.glucose(GlucoseReportClinicalConstants.timeInRangeHighMgDl, usesMgDl: analytics.usesMgDl)

        switch language {
        case .spanish:
            return "Los gráficos usan límites clínicos estandarizados: Bajo <\(low), En rango \(low)-\(high), Alto >\(high). Estos límites pueden diferir de los ajustes de rango de la app."
        case .french:
            return "Les graphiques utilisent les limites cliniques standardisées : Bas <\(low), Dans la cible \(low)-\(high), Haut >\(high). Ces limites peuvent différer des réglages de l’app."
        case .dutch:
            return "De grafieken gebruiken gestandaardiseerde klinische grenzen: Laag <\(low), Binnen bereik \(low)-\(high), Hoog >\(high). Deze grenzen kunnen afwijken van de app-instellingen."
        case .german:
            return "Die Diagramme verwenden standardisierte klinische Grenzen: Niedrig <\(low), Im Bereich \(low)-\(high), Hoch >\(high). Diese Grenzen können von den App-Einstellungen abweichen."
        case .italian:
            return "I grafici usano limiti clinici standardizzati: Basso <\(low), In intervallo \(low)-\(high), Alto >\(high). Questi limiti possono differire dalle impostazioni dell’app."
        case .portuguese:
            return "Os gráficos usam limites clínicos padronizados: Baixo <\(low), No intervalo \(low)-\(high), Alto >\(high). Estes limites podem diferir das definições da app."
        case .english:
            return "Charts use standardized clinical glucose range limits: Low <\(low), In Range \(low)-\(high), High >\(high). These limits may differ from the in-app user range settings."
        }
    }

    private var yDomain: ClosedRange<Double> {
        converted(40) ... converted(maximumYMgDl)
    }

    private var maximumYMgDl: Double {
        let maximum = displayProfiles.flatMap(\.points).map(\.valueMgDl).max() ?? GlucoseReportClinicalConstants.timeInRangeHighMgDl
        let paddedMaximum = max(GlucoseReportClinicalConstants.timeInRangeHighMgDl, maximum) * 1.08
        return min(450, max(250, ceil(paddedMaximum / 10) * 10))
    }

    private func dailyChart(_ profile: GlucoseReportDailyGlucoseProfile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(GlucoseReportFormatting.date(profile.date, language: language))
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(GlucoseReportColors.primaryText)

                Spacer()

                Text("TIR \(GlucoseReportFormatting.percentage(timeInRangePercentage(for: profile)))")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(GlucoseReportColors.secondaryText)
                    .monospacedDigit()
            }

            Chart {
                nighttimeBackground(yDomain: yDomain)

                RectangleMark(
                    xStart: .value("Start", 0),
                    xEnd: .value("End", 1440),
                    yStart: .value("Low", converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl)),
                    yEnd: .value("High", converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl))
                )
                .foregroundStyle(GlucoseReportColors.target.opacity(0.10))

                RuleMark(y: .value("Low", converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl)))
                    .lineStyle(StrokeStyle(lineWidth: 0.8))
                    .foregroundStyle(GlucoseReportColors.low.opacity(0.75))

                RuleMark(y: .value("High", converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl)))
                    .lineStyle(StrokeStyle(lineWidth: 0.8))
                    .foregroundStyle(GlucoseReportColors.high.opacity(0.75))

                ForEach(profile.points) { point in
                    LineMark(
                        x: .value("Time", point.minuteOfDay),
                        y: .value("Glucose", converted(point.valueMgDl))
                    )
                    .foregroundStyle(GlucoseReportColors.clinicalBlue.opacity(0.38))
                    .lineStyle(StrokeStyle(lineWidth: 0.8))
                    .interpolationMethod(.linear)

                    PointMark(
                        x: .value("Time", point.minuteOfDay),
                        y: .value("Glucose", converted(point.valueMgDl))
                    )
                    .symbolSize(7)
                    .foregroundStyle(color(for: point.valueMgDl))
                }
            }
            .chartLegend(.hidden)
            .chartXScale(domain: 0 ... 1440)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: [0, 360, 720, 1080, 1440]) { value in
                    AxisGridLine()
                        .foregroundStyle(GlucoseReportColors.rule.opacity(0.7))
                    AxisValueLabel {
                        if let minute = value.as(Int.self) {
                            Text(timeLabel(minute))
                                .font(.system(size: 6.5))
                                .foregroundStyle(GlucoseReportColors.secondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: yAxisValues) { value in
                    AxisGridLine()
                        .foregroundStyle(yAxisGridLineColor(for: value.as(Double.self)))
                    AxisValueLabel {
                        if let glucose = value.as(Double.self) {
                            Text(axisLabel(for: glucose))
                                .font(.system(size: 6.5))
                                .foregroundStyle(GlucoseReportColors.secondaryText)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .frame(height: chartHeight)
        }
    }

    private var yAxisValues: [Double] {
        [40, GlucoseReportClinicalConstants.timeInRangeLowMgDl, GlucoseReportClinicalConstants.timeInRangeHighMgDl, maximumYMgDl]
            .map(converted)
    }

    private func color(for valueMgDl: Double) -> Color {
        if valueMgDl < GlucoseReportClinicalConstants.timeInRangeLowMgDl {
            return GlucoseReportColors.low
        }

        if valueMgDl > GlucoseReportClinicalConstants.timeInRangeHighMgDl {
            return GlucoseReportColors.high
        }

        return GlucoseReportColors.target
    }

    private func timeInRangePercentage(for profile: GlucoseReportDailyGlucoseProfile) -> Double {
        guard !profile.points.isEmpty else { return 0 }
        let inRangeCount = profile.points.filter {
            $0.valueMgDl >= GlucoseReportClinicalConstants.timeInRangeLowMgDl &&
                $0.valueMgDl <= GlucoseReportClinicalConstants.timeInRangeHighMgDl
        }.count
        return Double(inRangeCount) / Double(profile.points.count) * 100
    }

    @ChartContentBuilder private func nighttimeBackground(yDomain: ClosedRange<Double>) -> some ChartContent {
        RectangleMark(
            xStart: .value("Start", 0),
            xEnd: .value("End", GlucoseReportClinicalConstants.dayStartMinute),
            yStart: .value("Low", yDomain.lowerBound),
            yEnd: .value("High", yDomain.upperBound)
        )
        .foregroundStyle(GlucoseReportColors.nighttimeBackground)

        RectangleMark(
            xStart: .value("Start", GlucoseReportClinicalConstants.nightStartMinute),
            xEnd: .value("End", 1440),
            yStart: .value("Low", yDomain.lowerBound),
            yEnd: .value("High", yDomain.upperBound)
        )
        .foregroundStyle(GlucoseReportColors.nighttimeBackground)
    }

    private func yAxisGridLineColor(for value: Double?) -> Color {
        guard let value else { return GlucoseReportColors.rule.opacity(0.7) }

        if isAxisValue(value, equalTo: converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl)) {
            return GlucoseReportColors.low.opacity(0.75)
        }

        if isAxisValue(value, equalTo: converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl)) {
            return GlucoseReportColors.high.opacity(0.75)
        }

        return GlucoseReportColors.rule.opacity(0.7)
    }

    private func isAxisValue(_ value: Double, equalTo comparison: Double) -> Bool {
        abs(value - comparison) < 0.01
    }

    private func axisLabel(for convertedValue: Double) -> String {
        convertedValue.bgValueToString(mgDl: analytics.usesMgDl)
    }

    private func converted(_ valueMgDl: Double) -> Double {
        valueMgDl.mgDlToMmol(mgDl: analytics.usesMgDl)
    }

    private func timeLabel(_ minute: Int) -> String {
        String(format: "%02d:00", min(minute / 60, 24))
    }
}

private struct GlucoseReportAIDSectionView: View {
    let aidAnalytics: GlucoseReportAIDAnalytics
    let usesMgDl: Bool
    let language: GlucoseReportLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(language.text(.automatedInsulinDelivery))

            HStack(spacing: 8) {
                aidTile(title: language.text(.aidSystem), value: aidAnalytics.systemDescription)
                aidTile(title: language.text(.pump), value: aidAnalytics.pumpDescription ?? "-")
                aidTile(title: language.text(.loopingTime), value: GlucoseReportFormatting.percentage(aidAnalytics.loopingTimePercentage))
                aidTile(title: language.text(.averageTDD), value: aidAnalytics.averageTDD.map { "\($0.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes) U/day" } ?? "-")
            }

            sectionTitle(
                language.text(.loopingOverview),
                trailingText: loopalyzerTitleDetail
            )
                .padding(.top, 4)

            GlucoseReportLoopalyzerChart(
                points: aidAnalytics.loopalyzerPoints,
                insulinTreatmentMarkers: aidAnalytics.insulinTreatmentMarkers,
                carbTreatmentMarkers: aidAnalytics.carbTreatmentMarkers,
                usesMgDl: usesMgDl,
                language: language,
                supportsCOB: aidAnalytics.supportsCOB,
                supportsScheduledBasalAnalytics: aidAnalytics.supportsScheduledBasalAnalytics
            )

            Text(language.text(.loopalyzerFootnote))
                .font(.system(size: 7.5))
                .foregroundStyle(GlucoseReportColors.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let profileSchedule = aidAnalytics.profileSchedules.first {
                sectionTitle(
                    language.text(.profile),
                    trailingText: "\(profileSchedule.name) (\(GlucoseReportFormatting.dateTime(profileSchedule.startDate, language: language)))"
                )
                    .padding(.top, 4)

                GlucoseReportAIDProfileTables(
                    schedule: profileSchedule,
                    usesMgDl: usesMgDl,
                    language: language
                )
            }
        }
    }

    private func aidTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(GlucoseReportColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(value)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(GlucoseReportColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 39, maxHeight: 39, alignment: .topLeading)
        .background(GlucoseReportColors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var loopalyzerTitleDetail: String {
        let period = language.text(.loopalyzerPeriodFormat, aidAnalytics.periodDays)
        let startDate = GlucoseReportFormatting.date(aidAnalytics.loopalyzerStartDate, language: language)
        let endDate = GlucoseReportFormatting.date(aidAnalytics.loopalyzerEndDate, language: language)
        return "\(period) (\(startDate) - \(endDate))"
    }

    private func sectionTitle(_ title: String, trailingText: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(GlucoseReportColors.clinicalBlue)

            Spacer()

            if let trailingText {
                Text(trailingText)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(GlucoseReportColors.secondaryText)
            }
        }
    }
}

private struct GlucoseReportLoopalyzerChart: View {
    let points: [GlucoseReportLoopalyzerPoint]
    let insulinTreatmentMarkers: [GlucoseReportLoopalyzerTreatmentMarker]
    let carbTreatmentMarkers: [GlucoseReportLoopalyzerTreatmentMarker]
    let usesMgDl: Bool
    let language: GlucoseReportLanguage
    let supportsCOB: Bool
    let supportsScheduledBasalAnalytics: Bool

    private enum Layout {
        static let plotHeight: CGFloat = 50
        static let xAxisHeight: CGFloat = 14
        static let chartHeight = plotHeight + xAxisHeight
        static let yAxisLabelWidth: CGFloat = 22
        static let treatmentBarWidthMinutes = 5.0
    }

    var body: some View {
        VStack(spacing: 5) {
            // Both basal charts depend on a scheduled profile. CareLink provides delivered
            // automatic-basal amounts but no profile from which either chart can be calculated.
            if supportsScheduledBasalAnalytics {
                reportChart(title: language.text(.scheduledBasalProfile), yDomain: 0 ... basalUpperBound, basalProfile: true)
            }
            reportChart(title: language.text(.averageGlucose), yDomain: glucoseDomain, glucose: true)
            if supportsScheduledBasalAnalytics {
                reportChart(title: language.text(.tempBasalDelta), yDomain: basalDeltaDomain, basalDelta: true)
            }
            reportChart(title: "IOB", yDomain: -1 ... iobUpperBound, iob: true)
            // CareLink contributes the vertical meal-entry markers but no decaying COB series.
            // State that limitation in the clinical chart instead of presenting an empty COB plot
            // as though zero or missing data were an algorithm result.
            reportChart(title: carbChartTitle, yDomain: 0 ... cobUpperBound, cob: true)
        }
    }

    private var carbChartTitle: String {
        supportsCOB ? "COB" : language.text(.careLinkCarbChartTitle)
    }

    private func reportChart(
        title: String,
        yDomain: ClosedRange<Double>,
        basalProfile: Bool = false,
        basalDelta: Bool = false,
        glucose: Bool = false,
        iob: Bool = false,
        cob: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            chartTitle(title)

            HStack(alignment: .top, spacing: 3) {
                Chart {
                    nighttimeBackground(yDomain: yDomain)

                    if glucose {
                        RectangleMark(
                            xStart: .value("Start", 0.0),
                            xEnd: .value("End", 1440.0),
                            yStart: .value("Low", convertedGlucose(GlucoseReportClinicalConstants.timeInRangeLowMgDl)),
                            yEnd: .value("High", convertedGlucose(GlucoseReportClinicalConstants.timeInRangeHighMgDl))
                        )
                        .foregroundStyle(GlucoseReportColors.target.opacity(0.14))
                    }

                    ForEach(points) { point in
                        if basalProfile, let value = point.scheduledBasalRate {
                            RectangleMark(
                                xStart: .value("Start", point.bucketStartMinute),
                                xEnd: .value("End", point.bucketEndMinute),
                                yStart: .value("Zero", 0),
                                yEnd: .value("Basal", value)
                            )
                            .foregroundStyle(GlucoseReportColors.aidScheduledBasalFill.opacity(GlucoseReportColors.aidScheduledBasalFillOpacity))
                        }
                        if basalProfile, let value = point.scheduledBasalRate {
                            // Scheduled values cover an entire quarter-hour bucket. Use the same
                            // start/end geometry for the dashed top edge and the filled block.
                            RuleMark(
                                xStart: .value("Start", point.bucketStartMinute),
                                xEnd: .value("End", point.bucketEndMinute),
                                y: .value("Basal", value)
                            )
                            .lineStyle(StrokeStyle(
                                lineWidth: GlucoseReportColors.aidScheduledBasalLineWidth,
                                dash: GlucoseReportColors.aidScheduledBasalDash
                            ))
                            .foregroundStyle(GlucoseReportColors.aidScheduledBasal)
                        }
                        if glucose, let value = point.glucoseMgDl {
                            // The value is averaged over the bucket and therefore belongs at its
                            // midpoint, 7.5 minutes after the stored bucket-start timestamp.
                            LineMark(x: .value("Time", point.bucketMidpointMinute), y: .value("Glucose", convertedGlucose(value)))
                                .foregroundStyle(GlucoseReportColors.target)
                                .lineStyle(StrokeStyle(lineWidth: 1.8))
                                .interpolationMethod(.catmullRom)
                        }
                        if basalDelta, let value = point.basalDeltaRate {
                            RectangleMark(
                                xStart: .value("Start", point.bucketBarStartMinute),
                                xEnd: .value("End", point.bucketBarEndMinute),
                                yStart: .value("Zero", 0),
                                yEnd: .value("Delta", value)
                            )
                            .foregroundStyle(GlucoseReportColors.aidDeliveredBasal.opacity(GlucoseReportColors.aidDeliveredBasalOpacity))
                        }
                        if iob, let value = point.iob {
                            RectangleMark(
                                xStart: .value("Start", point.bucketBarStartMinute),
                                xEnd: .value("End", point.bucketBarEndMinute),
                                yStart: .value("Zero", 0),
                                yEnd: .value("IOB", value)
                            )
                            .foregroundStyle(
                                value < 0
                                    ? GlucoseReportColors.low
                                    : GlucoseReportColors.aidIOB.opacity(GlucoseReportColors.aidIOBOpacity)
                            )
                        }
                        if cob, let value = point.cob {
                            RectangleMark(
                                xStart: .value("Start", point.bucketBarStartMinute),
                                xEnd: .value("End", point.bucketBarEndMinute),
                                yStart: .value("Zero", 0),
                                yEnd: .value("COB", value)
                            )
                            .foregroundStyle(GlucoseReportColors.aidCOB.opacity(GlucoseReportColors.aidCOBOpacity))
                        }
                    }

                    if basalProfile {
                        ForEach(scheduledBasalTransitions) { transition in
                            RuleMark(
                                x: .value("Time", transition.minuteOfDay),
                                yStart: .value("From", transition.fromRate),
                                yEnd: .value("To", transition.toRate)
                            )
                            .lineStyle(StrokeStyle(
                                lineWidth: GlucoseReportColors.aidScheduledBasalLineWidth,
                                dash: GlucoseReportColors.aidScheduledBasalDash
                            ))
                            .foregroundStyle(GlucoseReportColors.aidScheduledBasal)
                        }
                    }

                    if iob {
                        RuleMark(y: .value("Zero", 0))
                            .lineStyle(StrokeStyle(lineWidth: 1.0))
                            .foregroundStyle(GlucoseReportColors.secondaryText.opacity(0.8))

                        ForEach(insulinTreatmentMarkers) { marker in
                            treatmentMarker(marker, yDomain: yDomain)
                        }
                    }

                    if cob {
                        ForEach(carbTreatmentMarkers) { marker in
                            treatmentMarker(marker, yDomain: yDomain)
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXScale(
                    domain: 0.0 ... 1440.0,
                    range: .plotDimension(startPadding: 0, endPadding: 0)
                )
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [yDomain.lowerBound, yDomain.upperBound]) { _ in
                        AxisGridLine()
                            .foregroundStyle(GlucoseReportColors.rule)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [0.0, 360.0, 720.0, 1080.0, 1440.0]) { value in
                        AxisGridLine()
                            .foregroundStyle(GlucoseReportColors.rule.opacity(0.75))
                        AxisValueLabel {
                            if let minute = value.as(Double.self) {
                                Text(timeLabel(for: Int(minute)))
                                    .font(.system(size: 6.5))
                                    .foregroundStyle(GlucoseReportColors.secondaryText)
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.frame(height: Layout.plotHeight)
                }
                .frame(height: Layout.chartHeight, alignment: .top)

                yAxisLabels(for: yDomain)
            }
        }
    }

    private func chartTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 7.5, weight: .semibold))
            .foregroundStyle(GlucoseReportColors.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }

    @ChartContentBuilder private func nighttimeBackground(yDomain: ClosedRange<Double>) -> some ChartContent {
        RectangleMark(
            xStart: .value("Start", 0.0),
            xEnd: .value("End", Double(GlucoseReportClinicalConstants.dayStartMinute)),
            yStart: .value("Low", yDomain.lowerBound),
            yEnd: .value("High", yDomain.upperBound)
        )
        .foregroundStyle(GlucoseReportColors.nighttimeBackground)

        RectangleMark(
            xStart: .value("Start", Double(GlucoseReportClinicalConstants.nightStartMinute)),
            xEnd: .value("End", 1440.0),
            yStart: .value("Low", yDomain.lowerBound),
            yEnd: .value("High", yDomain.upperBound)
        )
        .foregroundStyle(GlucoseReportColors.nighttimeBackground)
    }

    private func yAxisLabels(for yDomain: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            axisLabel(yDomain.upperBound)
            Spacer()
            axisLabel(yDomain.lowerBound)
        }
        // Align labels to the plot rectangle only. The Chart's remaining height belongs to
        // x-axis labels and must not push the lower y value below its actual baseline.
        .frame(width: Layout.yAxisLabelWidth, height: Layout.plotHeight, alignment: .leading)
    }

    private func axisLabel(_ value: Double) -> some View {
        Text(value.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes)
            .font(.system(size: 6.5))
            .foregroundStyle(GlucoseReportColors.secondaryText)
            .lineLimit(1)
    }

    /// Loopalyzer's last two charts use vertical black bars for insulin and carbohydrate
    /// treatments. Center each visible bar on the original treatment timestamp.
    private func treatmentMarker(
        _ marker: GlucoseReportLoopalyzerTreatmentMarker,
        yDomain: ClosedRange<Double>
    ) -> some ChartContent {
        let halfWidth = Layout.treatmentBarWidthMinutes / 2
        return RectangleMark(
            xStart: .value("Start", max(Double(marker.minuteOfDay) - halfWidth, 0)),
            xEnd: .value("End", min(Double(marker.minuteOfDay) + halfWidth, 1440)),
            yStart: .value("Zero", 0),
            yEnd: .value("Treatment", min(marker.amount, yDomain.upperBound))
        )
        .foregroundStyle(GlucoseReportColors.aidTreatmentMarker)
    }

    private var basalUpperBound: Double {
        upperBound(values: points.compactMap(\.scheduledBasalRate), minimum: 2)
    }

    private var basalDeltaDomain: ClosedRange<Double> {
        let maximum = max(points.compactMap(\.basalDeltaRate).map(abs).max() ?? 0, 1)
        let bound = ceil(maximum * 1.15 * 10) / 10
        return -bound ... bound
    }

    private var glucoseDomain: ClosedRange<Double> {
        if usesMgDl {
            return 40 ... max(250, upperBound(values: points.compactMap(\.glucoseMgDl), minimum: 250))
        }

        return 40.0.mgDlToMmol() ... max(
            13.9,
            upperBound(values: points.compactMap { $0.glucoseMgDl.map(convertedGlucose) }, minimum: 13.9)
        )
    }

    private var iobUpperBound: Double {
        upperBound(values: points.compactMap(\.iob) + insulinTreatmentMarkers.map(\.amount), minimum: 5)
    }

    private var cobUpperBound: Double {
        upperBound(values: points.compactMap(\.cob) + carbTreatmentMarkers.map(\.amount), minimum: 30)
    }

    private func convertedGlucose(_ valueMgDl: Double) -> Double {
        valueMgDl.mgDlToMmol(mgDl: usesMgDl)
    }

    private func upperBound(values: [Double], minimum: Double) -> Double {
        guard let maximum = values.max(), maximum > 0 else { return minimum }
        return max(minimum, ceil(maximum * 1.15))
    }

    private func timeLabel(for minute: Int) -> String {
        String(format: "%02d:00", min(minute / 60, 24))
    }

    private var scheduledBasalTransitions: [ScheduledBasalTransition] {
        let scheduledPoints = points
            .compactMap { point -> (minute: Double, rate: Double)? in
                guard let rate = point.scheduledBasalRate else { return nil }
                return (point.bucketStartMinute, rate)
            }
            .sorted { $0.minute < $1.minute }

        return scheduledPoints.indices.compactMap { index in
            guard index > scheduledPoints.startIndex else { return nil }
            let previous = scheduledPoints[scheduledPoints.index(before: index)]
            let current = scheduledPoints[index]
            guard previous.rate != current.rate else { return nil }
            return ScheduledBasalTransition(
                minuteOfDay: current.minute,
                fromRate: previous.rate,
                toRate: current.rate
            )
        }
    }

    private struct ScheduledBasalTransition: Identifiable {
        let minuteOfDay: Double
        let fromRate: Double
        let toRate: Double

        var id: String {
            "\(minuteOfDay)-\(fromRate)-\(toRate)"
        }
    }
}

private struct GlucoseReportAIDProfileTables: View {
    let schedule: GlucoseReportAIDProfileSchedule
    let usesMgDl: Bool
    let language: GlucoseReportLanguage

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            scheduleColumn(title: language.text(.basalProfile), unit: "U", values: schedule.basal, decimalPlaces: 3)
            scheduleColumn(title: language.text(.carbRatio), unit: "g / U", values: schedule.carbRatio, decimalPlaces: 1)
            scheduleColumn(
                title: language.text(.sensitivity),
                unit: usesMgDl ? "mg/dL / U" : "mmol/L / U",
                values: schedule.sensitivity,
                decimalPlaces: 1,
                valueTransform: { $0.mgDlToMmol(mgDl: usesMgDl) }
            )
        }
    }

    private func scheduleColumn(
        title: String,
        unit: String,
        values: [GlucoseReportAIDProfileSchedule.ScheduleValue],
        decimalPlaces: Int,
        valueTransform: @escaping (Double) -> Double = { $0 }
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(title.uppercased()) (\(unit))")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(GlucoseReportColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            ForEach(values.prefix(7)) { value in
                HStack(spacing: 4) {
                    Text(timeLabel(for: value.secondsFromMidnight / 60))
                        .foregroundStyle(GlucoseReportColors.tertiaryText)
                        .frame(width: 28, alignment: .leading)
                    Text(valueTransform(value.value).round(toDecimalPlaces: decimalPlaces).stringWithoutTrailingZeroes)
                        .foregroundStyle(GlucoseReportColors.primaryText)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 7.5))
                .lineLimit(1)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GlucoseReportColors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func timeLabel(for minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}
