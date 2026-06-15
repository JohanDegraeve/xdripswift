//
//  SensorManagementView.swift
//  xdrip
//
//  Created by Paul Plant on 15/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct SensorManagementView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    let activeSensorProvider: () -> Sensor?
    let transmitterProvider: () -> CGMTransmitter?
    let calibrationsAccessor: CalibrationsAccessor
    let bgReadingsAccessor: BgReadingsAccessor
    let onStartSensor: (Date, String?) -> Void
    let onStopSensor: () -> Void
    let onSubmitCalibration: (Double) -> String?

    @State private var refreshView = false
    @State private var showingStartDateSheet = false
    @State private var showingStartCodeSheet = false
    @State private var showingCalibrationSheet = false
    @State private var showingStopConfirmation = false
    @State private var transientMessage: SensorManagementMessage?
    @State private var selectedStartDate = Date()
    @State private var sensorCode = "0000"
    @State private var calibrationValue = ""

    private let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let nilString = "-"

    var body: some View {
        let state = currentState()

        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(state.sensorDescription)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text(state.statusTitle)
                                    .font(.headline)
                                    .foregroundStyle(state.statusColor)
                            }

                            Spacer()

                            Image(systemName: "sensor.tag.radiowaves.forward")
                                .font(.title2)
                                .foregroundStyle(state.statusColor)
                        }

                        if let warmupUntil = state.warmupUntil {
                            Text(warmupUntil)
                                .font(.subheadline)
                                .foregroundStyle(Color(.colorSecondary))
                        }
                    }
                    .padding(.vertical, 4)
                    .id(refreshView)
                }

                Section(header: Text(Texts_HomeView.sensorManagementSummaryTitle)) {
                    row(title: Texts_HomeView.sensorManagementSensorType, data: state.sensorDescription)
                    row(title: Texts_HomeView.sensorManagementStartedAt, data: state.startDateString)
                    row(title: Texts_HomeView.sensorManagementElapsed, data: state.elapsedString)
                    row(title: Texts_HomeView.sensorManagementRemaining, data: state.remainingString)
                    row(title: Texts_HomeView.sensorManagementAlgorithm, data: state.algorithmDescription)
                    row(title: Texts_HomeView.sensorManagementCalibrationMode, data: state.calibrationModeDescription)
                    if let transmitterBattery = state.transmitterBattery {
                        row(title: Texts_HomeView.transmitterBatteryLevel, data: transmitterBattery)
                    }
                }

                Section(header: Text(Texts_HomeView.sensorManagementActionsTitle), footer: actionFooter(for: state)) {
                    Button(action: handleStartTap) {
                        Text(Texts_HomeView.startSensorActionTitle)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!state.canStartSensor)
                    .foregroundStyle(state.canStartSensor ? Color.green : Color(.systemGray))

                    Button(role: .destructive, action: {
                        showingStopConfirmation = true
                    }) {
                        Text(Texts_HomeView.stopSensorActionTitle)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!state.canStopSensor)
                    .foregroundStyle(state.canStopSensor ? Color.red : Color(.systemGray))
                }

                Section(header: Text(Texts_HomeView.sensorManagementCalibrationTitle), footer: calibrationFooter(for: state)) {
                    Button(action: {
                        calibrationValue = ""
                        showingCalibrationSheet = true
                    }) {
                        Text(Texts_HomeView.calibrationButton)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!state.canCalibrate)

                    if let currentCalibration = state.currentCalibration {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Texts_HomeView.sensorManagementCurrentCalibrationTitle)
                                .font(.headline)
                            calibrationSummaryView(calibration: currentCalibration, isHistoric: false)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text(Texts_HomeView.sensorManagementNoCalibrationYet)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }

                Section(header: Text(Texts_HomeView.sensorManagementHistoryTitle)) {
                    if state.calibrationHistory.isEmpty {
                        Text(Texts_HomeView.sensorManagementNoCalibrationHistory)
                            .foregroundStyle(Color(.colorSecondary))
                    } else {
                        ForEach(state.calibrationHistory, id: \.id) { calibration in
                            calibrationSummaryView(calibration: calibration, isHistoric: !calibration.isValid)
                        }
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
            calibrationSheet
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
                        Texts_HomeView.sensorManagementStartedAt,
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

    private var calibrationSheet: some View {
        NavigationView {
            Form {
                Section(header: Text(Texts_Calibrations.enterCalibrationValue)) {
                    TextField("...", text: $calibrationValue)
                        .keyboardType(isMgDl ? .numberPad : .decimalPad)
                }
            }
            .navigationTitle(Texts_HomeView.calibrationButton)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) {
                        showingCalibrationSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_Common.Ok) {
                        guard let valueAsDouble = calibrationValue.toDouble() else {
                            transientMessage = SensorManagementMessage(title: Texts_Common.warning, message: Texts_Common.invalidValue)
                            return
                        }

                        if let errorMessage = onSubmitCalibration(valueAsDouble) {
                            transientMessage = SensorManagementMessage(title: Texts_Common.warning, message: errorMessage)
                        } else {
                            showingCalibrationSheet = false
                            refreshView.toggle()
                        }
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

    private func actionFooter(for state: SensorManagementState) -> some View {
        Group {
            if let actionNote = state.sensorActionNote {
                Text(actionNote)
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

    private func calibrationSummaryView(calibration: SensorManagementCalibrationDisplay, isHistoric: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(calibration.timeStamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if isHistoric {
                    Text(Texts_HomeView.sensorManagementHistoricCalibration)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }
            }

            HStack {
                Text("BG")
                Spacer()
                Text(displayBgValue(calibration.bg))
                    .foregroundStyle(isHistoric ? Color(.systemGray) : Color(.colorSecondary))
            }

            HStack {
                Text("Raw")
                Spacer()
                Text(calibration.rawValue.bgValueToString(mgDl: true) + " " + Texts_Common.mgdl)
                    .foregroundStyle(isHistoric ? Color(.systemGray) : Color(.colorSecondary))
            }

            HStack {
                Text("Slope")
                Spacer()
                Text(calibration.slope.formatted(.number.rounded(increment: 0.0001)))
                    .foregroundStyle(isHistoric ? Color(.systemGray) : Color(.colorSecondary))
            }

            HStack {
                Text("Intercept")
                Spacer()
                Text(calibration.intercept.formatted(.number.rounded(increment: 0.0001)))
                    .foregroundStyle(isHistoric ? Color(.systemGray) : Color(.colorSecondary))
            }

            if let sentToTransmitter = calibration.sentToTransmitter, sentToTransmitter || calibration.acceptedByTransmitter == true {
                HStack {
                    Text("Transmitter Sync")
                    Spacer()
                    Text(calibration.acceptedByTransmitter == true ? "Accepted" : "Queued")
                        .foregroundStyle(isHistoric ? Color(.systemGray) : Color(.colorSecondary))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func row(title: String, data: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(data)
                .foregroundStyle(Color(.colorSecondary))
                .multilineTextAlignment(.trailing)
        }
    }

    private func displayBgValue(_ valueInMgDl: Double) -> String {
        valueInMgDl.mgDlToMmol(mgDl: isMgDl).bgValueRounded(mgDl: isMgDl).bgValueToString(mgDl: isMgDl) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }

    private func currentState() -> SensorManagementState {
        let transmitter = transmitterProvider()
        let activeSensor = activeSensorProvider()
        let sensorDescription = UserDefaults.standard.activeSensorDescription ?? activeSensor.map { _ in Texts_HomeView.sensor } ?? Texts_HomeView.notStarted
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
        case .none:
            warmupMinutes = nil
        }

        let elapsedMinutes = startDate.map { Double(Calendar.current.dateComponents([.minute], from: $0, to: Date()).minute ?? 0) }
        let remainingMinutes = (elapsedMinutes != nil && maxSensorAgeInDays > 0) ? ((maxSensorAgeInDays * 24 * 60) - (elapsedMinutes ?? 0)) : nil

        let warmupUntil: String?
        if let startDate = startDate, let warmupMinutes = warmupMinutes, let elapsedMinutes = elapsedMinutes, elapsedMinutes < warmupMinutes {
            let readyDate = startDate.addingTimeInterval(TimeInterval(minutes: warmupMinutes))
            warmupUntil = Texts_BluetoothPeripheralView.warmingUpUntil + " " + readyDate.toStringInUserLocale(timeStyle: .short, dateStyle: .none)
        } else {
            warmupUntil = nil
        }

        let statusTitle: String
        let statusColor: Color

        if activeSensor == nil {
            statusTitle = Texts_HomeView.sensorManagementStatusNotStarted
            statusColor = Color(.systemGray)
        } else if warmupUntil != nil {
            statusTitle = Texts_HomeView.sensorManagementStatusWarmingUp
            statusColor = Color.orange
        } else if let remainingMinutes = remainingMinutes, remainingMinutes < 0 {
            statusTitle = Texts_HomeView.sensorManagementStatusExpired
            statusColor = Color.red
        } else {
            statusTitle = Texts_HomeView.sensorManagementStatusActive
            statusColor = Color.green
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

        let currentCalibration = activeSensor.flatMap { calibrationsAccessor.lastCalibrationForActiveSensor(withActivesensor: $0) }.map(SensorManagementCalibrationDisplay.init)
        let calibrationHistory = activeSensor.map { sensor in
            calibrationsAccessor.getLatestCalibrations(howManyDays: 4, forSensor: sensor).map(SensorManagementCalibrationDisplay.init)
        } ?? []

        let firstCalibration = activeSensor.flatMap { calibrationsAccessor.firstCalibrationForActiveSensor(withActivesensor: $0) }
        let calibrationNote: String?
        let canCalibrate: Bool

        if !UserDefaults.standard.isMaster {
            canCalibrate = false
            calibrationNote = Texts_HomeView.sensorManagementNotAvailableInFollower
        } else if transmitter == nil {
            canCalibrate = false
            calibrationNote = Texts_HomeView.theresNoCGMTransmitterActive
        } else if activeSensor == nil {
            canCalibrate = false
            calibrationNote = Texts_HomeView.startSensorBeforeCalibration
        } else if transmitter?.isWebOOPEnabled() == true && transmitter?.overruleIsWebOOPEnabled() == false {
            canCalibrate = false
            calibrationNote = Texts_HomeView.calibrationNotNecessary
        } else if firstCalibration == nil && transmitter?.overruleIsWebOOPEnabled() == false {
            let readingCount = bgReadingsAccessor.getLatestBgReadings(limit: 36, howOld: nil, forSensor: activeSensor, ignoreRawData: false, ignoreCalculatedValue: true, includingSuppressed: true).count
            canCalibrate = false
            calibrationNote = readingCount > 1 ? Texts_Calibrations.calibrationNotificationRequestBody : Texts_HomeView.thereMustBeAreadingBeforeCalibration
        } else {
            canCalibrate = true
            calibrationNote = nil
        }

        return SensorManagementState(
            sensorDescription: sensorDescription,
            statusTitle: statusTitle,
            statusColor: statusColor,
            startDateString: startDate?.toStringInUserLocale(timeStyle: .short, dateStyle: .short, showTimeZone: true) ?? nilString,
            elapsedString: startDate?.daysAndHoursAgo() ?? nilString,
            remainingString: remainingMinutes.map { $0 < 0 ? "-" + abs($0).minutesToDaysAndHours() : $0.minutesToDaysAndHours() } ?? nilString,
            warmupUntil: warmupUntil,
            algorithmDescription: transmitter?.isWebOOPEnabled() == true ? Texts_HomeView.sensorManagementNativeAlgorithm : Texts_HomeView.sensorManagementXdripAlgorithm,
            calibrationModeDescription: transmitter?.isNonFixedSlopeEnabled() == true ? Texts_Calibrations.multiPointCalibration : Texts_Calibrations.singlePointCalibration,
            transmitterBattery: UserDefaults.standard.transmitterBatteryInfo?.description,
            canStartSensor: canManageSensor && activeSensor == nil,
            canStopSensor: canManageSensor && activeSensor != nil,
            needsSensorStartTime: transmitter?.needsSensorStartTime() ?? false,
            needsSensorStartCode: transmitter?.needsSensorStartCode() ?? false,
            sensorActionNote: sensorActionNote,
            canCalibrate: canCalibrate,
            calibrationNote: calibrationNote,
            currentCalibration: currentCalibration,
            calibrationHistory: calibrationHistory
        )
    }
}

private struct SensorManagementState {
    let sensorDescription: String
    let statusTitle: String
    let statusColor: Color
    let startDateString: String
    let elapsedString: String
    let remainingString: String
    let warmupUntil: String?
    let algorithmDescription: String
    let calibrationModeDescription: String
    let transmitterBattery: String?
    let canStartSensor: Bool
    let canStopSensor: Bool
    let needsSensorStartTime: Bool
    let needsSensorStartCode: Bool
    let sensorActionNote: String?
    let canCalibrate: Bool
    let calibrationNote: String?
    let currentCalibration: SensorManagementCalibrationDisplay?
    let calibrationHistory: [SensorManagementCalibrationDisplay]
}

private struct SensorManagementCalibrationDisplay {
    let id: String
    let timeStamp: Date
    let slope: Double
    let intercept: Double
    let bg: Double
    let rawValue: Double
    let isValid: Bool
    let sentToTransmitter: Bool?
    let acceptedByTransmitter: Bool?

    init(_ calibration: Calibration) {
        id = calibration.id
        timeStamp = calibration.timeStamp
        slope = calibration.slope
        intercept = calibration.intercept
        bg = calibration.bg
        rawValue = calibration.rawValue
        isValid = calibration.sensorConfidence != 0 && calibration.slopeConfidence != 0
        sentToTransmitter = calibration.sentToTransmitter
        acceptedByTransmitter = calibration.acceptedByTransmitter
    }
}

private struct SensorManagementMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
