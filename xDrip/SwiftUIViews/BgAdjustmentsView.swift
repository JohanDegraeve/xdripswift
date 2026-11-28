//
//  BgAdjustmentsView.swift
//  xdrip
//
//  Created by Paul Plant on 2/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import Combine

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

    private enum AdjustmentSection {
        case offsetAndCurve, previous, latest
    }

    private enum AdjustmentMode: CaseIterable {
        case off, offset, curve, both

        init(offset: Bool, curve: Bool) {
            switch (offset, curve) {
            case (false, false): self = .off
            case (true, false): self = .offset
            case (false, true): self = .curve
            case (true, true): self = .both
            }
        }

        var includesOffset: Bool { self == .offset || self == .both }
        var includesCurve: Bool { self == .curve || self == .both }

        var title: String {
            switch self {
            case .off: return Texts_HomeView.postProcessingLatestReadingOff
            case .offset: return Texts_HomeView.postProcessingOffset
            case .curve: return Texts_HomeView.postProcessingCurve
            case .both: return Texts_HomeView.postProcessingBoth
            }
        }
    }

    private enum AdjustmentAlert: Identifiable {
        case adjustment(AdjustmentMode)
        case latestReadingSmoothing(LatestReadingSmoothing.Mode)
        case invalidAdjustment

        var id: Int {
            switch self {
            case .adjustment: return 0
            case .latestReadingSmoothing: return 1
            case .invalidAdjustment: return 2
            }
        }
    }

    private struct ApplyFromOption {
        let title: String
        let timeInterval: TimeInterval
        /// A controlled semantic value for the consumer Activity Log. Passing the selection avoids
        /// reverse-engineering "3 hours" from a timestamp that may be anchored to a delayed reading.
        let troubleshootingRange: TroubleshootingPostProcessingApplyRange
    }

    /// available manual historical apply windows in hours
    private let applyFromPeriodsInHours = [3, 6, 12]

    private let bgReadingsAccessor: BgReadingsAccessor
    private let treatmentEntryAccessor: TreatmentEntryAccessor
    private let bgPostProcessingManager: BgPostProcessingManager

    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    @State private var bgReadings: [BgReading] = []
    @State private var previewSourceStartDate = Date.distantPast

    @State private var calculatedBgReadingValues: [Double] = []
    @State private var calculatedBgReadingDates: [Date] = []
    @State private var bgCheckTreatmentChartPointsValues: [Double] = []
    @State private var bgCheckTreatmentChartPointsDates: [Date] = []
    @State private var previewAllFinalBgReadingValues: [Double] = []
    @State private var previewAllFinalBgReadingDates: [Date] = []
    @State private var previewVisibleFinalBgReadingValues: [Double] = []
    @State private var previewVisibleFinalBgReadingDates: [Date] = []

    @State private var openedSourceContext: String?
    @State private var openedShape = ConstantsBgAdjustment.defaultShapeType.rawValue

    @State private var enableAdjustment = UserDefaults.standard.enableAdjustment && UserDefaults.standard.enableGlucoseAdjustment
    @State private var enableCurveAdjustment = UserDefaults.standard.enableAdjustment && UserDefaults.standard.enableCurveAdjustment
    @State private var adjustmentAlert: AdjustmentAlert?
    @State private var acknowledgedWarnings = [TroubleshootingPostProcessingWarning]()
    @State private var enableSmoothing = UserDefaults.standard.enableSmoothing
    @State private var latestReadingSmoothingMode = UserDefaults.standard.latestReadingSmoothingMode
    @State private var expandedSection: AdjustmentSection?
    @State private var useFiveMinuteReadings = UserDefaults.standard.useFiveMinuteReadings
    @State private var openingReferenceGlucoseValue: Double?
    @State private var draftAdjustedGlucoseValue = ""
    @State private var slope = "1.00"
    @State private var intercept = "0.0"
    @State private var adjustmentShapeTypeRawValue = ConstantsBgAdjustment.defaultShapeType.rawValue
    @State private var openedSlopeValue = 1.00
    @State private var openedInterceptValue = 0.0
    @State private var smoothingAlgorithm = UserDefaults.standard.bgSmoothingAlgorithm
    @State private var smoothingStrength = UserDefaults.standard.bgSmoothingStrength
    @State private var showingSmoothingAlgorithmInfo = false
    @State private var showingApplyFromConfirmation = false
    @State private var showingUnsavedChangesConfirmation = false
    @State private var showingDiscardConfirmation = false
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
                screenBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(Texts_HomeView.postProcessingTitle)
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .accessibilityAddTraits(.isHeader)
                    }

                    chartView()
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                    adjustmentList
                }
            }
            .ipadReadableContentWidth(980)
            .navigationTitle(dynamicTypeSize.isAccessibilitySize ? "" : Texts_HomeView.postProcessingTitle)
            .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .automatic)
            .toolbarBackground(screenBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: cancelEditing)
                    .foregroundStyle(Color.primary)
                    .confirmationDialog(Texts_Common.unsavedChanges, isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
                        Button(Texts_Common.discardChanges, role: .destructive) { presentationMode.wrappedValue.dismiss() }
                        Button(Texts_Common.Cancel, role: .cancel) {}
                    }
                    .alert(isPresented: $showingUnsavedChangesConfirmation) {
                        Alert(
                            title: Text(Texts_Common.unsavedChanges),
                            primaryButton: .default(Text(Texts_Common.save), action: {
                                beginApply()
                            }),
                            secondaryButton: .destructive(Text(Texts_Common.discardChanges), action: {
                                presentationMode.wrappedValue.dismiss()
                            })
                        )
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    OnlineHelpButton(topic: .glucoseAdjustments)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_HomeView.postProcessingApply) {
                        beginApply()
                    }
                    .tint(ConstantsAppColors.toolbarAction)
                    .disabled(!canApplyChanges())
                }
            }
            .sheet(isPresented: $showingBasicAdjustmentInputSheet) {
                BasicAdjustmentInputView(openingReferenceGlucoseValue: openingReferenceGlucoseValue, currentGlucoseValueInMgDl: latestSourceReading?.calculatedValue, currentGlucoseValueString: displayBgString(for: latestSourceReading?.calculatedValue), glucoseAdjustmentValueString: inputGlucoseAdjustmentValueString(for: draftAdjustedGlucoseValue), unitString: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol, enteredGlucoseValue: $draftAdjustedGlucoseValue, onCancel: {
                    draftAdjustedGlucoseValue = adjustedGlucoseInputValueString()
                    showingBasicAdjustmentInputSheet = false
                }, onConfirm: {
                    confirmDraftAdjustedGlucoseValue()
                    showingBasicAdjustmentInputSheet = false
                })
            }
            .alert(item: $adjustmentAlert) { alert in
                if case .invalidAdjustment = alert {
                    return Alert(title: Text(Texts_Common.warning), message: Text(Texts_HomeView.postProcessingInvalidAdjustment), dismissButton: .default(Text(Texts_Common.Ok)))
                }
                return enableConfirmationAlert(for: alert)
            }
            .confirmationDialog(Texts_HomeView.postProcessingApplyFrom, isPresented: $showingApplyFromConfirmation, titleVisibility: .visible) {
                ForEach(availableApplyFromOptions(), id: \.title) { option in
                    if applyFromOptionCanBeSelected(option) {
                        Button(option.title) { applyChanges(from: option) }
                    }
                }
                Button(Texts_Common.Cancel, role: .cancel) {}
            } message: {
                if let sourceDataNotUpdatedWarningText = sourceDataNotUpdatedWarningText() {
                    Text(sourceDataNotUpdatedWarningText)
                }
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
            .onChange(of: enableCurveAdjustment) { _ in
                updatePreviewData()
            }
            .onChange(of: latestReadingSmoothingMode) { _ in
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
                if openedSourceContext == bgPostProcessingManager.postProcessingEditingSource {
                    loadBgReadings()
                    updatePreviewData()
                }
            }
        }
    }

    private var adjustmentList: some View {
        List {
            Section {
                VStack(alignment: .leading) { offsetAndCurveSection() }
                    .listRowSeparator(.visible, edges: .bottom)
                VStack(alignment: .leading) { smoothingSection() }
                    .listRowSeparator(.visible, edges: .bottom)
                VStack(alignment: .leading) { latestReadingSmoothingSection() }
            }
            readingFrequencySection()
        }
        .modifier(AdjustmentListTopMargin())
    }

    private var screenBackground: Color {
        colorScheme == .dark ? ConstantsAppColors.groupedBackground : Color(uiColor: .systemGroupedBackground)
    }

    private var warningColor: Color {
        colorScheme == .dark ? Color(.systemYellow) : Color(.systemBrown)
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
                .dynamicTypeSize(...DynamicTypeSize.large)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Texts_HomeView.postProcessingPreviewHours)
                        .foregroundStyle(Color.secondary)
                        .font(.subheadline)
                    previewHoursPicker
                        .pickerStyle(.menu)
                }
            } else {
                HStack {
                    Text(Texts_HomeView.postProcessingPreviewHours)
                        .foregroundStyle(Color.secondary)
                        .font(.subheadline)
                    Spacer()
                    previewHoursPicker
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 240)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(chartBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var previewHoursPicker: some View {
        Picker(Texts_HomeView.postProcessingPreviewHours, selection: $chartHoursToShow) {
            ForEach(ConstantsBgAdjustment.previewChartHoursToShowOptions, id: \.self) { hours in
                Text("\(hours)h").tag(Double(hours))
            }
        }
    }

    private var historicalMode: LatestReadingSmoothing.Mode {
        guard enableSmoothing else { return .off }
        switch smoothingStrength {
        case 0: return .light
        case 2: return .strong
        default: return .medium
        }
    }

    private var adjustmentMode: AdjustmentMode {
        AdjustmentMode(offset: effectiveEnableAdjustment(), curve: effectiveEnableCurveAdjustment())
    }

    private var adjustmentSummary: String {
        guard shouldAllowAdjustmentForCurrentSource() else { return Texts_HomeView.postProcessingUnavailable }
        switch adjustmentMode {
        case .off: return AdjustmentMode.off.title
        case .offset: return offsetSummary
        case .curve: return curveSummary
        case .both: return [offsetSummary, curveSummary].joined(separator: " · ")
        }
    }

    private var offsetSummary: String {
        "\(AdjustmentMode.offset.title) \(displayAdjustmentValueString(for: intercept.toDouble() ?? 0))"
    }

    private var curveSummary: String {
        "\(AdjustmentMode.curve.title) \(displaySlopeString(for: slope.toDouble()))"
    }

    private func disclosureRow(_ section: AdjustmentSection, title: String, summary: String, enabled: Bool, available: Bool = true) -> some View {
        let expanded = expandedSection == section
        return Button {
            expandedSection = expanded ? nil : section
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(available ? (enabled ? Color(.systemGreen) : Color.secondary) : Color(uiColor: .tertiaryLabel))
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                }
                if !expanded {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue([summary, expanded ? Texts_HomeView.postProcessingExpanded : Texts_HomeView.postProcessingCollapsed].joined(separator: ", "))
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private func modeSelector<Mode: Hashable>(_ title: String, options: [Mode], off: Mode, selection: Mode, label: @escaping (Mode) -> String, onSelect: @escaping (Mode) -> Void) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            modeMenu(title, options: options, off: off, selection: selection, label: label, onSelect: onSelect)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 2) {
                    ForEach(options, id: \.self) { option in
                        let selected = option == selection
                        Button {
                            onSelect(option)
                        } label: {
                            Text(label(option))
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(Color.primary)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .tint(option == off ? offModeFill(selected: selected) : (selected ? Color(uiColor: .systemFill) : .clear))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(2)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .contain)
                .accessibilityLabel(title)

                modeMenu(title, options: options, off: off, selection: selection, label: label, onSelect: onSelect)
            }
        }
    }

    private func modeMenu<Mode: Hashable>(_ title: String, options: [Mode], off: Mode, selection: Mode, label: @escaping (Mode) -> String, onSelect: @escaping (Mode) -> Void) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    if option == selection {
                        Label(label(option), systemImage: "checkmark")
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            HStack {
                Text(Texts_HomeView.postProcessingMode)
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 8)
                Label(label(selection), systemImage: "chevron.up.chevron.down")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(selection == off ? Color.primary : Color.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(selection == off ? offModeFill(selected: true) : .clear, in: RoundedRectangle(cornerRadius: 7))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
    }

    private func offModeFill(selected: Bool) -> Color {
        Color(uiColor: .systemRed).opacity(selected ? 0.65 : 0.09)
    }

    private func selectAdjustmentMode(_ mode: AdjustmentMode) {
        guard mode != adjustmentMode else { return }
        if mode != .off && !acknowledgedWarnings.contains(.glucoseAdjustment) {
            adjustmentAlert = .adjustment(mode)
        } else {
            enableAdjustment = mode.includesOffset
            enableCurveAdjustment = mode.includesCurve
        }
    }

    private func strengthTitle(_ mode: LatestReadingSmoothing.Mode) -> String {
        switch mode {
        case .off: return Texts_HomeView.postProcessingLatestReadingOff
        case .light: return Texts_HomeView.postProcessingLight
        case .medium: return Texts_HomeView.postProcessingMedium
        case .strong: return Texts_HomeView.postProcessingStrong
        }
    }

    private func selectHistoricalMode(_ mode: LatestReadingSmoothing.Mode) {
        enableSmoothing = mode.isEnabled
        switch mode {
        case .off: break
        case .light: smoothingStrength = 0
        case .medium: smoothingStrength = 1
        case .strong: smoothingStrength = 2
        }
    }

    private func selectLiveMode(_ mode: LatestReadingSmoothing.Mode) {
        if mode.isEnabled && !latestReadingSmoothingMode.isEnabled && !acknowledgedWarnings.contains(.latestReadingSmoothing) {
            adjustmentAlert = .latestReadingSmoothing(mode)
        } else {
            latestReadingSmoothingMode = mode
        }
    }

    private func enableConfirmationAlert(for alert: AdjustmentAlert) -> Alert {
        let title: String
        let warnings: [(TroubleshootingPostProcessingWarning, String)]
        let confirm: () -> Void
        switch alert {
        case .adjustment(let mode):
            title = Texts_HomeView.postProcessingOffsetAndCurve
            warnings = [
                (.glucoseAdjustment, Texts_HomeView.postProcessingGlucoseAdjustmentWarning),
                (.curveAdjustment, Texts_HomeView.postProcessingCurveAdjustmentWarning)
            ]
            confirm = {
                enableAdjustment = mode.includesOffset
                enableCurveAdjustment = mode.includesCurve
            }
        case .latestReadingSmoothing(let mode):
            title = Texts_HomeView.postProcessingLatestReading
            warnings = [(.latestReadingSmoothing, Texts_HomeView.postProcessingLatestReadingWarning)]
            confirm = { latestReadingSmoothingMode = mode }
        case .invalidAdjustment:
            return Alert(title: Text(Texts_Common.warning), message: Text(Texts_HomeView.postProcessingInvalidAdjustment))
        }

        let message = (warnings.map { $0.1 } + [Texts_HomeView.postProcessingWarningAgreement]).joined(separator: "\n\n")
        return Alert(
            title: Text(title),
            message: Text(message),
            primaryButton: .cancel(Text(Texts_Common.Cancel)),
            secondaryButton: .default(Text(Texts_Common.Ok)) {
                for (feature, _) in warnings where !acknowledgedWarnings.contains(feature) {
                    acknowledgedWarnings.append(feature)
                }
                confirm()
            }
        )
    }

    private func offsetIsValid() -> Bool {
        guard let offset = intercept.toDouble() else { return false }
        return ConstantsBgAdjustment.isValidOffset(offset)
    }

    private func offsetWarningMessage(_ offset: Double?) -> String? {
        guard let offset else { return nil }
        if !ConstantsBgAdjustment.isValidOffset(offset) {
            return String(format: Texts_HomeView.postProcessingOffsetLimit, ConstantsBgAdjustment.maximumOffsetInMgDl.mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + " " + (UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol))
        }
        return ConstantsBgAdjustment.offsetNeedsWarning(offset) ? Texts_HomeView.postProcessingLargeOffsetWarning : nil
    }

    @ViewBuilder private func offsetAndCurveSection() -> some View {
        let title = Texts_HomeView.postProcessingOffsetAndCurve
        disclosureRow(.offsetAndCurve, title: title, summary: adjustmentSummary, enabled: adjustmentMode != .off, available: shouldAllowAdjustmentForCurrentSource())
        if expandedSection == .offsetAndCurve {
            if shouldAllowAdjustmentForCurrentSource() {
                modeSelector(title, options: AdjustmentMode.allCases, off: .off, selection: adjustmentMode, label: { $0.title }, onSelect: selectAdjustmentMode)
                    .padding(.top, 4)
                if effectiveEnableAdjustment() {
                    offsetAdjustmentValueRow()
                }
                if effectiveEnableCurveAdjustment() {
                    scaleAdjustmentControl()
                }
                if effectiveEnableAdjustment(), let warning = offsetWarningMessage(intercept.toDouble()) {
                    adjustmentHint(warning, color: offsetIsValid() ? warningColor : Color(.systemRed))
                } else if let hint = previewBgCheckHintText() {
                    adjustmentHint(hint, color: .secondary)
                }
            } else {
                Label(bgPostProcessingManager.bgAdjustmentDisabledMessageForCurrentSource() ?? Texts_HomeView.postProcessingAdjustmentUnavailableNativeCalibration, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private func adjustmentHint(_ text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .accessibilityHidden(true)
            Text(text)
        }
        .font(.footnote)
        .foregroundStyle(color)
    }

    private func nudgeControls(title: String, value: String, valueColor: Color, minusDisabled: Bool, plusDisabled: Bool, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            nudgeButton(symbol: "minus", label: String(format: Texts_HomeView.postProcessingDecrease, title), disabled: minusDisabled, action: onMinus)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 44)
            nudgeButton(symbol: "plus", label: String(format: Texts_HomeView.postProcessingIncrease, title), disabled: plusDisabled, action: onPlus)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func nudgeButton(symbol: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.medium))
                .frame(width: 34, height: 30)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Color.secondary : Color.primary)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private func adjustmentValueRow<Controls: View>(_ title: String, @ViewBuilder controls: () -> Controls) -> some View {
        let controls = controls()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                Text(title).fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 4)
                controls
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                controls
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var offsetReferenceButton: some View {
        let value = latestSourceReading == nil ? "-" : displayBgString(for: currentAdjustedGlucoseValueInMgDl())
        return Button {
            draftAdjustedGlucoseValue = adjustedGlucoseInputValueString()
            openingReferenceGlucoseValue = draftAdjustedGlucoseValue.toDouble()
            showingBasicAdjustmentInputSheet = true
        } label: {
            Text(value)
                .font(.subheadline)
                .monospacedDigit()
                .fixedSize()
                .foregroundStyle(latestSourceReading == nil ? Color.secondary : Color.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(latestSourceReading == nil)
        .accessibilityLabel(Texts_HomeView.postProcessingEnterReferenceGlucose)
        .accessibilityValue(value)
    }

    private func offsetAdjustmentValueRow() -> some View {
        let title = Texts_HomeView.postProcessingOffset
        let stepper = nudgeControls(title: title, value: displayAdjustmentValueString(for: intercept.toDouble() ?? 0.0, includeUnit: false), valueColor: offsetValueTextColor(), minusDisabled: !canDecreaseOffsetValue(), plusDisabled: !canIncreaseOffsetValue(), onMinus: {
            updateIntercept(by: -interceptNudgeValueInMgDl())
        }, onPlus: {
            updateIntercept(by: interceptNudgeValueInMgDl())
        })
        return adjustmentValueRow(title) {
            HStack(spacing: 4) {
                offsetReferenceButton
                stepper
            }
        }
    }

    @ViewBuilder private func scaleAdjustmentControl() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            adjustmentValueRow(Texts_HomeView.postProcessingScale) {
                nudgeControls(title: Texts_HomeView.postProcessingScale, value: displaySlopeString(for: slope.toDouble()), valueColor: scaleValueTextColor(), minusDisabled: !canDecreaseScaleValue(), plusDisabled: !canIncreaseScaleValue(), onMinus: {
                    updateSlope(by: -ConstantsBgAdjustment.slopeNudgeValue)
                }, onPlus: {
                    updateSlope(by: ConstantsBgAdjustment.slopeNudgeValue)
                })
            }

            Menu {
                Picker(Texts_HomeView.postProcessingCurveShape, selection: $adjustmentShapeTypeRawValue) {
                    ForEach([BgAdjustmentShapeType.softerHighs, .neutral, .softerLows], id: \.rawValue) { shape in
                        Text(shape.description).tag(shape.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(Texts_HomeView.postProcessingCurveShape)
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 8)
                    Text(adjustmentShapeType.description)
                        .foregroundStyle(Color.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(shapeControlDisabled())

            if shouldShowSelectedAdjustmentShapeDescription() {
                Text(selectedAdjustmentShapeDescription())
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private func smoothingSection() -> some View {
        let title = Texts_HomeView.postProcessingPreviousReadings
        let strength = strengthTitle(historicalMode)
        disclosureRow(.previous, title: title, summary: enableSmoothing ? [smoothingAlgorithm.description, strength].joined(separator: " · ") : strength, enabled: enableSmoothing)
        if expandedSection == .previous {
            modeSelector(title, options: LatestReadingSmoothing.Mode.allCases, off: .off, selection: historicalMode, label: strengthTitle, onSelect: selectHistoricalMode)
                .padding(.top, enableSmoothing ? 0 : 4)
            if enableSmoothing {
                HStack(spacing: 4) {
                    Menu {
                        ForEach(BgSmoothingAlgorithm.allCases, id: \.self) { smoothingAlgorithm in
                            Button {
                                self.smoothingAlgorithm = smoothingAlgorithm
                            } label: {
                                if self.smoothingAlgorithm == smoothingAlgorithm {
                                    Label(smoothingAlgorithm.description, systemImage: "checkmark")
                                } else {
                                    Text(smoothingAlgorithm.description)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(Texts_HomeView.postProcessingAlgorithm)
                                .foregroundStyle(Color.primary)
                            Spacer(minLength: 8)
                            Text(smoothingAlgorithm.description)
                                .foregroundStyle(Color.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingSmoothingAlgorithmInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Texts_HomeView.info)
                    .alert(smoothingAlgorithm.description, isPresented: $showingSmoothingAlgorithmInfo) {
                        Button(Texts_Common.Ok, role: .cancel) {}
                    } message: {
                        Text(smoothingAlgorithm.footerDescription)
                    }
                }
            }
            sectionFooter(Texts_HomeView.postProcessingPreviousReadingsFooter)
                .padding(.top, enableSmoothing ? 0 : 8)
        }
    }

    @ViewBuilder private func latestReadingSmoothingSection() -> some View {
        let title = Texts_HomeView.postProcessingLatestReading
        disclosureRow(.latest, title: title, summary: strengthTitle(latestReadingSmoothingMode), enabled: latestReadingSmoothingMode.isEnabled)
        if expandedSection == .latest {
            modeSelector(title, options: LatestReadingSmoothing.Mode.allCases, off: .off, selection: latestReadingSmoothingMode, label: strengthTitle, onSelect: selectLiveMode)
                .padding(.top, 4)
            sectionFooter(Texts_HomeView.postProcessingLatestReadingFooter)
                .padding(.top, 8)
        }
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.secondary)
    }

    @ViewBuilder private func readingFrequencySection() -> some View {
        if sourceCanUseFiveMinuteReadings() {
            Section(header: Text(Texts_HomeView.postProcessingReadingFrequency)) {
                Toggle(Texts_HomeView.postProcessingFiveMinuteReadings, isOn: $useFiveMinuteReadings)
                    .tint(ConstantsAppColors.normal)
            }
        }
    }

    private func chartContextView() -> Text {
        guard latestReadingSmoothingMode.isEnabled else {
            return Text(Texts_HomeView.postProcessingLatestReadingDisabled)
                .foregroundColor(.secondary)
        }

        var chartContextParts = [(title: String, value: Double, isFinalValue: Bool)]()

        let latestIndex = livePreviewReadingIndexes(previewReadingIndexes(dates: bgReadings.map(\.timeStamp))).last
        if let latestIndex {
            let originalValue = bgReadings[latestIndex].calculatedValue
            chartContextParts.append((title: Texts_HomeView.postProcessingOriginal, value: originalValue, isFinalValue: false))
        }

        if effectiveEnableAnyAdjustment(), let latestIndex, let adjustment = currentAdjustmentPreview() {
            let adjustedValue = adjustment.scaleCenterInMgDl + adjustment.slope * (bgReadings[latestIndex].calculatedValue - adjustment.scaleCenterInMgDl) + adjustment.intercept
            chartContextParts.append((title: Texts_HomeView.postProcessingAdjusted, value: adjustedValue, isFinalValue: false))
        }

        if let latestIndex, previewAllFinalBgReadingValues.indices.contains(latestIndex) {
            chartContextParts.append((title: Texts_HomeView.postProcessingSmoothed, value: previewAllFinalBgReadingValues[latestIndex], isFinalValue: true))
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
        let titleColor: Color = isFinalValue ? .primary : .secondary
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
        guard let adjustedGlucoseValueInMgDl = enteredGlucoseValueInMgDl(draftAdjustedGlucoseValue), let latestBgReading = latestSourceReading else { return }

        let offset = (adjustedGlucoseValueInMgDl - latestBgReading.calculatedValue).round(toDecimalPlaces: 1)
        guard ConstantsBgAdjustment.isValidOffset(offset) else { return }
        intercept = offset.stringWithoutTrailingZeroes
        offsetAdjustmentInputType = .adjustedGlucoseValue
    }

    private func chartDataSets() -> [GlucoseChartDataSet] {
        var dataSets = [GlucoseChartDataSet]()

        // Show the original calculated values behind the previewed final values
        // so the user can compare the effect of adjustment and smoothing.
        if effectiveEnableAnyAdjustment() || enableSmoothing || latestReadingSmoothingMode.isEnabled || effectiveUseFiveMinuteReadings() {
            dataSets.append(GlucoseChartDataSet(bgReadingValues: calculatedBgReadingValues, bgReadingDates: calculatedBgReadingDates, seriesIdentifier: "original", lineColor: nil, pointColor: ConstantsGlucoseChart.glucoseOriginalPreviewColor, lineWidth: 0, dash: [], showLine: false, showPoints: true, pointSizeMultiplier: 1.0, pointBorderColor: nil, pointBorderSizeMultiplier: nil))
        }

        if bgCheckTreatmentChartPointsValues.count > 0 {
            dataSets.append(GlucoseChartDataSet(bgReadingValues: bgCheckTreatmentChartPointsValues, bgReadingDates: bgCheckTreatmentChartPointsDates, seriesIdentifier: "bgCheckTreatments", lineColor: nil, pointColor: ConstantsGlucoseChart.bgCheckTreatmentColorInner, lineWidth: 0, dash: [], showLine: false, showPoints: true, pointSizeMultiplier: Double(ConstantsGlucoseChart.bgCheckTreatmentScaleInner) * 1.15, pointBorderColor: ConstantsGlucoseChart.bgCheckTreatmentColorOuter, pointBorderSizeMultiplier: Double(ConstantsGlucoseChart.bgCheckTreatmentScaleOuter) * 1.25))
        }

        return dataSets
    }

    private func loadViewState() {
        bgPostProcessingManager.refreshSourceContext()
        enableAdjustment = UserDefaults.standard.enableAdjustment && UserDefaults.standard.enableGlucoseAdjustment
        enableCurveAdjustment = UserDefaults.standard.enableAdjustment && UserDefaults.standard.enableCurveAdjustment
        enableSmoothing = UserDefaults.standard.enableSmoothing
        latestReadingSmoothingMode = UserDefaults.standard.latestReadingSmoothingMode
        useFiveMinuteReadings = UserDefaults.standard.useFiveMinuteReadings
        smoothingAlgorithm = UserDefaults.standard.bgSmoothingAlgorithm
        smoothingStrength = UserDefaults.standard.bgSmoothingStrength
        chartHoursToShow = Double(UserDefaults.standard.postProcessingPreviewChartHoursToShow)
        openedSourceContext = bgPostProcessingManager.postProcessingEditingSource
        let currentAdjustment = bgPostProcessingManager.latestActiveBgAdjustment()
        let saved = bgPostProcessingManager.adjustmentEditingPreferences
        openedSlopeValue = (enableCurveAdjustment ? currentAdjustment?.slope ?? saved.scale : saved.scale).round(toDecimalPlaces: 2)
        openedInterceptValue = (enableAdjustment ? currentAdjustment?.intercept ?? saved.offset : saved.offset).round(toDecimalPlaces: 1)
        openedShape = enableCurveAdjustment ? currentAdjustment?.adjustmentShapeType ?? saved.shape : saved.shape
        slope = openedSlopeValue.description
        intercept = openedInterceptValue.stringWithoutTrailingZeroes
        adjustmentShapeTypeRawValue = openedShape

        loadBgReadings()

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
        previewSourceStartDate = max(
            UserDefaults.standard.postProcessingStartTimeStamp ?? .distantPast,
            bgPostProcessingManager.currentSensorForPostProcessing()?.startDate ?? .distantPast
        )

        bgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: fromDate, forSensor: currentSensor, ignoreRawData: true, ignoreCalculatedValue: false, includingSuppressed: true).sorted { $0.timeStamp < $1.timeStamp }

        if !sourceCanUseFiveMinuteReadings() {
            useFiveMinuteReadings = false
        }

        calculatedBgReadingValues = bgReadings.map { $0.calculatedValue }
        calculatedBgReadingDates = bgReadings.map { $0.timeStamp }
        loadBgCheckTreatmentChartPoints(fromDate: fromDate)

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
        let now = Date()
        let bgCheckTreatments = treatmentEntryAccessor.getLatestTreatments(limit: nil, fromDate: fromDate)
            .filter { !$0.treatmentdeleted && $0.treatmentType == .BgCheck && $0.date <= now }
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

        guard effectiveEnableAnyAdjustment() || enableSmoothing || latestReadingSmoothingMode.isEnabled || effectiveUseFiveMinuteReadings() else {
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

        if effectiveEnableAnyAdjustment(), let adjustmentPreview = currentAdjustmentPreview() {
            finalValues = sourceValues.map {
                adjustmentPreview.scaleCenterInMgDl + adjustmentPreview.slope * ($0 - adjustmentPreview.scaleCenterInMgDl) + adjustmentPreview.intercept
            }
        }

        let dates = bgReadings.map(\.timeStamp)
        let visibleReadingIndexes = previewReadingIndexes(dates: dates)
        let baselineValues = finalValues
        if enableSmoothing {
            let validIndexes = sourceValues.indices.filter { sourceValues[$0] > 0 }
            let smoothed = bgPostProcessingManager.smoothedValuesSeparatedByReadingGap(
                values: validIndexes.map { baselineValues[$0] }, readingDates: validIndexes.map { dates[$0] },
                smoothingStrength: smoothingStrength, smoothingAlgorithm: smoothingAlgorithm
            )
            for (index, value) in zip(validIndexes, smoothed) where index != visibleReadingIndexes.last {
                finalValues[index] = value
            }
        }

        if latestReadingSmoothingMode.isEnabled {
            let liveIndexes = livePreviewReadingIndexes(visibleReadingIndexes)
            if let latest = liveIndexes.last {
                finalValues[latest] = LatestReadingSmoothing.value(
                    for: .init(date: dates[latest], value: baselineValues[latest]),
                    previous: liveIndexes.dropLast().map { .init(date: dates[$0], value: baselineValues[$0]) },
                    mode: latestReadingSmoothingMode
                )
            }
        }

        previewAllFinalBgReadingValues = finalValues
        previewAllFinalBgReadingDates = dates

        previewVisibleFinalBgReadingValues = visibleReadingIndexes.map { finalValues[$0] }
        previewVisibleFinalBgReadingDates = visibleReadingIndexes.map { bgReadings[$0].timeStamp }
    }

    private func currentAdjustmentPreview() -> (slope: Double, intercept: Double, scaleCenterInMgDl: Double)? {
        guard let slopeAsDouble = slope.toDouble(), let interceptAsDouble = intercept.toDouble() else { return nil }

        return (effectiveEnableCurveAdjustment() ? slopeAsDouble : 1.0, effectiveEnableAdjustment() ? interceptAsDouble : 0.0, adjustmentShapeType.scaleCenterInMgDl)
    }

    private func selectedApplyFromTimeStamp() -> Date {
        let latestBgReadingTimeStamp = latestSourceReading?.timeStamp ?? Date()

        if let postProcessingStartTimeStamp = UserDefaults.standard.postProcessingStartTimeStamp {
            return max(latestBgReadingTimeStamp, postProcessingStartTimeStamp)
        }

        return latestBgReadingTimeStamp
    }

    /// historical apply is anchored to the latest available reading, not to now,
    /// so gaps in incoming data do not shrink the user-selected rewrite window
    private func historicalApplyFromTimeStamp(for option: ApplyFromOption) -> Date {
        let latestBgReadingTimeStamp = latestSourceReading?.timeStamp ?? Date()
        return latestBgReadingTimeStamp.addingTimeInterval(-option.timeInterval)
    }

    private func previewReadingIndexes(dates: [Date]) -> [Int] {
        bgPostProcessingManager.visibleReadingIndexesAfterApplyingFiveMinuteCadence(
            readingDates: dates, enableFiveMinuteReadings: effectiveUseFiveMinuteReadings()
        ).filter { bgReadings[$0].calculatedValue > 0 }
    }

    private func livePreviewReadingIndexes(_ visibleIndexes: [Int]) -> [Int] {
        visibleIndexes.filter { bgReadings[$0].timeStamp >= previewSourceStartDate }
    }

    private var latestSourceReading: BgReading? {
        bgReadings.last { $0.timeStamp >= previewSourceStartDate && $0.calculatedValue > 0 }
    }

    private func beginApply() {
        guard canApplyChanges() else { return }
        if historicalSettingsChanged() {
            showingApplyFromConfirmation = true
        } else {
            if bgPostProcessingManager.updateLatestReadingSmoothing(
                mode: latestReadingSmoothingMode,
                acknowledgedWarning: acknowledgedWarnings.contains(.latestReadingSmoothing)
            ) {
                presentationMode.wrappedValue.dismiss()
            } else {
                adjustmentAlert = .invalidAdjustment
            }
        }
    }

    private func applyChanges(from option: ApplyFromOption) {
        guard canApplyChanges() else { return }

        let isNow = option.timeInterval == 0
        let applyFromTimeStamp = isNow ? selectedApplyFromTimeStamp() : historicalApplyFromTimeStamp(for: option)
        let adjustmentPreview = currentAdjustmentPreview()
        let applied = bgPostProcessingManager.applyPostProcessing(
            enableGlucoseAdjustment: effectiveEnableAdjustment(),
            enableCurveAdjustment: effectiveEnableCurveAdjustment(),
            slope: adjustmentPreview?.slope,
            intercept: adjustmentPreview?.intercept,
            adjustmentShapeType: adjustmentShapeType,
            applyFromTimeStamp: applyFromTimeStamp,
            isBasicAdjustment: false,
            enteredBgValue: currentAdjustedGlucoseValueInMgDl(),
            sourceCalculatedValue: latestSourceReading?.calculatedValue,
            enableSmoothing: enableSmoothing,
            useFiveMinuteReadings: effectiveUseFiveMinuteReadings(),
            smoothingPeriodInMinutes: ConstantsBgSmoothing.defaultSmoothingPeriodInMinutes,
            smoothingStrength: smoothingStrength,
            smoothingAlgorithm: smoothingAlgorithm,
            processingStartDateOverride: isNow ? nil : applyFromTimeStamp,
            troubleshootingApplyRange: option.troubleshootingRange,
            acknowledgedWarnings: acknowledgedWarnings,
            latestReadingSmoothingMode: latestReadingSmoothingMode
        )

        if applied {
            presentationMode.wrappedValue.dismiss()
        } else {
            adjustmentAlert = .invalidAdjustment
        }
    }

    private func cancelEditing() {
        if hasDraftChanges() && canApplyChanges() {
            showingUnsavedChangesConfirmation = true
        } else if hasDraftChanges() {
            showingDiscardConfirmation = true
        } else {
            presentationMode.wrappedValue.dismiss()
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
        guard let openedSourceContext, openedSourceContext == bgPostProcessingManager.postProcessingEditingSource,
              latestSourceReading != nil, !effectiveEnableAdjustment() || offsetIsValid() else { return false }
        return hasDraftChanges()
    }

    private func hasDraftChanges() -> Bool {
        historicalSettingsChanged() || latestReadingSmoothingMode != UserDefaults.standard.latestReadingSmoothingMode
    }

    private func historicalSettingsChanged() -> Bool {
        let defaults = UserDefaults.standard
        let glucoseAdjustmentChanged = enableAdjustment != (defaults.enableAdjustment && defaults.enableGlucoseAdjustment) ||
            (effectiveEnableAdjustment() && offsetValueChanged())
        let curveAdjustmentChanged = enableCurveAdjustment != (defaults.enableAdjustment && defaults.enableCurveAdjustment) ||
            (effectiveEnableCurveAdjustment() && (scaleValueChanged() || adjustmentShapeTypeRawValue != openedShape))

        return glucoseAdjustmentChanged || curveAdjustmentChanged ||
            enableSmoothing != UserDefaults.standard.enableSmoothing ||
            effectiveUseFiveMinuteReadings() != UserDefaults.standard.useFiveMinuteReadings ||
            (enableSmoothing && (smoothingStrength != UserDefaults.standard.bgSmoothingStrength ||
                smoothingAlgorithm != UserDefaults.standard.bgSmoothingAlgorithm))
    }

    private func shouldAllowAdjustmentForCurrentSource() -> Bool {
        bgPostProcessingManager.shouldAllowBgAdjustmentForCurrentSource()
    }

    private func effectiveEnableAdjustment() -> Bool {
        return shouldAllowAdjustmentForCurrentSource() && enableAdjustment
    }

    private func effectiveEnableCurveAdjustment() -> Bool {
        return shouldAllowAdjustmentForCurrentSource() && enableCurveAdjustment
    }

    private func effectiveEnableAnyAdjustment() -> Bool {
        return effectiveEnableAdjustment() || effectiveEnableCurveAdjustment()
    }

    private func effectiveUseFiveMinuteReadings() -> Bool {
        return sourceCanUseFiveMinuteReadings() && useFiveMinuteReadings
    }

    private func sourceCanUseFiveMinuteReadings() -> Bool {
        // The preview chart can optionally show older sensor or follower data.
        // Cadence detection must use the current source only so old 5 minute data
        // does not hide this option for a current faster source.
        return bgPostProcessingManager.currentSourceCanUseFiveMinuteReadings()
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
        var applyFromOptions = [ApplyFromOption(title: Texts_HomeView.postProcessingNow, timeInterval: 0, troubleshootingRange: .now)]

        for applyFromPeriodInHours in applyFromPeriodsInHours {
            let applyFromTimeInterval = Double(applyFromPeriodInHours) * 3600.0
            applyFromOptions.append(ApplyFromOption(title: "-\(applyFromPeriodInHours)h", timeInterval: applyFromTimeInterval, troubleshootingRange: .hoursAgo(applyFromPeriodInHours)))
        }

        return applyFromOptions
    }

    private func availableHistoricalApplyTimeInterval() -> TimeInterval {
        guard let latestPreviewReadingTimeStamp = latestSourceReading?.timeStamp else { return 0 }

        // Historical apply availability should follow the source history, not the
        // current preview zoom level. Otherwise selecting a shorter preview window
        // can incorrectly disable longer apply windows that are still valid.
        let sourceWindowStartTimeStamp = UserDefaults.standard.postProcessingStartTimeStamp ?? .distantPast

        return max(0, latestPreviewReadingTimeStamp.timeIntervalSince(sourceWindowStartTimeStamp))
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

        return String(format: "%.2f", locale: Locale.current, value)
    }

    private func scaleValueTextColor() -> Color {
        guard let currentSlope = slope.toDouble() else { return Color.secondary }

        return abs(currentSlope - 1.0) < 0.0001 ? Color.secondary : Color.primary
    }

    private func offsetValueTextColor() -> Color {
        if let offset = intercept.toDouble(), ConstantsBgAdjustment.offsetNeedsWarning(offset) {
            return offsetIsValid() ? warningColor : Color(.systemRed)
        }
        guard offsetAdjustmentInputType == .offsetValue else { return Color.secondary }

        if offsetValueChanged() || shouldHighlightCurrentOffsetValueOnOpen() {
            return Color.primary
        }

        return Color.secondary
    }

    private func shouldHighlightCurrentOffsetValueOnOpen() -> Bool {
        guard enableAdjustment else { return false }
        guard let interceptValue = intercept.toDouble(), abs(interceptValue) > 0.0001 else { return false }

        return !offsetValueChanged()
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

    private func shouldShowSelectedAdjustmentShapeDescription() -> Bool {
        return !shapeControlDisabled() && adjustmentShapeType != .neutral
    }

    private func previewBgCheckHintText() -> String? {
        let count = bgCheckTreatmentChartPointsValues.count
        if effectiveEnableCurveAdjustment(), scaleValueChanged() {
            return count < 2 ? Texts_HomeView.postProcessingScaleBgCheckHint : nil
        }
        if effectiveEnableAdjustment(), count == 0 {
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
        guard let adjustedGlucoseValueInMgDl = enteredGlucoseValueInMgDl(adjustedGlucoseValueString), let latestBgReading = latestSourceReading else {
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
        let prefix = adjustmentValueInMgDl < 0 ? "-" : "+"
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
        guard let latestBgReading = latestSourceReading else { return nil }

        return latestBgReading.calculatedValue + (intercept.toDouble() ?? 0.0)
    }

    private func canDecreaseOffsetValue() -> Bool {
        guard let currentAdjustedGlucoseValueInMgDl = currentAdjustedGlucoseValueInMgDl() else { return false }

        return currentAdjustedGlucoseValueInMgDl - interceptNudgeValueInMgDl() >= minimumGlucoseValueInMgDl &&
            (intercept.toDouble() ?? 0) - interceptNudgeValueInMgDl() >= -ConstantsBgAdjustment.maximumOffsetInMgDl
    }

    private func canIncreaseOffsetValue() -> Bool {
        guard let currentAdjustedGlucoseValueInMgDl = currentAdjustedGlucoseValueInMgDl() else { return false }

        return currentAdjustedGlucoseValueInMgDl + interceptNudgeValueInMgDl() <= maximumGlucoseValueInMgDl &&
            (intercept.toDouble() ?? 0) + interceptNudgeValueInMgDl() <= ConstantsBgAdjustment.maximumOffsetInMgDl
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

    let openingReferenceGlucoseValue: Double?
    let currentGlucoseValueInMgDl: Double?
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
                            .foregroundStyle(Color.secondary)
                    }

                    HStack {
                        Text(Texts_HomeView.postProcessingReferenceGlucose)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        AutoSelectingNumericTextField(placeholder: Texts_HomeView.postProcessingEnterValue, text: $enteredGlucoseValue, shouldBecomeFirstResponder: shouldFocusEnteredGlucoseValue)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 72, maxWidth: 96, alignment: .trailing)
                        Text(unitString)
                            .foregroundStyle(Color.secondary)
                    }
                }

                Section {
                    HStack {
                        Text(Texts_HomeView.postProcessingOffset)
                        Spacer()
                        Text(glucoseAdjustmentValueString)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Texts_HomeView.postProcessingReferenceGlucose)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: onCancel)
                        .foregroundStyle(Color.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_Common.Ok, action: onConfirm)
                        .tint(ConstantsAppColors.toolbarAction)
                        .disabled(!enteredGlucoseValueIsValid() || enteredGlucoseValue.toDouble() == openingReferenceGlucoseValue)
                }
            }
        }
        .onAppear {
            shouldFocusEnteredGlucoseValue = true
        }
    }

    @ViewBuilder private func validationMessageView() -> some View {
        if let entered = enteredGlucoseValueInMgDl(), let currentGlucoseValueInMgDl,
           !ConstantsBgAdjustment.isValidOffset(entered - currentGlucoseValueInMgDl) {
            Text(String(format: Texts_HomeView.postProcessingOffsetLimit, ConstantsBgAdjustment.maximumOffsetInMgDl.mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + " " + unitString))
                .foregroundStyle(Color(.systemRed))
        } else if !enteredGlucoseValue.isEmpty, !enteredGlucoseValueIsValid() {
            Text(String(format: Texts_HomeView.postProcessingValidGlucoseRange, minimumGlucoseValueString(), maximumGlucoseValueString()))
                .foregroundStyle(Color(.systemRed))
        }
    }

    private func enteredGlucoseValueIsValid() -> Bool {
        guard let enteredGlucoseValueInMgDl = enteredGlucoseValueInMgDl() else { return false }

        guard let currentGlucoseValueInMgDl else { return false }
        return enteredGlucoseValueInMgDl >= minimumGlucoseValueInMgDl && enteredGlucoseValueInMgDl <= maximumGlucoseValueInMgDl &&
            ConstantsBgAdjustment.isValidOffset(enteredGlucoseValueInMgDl - currentGlucoseValueInMgDl)
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


private struct AdjustmentListTopMargin: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.contentMargins(.top, 6, for: .scrollContent)
        } else {
            content
        }
    }
}
