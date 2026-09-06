//
//  SensorStartView.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import PhotosUI
import UIKit

/// Collects the start time for sensor types that do not require a sensor code.
struct SensorStartDateView: View {
    let onCancel: () -> Void
    let onStart: (Date) -> Void

    @State private var selectedStartDate = Date()

    var body: some View {
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
                    Button(Texts_Common.Cancel, action: onCancel)
                        .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Texts_Common.Ok) {
                        UserDefaults.standard.startSensorTimeInfoGiven = true
                        onStart(selectedStartDate)
                    }
                    .tint(ConstantsAppColors.toolbarAction)
                }
            }
        }
        .colorScheme(.dark)
    }
}

/// Collects and validates a Dexcom G6 sensor code before starting the session.
struct SensorStartCodeView: View {
    struct Configuration {
        let title: String
        let message: String
        let codeSectionTitle: String
        let placeholder: String
        let manualEntryMessage: String
        let allowsNoCode: Bool
        let scanner: DexcomSensorLabelScannerConfiguration
        let showsCancelButton: Bool
        let noLabelFoundMessage: String
        let invalidLabelMessage: String

        static let g6 = Configuration(
            title: Texts_HomeView.startSensorActionTitle,
            message: Texts_HomeView.enterSensorCode,
            codeSectionTitle: Texts_HomeView.startSensorActionTitle,
            placeholder: "0000",
            manualEntryMessage: Texts_HomeView.dexcomG6ManualSensorCodeMessage,
            allowsNoCode: true,
            scanner: .g6,
            showsCancelButton: true,
            noLabelFoundMessage: Texts_HomeView.noSensorLabelFound,
            invalidLabelMessage: Texts_HomeView.invalidSensorLabelFound
        )
    }

    let configuration: Configuration
    let onCancel: () -> Void
    let onManualEntry: ((@escaping (String) -> Void) -> Void)?
    let onSubmit: (String, DexcomG6SensorLabel?) -> Void

    @State private var sensorCode: String
    @State private var sensorLabel: DexcomG6SensorLabel?
    @State private var showingManualEntry = false
    @State private var showingCameraScanner = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isDecodingPhoto = false
    @State private var scanErrorMessage: String?
    @State private var hasSubmitted = false

    init(
        configuration: Configuration = .g6,
        initialCode: String = "",
        initialLabel: DexcomG6SensorLabel? = nil,
        onCancel: @escaping () -> Void,
        onManualEntry: ((@escaping (String) -> Void) -> Void)? = nil,
        onSubmit: @escaping (String, DexcomG6SensorLabel?) -> Void
    ) {
        self.configuration = configuration
        self.onCancel = onCancel
        self.onManualEntry = onManualEntry
        self.onSubmit = onSubmit
        _sensorCode = State(initialValue: initialCode)
        _sensorLabel = State(initialValue: initialLabel)
    }

    var body: some View {
        Form {
            Section {
                Text(configuration.message)
                    .foregroundStyle(Color(.colorSecondary))
            }

            Section(header: Text(configuration.codeSectionTitle)) {
                Button {
                    if let onManualEntry {
                        onManualEntry(selectManualCode)
                    } else {
                        showingManualEntry = true
                    }
                } label: {
                    codeEntryActionRow(
                        title: Texts_HomeView.manuallyEnterSensorCode,
                        systemImage: "keyboard"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    DexcomG6SensorLabelScanLogger.requested(source: .camera)
                    showingCameraScanner = true
                } label: {
                    codeEntryActionRow(
                        title: Texts_HomeView.scanWithCamera,
                        systemImage: "barcode.viewfinder"
                    )
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    codeEntryActionRow(
                        title: Texts_HomeView.chooseSensorLabelPhoto,
                        systemImage: "photo"
                    )
                }
                .buttonStyle(.plain)

                if configuration.allowsNoCode {
                    Button {
                        selectManualCode("0000")
                    } label: {
                        codeEntryActionRow(
                            title: Texts_HomeView.useWithoutSensorCode,
                            systemImage: "minus.circle"
                        )
                    }
                    .buttonStyle(.plain)
                }

            }
            .disabled(isDecodingPhoto)

            if isDecodingPhoto {
                Section(header: Text(Texts_HomeView.sensorInformationTitle)) {
                    HStack {
                        ProgressView()
                        Text(Texts_HomeView.readingSensorLabel)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                }
            } else if let sensorLabel {
                sensorLabelInformationSection(sensorLabel)
            } else if isSensorCodeValid {
                Section {
                    sensorLabelRow(
                        title: Texts_HomeView.sensorCode,
                        value: configuration.allowsNoCode && sensorCode == "0000"
                            ? Texts_HomeView.noSensorCode : sensorCode,
                        showsValidCode: isSensorCodeValid
                    )
                } footer: {
                    Text(Texts_HomeView.sensorLabelReviewFooter)
                }
            }

        }
        .navigationTitle(configuration.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if configuration.showsCancelButton {
                    Button(Texts_Common.Cancel, action: onCancel)
                        .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(Texts_HomeView.sensorCodeContinue) {
                    submit(sensorCode.trimmingCharacters(in: .whitespacesAndNewlines), label: sensorLabel)
                }
                .tint(ConstantsAppColors.toolbarAction)
                .disabled(!isSensorCodeValid || isDecodingPhoto || hasSubmitted)
            }
        }
        .colorScheme(.dark)
        .onAppear {
            // G7 setup keeps this review screen in the navigation path. Returning from the
            // next step must allow the reviewed selection to be confirmed again.
            hasSubmitted = false
        }
        .navigationDestination(isPresented: $showingManualEntry) {
            SensorManualCodeEntryView(
                title: configuration.title,
                message: configuration.manualEntryMessage,
                placeholder: configuration.placeholder,
                onSelect: { code in
                    selectManualCode(code)
                    showingManualEntry = false
                }
            )
        }
        .onChange(of: sensorCode) { newValue in
            guard let sensorLabel,
                  newValue.trimmingCharacters(in: .whitespacesAndNewlines) != sensorLabel.sensorCode else {
                return
            }
            self.sensorLabel = nil
        }
        .onChange(of: selectedPhoto) { newPhoto in
            guard let newPhoto else { return }
            DexcomG6SensorLabelScanLogger.requested(source: .photo)
            decode(photo: newPhoto)
        }
        .fullScreenCover(isPresented: $showingCameraScanner) {
            DexcomG6CameraScannerView(onScan: { label in
                apply(label: label)
                showingCameraScanner = false
            }, configuration: configuration.scanner)
        }
        .alert(Texts_HomeView.sensorLabelScanFailed, isPresented: Binding(
            get: { scanErrorMessage != nil },
            set: { if !$0 { scanErrorMessage = nil } }
        )) {
            Button(Texts_Common.Ok, role: .cancel) {}
        } message: {
            Text(scanErrorMessage ?? "")
        }
    }

    private var isSensorCodeValid: Bool {
        let trimmedCode = sensorCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return isFourDigitSensorCode(trimmedCode)
    }

    private func selectManualCode(_ code: String) {
        sensorLabel = nil
        sensorCode = code
    }

    private func isFourDigitSensorCode(_ code: String) -> Bool {
        code.count == 4 && code.utf8.allSatisfy { (48...57).contains($0) }
    }

    private func submit(_ code: String, label: DexcomG6SensorLabel?) {
        guard !hasSubmitted else { return }
        hasSubmitted = true
        onSubmit(code, label)
    }

    private func codeEntryActionRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ConstantsUI.disclosureIndicatorColor)
        }
        .foregroundStyle(ConstantsAppColors.rowTitleText)
        .contentShape(Rectangle())
    }

    private func sensorLabelRow(title: String, value: String, showsValidCode: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(Color(.colorPrimary))
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                if showsValidCode {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.green)
                        .accessibilityHidden(true)
                }
                Text(value)
                    .foregroundStyle(Color(.colorSecondary))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func sensorLabelInformationSection(_ label: DexcomG6SensorLabel) -> some View {
        Section {
            sensorLabelRow(title: Texts_HomeView.sensorCode, value: label.sensorCode, showsValidCode: isFourDigitSensorCode(label.sensorCode))
            if !label.lotNumber.isEmpty {
                sensorLabelRow(title: Texts_HomeView.sensorLotNumber, value: label.lotNumber)
            }
            sensorLabelRow(title: Texts_HomeView.sensorSerialNumber, value: label.serialNumber)
            if let manufactureDate = label.manufactureDate {
                // Applicator dates are calendar values rather than moments in time. The parser stores them at
                // midnight UTC, so format them in UTC to prevent US time zones from showing the previous day.
                sensorLabelRow(title: Texts_HomeView.sensorManufactureDate, value: manufactureDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short, timeZone: TimeZone(secondsFromGMT: 0)))
            }
            if let expirationDate = label.expirationDate {
                sensorLabelRow(title: Texts_HomeView.sensorExpirationDate, value: expirationDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short, timeZone: TimeZone(secondsFromGMT: 0)))
            }
        } header: {
            Text(Texts_HomeView.sensorInformationTitle)
        } footer: {
            Text(Texts_HomeView.sensorLabelReviewFooter)
        }
    }

    private func apply(label: DexcomG6SensorLabel) {
        sensorLabel = label
        sensorCode = label.sensorCode
    }

    private func decode(photo: PhotosPickerItem) {
        isDecodingPhoto = true

        Task {
            defer {
                isDecodingPhoto = false
                selectedPhoto = nil
            }

            do {
                guard let data = try await photo.loadTransferable(type: Data.self) else {
                    throw DexcomG6SensorLabelImageDecoderError.unreadableImage
                }
                DexcomG6SensorLabelScanLogger.photoLoaded(byteCount: data.count)
                let label = try await Task.detached(priority: .userInitiated) {
                    try DexcomG6SensorLabelImageDecoder.decode(data, configuration: configuration.scanner)
                }.value
                DexcomG6SensorLabelScanLogger.succeeded(source: .photo, label: label)
                apply(label: label)
            } catch DexcomG6SensorLabelImageDecoderError.multipleValidLabels {
                DexcomG6SensorLabelScanLogger.failed(source: .photo, reason: .multipleValidLabels)
                scanErrorMessage = Texts_HomeView.multipleSensorLabelsFound
            } catch DexcomG6SensorLabelImageDecoderError.noValidLabel {
                DexcomG6SensorLabelScanLogger.failed(source: .photo, reason: .noValidLabel)
                scanErrorMessage = configuration.noLabelFoundMessage
            } catch DexcomG6SensorLabelImageDecoderError.malformedLabel {
                DexcomG6SensorLabelScanLogger.failed(source: .photo, reason: .malformedLabel)
                scanErrorMessage = configuration.invalidLabelMessage
            } catch {
                DexcomG6SensorLabelScanLogger.failed(source: .photo, reason: .unreadableImage)
                scanErrorMessage = Texts_HomeView.sensorLabelPhotoUnreadable
            }
        }
    }
}

/// Large four-digit entry screen shared by Dexcom G6 calibration codes and G7 pairing codes.
struct SensorManualCodeEntryView: View {
    let title: String
    let message: String
    let placeholder: String
    let onSelect: (String) -> Void

    @State private var code = ""
    @State private var isValidated = false
    @State private var submissionTask: Task<Void, Never>?
    @FocusState private var codeFieldIsFocused: Bool

    var body: some View {
        Form {
            Section {
                Text(message)
                    .foregroundStyle(Color(.colorSecondary))
            }

            Section {
                HStack(spacing: 12) {
                    TextField(
                        title,
                        text: $code,
                        prompt: Text(placeholder)
                            .foregroundColor(Color(.secondaryLabel))
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .tracking(8)
                    .padding(.leading, 8)
                    .padding(.vertical, 8)
                    .focused($codeFieldIsFocused)
                    .accessibilityLabel(Texts_HomeView.manuallyEnterSensorCode)
                    .disabled(isValidated)
                    .onChange(of: code, perform: codeChanged)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isValidated ? Color.green : Color(.colorTertiary))
                        .animation(.easeInOut(duration: 0.2), value: isValidated)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            codeFieldIsFocused = true
        }
        .onDisappear {
            submissionTask?.cancel()
        }
    }

    private func codeChanged(_ enteredCode: String) {
        let digitsOnly = String(enteredCode.filter { ("0"..."9").contains(String($0)) }.prefix(4))
        if code != digitsOnly {
            code = digitsOnly
            return
        }

        guard digitsOnly.count == 4, !isValidated else { return }
        isValidated = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        submissionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            onSelect(digitsOnly)
        }
    }
}
