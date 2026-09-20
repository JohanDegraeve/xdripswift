//
//  SensorCodeScannerView.swift
//  xdrip
//
//  Created by Paul Plant on 26/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import AVFoundation
import os.log
import PhotosUI
import SwiftUI
import UIKit
import Vision

// MARK: - photo decoder

enum DexcomG6SensorLabelImageDecoderError: Error {
    case unreadableImage
    case noValidLabel
    case malformedLabel
    case multipleValidLabels
}

enum DexcomG6SensorLabelImageDecoder {
    static func decode(
        _ data: Data,
        configuration: DexcomSensorLabelScannerConfiguration = .g6
    ) throws -> DexcomG6SensorLabel {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.dataMatrix]

        do {
            try VNImageRequestHandler(data: data).perform([request])
        } catch {
            throw DexcomG6SensorLabelImageDecoderError.unreadableImage
        }

        let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
        guard !payloads.isEmpty else {
            throw DexcomG6SensorLabelImageDecoderError.noValidLabel
        }

        let decodedLabels: [DexcomG6SensorLabel] = payloads.compactMap { payload in
            return try? configuration.parse(payload)
        }
        let labels = Set(decodedLabels)

        guard !labels.isEmpty else {
            throw DexcomG6SensorLabelImageDecoderError.malformedLabel
        }
        guard labels.count == 1, let label = labels.first else {
            throw DexcomG6SensorLabelImageDecoderError.multipleValidLabels
        }
        return label
    }
}

// MARK: - scan logging

/// Writes sensor-label scan diagnostics to the developer trace and Activity Log.
enum DexcomG6SensorLabelScanLogger {
    private static let log = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categoryApplicationDataSensors
    )

    static func requested(source: TroubleshootingSensorLabelScanSource) {
        trace(
            "in sensorLabelScan, source = %{public}@, scan requested",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .info,
            source.rawValue
        )
    }

    static func cameraSessionStarted() {
        trace(
            "in sensorLabelScan, camera session started",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .info
        )
    }

    static func cameraRead(dataMatrixCount: Int) {
        trace(
            "in sensorLabelScan, camera read %{public}@ Data Matrix code(s)",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .info,
            String(dataMatrixCount)
        )
    }

    static func photoLoaded(byteCount: Int) {
        trace(
            "in sensorLabelScan, selected photo loaded, byte count = %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .info,
            String(byteCount)
        )
    }

    static func malformedCameraRead(_ error: Error) {
        trace(
            "in sensorLabelScan, camera read could not be decoded, reason = %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .error,
            troubleshooting: .standard(.sensorLabelScan(.failed(source: .camera, reason: .malformedLabel))),
            String(describing: error)
        )
    }

    static func multipleCameraLabelsRead() {
        trace(
            "in sensorLabelScan, camera read contained multiple valid Dexcom sensor labels",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .error,
            troubleshooting: .standard(.sensorLabelScan(.failed(source: .camera, reason: .multipleValidLabels)))
        )
    }

    static func succeeded(source: TroubleshootingSensorLabelScanSource, label: DexcomG6SensorLabel) {
        // Keep every value that was decoded from the label in the developer trace. G6 labels
        // normally provide the code, lot and serial number. G7-family labels also provide the
        // product identifier, manufacture date and package expiry date. Recording the complete
        // decoded result makes it possible to compare a tester's scan with the human-readable
        // applicator text without needing another photograph or access to the saved Core Data row.
        // The date-only formatter deliberately uses UTC so the logged calendar day cannot change
        // when the tester is in a time zone west of UTC.
        trace(
            "in sensorLabelScan, source = %{public}@, decoded sensor code = %{public}@, lot = %{public}@, serial = %{public}@, product identifier = %{public}@, manufacture date = %{public}@, expiry date = %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .info,
            troubleshooting: .standard(.sensorLabelScan(.succeeded(
                source: source,
                sensorCode: label.sensorCode,
                lotNumber: label.lotNumber,
                serialNumber: label.serialNumber
            ))),
            source.rawValue,
            label.sensorCode,
            label.lotNumber.isEmpty ? "nil" : label.lotNumber,
            label.serialNumber,
            label.productIdentifier ?? "nil",
            label.manufactureDate?.toDateOnlyStringForTrace() ?? "nil",
            label.expirationDate?.toDateOnlyStringForTrace() ?? "nil"
        )
    }

    static func failed(source: TroubleshootingSensorLabelScanSource, reason: TroubleshootingSensorLabelScanFailure) {
        trace(
            "in sensorLabelScan, source = %{public}@, scan failed, reason = %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .error,
            troubleshooting: .standard(.sensorLabelScan(.failed(source: source, reason: reason))),
            source.rawValue,
            reason.rawValue
        )
    }
}

// MARK: - camera scanner

private enum DexcomG6CameraScannerError: Identifiable {
    case permissionDenied
    case unavailable

    var id: Int {
        switch self {
        case .permissionDenied: return 0
        case .unavailable: return 1
        }
    }
}

struct DexcomG6CameraScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let onScan: (DexcomG6SensorLabel) -> Void
    var configuration: DexcomSensorLabelScannerConfiguration = .g6

    @State private var scannerError: DexcomG6CameraScannerError?
    @State private var isTorchAvailable = false
    @State private var isTorchOn = false
    @State private var scanSucceeded = false

    var body: some View {
        NavigationView {
            ZStack {
                DexcomG6CameraScannerRepresentable(
                    isTorchOn: isTorchOn,
                    configuration: configuration,
                    onScan: { label in
                        scanSucceeded = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onScan(label)
                            dismiss()
                        }
                    },
                    onError: { error in
                        switch error {
                        case .permissionDenied:
                            DexcomG6SensorLabelScanLogger.failed(
                                source: .camera,
                                reason: .cameraPermissionDenied
                            )
                        case .unavailable:
                            DexcomG6SensorLabelScanLogger.failed(
                                source: .camera,
                                reason: .cameraUnavailable
                            )
                        }
                        scannerError = error
                    },
                    onTorchAvailabilityChanged: { isAvailable in
                        isTorchAvailable = isAvailable
                        if !isAvailable {
                            isTorchOn = false
                        }
                    }
                )
                .ignoresSafeArea()

                GeometryReader { proxy in
                    ScannerMaskShape(scanSize: 150)
                        .fill(.black.opacity(0.4), style: FillStyle(eoFill: true))

                    VStack(spacing: 16) {
                        ScannerCornerShape(cornerLength: 22)
                            .stroke(
                                scanSucceeded ? Color.green : Color.white,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                            )
                            .frame(width: 150, height: 150)

                        Label(Texts_HomeView.sensorCodeScannerGuidance, systemImage: "barcode.viewfinder")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))

                        if isTorchAvailable {
                            Button {
                                isTorchOn.toggle()
                            } label: {
                                Label(
                                    Texts_HomeView.sensorCodeScannerTorch,
                                    systemImage: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill"
                                )
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    isTorchOn ? Color.white : Color.black.opacity(0.72),
                                    in: Capsule()
                                )
                                .foregroundStyle(isTorchOn ? Color.black : Color.white)
                            }
                            .accessibilityValue(isTorchOn ? Texts_Common.on : Texts_Common.off)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 24)
                    .offset(y: proxy.size.height / 2 - 75)
                }
                .ignoresSafeArea()
            }
            .background(Color.black)
            .navigationTitle(Texts_HomeView.scanSensorLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(Texts_Common.Cancel) { dismiss() }
                        .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                }
            }
        }
        .colorScheme(.dark)
        .alert(item: $scannerError) { error in
            switch error {
            case .permissionDenied:
                return Alert(
                    title: Text(Texts_HomeView.cameraAccessRequired),
                    message: Text(Texts_HomeView.cameraAccessRequiredMessage),
                    primaryButton: .default(Text(Texts_HomeView.openSettings)) {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(settingsURL)
                        dismiss()
                    },
                    secondaryButton: .cancel { dismiss() }
                )
            case .unavailable:
                return Alert(
                    title: Text(Texts_HomeView.cameraUnavailable),
                    message: Text(Texts_HomeView.cameraUnavailableMessage),
                    dismissButton: .default(Text(Texts_Common.Ok)) { dismiss() }
                )
            }
        }
    }
}

private struct DexcomG6CameraScannerRepresentable: UIViewRepresentable {
    let isTorchOn: Bool
    let configuration: DexcomSensorLabelScannerConfiguration
    let onScan: (DexcomG6SensorLabel) -> Void
    let onError: (DexcomG6CameraScannerError) -> Void
    let onTorchAvailabilityChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            configuration: configuration,
            onScan: onScan,
            onError: onError,
            onTorchAvailabilityChanged: onTorchAvailabilityChanged
        )
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = context.coordinator.captureSession
        context.coordinator.start()
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.updateVideoOrientation()
        context.coordinator.setTorch(isTorchOn)
    }

    static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let captureSession = AVCaptureSession()

        private let sessionQueue = DispatchQueue(label: "com.xdripswift.dexcom-label-scanner")
        private let configuration: DexcomSensorLabelScannerConfiguration
        private let onScan: (DexcomG6SensorLabel) -> Void
        private let onError: (DexcomG6CameraScannerError) -> Void
        private let onTorchAvailabilityChanged: (Bool) -> Void
        private var camera: AVCaptureDevice?
        private var isConfigured = false
        private var hasDeliveredResult = false
        private var hasReportedCameraRead = false
        private var hasReportedMalformedLabel = false
        private var hasReportedMultipleLabels = false

        init(
            configuration: DexcomSensorLabelScannerConfiguration,
            onScan: @escaping (DexcomG6SensorLabel) -> Void,
            onError: @escaping (DexcomG6CameraScannerError) -> Void,
            onTorchAvailabilityChanged: @escaping (Bool) -> Void
        ) {
            self.configuration = configuration
            self.onScan = onScan
            self.onError = onError
            self.onTorchAvailabilityChanged = onTorchAvailabilityChanged
        }

        func start() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                configureAndStart()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard let self else { return }
                    granted ? self.configureAndStart() : self.report(.permissionDenied)
                }
            case .denied, .restricted:
                report(.permissionDenied)
            @unknown default:
                report(.unavailable)
            }
        }

        func stop() {
            sessionQueue.async { [weak self] in
                guard let self else { return }
                self.updateTorch(enabled: false)
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                }
            }
        }

        func setTorch(_ enabled: Bool) {
            sessionQueue.async { [weak self] in
                self?.updateTorch(enabled: enabled)
            }
        }

        private func configureAndStart() {
            sessionQueue.async { [weak self] in
                guard let self else { return }

                if !self.isConfigured {
                    guard let camera = AVCaptureDevice.default(for: .video),
                          let input = try? AVCaptureDeviceInput(device: camera),
                          self.captureSession.canAddInput(input) else {
                        self.report(.unavailable)
                        return
                    }

                    let output = AVCaptureMetadataOutput()
                    guard self.captureSession.canAddOutput(output) else {
                        self.report(.unavailable)
                        return
                    }

                    self.captureSession.beginConfiguration()
                    self.captureSession.addInput(input)
                    self.captureSession.addOutput(output)
                    self.camera = camera
                    output.setMetadataObjectsDelegate(self, queue: .main)
                    guard output.availableMetadataObjectTypes.contains(.dataMatrix) else {
                        self.captureSession.commitConfiguration()
                        self.report(.unavailable)
                        return
                    }
                    output.metadataObjectTypes = [.dataMatrix]
                    self.captureSession.commitConfiguration()
                    self.isConfigured = true
                    DispatchQueue.main.async { [weak self] in
                        self?.onTorchAvailabilityChanged(camera.hasTorch)
                    }
                }

                guard !self.captureSession.isRunning else { return }
                self.captureSession.startRunning()
                DexcomG6SensorLabelScanLogger.cameraSessionStarted()
            }
        }

        private func updateTorch(enabled: Bool) {
            guard let camera,
                  camera.hasTorch,
                  camera.isTorchAvailable,
                  camera.isTorchModeSupported(enabled ? .on : .off) else {
                return
            }

            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
                if enabled {
                    try camera.setTorchModeOn(level: 0.5)
                } else {
                    camera.torchMode = .off
                }
            } catch {}
        }

        private func report(_ error: DexcomG6CameraScannerError) {
            DispatchQueue.main.async { [weak self] in self?.onError(error) }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasDeliveredResult else { return }

            let payloads = metadataObjects.compactMap { object -> String? in
                guard let object = object as? AVMetadataMachineReadableCodeObject,
                      object.type == .dataMatrix else {
                    return nil
                }
                return object.stringValue
            }

            guard !payloads.isEmpty else { return }
            if !hasReportedCameraRead {
                hasReportedCameraRead = true
                DexcomG6SensorLabelScanLogger.cameraRead(dataMatrixCount: payloads.count)
            }

            var labels = Set<DexcomG6SensorLabel>()
            for payload in payloads {
                do {
                    labels.insert(try configuration.parse(payload))
                } catch let error as DexcomG6SensorLabelParserError {
                    if !hasReportedMalformedLabel {
                        hasReportedMalformedLabel = true
                        DexcomG6SensorLabelScanLogger.malformedCameraRead(error)
                    }
                } catch {
                    if !hasReportedMalformedLabel {
                        hasReportedMalformedLabel = true
                        DexcomG6SensorLabelScanLogger.malformedCameraRead(error)
                    }
                }
            }

            guard labels.count == 1, let label = labels.first else {
                if labels.count > 1, !hasReportedMultipleLabels {
                    hasReportedMultipleLabels = true
                    DexcomG6SensorLabelScanLogger.multipleCameraLabelsRead()
                }
                return
            }
            hasDeliveredResult = true
            stop()
            DexcomG6SensorLabelScanLogger.succeeded(source: .camera, label: label)
            onScan(label)
        }
    }
}

// MARK: - scanner overlay

private struct ScannerMaskShape: Shape {
    let scanSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        let scanRect = CGRect(
            x: rect.midX - scanSize / 2,
            y: rect.midY - scanSize / 2,
            width: scanSize,
            height: scanSize
        )
        path.addRect(scanRect)
        return path
    }
}

private struct ScannerCornerShape: Shape {
    let cornerLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))

        return path
    }
}

// MARK: - camera preview

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateVideoOrientation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateVideoOrientation()
    }

    func updateVideoOrientation() {
        guard UIDevice.current.userInterfaceIdiom == .pad,
              let interfaceOrientation = window?.windowScene?.interfaceOrientation,
              let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: interfaceOrientation),
              let connection = previewLayer.connection,
              connection.isVideoOrientationSupported else {
            return
        }

        connection.videoOrientation = videoOrientation
    }
}

private extension AVCaptureVideoOrientation {
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }
}
