//
//  BatteryHistoryView.swift
//  xdrip
//
//  Created by Paul Plant on 1/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import CoreData
import SwiftUI

/// The time window displayed by the battery-history chart.
///
/// Fixed ranges always run backwards from the current time. Before a device reaches the next fixed
/// width, its actual recorded lifetime occupies that position so the picker never offers empty time.
enum BatteryHistoryRange: Hashable, Identifiable {
    case days(Int)
    case lifetime(TimeInterval)

    /// Picker identity is structural rather than localized presentation. Only one lifetime option
    /// is ever present, and its identity must remain distinct from a fixed range with the same label.
    enum ID: Hashable {
        case days(Int)
        case lifetime
    }

    var id: ID {
        switch self {
        case .days(let days): return .days(days)
        case .lifetime: return .lifetime
        }
    }

    var label: String {
        switch self {
        case .days(let days): return "\(days)\(Texts_Common.dayshort)"
        case .lifetime(let duration):
            let hours = max(1, Int(duration / 3600))
            return hours >= 24
                ? "\(hours / 24)\(Texts_Common.dayshort)\(hours % 24 == 0 ? "" : "\(hours % 24)\(Texts_Common.hourshort)")"
                : "\(hours)\(Texts_Common.hourshort)"
        }
    }

    static func available(firstObservation: Date, now: Date) -> [BatteryHistoryRange] {
        let lifetime = max(0, now.timeIntervalSince(firstObservation))
        var ranges = [BatteryHistoryRange]()
        for days in [3, 7, 12] where lifetime >= TimeInterval(days: Double(days)) {
            ranges.append(.days(days))
        }
        if ranges.isEmpty {
            ranges.append(.lifetime(lifetime))
        } else if lifetime < TimeInterval(days: 12),
                  case .days(let lastDays) = ranges.last,
                  lifetime > TimeInterval(days: Double(lastDays)) {
            // Below 12 days, the next unavailable fixed option is replaced by the actual lifetime.
            ranges.append(.lifetime(lifetime))
        } else if lifetime >= TimeInterval(days: 12) + 3600 {
            // Avoid showing a lifetime option that is effectively identical to the 12-day range.
            ranges.append(.lifetime(lifetime))
        }
        return ranges
    }

    func domain(now: Date) -> ClosedRange<Date> {
        let duration: TimeInterval
        switch self {
        case .days(let days): duration = TimeInterval(days: Double(days))
        case .lifetime(let lifetime): duration = max(6 * 3600, lifetime)
        }
        return now.addingTimeInterval(-duration) ... now
    }
}

/// Creates stable X-axis marks with localized labels at the visible endpoints.
struct BatteryHistoryXAxis {
    let domain: ClosedRange<Date>
    let calendar: Calendar

    init(domain: ClosedRange<Date>, calendar: Calendar = .autoupdatingCurrent) {
        self.domain = domain
        self.calendar = calendar
    }

    var dates: [Date] {
        let component: Calendar.Component = usesHourlyMarks ? .hour : .day
        let firstBoundary: Date?

        if usesHourlyMarks {
            firstBoundary = calendar.dateInterval(of: .hour, for: domain.lowerBound)?.end
        } else {
            firstBoundary = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: domain.lowerBound))
        }

        var dates = [domain.lowerBound]
        var date = firstBoundary
        while let currentDate = date, currentDate < domain.upperBound {
            // The final endpoint labels its own hour or day, so omit a duplicate boundary label.
            if !calendar.isDate(currentDate, equalTo: domain.upperBound, toGranularity: component) {
                dates.append(currentDate)
            }
            date = calendar.date(byAdding: component, value: 1, to: currentDate)
        }
        dates.append(domain.upperBound)
        return dates
    }

    /// Endpoint labels use their own mark layer so dense hourly or daily checks cannot compress
    /// either localized date into the narrow interval allocated to a neighbouring unlabeled mark.
    var endpointDates: [Date] {
        [domain.lowerBound, domain.upperBound]
    }

    func label(for date: Date) -> String {
        usesHourlyMarks
            ? date.formatted(.dateTime.hour())
            : date.formatted(.dateTime.day().month(.abbreviated))
    }

    func isEndpoint(_ date: Date) -> Bool {
        date == domain.lowerBound || date == domain.upperBound
    }

    func labelAnchor(for date: Date) -> UnitPoint {
        if date == domain.lowerBound { return .topLeading }
        if date == domain.upperBound { return .topTrailing }
        return .top
    }

    private var usesHourlyMarks: Bool {
        domain.upperBound.timeIntervalSince(domain.lowerBound) <= TimeInterval(days: 1)
    }
}

/// Displays device information and genuine persisted battery observations for one saved peripheral.
struct BatteryHistoryView: View {
    let peripheralObjectID: NSManagedObjectID
    let manager: BatteryHistoryManager

    @State private var points = [BatteryHistoryPoint]()
    @State private var information: BatteryHistoryInformation?
    @State private var selectedRange: BatteryHistoryRange?
    @State private var selectedPoint: BatteryHistoryPoint?
    @State private var now = Date()

    private var emptyBatterySystemImage: String {
        // The percent-suffixed battery symbols require iOS 17. Keep the empty state visible on iOS 16.
        if #available(iOS 17.0, *) {
            return "battery.0percent"
        }
        return "minus.plus.batteryblock.slash"
    }

    // MARK: - view

    var body: some View {
        GeometryReader { geometry in
            List {
                if let information {
                    Section {
                        LabeledContent(Texts_BluetoothPeripheralView.batteryHistoryTransmitterID, value: information.bluetoothName)
                        if let reading = information.currentReading {
                            LabeledContent(Texts_BluetoothPeripheralView.battery, value: currentReadingText(reading, elapsed: information.transmitterLifetime))
                        }
                    } header: {
                        Text(information.transmitterDescription)
                    }
                }

                Section {
                    if points.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: emptyBatterySystemImage)
                                .font(.largeTitle)
                            Text(Texts_BluetoothPeripheralView.batteryHistoryNoData)
                                .font(.headline)
                            Text(Texts_BluetoothPeripheralView.batteryHistoryBeginsAfterReading)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                    } else {
                        batteryHistoryChart(availableHeight: geometry.size.height)
                            .listRowInsets(EdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8))
                    }
                } header: {
                    Text(Texts_BluetoothPeripheralView.batteryHistory)
                    if !points.isEmpty {
                        Text(Texts_BluetoothPeripheralView.batteryHistoryRangeExplanation)
                    }
                }
            }
        }
        .navigationTitle(Texts_BluetoothPeripheralView.batteryHistory)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .colorScheme(.dark)
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .batteryHistoryDidChange)) { note in
            guard note.object as? NSManagedObjectID == peripheralObjectID else { return }
            reload()
        }
    }

    private var availableRanges: [BatteryHistoryRange] {
        guard let first = points.first?.observedAt else { return [] }
        return BatteryHistoryRange.available(firstObservation: first, now: now)
    }

    private func batteryHistoryChart(availableHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let activeChartPoint {
                HStack(alignment: .firstTextBaseline) {
                    Text(activeChartPoint.observedAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(Color(.colorSecondary))

                    Spacer(minLength: 8)

                    batteryValuePill(for: activeChartPoint)
                }
                .font(.subheadline.monospacedDigit())
            }

            chart
                .frame(height: chartHeight(availableHeight: availableHeight))
                .padding(.top, 2)

            Picker(
                Texts_BluetoothPeripheralView.batteryHistoryRange,
                selection: Binding(
                    get: { effectiveRange },
                    set: {
                        selectedRange = $0
                        selectedPoint = nil
                    }
                )
            ) {
                ForEach(availableRanges) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(Texts_BluetoothPeripheralView.batteryHistoryRangeAccessibility)
        }
    }

    @ViewBuilder private func batteryValuePill(for point: BatteryHistoryPoint) -> some View {
        if let reading = batteryReading(for: point) {
            // Keep the measurement name for VoiceOver without crowding the visible value.
            let label = point.kind == .dexcomVoltage ? Texts_BluetoothPeripheralView.voltageB : Texts_BluetoothPeripheralView.battery

            Text(currentReadingValueText(reading))
                .foregroundStyle(Color.cyan)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color(.systemGray6), in: Capsule())
                .accessibilityLabel(label + " " + currentReadingValueText(reading))
        }
    }

    private func chartHeight(availableHeight: CGFloat) -> CGFloat {
        min(220, max(150, (availableHeight - 400) * 0.55))
    }

    private func lifetimeText(_ lifetime: TimeInterval) -> String {
        (lifetime / 60).minutesToDaysAndHours()
    }


    private func currentReadingText(_ reading: BatteryHistoryCurrentReading, elapsed: TimeInterval?) -> String {
        let value = currentReadingValueText(reading)
        guard let elapsed else { return value }
        return "\(value) (\(lifetimeText(elapsed)))"
    }

    private func currentReadingValueText(_ reading: BatteryHistoryCurrentReading) -> String {
        switch reading {
        case .percentage(let value): return "\(value)%"
        case .voltageB(let rawValue): return "\(rawValue * 10)mV"
        }
    }

    private func batteryReading(for point: BatteryHistoryPoint) -> BatteryHistoryCurrentReading? {
        switch point.kind {
        case .percentage:
            return point.percentage.map(BatteryHistoryCurrentReading.percentage)
        case .dexcomVoltage:
            return point.voltageB.map { .voltageB(rawValue: $0) }
        }
    }

    private var effectiveRange: BatteryHistoryRange {
        if let selectedRange, availableRanges.contains(selectedRange) { return selectedRange }
        return availableRanges.last ?? .lifetime(0)
    }

    private var visiblePoints: [BatteryHistoryPoint] {
        let domain = effectiveRange.domain(now: now)
        return points.filter { domain.contains($0.observedAt) }
    }

    private var dominantVisiblePoints: [BatteryHistoryPoint] {
        let usesPercentage = points.last?.kind == .percentage
        return visiblePoints.filter {
            usesPercentage ? $0.percentage != nil : $0.voltageB != nil
        }
    }

    private var activeChartPoint: BatteryHistoryPoint? {
        // Match the noise-history interaction: show the latest point until the user touches a value.
        if let selectedPoint, dominantVisiblePoints.contains(where: { $0.id == selectedPoint.id }) {
            return selectedPoint
        }
        return dominantVisiblePoints.last
    }

    private func nearestVisiblePoint(to date: Date) -> BatteryHistoryPoint? {
        dominantVisiblePoints.min {
            abs($0.observedAt.timeIntervalSince(date)) < abs($1.observedAt.timeIntervalSince(date))
        }
    }

    @ViewBuilder private var chart: some View {
        let domain = effectiveRange.domain(now: now)
        let xAxis = BatteryHistoryXAxis(domain: domain)
        let latest = points.last
        let isPercentage = latest?.kind == .percentage
        let family = latest?.family
        let percentagePoints = visiblePoints.filter { $0.percentage != nil }
        let voltageBPoints = visiblePoints.filter { $0.voltageB != nil }
        let activePoint = activeChartPoint
        let voltageDomain = automaticVoltageDomain

        Chart {
            if isPercentage {
                // Percentage bands reuse the same urgent and warning boundaries as the
                // Bluetooth battery symbol shown in the peripheral detail section.
                RectangleMark(
                    xStart: .value("Start", domain.lowerBound),
                    xEnd: .value("End", domain.upperBound),
                    yStart: .value("Urgent", 0),
                    yEnd: .value("Urgent threshold", BluetoothBatteryLevelPresentation.urgentUpperBound)
                )
                .foregroundStyle(ConstantsAppColors.urgent.opacity(0.10))
                RectangleMark(
                    xStart: .value("Start", domain.lowerBound),
                    xEnd: .value("End", domain.upperBound),
                    yStart: .value("Warning", BluetoothBatteryLevelPresentation.urgentUpperBound),
                    yEnd: .value("Healthy", BluetoothBatteryLevelPresentation.warningUpperBound)
                )
                .foregroundStyle(ConstantsAppColors.warning.opacity(0.09))
                RectangleMark(
                    xStart: .value("Start", domain.lowerBound),
                    xEnd: .value("End", domain.upperBound),
                    yStart: .value("Healthy", BluetoothBatteryLevelPresentation.warningUpperBound),
                    yEnd: .value("Maximum", 100)
                )
                .foregroundStyle(ConstantsAppColors.normal.opacity(0.08))
                ForEach(BluetoothBatteryLevelPresentation.chartThresholds, id: \.self) { threshold in
                    RuleMark(y: .value("Threshold", threshold))
                        .foregroundStyle(Color(.systemGray2).opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                }

                // Heartbeat readings can be sparse, so keep all genuine observations in one
                // series and let the chart join them without manufacturing intermediate values.
                ForEach(percentagePoints) { point in
                    LineMark(x: .value("Time", point.observedAt), y: .value("Battery", point.percentage!), series: .value("Series", "Percentage"))
                        .foregroundStyle(Color.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            } else {
                if let family {
                    // Start at the visible domain rather than zero. Swift Charts otherwise renders
                    // the off-domain rectangle below the plot and into the X-axis controls.
                    RectangleMark(xStart: .value("Start", domain.lowerBound), xEnd: .value("End", domain.upperBound), yStart: .value("Low", voltageDomain.lowerBound), yEnd: .value("Low threshold", family.redBelow * 10))
                        .foregroundStyle(ConstantsAppColors.urgent.opacity(0.10))
                    RectangleMark(xStart: .value("Start", domain.lowerBound), xEnd: .value("End", domain.upperBound), yStart: .value("Caution", family.redBelow * 10), yEnd: .value("Healthy", family.greenFrom * 10))
                        .foregroundStyle(ConstantsAppColors.warning.opacity(0.09))
                    RectangleMark(xStart: .value("Start", domain.lowerBound), xEnd: .value("End", domain.upperBound), yStart: .value("Healthy", family.greenFrom * 10), yEnd: .value("Maximum", voltageDomain.upperBound))
                        .foregroundStyle(ConstantsAppColors.normal.opacity(0.08))
                    ForEach([family.redBelow, family.greenFrom], id: \.self) { threshold in
                        RuleMark(y: .value("Threshold", threshold * 10))
                            .foregroundStyle(Color(.systemGray2).opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                    }
                }
                ForEach(voltageBPoints) { point in
                    LineMark(x: .value("Time", point.observedAt), y: .value("Voltage B", point.voltageB! * 10), series: .value("Series", "Voltage B"))
                        .foregroundStyle(Color.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }

            if let activePoint {
                RuleMark(x: .value("Selected time", activePoint.observedAt))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.white.opacity(0.65))

                if isPercentage, let percentage = activePoint.percentage {
                    PointMark(x: .value("Selected time", activePoint.observedAt), y: .value("Battery", percentage))
                        .foregroundStyle(Color.cyan)
                        .symbolSize(48)
                } else if let voltageB = activePoint.voltageB {
                    PointMark(x: .value("Selected time", activePoint.observedAt), y: .value("Voltage B", voltageB * 10))
                        .foregroundStyle(Color.cyan)
                        .symbolSize(48)
                }
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: isPercentage ? 0 ... 100 : voltageDomain)
        .chartXAxis {
            // Draw compact checks for every requested hour or day without asking this dense layer
            // to lay out endpoint text as well.
            AxisMarks(values: xAxis.dates) { _ in
                AxisGridLine()
                    .foregroundStyle(Color(.systemGray3).opacity(0.18))
                AxisTick(length: 4)
                    .foregroundStyle(Color(.systemGray2))
            }

            AxisMarks(values: xAxis.endpointDates) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel(anchor: xAxis.labelAnchor(for: date), collisionResolution: .disabled) {
                        Text(xAxis.label(for: date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color(.colorSecondary))
                            .fixedSize()
                    }
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartOverlay { chartProxy in
            GeometryReader { geometryProxy in
                // A zero-distance drag supports both a tap and a continuous scrub over real samples.
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

                                selectedPoint = nearestVisiblePoint(to: date)
                            }
                    )
            }
        }
        .accessibilityLabel(Texts_BluetoothPeripheralView.batteryHistory)
    }

    private var automaticVoltageDomain: ClosedRange<Int> {
        // Voltage B is the only Dexcom battery value presented by this chart. Include both family
        // thresholds so even an entirely low history retains visible red, yellow and green context.
        var values = visiblePoints.compactMap(\.voltageB).map { $0 * 10 }
        if let family = points.last?.family {
            values.append(contentsOf: [family.redBelow * 10, family.greenFrom * 10])
        }

        guard let minimum = values.min(), let maximum = values.max() else { return 0 ... 3000 }
        let padding = max(50, (maximum - minimum) / 5)
        return max(0, minimum - padding) ... (maximum + padding)
    }

    private func reload() {
        now = Date()
        points = manager.history(peripheralObjectID: peripheralObjectID)
        selectedPoint = nil
        information = manager.information(peripheralObjectID: peripheralObjectID, now: now)
        if selectedRange == nil { selectedRange = availableRanges.last }
    }
}
