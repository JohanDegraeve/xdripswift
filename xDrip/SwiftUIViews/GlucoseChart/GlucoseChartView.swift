//
//  GlucoseChartView.swift
//  xdrip
//
//  Created by Paul Plant on 13/01/2024.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI
import Foundation

/// Retains the largest upper domain encountered by an interactive chart until an explicit reset.
///
/// Keeping this as presentation state avoids coupling y-axis interaction behaviour to chart data
/// loading. Compact charts never opt into it and therefore remain fully adaptive.
struct GlucoseChartYAxisRetentionState {

    private(set) var retainedMaximumInMgDl: Double?

    mutating func retain(maximumInMgDl: Double) {
        retainedMaximumInMgDl = max(retainedMaximumInMgDl ?? maximumInMgDl, maximumInMgDl)
    }

    mutating func reset(to maximumInMgDl: Double) {
        retainedMaximumInMgDl = maximumInMgDl
    }

    func effectiveMaximum(for maximumInMgDl: Double) -> Double {
        max(retainedMaximumInMgDl ?? maximumInMgDl, maximumInMgDl)
    }
}

/// Swift Charts implementation for rendering glucose readings and related chart annotations.
///
/// Lightweight callers can pass BG values and dates directly. Full-chart callers pass `chartState`,
/// which carries the visible range, glucose readings, calibrations, treatments and basal points.
///
/// The view does not load or mutate chart data. `GlucoseChartState` is the boundary between the
/// cached state manager and this renderer.
struct GlucoseChartView: View {

    // MARK: - Input Data

    var bgReadingValues: [Double]
    var bgReadingDates: [Date]
    var additionalBgReadingDataSets: [GlucoseChartDataSet]
    var backgroundBands: [GlucoseChartBackgroundBand]
    /// Optional AGP background, already mapped onto this chart's date axis.
    ///
    /// This keeps AGP inside the same chart as the glucose points. That avoids a second plot area
    /// with slightly different scaling or padding.
    var agpBackgroundPoints: [GlucoseChartAGPPoint]
    /// Multiplies the AGP colour opacity constants for compact chart views.
    let agpBackgroundOpacityMultiplier: Double
    /// Full cached/renderable chart state.
    ///
    /// When present, this overrides the direct BG arrays and enables the complete chart data set.
    var chartState: GlucoseChartState?

    // MARK: - Configuration

    let chartType: GlucoseChartType // shortened to chartType to make reading easier below
    let isMgDl: Bool
    let urgentLowLimitInMgDl: Double
    let lowLimitInMgDl: Double
    let highLimitInMgDl: Double
    let urgentHighLimitInMgDl: Double
    let liveActivityType: LiveActivityType
    let hoursToShow: Double
    let glucoseCircleDiameter: Double
    let showsTreatments: Bool
    let chartHeight: Double
    let chartWidth: Double
    let showHighContrast: Bool
    let overrideChartHeightWasPassed: Bool
    let explicitVisibleEndDate: Date?
    let visibleStartDate: Date
    let visibleEndDate: Date
    /// Opt-in fixed y-axis context for the main glucose chart.
    ///
    /// Widgets, watch, notification and Live Activity charts stay adaptive by default. The main Home
    /// chart keeps enough low and high context for visually coherent scrolling.
    var usesMainChartYAxisContext = false
    var mainChartYAxisResetRevision = 0

    @State private var yAxisRetentionState = GlucoseChartYAxisRetentionState()
    @State private var yAxisAutoResetWorkItem: DispatchWorkItem?

    private enum YAxisLabelStyle {
        case objective
        case secondaryObjective
        case dimmed
    }

    // MARK: - Initialisation

    /// Creates a glucose chart for widgets, live activities, notifications or the full SwiftUI chart state.
    /// - Parameters:
    ///   - glucoseChartType: Defines the default size, labels, colours and widget/live-activity layout behaviour.
    ///   - bgReadingValues: Glucose values in mg/dL. Ignored when `chartState` is supplied.
    ///   - bgReadingDates: Dates matching `bgReadingValues`. Ignored when `chartState` is supplied.
    ///   - additionalBgReadingDataSets: Optional extra glucose-like series, such as original/raw readings.
    ///   - isMgDl: Whether axis labels should be shown in mg/dL or mmol/L.
    ///   - urgentLowLimitInMgDl: Urgent low threshold in mg/dL.
    ///   - lowLimitInMgDl: Low threshold in mg/dL.
    ///   - highLimitInMgDl: High threshold in mg/dL.
    ///   - urgentHighLimitInMgDl: Urgent high threshold in mg/dL.
    ///   - liveActivityType: Live activity size variant. Defaults to `.normal` when nil.
    ///   - hoursToShowScalingHours: Overrides the chart type's default visible duration.
    ///   - glucoseCircleDiameterScalingHours: Optional baseline used to scale glucose/treatment symbol sizes for wider or narrower ranges.
    ///   - showsTreatments: Whether treatment and basal marks should be rendered.
    ///   - overrideChartHeight: Optional explicit chart height.
    ///   - overrideChartWidth: Optional explicit chart width.
    ///   - highContrast: Optional high-contrast override for StandBy charts.
    ///   - chartState: Full SwiftUI chart state containing the visible range and all renderable chart series.
    init(glucoseChartType: GlucoseChartType, bgReadingValues: [Double]?, bgReadingDates: [Date]?, additionalBgReadingDataSets: [GlucoseChartDataSet]? = nil, backgroundBands: [GlucoseChartBackgroundBand]? = nil, agpBackgroundPoints: [GlucoseChartAGPPoint]? = nil, agpBackgroundOpacityMultiplier: Double? = nil, explicitVisibleEndDate: Date? = nil, isMgDl: Bool, urgentLowLimitInMgDl: Double, lowLimitInMgDl: Double, highLimitInMgDl: Double, urgentHighLimitInMgDl: Double, liveActivityType: LiveActivityType?, hoursToShowScalingHours: Double?, glucoseCircleDiameterScalingHours: Double?, showsTreatments: Bool = true, overrideChartHeight: Double?, overrideChartWidth: Double?, highContrast: Bool?, chartState: GlucoseChartState? = nil) {

        self.chartType = glucoseChartType
        self.isMgDl = isMgDl
        self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
        self.lowLimitInMgDl = lowLimitInMgDl
        self.highLimitInMgDl = highLimitInMgDl
        self.urgentHighLimitInMgDl = urgentHighLimitInMgDl
        self.liveActivityType = liveActivityType ?? .normal
        self.showHighContrast = highContrast ?? false
        self.overrideChartHeightWasPassed = overrideChartHeight != nil
        self.explicitVisibleEndDate = explicitVisibleEndDate
        self.showsTreatments = showsTreatments
        // clamp the multiplier so callers can only reduce or keep the normal AGP opacity
        self.agpBackgroundOpacityMultiplier = min(max(agpBackgroundOpacityMultiplier ?? 1, 0), 1)

        // here we want to automatically set the hoursToShow based upon the chart type, but some chart instances might need
        // this to be overriden such as for zooming in/out of the chart (i.e. the Watch App)
        self.hoursToShow = hoursToShowScalingHours ?? chartType.hoursToShow(liveActivityType: self.liveActivityType)

        self.chartHeight = overrideChartHeight ?? chartType.viewSize(liveActivityType: self.liveActivityType).height

        self.chartWidth = overrideChartWidth ?? chartType.viewSize(liveActivityType: self.liveActivityType).width

        // apply a scale to the glucoseCircleDiameter if an override value is passed
        self.glucoseCircleDiameter = chartType.glucoseCircleDiameter(liveActivityType: self.liveActivityType) * ((glucoseCircleDiameterScalingHours ?? self.hoursToShow) / self.hoursToShow)
        self.chartState = chartState

        let endDate = chartState?.endDate ?? explicitVisibleEndDate ?? Date()
        let startDate = chartState?.startDate ?? endDate.addingTimeInterval(-hoursToShow * 60 * 60)
        self.visibleStartDate = startDate
        self.visibleEndDate = endDate

        // as all widget instances are passed 12 hours of bg values, we must initialize this instance to use only the amount of hours of value required by the chartType passed
        self.bgReadingValues = []
        self.bgReadingDates = []
        self.additionalBgReadingDataSets = []
        self.backgroundBands = []
        self.agpBackgroundPoints = []

        let sourceBgReadingValues = chartState?.bgReadingValues ?? bgReadingValues
        let sourceBgReadingDates = chartState?.bgReadingDates ?? bgReadingDates

        if let bgReadingValues = sourceBgReadingValues, let bgReadingDates = sourceBgReadingDates {
            for (bgReadingValue, bgReadingDate) in zip(bgReadingValues, bgReadingDates) {
                if bgReadingDate >= startDate && bgReadingDate <= endDate {
                    self.bgReadingValues.append(bgReadingValue)
                    self.bgReadingDates.append(bgReadingDate)
                }
            }
        }

        if let additionalBgReadingDataSets = chartState?.additionalBgReadingDataSets ?? additionalBgReadingDataSets {
            self.additionalBgReadingDataSets = additionalBgReadingDataSets.map { dataSet in
                var filteredBgReadingValues = [Double]()
                var filteredBgReadingDates = [Date]()

                for (index, bgReadingDate) in dataSet.bgReadingDates.enumerated() {
                    if bgReadingDate >= startDate && bgReadingDate <= endDate, index < dataSet.bgReadingValues.count {
                        filteredBgReadingValues.append(dataSet.bgReadingValues[index])
                        filteredBgReadingDates.append(bgReadingDate)
                    }
                }

                return GlucoseChartDataSet(bgReadingValues: filteredBgReadingValues, bgReadingDates: filteredBgReadingDates, seriesIdentifier: dataSet.seriesIdentifier, lineColor: dataSet.lineColor, pointColor: dataSet.pointColor, lineWidth: dataSet.lineWidth, dash: dataSet.dash, showLine: dataSet.showLine, showPoints: dataSet.showPoints, pointSizeMultiplier: dataSet.pointSizeMultiplier, pointBorderColor: dataSet.pointBorderColor, pointBorderSizeMultiplier: dataSet.pointBorderSizeMultiplier)
            }
        }

        if let backgroundBands = chartState?.backgroundBands ?? backgroundBands {
            self.backgroundBands = backgroundBands.compactMap { backgroundBand in
                let clippedStartDate = max(backgroundBand.startDate, startDate)
                let clippedEndDate = min(backgroundBand.endDate, endDate)

                guard clippedStartDate < clippedEndDate else { return nil }

                return GlucoseChartBackgroundBand(
                    startDate: clippedStartDate,
                    endDate: clippedEndDate,
                    style: backgroundBand.style
                )
            }
        }

        if let agpBackgroundPoints = agpBackgroundPoints {
            // AGP points are filtered and sanity-checked here because they may arrive over Watch
            // Connectivity. Bad percentile ordering can make Swift Charts draw crossing bands.
            let agpBackgroundEndDate = endDate.addingTimeInterval(5 * 60)

            self.agpBackgroundPoints = agpBackgroundPoints.filter { point in
                point.date >= startDate &&
                    point.date <= agpBackgroundEndDate &&
                    point.p5MgDl <= point.p25MgDl &&
                    point.p25MgDl <= point.medianMgDl &&
                    point.medianMgDl <= point.p75MgDl &&
                    point.p75MgDl <= point.p95MgDl
            }
        }
    }

    // MARK: - Axis and Colour Helpers

    /// Opts the chart into the fixed-context y-axis used by the main glucose chart.
    ///
    /// Compact charts intentionally stay adaptive by default so widgets, watch charts,
    /// notifications and live activities do not reserve unnecessary vertical space.
    func mainChartYAxisContext(resetRevision: Int = 0) -> Self {
        var view = self
        view.usesMainChartYAxisContext = true
        view.mainChartYAxisResetRevision = resetRevision

        return view
    }

    /// Blood glucose color dependant on the user defined limit values
    /// - Returns: a Color object either red, yellow or green
    func bgColor(bgValueInMgDl: Double) -> Color {
        if chartType != .widgetSystemSmallStandBy || !showHighContrast {
            if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                return .red
            } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                return .yellow
            } else {
                return .green
            }
        } else {
            return .white
        }

    }

    private func xAxisLabelEveryHours() -> Int {
        if chartType == .miniChart {
            return chartType.xAxisLabelEveryHours()
        }

        switch hoursToShow {
        case 24...:
            return 4
        case 12...:
            return 2
        case 8...:
            return 2
        default:
            return chartType.xAxisLabelEveryHours()
        }
    }

    private func xAxisLabelDates(everyHours: Int) -> [Date] {
        if chartType == .miniChart {
            return miniChartXAxisLabelDates()
        }

        // Keep labels anchored to real clock hours so a small scroll cannot switch between odd and
        // even hour labels.
        let hourInterval = max(everyHours, 1)
        let calendar = Calendar.current
        let startOfVisibleHourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: visibleStartDate)

        guard var date = calendar.date(from: startOfVisibleHourComponents) else { return [] }

        if date < visibleStartDate, let nextHourDate = calendar.date(byAdding: .hour, value: 1, to: date) {
            date = nextHourDate
        }

        var dates = [Date]()

        while date <= visibleEndDate {
            let hour = calendar.component(.hour, from: date)

            if hourInterval == 1 || hour % hourInterval == 0 {
                dates.append(date)
            }

            guard let nextDate = calendar.date(byAdding: .hour, value: 1, to: date), nextDate > date else {
                break
            }

            date = nextDate
        }

        return dates
    }

    private func miniChartXAxisLabelDates() -> [Date] {
        let calendar = Calendar.current
        var dates = [Date]()
        var date = calendar.startOfDay(for: visibleStartDate)

        // The home mini-chart reference shows day boundaries rather than a dense hour grid. We keep
        // that behaviour here so the 24 hour overview has a clear midnight marker.
        while date <= visibleStartDate {
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date else {
                return dates
            }

            date = nextDate
        }

        while date < visibleEndDate {
            dates.append(date)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date else {
                break
            }

            date = nextDate
        }

        return dates
    }

    private func xAxisMidnightDates() -> [Date] {
        let calendar = Calendar.current
        var dates = [Date]()
        var date = calendar.startOfDay(for: visibleStartDate)

        if date < visibleStartDate, let nextDate = calendar.date(byAdding: .day, value: 1, to: date) {
            date = nextDate
        }

        while date <= visibleEndDate {
            dates.append(date)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date else {
                break
            }

            date = nextDate
        }

        return dates
    }

    private func mainChartYAxisContextMarks(maximumRenderableValue: Double) -> (labeledValues: [Double], gridOnlyValues: [Double]) {
        guard usesMainChartYAxisContext else {
            return ([], [])
        }

        // These are context marks, not data-derived ticks. Keeping upper reference lines visible
        // makes scroll and zoom comparisons easier while compact charts remain adaptive.
        var labeledValues = [Double]()
        var gridOnlyValues = [Double]()

        if urgentLowLimitInMgDl >= ConstantsGlucoseChartSwiftUI.yAxisLowContextMinimumUrgentLowInMgDl {
            labeledValues.append(ConstantsGlucoseChartSwiftUI.yAxisLowContextGridLineInMgDl)
        }

        if urgentHighLimitInMgDl < 135 {
            labeledValues.append(150)
        }

        if urgentHighLimitInMgDl <= 190 {
            labeledValues.append(200)
        } else if urgentHighLimitInMgDl < 200 {
            gridOnlyValues.append(200)
        }

        var lastContextValue = max(labeledValues.last ?? urgentHighLimitInMgDl, gridOnlyValues.last ?? urgentHighLimitInMgDl)
        let additionalContextValues = ConstantsGlucoseChartSwiftUI.yAxisUpperContextGridLinesInMgDl.dropFirst(2)

        for value in additionalContextValues where lastContextValue < maximumRenderableValue {
            let threshold: Double

            switch value {
            case 250:
                threshold = 240
            case 300:
                threshold = 280
            case 350:
                threshold = 330
            case 400:
                threshold = 380
            default:
                threshold = value
            }

            let shouldAddContextValue = value == 250 ? urgentHighLimitInMgDl < threshold : urgentHighLimitInMgDl <= threshold

            if shouldAddContextValue {
                labeledValues.append(value)
                lastContextValue = value
            }
        }

        return (labeledValues, gridOnlyValues)
    }

    @ViewBuilder private func yAxisLabel(value: Double, style: YAxisLabelStyle) -> some View {
        Text(value.mgDlToMmolAndToString(mgDl: isMgDl))
            .foregroundStyle(yAxisLabelColor(style: style))
            .font(yAxisLabelFont(style: style))
            .monospacedDigit()
            .lineLimit(1)
            .frame(width: yAxisLabelWidth(), alignment: yAxisLabelAlignment())
            .offset(x: yAxisLabelOffsetX(), y: chartType.yAxisLabelOffsetY())
    }

    private func yAxisLabelColor(style: YAxisLabelStyle) -> Color {
        guard usesMainChartYAxisContext else {
            switch style {
            case .objective:
                return ConstantsGlucoseChartSwiftUI.yAxisLabelPrimaryColor
            case .secondaryObjective, .dimmed:
                return ConstantsGlucoseChartSwiftUI.yAxisLabelSecondaryColor
            }
        }

        switch style {
        case .objective, .secondaryObjective:
            return ConstantsGlucoseChartSwiftUI.yAxisMainChartObjectiveLabelColor
        case .dimmed:
            return ConstantsGlucoseChartSwiftUI.yAxisMainChartDimmedLabelColor
        }
    }

    private func yAxisLabelFont(style: YAxisLabelStyle) -> Font {
        guard usesMainChartYAxisContext else {
            return .footnote
        }

        switch style {
        case .objective:
            return .system(size: ConstantsGlucoseChartSwiftUI.yAxisMainChartObjectiveLabelFontSize, weight: .bold)
        case .secondaryObjective, .dimmed:
            return .system(size: ConstantsGlucoseChartSwiftUI.yAxisMainChartSecondaryLabelFontSize)
        }
    }

    private func yAxisLabelOffsetX() -> CGFloat {
        usesMainChartYAxisContext ? ConstantsGlucoseChartSwiftUI.yAxisMainChartLabelOffsetX : chartType.yAxisLabelOffsetX()
    }

    private func yAxisLabelWidth() -> CGFloat {
        guard usesMainChartYAxisContext else {
            return ConstantsGlucoseChartSwiftUI.yAxisLabelWidth
        }

        return isMgDl
            ? ConstantsGlucoseChartSwiftUI.yAxisMainChartLabelWidthInMgDl
            : ConstantsGlucoseChartSwiftUI.yAxisMainChartLabelWidthInMmol
    }

    private func yAxisLabelAlignment() -> Alignment {
        // Main-chart labels share a fixed right-side lane and the same leading edge. Generated
        // widget and intent chart presets retain their trailing alignment.
        usesMainChartYAxisContext ? .leading : .trailing
    }

    /// Adds an empty trailing span only to mini-chart rendering, positioning the `now` edge clear
    /// of the view's rounded corner without creating future glucose values.
    private func renderedXScaleEndDate() -> Date {
        if usesMainChartYAxisContext {
            return visibleEndDate
        }

        guard chartType == .miniChart else {
            return visibleEndDate.addingTimeInterval(5 * 60)
        }

        let visibleTimeInterval = visibleEndDate.timeIntervalSince(visibleStartDate)
        let edgeInsetTimeInterval = ConstantsGlucoseChartSwiftUI.miniChartEdgeInsetTimeInterval(
            visibleTimeInterval: visibleTimeInterval,
            chartWidth: chartWidth
        )

        return visibleEndDate.addingTimeInterval(edgeInsetTimeInterval)
    }

    private func overlayWindowClampedToVisibleRange(visibleRangeEndDate: Date) -> (startDate: Date, endDate: Date)? {
        guard let overlayWindowStartDate = chartState?.overlayWindowStartDate, let overlayWindowEndDate = chartState?.overlayWindowEndDate, overlayWindowStartDate < overlayWindowEndDate else {
            return nil
        }

        // Clamp only for dimming rectangles. Edge bars are calculated separately so a real boundary
        // is only drawn when that boundary is actually visible, except for the current-time tolerance
        // used to keep the right edge visible when the main chart ends at "now".
        let clampedStartDate = max(overlayWindowStartDate, visibleStartDate)
        let clampedEndDate = min(overlayWindowEndDate, visibleRangeEndDate)

        guard clampedStartDate < clampedEndDate else {
            return nil
        }

        return (clampedStartDate, clampedEndDate)
    }

    private func overlayWindowIsOutsideVisibleRange(visibleRangeEndDate: Date) -> Bool {
        guard let overlayWindowStartDate = chartState?.overlayWindowStartDate, let overlayWindowEndDate = chartState?.overlayWindowEndDate, overlayWindowStartDate < overlayWindowEndDate else {
            return false
        }

        return overlayWindowEndDate <= visibleStartDate || overlayWindowStartDate >= visibleRangeEndDate
    }

    private func overlayWindowStartEdgeDate(visibleRangeEndDate: Date) -> Date? {
        guard let overlayWindowStartDate = chartState?.overlayWindowStartDate, overlayWindowStartDate >= visibleStartDate, overlayWindowStartDate <= visibleRangeEndDate else {
            return nil
        }

        return overlayWindowStartDate
    }

    private func overlayWindowEndEdgeDate(visibleRangeEndDate: Date) -> Date? {
        guard let overlayWindowEndDate = chartState?.overlayWindowEndDate, overlayWindowEndDate >= visibleStartDate else {
            return nil
        }

        if overlayWindowEndDate <= visibleRangeEndDate {
            return overlayWindowEndDate
        }

        if overlayWindowEndDate.timeIntervalSince(visibleEndDate) <= ConstantsGlucoseChartSwiftUI.overlayWindowCurrentTimeEdgeTolerance {
            return visibleEndDate
        }

        return nil
    }

    // MARK: - Body

    var body: some View {
        let additionalValues = additionalBgReadingDataSets.flatMap { $0.bgReadingValues }
        let visibleTreatmentPoints = showsTreatments
            ? chartState?.treatmentPoints.filter(from: visibleStartDate, to: visibleEndDate) ?? GlucoseChartTreatmentPoints()
            : GlucoseChartTreatmentPoints()
        let visibleCalibrationPoints = chartState?.calibrationPoints.filter { $0.date >= visibleStartDate && $0.date <= visibleEndDate } ?? []
        let treatmentValues = visibleCalibrationPoints.map { $0.value } + visibleTreatmentPoints.allRenderableValues
        let allBgValues = bgReadingValues + additionalValues + treatmentValues
        let effectiveMinimumChartValue = showsTreatments
            ? chartState?.minimumChartValueInMgDl ?? ConstantsGlucoseChartSwiftUI.yAxisAbsoluteMinimumChartValueInMgDl
            : ConstantsGlucoseChartSwiftUI.yAxisAbsoluteMinimumChartValueInMgDl
        let showsBasalDomain = effectiveMinimumChartValue < ConstantsGlucoseChartSwiftUI.yAxisAbsoluteMinimumChartValueInMgDl
        let lowerDomainPadding = showsBasalDomain ? ConstantsGlucoseChartSwiftUI.yAxisBasalDomainPaddingInMgDl : ConstantsGlucoseChartSwiftUI.yAxisDomainPaddingInMgDl
        let minimumDomainValue = min((allBgValues.min() ?? 40), urgentLowLimitInMgDl, effectiveMinimumChartValue)
        let maximumRenderableValue = max((allBgValues.max() ?? urgentHighLimitInMgDl), urgentHighLimitInMgDl)
        let calculatedYAxisContextMarks = mainChartYAxisContextMarks(maximumRenderableValue: maximumRenderableValue)
        let calculatedYAxisContextValues = calculatedYAxisContextMarks.labeledValues + calculatedYAxisContextMarks.gridOnlyValues
        let calculatedMaximumContextValue = calculatedYAxisContextValues.max() ?? maximumRenderableValue
        let calculatedMaximumDomainValue = max(maximumRenderableValue, calculatedMaximumContextValue)
        let maximumDomainValue = usesMainChartYAxisContext
            ? yAxisRetentionState.effectiveMaximum(for: calculatedMaximumDomainValue)
            : calculatedMaximumDomainValue
        // Retain the matching context marks as well as the scale so labels do not disappear while
        // the upper domain itself is being held steady.
        let yAxisContextMarks = mainChartYAxisContextMarks(maximumRenderableValue: maximumDomainValue)
        let yAxisContextValues = yAxisContextMarks.labeledValues + yAxisContextMarks.gridOnlyValues
        let upperDomainPadding = usesMainChartYAxisContext ? ConstantsGlucoseChartSwiftUI.yAxisMainChartContextTopPaddingInMgDl : ConstantsGlucoseChartSwiftUI.yAxisDomainPaddingInMgDl
        let domain = (minimumDomainValue - lowerDomainPadding) ... (maximumDomainValue + upperDomainPadding)
        let xAxisLabelEveryHours = xAxisLabelEveryHours()
        let xAxisLabelDates = xAxisLabelDates(everyHours: xAxisLabelEveryHours)
        let xAxisMidnightDates = xAxisMidnightDates()
        let xScaleEndDate = renderedXScaleEndDate()
        let xScaleDomain = visibleStartDate ... xScaleEndDate
        let overlayWindow = overlayWindowClampedToVisibleRange(visibleRangeEndDate: xScaleEndDate)
        let overlayWindowIsOutsideVisibleRange = overlayWindowIsOutsideVisibleRange(visibleRangeEndDate: xScaleEndDate)
        let overlayWindowStartRuleDate = overlayWindowStartEdgeDate(visibleRangeEndDate: xScaleEndDate)
        let overlayWindowEndRuleDate = overlayWindowEndEdgeDate(visibleRangeEndDate: xScaleEndDate)
        let chartAspectRatio = chartType.aspectRatio()
        let chartPadding = chartType.padding()
        let yAxisLineSize = chartType.yAxisLineSize()

        // Swift Charts renders marks in declaration order: guides first, basal and treatments below
        // glucose, then calibration and overlay marks above the plot.
        Chart {
            ForEach(backgroundBands) { backgroundBand in
                RectangleMark(
                    xStart: .value("Sensor noise start", backgroundBand.startDate),
                    xEnd: .value("Sensor noise end", backgroundBand.endDate),
                    yStart: .value("Sensor noise minimum", domain.lowerBound),
                    yEnd: .value("Sensor noise maximum", domain.upperBound)
                )
                .foregroundStyle(backgroundBand.style.color)
            }

            if chartType != .miniChart {
                ForEach(xAxisMidnightDates, id: \.self) { xAxisMidnightDate in
                    RuleMark(x: .value("Midnight", xAxisMidnightDate))
                        .lineStyle(StrokeStyle(lineWidth: ConstantsGlucoseChartSwiftUI.xAxisMidnightGridLineSize))
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisMidnightGridLineColor)
                }
            }

            // Range threshold guide lines.
            ForEach(yAxisContextValues, id: \.self) { contextValue in
                RuleMark(y: .value("", contextValue))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize))
                    .foregroundStyle(ConstantsGlucoseChartSwiftUI.yAxisContextGridLineColor)
            }

            if chartType.yAxisShowUrgentLowHighLines(), domain.contains(urgentLowLimitInMgDl) {
                RuleMark(y: .value("", urgentLowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [2 * yAxisLineSize, 6 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisUrgentLowHighLineColor())
            }

            if chartType.yAxisShowUrgentLowHighLines(), domain.contains(urgentHighLimitInMgDl) {
                RuleMark(y: .value("", urgentHighLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [2 * yAxisLineSize, 6 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisUrgentLowHighLineColor())
            }

            if domain.contains(lowLimitInMgDl) {
                RuleMark(y: .value("", lowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [4 * yAxisLineSize, 3 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisLowHighLineColor())
            }

            if domain.contains(highLimitInMgDl) {
                RuleMark(y: .value("", highLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [4 * yAxisLineSize, 3 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisLowHighLineColor())
            }

            // Optional AGP background. These marks deliberately do not feed the y-domain above, so
            // the foreground glucose points stay in exactly the same positions when AGP is shown.
            // Values outside the current chart domain are clipped by the chart instead of changing
            // the scale.
            agpBackgroundMarks()

            // add a phantom glucose point at the beginning of the timeline to fix the start point in case there are no glucose values at that time (for instances after starting a new sensor)
            PointMark(x: .value("Time", visibleStartDate),
                      y: .value("BG", 100))
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter)
            .foregroundStyle(.clear)

            // Basal areas/lines and primary treatments are drawn below glucose points.
            //
            // The state manager has already produced scheduled and temporary basal step/fill points,
            // so the view only chooses the mark type and visual style.
            if let chartState = chartState {
                ForEach(visibleTreatmentPoints.basalRateFill) { point in
                    AreaMark(x: .value("Time", point.date),
                             yStart: .value("BG", chartState.minimumChartValueInMgDl),
                             yEnd: .value("BG", point.value))
                    .interpolationMethod(.stepStart)
                    .foregroundStyle(GlucoseChartTreatmentStyle.basalFillColor)
                }

                ForEach(visibleTreatmentPoints.basalRates) { point in
                    LineMark(x: .value("Time", point.date),
                             y: .value("BG", point.value),
                             series: .value("Series", "tempBasal"))
                    .interpolationMethod(.stepStart)
                    .lineStyle(StrokeStyle(lineWidth: GlucoseChartTreatmentStyle.basalLineWidth))
                    .foregroundStyle(GlucoseChartTreatmentStyle.basalLineColor)
                }

                ForEach(visibleTreatmentPoints.automaticBasalPulses) { pulse in
                    RectangleMark(
                        xStart: .value("Start", pulse.startDate),
                        xEnd: .value("End", pulse.endDate),
                        yStart: .value("BG", chartState.minimumChartValueInMgDl),
                        yEnd: .value("BG", pulse.value)
                    )
                    .foregroundStyle(GlucoseChartTreatmentStyle.automaticBasalPulseColor)
                }

                ForEach(visibleTreatmentPoints.scheduledBasalRates) { point in
                    LineMark(x: .value("Time", point.date),
                             y: .value("BG", point.value),
                             series: .value("Series", "scheduledBasal"))
                    .interpolationMethod(.stepStart)
                    .lineStyle(StrokeStyle(lineWidth: GlucoseChartTreatmentStyle.scheduledBasalLineWidth, dash: [3, 2]))
                    .foregroundStyle(GlucoseChartTreatmentStyle.scheduledBasalLineColor)
                }

                treatmentCircleMarks(points: visibleTreatmentPoints.veryLargeCarbs, color: GlucoseChartTreatmentStyle.carbsColor, scale: GlucoseChartTreatmentStyle.veryLargeCarbsScale, symbolSizeMultiplier: ConstantsGlucoseChartSwiftUI.carbTreatmentSymbolSizeMultiplier, labelPosition: .top)
                treatmentCircleMarks(points: visibleTreatmentPoints.largeCarbs, color: GlucoseChartTreatmentStyle.carbsColor, scale: GlucoseChartTreatmentStyle.largeCarbsScale, symbolSizeMultiplier: ConstantsGlucoseChartSwiftUI.carbTreatmentSymbolSizeMultiplier, labelPosition: .top)
                treatmentCircleMarks(points: visibleTreatmentPoints.mediumCarbs, color: GlucoseChartTreatmentStyle.carbsColor, scale: GlucoseChartTreatmentStyle.mediumCarbsScale, symbolSizeMultiplier: ConstantsGlucoseChartSwiftUI.carbTreatmentSymbolSizeMultiplier, labelPosition: .top)
                treatmentCircleMarks(points: visibleTreatmentPoints.smallCarbs, color: GlucoseChartTreatmentStyle.carbsColor, scale: GlucoseChartTreatmentStyle.smallCarbsScale, symbolSizeMultiplier: ConstantsGlucoseChartSwiftUI.carbTreatmentSymbolSizeMultiplier, labelPosition: nil)

                bolusMarks(points: visibleTreatmentPoints.smallBolus, scale: GlucoseChartTreatmentStyle.smallBolusScale, showLabels: false)
                bolusMarks(points: visibleTreatmentPoints.mediumBolus, scale: GlucoseChartTreatmentStyle.mediumBolusScale, showLabels: true)
                bolusMarks(points: visibleTreatmentPoints.largeBolus, scale: GlucoseChartTreatmentStyle.largeBolusScale, showLabels: true)
                bolusMarks(points: visibleTreatmentPoints.veryLargeBolus, scale: GlucoseChartTreatmentStyle.veryLargeBolusScale, showLabels: true)
            }

            // Extra glucose-like data sets, such as original/raw glucose values, can provide lines, points or bordered points.
            ForEach(additionalBgReadingDataSets.indices, id: \.self) { dataSetIndex in
                let dataSet = additionalBgReadingDataSets[dataSetIndex]

                ForEach(dataSet.bgReadingValues.indices, id: \.self) { valueIndex in
                    if dataSet.showLine, let lineColor = dataSet.lineColor {
                        let bgReadingDate = dataSet.bgReadingDates[valueIndex]
                        let bgReadingValue = dataSet.bgReadingValues[valueIndex]
                        let strokeStyle = StrokeStyle(lineWidth: dataSet.lineWidth, dash: dataSet.dash)

                        LineMark(x: .value("Time", bgReadingDate),
                                 y: .value("BG", bgReadingValue),
                                 series: .value("Series", dataSet.seriesIdentifier))
                        .lineStyle(strokeStyle)
                        .foregroundStyle(lineColor)
                    }
                }
            }

            ForEach(additionalBgReadingDataSets.indices, id: \.self) { dataSetIndex in
                let dataSet = additionalBgReadingDataSets[dataSetIndex]

                ForEach(dataSet.bgReadingValues.indices, id: \.self) { valueIndex in
                    if dataSet.showPoints && dataSet.pointBorderColor == nil {
                        let bgReadingDate = dataSet.bgReadingDates[valueIndex]
                        let bgReadingValue = dataSet.bgReadingValues[valueIndex]
                        let pointColor = dataSet.pointColor ?? dataSet.lineColor ?? .clear

                        PointMark(x: .value("Time", bgReadingDate),
                                  y: .value("BG", bgReadingValue))
                        .symbol(Circle())
                        .symbolSize(glucosePointSymbolSize(scale: dataSet.pointSizeMultiplier))
                        .foregroundStyle(pointColor)
                    }
                }
            }

            // Main glucose points.
            ForEach(bgReadingValues.indices, id: \.self) { index in
                PointMark(x: .value("Time", bgReadingDates[index]),
                          y: .value("BG", bgReadingValues[index]))
                    .symbol(Circle())
                    .symbolSize(glucosePointSymbolSize())
                    .foregroundStyle(bgColor(bgValueInMgDl: bgReadingValues[index]))
            }

            // Calibration, BG check and note markers sit above glucose points.
            if chartState != nil {
                borderedCircleMarks(points: visibleCalibrationPoints, outerColor: GlucoseChartTreatmentStyle.calibrationOuterColor, innerColor: GlucoseChartTreatmentStyle.calibrationInnerColor, outerScale: GlucoseChartTreatmentStyle.calibrationOuterScale, innerScale: GlucoseChartTreatmentStyle.calibrationInnerScale)

                borderedTreatmentCircleMarks(points: visibleTreatmentPoints.bgChecks, outerColor: GlucoseChartTreatmentStyle.bgCheckOuterColor, innerColor: GlucoseChartTreatmentStyle.bgCheckInnerColor, outerScale: GlucoseChartTreatmentStyle.bgCheckOuterScale, innerScale: GlucoseChartTreatmentStyle.bgCheckInnerScale)

                treatmentCircleMarks(points: visibleTreatmentPoints.notes, color: GlucoseChartTreatmentStyle.noteColor, scale: GlucoseChartTreatmentStyle.noteScale, labelPosition: nil)
            }

            ForEach(additionalBgReadingDataSets.indices, id: \.self) { dataSetIndex in
                let dataSet = additionalBgReadingDataSets[dataSetIndex]

                ForEach(dataSet.bgReadingValues.indices, id: \.self) { valueIndex in
                    if dataSet.showPoints, let pointBorderColor = dataSet.pointBorderColor, let pointBorderSizeMultiplier = dataSet.pointBorderSizeMultiplier {
                        let bgReadingDate = dataSet.bgReadingDates[valueIndex]
                        let bgReadingValue = dataSet.bgReadingValues[valueIndex]
                        let pointColor = dataSet.pointColor ?? dataSet.lineColor ?? .clear

                        PointMark(x: .value("Time", bgReadingDate),
                                  y: .value("BG", bgReadingValue))
                        .symbol(Circle())
                        .symbolSize(glucosePointSymbolSize(scale: pointBorderSizeMultiplier))
                        .foregroundStyle(pointBorderColor)

                        PointMark(x: .value("Time", bgReadingDate),
                                  y: .value("BG", bgReadingValue))
                        .symbol(Circle())
                        .symbolSize(glucosePointSymbolSize(scale: dataSet.pointSizeMultiplier))
                        .foregroundStyle(pointColor)
                    }
                }
            }

            // Optional overview overlay used by mini charts to show the larger chart's visible time window.
            //
            // This is intentionally data-driven from `chartState` so normal charts ignore it. If the
            // clear window is completely off-screen, the whole plot area is dimmed with no edge bars.
            if overlayWindowIsOutsideVisibleRange {
                RectangleMark(xStart: .value("Overlay start", visibleStartDate),
                              xEnd: .value("Overlay end", xScaleEndDate),
                              yStart: .value("Overlay minimum", domain.lowerBound),
                              yEnd: .value("Overlay maximum", domain.upperBound))
                    .foregroundStyle(ConstantsGlucoseChartSwiftUI.overlayWindowShadeColor)

                RectangleMark(xStart: .value("Overlay start", visibleStartDate),
                              xEnd: .value("Overlay end", xScaleEndDate),
                              yStart: .value("Overlay minimum", domain.lowerBound),
                              yEnd: .value("Overlay maximum", domain.upperBound))
                    .foregroundStyle(ConstantsGlucoseChartSwiftUI.overlayWindowTintColor)
            } else if let overlayWindow = overlayWindow {
                if visibleStartDate < overlayWindow.startDate {
                    RectangleMark(xStart: .value("Overlay start", visibleStartDate),
                                  xEnd: .value("Overlay window start", overlayWindow.startDate),
                                  yStart: .value("Overlay minimum", domain.lowerBound),
                                  yEnd: .value("Overlay maximum", domain.upperBound))
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.overlayWindowShadeColor)

                    RectangleMark(xStart: .value("Overlay start", visibleStartDate),
                                  xEnd: .value("Overlay window start", overlayWindow.startDate),
                                  yStart: .value("Overlay minimum", domain.lowerBound),
                                  yEnd: .value("Overlay maximum", domain.upperBound))
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.overlayWindowTintColor)
                }

                if overlayWindow.endDate < xScaleEndDate {
                    RectangleMark(xStart: .value("Overlay window end", overlayWindow.endDate),
                                  xEnd: .value("Overlay end", xScaleEndDate),
                                  yStart: .value("Overlay minimum", domain.lowerBound),
                                  yEnd: .value("Overlay maximum", domain.upperBound))
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.overlayWindowShadeColor)

                    RectangleMark(xStart: .value("Overlay window end", overlayWindow.endDate),
                                  xEnd: .value("Overlay end", xScaleEndDate),
                                  yStart: .value("Overlay minimum", domain.lowerBound),
                                  yEnd: .value("Overlay maximum", domain.upperBound))
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.overlayWindowTintColor)
                }

                if let overlayWindowStartRuleDate = overlayWindowStartRuleDate {
                    RuleMark(x: .value("Overlay window start", overlayWindowStartRuleDate))
                        .lineStyle(StrokeStyle(lineWidth: ConstantsGlucoseChartSwiftUI.overlayWindowEdgeLineWidth))
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.overlayWindowEdgeColor)
                }

                if let overlayWindowEndRuleDate = overlayWindowEndRuleDate {
                    RuleMark(x: .value("Overlay window end", overlayWindowEndRuleDate))
                        .lineStyle(StrokeStyle(lineWidth: ConstantsGlucoseChartSwiftUI.overlayWindowEdgeLineWidth))
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.overlayWindowEdgeColor)
                }
            }

            // Mini-chart midnight markers are drawn above the optional inactive-window overlay.
            // This keeps day boundaries readable without needing a second brighter marker pass for
            // the dimmed regions.
            if chartType == .miniChart {
                ForEach(xAxisLabelDates, id: \.self) { xAxisLabelDate in
                    RuleMark(x: .value("Mini-chart midnight", xAxisLabelDate))
                        .lineStyle(StrokeStyle(lineWidth: ConstantsGlucoseChartSwiftUI.miniChartXAxisMidnightLineSize))
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.miniChartXAxisMidnightLineColor)
                }
            }

            // add a phantom glucose point five minutes after the end of any BG values to fix the end point
            // we use it to make sure the chart ends "now" even if the last bg reading was some time ago
            // it also serves to make sure the last chartpoint circle isn't cut off by the y-axis
            PointMark(x: .value("Time", visibleEndDate.addingTimeInterval(5 * 60)),
                      y: .value("BG", 100))
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter)
            .foregroundStyle(.clear)
        }
        .chartXAxis {
            AxisMarks(values: xAxisLabelDates) {
                if let value = $0.as(Date.self) {
                    if chartType.xAxisShowLabels() {
                        AxisValueLabel {
                            let shouldHideLabel = abs(visibleEndDate.distance(to: value)) < ConstantsGlucoseChartSwiftUI.xAxisLabelFirstClippingInMinutes || abs(visibleStartDate.distance(to: value)) < ConstantsGlucoseChartSwiftUI.xAxisLabelLastClippingInMinutes ? true : false

                            Text(value.formatted(.dateTime.hour()))
                                .opacity(shouldHideLabel ? 0 : 1)
                                .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisLabelColor)
                                .font(.footnote)
                                .monospacedDigit()
                                .frame(width: ConstantsGlucoseChartSwiftUI.xAxisLabelWidth, alignment: .center)
                                .offset(x: chartType.xAxisLabelOffsetX(), y: chartType.xAxisLabelOffsetY())
                        }
                    }

                    if chartType != .miniChart {
                        AxisGridLine()
                            .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisGridLineColor)
                    }
                }
            }
        }
        .chartYAxis {
            if !yAxisContextMarks.labeledValues.isEmpty {
                AxisMarks(values: yAxisContextMarks.labeledValues) {
                    if let value = $0.as(Double.self) {
                        AxisValueLabel {
                            yAxisLabel(value: value, style: .dimmed)
                        }
                    }
                }
            }

            AxisMarks(values: [lowLimitInMgDl, highLimitInMgDl]) {
                if let value = $0.as(Double.self) {
                    AxisValueLabel {
                        yAxisLabel(value: value, style: .objective)
                    }
                }
            }

            if chartType.yAxisShowUrgentLowHighLines() {
                AxisMarks(values: [urgentLowLimitInMgDl, urgentHighLimitInMgDl]) {
                    if let value = $0.as(Double.self) {
                        AxisValueLabel {
                            yAxisLabel(value: value, style: .secondaryObjective)
                        }
                    }
                }
            }
        }
        .if(chartType.frame()) { view in
            view.frame(width: chartWidth, height: chartHeight)
        }
        .if(chartAspectRatio.enable && !overrideChartHeightWasPassed) { view in
            view.aspectRatio(chartAspectRatio.aspectRatio, contentMode: chartAspectRatio.contentMode)
        }
        .if(overrideChartHeightWasPassed) { view in
            view
                .frame(maxWidth: .infinity)
                .frame(height: chartHeight)
        }
        .if(chartPadding.enable) { view in
            view.padding(chartPadding.padding)
        }
        .chartYAxis(chartType.yAxisShowLabels())
        .chartXScale(domain: xScaleDomain)
        .chartYScale(domain: domain)
        .chartOverlay { chartProxy in
            GeometryReader { geometryProxy in
                if usesMainChartYAxisContext {
                    if #available(iOS 17.0, watchOS 10.0, *) {
                        if let plotFrame = chartProxy.plotFrame {
                            mainChartPlotBorder(plotRect: geometryProxy[plotFrame], overlaySize: geometryProxy.size)
                        }
                    } else {
                        mainChartPlotBorder(plotRect: geometryProxy[chartProxy.plotAreaFrame], overlaySize: geometryProxy.size)
                    }
                }
            }
        }
        .modifier(ChartBackgroundModifier(chartType: chartType))
        .clipShape(RoundedRectangle(cornerRadius: chartType.cornerRadius()))
        .onAppear {
            guard usesMainChartYAxisContext else { return }

            resetRetainedYAxisMaximum(to: calculatedMaximumDomainValue)
        }
        .onCompatibleChange(of: calculatedMaximumDomainValue) { newMaximum in
            guard usesMainChartYAxisContext else { return }

            retainYAxisMaximum(newMaximum)
            // Cached chart data can arrive after scrolling stops. Restarting the idle period for
            // every candidate change prevents an older pending reset from superseding newer data.
            scheduleYAxisAutoReset(to: newMaximum)
        }
        .onCompatibleChange(of: visibleEndDate) { _ in
            guard usesMainChartYAxisContext else { return }

            retainYAxisMaximum(calculatedMaximumDomainValue)
            scheduleYAxisAutoReset(to: calculatedMaximumDomainValue)
        }
        .onCompatibleChange(of: mainChartYAxisResetRevision) { _ in
            guard usesMainChartYAxisContext else { return }

            resetRetainedYAxisMaximum(to: calculatedMaximumDomainValue)
        }
        .onDisappear {
            yAxisAutoResetWorkItem?.cancel()
            yAxisAutoResetWorkItem = nil
        }
    }

    private func retainYAxisMaximum(_ maximumInMgDl: Double) {
        var retentionState = yAxisRetentionState
        retentionState.retain(maximumInMgDl: maximumInMgDl)
        yAxisRetentionState = retentionState
    }

    private func resetRetainedYAxisMaximum(to maximumInMgDl: Double) {
        yAxisAutoResetWorkItem?.cancel()
        yAxisAutoResetWorkItem = nil

        var retentionState = yAxisRetentionState
        retentionState.reset(to: maximumInMgDl)
        yAxisRetentionState = retentionState
    }

    private func scheduleYAxisAutoReset(to maximumInMgDl: Double) {
        yAxisAutoResetWorkItem?.cancel()
        yAxisAutoResetWorkItem = nil

        let workItem = DispatchWorkItem {
            resetRetainedYAxisMaximum(to: maximumInMgDl)
        }
        yAxisAutoResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ConstantsHomeView.mainChartYAxisAutoResetDelay,
            execute: workItem
        )
    }

    // MARK: - Chart Mark Helpers

    private func glucosePointSymbolSize(scale: Double = 1.0) -> Double {
        glucoseCircleDiameter * scale * ConstantsGlucoseChartSwiftUI.glucosePointSymbolSizeMultiplier
    }

    private func mainChartPlotBorder(plotRect: CGRect, overlaySize: CGSize) -> some View {
        let lineInset = ConstantsGlucoseChartSwiftUI.chartPlotBorderLineWidth / 2
        let trailingXPosition = plotRect.maxX - lineInset
        let bottomYPosition = plotRect.maxY - lineInset

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(ConstantsGlucoseChartSwiftUI.chartPlotBorderColor)
                .frame(width: ConstantsGlucoseChartSwiftUI.chartPlotBorderLineWidth, height: plotRect.height)
                .offset(x: trailingXPosition, y: plotRect.minY)

            Rectangle()
                .fill(ConstantsGlucoseChartSwiftUI.chartPlotBorderColor)
                .frame(width: plotRect.width, height: ConstantsGlucoseChartSwiftUI.chartPlotBorderLineWidth)
                .offset(x: plotRect.minX, y: bottomYPosition)
        }
        .frame(width: overlaySize.width, height: overlaySize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func treatmentCircleMarks(points: [GlucoseChartTreatmentPoint], color: Color, scale: Double, symbolSizeMultiplier: Double = 1.0, labelPosition: AnnotationPosition?) -> some ChartContent {
        ForEach(points) { point in
            PointMark(x: .value("Time", point.date),
                      y: .value("BG", point.yValue))
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter * scale * symbolSizeMultiplier)
            .foregroundStyle(color)
            .annotation(position: labelPosition ?? .overlay) {
                if labelPosition != nil, let label = point.label {
                    treatmentLabel(label)
                }
            }
        }
    }

    private func bolusMarks(points: [GlucoseChartTreatmentPoint], scale: Double, showLabels: Bool) -> some ChartContent {
        let symbolWidth = bolusTriangleSize() * scale
        let symbolHeight = symbolWidth * GlucoseChartTreatmentStyle.bolusTriangleHeightScale

        return ForEach(points) { point in
            PointMark(x: .value("Time", point.date),
                      y: .value("BG", point.yValue))
            .symbol {
                DownTriangle()
                    .fill(GlucoseChartTreatmentStyle.bolusColor)
                    .frame(width: symbolWidth, height: symbolHeight)
            }
            .annotation(position: .bottom) {
                if showLabels, let label = point.label {
                    treatmentLabel(label)
                }
            }
        }
    }

    private func bolusTriangleSize() -> Double {
        switch hoursToShow {
        case 0...3:
            return GlucoseChartTreatmentStyle.bolusTriangleSize3h
        case 3...8:
            return GlucoseChartTreatmentStyle.bolusTriangleSize6h
        case 8...16:
            return GlucoseChartTreatmentStyle.bolusTriangleSize12h
        default:
            return GlucoseChartTreatmentStyle.bolusTriangleSize24h
        }
    }

    @ChartContentBuilder private func agpBackgroundMarks() -> some ChartContent {
        // draw the widest band first, then the inner band, then the median line
        // the glucose points are drawn afterwards so they stay as the main foreground data
        ForEach(agpBackgroundPoints) { point in
            AreaMark(x: .value("Time", point.date),
                     yStart: .value("AGP P5", point.p5MgDl),
                     yEnd: .value("AGP P95", point.p95MgDl),
                     series: .value("Series", "AGP 5-95%"))
            .interpolationMethod(.linear)
            .foregroundStyle(ConstantsGlucoseChartSwiftUI.agpOuterBand)
            .opacity(agpBackgroundOpacityMultiplier)
        }

        ForEach(agpBackgroundPoints) { point in
            AreaMark(x: .value("Time", point.date),
                     yStart: .value("AGP P25", point.p25MgDl),
                     yEnd: .value("AGP P75", point.p75MgDl),
                     series: .value("Series", "AGP 25-75%"))
            .interpolationMethod(.linear)
            .foregroundStyle(ConstantsGlucoseChartSwiftUI.agpInnerBand)
            .opacity(agpBackgroundOpacityMultiplier)
        }

        ForEach(agpBackgroundPoints) { point in
            LineMark(x: .value("Time", point.date),
                     y: .value("AGP median", point.medianMgDl),
                     series: .value("Series", "AGP median"))
            .interpolationMethod(.linear)
            .lineStyle(StrokeStyle(lineWidth: ConstantsGlucoseChartSwiftUI.agpMedianLineWidth))
            .foregroundStyle(ConstantsGlucoseChartSwiftUI.agpMedian)
            .opacity(agpBackgroundOpacityMultiplier)
        }
    }

    private func borderedCircleMarks(points: [GlucoseChartPoint], outerColor: Color, innerColor: Color, outerScale: Double, innerScale: Double) -> some ChartContent {
        ForEach(points) { point in
            PointMark(x: .value("Time", point.date),
                      y: .value("BG", point.value))
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter * outerScale)
            .foregroundStyle(outerColor)

            PointMark(x: .value("Time", point.date),
                      y: .value("BG", point.value))
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter * innerScale)
            .foregroundStyle(innerColor)
        }
    }

    private func borderedTreatmentCircleMarks(points: [GlucoseChartTreatmentPoint], outerColor: Color, innerColor: Color, outerScale: Double, innerScale: Double) -> some ChartContent {
        ForEach(points) { point in
            PointMark(x: .value("Time", point.date),
                      y: .value("BG", point.yValue))
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter * outerScale)
            .foregroundStyle(outerColor)

            PointMark(x: .value("Time", point.date),
                      y: .value("BG", point.yValue))
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter * innerScale)
            .foregroundStyle(innerColor)
        }
    }

    private func treatmentLabel(_ label: String) -> some View {
        Text(" \(label) ")
            .font(.system(size: GlucoseChartTreatmentStyle.treatmentLabelFontSize, weight: .bold))
            .foregroundStyle(GlucoseChartTreatmentStyle.treatmentLabelFontColor)
            .background(GlucoseChartTreatmentStyle.treatmentLabelBackgroundColor)
    }
}

// MARK: - Visible Treatment Filtering

private extension GlucoseChartTreatmentPoints {

    /// Returns only points visible in the current chart window.
    ///
    /// Most markers can be filtered directly. Basal step series need synthetic edge points because
    /// the previous segment may have started before the visible start date or continue after the
    /// visible end date. Without this, the continuous basal graph clips at the chart edges.
    func filter(from startDate: Date, to endDate: Date) -> GlucoseChartTreatmentPoints {
        GlucoseChartTreatmentPoints(
            smallBolus: smallBolus.filter { $0.date >= startDate && $0.date <= endDate },
            mediumBolus: mediumBolus.filter { $0.date >= startDate && $0.date <= endDate },
            largeBolus: largeBolus.filter { $0.date >= startDate && $0.date <= endDate },
            veryLargeBolus: veryLargeBolus.filter { $0.date >= startDate && $0.date <= endDate },
            smallCarbs: smallCarbs.filter { $0.date >= startDate && $0.date <= endDate },
            mediumCarbs: mediumCarbs.filter { $0.date >= startDate && $0.date <= endDate },
            largeCarbs: largeCarbs.filter { $0.date >= startDate && $0.date <= endDate },
            veryLargeCarbs: veryLargeCarbs.filter { $0.date >= startDate && $0.date <= endDate },
            bgChecks: bgChecks.filter { $0.date >= startDate && $0.date <= endDate },
            notes: notes.filter { $0.date >= startDate && $0.date <= endDate },
            scheduledBasalRates: scheduledBasalRates.visibleStepPoints(from: startDate, to: endDate, idPrefix: "visible-scheduled-basal"),
            basalRates: basalRates.visibleStepPoints(from: startDate, to: endDate, idPrefix: "visible-temp-basal"),
            basalRateFill: basalRateFill.visibleStepPoints(from: startDate, to: endDate, idPrefix: "visible-temp-basal-fill"),
            automaticBasalPulses: automaticBasalPulses.filter { $0.endDate >= startDate && $0.startDate <= endDate }
        )
    }

    var allRenderableValues: [Double] {
        smallBolus.map { $0.yValue }
        + mediumBolus.map { $0.yValue }
        + largeBolus.map { $0.yValue }
        + veryLargeBolus.map { $0.yValue }
        + smallCarbs.map { $0.yValue }
        + mediumCarbs.map { $0.yValue }
        + largeCarbs.map { $0.yValue }
        + veryLargeCarbs.map { $0.yValue }
        + bgChecks.map { $0.yValue }
        + notes.map { $0.yValue }
        + scheduledBasalRates.map { $0.value }
        + basalRates.map { $0.value }
        + basalRateFill.map { $0.value }
        + automaticBasalPulses.map { $0.value }
    }

}

// MARK: - Visible Step Series Edges

extension Array where Element == GlucoseChartPoint {

    /// Adds synthetic start/end edge points so step lines remain continuous when a visible range cuts through a basal segment.
    ///
    /// Applied at visible-filter time so the cached basal series can be wider than the chart without
    /// losing the first or last visible horizontal segment.
    func visibleStepPoints(from startDate: Date, to endDate: Date, idPrefix: String) -> [GlucoseChartPoint] {
        guard startDate < endDate, !isEmpty else { return [] }

        var visiblePoints = [GlucoseChartPoint]()
        // Equal-time step points must retain their original previous-rate then new-rate order.
        // Reversing that pair changes the rendered basal value while scrolling the same range.
        let points = enumerated().sorted { lhs, rhs in
            lhs.element.date == rhs.element.date
                ? lhs.offset < rhs.offset
                : lhs.element.date < rhs.element.date
        }.map(\.element)

        if let startPoint = points.last(where: { $0.date <= startDate }) {
            visiblePoints.append(GlucoseChartPoint(date: startDate, value: startPoint.value, idPrefix: "\(idPrefix)-start"))
        }

        visiblePoints.append(contentsOf: points.filter { $0.date > startDate && $0.date < endDate })

        if let endPoint = points.last(where: { $0.date <= endDate }) {
            visiblePoints.append(GlucoseChartPoint(date: endDate, value: endPoint.value, idPrefix: "\(idPrefix)-end"))
        }

        return visiblePoints
    }

}

// MARK: - Shapes

private struct DownTriangle: Shape {

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()

        return path
    }

}

// MARK: - Compatibility

private extension View {

    /// Uses the modern change handler while preserving targets that still support iOS 16.
    @ViewBuilder
    func onCompatibleChange<Value: Equatable>(
        of value: Value,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        if #available(iOS 17.0, watchOS 10.0, *) {
            onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            onChange(of: value, perform: action)
        }
    }

}

// MARK: - Background

// apply a view modifier so that we can correctly show the chart views when displayed as a widget
// this ensures that the widgets can be displayed in tinted or clear styles (in iOS26)
private struct ChartBackgroundModifier: ViewModifier {
    let chartType: GlucoseChartType

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            if chartType == .miniChart {
                content
                    .background(chartType.backgroundColor())
                    .containerBackground(.clear, for: .widget)
            } else {
                content.containerBackground(.clear, for: .widget)
            }
        } else {
            content.background(chartType.backgroundColor())
        }
    }
}
