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
    private let sensorStartDate: Date
    private let isMgDl: Bool
    private let currentMeasurementsDetail: String?

    init(
        sensorID: String,
        sensorStartDate: Date,
        sensorNoiseManager: SensorNoiseManager,
        isMgDl: Bool,
        currentMeasurementsDetail: String? = nil
    ) {
        self.sensorID = sensorID
        self.sensorStartDate = sensorStartDate
        self.isMgDl = isMgDl
        self.currentMeasurementsDetail = currentMeasurementsDetail
        // Open directly on the widest meaningful range so the history view immediately shows the
        // full sensor context, while still letting the picker keep user changes during this session.
        _selectedRange = State(
            initialValue: SensorNoiseHistoryRange.availableRanges(
                sensorStartDate: sensorStartDate,
                sensorEndDate: nil
            ).last ?? .day
        )
        _viewModel = StateObject(
            wrappedValue: SensorNoiseHistoryViewModel(
                sensorID: sensorID,
                sensorStartDate: sensorStartDate,
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

                        SensorNoiseGaugeRow(
                            title: Texts_HomeView.sensorManagementNoisePersistent,
                            noiseInMgDl: snapshot.persistentNoise,
                            coverage: snapshot.persistentCoverage,
                            isMgDl: isMgDl,
                            sensitivity: sensorNoiseSensitivity
                        )
                    } header: {
                        Text(Texts_HomeView.sensorNoiseHistoryCurrentTitle)
                    }

                    Section {
                        noiseHistoryChart(
                            snapshot: snapshot,
                            chartHeight: max(110, (geometry.size.height - 430) * 0.55)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(.vertical, 2)
    }

    /// Keeps the local display state aligned with the persisted app-wide setting.
    private func refreshSensorNoiseSensitivity() {
        sensorNoiseSensitivity = UserDefaults.standard.sensorNoiseSensitivity
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
        let availableRanges = SensorNoiseHistoryRange.availableRanges(sensorStartDate: snapshot.sensorStartDate, sensorEndDate: snapshot.sensorEndDate)
        // The picker hides ranges that are not useful for the current sensor age. If the old state
        // points at a hidden range, use the widest currently available range until the user picks another one.
        let effectiveRange = availableRanges.contains(selectedRange) ? selectedRange : (availableRanges.last ?? .day)
        let chartData = SensorNoiseChartData(
            snapshot: snapshot,
            range: effectiveRange,
            isMgDl: isMgDl
        )
        let displayedPoint = selectedPoint ?? chartData.points.last

        return VStack(alignment: .leading, spacing: 14) {
            if let displayedPoint {
                Text(displayedPoint.timeStamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color(.colorSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    noiseValuePill(
                        label: Texts_HomeView.sensorNoiseHistoryShortCompact,
                        value: displayedPoint.shortTermNoise
                    )
                    noiseValuePill(
                        label: Texts_HomeView.sensorNoiseHistoryLongCompact,
                        value: displayedPoint.longTermNoise
                    )
                    noiseValuePill(
                        label: Texts_HomeView.sensorNoiseHistoryPersistentCompact,
                        value: displayedPoint.persistentNoise
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

            Picker(
                Texts_HomeView.sensorNoiseHistoryRangeTitle,
                selection: Binding(
                    get: { effectiveRange },
                    set: { selectedRange = $0 }
                )
            ) {
                ForEach(availableRanges) { range in
                    Text(range.localizedTitle(sensorStartDate: snapshot.sensorStartDate, sensorEndDate: snapshot.sensorEndDate)).tag(range)
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
        .frame(maxWidth: .infinity)
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

            ForEach(chartData.persistentSegments) { segment in
                LineMark(
                    x: .value("Time", segment.startDate),
                    y: .value("Noise", segment.startValue),
                    series: .value("Segment", segment.id)
                )
                .lineStyle(StrokeStyle(lineWidth: 3.25, lineCap: .round, lineJoin: .round, dash: [2, 4]))
                .foregroundStyle(segment.color.opacity(0.9))

                LineMark(
                    x: .value("Time", segment.endDate),
                    y: .value("Noise", segment.endValue),
                    series: .value("Segment", segment.id)
                )
                .lineStyle(StrokeStyle(lineWidth: 3.25, lineCap: .round, lineJoin: .round, dash: [2, 4]))
                .foregroundStyle(segment.color.opacity(0.9))
            }

            ForEach(chartData.trendPoints) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Trend", point.value)
                )
                .lineStyle(StrokeStyle(lineWidth: 3.75, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.cyan)
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

                if let persistentNoise = displayedPoint.persistentNoise {
                    PointMark(
                        x: .value("Selected time", displayedPoint.timeStamp),
                        y: .value("Persistent noise", chartData.displayValue(persistentNoise))
                    )
                    .symbolSize(58)
                    .foregroundStyle(ConstantsSensorNoise.state(for: persistentNoise, sensitivity: sensorNoiseSensitivity).displayColor)
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

// MARK: - view model

@MainActor private final class SensorNoiseHistoryViewModel: ObservableObject {
    @Published private(set) var snapshot: SensorNoiseHistorySnapshot?
    @Published private(set) var isBuildingHistory = false

    private let sensorID: String
    private let sensorStartDate: Date
    private let sensorNoiseManager: SensorNoiseManager
    private var hasLoaded = false

    init(sensorID: String, sensorStartDate: Date, sensorNoiseManager: SensorNoiseManager) {
        self.sensorID = sensorID
        self.sensorStartDate = sensorStartDate
        self.sensorNoiseManager = sensorNoiseManager
    }

    /// Loads cached points immediately and starts the one-time session rebuild when required.
    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        snapshot = sensorNoiseManager.historySnapshot(sensorID: sensorID, sessionStartDate: sensorStartDate)
        isBuildingHistory = sensorNoiseManager.rebuildHistoryIfNeeded(sensorID: sensorID, sessionStartDate: sensorStartDate) { [weak self] in
            guard let self else { return }
            self.snapshot = self.sensorNoiseManager.historySnapshot(sensorID: self.sensorID, sessionStartDate: self.sensorStartDate)
            self.isBuildingHistory = false
        }
    }

    /// Refreshes the detached snapshot after the manager stores or rebuilds history.
    func reloadCachedHistory() {
        snapshot = sensorNoiseManager.historySnapshot(sensorID: sensorID, sessionStartDate: sensorStartDate)
    }
}

// MARK: - sensor management summary

/// Compact current noise indicator used by the parent sensor management screen.
struct SensorNoiseSummaryRow: View {
    let shortTermNoise: Double?
    let longTermNoise: Double?
    let persistentNoise: Double?
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
            Text("/")
                .foregroundStyle(Color(.colorSecondary))
            Text(displayValue(persistentNoise))
                .foregroundStyle(
                    persistentNoise.map { ConstantsSensorNoise.state(for: $0, sensitivity: UserDefaults.standard.sensorNoiseSensitivity).displayColor }
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

    private static let minimumFullSessionChartDuration: TimeInterval = 6 * 60 * 60
    private static let minimumDistinctRangeDifference: TimeInterval = 60 * 60

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

    /// Only shows chart widths that add useful information for the current sensor age.
    ///
    /// The full-session option is always available for new sensors and replaces `1d` until the
    /// sensor has at least one extra hour of data. Fixed ranges are then added only when they are
    /// meaningfully smaller than the current full session.
    static func availableRanges(sensorStartDate: Date, sensorEndDate: Date?) -> [SensorNoiseHistoryRange] {
        let endDate = sensorEndDate ?? Date()
        let elapsed = max(endDate.timeIntervalSince(sensorStartDate), 0)
        var ranges = [SensorNoiseHistoryRange]()

        if elapsed >= ((SensorNoiseHistoryRange.day.duration ?? 0) + Self.minimumDistinctRangeDifference) {
            ranges.append(.day)
        }

        if elapsed >= (SensorNoiseHistoryRange.threeDays.duration ?? 0) {
            ranges.append(.threeDays)
        }

        if elapsed >= (SensorNoiseHistoryRange.week.duration ?? 0) {
            ranges.append(.week)
        }

        let widestFixedDuration = ranges.last?.duration ?? 0
        if ranges.isEmpty || elapsed >= widestFixedDuration + Self.minimumDistinctRangeDifference {
            ranges.append(.all)
        }

        return ranges
    }

    func chartDuration(sensorStartDate: Date, sensorEndDate: Date?) -> TimeInterval {
        if let duration { return duration }

        let endDate = sensorEndDate ?? Date()
        let elapsed = max(endDate.timeIntervalSince(sensorStartDate), 0)

        return max(elapsed, Self.minimumFullSessionChartDuration)
    }

    func localizedTitle(sensorStartDate: Date, sensorEndDate: Date?) -> String {
        switch self {
        case .day:
            return Texts_HomeView.sensorNoiseHistoryDayRange
        case .threeDays:
            return Texts_HomeView.sensorNoiseHistoryThreeDayRange
        case .week:
            return Texts_HomeView.sensorNoiseHistoryWeekRange
        case .all:
            return Self.fullSessionTitle(sensorStartDate: sensorStartDate, sensorEndDate: sensorEndDate)
        }
    }

    /// Shows the full sensor session as a compact chart-width label.
    private static func fullSessionTitle(sensorStartDate: Date, sensorEndDate: Date?) -> String {
        let endDate = sensorEndDate ?? Date()
        let elapsedHours = max(Int(endDate.timeIntervalSince(sensorStartDate) / (60 * 60)), 0)
        let days = elapsedHours / 24
        let hours = elapsedHours % 24

        // The selector is a chart-width label, so keep it rounded to complete hours. The general
        // Nightscout-style helper can show minutes for short durations, which is too noisy here.
        if days > 0 {
            return "\(days)d\(hours)h"
        }

        return "\(max(hours, 1))h"
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
    private static let trendMinimumRange: SensorNoiseHistoryRange = .day
    private static let trendBucketDuration: TimeInterval = 6 * 60 * 60
    private static let trendRenderPointCount = 40
    private static let shortLineStandardOpacity = 0.2
    private static let shortLineTrendOpacity = shortLineStandardOpacity
    private static let shortLineWideTrendOpacity = shortLineTrendOpacity
    private static let longLineStandardOpacity = 0.5
    private static let longLineTrendOpacity = longLineStandardOpacity
    private static let longLineWideTrendOpacity = longLineTrendOpacity

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
    let persistentSegments: [SensorNoiseChartSegment]
    let xAxisDates: [Date]?
    let trendPoints: [SensorNoiseChartTrendPoint]

    /// Prepares only the selected time range and reduces its render cost without bridging data gaps.
    init(snapshot: SensorNoiseHistorySnapshot, range: SensorNoiseHistoryRange, isMgDl: Bool) {
        self.isMgDl = isMgDl
        self.range = range

        let latestPointDate = snapshot.points.last?.timeStamp ?? snapshot.sensorStartDate
        let proposedEndDate = snapshot.sensorEndDate ?? max(Date(), latestPointDate)
        let endDate = max(proposedEndDate, snapshot.sensorStartDate.addingTimeInterval(60))
        let proposedStartDate = endDate.addingTimeInterval(-range.chartDuration(sensorStartDate: snapshot.sensorStartDate, sensorEndDate: snapshot.sensorEndDate))
        let startDate = range == .all ? proposedStartDate : max(snapshot.sensorStartDate, proposedStartDate)
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

        shortSegments = Self.segments(pointGroups: displayGroups, metric: .short, isMgDl: isMgDl, sensitivity: sensitivity)
        longSegments = Self.segments(pointGroups: displayGroups, metric: .long, isMgDl: isMgDl, sensitivity: sensitivity)
        persistentSegments = Self.segments(pointGroups: displayGroups, metric: .persistent, isMgDl: isMgDl, sensitivity: sensitivity)
        trendPoints = Self.trendPoints(points: visiblePoints, range: range, isMgDl: isMgDl)

        let largestObservedValue = points.flatMap { point in
            [point.shortTermNoise, point.longTermNoise, point.persistentNoise].compactMap { $0 }
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
    private enum Metric {
        case short
        case long
        case persistent
    }

    private static func segments(
        pointGroups: [[SensorNoiseHistoryPoint]],
        metric: Metric,
        isMgDl: Bool,
        sensitivity: SensorNoiseSensitivity
    ) -> [SensorNoiseChartSegment] {
        var segmentIndex = 0
        var result = [SensorNoiseChartSegment]()

        for points in pointGroups where points.count > 1 {
            for pair in zip(points, points.dropFirst()) {
                defer { segmentIndex += 1 }

                let startNoise: Double?
                let endNoise: Double?

                switch metric {
                case .short:
                    startNoise = pair.0.shortTermNoise
                    endNoise = pair.1.shortTermNoise
                case .long:
                    startNoise = pair.0.longTermNoise
                    endNoise = pair.1.longTermNoise
                case .persistent:
                    startNoise = pair.0.persistentNoise
                    endNoise = pair.1.persistentNoise
                }
                guard let startNoise, let endNoise else { continue }

                let state: SensorNoiseState
                if pair.0.state == .flatlineSuspected || pair.1.state == .flatlineSuspected {
                    state = .flatlineSuspected
                } else {
                    state = ConstantsSensorNoise.state(for: max(startNoise, endNoise), sensitivity: sensitivity)
                }

                result.append(
                    SensorNoiseChartSegment(
                        id: String(describing: metric) + "-" + String(segmentIndex),
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

    /// Builds a lifecycle trend curve from bucketed four-hour noise values.
    ///
    /// Six-hour median buckets avoid individual spikes controlling the fit. The quadratic fit allows
    /// the normal sensor pattern of noisy start, quieter middle and possible noisier end, while
    /// keeping the line too constrained to become a wavy moving average.
    ///
    /// NIST describes least-squares polynomial fitting as useful for estimating response shape, and
    /// a simple ln-style response transform as a common way to reduce uneven variance before fitting:
    /// https://www.itl.nist.gov/div898/handbook/ppc/section4/ppc431.htm
    /// https://www.itl.nist.gov/div898/handbook/pmd/section6/pmd624.htm
    private static func trendPoints(points: [SensorNoiseHistoryPoint], range: SensorNoiseHistoryRange, isMgDl: Bool) -> [SensorNoiseChartTrendPoint] {
        guard range.chartOrder >= Self.trendMinimumRange.chartOrder else { return [] }

        let sourcePoints = points.compactMap { point -> (date: Date, value: Double)? in
            guard let noise = point.longTermNoise else { return nil }

            return (point.timeStamp, noise)
        }

        let buckets = trendBuckets(from: sourcePoints)

        guard buckets.count >= 3,
              let firstDate = buckets.first?.date,
              let lastDate = buckets.last?.date,
              lastDate > firstDate else {
            return []
        }

        let duration = lastDate.timeIntervalSince(firstDate)
        let samples = buckets.map { bucket in
            let x = bucket.date.timeIntervalSince(firstDate) / duration

            return (x: x, y: log1p(max(bucket.value, 0)))
        }

        guard let coefficients = quadraticCoefficients(samples: samples) else { return [] }
        let pointCount = max(2, min(Self.trendRenderPointCount, Int(duration / ConstantsSensorNoise.measurementInterval)))

        return (0 ..< pointCount).map { index in
            let ratio = Double(index) / Double(pointCount - 1)
            let date = firstDate.addingTimeInterval(duration * ratio)
            let fittedLogValue = coefficients.a + (coefficients.b * ratio) + (coefficients.c * ratio * ratio)
            let fittedValue = max(expm1(fittedLogValue), 0)

            return SensorNoiseChartTrendPoint(date: date, value: fittedValue.mgDlToMmol(mgDl: isMgDl))
        }
    }

    /// Reduces raw history to one median four-hour noise value per six-hour bucket.
    private static func trendBuckets(from points: [(date: Date, value: Double)]) -> [(date: Date, value: Double)] {
        guard let firstDate = points.first?.date else { return [] }

        let groupedValues = Dictionary(grouping: points) { point in
            Int(point.date.timeIntervalSince(firstDate) / Self.trendBucketDuration)
        }

        return groupedValues.keys.sorted().compactMap { bucketIndex in
            guard let bucketPoints = groupedValues[bucketIndex], !bucketPoints.isEmpty else { return nil }

            let bucketDate = firstDate.addingTimeInterval((Double(bucketIndex) + 0.5) * Self.trendBucketDuration)
            return (date: bucketDate, value: median(bucketPoints.map(\.value)))
        }
    }

    /// Solves the normal equations for y = a + bx + cx².
    private static func quadraticCoefficients(samples: [(x: Double, y: Double)]) -> (a: Double, b: Double, c: Double)? {
        let count = Double(samples.count)
        let sumX = samples.reduce(0.0) { $0 + $1.x }
        let sumX2 = samples.reduce(0.0) { $0 + ($1.x * $1.x) }
        let sumX3 = samples.reduce(0.0) { $0 + ($1.x * $1.x * $1.x) }
        let sumX4 = samples.reduce(0.0) { $0 + ($1.x * $1.x * $1.x * $1.x) }
        let sumY = samples.reduce(0.0) { $0 + $1.y }
        let sumXY = samples.reduce(0.0) { $0 + ($1.x * $1.y) }
        let sumX2Y = samples.reduce(0.0) { $0 + ($1.x * $1.x * $1.y) }

        let determinant = count * ((sumX2 * sumX4) - (sumX3 * sumX3))
            - sumX * ((sumX * sumX4) - (sumX3 * sumX2))
            + sumX2 * ((sumX * sumX3) - (sumX2 * sumX2))

        guard abs(determinant) > 0.000001 else { return nil }

        let determinantA = sumY * ((sumX2 * sumX4) - (sumX3 * sumX3))
            - sumX * ((sumXY * sumX4) - (sumX3 * sumX2Y))
            + sumX2 * ((sumXY * sumX3) - (sumX2 * sumX2Y))
        let determinantB = count * ((sumXY * sumX4) - (sumX3 * sumX2Y))
            - sumY * ((sumX * sumX4) - (sumX3 * sumX2))
            + sumX2 * ((sumX * sumX2Y) - (sumXY * sumX2))
        let determinantC = count * ((sumX2 * sumX2Y) - (sumXY * sumX3))
            - sumX * ((sumX * sumX2Y) - (sumXY * sumX2))
            + sumY * ((sumX * sumX3) - (sumX2 * sumX2))

        return (
            a: determinantA / determinant,
            b: determinantB / determinant,
            c: determinantC / determinant
        )
    }

    /// Returns the middle value, or the average of the two middle values for even-sized buckets.
    private static func median(_ values: [Double]) -> Double {
        let sortedValues = values.sorted()
        let middleIndex = sortedValues.count / 2

        if sortedValues.count.isMultiple(of: 2) {
            return (sortedValues[middleIndex - 1] + sortedValues[middleIndex]) / 2
        }

        return sortedValues[middleIndex]
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

    /// Reduces rendering cost while preserving endpoints and the largest value for each plotted metric.
    private static func downsample(
        _ points: [SensorNoiseHistoryPoint],
        maximumBuckets: Int
    ) -> [SensorNoiseHistoryPoint] {
        guard points.count > maximumBuckets * 4 else { return points }

        let bucketSize = Int(ceil(Double(points.count) / Double(maximumBuckets)))
        var reduced = [SensorNoiseHistoryPoint]()
        reduced.reserveCapacity(maximumBuckets * 5)

        for bucketStart in stride(from: 0, to: points.count, by: bucketSize) {
            let bucketEnd = min(bucketStart + bucketSize, points.count)
            let bucket = Array(points[bucketStart ..< bucketEnd])
            var candidates = [bucket.first, bucket.last]
            candidates.append(bucket.max { ($0.shortTermNoise ?? -1) < ($1.shortTermNoise ?? -1) })
            candidates.append(bucket.max { ($0.longTermNoise ?? -1) < ($1.longTermNoise ?? -1) })
            candidates.append(bucket.max { ($0.persistentNoise ?? -1) < ($1.persistentNoise ?? -1) })

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
