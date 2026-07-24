//
//  SensorNoiseHistoryView.swift
//  xdrip
//
//  Created by Paul Plant on 16/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

/// Detailed sensor-session noise history opened from sensor management.
///
/// The view shows the latest persisted measurements and a selectable chart built from the current
/// sensor session. It defaults to the newest visible chart point and returns there whenever the
/// user changes the displayed time range.
struct SensorNoiseHistoryView: View {
    @StateObject private var viewModel: SensorNoiseHistoryViewModel
    @State private var selectedRange = SensorNoiseHistoryRange.day
    @State private var selectedPoint: SensorNoiseHistoryPoint?
    @State private var sensorNoiseSensitivity = UserDefaults.standard.sensorNoiseSensitivity

    private let sensorID: String
    private let isMgDl: Bool
    private let currentMeasurementsDetail: String?

    init(
        sensorID: String,
        sensorNoiseManager: SensorNoiseManager,
        isMgDl: Bool,
        currentMeasurementsDetail: String? = nil
    ) {
        self.sensorID = sensorID
        self.isMgDl = isMgDl
        self.currentMeasurementsDetail = currentMeasurementsDetail
        _viewModel = StateObject(
            wrappedValue: SensorNoiseHistoryViewModel(
                sensorID: sensorID,
                sensorNoiseManager: sensorNoiseManager
            )
        )
    }

    // MARK: - view

    var body: some View {
        GeometryReader { geometry in
            List {
                if let snapshot = viewModel.snapshot {
                    Section {
                        currentStateRow(snapshot: snapshot)

                        sensorNoiseSensitivityRow()

                        SensorNoiseGaugeRow(
                            title: Texts_HomeView.sensorManagementNoiseShortTerm,
                            noiseInMgDl: snapshot.shortTermNoise,
                            coverage: snapshot.shortTermCoverage,
                            isMgDl: isMgDl,
                            sensitivity: sensorNoiseSensitivity
                        )

                        SensorNoiseGaugeRow(
                            title: Texts_HomeView.sensorManagementNoiseLongTerm,
                            noiseInMgDl: snapshot.longTermNoise,
                            coverage: snapshot.longTermCoverage,
                            isMgDl: isMgDl,
                            sensitivity: sensorNoiseSensitivity
                        )
                    } header: {
                        Text(Texts_HomeView.sensorNoiseHistoryCurrentTitle)
                    }

                    Section {
                        noiseHistoryChart(
                            snapshot: snapshot,
                            chartHeight: max(110, (geometry.size.height - 430) * 0.62)
                        )
                        .listRowInsets(EdgeInsets(top: 14, leading: 12, bottom: 16, trailing: 12))
                    } header: {
                        Text(Texts_HomeView.sensorNoiseHistoryChartTitle)
                    } footer: {
                        Text(Texts_HomeView.sensorNoiseHistoryFooter)
                    }
                } else {
                    Section {
                        ProgressView(Texts_HomeView.sensorNoiseHistoryLoading)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 28)
                    }
                }
            }
        }
        .navigationTitle(Texts_HomeView.sensorNoiseHistoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
            refreshSensorNoiseSensitivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sensorNoiseHistoryDidChange)) { notification in
            guard notification.object as? String == sensorID else { return }
            viewModel.reloadCachedHistory()
        }
        .onChange(of: selectedRange) { _ in
            selectedPoint = nil
        }
    }

    // MARK: - current measurements

    private func currentStateRow(snapshot: SensorNoiseHistorySnapshot) -> some View {
        let state = displayState(snapshot: snapshot)

        return HStack(spacing: 10) {
            Circle()
                .fill(state.displayColor)
                .frame(width: 11, height: 11)
                .overlay {
                    Circle()
                        .stroke(state.displayColor.opacity(0.35), lineWidth: 5)
                }

            Text(state.localizedTitle)
                .font(.body)
                .foregroundStyle(state.displayColor)

            Spacer()

            if let currentMeasurementsDetail {
                Text(currentMeasurementsDetail)
                    .foregroundStyle(Color(.colorSecondary))
            }
        }
        .padding(.vertical, 2)
    }

    private func sensorNoiseSensitivityRow() -> some View {
        NavigationLink {
            SensorNoiseSensitivitySelectionView(
                selectedSensitivity: sensorNoiseSensitivity,
                onSelect: updateSensorNoiseSensitivity
            )
        } label: {
            HStack {
                Text(Texts_SettingsView.sensorNoiseSensitivity)

                Spacer()

                Text(sensorNoiseSensitivity.description)
                    .foregroundStyle(Color(.colorSecondary))
            }
        }
    }

    /// Keeps the local display state aligned with the persisted app-wide setting.
    private func refreshSensorNoiseSensitivity() {
        sensorNoiseSensitivity = UserDefaults.standard.sensorNoiseSensitivity
    }

    /// Stores the new sensitivity and refreshes this view immediately.
    private func updateSensorNoiseSensitivity(_ sensitivity: SensorNoiseSensitivity) {
        UserDefaults.standard.sensorNoiseSensitivity = sensitivity
        sensorNoiseSensitivity = sensitivity
    }

    private func displayState(snapshot: SensorNoiseHistorySnapshot) -> SensorNoiseState {
        ConstantsSensorNoise.displayState(
            rawState: snapshot.state,
            shortTermNoise: snapshot.shortTermNoise,
            longTermNoise: snapshot.longTermNoise,
            sensitivity: sensorNoiseSensitivity
        )
    }

    // MARK: - history chart

    /// Builds the selected range and falls back to its newest point until the user touches the chart.
    private func noiseHistoryChart(snapshot: SensorNoiseHistorySnapshot, chartHeight: CGFloat) -> some View {
        let chartData = SensorNoiseChartData(
            snapshot: snapshot,
            range: selectedRange,
            isMgDl: isMgDl
        )
        let displayedPoint = selectedPoint ?? chartData.points.last

        return VStack(alignment: .leading, spacing: 14) {
            if let displayedPoint {
                HStack(spacing: 8) {
                    Text(displayedPoint.timeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .short))
                        .font(.footnote.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)

                    Spacer()

                    noiseValuePill(
                        label: Texts_HomeView.sensorNoiseHistoryShortCompact,
                        value: displayedPoint.shortTermNoise
                    )
                    noiseValuePill(
                        label: Texts_HomeView.sensorNoiseHistoryLongCompact,
                        value: displayedPoint.longTermNoise
                    )
                }
            }

            Group {
                if chartData.points.isEmpty {
                    VStack(spacing: 9) {
                        if viewModel.isBuildingHistory {
                            ProgressView()
                        } else {
                            Image(systemName: "waveform.path.ecg.rectangle")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(Color(.systemGray))
                        }

                        Text(
                            viewModel.isBuildingHistory
                                ? Texts_HomeView.sensorNoiseHistoryLoading
                                : Texts_HomeView.sensorNoiseHistoryNoDataTitle
                        )
                        .font(.subheadline)
                        .fontWeight(.semibold)

                        Text(Texts_HomeView.sensorNoiseHistoryNoDataMessage)
                            .font(.caption)
                            .foregroundStyle(Color(.colorSecondary))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: chartHeight)
                } else {
                    chart(
                        chartData: chartData,
                        displayedPoint: displayedPoint,
                        chartHeight: chartHeight
                    )
                }
            }

            Picker(Texts_HomeView.sensorNoiseHistoryRangeTitle, selection: $selectedRange) {
                ForEach(SensorNoiseHistoryRange.allCases) { range in
                    Text(range.localizedTitle).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func noiseValuePill(label: String, value: Double?) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundStyle(Color(.colorSecondary))
            Text(value.map(displayNoiseValue) ?? "-")
                .foregroundStyle(
                    value.map { ConstantsSensorNoise.state(for: $0, sensitivity: sensorNoiseSensitivity).displayColor }
                        ?? Color(.colorSecondary)
                )
        }
        .font(.subheadline.monospacedDigit())
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color(.systemGray6), in: Capsule())
        .accessibilityLabel(label + " " + (value.map(displayNoiseValue) ?? Texts_Common.notAvailable))
    }

    /// Draws both noise windows, threshold bands and the currently selected reading.
    private func chart(
        chartData: SensorNoiseChartData,
        displayedPoint: SensorNoiseHistoryPoint?,
        chartHeight: CGFloat
    ) -> some View {
        Chart {
            RectangleMark(
                xStart: .value("Start", chartData.domain.lowerBound),
                xEnd: .value("End", chartData.domain.upperBound),
                yStart: .value("Low start", 0),
                yEnd: .value("Low end", chartData.elevatedThreshold)
            )
            .foregroundStyle(ConstantsAppColors.normal.opacity(0.055))

            RectangleMark(
                xStart: .value("Start", chartData.domain.lowerBound),
                xEnd: .value("End", chartData.domain.upperBound),
                yStart: .value("Elevated start", chartData.elevatedThreshold),
                yEnd: .value("Elevated end", chartData.veryHighThreshold)
            )
            .foregroundStyle(ConstantsAppColors.warning.opacity(0.07))

            RectangleMark(
                xStart: .value("Start", chartData.domain.lowerBound),
                xEnd: .value("End", chartData.domain.upperBound),
                yStart: .value("Very high start", chartData.veryHighThreshold),
                yEnd: .value("Very high end", chartData.extremeThreshold)
            )
            .foregroundStyle(ConstantsAppColors.caution.opacity(0.075))

            RectangleMark(
                xStart: .value("Start", chartData.domain.lowerBound),
                xEnd: .value("End", chartData.domain.upperBound),
                yStart: .value("Extreme start", chartData.extremeThreshold),
                yEnd: .value("Extreme end", chartData.yMaximum)
            )
            .foregroundStyle(ConstantsAppColors.urgent.opacity(0.075))

            ForEach(chartData.thresholds, id: \.self) { threshold in
                RuleMark(y: .value("Noise threshold", threshold))
                    .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [3, 4]))
                    .foregroundStyle(Color(.systemGray2).opacity(0.35))
            }

            ForEach(chartData.shortSegments) { segment in
                LineMark(
                    x: .value("Time", segment.startDate),
                    y: .value("Noise", segment.startValue),
                    series: .value("Segment", segment.id)
                )
                .lineStyle(StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .foregroundStyle(segment.color.opacity(chartData.shortLineOpacity))

                LineMark(
                    x: .value("Time", segment.endDate),
                    y: .value("Noise", segment.endValue),
                    series: .value("Segment", segment.id)
                )
                .lineStyle(StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .foregroundStyle(segment.color.opacity(chartData.shortLineOpacity))
            }

            ForEach(chartData.longSegments) { segment in
                LineMark(
                    x: .value("Time", segment.startDate),
                    y: .value("Noise", segment.startValue),
                    series: .value("Segment", segment.id)
                )
                .lineStyle(StrokeStyle(lineWidth: 2.75, lineCap: .round, lineJoin: .round, dash: [7, 4]))
                .foregroundStyle(segment.color.opacity(chartData.longLineOpacity))

                LineMark(
                    x: .value("Time", segment.endDate),
                    y: .value("Noise", segment.endValue),
                    series: .value("Segment", segment.id)
                )
                .lineStyle(StrokeStyle(lineWidth: 2.75, lineCap: .round, lineJoin: .round, dash: [7, 4]))
                .foregroundStyle(segment.color.opacity(chartData.longLineOpacity))
            }

            ForEach(chartData.trendPoints) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Trend", point.value)
                )
                .lineStyle(StrokeStyle(lineWidth: 3.25, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.white.opacity(0.82))
            }

            if let displayedPoint {
                RuleMark(x: .value("Selected time", displayedPoint.timeStamp))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.white.opacity(0.65))

                if let shortTermNoise = displayedPoint.shortTermNoise {
                    PointMark(
                        x: .value("Selected time", displayedPoint.timeStamp),
                        y: .value("Short noise", chartData.displayValue(shortTermNoise))
                    )
                    .symbolSize(48)
                    .foregroundStyle(ConstantsSensorNoise.state(for: shortTermNoise, sensitivity: sensorNoiseSensitivity).displayColor)
                }

                if let longTermNoise = displayedPoint.longTermNoise {
                    PointMark(
                        x: .value("Selected time", displayedPoint.timeStamp),
                        y: .value("Long noise", chartData.displayValue(longTermNoise))
                    )
                    .symbolSize(35)
                    .foregroundStyle(ConstantsSensorNoise.state(for: longTermNoise, sensitivity: sensorNoiseSensitivity).displayColor)
                }
            }
        }
        .chartXAxis {
            if let xAxisDates = chartData.xAxisDates {
                AxisMarks(values: xAxisDates) { value in
                    AxisGridLine()
                        .foregroundStyle(Color(.systemGray3).opacity(0.18))
                    AxisTick()
                        .foregroundStyle(Color(.systemGray2))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(chartData.xAxisLabel(for: date))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Color(.colorSecondary))
                        }
                    }
                }
            } else {
                AxisMarks(values: .automatic(desiredCount: chartData.xAxisMarkCount)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color(.systemGray3).opacity(0.18))
                    AxisTick()
                        .foregroundStyle(Color(.systemGray2))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(chartData.xAxisLabel(for: date))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Color(.colorSecondary))
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                    .foregroundStyle(Color(.systemGray3).opacity(0.16))
                AxisValueLabel {
                    if let noise = value.as(Double.self) {
                        Text(chartData.yAxisLabel(for: noise))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }
            }
        }
        .chartXScale(domain: chartData.domain)
        .chartYScale(domain: 0 ... chartData.yMaximum)
        .chartOverlay { chartProxy in
            GeometryReader { geometryProxy in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let plotFrame = geometryProxy[chartProxy.plotAreaFrame]
                                let xPosition = gesture.location.x - plotFrame.origin.x

                                guard xPosition >= 0,
                                      xPosition <= plotFrame.width,
                                      let date: Date = chartProxy.value(atX: xPosition) else { return }

                                selectedPoint = chartData.nearestPoint(to: date)
                            }
                    )
            }
        }
        .frame(height: chartHeight)
        .padding(.top, 2)
        .accessibilityLabel(Texts_HomeView.sensorNoiseHistoryChartAccessibility)
    }

    private func displayNoiseValue(_ noiseInMgDl: Double) -> String {
        let value = noiseInMgDl.mgDlToMmol(mgDl: isMgDl)
        return isMgDl
            ? value.formatted(.number.precision(.fractionLength(1)))
            : value.formatted(.number.precision(.fractionLength(2)))
    }
}

// MARK: - sensitivity picker

private struct SensorNoiseSensitivitySelectionView: View {
    let selectedSensitivity: SensorNoiseSensitivity
    let onSelect: (SensorNoiseSensitivity) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(SensorNoiseSensitivity.allCases, id: \.self) { sensitivity in
                    Button {
                        onSelect(sensitivity)
                        dismiss()
                    } label: {
                        HStack {
                            Text(sensitivity.description)
                                .foregroundStyle(Color(.colorPrimary))

                            Spacer()

                            if selectedSensitivity == sensitivity {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(Texts_SettingsView.sensorNoiseSensitivityFooter)
            }
        }
        .navigationTitle(Texts_SettingsView.sensorNoiseSensitivity)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - view model

@MainActor private final class SensorNoiseHistoryViewModel: ObservableObject {
    @Published private(set) var snapshot: SensorNoiseHistorySnapshot?
    @Published private(set) var isBuildingHistory = false

    private let sensorID: String
    private let sensorNoiseManager: SensorNoiseManager
    private var hasLoaded = false

    init(sensorID: String, sensorNoiseManager: SensorNoiseManager) {
        self.sensorID = sensorID
        self.sensorNoiseManager = sensorNoiseManager
    }

    /// Loads cached points immediately and starts the one-time session rebuild when required.
    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        snapshot = sensorNoiseManager.historySnapshot(sensorID: sensorID)
        isBuildingHistory = sensorNoiseManager.rebuildHistoryIfNeeded(sensorID: sensorID) { [weak self] in
            guard let self else { return }
            self.snapshot = self.sensorNoiseManager.historySnapshot(sensorID: self.sensorID)
            self.isBuildingHistory = false
        }
    }

    /// Refreshes the detached snapshot after the manager stores or rebuilds history.
    func reloadCachedHistory() {
        snapshot = sensorNoiseManager.historySnapshot(sensorID: sensorID)
    }
}

// MARK: - sensor management summary

/// Compact current noise indicator used by the parent sensor management screen.
struct SensorNoiseSummaryRow: View {
    let shortTermNoise: Double?
    let longTermNoise: Double?
    let state: SensorNoiseState
    let isMgDl: Bool

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .fill(state.displayColor)
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .stroke(state.displayColor.opacity(0.3), lineWidth: 5)
                }

            Text(state.localizedTitle)
                .font(.body)
                .foregroundStyle(state.displayColor)

            Spacer()

            compactNoiseValues
        }
        .padding(.vertical, 3)
    }

    private var compactNoiseValues: some View {
        HStack(spacing: 5) {
            Text(displayValue(shortTermNoise))
                .foregroundStyle(
                    shortTermNoise.map { ConstantsSensorNoise.state(for: $0, sensitivity: UserDefaults.standard.sensorNoiseSensitivity).displayColor }
                        ?? Color(.colorSecondary)
                )
            Text("/")
                .foregroundStyle(Color(.colorSecondary))
            Text(displayValue(longTermNoise))
                .foregroundStyle(
                    longTermNoise.map { ConstantsSensorNoise.state(for: $0, sensitivity: UserDefaults.standard.sensorNoiseSensitivity).displayColor }
                        ?? Color(.colorSecondary)
                )
        }
        .font(.body.monospacedDigit())
    }

    private func displayValue(_ value: Double?) -> String {
        value.map(displayValue) ?? "-"
    }

    private func displayValue(_ value: Double) -> String {
        let displayValue = value.mgDlToMmol(mgDl: isMgDl)
        return isMgDl
            ? displayValue.formatted(.number.precision(.fractionLength(1)))
            : displayValue.formatted(.number.precision(.fractionLength(2)))
    }
}

/// Lower-is-better gauge for one persisted noise window.
private struct SensorNoiseGaugeRow: View {
    let title: String
    let noiseInMgDl: Double?
    let coverage: Double
    let isMgDl: Bool
    let sensitivity: SensorNoiseSensitivity

    private var maximumGaugeValue: Double {
        ConstantsSensorNoise.extremeNoiseStandardDeviation * 1.25
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if let noiseInMgDl {
                    Text(displayValue(noiseInMgDl))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(ConstantsSensorNoise.state(for: noiseInMgDl, sensitivity: sensitivity).displayColor)
                } else {
                    Text(Texts_HomeView.sensorManagementNoiseCollecting)
                        .font(.caption)
                        .foregroundStyle(Color(.colorSecondary))
                }
            }

            if let noiseInMgDl {
                Gauge(value: min(max(noiseInMgDl, 0), maximumGaugeValue), in: 0 ... maximumGaugeValue) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinear)
                .tint(ConstantsSensorNoise.state(for: noiseInMgDl, sensitivity: sensitivity).displayColor)
            } else {
                ProgressView(value: min(max(coverage, 0), 1))
                    .tint(Color(.systemGray))
            }
        }
        .padding(.vertical, 3)
    }

    private func displayValue(_ noiseInMgDl: Double) -> String {
        let displayNoise = noiseInMgDl.mgDlToMmol(mgDl: isMgDl)
        let value = isMgDl
            ? displayNoise.formatted(.number.precision(.fractionLength(1)))
            : displayNoise.formatted(.number.precision(.fractionLength(2)))
        return value + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }
}

// MARK: - chart models

private enum SensorNoiseHistoryRange: String, CaseIterable, Identifiable {
    case day
    case threeDays
    case week
    case all

    var id: String { rawValue }

    var chartOrder: Int {
        switch self {
        case .day:
            return 0
        case .threeDays:
            return 1
        case .week:
            return 2
        case .all:
            return 3
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .day:
            return 24 * 60 * 60
        case .threeDays:
            return 3 * 24 * 60 * 60
        case .week:
            return 7 * 24 * 60 * 60
        case .all:
            return nil
        }
    }

    var localizedTitle: String {
        switch self {
        case .day:
            return Texts_HomeView.sensorNoiseHistoryDayRange
        case .threeDays:
            return Texts_HomeView.sensorNoiseHistoryThreeDayRange
        case .week:
            return Texts_HomeView.sensorNoiseHistoryWeekRange
        case .all:
            return Texts_HomeView.sensorNoiseHistoryAllRange
        }
    }
}

private struct SensorNoiseChartSegment: Identifiable {
    let id: String
    let startDate: Date
    let endDate: Date
    let startValue: Double
    let endValue: Double
    let color: Color
}

private struct SensorNoiseChartTrendPoint: Identifiable {
    let date: Date
    let value: Double

    var id: TimeInterval { date.timeIntervalSince1970 }
}

private struct SensorNoiseChartData {
    private static let trendMinimumRange: SensorNoiseHistoryRange = .threeDays
    private static let shortLineStandardOpacity = 0.32
    private static let shortLineTrendOpacity = 0.10
    private static let shortLineWideTrendOpacity = 0.055
    private static let longLineStandardOpacity = 1.0
    private static let longLineTrendOpacity = 0.30
    private static let longLineWideTrendOpacity = 0.16

    let points: [SensorNoiseHistoryPoint]
    let range: SensorNoiseHistoryRange
    let domain: ClosedRange<Date>
    let yMaximum: Double
    let elevatedThreshold: Double
    let veryHighThreshold: Double
    let extremeThreshold: Double
    let isMgDl: Bool
    let shortSegments: [SensorNoiseChartSegment]
    let longSegments: [SensorNoiseChartSegment]
    let xAxisDates: [Date]?
    let trendPoints: [SensorNoiseChartTrendPoint]

    /// Prepares only the selected time range and reduces its render cost without bridging data gaps.
    init(snapshot: SensorNoiseHistorySnapshot, range: SensorNoiseHistoryRange, isMgDl: Bool) {
        self.isMgDl = isMgDl
        self.range = range

        let latestPointDate = snapshot.points.last?.timeStamp ?? snapshot.sensorStartDate
        let proposedEndDate = snapshot.sensorEndDate ?? max(Date(), latestPointDate)
        let endDate = max(proposedEndDate, snapshot.sensorStartDate.addingTimeInterval(60))
        let proposedStartDate = range.duration.map { endDate.addingTimeInterval(-$0) } ?? snapshot.sensorStartDate
        let startDate = max(snapshot.sensorStartDate, proposedStartDate)
        domain = startDate ... endDate
        switch range {
        case .day:
            xAxisDates = Self.hourlyXAxisDates(from: startDate, to: endDate)
        case .threeDays:
            xAxisDates = Self.dailyXAxisDates(from: startDate, to: endDate)
        case .week, .all:
            xAxisDates = nil
        }
        let sensitivity = UserDefaults.standard.sensorNoiseSensitivity

        let visiblePoints = snapshot.points.filter { $0.timeStamp >= startDate && $0.timeStamp <= endDate }
        let contiguousGroups = Self.contiguousGroups(visiblePoints)
        let bucketsPerGroup = max(12, 180 / max(contiguousGroups.count, 1))
        let displayGroups = contiguousGroups.map { Self.downsample($0, maximumBuckets: bucketsPerGroup) }
        points = displayGroups.flatMap { $0 }

        elevatedThreshold = ConstantsSensorNoise.threshold(ConstantsSensorNoise.elevatedNoiseStandardDeviation, sensitivity: sensitivity).mgDlToMmol(mgDl: isMgDl)
        veryHighThreshold = ConstantsSensorNoise.threshold(ConstantsSensorNoise.veryHighNoiseStandardDeviation, sensitivity: sensitivity).mgDlToMmol(mgDl: isMgDl)
        extremeThreshold = ConstantsSensorNoise.threshold(ConstantsSensorNoise.extremeNoiseStandardDeviation, sensitivity: sensitivity).mgDlToMmol(mgDl: isMgDl)

        shortSegments = Self.segments(pointGroups: displayGroups, isLongTerm: false, isMgDl: isMgDl, sensitivity: sensitivity)
        longSegments = Self.segments(pointGroups: displayGroups, isLongTerm: true, isMgDl: isMgDl, sensitivity: sensitivity)
        trendPoints = Self.trendPoints(points: visiblePoints, range: range, isMgDl: isMgDl)

        let largestObservedValue = points.flatMap { point in
            [point.shortTermNoise, point.longTermNoise].compactMap { $0 }
        }
        .max()?
        .mgDlToMmol(mgDl: isMgDl) ?? 0
        let largestTrendValue = trendPoints.map(\.value).max() ?? 0
        yMaximum = max(extremeThreshold * 1.16, largestObservedValue * 1.12, largestTrendValue * 1.12)
    }

    var thresholds: [Double] {
        [elevatedThreshold, veryHighThreshold, extremeThreshold]
    }

    var xAxisMarkCount: Int {
        domain.upperBound.timeIntervalSince(domain.lowerBound) > 3 * 24 * 60 * 60 ? 4 : 5
    }

    var shortLineOpacity: Double {
        guard !trendPoints.isEmpty else { return Self.shortLineStandardOpacity }

        return range.chartOrder >= SensorNoiseHistoryRange.week.chartOrder
            ? Self.shortLineWideTrendOpacity
            : Self.shortLineTrendOpacity
    }

    var longLineOpacity: Double {
        guard !trendPoints.isEmpty else { return Self.longLineStandardOpacity }

        return range.chartOrder >= SensorNoiseHistoryRange.week.chartOrder
            ? Self.longLineWideTrendOpacity
            : Self.longLineTrendOpacity
    }

    func displayValue(_ noiseInMgDl: Double) -> Double {
        noiseInMgDl.mgDlToMmol(mgDl: isMgDl)
    }

    func nearestPoint(to date: Date) -> SensorNoiseHistoryPoint? {
        points.min { first, second in
            abs(first.timeStamp.timeIntervalSince(date)) < abs(second.timeStamp.timeIntervalSince(date))
        }
    }

    /// Uses hour labels for short ranges and compact calendar dates for longer ranges.
    func xAxisLabel(for date: Date) -> String {
        if domain.upperBound.timeIntervalSince(domain.lowerBound) <= 24 * 60 * 60 {
            return date.formatted(.dateTime.hour())
        }

        if domain.upperBound.timeIntervalSince(domain.lowerBound) >= 2 * 24 * 60 * 60 {
            return date.formatted(.dateTime.day().month(.abbreviated))
        }

        return date.formatted(.dateTime.hour().minute())
    }

    func yAxisLabel(for value: Double) -> String {
        isMgDl
            ? value.formatted(.number.precision(.fractionLength(0)))
            : value.formatted(.number.precision(.fractionLength(1)))
    }

    /// Returns stable four-hour marks for the 24-hour view instead of shifting automatic labels.
    private static func hourlyXAxisDates(from startDate: Date, to endDate: Date) -> [Date] {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour], from: startDate)

        guard var date = calendar.date(from: startComponents) else { return [] }

        if date <= startDate, let nextHour = calendar.date(byAdding: .hour, value: 1, to: date) {
            date = nextHour
        }

        var dates = [Date]()

        while date < endDate {
            if calendar.component(.hour, from: date) % 4 == 0 {
                dates.append(date)
            }

            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: date), nextHour > date else {
                break
            }

            date = nextHour
        }

        return dates
    }

    /// Returns one midnight marker per calendar day for the 3-day view.
    private static func dailyXAxisDates(from startDate: Date, to endDate: Date) -> [Date] {
        let calendar = Calendar.current
        guard var date = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: startDate)) else { return [] }

        var dates = [Date]()

        while date < endDate {
            dates.append(date)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date else {
                break
            }

            date = nextDate
        }

        return dates
    }

    /// Builds independently colored line segments for one measurement window.
    private static func segments(
        pointGroups: [[SensorNoiseHistoryPoint]],
        isLongTerm: Bool,
        isMgDl: Bool,
        sensitivity: SensorNoiseSensitivity
    ) -> [SensorNoiseChartSegment] {
        var segmentIndex = 0
        var result = [SensorNoiseChartSegment]()

        for points in pointGroups where points.count > 1 {
            for pair in zip(points, points.dropFirst()) {
                defer { segmentIndex += 1 }

                let startNoise = isLongTerm ? pair.0.longTermNoise : pair.0.shortTermNoise
                let endNoise = isLongTerm ? pair.1.longTermNoise : pair.1.shortTermNoise
                guard let startNoise, let endNoise else { continue }

                let state: SensorNoiseState
                if pair.0.state == .flatlineSuspected || pair.1.state == .flatlineSuspected {
                    state = .flatlineSuspected
                } else {
                    state = ConstantsSensorNoise.state(for: max(startNoise, endNoise), sensitivity: sensitivity)
                }

                result.append(
                    SensorNoiseChartSegment(
                        id: (isLongTerm ? "long-" : "short-") + String(segmentIndex),
                        startDate: pair.0.timeStamp,
                        endDate: pair.1.timeStamp,
                        startValue: startNoise.mgDlToMmol(mgDl: isMgDl),
                        endValue: endNoise.mgDlToMmol(mgDl: isMgDl),
                        color: state.displayColor
                    )
                )
            }
        }

        return result
    }

    /// Builds one straight best-fit line so wider charts show the session's overall noise direction.
    private static func trendPoints(points: [SensorNoiseHistoryPoint], range: SensorNoiseHistoryRange, isMgDl: Bool) -> [SensorNoiseChartTrendPoint] {
        guard range.chartOrder >= Self.trendMinimumRange.chartOrder else { return [] }

        let sourcePoints = points.compactMap { point -> (date: Date, value: Double)? in
            let noise = point.longTermNoise ?? point.shortTermNoise
            guard let noise else { return nil }

            return (point.timeStamp, noise)
        }

        guard sourcePoints.count >= 3,
              let firstDate = sourcePoints.first?.date,
              let lastDate = sourcePoints.last?.date,
              lastDate > firstDate else {
            return []
        }

        let xValues = sourcePoints.map { $0.date.timeIntervalSince(firstDate) }
        let yValues = sourcePoints.map(\.value)
        let meanX = xValues.reduce(0, +) / Double(xValues.count)
        let meanY = yValues.reduce(0, +) / Double(yValues.count)
        let covariance = zip(xValues, yValues).reduce(0.0) { $0 + (($1.0 - meanX) * ($1.1 - meanY)) }
        let variance = xValues.reduce(0.0) { $0 + (($1 - meanX) * ($1 - meanX)) }

        guard variance > 0 else { return [] }

        let slope = covariance / variance
        let intercept = meanY - (slope * meanX)
        let startValue = max(intercept, 0)
        let endX = lastDate.timeIntervalSince(firstDate)
        let endValue = max(intercept + (slope * endX), 0)

        return [
            SensorNoiseChartTrendPoint(date: firstDate, value: startValue.mgDlToMmol(mgDl: isMgDl)),
            SensorNoiseChartTrendPoint(date: lastDate, value: endValue.mgDlToMmol(mgDl: isMgDl))
        ]
    }

    /// Splits points at missing-reading gaps so the chart never draws a misleading connecting line.
    private static func contiguousGroups(_ points: [SensorNoiseHistoryPoint]) -> [[SensorNoiseHistoryPoint]] {
        guard let firstPoint = points.first else { return [] }

        var groups = [[firstPoint]]

        for point in points.dropFirst() {
            guard let previousPoint = groups.last?.last else { continue }

            if point.timeStamp.timeIntervalSince(previousPoint.timeStamp) > ConstantsSensorNoise.maximumGap {
                groups.append([point])
            } else {
                groups[groups.count - 1].append(point)
            }
        }

        return groups
    }

    /// Reduces rendering cost while preserving endpoints and the largest values in each bucket.
    private static func downsample(
        _ points: [SensorNoiseHistoryPoint],
        maximumBuckets: Int
    ) -> [SensorNoiseHistoryPoint] {
        guard points.count > maximumBuckets * 4 else { return points }

        let bucketSize = Int(ceil(Double(points.count) / Double(maximumBuckets)))
        var reduced = [SensorNoiseHistoryPoint]()
        reduced.reserveCapacity(maximumBuckets * 4)

        for bucketStart in stride(from: 0, to: points.count, by: bucketSize) {
            let bucketEnd = min(bucketStart + bucketSize, points.count)
            let bucket = Array(points[bucketStart ..< bucketEnd])
            var candidates = [bucket.first, bucket.last]
            candidates.append(bucket.max { ($0.shortTermNoise ?? -1) < ($1.shortTermNoise ?? -1) })
            candidates.append(bucket.max { ($0.longTermNoise ?? -1) < ($1.longTermNoise ?? -1) })

            let uniqueCandidates = candidates.compactMap { $0 }.reduce(into: [String: SensorNoiseHistoryPoint]()) {
                $0[$1.id] = $1
            }
            reduced.append(contentsOf: uniqueCandidates.values.sorted { $0.timeStamp < $1.timeStamp })
        }

        return reduced.sorted { $0.timeStamp < $1.timeStamp }
    }
}

// MARK: - display helpers

extension SensorNoiseState {
    var localizedTitle: String {
        switch self {
        case .collecting:
            return Texts_HomeView.sensorManagementNoiseCollecting
        case .low:
            return Texts_HomeView.sensorManagementNoiseLow
        case .elevated:
            return Texts_HomeView.sensorManagementNoiseElevated
        case .veryHigh:
            return Texts_HomeView.sensorManagementNoiseVeryHigh
        case .extreme:
            return Texts_HomeView.sensorManagementNoiseExtreme
        case .flatlineSuspected:
            return Texts_HomeView.sensorNoiseWarningFlatlineTitle
        }
    }

    var displayColor: Color {
        switch self {
        case .collecting:
            return Color(.systemGray)
        case .low:
            return ConstantsAppColors.normal
        case .elevated:
            return ConstantsAppColors.warning
        case .veryHigh:
            return ConstantsAppColors.caution
        case .extreme, .flatlineSuspected:
            return ConstantsAppColors.urgent
        }
    }
}
