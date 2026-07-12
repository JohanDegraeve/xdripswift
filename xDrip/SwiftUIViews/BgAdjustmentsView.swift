//
//  BgAdjustmentsView.swift
//  xdrip
//
//  Created by Paul Plant on 2/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Glucose post-processing controls and a live preview of their effect on stored readings.
///
/// Draft form values remain local until confirmed. The preview arrays are rebuilt from the same
/// post-processing manager used by the application rather than applying separate display logic.
struct BgAdjustmentsView: View {
    private let minimumGlucoseValueInMgDl = ConstantsCalibrationAlgorithms.minimumBgReadingCalculatedValue
    private let maximumGlucoseValueInMgDl = ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue

    // Track whether the user last changed the offset by nudging the delta
    // or by directly entering an adjusted glucose value.
    private enum OffsetAdjustmentInputType {
        case adjustedGlucoseValue
        case offsetValue
    }

    private struct ApplyFromOption {
        let title: String
        let timeInterval: TimeInterval
    }

    /// available manual historical apply windows in hours
    private let applyFromPeriodsInHours = [3, 6, 12]

    private let bgReadingsAccessor: BgReadingsAccessor
    private let treatmentEntryAccessor: TreatmentEntryAccessor
    private let bgPostProcessingManager: BgPostProcessingManager

    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @State private var bgReadings: [BgReading] = []

    @State private var calculatedBgReadingValues: [Double] = []
    @State private var calculatedBgReadingDates: [Date] = []
    @State private var bgCheckTreatmentChartPointsValues: [Double] = []
    @State private var bgCheckTreatmentChartPointsDates: [Date] = []
    @State private var previewAllFinalBgReadingValues: [Double] = []
    @State private var previewAllFinalBgReadingDates: [Date] = []
    @State private var previewVisibleFinalBgReadingValues: [Double] = []
    @State private var previewVisibleFinalBgReadingDates: [Date] = []

    @State private var currentBgAdjustment: BgAdjustment?

    @State private var enableAdjustment = UserDefaults.standard.enableAdjustment
    @State private var enableSmoothing = UserDefaults.standard.enableSmoothing
    @State private var useFiveMinuteReadings = UserDefaults.standard.useFiveMinuteReadings
    @State private var draftAdjustedGlucoseValue = ""
    @State private var slope = "1.00"
    @State private var intercept = "0.0"
    @State private var adjustmentShapeTypeRawValue = ConstantsBgAdjustment.defaultShapeType.rawValue
    @State private var openedSlopeValue = 1.00
    @State private var openedInterceptValue = 0.0
    @State private var smoothingAlgorithm = UserDefaults.standard.bgSmoothingAlgorithm
    @State private var smoothingStrength = UserDefaults.standard.bgSmoothingStrength
    @State private var selectedApplyFromPeriodIndex = 0
    @State private var chartHoursToShow = Double(UserDefaults.standard.postProcessingPreviewChartHoursToShow)
    @State private var showingBasicAdjustmentInputSheet = false
    @State private var viewStateWasLoaded = false
    @State private var offsetAdjustmentInputType: OffsetAdjustmentInputType = .offsetValue
    private let chartContextSeparator = ", "
    /// refresh the chart while the view stays open so the time axis and points
    /// continue to reflect newly arrived readings
    private let chartRefreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(bgReadingsAccessor: BgReadingsAccessor, treatmentEntryAccessor: TreatmentEntryAccessor, bgPostProcessingManager: BgPostProcessingManager) {
        self.bgReadingsAccessor = bgReadingsAccessor
        self.treatmentEntryAccessor = treatmentEntryAccessor
        self.bgPostProcessingManager = bgPostProcessingManager
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ConstantsAppColors.groupedBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    chartView()
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                    List {
                        adjustmentSection()
                        smoothingSection()
                        readingFrequencySection()
                        applyFromSection()
                    }
                }
            }
            .navigationTitle(Texts_HomeView.postProcessingTitle)
            .toolbarBackground(ConstantsAppColors.groupedBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: {
                        self.presentationMode.wrappedValue.dismiss()
                    })
                }

            }
            .sheet(isPresented: $showingBasicAdjustmentInputSheet) {
                BasicAdjustmentInputView(currentGlucoseValueString: displayBgString(for: bgReadings.last?.calculatedValue), glucoseAdjustmentValueString: inputGlucoseAdjustmentValueString(for: draftAdjustedGlucoseValue), unitString: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol, enteredGlucoseValue: $draftAdjustedGlucoseValue, onCancel: {
                    draftAdjustedGlucoseValue = adjustedGlucoseInputValueString()
                    showingBasicAdjustmentInputSheet = false
                }, onConfirm: {
                    confirmDraftAdjustedGlucoseValue()
                    showingBasicAdjustmentInputSheet = false
                })
            }
            .onAppear {
                if !viewStateWasLoaded {
                    loadViewState()
                    viewStateWasLoaded = true
                }
            }
            .onChange(of: enableAdjustment) { _ in
                updatePreviewData()
            }
            .onChange(of: enableSmoothing) { _ in
                updatePreviewData()
            }
            .onChange(of: useFiveMinuteReadings) { _ in
                updatePreviewData()
            }
            .onChange(of: adjustmentShapeTypeRawValue) { _ in
                updatePreviewData()
            }
            .onChange(of: slope) { _ in
                updatePreviewData()
            }
            .onChange(of: intercept) { _ in
                updatePreviewData()
            }
            .onChange(of: smoothingStrength) { _ in
                updatePreviewData()
            }
            .onChange(of: smoothingAlgorithm) { _ in
                updatePreviewData()
            }
            .onChange(of: chartHoursToShow) { newValue in
                UserDefaults.standard.postProcessingPreviewChartHoursToShow = Int(newValue)
                loadBgReadings()
                updatePreviewData()
            }
            .onReceive(chartRefreshTimer) { _ in
                loadBgReadings()
                updatePreviewData()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var adjustmentShapeType: BgAdjustmentShapeType {
        return BgAdjustmentShapeType(rawValue: adjustmentShapeTypeRawValue) ?? ConstantsBgAdjustment.defaultShapeType
    }

    @ViewBuilder private func chartView() -> some View {
        let chartBackgroundColor = Color(.secondarySystemGroupedBackground)

        VStack(alignment: .leading, spacing: 2) {
            chartContextView()
                .font(.subheadline)

            GlucoseChartView(glucoseChartType: .siriGlucoseIntent, bgReadingValues: previewBgReadingValues(), bgReadingDates: previewBgReadingDates(), additionalBgReadingDataSets: chartDataSets(), isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl, urgentLowLimitInMgDl: UserDefaults.standard.urgentLowMarkValue, lowLimitInMgDl: UserDefaults.standard.lowMarkValue, highLimitInMgDl: UserDefaults.standard.highMarkValue, urgentHighLimitInMgDl: UserDefaults.standard.urgentHighMarkValue, liveActivityType: nil, hoursToShowScalingHours: chartHoursToShow, glucoseCircleDiameterScalingHours: chartHoursToShow, overrideChartHeight: 120, overrideChartWidth: nil, highContrast: nil)

            HStack {
                Text(Texts_HomeView.postProcessingPreviewHours)
                    .foregroundStyle(Color(.colorSecondary))
                    .font(.subheadline)
                Spacer()
                Picker(Texts_HomeView.postProcessingPreviewHours, selection: Binding<Int>(
                    get: { Int(chartHoursToShow) },
                    set: { selectedChartHoursToShow in
                        chartHoursToShow = Double(selectedChartHoursToShow)
                    }
                )) {
                    ForEach(ConstantsBgAdjustment.previewChartHoursToShowOptions, id: \.self) { previewChartHoursToShow in
                        Text("\(previewChartHoursToShow)h")
                            .tag(previewChartHoursToShow)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(chartBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func adjustmentSection() -> some View {
        Section(header: Text(Texts_HomeView.postProcessingAdjustment), footer: adjustmentSectionFooter()) {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(Texts_HomeView.postProcessingEnable, isOn: $enableAdjustment)
                    .disabled(!shouldAllowAdjustmentForCurrentSource())

                if effectiveEnableAdjustment(), let previewBgCheckHintText = previewBgCheckHintText() {
                    Text(previewBgCheckHintText)
                        .font(.footnote)
                        .foregroundStyle(Color(.systemRed))
                }
            }

            if effectiveEnableAdjustment() {
                offsetAdjustmentValueRow()

                scaleAdjustmentControl()
            }
        }
    }

    @ViewBuilder private func adjustmentSectionFooter() -> some View {
        if let adjustmentDisabledMessage = adjustmentDisabledMessage() {
            Text(adjustmentDisabledMessage)
        }
    }

    private func advancedAdjustmentValueRow(title: String, value: String, valueColor: Color, minusDisabled: Bool = false, plusDisabled: Bool = false, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button("-") {
                onMinus()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(minusDisabled)

            Text(value)
                .foregroundStyle(valueColor)
                .frame(minWidth: 44, alignment: .center)

            Button("+") {
                onPlus()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(plusDisabled)
        }
    }

    @ViewBuilder private func offsetAdjustmentValueRow() -> some View {
        HStack {
            Text(Texts_HomeView.postProcessingOffset)
            Spacer()
            Button {
                draftAdjustedGlucoseValue = adjustedGlucoseInputValueString()
                showingBasicAdjustmentInputSheet = true
            } label: {
                Text(displayBgString(for: currentAdjustedGlucoseValueInMgDl()))
                    .foregroundStyle(offsetAdjustmentInputType == .adjustedGlucoseValue ? Color(.colorPrimary) : Color(.colorTertiary))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            Button("-") {
                updateIntercept(by: -interceptNudgeValueInMgDl())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canDecreaseOffsetValue())

            Text(displayAdjustmentValueString(for: intercept.toDouble() ?? 0.0, includeUnit: false))
                .foregroundStyle(offsetValueTextColor())
                .frame(minWidth: 44, alignment: .center)

            Button("+") {
                updateIntercept(by: interceptNudgeValueInMgDl())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canIncreaseOffsetValue())
        }
    }

    @ViewBuilder private func scaleAdjustmentControl() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            advancedAdjustmentValueRow(title: Texts_HomeView.postProcessingScale, value: displaySlopeString(for: slope.toDouble()), valueColor: scaleValueTextColor(), minusDisabled: !canDecreaseScaleValue(), plusDisabled: !canIncreaseScaleValue(), onMinus: {
                updateSlope(by: -ConstantsBgAdjustment.slopeNudgeValue)
            }, onPlus: {
                updateSlope(by: ConstantsBgAdjustment.slopeNudgeValue)
            })

            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)

            HStack {
                Text(Texts_HomeView.postProcessingShape)
                Spacer()
                compactAdjustmentShapeControl()
            }

            if shouldShowSelectedAdjustmentShapeDescription() {
                Text(selectedAdjustmentShapeDescription())
                    .font(.footnote)
                    .foregroundStyle(Color(.colorSecondary))
            }
        }
        .padding(.vertical, 2)
    }

    private func smoothingSection() -> some View {
        Section(header: Text(Texts_HomeView.postProcessingSmoothing)) {
            Toggle(Texts_HomeView.postProcessingEnable, isOn: $enableSmoothing)

            if enableSmoothing {
                Picker(Texts_HomeView.postProcessingStrength, selection: $smoothingStrength) {
                    smoothingStrengthPickerItem(title: Texts_HomeView.postProcessingLight, strength: 0)
                    smoothingStrengthPickerItem(title: Texts_HomeView.postProcessingMedium, strength: 1)
                    smoothingStrengthPickerItem(title: Texts_HomeView.postProcessingStrong, strength: 2)
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 10) {
                    Picker(Texts_HomeView.postProcessingAlgorithm, selection: $smoothingAlgorithm) {
                        ForEach(BgSmoothingAlgorithm.allCases, id: \.self) { smoothingAlgorithm in
                            Text(smoothingAlgorithm.description)
                                .tag(smoothingAlgorithm)
                        }
                    }

                    Text(smoothingAlgorithm.footerDescription)
                        .font(.footnote)
                        .foregroundStyle(Color(.colorSecondary))
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder private func readingFrequencySection() -> some View {
        if sourceCanUseFiveMinuteReadings() {
            Section(header: Text(Texts_HomeView.postProcessingReadingFrequency)) {
                Toggle(Texts_HomeView.postProcessingFiveMinuteReadings, isOn: $useFiveMinuteReadings)
            }
        }
    }

    private func applyFromSection() -> some View {
        let applyFromOptions = availableApplyFromOptions()

        return Section(header: Text(applyFromSectionTitle())) {
            VStack(alignment: .leading, spacing: 10) {
                compactApplyFromControl(applyFromOptions: applyFromOptions)

                if let sourceDataNotUpdatedWarningText = sourceDataNotUpdatedWarningText() {
                    Text(sourceDataNotUpdatedWarningText)
                        .font(.footnote)
                        .foregroundStyle(Color(.colorSecondary))
                }
            }

            Button(action: {
                applySelectedChanges()
            }) {
                Text(Texts_HomeView.postProcessingApply)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(applyButtonTintColor())
            .disabled(!canApplySelectedChanges())
        }
    }

    private func smoothingStrengthPickerItem(title: String, strength: Int) -> some View {
        Text(title)
            .tag(strength)
    }

    private func chartContextView() -> Text {
        var chartContextParts = [(title: String, value: Double, isFinalValue: Bool)]()

        if let originalValue = bgReadings.last?.calculatedValue {
            let finalValueIsOriginal = !enableAdjustment && !enableSmoothing
            chartContextParts.append((title: Texts_HomeView.postProcessingOriginal, value: originalValue, isFinalValue: finalValueIsOriginal))
        }

        if effectiveEnableAdjustment(), let adjustedValue = latestAdjustedPreviewValue() {
            let finalValueIsAdjusted = !enableSmoothing
            chartContextParts.append((title: Texts_HomeView.postProcessingAdjusted, value: adjustedValue, isFinalValue: finalValueIsAdjusted))
        }

        if enableSmoothing, let smoothedValue = latestSmoothedPreviewValue() {
            chartContextParts.append((title: Texts_HomeView.postProcessingSmoothed, value: smoothedValue, isFinalValue: true))
        }

        guard chartContextParts.count > 0 else {
            return Text(Texts_HomeView.postProcessingNoCurrentValues)
                .foregroundColor(.secondary)
        }

        var returnText = Text("")

        for (index, chartContextPart) in chartContextParts.enumerated() {
            if index > 0 {
                returnText = returnText + Text(chartContextSeparator).foregroundColor(.secondary)
            }

            returnText = returnText + chartContextPartText(for: chartContextPart.title, value: chartContextPart.value, isFinalValue: chartContextPart.isFinalValue)
        }

        return returnText
    }

    private func chartContextPartText(for title: String, value: Double, isFinalValue: Bool) -> Text {
        let titleColor: Color = isFinalValue ? .white : .secondary
        let valueColor: Color = isFinalValue ? glucoseTextColor(for: value) : .secondary
        let titleText = Text(title + ": ").foregroundColor(titleColor)
        let valueText = Text(displayBgValueString(for: value)).foregroundColor(valueColor)
        let partText = titleText + valueText

        if isFinalValue {
            return partText.bold()
        }

        return partText
    }

    private func confirmDraftAdjustedGlucoseValue() {
        guard let adjustedGlucoseValueInMgDl = enteredGlucoseValueInMgDl(draftAdjustedGlucoseValue), let latestBgReading = bgReadings.last else { return }

        intercept = (adjustedGlucoseValueInMgDl - latestBgReading.calculatedValue).round(toDecimalPlaces: 1).stringWithoutTrailingZeroes
        offsetAdjustmentInputType = .adjustedGlucoseValue
    }

    private func chartDataSets() -> [GlucoseChartDataSet] {
        var dataSets = [GlucoseChartDataSet]()

        // Show the original calculated values behind the previewed final values
        // so the user can compare the effect of adjustment and smoothing.
        if enableAdjustment || enableSmoothing || effectiveUseFiveMinuteReadings() {
            dataSets.append(GlucoseChartDataSet(bgReadingValues: calculatedBgReadingValues, bgReadingDates: calculatedBgReadingDates, seriesIdentifier: "original", lineColor: nil, pointColor: ConstantsGlucoseChart.glucoseOriginalColor, lineWidth: 0, dash: [], showLine: false, showPoints: true, pointSizeMultiplier: 1.0, pointBorderColor: nil, pointBorderSizeMultiplier: nil))
        }

        if bgCheckTreatmentChartPointsValues.count > 0 {
            dataSets.append(GlucoseChartDataSet(bgReadingValues: bgCheckTreatmentChartPointsValues, bgReadingDates: bgCheckTreatmentChartPointsDates, seriesIdentifier: "bgCheckTreatments", lineColor: nil, pointColor: ConstantsGlucoseChart.bgCheckTreatmentColorInner, lineWidth: 0, dash: [], showLine: false, showPoints: true, pointSizeMultiplier: Double(ConstantsGlucoseChart.bgCheckTreatmentScaleInner) * 1.15, pointBorderColor: ConstantsGlucoseChart.bgCheckTreatmentColorOuter, pointBorderSizeMultiplier: Double(ConstantsGlucoseChart.bgCheckTreatmentScaleOuter) * 1.25))
        }

        return dataSets
    }

    private func loadViewState() {
        bgPostProcessingManager.refreshSourceContext()
        enableAdjustment = UserDefaults.standard.enableAdjustment
        enableSmoothing = UserDefaults.standard.enableSmoothing
        useFiveMinuteReadings = UserDefaults.standard.useFiveMinuteReadings
        smoothingAlgorithm = UserDefaults.standard.bgSmoothingAlgorithm
        smoothingStrength = UserDefaults.standard.bgSmoothingStrength
        chartHoursToShow = Double(UserDefaults.standard.postProcessingPreviewChartHoursToShow)
        currentBgAdjustment = bgPostProcessingManager.latestActiveBgAdjustment()

        loadBgReadings()

        if let currentBgAdjustment = currentBgAdjustment {
            slope = currentBgAdjustment.slope.round(toDecimalPlaces: 2).description
            intercept = currentBgAdjustment.intercept.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes
            adjustmentShapeTypeRawValue = currentBgAdjustment.adjustmentShapeType
            openedSlopeValue = currentBgAdjustment.slope.round(toDecimalPlaces: 2)
            openedInterceptValue = currentBgAdjustment.intercept.round(toDecimalPlaces: 1)
        } else {
            slope = "1.00"
            intercept = "0.0"
            adjustmentShapeTypeRawValue = ConstantsBgAdjustment.defaultShapeType.rawValue
            openedSlopeValue = 1.0
            openedInterceptValue = 0.0
        }

        if enableAdjustment, let interceptValue = intercept.toDouble(), abs(interceptValue) > 0.0001 {
            offsetAdjustmentInputType = .offsetValue
        } else {
            offsetAdjustmentInputType = .adjustedGlucoseValue
        }

        draftAdjustedGlucoseValue = adjustedGlucoseInputValueString()
        updatePreviewData()
    }

    private func loadBgReadings() {
        let chartWindowStartDate = Date(timeIntervalSinceNow: -(chartHoursToShow * 3600))
        let fromDate = previewChartStartDate(chartWindowStartDate: chartWindowStartDate)
        let currentSensor = previewChartSensor()

        bgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: fromDate, forSensor: currentSensor, ignoreRawData: true, ignoreCalculatedValue: false, includingSuppressed: true).sorted { $0.timeStamp < $1.timeStamp }

        if !sourceCanUseFiveMinuteReadings() {
            useFiveMinuteReadings = false
        }

        calculatedBgReadingValues = bgReadings.map { $0.calculatedValue }
        calculatedBgReadingDates = bgReadings.map { $0.timeStamp }
        loadBgCheckTreatmentChartPoints(fromDate: fromDate)
        normalizeSelectedApplyFromOptionIndex()

        previewAllFinalBgReadingValues = []
        previewAllFinalBgReadingDates = []
        previewVisibleFinalBgReadingValues = []
        previewVisibleFinalBgReadingDates = []
    }

    private func previewChartStartDate(chartWindowStartDate: Date) -> Date {
        guard ConstantsBgAdjustment.showOnlyLatestDataSourceInPreviewChart else { return chartWindowStartDate }

        return max(chartWindowStartDate, UserDefaults.standard.postProcessingStartTimeStamp ?? .distantPast)
    }

    private func previewChartSensor() -> Sensor? {
        guard ConstantsBgAdjustment.showOnlyLatestDataSourceInPreviewChart else { return nil }

        return bgPostProcessingManager.currentSensorForPostProcessing()
    }

    private func loadBgCheckTreatmentChartPoints(fromDate: Date) {
        let bgCheckTreatments = treatmentEntryAccessor.getLatestTreatments(limit: nil, fromDate: fromDate)
            .filter { !$0.treatmentdeleted && $0.treatmentType == .BgCheck }
            .sorted { $0.date < $1.date }

        bgCheckTreatmentChartPointsValues = bgCheckTreatments.map { $0.value }
        bgCheckTreatmentChartPointsDates = bgCheckTreatments.map { $0.date }
    }

    private func updatePreviewData() {
        guard bgReadings.count > 0 else {
            previewAllFinalBgReadingValues = []
            previewAllFinalBgReadingDates = []
            previewVisibleFinalBgReadingValues = []
            previewVisibleFinalBgReadingDates = []
            return
        }

        guard effectiveEnableAdjustment() || enableSmoothing || effectiveUseFiveMinuteReadings() else {
            previewAllFinalBgReadingValues = []
            previewAllFinalBgReadingDates = []
            previewVisibleFinalBgReadingValues = []
            previewVisibleFinalBgReadingDates = []
            return
        }

        // Start from the calculated values, then layer in adjustment and smoothing
        // in the same order used by the stored post processing path.
        let sourceValues = bgReadings.map { $0.calculatedValue }
        var finalValues = sourceValues

        if effectiveEnableAdjustment(), let adjustmentPreview = currentAdjustmentPreview() {
            finalValues = sourceValues.map {
                adjustmentPreview.scaleCenterInMgDl + adjustmentPreview.slope * ($0 - adjustmentPreview.scaleCenterInMgDl) + adjustmentPreview.intercept
            }
        }

        if enableSmoothing {
            finalValues = smoothPreviewValues(previewValues: finalValues)
        }

        previewAllFinalBgReadingValues = finalValues
        previewAllFinalBgReadingDates = bgReadings.map { $0.timeStamp }

        let visibleReadingIndexes = bgPostProcessingManager.visibleReadingIndexesAfterApplyingFiveMinuteCadence(readingDates: bgReadings.map { $0.timeStamp }, enableFiveMinuteReadings: enableSmoothing && effectiveUseFiveMinuteReadings())
        previewVisibleFinalBgReadingValues = visibleReadingIndexes.map { finalValues[$0] }
        previewVisibleFinalBgReadingDates = visibleReadingIndexes.map { bgReadings[$0].timeStamp }
    }

    private func currentAdjustmentPreview() -> (slope: Double, intercept: Double, scaleCenterInMgDl: Double)? {
        guard let slopeAsDouble = slope.toDouble(), let interceptAsDouble = intercept.toDouble() else { return nil }

        return (slopeAsDouble, interceptAsDouble, adjustmentShapeType.scaleCenterInMgDl)
    }

    private func latestAdjustedPreviewValue() -> Double? {
        guard let latestCalculatedValue = bgReadings.last?.calculatedValue else { return nil }

        if let currentAdjustmentPreview = currentAdjustmentPreview() {
            return currentAdjustmentPreview.scaleCenterInMgDl + currentAdjustmentPreview.slope * (latestCalculatedValue - currentAdjustmentPreview.scaleCenterInMgDl) + currentAdjustmentPreview.intercept
        }

        return latestCalculatedValue
    }

    private func latestSmoothedPreviewValue() -> Double? {
        if let latestPreviewFinalValue = previewAllFinalBgReadingValues.last {
            return latestPreviewFinalValue
        }

        if let latestAdjustedPreviewValue = latestAdjustedPreviewValue() {
            return latestAdjustedPreviewValue
        }

        return bgReadings.last?.calculatedValue
    }

    private func selectedApplyFromTimeStamp() -> Date {
        let latestBgReadingTimeStamp = bgReadings.last?.timeStamp ?? Date()

        if let postProcessingStartTimeStamp = UserDefaults.standard.postProcessingStartTimeStamp {
            return max(latestBgReadingTimeStamp, postProcessingStartTimeStamp)
        }

        return latestBgReadingTimeStamp
    }

    /// historical apply is anchored to the latest available reading, not to now,
    /// so gaps in incoming data do not shrink the user-selected rewrite window
    private func selectedHistoricalApplyFromTimeStamp() -> Date {
        let latestBgReadingTimeStamp = bgReadings.last?.timeStamp ?? Date()
        let selectedApplyFromOption = availableApplyFromOptions()[selectedApplyFromPeriodIndex]

        return latestBgReadingTimeStamp.addingTimeInterval(-selectedApplyFromOption.timeInterval)
    }

    private func smoothPreviewValues(previewValues: [Double]) -> [Double] {
        return bgPostProcessingManager.smoothedValuesSeparatedByReadingGap(values: previewValues, readingDates: bgReadings.map { $0.timeStamp }, smoothingStrength: smoothingStrength, smoothingAlgorithm: smoothingAlgorithm)
    }

    private func applyNowChanges() {
        let adjustmentPreview = currentAdjustmentPreview()

        bgPostProcessingManager.applyPostProcessing(enableAdjustment: effectiveEnableAdjustment(), slope: adjustmentPreview?.slope, intercept: adjustmentPreview?.intercept, adjustmentShapeType: adjustmentShapeType, applyFromTimeStamp: selectedApplyFromTimeStamp(), isBasicAdjustment: false, enteredBgValue: currentAdjustedGlucoseValueInMgDl(), sourceCalculatedValue: bgReadings.last?.calculatedValue, enableSmoothing: enableSmoothing, useFiveMinuteReadings: effectiveUseFiveMinuteReadings(), smoothingPeriodInMinutes: ConstantsBgSmoothing.defaultSmoothingPeriodInMinutes, smoothingStrength: smoothingStrength, smoothingAlgorithm: smoothingAlgorithm)
        presentationMode.wrappedValue.dismiss()
    }

    private func applyHistoricalChanges() {
        let adjustmentPreview = currentAdjustmentPreview()
        let historicalApplyFromTimeStamp = selectedHistoricalApplyFromTimeStamp()

        bgPostProcessingManager.applyPostProcessing(enableAdjustment: effectiveEnableAdjustment(), slope: adjustmentPreview?.slope, intercept: adjustmentPreview?.intercept, adjustmentShapeType: adjustmentShapeType, applyFromTimeStamp: historicalApplyFromTimeStamp, isBasicAdjustment: false, enteredBgValue: currentAdjustedGlucoseValueInMgDl(), sourceCalculatedValue: bgReadings.last?.calculatedValue, enableSmoothing: enableSmoothing, useFiveMinuteReadings: effectiveUseFiveMinuteReadings(), smoothingPeriodInMinutes: ConstantsBgSmoothing.defaultSmoothingPeriodInMinutes, smoothingStrength: smoothingStrength, smoothingAlgorithm: smoothingAlgorithm, processingStartDateOverride: historicalApplyFromTimeStamp)
        presentationMode.wrappedValue.dismiss()
    }

    private func applySelectedChanges() {
        if selectedApplyFromPeriodIndex == 0 {
            applyNowChanges()
        } else {
            applyHistoricalChanges()
        }
    }

    private func updateSlope(by valueToAdd: Double) {
        let currentSlope = slope.toDouble() ?? 1.0
        slope = (currentSlope + valueToAdd).round(toDecimalPlaces: 2).description
    }

    private func updateIntercept(by valueToAdd: Double) {
        let currentIntercept = intercept.toDouble() ?? 0.0
        intercept = (currentIntercept + valueToAdd).round(toDecimalPlaces: 1).stringWithoutTrailingZeroes
        draftAdjustedGlucoseValue = adjustedGlucoseInputValueString()
        offsetAdjustmentInputType = .offsetValue
    }

    private func canApplyChanges() -> Bool {
        if effectiveEnableAdjustment() {
            return currentAdjustmentPreview() != nil
        }

        let smoothingEnabledChanged = enableSmoothing != UserDefaults.standard.enableSmoothing
        let fiveMinuteReadingsChanged = effectiveUseFiveMinuteReadings() != UserDefaults.standard.useFiveMinuteReadings
        let smoothingStrengthChanged = smoothingStrength != UserDefaults.standard.bgSmoothingStrength
        let smoothingAlgorithmChanged = smoothingAlgorithm != UserDefaults.standard.bgSmoothingAlgorithm

        return smoothingEnabledChanged || fiveMinuteReadingsChanged || smoothingStrengthChanged || smoothingAlgorithmChanged || currentBgAdjustment != nil
    }

    private func canApplySelectedChanges() -> Bool {
        guard bgReadings.count > 0 else { return false }

        if selectedApplyFromPeriodIndex > 0 {
            return !effectiveEnableAdjustment() || currentAdjustmentPreview() != nil
        }

        return canApplyChanges()
    }

    private func applyFromSectionTitle() -> String {
        guard selectedApplyFromPeriodIndex > 0 else { return Texts_HomeView.postProcessingApplyFrom }

        return Texts_HomeView.postProcessingApplyFrom + " " + selectedHistoricalApplyFromTimeStamp().toString(timeStyle: .short, dateStyle: .none)
    }

    private func applyButtonTintColor() -> Color {
        return selectedApplyFromPeriodIndex > 0 ? Color(.systemRed) : Color(.systemBlue)
    }

    private func shouldAllowAdjustmentForCurrentSource() -> Bool {
        return bgPostProcessingManager.shouldAllowBgAdjustmentForCurrentSource()
    }

    private func adjustmentDisabledMessage() -> String? {
        return bgPostProcessingManager.bgAdjustmentDisabledMessageForCurrentSource()
    }

    private func effectiveEnableAdjustment() -> Bool {
        return shouldAllowAdjustmentForCurrentSource() && enableAdjustment
    }

    private func effectiveUseFiveMinuteReadings() -> Bool {
        return sourceCanUseFiveMinuteReadings() && useFiveMinuteReadings
    }

    private func sourceCanUseFiveMinuteReadings() -> Bool {
        return bgPostProcessingManager.sourceCanUseFiveMinuteReadings(readingDates: bgReadings.map { $0.timeStamp })
    }

    private func sourceDataNotUpdatedWarningText() -> String? {
        if UserDefaults.standard.isMaster {
            let masterNightscoutBgWritesAvailable = UserDefaults.standard.nightscoutEnabled
                && UserDefaults.standard.nightscoutUrl != nil
                && UserDefaults.standard.masterUploadDataToNightscout

            return masterNightscoutBgWritesAvailable ? nil : Texts_HomeView.postProcessingMasterNightscoutUploadDisabled
        }

        switch UserDefaults.standard.followerDataSourceType {
        case .nightscout:
            return Texts_HomeView.postProcessingNightscoutDataNotUpdated
        case .dexcomShare:
            return Texts_HomeView.postProcessingDexcomShareDataNotUpdated
        default:
            return nil
        }
    }

    private func availableApplyFromOptions() -> [ApplyFromOption] {
        var applyFromOptions = [ApplyFromOption(title: Texts_HomeView.postProcessingNow, timeInterval: 0)]

        for applyFromPeriodInHours in applyFromPeriodsInHours {
            let applyFromTimeInterval = Double(applyFromPeriodInHours) * 3600.0
            applyFromOptions.append(ApplyFromOption(title: "-\(applyFromPeriodInHours)h", timeInterval: applyFromTimeInterval))
        }

        return applyFromOptions
    }

    private func availableHistoricalApplyTimeInterval() -> TimeInterval {
        guard let latestPreviewReadingTimeStamp = bgReadings.last?.timeStamp else { return 0 }

        // Historical apply availability should follow the source history, not the
        // current preview zoom level. Otherwise selecting a shorter preview window
        // can incorrectly disable longer apply windows that are still valid.
        let sourceWindowStartTimeStamp = UserDefaults.standard.postProcessingStartTimeStamp ?? .distantPast

        return max(0, latestPreviewReadingTimeStamp.timeIntervalSince(sourceWindowStartTimeStamp))
    }

    private func normalizeSelectedApplyFromOptionIndex() {
        let maximumIndex = availableApplyFromOptions().count - 1
        selectedApplyFromPeriodIndex = min(selectedApplyFromPeriodIndex, maximumIndex)

        if !applyFromOptionCanBeSelected(availableApplyFromOptions()[selectedApplyFromPeriodIndex]) {
            selectedApplyFromPeriodIndex = 0
        }
    }

    private func displayBgString(for value: Double?) -> String {
        guard let value = value else { return Texts_Common.unknown }

        let unitString = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
        let valueString = displayBgValueString(for: value)

        return valueString + " " + unitString
    }

    private func displayBgValueString(for value: Double?) -> String {
        guard let value = value else { return Texts_Common.unknown }

        return value.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    }

    private func displaySlopeString(for value: Double?) -> String {
        guard let value = value else { return Texts_Common.unknown }

        return String(format: "%.2f", value)
    }

    private func scaleValueTextColor() -> Color {
        guard let currentSlope = slope.toDouble() else { return Color(.colorTertiary) }

        return abs(currentSlope - 1.0) < 0.0001 ? Color(.colorTertiary) : Color(.colorPrimary)
    }

    private func offsetValueTextColor() -> Color {
        guard offsetAdjustmentInputType == .offsetValue else { return Color(.colorTertiary) }

        if offsetValueChanged() || shouldHighlightCurrentOffsetValueOnOpen() {
            return Color(.colorPrimary)
        }

        return Color(.colorTertiary)
    }

    private func shouldHighlightCurrentOffsetValueOnOpen() -> Bool {
        guard enableAdjustment else { return false }
        guard let interceptValue = intercept.toDouble(), abs(interceptValue) > 0.0001 else { return false }

        return !offsetValueChanged() && currentBgAdjustment != nil
    }

    private func inputGlucoseString(for valueInMgDl: Double?) -> String {
        guard let valueInMgDl = valueInMgDl else { return "" }

        return valueInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    }

    private func enteredGlucoseValueInMgDl(_ glucoseValueString: String) -> Double? {
        guard let glucoseValue = glucoseValueString.toDouble() else { return nil }

        return glucoseValue.mmolToMgdl(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    }

    private func adjustedGlucoseInputValueString() -> String {
        return inputGlucoseString(for: currentAdjustedGlucoseValueInMgDl())
    }

    private func interceptNudgeValueInMgDl() -> Double {
        let interceptNudgeValueInUserUnit = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? ConstantsBgAdjustment.interceptNudgeValueInMgDl : ConstantsBgAdjustment.interceptNudgeValueInMmol

        return interceptNudgeValueInUserUnit.mmolToMgdl(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    }

    private func offsetValueChanged() -> Bool {
        guard let currentIntercept = intercept.toDouble() else { return false }

        return abs(currentIntercept - openedInterceptValue) > 0.0001
    }

    private func scaleValueChanged() -> Bool {
        guard let currentSlope = slope.toDouble() else { return false }

        return abs(currentSlope - openedSlopeValue) > 0.0001
    }

    private func shapeControlDisabled() -> Bool {
        guard let currentSlope = slope.toDouble() else { return true }

        return abs(currentSlope - 1.0) < 0.0001
    }

    @ViewBuilder private func compactAdjustmentShapeControl() -> some View {
        let bgAdjustmentShapeTypes: [BgAdjustmentShapeType] = [.softerHighs, .neutral, .softerLows]

        HStack(spacing: 4) {
            ForEach(bgAdjustmentShapeTypes, id: \.rawValue) { bgAdjustmentShapeType in
                Button {
                    if !shapeControlDisabled() {
                        adjustmentShapeTypeRawValue = bgAdjustmentShapeType.rawValue
                    }
                } label: {
                    Text(bgAdjustmentShapeType.description)
                        .font(.footnote)
                        .lineLimit(1)
                        .foregroundStyle(compactAdjustmentShapeControlTextColor(for: bgAdjustmentShapeType))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(compactAdjustmentShapeControlBackgroundColor(for: bgAdjustmentShapeType))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(shapeControlDisabled())
            }
        }
    }

    @ViewBuilder private func compactApplyFromControl(applyFromOptions: [ApplyFromOption]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(applyFromOptions.enumerated()), id: \.offset) { applyFromOptionIndex, applyFromOption in
                Button {
                    if applyFromOptionCanBeSelected(applyFromOption) {
                        selectedApplyFromPeriodIndex = applyFromOptionIndex
                    }
                } label: {
                    Text(applyFromOption.title)
                        .font(.footnote)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(compactApplyFromControlTextColor(applyFromOptionIndex: applyFromOptionIndex, applyFromOption: applyFromOption))
                        .padding(.vertical, 7)
                        .background(compactApplyFromControlBackgroundColor(applyFromOptionIndex: applyFromOptionIndex, applyFromOption: applyFromOption))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!applyFromOptionCanBeSelected(applyFromOption))
            }
        }
    }

    private func applyFromOptionCanBeSelected(_ applyFromOption: ApplyFromOption) -> Bool {
        if applyFromOption.timeInterval == 0 {
            return true
        }

        let availableHistoricalApplyTimeInterval = availableHistoricalApplyTimeInterval()
        let threeHoursInSeconds = Double(applyFromPeriodsInHours[0]) * 3600.0
        let sixHoursInSeconds = Double(applyFromPeriodsInHours[1]) * 3600.0

        // Historical apply should unlock in the next standard bucket.
        // Any available context can be expanded to the first 3 hour window.
        // Once 3 hours are available, unlock 6 hours.
        // Once 6 hours are available, unlock 12 hours.
        switch Int(applyFromOption.timeInterval / 3600.0) {
        case applyFromPeriodsInHours[0]:
            return availableHistoricalApplyTimeInterval > 0
        case applyFromPeriodsInHours[1]:
            return availableHistoricalApplyTimeInterval >= threeHoursInSeconds
        case applyFromPeriodsInHours[2]:
            return availableHistoricalApplyTimeInterval >= sixHoursInSeconds
        default:
            return false
        }
    }

    private func compactApplyFromControlBackgroundColor(applyFromOptionIndex: Int, applyFromOption: ApplyFromOption) -> Color {
        if selectedApplyFromPeriodIndex == applyFromOptionIndex {
            return applyFromOptionCanBeSelected(applyFromOption) ? Color(.colorPrimary) : Color(.systemGray3)
        }

        return applyFromOptionCanBeSelected(applyFromOption) ? Color(.systemGray5) : Color(.systemGray6)
    }

    private func compactApplyFromControlTextColor(applyFromOptionIndex: Int, applyFromOption: ApplyFromOption) -> Color {
        if selectedApplyFromPeriodIndex == applyFromOptionIndex {
            return applyFromOptionCanBeSelected(applyFromOption) ? Color(.systemBackground) : Color(.colorPrimary)
        }

        return applyFromOptionCanBeSelected(applyFromOption) ? Color(.colorPrimary) : Color(.colorSecondary)
    }

    private func compactAdjustmentShapeControlBackgroundColor(for bgAdjustmentShapeType: BgAdjustmentShapeType) -> Color {
        if adjustmentShapeTypeRawValue == bgAdjustmentShapeType.rawValue {
            return shapeControlDisabled() ? Color(.systemGray3) : Color(.colorPrimary)
        }

        return shapeControlDisabled() ? Color(.systemGray6) : Color(.systemGray5)
    }

    private func compactAdjustmentShapeControlTextColor(for bgAdjustmentShapeType: BgAdjustmentShapeType) -> Color {
        if adjustmentShapeTypeRawValue == bgAdjustmentShapeType.rawValue {
            return shapeControlDisabled() ? Color(.colorPrimary) : Color(.systemBackground)
        }

        return shapeControlDisabled() ? Color(.colorSecondary) : Color(.colorPrimary)
    }

    private func shouldShowSelectedAdjustmentShapeDescription() -> Bool {
        return !shapeControlDisabled() && adjustmentShapeType != .neutral
    }

    private func previewBgCheckHintText() -> String? {
        if scaleValueChanged() && bgCheckTreatmentChartPointsValues.count < 2 {
            return Texts_HomeView.postProcessingScaleBgCheckHint
        }

        if bgCheckTreatmentChartPointsValues.count < 1 {
            return Texts_HomeView.postProcessingOffsetBgCheckHint
        }

        return nil
    }

    private func selectedAdjustmentShapeDescription() -> String {
        switch adjustmentShapeType {
        case .softerLows:
            return Texts_HomeView.postProcessingSofterHighsDescription
        case .neutral:
            return Texts_HomeView.postProcessingNeutralDescription
        case .softerHighs:
            return Texts_HomeView.postProcessingSofterLowsDescription
        }
    }

    private func inputGlucoseAdjustmentValueString(for adjustedGlucoseValueString: String) -> String {
        guard let adjustedGlucoseValueInMgDl = enteredGlucoseValueInMgDl(adjustedGlucoseValueString), let latestBgReading = bgReadings.last else {
            return displayAdjustmentValueString(for: intercept.toDouble() ?? 0.0)
        }

        return displayAdjustmentValueString(for: adjustedGlucoseValueInMgDl - latestBgReading.calculatedValue)
    }

    private func previewBgReadingValues() -> [Double] {
        if !previewVisibleFinalBgReadingValues.isEmpty {
            return previewVisibleFinalBgReadingValues
        }

        if !previewAllFinalBgReadingValues.isEmpty {
            return []
        }

        return calculatedBgReadingValues
    }

    private func previewBgReadingDates() -> [Date] {
        if !previewVisibleFinalBgReadingDates.isEmpty {
            return previewVisibleFinalBgReadingDates
        }

        if !previewAllFinalBgReadingDates.isEmpty {
            return []
        }

        return calculatedBgReadingDates
    }

    private func displayAdjustmentValueString(for adjustmentValueInMgDl: Double, includeUnit: Bool = true) -> String {
        let adjustmentValueInUserUnit = adjustmentValueInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        let unitString = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
        let prefix = adjustmentValueInUserUnit > 0 ? "+" : adjustmentValueInUserUnit < 0 ? "-" : ""
        let absoluteValueString = abs(adjustmentValueInUserUnit).bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

        if includeUnit {
            return prefix + absoluteValueString + " " + unitString
        }

        return prefix + absoluteValueString
    }

    private func glucoseTextColor(for valueInMgDl: Double) -> Color {
        if valueInMgDl >= UserDefaults.standard.urgentHighMarkValue || valueInMgDl <= UserDefaults.standard.urgentLowMarkValue {
            return ConstantsGlucoseChart.glucoseUrgentRangeColor
        }

        if valueInMgDl >= UserDefaults.standard.highMarkValue || valueInMgDl <= UserDefaults.standard.lowMarkValue {
            return ConstantsGlucoseChart.glucoseNotUrgentRangeColor
        }

        return ConstantsGlucoseChart.glucoseInRangeColor
    }

    private func currentAdjustedGlucoseValueInMgDl() -> Double? {
        guard let latestBgReading = bgReadings.last else { return nil }

        return latestBgReading.calculatedValue + (intercept.toDouble() ?? 0.0)
    }

    private func canDecreaseOffsetValue() -> Bool {
        guard let currentAdjustedGlucoseValueInMgDl = currentAdjustedGlucoseValueInMgDl() else { return false }

        return currentAdjustedGlucoseValueInMgDl - interceptNudgeValueInMgDl() >= minimumGlucoseValueInMgDl
    }

    private func canIncreaseOffsetValue() -> Bool {
        guard let currentAdjustedGlucoseValueInMgDl = currentAdjustedGlucoseValueInMgDl() else { return false }

        return currentAdjustedGlucoseValueInMgDl + interceptNudgeValueInMgDl() <= maximumGlucoseValueInMgDl
    }

    private func canDecreaseScaleValue() -> Bool {
        guard let currentSlope = slope.toDouble() else { return false }

        return currentSlope - ConstantsBgAdjustment.slopeNudgeValue >= ConstantsBgAdjustment.minimumSlopeValue
    }

    private func canIncreaseScaleValue() -> Bool {
        guard let currentSlope = slope.toDouble() else { return false }

        return currentSlope + ConstantsBgAdjustment.slopeNudgeValue <= ConstantsBgAdjustment.maximumSlopeValue
    }

}

/// Compact direct-entry sheet for a basic glucose adjustment.
private struct BasicAdjustmentInputView: View {
    @State private var shouldFocusEnteredGlucoseValue = false

    private let minimumGlucoseValueInMgDl = ConstantsCalibrationAlgorithms.minimumBgReadingCalculatedValue
    private let maximumGlucoseValueInMgDl = ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue

    let currentGlucoseValueString: String
    let glucoseAdjustmentValueString: String
    let unitString: String
    @Binding var enteredGlucoseValue: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            List {
                Section(footer: validationMessageView()) {
                    HStack {
                        Text(Texts_HomeView.postProcessingCurrentValue)
                        Spacer()
                        Text(currentGlucoseValueString)
                            .foregroundStyle(Color(.colorSecondary))
                    }

                    HStack {
                        Text(Texts_HomeView.postProcessingAdjustedGlucose)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer()
                        AutoSelectingNumericTextField(placeholder: Texts_HomeView.postProcessingEnterValue, text: $enteredGlucoseValue, shouldBecomeFirstResponder: shouldFocusEnteredGlucoseValue)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 72, maxWidth: 96, alignment: .trailing)
                        Text(unitString)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }

                Section {
                    HStack {
                        Text(Texts_HomeView.postProcessingOffset)
                        Spacer()
                        Text(glucoseAdjustmentValueString)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Texts_HomeView.postProcessingEnterGlucose)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: onCancel)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_Common.Ok, action: onConfirm)
                        .disabled(!enteredGlucoseValueIsValid())
                }
            }
        }
        .colorScheme(.dark)
        .onAppear {
            shouldFocusEnteredGlucoseValue = true
        }
    }

    @ViewBuilder private func validationMessageView() -> some View {
        if !enteredGlucoseValue.isEmpty, !enteredGlucoseValueIsValid() {
            Text(String(format: Texts_HomeView.postProcessingValidGlucoseRange, minimumGlucoseValueString(), maximumGlucoseValueString()))
                .foregroundStyle(Color(.systemRed))
        }
    }

    private func enteredGlucoseValueIsValid() -> Bool {
        guard let enteredGlucoseValueInMgDl = enteredGlucoseValueInMgDl() else { return false }

        return enteredGlucoseValueInMgDl >= minimumGlucoseValueInMgDl && enteredGlucoseValueInMgDl <= maximumGlucoseValueInMgDl
    }

    private func enteredGlucoseValueInMgDl() -> Double? {
        guard let enteredGlucoseValue = enteredGlucoseValue.toDouble() else { return nil }

        return enteredGlucoseValue.mmolToMgdl(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    }

    private func minimumGlucoseValueString() -> String {
        return minimumGlucoseValueInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + " " + unitString
    }

    private func maximumGlucoseValueString() -> String {
        return maximumGlucoseValueInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + " " + unitString
    }
}

/// Numeric field adapter used only to select the complete initial value when editing begins.
private struct AutoSelectingNumericTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let shouldBecomeFirstResponder: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.text = text
        textField.keyboardType = .decimalPad
        textField.textAlignment = .right
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)

        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }

        if shouldBecomeFirstResponder && !context.coordinator.didBecomeFirstResponder {
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
                context.coordinator.didBecomeFirstResponder = true
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var didBecomeFirstResponder = false

        init(text: Binding<String>) {
            self._text = text
        }

        @objc func textDidChange(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }
    }
}
