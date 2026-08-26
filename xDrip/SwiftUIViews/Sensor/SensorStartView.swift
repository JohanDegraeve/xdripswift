//
//  SensorStartView.swift
//  xdrip
//
//  Created by Paul Plant on 27/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import PhotosUI

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
    let onCancel: () -> Void
    let onSubmit: (String, DexcomG6SensorLabel?) -> Void

    @State private var sensorCode = ""
    @State private var sensorLabel: DexcomG6SensorLabel?
    @State private var showingCameraScanner = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isDecodingPhoto = false
    @State private var scanErrorMessage: String?

    var body: some View {
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

                Section {
                    Button {
                        DexcomG6SensorLabelScanLogger.requested(source: .camera)
                        showingCameraScanner = true
                    } label: {
                        Label(Texts_HomeView.scanWithCamera, systemImage: "barcode.viewfinder")
                    }
                    .foregroundStyle(ConstantsAppColors.toolbarAction)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(Texts_HomeView.chooseSensorLabelPhoto, systemImage: "photo")
                    }
                    .foregroundStyle(ConstantsAppColors.toolbarAction)

                    if isDecodingPhoto {
                        HStack {
                            ProgressView()
                            Text(Texts_HomeView.readingSensorLabel)
                                .foregroundStyle(Color(.colorSecondary))
                        }
                    }
                }

                if let sensorLabel {
                    sensorLabelInformationSection(sensorLabel)
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
                        onSubmit(sensorCode.trimmingCharacters(in: .whitespacesAndNewlines), sensorLabel)
                    }
                    .tint(ConstantsAppColors.toolbarAction)
                    .disabled(!isSensorCodeValid)
                }
            }
        }
        .colorScheme(.dark)
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
            DexcomG6CameraScannerView { label in
                apply(label: label)
                showingCameraScanner = false
            }
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
        return trimmedCode.isEmpty
            || (trimmedCode.count == 4 && trimmedCode.utf8.allSatisfy { (48...57).contains($0) })
    }

    private func sensorLabelRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color(.colorPrimary))
            Spacer()
            Text(value)
                .foregroundStyle(Color(.colorSecondary))
                .multilineTextAlignment(.trailing)
        }
    }

    private func sensorLabelInformationSection(_ label: DexcomG6SensorLabel) -> some View {
        Section {
            sensorLabelRow(title: Texts_HomeView.sensorLotNumber, value: label.lotNumber)
            sensorLabelRow(title: Texts_HomeView.sensorSerialNumber, value: label.serialNumber)
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
                    try DexcomG6SensorLabelImageDecoder.decode(data)
                }.value
                DexcomG6SensorLabelScanLogger.succeeded(source: .photo, label: label)
                apply(label: label)
            } catch DexcomG6SensorLabelImageDecoderError.multipleValidLabels {
                DexcomG6SensorLabelScanLogger.failed(source: .photo, reason: .multipleValidLabels)
                scanErrorMessage = Texts_HomeView.multipleSensorLabelsFound
            } catch DexcomG6SensorLabelImageDecoderError.noValidLabel {
                DexcomG6SensorLabelScanLogger.failed(source: .photo, reason: .noValidLabel)
                scanErrorMessage = Texts_HomeView.noSensorLabelFound
            } catch DexcomG6SensorLabelImageDecoderError.malformedLabel {
                DexcomG6SensorLabelScanLogger.failed(source: .photo, reason: .malformedLabel)
                scanErrorMessage = Texts_HomeView.invalidSensorLabelFound
            } catch {
                DexcomG6SensorLabelScanLogger.failed(source: .photo, reason: .unreadableImage)
                scanErrorMessage = Texts_HomeView.sensorLabelPhotoUnreadable
            }
        }
    }
}
