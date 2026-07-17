//
//  SensorManagementView.swift
//  xdrip
//
//  Created by Paul Plant on 15/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import os

/// Sensor summary and the start, stop and calibration workflows opened from Home.
///
/// Sensor and calibration changes are passed back to the application coordinator. The view only
/// owns temporary form and confirmation state.
struct SensorManagementView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    let activeSensorProvider: () -> Sensor?
    let transmitterProvider: () -> CGMTransmitter?
    let calibrationsAccessor: CalibrationsAccessor
    let bgReadingsAccessor: BgReadingsAccessor
    let sensorNoiseManager: SensorNoiseManager
    let onStartSensor: (Date, String?) -> Void
    let onStopSensor: () -> Void
    let onSubmitCalibration: (Double) -> String?

    @State private var refreshView = false
    @State private var showingStartDateSheet = false
    @State private var showingStartCodeSheet = false
    @State private var showingStopConfirmation = false
    @State private var showingCalibrationSheet = false
    @State private var showingLargeCalibrationDifferenceConfirmation = false
    @State private var transientMessage: SensorManagementMessage?
    @State private var selectedStartDate = Date()
    @State private var sensorCode = "0000"
    @State private var calibrationValue = ""

    private let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let nilString = "-"
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataCalibrations)

    var body: some View {
        let state = currentState()

        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(state.bannerTitle)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text(state.statusTitle)
                                    .font(.headline)
                                    .foregroundStyle(state.statusColor)
                            }

                            Spacer()

                            Image(systemName: "sensor.tag.radiowaves.forward")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(state.statusColor)
                        }
                    }
                    .padding(.vertical, 4)
                    .id(refreshView)
                }

                if state.hasTransmitter {
                    Section(header: Text(Texts_HomeView.sensorManagementSummaryTitle), footer: summaryFooter(for: state)) {
                        row(title: Texts_HomeView.sensorStart, data: state.startDateString)
                        row(title: state.secondarySessionTitle, data: state.secondarySessionValue, dataColor: state.secondarySessionColor)
                        if state.showsRemainingRow {
                            row(title: Texts_HomeView.sensorManagementRemaining, data: state.remainingString, dataColor: state.remainingColor)
                        }
                    }

                    if state.showsNoise {
                        Section(header: Text(Texts_HomeView.sensorManagementNoiseTitle), footer: Text(Texts_HomeView.sensorManagementNoiseFooter)) {
                            if let sensorID = state.sensorID {
                                NavigationLink {
                                    SensorNoiseHistoryView(
                                        sensorID: sensorID,
                                        sensorNoiseManager: sensorNoiseManager,
                                        isMgDl: isMgDl,
                                        currentMeasurementsDetail: state.noiseMeasurementsDetail
                                    )
                                } label: {
                                    SensorNoiseSummaryRow(
                                        shortTermNoise: state.shortTermNoise,
                                        longTermNoise: state.longTermNoise,
                                        state: state.noiseState,
                                        isMgDl: isMgDl
                                    )
                                }
                            }
                        }
                    }

                    Section(header: Text(Texts_HomeView.sensorManagementActionsTitle), footer: actionFooter(for: state)) {
                        Button(role: state.canStopSensor ? .destructive : nil, action: {
                            if state.canStopSensor {
                                showingStopConfirmation = true
                            } else {
                                handleStartTap()
                            }
                        }) {
                            Text(state.canStopSensor ? Texts_HomeView.stopSensorActionTitle : Texts_HomeView.startSensorActionTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(state.canStopSensor ? .red : .green)
                        .disabled(!state.canStartSensor && !state.canStopSensor)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }

                    Section(header: Text(Texts_HomeView.sensorManagementCalibrationTitle), footer: calibrationFooter(for: state)) {
                        if state.showCalibrationUnavailableRow {
                            row(title: Texts_HomeView.calibrationButton, data: Texts_Common.notAvailable)
                        } else {
                            Button(action: {
                                calibrationValue = ""
                                showingCalibrationSheet = true
                            }) {
                                Text(Texts_HomeView.calibrationButton)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(.systemBlue))
                            .disabled(!state.canCalibrate || state.currentBgDisplay == nil)
                        }

                        if let currentCalibration = state.currentCalibration {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(Texts_HomeView.sensorManagementCurrentCalibrationTitle)
                                    .font(.headline)
                                calibrationSummaryView(calibration: currentCalibration, isHistoric: false)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if !state.calibrationHistory.isEmpty {
                        Section(header: Text(Texts_HomeView.sensorManagementHistoryTitle)) {
                            ForEach(state.calibrationHistory, id: \.id) { calibration in
                                calibrationSummaryView(calibration: calibration, isHistoric: !calibration.isValid)
                            }
                        }
                    }
                } else {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(Color(.colorSecondary))

                            Text(Texts_HomeView.sensorManagementNoTransmitterNote)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(.colorPrimary))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle(Texts_HomeView.sensorManagementTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: {
                        self.presentationMode.wrappedValue.dismiss()
                    })
                }
            }
        }
        .colorScheme(.dark)
        .onReceive(timer) { _ in
            refreshView.toggle()
        }
        .alert(item: $transientMessage) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text(Texts_Common.Ok)))
        }
        .alert(Texts_Common.warning, isPresented: $showingLargeCalibrationDifferenceConfirmation) {
            Button(Texts_Common.Cancel, role: .cancel) {}
            Button(Texts_HomeView.calibrationButton) {
                confirmCalibrationAfterWarning()
            }
        } message: {
            Text(largeCalibrationDifferenceWarning(for: currentState()) ?? "")
        }
        .alert(Texts_Common.warning, isPresented: $showingStopConfirmation) {
            Button(Texts_Common.Cancel, role: .cancel) {}
            Button(Texts_Common.yes, role: .destructive) {
                onStopSensor()
                refreshView.toggle()
            }
        } message: {
            Text(Texts_HomeView.stopSensorConfirmation)
        }
        .sheet(isPresented: $showingStartDateSheet) {
            startDateSheet
        }
        .sheet(isPresented: $showingStartCodeSheet) {
            startCodeSheet
        }
        .sheet(isPresented: $showingCalibrationSheet) {
            calibrationSheet(state: state)
        }
    }

    private var startDateSheet: some View {
        NavigationView {
            Form {
                if !UserDefaults.standard.startSensorTimeInfoGiven {
                    Section {
                        Text(Texts_HomeView.startSensorTimeInfo)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }

                Section(header: Text(Texts_HomeView.startSensorActionTitle)) {
                    DatePicker(
                        Texts_HomeView.sensorStart,
                        selection: $selectedStartDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle(Texts_HomeView.startSensorActionTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) {
                        showingStartDateSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_Common.Ok) {
                        UserDefaults.standard.startSensorTimeInfoGiven = true
                        showingStartDateSheet = false
                        onStartSensor(selectedStartDate, nil)
                        refreshView.toggle()
                    }
                }
            }
        }
        .colorScheme(.dark)
    }

    private var startCodeSheet: some View {
        NavigationView {
            Form {
                Section {
                    Text(Texts_HomeView.enterSensorCode)
                        .foregroundStyle(Color(.colorSecondary))
                }

                Section(header: Text(Texts_HomeView.startSensorActionTitle)) {
                    TextField("0000", text: $sensorCode)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(Texts_HomeView.startSensorActionTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) {
                        showingStartCodeSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_Common.Ok) {
                        let codeToSubmit = sensorCode.trimmingCharacters(in: .whitespacesAndNewlines)
                        showingStartCodeSheet = false
                        onStartSensor(Date(), codeToSubmit.isEmpty ? nil : codeToSubmit)
                        refreshView.toggle()
                    }
                }
            }
        }
        .colorScheme(.dark)
    }

    private func handleStartTap() {
        let state = currentState()

        if state.needsSensorStartTime {
            selectedStartDate = Date()
            showingStartDateSheet = true
        } else if state.needsSensorStartCode {
            sensorCode = "0000"
            showingStartCodeSheet = true
        } else {
            onStartSensor(Date(), nil)
            refreshView.toggle()
        }
    }

    private func submitCalibration() {
        let state = currentState()

        guard isCalibrationValueInRange() else {
            return
        }

        guard calibrationValue.toDouble() != nil else {
            transientMessage = SensorManagementMessage(title: Texts_Common.warning, message: Texts_Common.invalidValue)
            return
        }

        if state.shouldWarnOnLargeCalibrationStep, largeCalibrationDifferenceWarning(for: state) != nil {
            showingLargeCalibrationDifferenceConfirmation = true
            return
        }

        executeCalibration(state: state)
    }

    private func confirmCalibrationAfterWarning() {
        guard isCalibrationValueInRange() else { return }

        executeCalibration(state: currentState())
    }

    private func executeCalibration(state: SensorManagementState) {
        guard let valueAsDouble = calibrationValue.toDouble() else { return }

        let currentBgValueDescription = state.currentBgDisplay?.displayValueWithUnit(isMgDl: isMgDl) ?? nilString
        let calibrationValueDescription = displayEnteredCalibrationValueWithUnit(valueAsDouble)
        let warningMessage = largeCalibrationDifferenceWarning(for: state)

        if let warningMessage {
            trace(
                "in submitCalibration, user calibrating. current BG = %{public}@, calibration value = %{public}@, warning = %{public}@",
                log: log,
                category: ConstantsLog.categoryApplicationDataCalibrations,
                type: .info,
                currentBgValueDescription,
                calibrationValueDescription,
                warningMessage
            )
        } else {
            trace(
                "in submitCalibration, user calibrating. current BG = %{public}@, calibration value = %{public}@",
                log: log,
                category: ConstantsLog.categoryApplicationDataCalibrations,
                type: .info,
                currentBgValueDescription,
                calibrationValueDescription
            )
        }

        if let errorMessage = onSubmitCalibration(valueAsDouble) {
            transientMessage = SensorManagementMessage(title: Texts_Common.warning, message: errorMessage)
        } else {
            showingCalibrationSheet = false
            refreshView.toggle()
        }
    }

    private func actionFooter(for state: SensorManagementState) -> some View {
        Group {
            if let actionNote = state.sensorActionNote {
                Text(actionNote)
            }
        }
    }

    private func summaryFooter(for state: SensorManagementState) -> some View {
        Group {
            if let expiryFooter = state.expiryFooter {
                Text(expiryFooter)
            }
        }
    }

    private func calibrationFooter(for state: SensorManagementState) -> some View {
        Group {
            if let calibrationNote = state.calibrationNote {
                Text(calibrationNote)
            }
        }
    }

    private func calibrationSheet(state: SensorManagementState) -> some View {
        NavigationView {
            Form {
                Section(footer: calibrationEntryFooter) {
                    HStack {
                        Text(Texts_HomeView.postProcessingCurrentValue)
                        Spacer()
                        if let currentBgDisplay = state.currentBgDisplay {
                            Text(currentBgDisplay.rawValue)
                                .foregroundStyle(Color(.colorSecondary))
                            Text(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
                                .foregroundStyle(Color(.colorTertiary))
                        } else {
                            Text(nilString)
                                .foregroundStyle(Color(.colorSecondary))
                        }
                    }

                    HStack {
                        Text(Texts_BgReadings.calibrationValue)
                        Spacer()
                        TextField(isMgDl ? "---" : "-.-", text: $calibrationValue)
                            .keyboardType(isMgDl ? .numberPad : .decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 96)
                            .foregroundStyle(calibrationValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.colorSecondary) : Color(.colorPrimary))
                        Text(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
                            .foregroundStyle(Color(.colorTertiary))
                    }
                }
            }
            .navigationTitle(Texts_HomeView.calibrationButton)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) {
                        calibrationValue = ""
                        showingCalibrationSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_HomeView.calibrationButton) {
                        submitCalibration()
                    }
                    .disabled(!state.canCalibrate || !isCalibrationValueValid(for: state))
                }
            }
        }
        .colorScheme(.dark)
    }

    private var calibrationEntryFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            validationMessageView()
            Text(Texts_HomeView.sensorManagementCalibrationSafetyFooter)
            Button(action: {
                openCalibrationHelp()
            }) {
                Label(Texts_HomeView.sensorManagementCalibrationHelp, systemImage: "questionmark.circle")
            }
            .padding(.top, 6)
        }
    }

    private func calibrationSummaryView(calibration: SensorManagementCalibrationDisplay, isHistoric: Bool) -> some View {
        let showsCalculatedCalibrationDetails = calibration.showsCalculatedDetails

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(calibration.timeStamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.colorPrimary))
                Spacer()
                if isHistoric {
                    Text(Texts_HomeView.sensorManagementHistoricCalibration)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }
            }

            HStack {
                Text("BG")
                    .foregroundStyle(Color(.colorSecondary))
                Spacer()
                Text(displayBgValue(calibration.bg))
                    .foregroundStyle(isHistoric ? Color(.systemGray) : Color(.colorSecondary))
            }

            if showsCalculatedCalibrationDetails {
                HStack {
                    Text("Raw")
                        .foregroundStyle(Color(.colorSecondary))
                    Spacer()
                    Text(calibration.rawValue.bgValueToString(mgDl: true) + " " + Texts_Common.mgdl)
                        .foregroundStyle(isHistoric ? Color(.systemGray) : Color(.colorSecondary))
                }

                HStack {
                    Text("Slope")
                        .foregroundStyle(Color(.colorSecondary))
                    Spacer()
                    Text(calibration.slope.formatted(.number.rounded(increment: 0.0001)))
                        .foregroundStyle(isHistoric ? Color(.systemGray) : Color(.colorSecondary))
                }

                HStack {
                    Text("Intercept")
                        .foregroundStyle(Color(.colorSecondary))
                    Spacer()
                    Text(calibration.intercept.formatted(.number.rounded(increment: 0.0001)))
                        .foregroundStyle(isHistoric ? Color(.systemGray) : Color(.colorSecondary))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func row(title: String, data: String, dataColor: Color = Color(.colorSecondary)) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(data)
                .foregroundStyle(dataColor)
                .multilineTextAlignment(.trailing)
        }
    }

    private func displayBgValue(_ valueInMgDl: Double) -> String {
        valueInMgDl.mgDlToMmol(mgDl: isMgDl).bgValueRounded(mgDl: isMgDl).bgValueToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }

    private func displayEditableBgValue(_ valueInMgDl: Double) -> String {
        valueInMgDl.mgDlToMmol(mgDl: isMgDl).bgValueRounded(mgDl: isMgDl).stringWithoutTrailingZeroes
    }

    private func isCalibrationValueValid(for state: SensorManagementState) -> Bool {
        guard let currentBgDisplay = state.currentBgDisplay else { return false }
        guard calibrationValue.toDouble() != nil else { return false }

        return calibrationValue.trimmingCharacters(in: .whitespacesAndNewlines) != currentBgDisplay.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder private func validationMessageView() -> some View {
        if !calibrationValue.isEmpty, !isCalibrationValueInRange() {
            Text(String(format: Texts_HomeView.postProcessingValidGlucoseRange, minimumGlucoseValueString(), maximumGlucoseValueString()))
                .foregroundStyle(Color(.systemRed))
        }
    }

    private func isCalibrationValueInRange() -> Bool {
        guard let enteredCalibrationValueInMgDl = enteredCalibrationValueInMgDl() else { return false }

        return enteredCalibrationValueInMgDl >= ConstantsCalibrationAlgorithms.minimumBgReadingCalculatedValue &&
            enteredCalibrationValueInMgDl <= ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue
    }

    private func enteredCalibrationValueInMgDl() -> Double? {
        guard let enteredCalibrationValue = calibrationValue.toDouble() else { return nil }

        return enteredCalibrationValue.mmolToMgdl(mgDl: isMgDl)
    }

    private func largeCalibrationDifferenceWarning(for state: SensorManagementState) -> String? {
        guard let currentBgDisplay = state.currentBgDisplay else { return nil }
        guard let enteredValueInMgDl = enteredCalibrationValueInMgDl() else { return nil }
        let differenceInMgDl = abs(enteredValueInMgDl - currentBgDisplay.valueInMgDl)

        // Only some transmitters want this extra guardrail. When enabled, keep
        // large recalibrations behind an explicit confirmation.
        guard differenceInMgDl > ConstantsCalibrationAlgorithms.maximumRecommendedCalibrationDifferenceInMgDl else { return nil }

        return String(
            format: Texts_HomeView.sensorManagementLargeCalibrationDifferenceWarningFormat,
            displayCalibrationDifferenceLimit()
        )
    }

    private func displayCalibrationDifferenceLimit() -> String {
        let limitInUserUnit = ConstantsCalibrationAlgorithms.maximumRecommendedCalibrationDifferenceInMgDl
            .mgDlToMmol(mgDl: isMgDl)
            .bgValueRounded(mgDl: isMgDl)

        return limitInUserUnit.bgValueToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }

    private func displayEnteredCalibrationValueWithUnit(_ value: Double) -> String {
        let valueInUserUnit = value.bgValueRounded(mgDl: isMgDl)
        return valueInUserUnit.bgValueToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }

    private func minimumGlucoseValueString() -> String {
        let minimumValue = ConstantsCalibrationAlgorithms.minimumBgReadingCalculatedValue
            .mgDlToMmol(mgDl: isMgDl)
            .bgValueRounded(mgDl: isMgDl)
        return minimumValue.bgValueToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }

    private func maximumGlucoseValueString() -> String {
        let maximumValue = ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue
            .mgDlToMmol(mgDl: isMgDl)
            .bgValueRounded(mgDl: isMgDl)
        return maximumValue.bgValueToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }

    private func openCalibrationHelp() {
        let urlString: String

        if let languageCode = NSLocale.current.language.languageCode?.identifier,
           languageCode != ConstantsHomeView.onlineHelpBaseLocale,
           UserDefaults.standard.translateOnlineHelp {
            urlString = ConstantsHomeView.calibrationHelpURLTranslated1 + languageCode + ConstantsHomeView.calibrationHelpURLTranslated2
        } else {
            urlString = ConstantsHomeView.calibrationHelpURL
        }

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func currentState() -> SensorManagementState {
        let transmitter = transmitterProvider()
        let activeSensor = activeSensorProvider()
        let sensorDescription: String
        if activeSensor != nil {
            sensorDescription = UserDefaults.standard.activeSensorDescription ?? Texts_HomeView.sensor
        } else {
            sensorDescription = Texts_HomeView.sensorManagementNoSensor
        }
        let startDate = activeSensor?.startDate
        let maxSensorAgeInDays = UserDefaults.standard.activeSensorMaxSensorAgeInDays ?? transmitter?.maxSensorAgeInDays() ?? 0

        let sensorType = transmitter?.cgmTransmitterType().sensorType()
        let isAnubis = transmitter?.isAnubisG6() ?? false
        let warmupMinutes: Double?

        switch sensorType {
        case .Libre:
            warmupMinutes = ConstantsMaster.minimumSensorWarmUpRequiredInMinutes
        case .Dexcom:
            warmupMinutes = isAnubis ? ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG6Anubis : ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG5G6
        case .Medtrum:
            warmupMinutes = nil
        case .none:
            warmupMinutes = nil
        }

        let elapsedMinutes = startDate.map { Double(Calendar.current.dateComponents([.minute], from: $0, to: Date()).minute ?? 0) }
        let remainingMinutes = (elapsedMinutes != nil && maxSensorAgeInDays > 0) ? ((maxSensorAgeInDays * 24 * 60) - (elapsedMinutes ?? 0)) : nil
        let expiryDate = startDate.map { $0.addingTimeInterval(TimeInterval(days: maxSensorAgeInDays)) }

        let warmupReadyTimeString: String?
        if let startDate = startDate, let warmupMinutes = warmupMinutes, let elapsedMinutes = elapsedMinutes, elapsedMinutes < warmupMinutes {
            let readyDate = startDate.addingTimeInterval(TimeInterval(minutes: warmupMinutes))
            warmupReadyTimeString = readyDate.toStringInUserLocale(timeStyle: .short, dateStyle: .none)
        } else {
            warmupReadyTimeString = nil
        }

        let statusTitle: String
        let statusColor: Color

        if activeSensor == nil {
            statusTitle = Texts_HomeView.sensorManagementStatusNotStarted
            statusColor = Color(.systemGray)
        } else if warmupReadyTimeString != nil {
            statusTitle = Texts_HomeView.sensorManagementStatusWarmingUp
            statusColor = Color.orange
        } else if let remainingMinutes = remainingMinutes, remainingMinutes < 0 {
            statusTitle = Texts_HomeView.sensorManagementStatusExpired
            statusColor = Color.red
        } else {
            statusTitle = Texts_HomeView.sensorManagementStatusActive
            statusColor = Color.green
        }

        let expiryFooter: String?
        if activeSensor != nil, warmupReadyTimeString == nil, maxSensorAgeInDays > 0, let expiryDate {
            expiryFooter = String(
                format: Texts_HomeView.sensorManagementExpiryFooterFormat,
                expiryDate.toStringInUserLocale(timeStyle: .short, dateStyle: .medium)
            )
        } else {
            expiryFooter = nil
        }

        let secondarySessionTitle: String
        let secondarySessionValue: String
        let secondarySessionColor: Color
        let showsRemainingRow: Bool

        if let warmupReadyTimeString {
            secondarySessionTitle = Texts_BluetoothPeripheralView.warmingUpUntil
            secondarySessionValue = warmupReadyTimeString
            secondarySessionColor = Color(.colorSecondary)
            showsRemainingRow = false
        } else {
            secondarySessionTitle = Texts_HomeView.sensorManagementElapsed
            secondarySessionValue = startDate?.daysAndHoursAgo() ?? nilString
            secondarySessionColor = Color(.colorSecondary)
            showsRemainingRow = true
        }

        let remainingColor: Color
        if let remainingMinutes {
            if remainingMinutes < 0 {
                remainingColor = ConstantsHomeView.sensorProgressExpiredSwiftUI
            } else if remainingMinutes <= ConstantsHomeView.sensorProgressViewUrgentInMinutes {
                remainingColor = ConstantsHomeView.sensorProgressViewProgressColorUrgentSwiftUI
            } else if remainingMinutes <= ConstantsHomeView.sensorProgressViewWarningInMinutes {
                remainingColor = ConstantsHomeView.sensorProgressViewProgressColorWarningSwiftUI
            } else {
                remainingColor = Color(.colorSecondary)
            }
        } else {
            remainingColor = Color(.colorSecondary)
        }

        let noiseMeasurementsDetail: String?
        if let startDate {
            noiseMeasurementsDetail = sensorDescription + " (" + startDate.daysAndHoursAgo() + ")"
        } else {
            noiseMeasurementsDetail = nil
        }

        let canManageSensor = UserDefaults.standard.isMaster && (transmitter?.cgmTransmitterType().allowManualSensorStart() ?? false)
        let sensorActionNote: String?
        if !UserDefaults.standard.isMaster {
            sensorActionNote = Texts_HomeView.sensorManagementNotAvailableInFollower
        } else if transmitter == nil {
            sensorActionNote = Texts_HomeView.sensorManagementNoTransmitterNote
        } else if !(transmitter?.cgmTransmitterType().allowManualSensorStart() ?? false) {
            sensorActionNote = Texts_HomeView.sensorManagementAutomaticSessionNote
        } else {
            sensorActionNote = nil
        }

        let currentCalibration = calibrationsAccessor
            .lastCalibrationForActiveSensor(withActivesensor: activeSensor)
            .map(SensorManagementCalibrationDisplay.init)
        let calibrationHistory = activeSensor.map { activeSensor in
            calibrationsAccessor
                .getLatestCalibrations(howManyDays: 4, forSensor: activeSensor)
                .map(SensorManagementCalibrationDisplay.init)
                // The latest valid calibration is already shown in its own section.
                .filter { $0.id != currentCalibration?.id }
        } ?? []

        let firstCalibration = activeSensor.flatMap { calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: $0) }
        let calibrationNote: String?
        let canCalibrate: Bool
        let showCalibrationUnavailableRow: Bool

        if !UserDefaults.standard.isMaster {
            canCalibrate = false
            showCalibrationUnavailableRow = false
            calibrationNote = Texts_HomeView.sensorManagementNotAvailableInFollower
        } else if transmitter == nil {
            canCalibrate = false
            showCalibrationUnavailableRow = false
            calibrationNote = Texts_HomeView.theresNoCGMTransmitterActive
        } else if activeSensor == nil {
            canCalibrate = false
            showCalibrationUnavailableRow = false
            calibrationNote = Texts_HomeView.startSensorBeforeCalibration
        } else if transmitter?.isWebOOPEnabled() == true && transmitter?.overruleIsWebOOPEnabled() == false {
            canCalibrate = false
            showCalibrationUnavailableRow = true
            calibrationNote = nil
        } else if firstCalibration == nil && transmitter?.overruleIsWebOOPEnabled() == false {
            let readingCount = bgReadingsAccessor.getLatestBgReadings(limit: 36, fromDate: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true, includingSuppressed: true).count
            canCalibrate = false
            showCalibrationUnavailableRow = false
            calibrationNote = readingCount > 1 ? Texts_Calibrations.calibrationNotificationRequestBody : Texts_HomeView.thereMustBeAreadingBeforeCalibration
        } else {
            canCalibrate = true
            showCalibrationUnavailableRow = false
            calibrationNote = nil
        }

        let rawNoiseState = activeSensor.flatMap { SensorNoiseState(rawValue: $0.noiseStateRaw) } ?? .collecting
        let noiseState = ConstantsSensorNoise.displayState(
            rawState: rawNoiseState,
            shortTermNoise: activeSensor?.shortTermNoise?.doubleValue,
            longTermNoise: activeSensor?.longTermNoise?.doubleValue,
            sensitivity: UserDefaults.standard.sensorNoiseSensitivity
        )

        return SensorManagementState(
            hasTransmitter: transmitter != nil,
            showsNoise: UserDefaults.standard.isMaster && activeSensor != nil,
            sensorID: activeSensor?.id,
            bannerTitle: sensorDescription,
            statusTitle: statusTitle,
            statusColor: statusColor,
            startDateString: startDate?.toStringInUserLocale(timeStyle: .short, dateStyle: .short) ?? nilString,
            secondarySessionTitle: secondarySessionTitle,
            secondarySessionValue: secondarySessionValue,
            secondarySessionColor: secondarySessionColor,
            remainingString: remainingMinutes.map { $0 < 0 ? "-" + abs($0).minutesToDaysAndHours() : $0.minutesToDaysAndHours() } ?? nilString,
            remainingColor: remainingColor,
            noiseMeasurementsDetail: noiseMeasurementsDetail,
            expiryFooter: expiryFooter,
            showsRemainingRow: showsRemainingRow,
            canStartSensor: canManageSensor && activeSensor == nil,
            canStopSensor: canManageSensor && activeSensor != nil,
            needsSensorStartTime: transmitter?.needsSensorStartTime() ?? false,
            needsSensorStartCode: transmitter?.needsSensorStartCode() ?? false,
            shouldWarnOnLargeCalibrationStep: transmitter?.shouldWarnOnLargeCalibrationStep() ?? false,
            sensorActionNote: sensorActionNote,
            canCalibrate: canCalibrate,
            showCalibrationUnavailableRow: showCalibrationUnavailableRow,
            calibrationNote: calibrationNote,
            shortTermNoise: activeSensor?.shortTermNoise?.doubleValue,
            longTermNoise: activeSensor?.longTermNoise?.doubleValue,
            noiseState: noiseState,
            currentBgDisplay: activeSensor.flatMap { bgReadingsAccessor.last(forSensor: $0) }.map {
                SensorManagementEnteredBgValue(rawValue: displayEditableBgValue($0.finalValue), valueInMgDl: $0.finalValue)
            },
            currentCalibration: currentCalibration,
            calibrationHistory: calibrationHistory
        )
    }
}

/// Complete value presentation derived from the current sensor and transmitter.
private struct SensorManagementState {
    let hasTransmitter: Bool
    let showsNoise: Bool
    let sensorID: String?
    let bannerTitle: String
    let statusTitle: String
    let statusColor: Color
    let startDateString: String
    let secondarySessionTitle: String
    let secondarySessionValue: String
    let secondarySessionColor: Color
    let remainingString: String
    let remainingColor: Color
    let noiseMeasurementsDetail: String?
    let expiryFooter: String?
    let showsRemainingRow: Bool
    let canStartSensor: Bool
    let canStopSensor: Bool
    let needsSensorStartTime: Bool
    let needsSensorStartCode: Bool
    let shouldWarnOnLargeCalibrationStep: Bool
    let sensorActionNote: String?
    let canCalibrate: Bool
    let showCalibrationUnavailableRow: Bool
    let calibrationNote: String?
    let shortTermNoise: Double?
    let longTermNoise: Double?
    let noiseState: SensorNoiseState
    let currentBgDisplay: SensorManagementEnteredBgValue?
    let currentCalibration: SensorManagementCalibrationDisplay?
    let calibrationHistory: [SensorManagementCalibrationDisplay]
}

/// Parsed calibration input in display and mg/dL units.
private struct SensorManagementEnteredBgValue {
    let rawValue: String
    let valueInMgDl: Double

    func displayValueWithUnit(isMgDl: Bool) -> String {
        rawValue + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }
}

/// One previous calibration displayed in the sensor summary.
private struct SensorManagementCalibrationDisplay {
    let id: String
    let timeStamp: Date
    let slope: Double
    let intercept: Double
    let bg: Double
    let rawValue: Double
    let isValid: Bool

    init(_ calibration: Calibration) {
        id = calibration.id
        timeStamp = calibration.timeStamp
        slope = calibration.slope
        intercept = calibration.intercept
        bg = calibration.bg
        rawValue = calibration.rawValue
        isValid = calibration.sensorConfidence != 0 && calibration.slopeConfidence != 0
    }

    var showsCalculatedDetails: Bool {
        abs(slope) > 0.0001 || abs(intercept) > 0.0001
    }
}

/// Transient result or validation message shown by the sensor workflow.
private struct SensorManagementMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
