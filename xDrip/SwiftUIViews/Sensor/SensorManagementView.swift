//
//  SensorManagementView.swift
//  xdrip
//
//  Created by Paul Plant on 15/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import Combine

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
    let onStartSensor: (SensorStartRequest) -> Void
    let onStopSensor: () -> Void
    let onSubmitCalibration: (CalibrationSubmission) -> String?
    let initiallyShowsCalibration: Bool

    @State private var refreshView = false
    @State private var showingStartDateSheet = false
    @State private var showingStartCodeSheet = false
    @State private var showingStopConfirmation = false
    @State private var showingCalibrationSheet = false
    @State private var showingSensorDetails = false
    @State private var showingNoSensorCodeConfirmation = false
    @State private var sensorNoiseSensitivity = UserDefaults.standard.sensorNoiseSensitivity
    @State private var persistentNoise: Double?
    @State private var persistentNoiseSensorID: String?
    @State private var pendingStartSensorCode: String?
    @State private var pendingStartSensorLabel: DexcomG6SensorLabel?

    private let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let nilString = "-"

    var body: some View {
        let state = currentState()

        if initiallyShowsCalibration, state.canCalibrate, state.currentBgDisplay != nil {
            CalibrationView(
                canCalibrate: state.canCalibrate,
                shouldWarnOnLargeCalibrationStep: state.shouldWarnOnLargeCalibrationStep,
                currentBgDisplay: state.currentBgDisplay,
                readiness: state.calibrationReadiness,
                isMgDl: isMgDl,
                onSubmitCalibration: onSubmitCalibration,
                onCalibrationSaved: {}
            )
        } else {
            sensorManagementView(state: state)
        }
    }

    private func sensorManagementView(state: SensorManagementState) -> some View {
        NavigationView {
            VStack(spacing: 0) {
                if state.hasTransmitter {
                    HStack(spacing: 12) {
                        if state.canStartSensor || state.canStopSensor {
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
                        }

                        Button(action: {
                            showingCalibrationSheet = true
                        }) {
                            Text(Texts_HomeView.calibrationButton)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(.systemBlue))
                        .disabled(!state.canCalibrate || state.currentBgDisplay == nil)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                List {
                    if state.hasTransmitter {
                        Section(header: Text(Texts_HomeView.sensorManagementSummaryTitle), footer: summaryFooter(for: state)) {
                            statusRow(state: state)
                                .id(refreshView)

                            if state.sensorInformationRows.isEmpty {
                                row(title: Texts_HomeView.sensorManagementCGMType, data: state.bannerTitle)
                            } else {
                                NavigationLink {
                                    SensorInformationView(rows: state.sensorInformationRows)
                                } label: {
                                    row(title: Texts_HomeView.sensorManagementCGMType, data: state.bannerTitle)
                                }
                            }

                            Button {
                                showingSensorDetails = true
                            } label: {
                                HStack {
                                    Text(Texts_HomeView.sensorManagementElapsed)
                                        .foregroundStyle(Color(.colorPrimary))
                                    Spacer()
                                    Text(state.sessionLifetimeString)
                                        .foregroundStyle(Color(.colorSecondary))
                                        .multilineTextAlignment(.trailing)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color(.tertiaryLabel))
                                }
                            }
                        }

                        if state.showsNoise {
                            Section(header: Text(Texts_HomeView.sensorManagementNoiseTitle)) {
                                if let sensorID = state.sensorID, let sensorStartDate = state.sensorStartDate {
                                    NavigationLink {
                                        SensorNoiseHistoryView(
                                            sensorID: sensorID,
                                            sensorStartDate: sensorStartDate,
                                            sensorNoiseManager: sensorNoiseManager,
                                            isMgDl: isMgDl,
                                            currentMeasurementsDetail: state.noiseMeasurementsDetail
                                        )
                                    } label: {
                                        SensorNoiseSummaryRow(
                                            shortTermNoise: state.shortTermNoise,
                                            longTermNoise: state.longTermNoise,
                                            persistentNoise: state.persistentNoise,
                                            state: state.noiseState,
                                            isMgDl: isMgDl
                                        )
                                    }
                                }

                                sensorNoiseSensitivityRow()
                            }
                        }

                        Section(header: Text(Texts_HomeView.sensorManagementHistoryTitle), footer: calibrationFooter(for: state)) {
                            NavigationLink {
                                CalibrationHistoryView(
                                    currentCalibration: state.currentCalibration,
                                    calibrationHistory: state.calibrationHistory,
                                    isMgDl: isMgDl
                                )
                            } label: {
                                row(title: Texts_HomeView.sensorManagementLastCalibration, data: state.calibrationSummary)
                            }
                            .disabled(!state.hasCalibrationHistory)
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
            }
            .ipadReadableContentWidth(860)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(Texts_HomeView.sensorManagementTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel, action: {
                        self.presentationMode.wrappedValue.dismiss()
                    })
                    .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    OnlineHelpButton(topic: .sensorManagement)
                }
            }
        }
        .colorScheme(.dark)
        .onAppear {
            refreshSensorNoiseSensitivity()
            refreshPersistentNoise()
        }
        .onReceive(timer) { _ in
            refreshView.toggle()
            refreshPersistentNoiseIfSensorChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sensorNoiseHistoryDidChange)) { notification in
            guard notification.object as? String == activeSensorProvider()?.id else { return }
            refreshPersistentNoise(rebuildIfNeeded: false)
        }
        .alert(Texts_HomeView.sensorManagementSessionDetails, isPresented: $showingSensorDetails) {
            Button(Texts_Common.Ok, role: .cancel) {}
        } message: {
            Text(state.sensorDetailsMessage)
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
        .alert(Texts_HomeView.noSensorCodeSelectedTitle, isPresented: $showingNoSensorCodeConfirmation) {
            Button(Texts_Common.Cancel, role: .cancel) {
                pendingStartSensorCode = nil
                pendingStartSensorLabel = nil
            }
            Button(Texts_HomeView.startSensorAnyway) {
                startSensorWithPendingCode()
            }
        } message: {
            Text(Texts_HomeView.noSensorCodeSelectedMessage)
        }
        .sheet(isPresented: $showingStartDateSheet) {
            SensorStartDateView(
                onCancel: {
                    showingStartDateSheet = false
                },
                onStart: { startDate in
                    showingStartDateSheet = false
                    onStartSensor(SensorStartRequest(startDate: startDate))
                    refreshView.toggle()
                }
            )
        }
        .sheet(isPresented: $showingStartCodeSheet) {
            SensorStartCodeView(
                onCancel: {
                    showingStartCodeSheet = false
                },
                onSubmit: submitStartSensorCode
            )
        }
        .sheet(isPresented: $showingCalibrationSheet) {
            CalibrationView(
                canCalibrate: state.canCalibrate,
                shouldWarnOnLargeCalibrationStep: state.shouldWarnOnLargeCalibrationStep,
                currentBgDisplay: state.currentBgDisplay,
                readiness: state.calibrationReadiness,
                isMgDl: isMgDl,
                onSubmitCalibration: onSubmitCalibration,
                onCalibrationSaved: {
                    refreshView.toggle()
                }
            )
        }
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

    /// Keeps the parent Sensor Noise row aligned with the persisted sensitivity.
    private func refreshSensorNoiseSensitivity() {
        sensorNoiseSensitivity = UserDefaults.standard.sensorNoiseSensitivity
    }

    /// Stores the app-wide sensitivity and updates the parent row immediately.
    private func updateSensorNoiseSensitivity(_ sensitivity: SensorNoiseSensitivity) {
        UserDefaults.standard.sensorNoiseSensitivity = sensitivity
        sensorNoiseSensitivity = sensitivity
    }

    /// Keeps the compact 12-hour value aligned with the same persisted history used by Noise History.
    private func refreshPersistentNoise(rebuildIfNeeded: Bool = true) {
        guard let sensor = activeSensorProvider() else {
            persistentNoiseSensorID = nil
            persistentNoise = nil
            return
        }

        persistentNoiseSensorID = sensor.id
        persistentNoise = sensorNoiseManager.historySnapshot(
            sensorID: sensor.id,
            sessionStartDate: sensor.startDate
        )?.persistentNoise

        guard rebuildIfNeeded else { return }

        sensorNoiseManager.rebuildHistoryIfNeeded(sensorID: sensor.id, sessionStartDate: sensor.startDate) {
            guard activeSensorProvider()?.id == sensor.id else { return }
            refreshPersistentNoise(rebuildIfNeeded: false)
        }
    }

    private func refreshPersistentNoiseIfSensorChanged() {
        guard activeSensorProvider()?.id != persistentNoiseSensorID else { return }
        refreshPersistentNoise()
    }

    private func handleStartTap() {
        let state = currentState()

        if state.needsSensorStartTime {
            showingStartDateSheet = true
        } else if state.needsSensorStartCode {
            showingStartCodeSheet = true
        } else {
            onStartSensor(SensorStartRequest(startDate: Date()))
            refreshView.toggle()
        }
    }

    private func submitStartSensorCode(_ codeToSubmit: String, sensorLabel: DexcomG6SensorLabel?) {
        let normalizedCode = codeToSubmit.isEmpty ? "0000" : codeToSubmit

        showingStartCodeSheet = false

        if normalizedCode == "0000" {
            pendingStartSensorCode = normalizedCode
            pendingStartSensorLabel = sensorLabel
            showingNoSensorCodeConfirmation = true
        } else {
            onStartSensor(
                SensorStartRequest(
                    startDate: Date(),
                    requestedSensorCode: normalizedCode,
                    sensorLabel: sensorLabel
                )
            )
            refreshView.toggle()
        }
    }

    private func startSensorWithPendingCode() {
        onStartSensor(
            SensorStartRequest(
                startDate: Date(),
                requestedSensorCode: pendingStartSensorCode ?? "0000",
                sensorLabel: pendingStartSensorLabel
            )
        )
        pendingStartSensorCode = nil
        pendingStartSensorLabel = nil
        refreshView.toggle()
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

    private func statusRow(state: SensorManagementState) -> some View {
        HStack {
            Text(Texts_HomeView.statusActionTitle)
            Spacer()
            HStack(spacing: 8) {
                Circle()
                    .fill(state.statusColor)
                    .frame(width: 10, height: 10)
                Text(state.statusTitle)
                    .foregroundStyle(state.usesNormalStatusTextColor ? Color(.colorSecondary) : state.statusColor)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func row(title: String, data: String, dataColor: Color = ConstantsAppColors.rowDetailText) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(ConstantsAppColors.rowTitleText)
            Spacer()
            Text(data)
                .foregroundStyle(dataColor)
                .multilineTextAlignment(.trailing)
        }
    }

    private func displayEditableBgValue(_ valueInMgDl: Double) -> String {
        valueInMgDl.mgDlToMmolAndToString(mgDl: isMgDl)
    }

    private func sensorDetailsMessage(
        sensorDescription: String,
        startDate: Date?,
        expiryDate: Date?,
        elapsedString: String,
        remainingString: String,
        warmupReadyTimeString: String?,
        sensorInformationRows: [SensorManagementInformationRow]
    ) -> String {
        var detailLines = [
            Texts_HomeView.sensor + ": " + sensorDescription,
            Texts_HomeView.sensorManagementStarted + ": " + (startDate?.toStringInUserLocale(timeStyle: .short, dateStyle: .medium) ?? nilString),
            Texts_HomeView.sensorManagementEnds + ": " + (expiryDate?.toStringInUserLocale(timeStyle: .short, dateStyle: .medium) ?? nilString),
            Texts_HomeView.sensorManagementElapsed + ": " + elapsedString,
            Texts_HomeView.sensorManagementRemaining + ": " + remainingString
        ]

        if let warmupReadyTimeString {
            detailLines.append(Texts_BluetoothPeripheralView.warmingUpUntil + ": " + warmupReadyTimeString)
        }

        if !sensorInformationRows.isEmpty {
            detailLines.append("")
            detailLines.append(contentsOf: sensorInformationRows.map { $0.title + ": " + $0.value })
        }

        return detailLines.joined(separator: "\n")
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
            if transmitter?.cgmTransmitterType() == .dexcomG7 {
                warmupMinutes = ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG7
            } else {
                warmupMinutes = isAnubis ? ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG6Anubis : ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG5G6
            }
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
        let usesNormalStatusTextColor = activeSensor != nil && warmupReadyTimeString == nil && !(remainingMinutes.map { $0 < 0 } ?? false)

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

        let elapsedString = startDate?.daysAndHoursAgo() ?? nilString
        let displayRemainingString = remainingMinutes.map { $0 < 0 ? "-" + abs($0).minutesToDaysAndHours() : $0.minutesToDaysAndHours() } ?? nilString
        let sessionLifetimeString = elapsedString
        let sessionLifetimeColor = Color(.colorSecondary)

        let sensorInformationRows = sensorInformationRows(
            activeSensor: activeSensor,
            isDexcomG6: transmitter?.needsSensorStartCode() == true
        )

        let sensorDetailsMessage = sensorDetailsMessage(
            sensorDescription: sensorDescription,
            startDate: startDate,
            expiryDate: expiryDate,
            elapsedString: elapsedString,
            remainingString: displayRemainingString,
            warmupReadyTimeString: warmupReadyTimeString,
            sensorInformationRows: sensorInformationRows
        )

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

        let lastCalibration = currentCalibration ?? calibrationHistory.first
        let hasCalibrationHistory = lastCalibration != nil || !calibrationHistory.isEmpty
        let calibrationSummary: String
        if let lastCalibration {
            calibrationSummary = lastCalibration.timeStamp.formatted(date: .abbreviated, time: .shortened)
        } else if showCalibrationUnavailableRow {
            calibrationSummary = Texts_Common.notAvailable
        } else {
            calibrationSummary = nilString
        }

        let rawNoiseState = activeSensor.flatMap { SensorNoiseState(rawValue: $0.noiseStateRaw) } ?? .collecting
        let noiseState = ConstantsSensorNoise.displayState(
            rawState: rawNoiseState,
            shortTermNoise: activeSensor?.shortTermNoise?.doubleValue,
            longTermNoise: activeSensor?.longTermNoise?.doubleValue,
            sensitivity: UserDefaults.standard.sensorNoiseSensitivity
        )
        let recentReadings = activeSensor.map {
            bgReadingsAccessor.getLatestBgReadingSnapshots(
                limit: nil,
                fromDate: Date().addingTimeInterval(-CalibrationReadinessConstants.trendLookback),
                forSensor: $0,
                ignoreRawData: true,
                ignoreCalculatedValue: false
            )
        } ?? []
        let calibrationReadiness = CalibrationReadinessEvaluator(now: Date()).evaluate(
            hasActiveSensor: activeSensor != nil,
            recentReadings: recentReadings.map {
                CalibrationReadinessReading(timeStamp: $0.timeStamp, valueInMgDl: $0.finalValue)
            },
            noiseState: noiseState
        )

        return SensorManagementState(
            hasTransmitter: transmitter != nil,
            showsNoise: UserDefaults.standard.isMaster && activeSensor != nil,
            sensorID: activeSensor?.id,
            sensorStartDate: activeSensor?.startDate,
            bannerTitle: sensorDescription,
            statusTitle: statusTitle,
            statusColor: statusColor,
            usesNormalStatusTextColor: usesNormalStatusTextColor,
            sessionLifetimeString: sessionLifetimeString,
            sessionLifetimeColor: sessionLifetimeColor,
            sensorDetailsMessage: sensorDetailsMessage,
            sensorInformationRows: sensorInformationRows,
            startDateString: startDate?.toStringInUserLocale(timeStyle: .short, dateStyle: .short) ?? nilString,
            secondarySessionTitle: secondarySessionTitle,
            secondarySessionValue: secondarySessionValue,
            secondarySessionColor: secondarySessionColor,
            remainingString: displayRemainingString,
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
            calibrationSummary: calibrationSummary,
            hasCalibrationHistory: hasCalibrationHistory,
            shortTermNoise: activeSensor?.shortTermNoise?.doubleValue,
            longTermNoise: activeSensor?.longTermNoise?.doubleValue,
            persistentNoise: activeSensor?.id == persistentNoiseSensorID ? persistentNoise : nil,
            noiseState: noiseState,
            currentBgDisplay: activeSensor.flatMap { bgReadingsAccessor.last(forSensor: $0) }.map {
                SensorManagementEnteredBgValue(rawValue: displayEditableBgValue($0.finalValue), valueInMgDl: $0.finalValue)
            },
            calibrationReadiness: calibrationReadiness,
            currentCalibration: currentCalibration,
            calibrationHistory: calibrationHistory
        )
    }

    private func sensorInformationRows(
        activeSensor: Sensor?,
        isDexcomG6: Bool
    ) -> [SensorManagementInformationRow] {
        guard isDexcomG6, let activeSensor else { return [] }

        let origin = activeSensor.sensorSessionOrigin
        let hasStoredInformation = origin != .unknown
            || activeSensor.requestedSensorCode != nil
            || activeSensor.sensorLabelCode != nil
            || activeSensor.sensorLotNumber != nil
            || activeSensor.sensorSerialNumber != nil
        guard hasStoredInformation else { return [] }

        var rows: [SensorManagementInformationRow] = []
        let activeCode = activeSensor.activeSensorCode

        if let labelCode = activeSensor.sensorLabelCode {
            rows.append(.init(title: Texts_HomeView.scannedSensorLabelCode, value: labelCode))
        } else {
            let displayedCode = activeCode
                ?? (origin == .startRequested ? activeSensor.requestedSensorCode : nil)
            let value: String
            if displayedCode == "0000" {
                value = Texts_HomeView.noCodeSensorSessionValue
            } else {
                value = displayedCode ?? Texts_HomeView.sensorCodeUnknown
            }
            rows.append(.init(title: Texts_HomeView.sensorCode, value: value))
        }

        if let lotNumber = activeSensor.sensorLotNumber {
            rows.append(.init(title: Texts_HomeView.sensorLotNumber, value: lotNumber))
        }

        if let serialNumber = activeSensor.sensorSerialNumber {
            rows.append(.init(title: Texts_HomeView.sensorSerialNumber, value: serialNumber))
        }

        rows.append(.init(title: Texts_HomeView.sensorSessionOrigin, value: sessionOriginText(origin)))
        return rows
    }

    private func sessionOriginText(_ origin: SensorSessionOrigin) -> String {
        switch origin {
        case .unknown: return Texts_HomeView.sensorSessionOriginUnknown
        case .startRequested: return Texts_HomeView.sensorSessionOriginAwaitingTransmitter
        case .startedByApp: return Texts_HomeView.sensorSessionOriginStartedByApp
        case .existingSessionAdopted: return Texts_HomeView.sensorSessionOriginExistingAdopted
        case .transmitterDetected: return Texts_HomeView.sensorSessionOriginTransmitterDetected
        case .startRejected: return Texts_HomeView.sensorSessionOriginRejected
        }
    }

}

// MARK: - sensitivity picker

private struct SensorNoiseSensitivitySelectionView: View {
    @State private var selectedSensitivity: SensorNoiseSensitivity

    private let initialSensitivity: SensorNoiseSensitivity
    let onSelect: (SensorNoiseSensitivity) -> Void
    @Environment(\.dismiss) private var dismiss

    /// Starts the picker on the sensitivity currently stored by the parent view.
    init(selectedSensitivity: SensorNoiseSensitivity, onSelect: @escaping (SensorNoiseSensitivity) -> Void) {
        self.initialSensitivity = selectedSensitivity
        self.onSelect = onSelect
        _selectedSensitivity = State(initialValue: selectedSensitivity)
    }

    var body: some View {
        List {
            Section {
                ForEach(SensorNoiseSensitivity.allCases, id: \.self) { sensitivity in
                    Button {
                        selectedSensitivity = sensitivity
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(Texts_Common.Ok) {
                    onSelect(selectedSensitivity)
                    dismiss()
                }
                .tint(ConstantsAppColors.toolbarAction)
                .disabled(selectedSensitivity == initialSensitivity)
            }
        }
    }
}

/// Complete value presentation derived from the current sensor and transmitter.
private struct SensorManagementState {
    let hasTransmitter: Bool
    let showsNoise: Bool
    let sensorID: String?
    let sensorStartDate: Date?
    let bannerTitle: String
    let statusTitle: String
    let statusColor: Color
    let usesNormalStatusTextColor: Bool
    let sessionLifetimeString: String
    let sessionLifetimeColor: Color
    let sensorDetailsMessage: String
    let sensorInformationRows: [SensorManagementInformationRow]
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
    let calibrationSummary: String
    let hasCalibrationHistory: Bool
    let shortTermNoise: Double?
    let longTermNoise: Double?
    let persistentNoise: Double?
    let noiseState: SensorNoiseState
    let currentBgDisplay: SensorManagementEnteredBgValue?
    let calibrationReadiness: CalibrationReadiness
    let currentCalibration: SensorManagementCalibrationDisplay?
    let calibrationHistory: [SensorManagementCalibrationDisplay]
}

private struct SensorManagementInformationRow: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

/// Presents the optional Dexcom G6 label and session metadata outside the main summary.
private struct SensorInformationView: View {
    let rows: [SensorManagementInformationRow]

    var body: some View {
        List {
            Section {
                ForEach(rows) { informationRow in
                    HStack {
                        Text(informationRow.title)
                            .foregroundStyle(Color(.colorPrimary))

                        Spacer()

                        Text(informationRow.value)
                            .foregroundStyle(Color(.colorSecondary))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .ipadReadableContentWidth(860)
        .navigationTitle(Texts_HomeView.sensorInformationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
