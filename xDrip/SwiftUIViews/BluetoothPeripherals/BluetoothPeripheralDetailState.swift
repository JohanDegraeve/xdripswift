//
//  BluetoothPeripheralDetailState.swift
//  xdrip
//
//  Created by Paul Plant on 19/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import AVFoundation
import CoreBluetooth
import SwiftUI
import UIKit
import UserNotifications
import os

/// Presentation and action state for one Bluetooth peripheral detail screen.
///
/// This class retains the established transmitter-specific logic while publishing value-based
/// sections and rows for SwiftUI. It also remains the delegate boundary for scan and connection
/// callbacks, which is why it inherits from `NSObject`.
final class BluetoothPeripheralDetailState: NSObject, ObservableObject {
    // MARK: - Published State

    @Published private(set) var sections: [BluetoothPeripheralDetailSection] = []
    @Published private(set) var connectButtonTitle = Texts_BluetoothPeripheralView.connect
    @Published private(set) var connectButtonIsEnabled = true
    @Published private(set) var connectButtonStatusText = ""
    @Published private(set) var connectButtonIsStopAction = false
    @Published private(set) var connectButtonTintColor = BluetoothPeripheralConnectButtonTintColor.green
    @Published private(set) var statusFooterText: String?
    @Published private(set) var statusFooterSystemImage: String?
    // Allows the status footer to show a warning without changing the banner status text.
    @Published private(set) var statusFooterIsWarning = false
    @Published private(set) var connectionStatus = BluetoothPeripheralDisplayStatus.notScanning
    @Published private(set) var category = BluetoothPeripheralCategory.CGM
    @Published private(set) var canDeletePeripheral = false
    @Published var pendingAlert: BluetoothPeripheralDetailAlert?

    // MARK: - Dependencies

    private var bluetoothPeripheral: BluetoothPeripheral?
    private let expectedBluetoothPeripheralType: BluetoothPeripheralType
    private let coreDataManager: CoreDataManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    private weak var sensorProvider: ActiveSensorProviding?
    private let bgReadingsAccessor: BgReadingsAccessor
    private let closeDetailView: () -> Void
    private let presentTextEntryView: (BluetoothPeripheralTextEntry) -> Void
    private let presentSelectionListView: (BluetoothPeripheralSelectionList) -> Void

    // MARK: - Working State

    private var transmitterIdTempValue: String?
    private var isScanning = false
    private var nfcScanNeeded = false
    private var nfcScanSuccessful = false
    private var previousScanningResult: BluetoothTransmitter.startScanningResult?
    private var cachedTransmitterReadSuccessSummaryText: String?
    private var cachedTransmitterReadSuccessSummaryMessage: String?
    private var cachedTransmitterReadSuccessSummaryIndicatorColor: Color?
    private var transmitterReadSuccessTimer: Timer?
    private var didAddObservers = false
    private var didStart = false

    private var webOOPSettingsSectionIsShown = false
    private var nonFixedSettingsSectionIsShown = false
    private var webOOPAndNonFixedSlopeVisibilityIsKnown = false

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBluetoothPeripheralViewController)
    private let m5StackRotationStrings = ["0", "90", "180", "270"]
    private let m5StackBrightnessStrings = ["0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100"]

    init(
        bluetoothPeripheral: BluetoothPeripheral?,
        expectedBluetoothPeripheralType: BluetoothPeripheralType,
        coreDataManager: CoreDataManager,
        bluetoothPeripheralManager: BluetoothPeripheralManaging,
        sensorProvider: ActiveSensorProviding?,
        closeDetailView: @escaping () -> Void,
        presentTextEntryView: @escaping (BluetoothPeripheralTextEntry) -> Void,
        presentSelectionListView: @escaping (BluetoothPeripheralSelectionList) -> Void
    ) {
        self.bluetoothPeripheral = bluetoothPeripheral
        self.expectedBluetoothPeripheralType = expectedBluetoothPeripheralType
        self.coreDataManager = coreDataManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        self.sensorProvider = sensorProvider
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.closeDetailView = closeDetailView
        self.presentTextEntryView = presentTextEntryView
        self.presentSelectionListView = presentSelectionListView
        self.transmitterIdTempValue = bluetoothPeripheral?.blePeripheral.transmitterId

        super.init()

        configureTransmitterDelegates()
        refresh()
    }

    deinit {
        stop()
        reassignTransmitterDelegatesToBluetoothPeripheralManager()
    }

    var screenTitle: String {
        switch expectedBluetoothPeripheralType {
        case .M5StackType:
            return Texts_M5StackView.m5StackViewscreenTitle
        case .M5StickCType:
            return Texts_M5StackView.m5StickCViewscreenTitle
        default:
            return expectedBluetoothPeripheralType.bluetoothPeripheralDisplayTitle
        }
    }

    var displayTitle: String {
        if let alias = bluetoothPeripheral?.blePeripheral.alias, !alias.isEmpty {
            return alias
        }

        return bluetoothPeripheral?.blePeripheral.name ?? screenTitle
    }

    func start() {
        guard !didStart else {
            refresh()
            return
        }

        didStart = true
        addObserversIfNeeded()
        updateTransmitterReadSuccess()
        startTransmitterReadSuccessTimer()

        if bluetoothPeripheral == nil, expectedBluetoothPeripheralType.needsTransmitterId() {
            DispatchQueue.main.async { [weak self] in
                self?.requestTransmitterId()
            }
        }

        refresh()
    }

    func stop() {
        stopTransmitterReadSuccessTimer()
        removeObserversIfNeeded()
        bluetoothPeripheralManager?.stopScanningForNewDevice()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func refresh() {
        let connectButtonState = makeConnectButtonState()

        connectButtonTitle = connectButtonState.title
        connectButtonIsEnabled = connectButtonState.isEnabled
        connectButtonStatusText = connectButtonState.statusText
        connectButtonIsStopAction = connectButtonState.isStopAction
        connectButtonTintColor = connectButtonState.tintColor
        // Use a short footer message here. The full explanation is still shown by
        // the alert guard when activation is attempted from any stale path.
        let activationBlockedMessage = activationBlockedFooterMessageForCurrentPeripheral()
        statusFooterText = makeStatusFooterText(activationBlockedMessage: activationBlockedMessage)
        statusFooterSystemImage = makeStatusFooterSystemImage(activationBlockedMessage: activationBlockedMessage)
        statusFooterIsWarning = activationBlockedMessage != nil
        connectionStatus = makeConnectionDisplayStatus()
        category = expectedBluetoothPeripheralType.category()
        canDeletePeripheral = bluetoothPeripheral != nil
        sections = makeSections()
    }

    func connectButtonTapped() {
        connectButtonHandler()
        refresh()
    }

    func deleteButtonTapped() {
        guard let bluetoothPeripheral = bluetoothPeripheral else { return }

        let bluetoothPeripheralName = bluetoothPeripheral.blePeripheral.alias.map {
            Texts_BluetoothPeripheralView.bluetoothPeripheralAlias + " " + $0
        } ?? bluetoothPeripheral.blePeripheral.name

        pendingAlert = BluetoothPeripheralDetailAlert(
            title: Texts_Common.delete,
            message: Texts_BluetoothPeripheralView.confirmDeletionBluetoothPeripheral + " " + bluetoothPeripheralName + "?",
            primaryButtonTitle: Texts_Common.delete,
            primaryAction: { [weak self] in
                self?.delete(bluetoothPeripheral: bluetoothPeripheral)
            },
            secondaryButtonTitle: Texts_Common.Cancel
        )
    }

    func presentTextEntry(_ textEntry: BluetoothPeripheralTextEntry) {
        presentTextEntryView(textEntry)
    }

    func select(row: BluetoothPeripheralDetailRow) {
        row.action?()
    }

    func setToggle(row: BluetoothPeripheralDetailRow, isOn: Bool) {
        row.toggle?.setValue(isOn)
    }

    private func makeSections() -> [BluetoothPeripheralDetailSection] {
        var sections = [BluetoothPeripheralDetailSection]()

        sections.append(BluetoothPeripheralDetailSection(
            id: "bluetooth",
            title: Texts_SettingsView.m5StackSectionTitleBluetooth,
            rows: makeBluetoothRows()
        ))

        guard bluetoothPeripheral != nil else { return sections }

        if let webOOPSection = makeWebOOPSection() {
            sections.append(webOOPSection)
        }

        if let nonFixedCalibrationSection = makeNonFixedCalibrationSection() {
            sections.append(nonFixedCalibrationSection)
        }

        sections.append(contentsOf: makePeripheralSpecificSections())

        return sections
    }

    private func makeBluetoothRows() -> [BluetoothPeripheralDetailRow] {
        var rows = [BluetoothPeripheralDetailRow]()

        rows.append(row(
            id: "name",
            title: Texts_Common.name,
            detail: bluetoothPeripheral?.blePeripheral.name
        ))

        rows.append(row(
            id: "alias",
            title: Texts_BluetoothPeripheralView.bluetoothPeripheralAlias,
            detail: bluetoothPeripheral?.blePeripheral.alias,
            showsDisclosure: bluetoothPeripheral != nil,
            isEnabled: bluetoothPeripheral != nil,
            action: { [weak self] in
                self?.requestAlias()
            }
        ))

        rows.append(row(
            id: "connection-date",
            title: connectionTimestampTitle(),
            detail: bluetoothPeripheral?.blePeripheral.lastConnectionStatusChangeTimeStamp?.toStringInUserLocale(timeStyle: .short, dateStyle: .short) ?? ""
        ))

        if expectedBluetoothPeripheralType.needsTransmitterId() {
            rows.append(row(
                id: "transmitter-id",
                title: Texts_SettingsView.labelTransmitterId,
                detail: transmitterIdDisplayText(),
                showsDisclosure: transmitterIdTempValue == nil,
                isEnabled: true,
                action: transmitterIdTempValue == nil ? { [weak self] in
                    self?.requestTransmitterId()
                } : nil
            ))
        }

        // Read success only has meaning for the transmitter currently selected for use.
        if expectedBluetoothPeripheralType.canShowTransmitterReadSuccess(),
           sensorProvider?.activeSensor != nil,
           bluetoothPeripheral?.blePeripheral.shouldconnect == true {
            rows.append(row(
                id: "read-success",
                title: Texts_BluetoothPeripheralView.readSuccess,
                detail: cachedTransmitterReadSuccessSummaryText ?? "",
                detailIndicator: transmitterReadSuccessDetailIndicator(),
                showsDisclosure: cachedTransmitterReadSuccessSummaryMessage?.isEmpty == false,
                isEnabled: cachedTransmitterReadSuccessSummaryMessage?.isEmpty == false,
                action: { [weak self] in
                    self?.showReadSuccessInfo()
                }
            ))
        }

        return rows
    }

    private func makeWebOOPSection() -> BluetoothPeripheralDetailSection? {
        guard expectedBluetoothPeripheralType.canWebOOP(), let bluetoothPeripheral = bluetoothPeripheral else {
            return nil
        }

        webOOPSettingsSectionIsShown = true

        let detail = bluetoothPeripheral.blePeripheral.webOOPEnabled ? Texts_BluetoothPeripheralView.nativeAlgorithm : Texts_BluetoothPeripheralView.xDripAlgorithm

        return BluetoothPeripheralDetailSection(
            id: "web-oop",
            title: Texts_SettingsView.labelWebOOP,
            rows: [
                row(
                    id: "web-oop-enabled",
                    title: Texts_SettingsView.labelAlgorithmType,
                    detail: detail,
                    showsDisclosure: true,
                    action: { [weak self] in
                        self?.requestAlgorithmType()
                    }
                )
            ]
        )
    }

    private func makeNonFixedCalibrationSection() -> BluetoothPeripheralDetailSection? {
        guard expectedBluetoothPeripheralType.canUseNonFixedSlope(), let bluetoothPeripheral = bluetoothPeripheral else {
            return nil
        }

        nonFixedSettingsSectionIsShown = true

        let detail = bluetoothPeripheral.blePeripheral.webOOPEnabled
            ? Texts_Common.notRequired
            : (bluetoothPeripheral.blePeripheral.nonFixedSlopeEnabled ? Texts_Calibrations.multiPointCalibration : Texts_Calibrations.singlePointCalibration)

        return BluetoothPeripheralDetailSection(
            id: "non-fixed-calibration",
            title: Texts_SettingsView.labelCalibrationType,
            rows: [
                row(
                    id: "non-fixed-calibration-enabled",
                    title: Texts_SettingsView.labelCalibrationType,
                    detail: detail,
                    showsDisclosure: !bluetoothPeripheral.blePeripheral.webOOPEnabled,
                    isEnabled: !bluetoothPeripheral.blePeripheral.webOOPEnabled,
                    action: { [weak self] in
                        self?.requestCalibrationType()
                    }
                )
            ]
        )
    }

    private func makePeripheralSpecificSections() -> [BluetoothPeripheralDetailSection] {
        guard let bluetoothPeripheral = bluetoothPeripheral else { return [] }

        switch expectedBluetoothPeripheralType {
        case .DexcomType:
            return makeDexcomG5Sections(bluetoothPeripheral: bluetoothPeripheral)
        case .DexcomG7Type:
            return makeDexcomG7Sections(bluetoothPeripheral: bluetoothPeripheral)
        case .Libre2Type:
            return makeLibre2Sections(bluetoothPeripheral: bluetoothPeripheral)
        case .MiaoMiaoType:
            return makeMiaoMiaoSections(bluetoothPeripheral: bluetoothPeripheral)
        case .BubbleType:
            return makeBubbleSections(bluetoothPeripheral: bluetoothPeripheral)
        case .MedtrumTouchCareNanoType:
            return makeMedtrumTouchCareNanoSections(bluetoothPeripheral: bluetoothPeripheral)
        case .M5StackType:
            return makeM5StackSections(bluetoothPeripheral: bluetoothPeripheral, includesSpecificM5StackSection: true)
        case .M5StickCType:
            return makeM5StackSections(bluetoothPeripheral: bluetoothPeripheral, includesSpecificM5StackSection: false)
        case .Libre3HeartBeatType, .DexcomG7HeartBeatType, .OmniPodHeartBeatType:
            return []
        }
    }

    private func row(
        id: String,
        title: String,
        detail: String? = nil,
        detailIndicator: SettingsIndicator? = nil,
        detailSymbol: BluetoothPeripheralDetailSymbol? = nil,
        showsDisclosure: Bool = false,
        isEnabled: Bool = true,
        action: (() -> Void)? = nil
    ) -> BluetoothPeripheralDetailRow {
        BluetoothPeripheralDetailRow(
            id: id,
            title: title,
            detail: detail,
            detailIndicator: detailIndicator,
            detailSymbol: detailSymbol,
            showsDisclosure: showsDisclosure,
            isEnabled: isEnabled,
            toggle: nil,
            action: action
        )
    }

    private func toggleRow(
        id: String,
        title: String,
        isOn: Bool,
        isEnabled: Bool = true,
        detailSymbol: BluetoothPeripheralDetailSymbol? = nil,
        setValue: @escaping (Bool) -> Void
    ) -> BluetoothPeripheralDetailRow {
        BluetoothPeripheralDetailRow(
            id: id,
            title: title,
            detail: nil,
            detailIndicator: nil,
            detailSymbol: detailSymbol,
            showsDisclosure: false,
            isEnabled: isEnabled,
            toggle: BluetoothPeripheralDetailToggle(isOn: isOn, setValue: setValue),
            action: nil
        )
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath, let keyPathEnum = UserDefaults.Key(rawValue: keyPath) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.handleObserved(userDefaultsKey: keyPathEnum)
        }
    }
}

// MARK: - Common Actions

private extension BluetoothPeripheralDetailState {
    func makeConnectButtonState() -> BluetoothPeripheralConnectButtonState {
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager as? BluetoothPeripheralManager else {
            return BluetoothPeripheralConnectButtonState(title: Texts_BluetoothPeripheralView.connect, isEnabled: false, statusText: "", tintColor: .disabledGray)
        }

        if let bluetoothPeripheral = bluetoothPeripheral {
            if bluetoothPeripheral.blePeripheral.shouldconnect {
                // Keep this as a stop action while the device is active.
                // Dexcom can rapidly move between scanning and connected during each reading cycle.
                if nfcScanNeeded {
                    return BluetoothPeripheralConnectButtonState(title: Texts_BluetoothPeripheralView.donotconnect, isEnabled: true, statusText: Texts_BluetoothPeripheralView.nfcScanNeeded, isStopAction: true, tintColor: .red)
                }

                let statusText = bluetoothPeripheralIsConnected(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager)
                    ? Texts_BluetoothPeripheralView.connected
                    : Texts_BluetoothPeripheralView.tryingToConnect

                return BluetoothPeripheralConnectButtonState(title: Texts_BluetoothPeripheralView.donotconnect, isEnabled: true, statusText: statusText, isStopAction: true, tintColor: .red)
            }

            if activationIsBlockedForCurrentPeripheral() {
                return BluetoothPeripheralConnectButtonState(title: Texts_BluetoothPeripheralView.connect, isEnabled: false, statusText: Texts_BluetoothPeripheralView.notTryingToConnect, tintColor: .disabledGray)
            }

            return BluetoothPeripheralConnectButtonState(title: Texts_BluetoothPeripheralView.connect, isEnabled: true, statusText: Texts_BluetoothPeripheralView.notTryingToConnect)
        }

        if expectedBluetoothPeripheralType.needsTransmitterId(), transmitterIdTempValue == nil {
            return BluetoothPeripheralConnectButtonState(title: Texts_SettingsView.labelTransmitterIdTextForButton, isEnabled: true, statusText: Texts_BluetoothPeripheralView.needsTransmitterId, tintColor: .blue)
        }

        if nfcScanNeeded {
            return BluetoothPeripheralConnectButtonState(title: Texts_BluetoothPeripheralView.scanning, isEnabled: true, statusText: Texts_BluetoothPeripheralView.nfcScanNeeded, tintColor: .neutral)
        }

        if nfcScanSuccessful {
            return BluetoothPeripheralConnectButtonState(title: Texts_BluetoothPeripheralView.donotconnect, isEnabled: false, statusText: Texts_BluetoothPeripheralView.tryingToConnect, isStopAction: true, tintColor: .disabledGray)
        }

        if activationIsBlockedForCurrentPeripheral() {
            return BluetoothPeripheralConnectButtonState(title: Texts_BluetoothPeripheralView.scan, isEnabled: false, statusText: Texts_BluetoothPeripheralView.readyToScan, tintColor: .disabledGray)
        }

        if !isScanning {
            return BluetoothPeripheralConnectButtonState(title: Texts_BluetoothPeripheralView.scan, isEnabled: true, statusText: Texts_BluetoothPeripheralView.readyToScan)
        }

        return BluetoothPeripheralConnectButtonState(title: Texts_BluetoothPeripheralView.scanning, isEnabled: false, statusText: Texts_BluetoothPeripheralView.scanning, tintColor: .disabledGray)
    }

    func makeConnectionDisplayStatus() -> BluetoothPeripheralDisplayStatus {
        let bluetoothTransmitter: BluetoothTransmitter?

        if let bluetoothPeripheral = bluetoothPeripheral {
            bluetoothTransmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false)
        } else {
            bluetoothTransmitter = nil
        }

        return BluetoothPeripheralDisplayStatus(
            bluetoothTransmitter: bluetoothTransmitter,
            // A saved device that should connect is still active while waiting for the next Bluetooth cycle.
            isScanningForNewPeripheral: isScanning || bluetoothPeripheral?.blePeripheral.shouldconnect == true
        )
    }

    // Used by the disabled button state. The alert text is not needed here
    // because the detail footer explains the reason before the user taps.
    func activationIsBlockedForCurrentPeripheral() -> Bool {
        guard expectedBluetoothPeripheralType.category() == .CGM else { return false }

        return otherCGMTransmitterHasShouldConnectTrue() || !UserDefaults.standard.isMaster
    }

    // Keep the footer short so the Status section remains readable.
    // The full alert text is still used by canActivateCurrentPeripheral().
    func activationBlockedFooterMessageForCurrentPeripheral() -> String? {
        guard expectedBluetoothPeripheralType.category() == .CGM else { return nil }

        if otherCGMTransmitterHasShouldConnectTrue() {
            return Texts_BluetoothPeripheralsView.noMultipleActiveCGMsAllowedFooter
        }

        if !UserDefaults.standard.isMaster {
            return Texts_BluetoothPeripheralView.cannotActiveCGMInFollowerMode
        }

        return nil
    }

    // Warning text has priority over the normal Dexcom mode footer because it
    // explains why the action button is disabled.
    func makeStatusFooterText(activationBlockedMessage: String?) -> String? {
        if let activationBlockedMessage = activationBlockedMessage {
            return "⚠️ " + activationBlockedMessage
        }

        if expectedBluetoothPeripheralType == .DexcomType, let dexcomG5 = bluetoothPeripheral as? DexcomG5 {
            return dexcomG5.useOtherApp
                ? Texts_BluetoothPeripheralView.runningInCoexistenceMode
                : Texts_BluetoothPeripheralView.runningInPrimaryMode
        }

        return nil
    }

    // Primary and co-existence labels are localized text, but the leading symbol
    // is a fixed visual cue and should not be part of the localized string.
    func makeStatusFooterSystemImage(activationBlockedMessage: String?) -> String? {
        guard activationBlockedMessage == nil,
              expectedBluetoothPeripheralType == .DexcomType,
              let dexcomG5 = bluetoothPeripheral as? DexcomG5
        else {
            return nil
        }

        return dexcomG5ModeSystemImage(useOtherApp: dexcomG5.useOtherApp)
    }

    // The Dexcom G5/G6/ONE mode symbol is a fixed UI marker.
    // It should change with the switch state but not be localized.
    func dexcomG5ModeSystemImage(useOtherApp: Bool) -> String {
        useOtherApp ? "c.circle" : "p.circle"
    }

    func connectionTimestampTitle() -> String {
        guard let bluetoothPeripheral = bluetoothPeripheral,
              let bluetoothPeripheralManager = bluetoothPeripheralManager as? BluetoothPeripheralManager,
              bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp != nil
        else {
            return Texts_BluetoothPeripheralView.connectedAt
        }

        return bluetoothPeripheralIsConnected(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager)
            ? Texts_BluetoothPeripheralView.connectedAt
            : Texts_BluetoothPeripheralView.disConnectedAt
    }

    func transmitterIdDisplayText() -> String? {
        if transmitterIdTempValue == ConstantsBluetoothPairing.dummyDexcomG7TypeTransmitterId || transmitterIdTempValue == "DX" {
            return "Automatic"
        }

        return transmitterIdTempValue
    }

    func batterySymbol(percent: Int) -> BluetoothPeripheralDetailSymbol? {
        guard percent > 0 else { return nil }

        switch percent {
        case 0...10:
            return BluetoothPeripheralDetailSymbol(systemName: batterySystemName(percent: 0), color: Color(.systemRed))
        case 11...25:
            return BluetoothPeripheralDetailSymbol(systemName: batterySystemName(percent: 25), color: Color(.systemYellow))
        case 26...65:
            return BluetoothPeripheralDetailSymbol(systemName: batterySystemName(percent: 50), color: .green)
        case 66...90:
            return BluetoothPeripheralDetailSymbol(systemName: batterySystemName(percent: 75), color: .green)
        default:
            return BluetoothPeripheralDetailSymbol(systemName: batterySystemName(percent: 100), color: .green)
        }
    }

    func batterySymbol(voltageB: Int32) -> BluetoothPeripheralDetailSymbol? {
        guard voltageB > 0 else { return nil }

        // Dexcom G5/G6 battery state is based on voltage B, not a percentage.
        if voltageB < 270 {
            return BluetoothPeripheralDetailSymbol(systemName: batterySystemName(percent: 0), color: Color(.systemRed))
        } else if voltageB < 280 {
            return BluetoothPeripheralDetailSymbol(systemName: batterySystemName(percent: 25), color: Color(.systemYellow))
        } else {
            return BluetoothPeripheralDetailSymbol(systemName: batterySystemName(percent: 100), color: .green)
        }
    }

    func batterySystemName(percent: Int) -> String {
        if #available(iOS 17.0, *) {
            return "battery.\(percent)percent"
        }

        switch percent {
        case 0:
            return "minus.plus.batteryblock.slash"
        case 25, 50:
            return "minus.plus.batteryblock"
        default:
            return "minus.plus.batteryblock.fill"
        }
    }

    func connectButtonHandler() {
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else { return }

        checkIfNFCScanIsNeeded()

        if let bluetoothPeripheral = bluetoothPeripheral {
            if bluetoothPeripheral.blePeripheral.shouldconnect {
                setShouldConnectToFalse(for: bluetoothPeripheral, askUser: true)
            } else {
                guard canActivateCurrentPeripheral() else { return }

                bluetoothPeripheral.blePeripheral.shouldconnect = true
                coreDataManager.saveChanges()

                if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: true) {
                    bluetoothTransmitter.bluetoothTransmitterDelegate = self
                    configureSpecificDelegate(for: bluetoothTransmitter)
                    bluetoothTransmitter.connect()
                }
            }
        } else if expectedBluetoothPeripheralType.needsTransmitterId(), transmitterIdTempValue == nil {
            requestTransmitterId()
        } else {
            scanForBluetoothPeripheral(type: expectedBluetoothPeripheralType)
        }

        refresh()
    }

    func canActivateCurrentPeripheral() -> Bool {
        guard expectedBluetoothPeripheralType.category() == .CGM else { return true }

        if otherCGMTransmitterHasShouldConnectTrue() {
            pendingAlert = BluetoothPeripheralDetailAlert(
                title: Texts_Common.warning,
                message: Texts_BluetoothPeripheralsView.noMultipleActiveCGMsAllowed
            )
            return false
        }

        if !UserDefaults.standard.isMaster {
            pendingAlert = BluetoothPeripheralDetailAlert(
                title: Texts_Common.warning,
                message: Texts_BluetoothPeripheralView.cannotActiveCGMInFollowerMode
            )
            return false
        }

        return true
    }

    func otherCGMTransmitterHasShouldConnectTrue() -> Bool {
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else { return false }

        return bluetoothPeripheralManager.getBluetoothPeripherals().contains { bluetoothPeripheral in
            bluetoothPeripheral.bluetoothPeripheralType().category() == .CGM &&
                bluetoothPeripheral.blePeripheral.shouldconnect &&
                bluetoothPeripheral.blePeripheral.address != self.bluetoothPeripheral?.blePeripheral.address
        }
    }

    func setShouldConnectToFalse(for bluetoothPeripheral: BluetoothPeripheral, askUser: Bool) {
        if askUser {
            pendingAlert = BluetoothPeripheralDetailAlert(
                title: Texts_BluetoothPeripheralView.confirmDisconnectTitle,
                message: Texts_BluetoothPeripheralView.confirmDisconnectMessage,
                primaryButtonTitle: Texts_BluetoothPeripheralView.disconnect,
                primaryAction: { [weak self] in
                    self?.disconnect(bluetoothPeripheral: bluetoothPeripheral)
                },
                secondaryButtonTitle: Texts_Common.Cancel
            )
        } else {
            disconnect(bluetoothPeripheral: bluetoothPeripheral)
        }
    }

    func disconnect(bluetoothPeripheral: BluetoothPeripheral) {
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else { return }

        bluetoothPeripheral.blePeripheral.shouldconnect = false
        coreDataManager.saveChanges()

        if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false), bluetoothTransmitter is CGMTransmitter {
            UserDefaults.standard.libre1DerivedAlgorithmParameters = nil
            UserDefaults.standard.stopActiveSensor = true
        }

        bluetoothPeripheralManager.setBluetoothTransmitterToNil(forBluetoothPeripheral: bluetoothPeripheral)
        refresh()
    }

    func delete(bluetoothPeripheral: BluetoothPeripheral) {
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else { return }

        if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false), bluetoothTransmitter is CGMTransmitter {
            UserDefaults.standard.libre1DerivedAlgorithmParameters = nil
            UserDefaults.standard.stopActiveSensor = true
        }

        bluetoothPeripheralManager.deleteBluetoothPeripheral(bluetoothPeripheral: bluetoothPeripheral)
        self.bluetoothPeripheral = nil
        closeDetailView()
    }

    func bluetoothPeripheralIsConnected(bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManager) -> Bool {
        bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false)?.getConnectionStatus() == .connected
    }

    func requestAlias() {
        guard let bluetoothPeripheral = bluetoothPeripheral else { return }

        presentTextEntryView(BluetoothPeripheralTextEntry(
            title: Texts_BluetoothPeripheralView.bluetoothPeripheralAlias,
            message: Texts_BluetoothPeripheralView.selectAliasText,
            keyboardType: .default,
            text: bluetoothPeripheral.blePeripheral.alias,
            placeholder: nil,
            actionTitle: Texts_Common.Ok,
            cancelTitle: Texts_Common.Cancel,
            actionHandler: { [weak self] text in
                self?.setAlias(text, for: bluetoothPeripheral)
            },
            actionIsEnabled: nil,
            inputValidator: nil
        ))
    }

    func setAlias(_ aliasText: String, for bluetoothPeripheral: BluetoothPeripheral) {
        let newAlias = aliasText.toNilIfLength0()

        if let newAlias = newAlias, let bluetoothPeripheralManager = bluetoothPeripheralManager {
            let aliasAlreadyExists = bluetoothPeripheralManager.getBluetoothPeripherals().contains { otherBluetoothPeripheral in
                otherBluetoothPeripheral.blePeripheral.address != bluetoothPeripheral.blePeripheral.address &&
                    otherBluetoothPeripheral.blePeripheral.alias == newAlias
            }

            if aliasAlreadyExists {
                pendingAlert = BluetoothPeripheralDetailAlert(
                    title: Texts_Common.warning,
                    message: Texts_BluetoothPeripheralView.aliasAlreadyExists
                )
                return
            }
        }

        bluetoothPeripheral.blePeripheral.alias = newAlias
        coreDataManager.saveChanges()
        refresh()
    }

    func showReadSuccessInfo() {
        guard let message = cachedTransmitterReadSuccessSummaryMessage, !message.isEmpty else { return }

        pendingAlert = BluetoothPeripheralDetailAlert(
            title: Texts_BluetoothPeripheralView.readSuccess,
            message: message
        )
    }

    func transmitterReadSuccessDetailIndicator() -> SettingsIndicator? {
        cachedTransmitterReadSuccessSummaryIndicatorColor.map { SettingsIndicator(color: $0) }
    }

    func sensorStatusDetailIndicator(for sensorStatus: String?) -> SettingsIndicator? {
        guard let sensorStatus = sensorStatus, !sensorStatus.isEmpty else {
            return nil
        }

        // Sensor status is stored as display text, so match the known Dexcom descriptions exactly.
        if let indicatorColor = DexcomAlgorithmState.indicatorColor(forDescription: sensorStatus) {
            return SettingsIndicator(color: color(for: indicatorColor))
        }

        if let indicatorColor = DexcomSessionStartResponse.indicatorColor(forDescription: sensorStatus) {
            return SettingsIndicator(color: color(for: indicatorColor))
        }

        return SettingsIndicator(color: color(for: .red))
    }

    func color(for sensorStatusIndicatorColor: DexcomSensorStatusIndicatorColor) -> Color {
        switch sensorStatusIndicatorColor {
        case .green:
            return .green
        case .yellow:
            return Color(.systemYellow)
        case .orange:
            return Color(.systemOrange)
        case .red:
            return Color(.systemRed)
        }
    }
}

// MARK: - Scanning and NFC

private extension BluetoothPeripheralDetailState {
    func scanForBluetoothPeripheral(type: BluetoothPeripheralType) {
        guard bluetoothPeripheral == nil, let bluetoothPeripheralManager = bluetoothPeripheralManager else { return }
        guard !type.needsTransmitterId() || transmitterIdTempValue != nil else { return }

        previousScanningResult = nil

        bluetoothPeripheralManager.startScanningForNewDevice(
            type: type,
            transmitterId: transmitterIdTempValue,
            bluetoothTransmitterDelegate: self,
            callBackForScanningResult: { [weak self] startScanningResult in
                self?.handleScanningResult(startScanningResult: startScanningResult)
            },
            callback: { [weak self] bluetoothPeripheral in
                self?.handleFound(bluetoothPeripheral: bluetoothPeripheral)
            }
        )
    }

    func handleFound(bluetoothPeripheral: BluetoothPeripheral) {
        trace("in BluetoothPeripheralDetailState, callback. bluetoothPeripheral address = %{public}@, name = %{public}@", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .info, bluetoothPeripheral.blePeripheral.address, bluetoothPeripheral.blePeripheral.name)

        isScanning = false
        UIApplication.shared.isIdleTimerDisabled = false

        self.bluetoothPeripheral = bluetoothPeripheral
        bluetoothPeripheral.blePeripheral.transmitterId = transmitterIdTempValue

        if let bluetoothTransmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
            bluetoothTransmitter.bluetoothTransmitterDelegate = self
            configureSpecificDelegate(for: bluetoothTransmitter)
        }

        refresh()
    }

    func handleScanningResult(startScanningResult: BluetoothTransmitter.startScanningResult) {
        guard startScanningResult != previousScanningResult else { return }

        previousScanningResult = startScanningResult

        switch startScanningResult {
        case .success:
            isScanning = true
            UIApplication.shared.isIdleTimerDisabled = true

            if !expectedBluetoothPeripheralType.needsNFCScanToConnect() {
                pendingAlert = BluetoothPeripheralDetailAlert(title: Texts_HomeView.info, message: Texts_HomeView.startScanningInfo)
            }

        case .alreadyScanning, .alreadyConnected, .connecting:
            trace("in handleScanningResult, scanning not started. Scanning result = %{public}@", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error, startScanningResult.description())
            isScanning = false

        case .poweredOff:
            trace("in handleScanningResult, scanning not started. Bluetooth is not on", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error)
            pendingAlert = BluetoothPeripheralDetailAlert(title: Texts_Common.warning, message: Texts_HomeView.bluetoothIsNotOn)

        case .other(let reason):
            trace("in handleScanningResult, scanning not started. Scanning result = %{public}@", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error, reason)

        case .unauthorized:
            trace("in handleScanningResult, scanning not started. Scanning result = unauthorized", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error)
            pendingAlert = BluetoothPeripheralDetailAlert(title: Texts_Common.warning, message: Texts_HomeView.bluetoothIsNotAuthorized)

        case .unknown:
            trace("in handleScanningResult, scanning not started. This always happens when a BluetoothTransmitter starts scanning. We should now see a new call to handleScanningResult", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .info)

        case .nfcScanNeeded:
            trace("in handleScanningResult, an NFC scan is required before BLE scanning will be started. Scanning result = nfcScanNeeded", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error)
        }

        refresh()
    }

    func checkIfNFCScanIsNeeded() {
        nfcScanNeeded = false
        nfcScanSuccessful = false

        if bluetoothPeripheral?.bluetoothPeripheralType().needsNFCScanToConnect() == true {
            nfcScanNeeded = true
        }

        if expectedBluetoothPeripheralType.needsNFCScanToConnect() {
            nfcScanNeeded = true
        }

        UserDefaults.standard.nfcScanSuccessful = false
        UserDefaults.standard.nfcScanFailed = false
    }

    func nfcScanFailed(for bluetoothPeripheral: BluetoothPeripheral?) {
        if let bluetoothPeripheral = bluetoothPeripheral {
            setShouldConnectToFalse(for: bluetoothPeripheral, askUser: false)
        } else {
            refresh()
        }

        pendingAlert = BluetoothPeripheralDetailAlert(
            title: TextsLibreNFC.nfcScanFailedTitle,
            message: TextsLibreNFC.nfcScanFailedMessage,
            primaryButtonTitle: TextsLibreNFC.nfcScanFailedScanAgainButton,
            primaryAction: { [weak self] in
                AudioServicesPlaySystemSound(1102)
                self?.checkIfNFCScanIsNeeded()
                self?.connectButtonHandler()
            },
            secondaryButtonTitle: Texts_Common.Cancel,
            secondaryAction: { [weak self] in
                if bluetoothPeripheral == nil {
                    self?.closeDetailView()
                } else {
                    self?.checkIfNFCScanIsNeeded()
                    self?.refresh()
                }
            }
        )
    }

    func addObserversIfNeeded() {
        guard !didAddObservers else { return }

        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nfcScanFailed.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nfcScanSuccessful.rawValue, options: .new, context: nil)
        didAddObservers = true
    }

    func removeObserversIfNeeded() {
        guard didAddObservers else { return }

        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nfcScanFailed.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nfcScanSuccessful.rawValue)
        didAddObservers = false
    }

    func handleObserved(userDefaultsKey: UserDefaults.Key) {
        switch userDefaultsKey {
        case .nfcScanFailed:
            guard UserDefaults.standard.nfcScanFailed else { return }

            nfcScanSuccessful = false
            nfcScanNeeded = false

            trace("in observeValue, nfcScanFailed has been set to true so will disconnect and offer to scan again", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error)
            nfcScanFailed(for: bluetoothPeripheral)

        case .nfcScanSuccessful:
            guard UserDefaults.standard.nfcScanSuccessful else { return }

            nfcScanSuccessful = true
            nfcScanNeeded = false

            trace("in observeValue, nfcScanSuccessful has been set to true so will inform the user and try and update the connection status to Scanning", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error)
            pendingAlert = BluetoothPeripheralDetailAlert(title: TextsLibreNFC.nfcScanSuccessfulTitle, message: TextsLibreNFC.nfcScanSuccessfulMessage)
            refresh()

        default:
            break
        }
    }
}

// MARK: - Transmitter ID

private extension BluetoothPeripheralDetailState {
    func requestTransmitterId() {
        var transmitterIdTitleText = Texts_SettingsView.labelTransmitterId
        var transmitterIdMessageText = Texts_SettingsView.labelGiveTransmitterId
        var placeholder = "00000"
        var actionIsEnabled: ((String) -> Bool)?
        var textInputAutocapitalization = TextInputAutocapitalization.words

        switch expectedBluetoothPeripheralType {
        case .Libre3HeartBeatType:
            transmitterIdTitleText = Texts_SettingsView.labelBluetoothDeviceName
            transmitterIdMessageText = Texts_SettingsView.heartbeatLibreMessage
            placeholder = "000000000000"
        case .DexcomType:
            textInputAutocapitalization = .characters
        case .DexcomG7Type, .DexcomG7HeartBeatType:
            transmitterIdMessageText = Texts_SettingsView.dexcomG7Message
            placeholder = "DX0000"
        default:
            break
        }

        switch expectedBluetoothPeripheralType {
        case .DexcomType:
            actionIsEnabled = { transmitterId in
                transmitterId.count == 6
            }
        default:
            break
        }

        presentTextEntryView(BluetoothPeripheralTextEntry(
            title: transmitterIdTitleText,
            message: transmitterIdMessageText,
            keyboardType: .alphabet,
            textInputAutocapitalization: textInputAutocapitalization,
            text: transmitterIdTempValue,
            placeholder: placeholder,
            actionTitle: Texts_Common.Ok,
            cancelTitle: Texts_Common.Cancel,
            actionHandler: { [weak self] transmitterId in
                self?.setTransmitterId(transmitterId)
            },
            actionIsEnabled: actionIsEnabled,
            inputValidator: { [weak self] transmitterId in
                self?.expectedBluetoothPeripheralType.validateTransmitterId(transmitterId: transmitterId)
            }
        ))
    }

    func setTransmitterId(_ transmitterId: String) {
        // Only G5/G6 transmitter IDs must be uppercase. Other Bluetooth names can use mixed case.
        let transmitterIdValue = expectedBluetoothPeripheralType == .DexcomType ? transmitterId.uppercased() : transmitterId

        transmitterIdTempValue = transmitterIdValue.toNilIfLength0() ?? ConstantsBluetoothPairing.dummyDexcomG7TypeTransmitterId
        refresh()
    }
}

// MARK: - Algorithm and Calibration

private extension BluetoothPeripheralDetailState {
    func requestAlgorithmType() {
        guard let bluetoothPeripheral = bluetoothPeripheral else { return }

        let currentAlgorithmType = bluetoothPeripheral.blePeripheral.webOOPEnabled ? AlgorithmType.nativeAlgorithm : AlgorithmType.xDripAlgorithm
        let data = AlgorithmType.allCases.map { $0.description }
        let selectedRow = AlgorithmType.allCases.firstIndex(of: currentAlgorithmType)

        presentSelectionListView(BluetoothPeripheralSelectionList(
            title: Texts_SettingsView.labelAlgorithmType,
            data: data,
            selectedRow: selectedRow,
            actionHandler: { [weak self] index in
                self?.confirmAlgorithmChange(index: index, selectedRow: selectedRow, oldAlgorithmType: currentAlgorithmType, bluetoothPeripheral: bluetoothPeripheral)
            }
        ))
    }

    func confirmAlgorithmChange(index: Int, selectedRow: Int?, oldAlgorithmType: AlgorithmType, bluetoothPeripheral: BluetoothPeripheral) {
        guard index != selectedRow else { return }

        let newAlgorithmType = AlgorithmType(rawValue: index) ?? .nativeAlgorithm

        pendingAlert = BluetoothPeripheralDetailAlert(
            title: Texts_SettingsView.labelAlgorithmType,
            message: newAlgorithmType == .nativeAlgorithm ? Texts_BluetoothPeripheralView.confirmAlgorithmChangeToTransmitterMessage : Texts_BluetoothPeripheralView.confirmAlgorithmChangeToxDripMessage,
            primaryButtonTitle: Texts_BluetoothPeripheralView.confirm,
            primaryAction: { [weak self] in
                self?.setAlgorithmType(newAlgorithmType, oldAlgorithmType: oldAlgorithmType, bluetoothPeripheral: bluetoothPeripheral)
            },
            secondaryButtonTitle: Texts_Common.Cancel
        )
    }

    func setAlgorithmType(_ newAlgorithmType: AlgorithmType, oldAlgorithmType: AlgorithmType, bluetoothPeripheral: BluetoothPeripheral) {
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else { return }

        bluetoothPeripheral.blePeripheral.webOOPEnabled = newAlgorithmType == .nativeAlgorithm
        bluetoothPeripheralManager.receivedNewValue(webOOPEnabled: newAlgorithmType == .nativeAlgorithm, for: bluetoothPeripheral)

        if newAlgorithmType == .nativeAlgorithm {
            bluetoothPeripheral.blePeripheral.nonFixedSlopeEnabled = false
            bluetoothPeripheralManager.receivedNewValue(nonFixedSlopeEnabled: false, for: bluetoothPeripheral)
        }

        coreDataManager.saveChanges()
        webOOPAndNonFixedSlopeVisibilityIsKnown = false

        trace("Algorithm type was changed from '%{public}@' to '%{public}@'", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .info, oldAlgorithmType.description, newAlgorithmType.description)
        refresh()
    }

    func requestCalibrationType() {
        guard let bluetoothPeripheral = bluetoothPeripheral, !bluetoothPeripheral.blePeripheral.webOOPEnabled else { return }

        let currentCalibrationType = bluetoothPeripheral.blePeripheral.nonFixedSlopeEnabled ? CalibrationType.multiPoint : CalibrationType.singlePoint
        let data = CalibrationType.allCases.map { $0.description }
        let selectedRow = CalibrationType.allCases.firstIndex(of: currentCalibrationType)

        presentSelectionListView(BluetoothPeripheralSelectionList(
            title: Texts_SettingsView.labelCalibrationType,
            data: data,
            selectedRow: selectedRow,
            actionHandler: { [weak self] index in
                self?.confirmCalibrationChange(index: index, selectedRow: selectedRow, oldCalibrationType: currentCalibrationType, bluetoothPeripheral: bluetoothPeripheral)
            }
        ))
    }

    func confirmCalibrationChange(index: Int, selectedRow: Int?, oldCalibrationType: CalibrationType, bluetoothPeripheral: BluetoothPeripheral) {
        guard index != selectedRow else { return }

        let newCalibrationType = CalibrationType(rawValue: index) ?? .singlePoint

        pendingAlert = BluetoothPeripheralDetailAlert(
            title: Texts_SettingsView.labelCalibrationType,
            message: newCalibrationType == .singlePoint ? Texts_BluetoothPeripheralView.confirmCalibrationChangeToSinglePointMessage : Texts_BluetoothPeripheralView.confirmCalibrationChangeToMultiPointMessage,
            primaryButtonTitle: Texts_BluetoothPeripheralView.confirm,
            primaryAction: { [weak self] in
                self?.setCalibrationType(newCalibrationType, oldCalibrationType: oldCalibrationType, bluetoothPeripheral: bluetoothPeripheral)
            },
            secondaryButtonTitle: Texts_Common.Cancel
        )
    }

    func setCalibrationType(_ newCalibrationType: CalibrationType, oldCalibrationType: CalibrationType, bluetoothPeripheral: BluetoothPeripheral) {
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else { return }

        bluetoothPeripheral.blePeripheral.nonFixedSlopeEnabled = newCalibrationType == .multiPoint
        bluetoothPeripheralManager.receivedNewValue(nonFixedSlopeEnabled: newCalibrationType == .multiPoint, for: bluetoothPeripheral)
        coreDataManager.saveChanges()

        trace("Calibration activity type was changed from '%{public}@' to '%{public}@'", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, oldCalibrationType.description, newCalibrationType.description)
        refresh()
    }
}

// MARK: - Read Success

private extension BluetoothPeripheralDetailState {
    func startTransmitterReadSuccessTimer() {
        transmitterReadSuccessTimer?.invalidate()
        transmitterReadSuccessTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateTransmitterReadSuccess()
        }

        if let transmitterReadSuccessTimer = transmitterReadSuccessTimer {
            RunLoop.main.add(transmitterReadSuccessTimer, forMode: .common)
        }
    }

    func stopTransmitterReadSuccessTimer() {
        transmitterReadSuccessTimer?.invalidate()
        transmitterReadSuccessTimer = nil
    }

    func updateTransmitterReadSuccess() {
        guard expectedBluetoothPeripheralType.canShowTransmitterReadSuccess(),
              let bluetoothPeripheralManager = bluetoothPeripheralManager,
              let bluetoothPeripheral = bluetoothPeripheral,
              let activeSensor = sensorProvider?.activeSensor
        else {
            cachedTransmitterReadSuccessSummaryText = "Waiting..."
            cachedTransmitterReadSuccessSummaryMessage = ""
            cachedTransmitterReadSuccessSummaryIndicatorColor = nil
            refresh()
            return
        }

        if let status = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false)?.getConnectionStatus(),
           status == .disconnected,
           bluetoothPeripheral.blePeripheral.shouldconnect == false {
            return
        }

        let display = TransmitterReadSuccessManager(bgReadingsAccessor: bgReadingsAccessor).getReadSuccess(forSensor: activeSensor, now: nil, notBefore: nil)
        let now = Date()
        let availableHours: Double = {
            guard let earliestTimestamp = display.earliestTimestampInLast24h else { return 0 }
            let seconds = max(0, now.timeIntervalSince(earliestTimestamp))
            return seconds / 3600.0
        }()

        func windowLabel(for nominalHours: Int, expected: Int, fullExpected: Int) -> String {
            if expected >= fullExpected {
                return Date().addingTimeInterval(-Double(nominalHours) * 60 * 60).daysAndHoursAgo(showOnlyHours: true)
            }

            let shownHours = min(availableHours, Double(nominalHours))
            return Date().addingTimeInterval(-Double(shownHours) * 60 * 60).daysAndHoursAgo()
        }

        let okSuccessPercentage = display.nominalGapInSeconds > 180 ? 95.0 : 80.0
        let warningSuccessPercentage = display.nominalGapInSeconds > 180 ? 90.0 : 70.0

        func indicatorColor(for successPercentage: Double) -> Color {
            if successPercentage >= okSuccessPercentage {
                return .green
            } else if successPercentage >= warningSuccessPercentage {
                return Color(.systemYellow)
            } else {
                return Color(.systemRed)
            }
        }

        let gap = display.nominalGapInSeconds
        let fullExpected6h = Int(floor((6.0 * 3600.0) / Double(gap)))
        let fullExpected12h = Int(floor((12.0 * 3600.0) / Double(gap)))
        let fullExpected24h = Int(floor((24.0 * 3600.0) / Double(gap)))

        if display.expected24h == 0 {
            cachedTransmitterReadSuccessSummaryText = "Waiting..."
            cachedTransmitterReadSuccessSummaryMessage = ""
            cachedTransmitterReadSuccessSummaryIndicatorColor = nil
            refresh()
            return
        }

        let label6h = windowLabel(for: 6, expected: display.expected6h, fullExpected: fullExpected6h)
        let label12h = windowLabel(for: 12, expected: display.expected12h, fullExpected: fullExpected12h)
        let label24h = windowLabel(for: 24, expected: display.expected24h, fullExpected: fullExpected24h)

        cachedTransmitterReadSuccessSummaryText = "\(String(format: "%0.0f", display.success24h))% (\(label24h))"
        cachedTransmitterReadSuccessSummaryIndicatorColor = indicatorColor(for: display.success24h)

        var summaryMessageLines = [String]()
        summaryMessageLines.append("Expecting \(expectedBluetoothPeripheralType.bluetoothPeripheralDisplayTitle) readings every \(display.nominalGapInSeconds) seconds.")
        summaryMessageLines.append("\(String(format: "%0.1f", display.success6h))% (\(label6h): \(display.expected6h - display.actual6h) dropped)")

        if display.expected12h >= fullExpected6h {
            summaryMessageLines.append("\(String(format: "%0.1f", display.success12h))% (\(label12h): \(display.expected12h - display.actual12h) dropped)")
        }

        if display.expected24h >= fullExpected12h {
            summaryMessageLines.append("\(String(format: "%0.1f", display.success24h))% (\(label24h): \(display.expected24h - display.actual24h) dropped)")
        }

        cachedTransmitterReadSuccessSummaryMessage = summaryMessageLines.joined(separator: "\n\n")
        refresh()
    }
}

// MARK: - Models

/// One grouped detail section and its current rows.
struct BluetoothPeripheralDetailSection: Identifiable {
    let id: String
    let title: String?
    let headerDetail: String?
    let headerSymbol: BluetoothPeripheralDetailSymbol?
    let footer: String?
    let footerLines: [BluetoothPeripheralDetailFooterLine]
    let rows: [BluetoothPeripheralDetailRow]

    init(
        id: String,
        title: String?,
        headerDetail: String? = nil,
        headerSymbol: BluetoothPeripheralDetailSymbol? = nil,
        footer: String? = nil,
        footerLines: [BluetoothPeripheralDetailFooterLine] = [],
        rows: [BluetoothPeripheralDetailRow]
    ) {
        self.id = id
        self.title = title
        self.headerDetail = headerDetail
        self.headerSymbol = headerSymbol
        self.footer = footer
        self.footerLines = footerLines
        self.rows = rows
    }

    init(
        index: Int,
        title: String?,
        headerDetail: String? = nil,
        headerSymbol: BluetoothPeripheralDetailSymbol? = nil,
        footer: String? = nil,
        footerLines: [BluetoothPeripheralDetailFooterLine] = [],
        rows: [BluetoothPeripheralDetailRow]
    ) {
        self.id = String(index)
        self.title = title
        self.headerDetail = headerDetail
        self.headerSymbol = headerSymbol
        self.footer = footer
        self.footerLines = footerLines
        self.rows = rows
    }
}

/// One styled line in a section footer.
struct BluetoothPeripheralDetailFooterLine: Identifiable {
    let id = UUID()
    let systemImage: String
    let text: String
    // Used to mute the mode description that does not match the current switch state.
    let isActive: Bool
}

/// Value model for one configurable peripheral row.
struct BluetoothPeripheralDetailRow: Identifiable {
    let id: String
    let title: String
    let detail: String?
    let detailIndicator: SettingsIndicator?
    let detailSymbol: BluetoothPeripheralDetailSymbol?
    let showsDisclosure: Bool
    let isEnabled: Bool
    let toggle: BluetoothPeripheralDetailToggle?
    let action: (() -> Void)?

    init(
        id: String,
        title: String,
        detail: String?,
        detailIndicator: SettingsIndicator?,
        detailSymbol: BluetoothPeripheralDetailSymbol?,
        showsDisclosure: Bool,
        isEnabled: Bool,
        toggle: BluetoothPeripheralDetailToggle?,
        action: (() -> Void)?
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.detailIndicator = detailIndicator
        self.detailSymbol = detailSymbol
        self.showsDisclosure = showsDisclosure
        self.isEnabled = isEnabled
        self.toggle = toggle
        self.action = action
    }

}

/// Binding actions used by a Boolean detail row.
struct BluetoothPeripheralDetailToggle {
    let isOn: Bool
    let setValue: (Bool) -> Void
}

/// Optional symbol and color displayed with a detail value.
struct BluetoothPeripheralDetailSymbol {
    let systemName: String
    let color: Color
}

/// Complete presentation state for the connect or stop button.
struct BluetoothPeripheralConnectButtonState {
    let title: String
    let isEnabled: Bool
    let statusText: String
    let isStopAction: Bool
    let tintColor: BluetoothPeripheralConnectButtonTintColor

    init(title: String, isEnabled: Bool, statusText: String, isStopAction: Bool = false, tintColor: BluetoothPeripheralConnectButtonTintColor = .green) {
        self.title = title
        self.isEnabled = isEnabled
        self.statusText = statusText
        self.isStopAction = isStopAction
        self.tintColor = tintColor
    }
}

/// Semantic tint used by the native connect button.
enum BluetoothPeripheralConnectButtonTintColor {
    case disabledGray
    case neutral
    case green
    case blue
    case red
}

/// Alert requested by transmitter validation or connection actions.
struct BluetoothPeripheralDetailAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButtonTitle: String?
    let primaryAction: (() -> Void)?
    let secondaryButtonTitle: String?
    let secondaryAction: (() -> Void)?

    init(
        title: String,
        message: String,
        primaryButtonTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryButtonTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryAction = secondaryAction
    }
}

/// Text-entry route supplied by transmitter-specific configuration logic.
struct BluetoothPeripheralTextEntry: Identifiable {
    let id = UUID()
    let title: String?
    let message: String?
    let keyboardType: UIKeyboardType
    let textInputAutocapitalization: TextInputAutocapitalization?
    let text: String?
    let placeholder: String?
    let actionTitle: String
    let cancelTitle: String
    let actionHandler: (String) -> Void
    let actionIsEnabled: ((String) -> Bool)?
    let inputValidator: ((String) -> String?)?

    init(
        title: String?,
        message: String?,
        keyboardType: UIKeyboardType,
        textInputAutocapitalization: TextInputAutocapitalization? = .words,
        text: String?,
        placeholder: String?,
        actionTitle: String,
        cancelTitle: String,
        actionHandler: @escaping (String) -> Void,
        actionIsEnabled: ((String) -> Bool)?,
        inputValidator: ((String) -> String?)?
    ) {
        self.title = title
        self.message = message
        self.keyboardType = keyboardType
        self.textInputAutocapitalization = textInputAutocapitalization
        self.text = text
        self.placeholder = placeholder
        self.actionTitle = actionTitle
        self.cancelTitle = cancelTitle
        self.actionHandler = actionHandler
        self.actionIsEnabled = actionIsEnabled
        self.inputValidator = inputValidator
    }
}

/// Selection-list route supplied by transmitter-specific configuration logic.
struct BluetoothPeripheralSelectionList: Identifiable {
    let id = UUID()
    let title: String
    let data: [String]
    let selectedRow: Int?
    let actionHandler: (Int) -> Void
}

// MARK: - Dexcom G5/G6/ONE

private extension BluetoothPeripheralDetailState {
    func makeDexcomG5Sections(bluetoothPeripheral: BluetoothPeripheral) -> [BluetoothPeripheralDetailSection] {
        guard let dexcomG5 = bluetoothPeripheral as? DexcomG5 else { return [] }

        var sections = [
            BluetoothPeripheralDetailSection(
                id: "dexcom-g5",
                title: "Dexcom",
                headerDetail: dexcomG5.isAnubis ? "Anubis" : nil,
                headerSymbol: dexcomG5.isAnubis ? BluetoothPeripheralDetailSymbol(systemName: "checkmark.circle", color: .green) : nil,
                rows: makeDexcomG5CommonRows(dexcomG5: dexcomG5)
            ),
            BluetoothPeripheralDetailSection(
                id: "dexcom-g5-coexistence",
                title: nil,
                footerLines: dexcomG5CoexistenceFooterLines(dexcomG5: dexcomG5),
                rows: makeDexcomG5CoexistenceRows(dexcomG5: dexcomG5)
            ),
            BluetoothPeripheralDetailSection(
                id: "dexcom-g5-battery",
                title: Texts_BluetoothPeripheralView.battery,
                headerSymbol: batterySymbol(voltageB: dexcomG5.voltageB),
                rows: makeDexcomG5BatteryRows(dexcomG5: dexcomG5)
            )
        ]

        if dexcomG5.isAnubis {
            sections.append(BluetoothPeripheralDetailSection(
                id: "dexcom-g5-anubis",
                title: Texts_SettingsView.labelResetTransmitter,
                rows: makeDexcomG5AnubisRows(dexcomG5: dexcomG5)
            ))
        }

        return sections
    }

    func makeDexcomG5CommonRows(dexcomG5: DexcomG5) -> [BluetoothPeripheralDetailRow] {
        [
            row(
                id: "dexcom-g5-sensor-start-date",
                title: Texts_BluetoothPeripheralView.sensorStartDate,
                detail: dexcomG5SensorStartDateText(dexcomG5: dexcomG5),
                showsDisclosure: shouldShowDexcomG5SensorStartDate(dexcomG5: dexcomG5),
                isEnabled: shouldShowDexcomG5SensorStartDate(dexcomG5: dexcomG5),
                action: { [weak self] in
                    self?.showDexcomG5SensorStartDateInfo(dexcomG5: dexcomG5)
                }
            ),
            row(
                id: "dexcom-g5-transmitter-start-date",
                title: Texts_BluetoothPeripheralView.transmittterStartDate,
                detail: dexcomG5.transmitterStartDate?.toStringInUserLocale(timeStyle: .none, dateStyle: .short) ?? "",
                showsDisclosure: dexcomG5.transmitterStartDate != nil,
                isEnabled: dexcomG5.transmitterStartDate != nil,
                action: { [weak self] in
                    self?.showDexcomG5TransmitterStartDateInfo(dexcomG5: dexcomG5)
                }
            ),
            row(
                id: "dexcom-g5-transmitter-expiry-date",
                title: Texts_BluetoothPeripheralView.transmittterExpiryDate,
                detail: dexcomG5TransmitterExpiryDate(dexcomG5: dexcomG5)?.toStringInUserLocale(timeStyle: .none, dateStyle: .short) ?? "-",
                showsDisclosure: dexcomG5TransmitterExpiryDate(dexcomG5: dexcomG5) != nil,
                isEnabled: dexcomG5TransmitterExpiryDate(dexcomG5: dexcomG5) != nil,
                action: { [weak self] in
                    self?.showDexcomG5TransmitterExpiryDateInfo(dexcomG5: dexcomG5)
                }
            ),
            row(
                id: "dexcom-g5-firmware",
                title: Texts_Common.firmware,
                detail: dexcomG5.firmwareVersion
            ),
            row(
                id: "dexcom-g5-sensor-status",
                title: Texts_Common.sensorStatus,
                detail: dexcomG5.sensorStatus,
                // Only the active transmitter should show a health indicator.
                // Stored inactive devices may have stale sensor status values.
                detailIndicator: dexcomG5.blePeripheral.shouldconnect ? sensorStatusDetailIndicator(for: dexcomG5.sensorStatus) : nil,
                showsDisclosure: dexcomG5.sensorStatus != nil,
                isEnabled: dexcomG5.sensorStatus != nil,
                action: { [weak self] in
                    self?.showInfo(title: Texts_Common.sensorStatus, message: dexcomG5.sensorStatus.map { "\n" + $0 })
                }
            )
        ]
    }

    func makeDexcomG5CoexistenceRows(dexcomG5: DexcomG5) -> [BluetoothPeripheralDetailRow] {
        [
            toggleRow(
                id: "dexcom-g5-use-other-app",
                title: Texts_BluetoothPeripheralView.useOtherDexcomApp,
                isOn: dexcomG5.useOtherApp,
                detailSymbol: BluetoothPeripheralDetailSymbol(
                    systemName: dexcomG5ModeSystemImage(useOtherApp: dexcomG5.useOtherApp),
                    color: Color(.colorSecondary)
                ),
                setValue: { [weak self] isOn in
                    self?.setDexcomG5UseOtherApp(isOn, dexcomG5: dexcomG5)
                }
            )
        ]
    }

    // Keep the two mode explanations separate so each line can carry its own mode symbol.
    // The active mode is first because it explains the current switch state.
    func dexcomG5CoexistenceFooterLines(dexcomG5: DexcomG5) -> [BluetoothPeripheralDetailFooterLine] {
        let coexistenceLine = BluetoothPeripheralDetailFooterLine(
            systemImage: "c.circle",
            text: Texts_BluetoothPeripheralView.useOtherDexcomAppCoexistenceFooter,
            isActive: dexcomG5.useOtherApp
        )

        let primaryLine = BluetoothPeripheralDetailFooterLine(
            systemImage: "p.circle",
            text: Texts_BluetoothPeripheralView.useOtherDexcomAppPrimaryFooter,
            isActive: !dexcomG5.useOtherApp
        )

        return dexcomG5.useOtherApp
            ? [coexistenceLine, primaryLine]
            : [primaryLine, coexistenceLine]
    }

    func makeDexcomG5BatteryRows(dexcomG5: DexcomG5) -> [BluetoothPeripheralDetailRow] {
        [
            row(
                id: "dexcom-g5-voltage-a",
                title: "Voltage A",
                detail: dexcomG5.voltageA != 0 ? dexcomG5.voltageA.description + "0 mV" : "Waiting for data..."
            ),
            row(
                id: "dexcom-g5-voltage-b",
                title: "Voltage B",
                detail: dexcomG5VoltageBText(dexcomG5: dexcomG5)
            )
        ]
    }

    func makeDexcomG5AnubisRows(dexcomG5: DexcomG5) -> [BluetoothPeripheralDetailRow] {
        [
            toggleRow(
                id: "dexcom-g5-reset-required",
                title: Texts_BluetoothPeripheralView.resetRequired,
                isOn: dexcomG5.resetRequired,
                setValue: { [weak self] isOn in
                    self?.setDexcomG5ResetRequired(isOn, dexcomG5: dexcomG5)
                }
            ),
            row(
                id: "dexcom-g5-last-reset-time",
                title: Texts_BluetoothPeripheralView.lastResetTimeStamp,
                detail: dexcomG5.lastResetTimeStamp?.toStringInUserLocale(timeStyle: .short, dateStyle: .short) ?? "-"
            ),
            row(
                id: "dexcom-g5-override-sensor-max-days",
                title: Texts_BluetoothPeripheralView.maxSensorAgeInDaysOverridenAnubis,
                detail: dexcomG5OverrideSensorMaxDaysText(),
                showsDisclosure: true,
                action: { [weak self] in
                    self?.requestDexcomG5OverrideSensorMaxDays()
                }
            )
        ]
    }

    func shouldShowDexcomG5SensorStartDate(dexcomG5: DexcomG5) -> Bool {
        dexcomG5.sensorStatus != DexcomAlgorithmState.SessionStopped.description
    }

    func dexcomG5SensorStartDateText(dexcomG5: DexcomG5) -> String {
        guard let startDate = dexcomG5.sensorStartDate, shouldShowDexcomG5SensorStartDate(dexcomG5: dexcomG5) else {
            return Texts_HomeView.notStarted
        }

        let sensorTimeInMinutes = -Int(startDate.timeIntervalSinceNow / 60)
        let minimumSensorWarmUpRequiredInMinutes = dexcomG5.isAnubis ? ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG6Anubis : ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG5G6

        if sensorTimeInMinutes < Int(minimumSensorWarmUpRequiredInMinutes) {
            let sensorReadyDateTime = startDate.addingTimeInterval(minimumSensorWarmUpRequiredInMinutes * 60)
            return Texts_BluetoothPeripheralView.warmingUpUntil + " " + sensorReadyDateTime.toStringInUserLocale(timeStyle: .short, dateStyle: .none)
        }

        return startDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short)
    }

    func dexcomG5TransmitterExpiryDate(dexcomG5: DexcomG5) -> Date? {
        dexcomG5.transmitterStartDate?.addingTimeInterval(60 * 60 * 24 * (dexcomG5.isAnubis ? ConstantsMaster.transmitterExpiryDaysDexcomG6Anubis : ConstantsMaster.transmitterExpiryDaysDexcomG5G6))
    }

    func dexcomG5VoltageBText(dexcomG5: DexcomG5) -> String {
        guard dexcomG5.voltageB != 0 else { return "Waiting for data..." }

        return dexcomG5.voltageB.description + "0 mV"
    }

    func dexcomG5OverrideSensorMaxDaysText() -> String {
        if let maxSensorAgeInDaysOverridenAnubis = UserDefaults.standard.activeSensorMaxSensorAgeInDaysOverridenAnubis, maxSensorAgeInDaysOverridenAnubis > 0 {
            return "\(maxSensorAgeInDaysOverridenAnubis.stringWithoutTrailingZeroes) \(Texts_Common.days)"
        }

        return "(\(Texts_Common.default0) \(ConstantsDexcomG5.maxSensorAgeInDays.stringWithoutTrailingZeroes) \(Texts_Common.days))"
    }

    func showDexcomG5SensorStartDateInfo(dexcomG5: DexcomG5) {
        guard let startDate = dexcomG5.sensorStartDate, shouldShowDexcomG5SensorStartDate(dexcomG5: dexcomG5) else { return }

        var startDateString = startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
        startDateString += "\n\n" + startDate.daysAndHoursAgo() + " " + Texts_HomeView.ago
        showInfo(title: Texts_BluetoothPeripheralView.sensorStartDate, message: "\n" + startDateString)
    }

    func showDexcomG5TransmitterStartDateInfo(dexcomG5: DexcomG5) {
        guard let startDate = dexcomG5.transmitterStartDate else { return }

        var startDateString = startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
        startDateString += "\n\n" + startDate.daysAndHoursAgo() + " " + Texts_HomeView.ago
        showInfo(title: Texts_BluetoothPeripheralView.transmittterStartDate, message: "\n" + startDateString)
    }

    func showDexcomG5TransmitterExpiryDateInfo(dexcomG5: DexcomG5) {
        guard let transmitterExpiryDate = dexcomG5TransmitterExpiryDate(dexcomG5: dexcomG5) else { return }

        let expiryDays = dexcomG5.isAnubis ? ConstantsMaster.transmitterExpiryDaysDexcomG6Anubis : ConstantsMaster.transmitterExpiryDaysDexcomG5G6
        var expiryDateString = transmitterExpiryDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
        expiryDateString += "\n\n" + transmitterExpiryDate.daysAndHoursRemaining(showOnlyDays: true) + " / " + expiryDays.stringWithoutTrailingZeroes + Texts_Common.dayshort + " " + Texts_HomeView.remaining
        expiryDateString += dexcomG5.isAnubis ? "\n\n Anubis" : ""
        showInfo(title: Texts_BluetoothPeripheralView.transmittterExpiryDate, message: "\n" + expiryDateString)
    }

    func setDexcomG5UseOtherApp(_ isOn: Bool, dexcomG5: DexcomG5) {
        dexcomG5.useOtherApp = isOn

        if let cGMG5Transmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: dexcomG5, createANewOneIfNecesssary: false) as? CGMG5Transmitter {
            cGMG5Transmitter.useOtherApp = isOn
            pendingAlert = BluetoothPeripheralDetailAlert(
                title: Texts_BluetoothPeripheralView.useOtherDexcomApp,
                message: isOn ? Texts_BluetoothPeripheralView.useOtherDexcomAppMessageEnabled : Texts_BluetoothPeripheralView.useOtherDexcomAppMessageDisabled
            )
        }

        refresh()
    }

    func setDexcomG5ResetRequired(_ isOn: Bool, dexcomG5: DexcomG5) {
        dexcomG5.resetRequired = isOn

        if let cGMG5Transmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: dexcomG5, createANewOneIfNecesssary: false) as? CGMG5Transmitter {
            cGMG5Transmitter.reset(requested: isOn)

            if isOn {
                pendingAlert = BluetoothPeripheralDetailAlert(
                    title: Texts_BluetoothPeripheralView.resetRequired,
                    message: Texts_SettingsView.resetDexcomTransmitterMessage
                )
            }
        }

        refresh()
    }

    func requestDexcomG5OverrideSensorMaxDays() {
        presentTextEntryView(BluetoothPeripheralTextEntry(
            title: Texts_BluetoothPeripheralView.maxSensorAgeInDaysOverridenAnubis,
            message: Texts_BluetoothPeripheralView.maxSensorAgeInDaysOverridenAnubisMessage,
            keyboardType: .numberPad,
            text: (UserDefaults.standard.activeSensorMaxSensorAgeInDaysOverridenAnubis ?? ConstantsDexcomG5.maxSensorAgeInDays).stringWithoutTrailingZeroes,
            placeholder: nil,
            actionTitle: Texts_Common.Ok,
            cancelTitle: Texts_Common.Cancel,
            actionHandler: { [weak self] value in
                self?.setDexcomG5OverrideSensorMaxDays(value)
            },
            actionIsEnabled: nil,
            inputValidator: nil
        ))
    }

    func setDexcomG5OverrideSensorMaxDays(_ value: String) {
        if let maxSensorAgeInDaysOverridenAnubis = Double(value),
           maxSensorAgeInDaysOverridenAnubis >= 0,
           maxSensorAgeInDaysOverridenAnubis <= ConstantsDexcomG5.maxSensorAgeInDaysOverridenAnubisMaximum {
            UserDefaults.standard.activeSensorMaxSensorAgeInDaysOverridenAnubis = maxSensorAgeInDaysOverridenAnubis
        }

        refresh()
    }
}

// MARK: - Dexcom G7/ONE+/Stelo

private extension BluetoothPeripheralDetailState {
    func makeDexcomG7Sections(bluetoothPeripheral: BluetoothPeripheral) -> [BluetoothPeripheralDetailSection] {
        guard let dexcomG7 = bluetoothPeripheral as? DexcomG7 else { return [] }

        var rows = [
            row(
                id: "dexcom-g7-sensor-start-date",
                title: Texts_BluetoothPeripheralView.sensorStartDate,
                detail: dexcomG7.sensorStartDate?.toStringInUserLocale(timeStyle: .none, dateStyle: .short) ?? ""
            ),
            row(
                id: "dexcom-g7-sensor-status",
                title: Texts_Common.sensorStatus,
                detail: dexcomG7.sensorStatus,
                // Only the active transmitter should show a health indicator.
                // Stored inactive devices may have stale sensor status values.
                detailIndicator: dexcomG7.blePeripheral.shouldconnect ? sensorStatusDetailIndicator(for: dexcomG7.sensorStatus) : nil
            )
        ]

        if UserDefaults.standard.activeSensorTransmitterId?.starts(with: "DXCM") == true {
            rows.append(toggleRow(
                id: "dexcom-g7-is-15-day",
                title: Texts_BluetoothPeripheralView.is15DayDexcomG7,
                isOn: UserDefaults.standard.is15DayDexcomG7,
                setValue: { isOn in
                    UserDefaults.standard.is15DayDexcomG7 = isOn
                }
            ))
        }

        return [
            BluetoothPeripheralDetailSection(
                id: "dexcom-g7",
                title: "Dexcom G7 / ONE+ / Stelo",
                rows: rows
            )
        ]
    }
}

// MARK: - Libre / Bubble / MiaoMiao

private extension BluetoothPeripheralDetailState {
    func makeLibre2Sections(bluetoothPeripheral: BluetoothPeripheral) -> [BluetoothPeripheralDetailSection] {
        guard let libre2 = bluetoothPeripheral as? Libre2 else { return [] }

        return [
            BluetoothPeripheralDetailSection(
                id: "libre-2",
                title: BluetoothPeripheralType.Libre2Type.rawValue,
                rows: [
                    row(
                        id: "libre-2-sensor-serial-number",
                        title: Texts_BluetoothPeripheralView.sensorSerialNumber,
                        detail: libre2.blePeripheral.sensorSerialNumber,
                        showsDisclosure: libre2.blePeripheral.sensorSerialNumber != nil,
                        isEnabled: libre2.blePeripheral.sensorSerialNumber != nil,
                        action: { [weak self] in
                            self?.showInfo(title: Texts_BluetoothPeripheralView.sensorSerialNumber, message: libre2.blePeripheral.sensorSerialNumber.map { "\n" + $0 })
                        }
                    ),
                    row(
                        id: "libre-2-sensor-start-time",
                        title: Texts_HomeView.sensorStart,
                        detail: libre2SensorStartText(libre2: libre2),
                        showsDisclosure: libre2.sensorTimeInMinutes != nil,
                        isEnabled: libre2.sensorTimeInMinutes != nil,
                        action: { [weak self] in
                            self?.showLibre2SensorStartTimeInfo(libre2: libre2)
                        }
                    )
                ]
            )
        ]
    }

    func libre2SensorStartText(libre2: Libre2) -> String {
        guard let sensorTimeInMinutes = libre2.sensorTimeInMinutes else {
            return "Not Connected"
        }

        let startDate = Date(timeIntervalSinceNow: -Double(sensorTimeInMinutes * 60))

        if sensorTimeInMinutes < Int(ConstantsMaster.minimumSensorWarmUpRequiredInMinutes) {
            let sensorReadyDateTime = startDate.addingTimeInterval(ConstantsMaster.minimumSensorWarmUpRequiredInMinutes * 60)
            return Texts_BluetoothPeripheralView.warmingUpUntil + " " + sensorReadyDateTime.toStringInUserLocale(timeStyle: .short, dateStyle: .none)
        }

        return startDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short)
    }

    func showLibre2SensorStartTimeInfo(libre2: Libre2) {
        guard let sensorTimeInMinutes = libre2.sensorTimeInMinutes else { return }

        let startDate = Date(timeIntervalSinceNow: -Double(sensorTimeInMinutes * 60))
        var sensorStartTimeText = startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
        sensorStartTimeText += "\n\n" + startDate.daysAndHoursAgo() + " " + Texts_HomeView.ago
        showInfo(title: Texts_BluetoothPeripheralView.sensorStartDate, message: "\n" + sensorStartTimeText)
    }

    func makeMiaoMiaoSections(bluetoothPeripheral: BluetoothPeripheral) -> [BluetoothPeripheralDetailSection] {
        guard let miaoMiao = bluetoothPeripheral as? MiaoMiao else { return [] }

        return [
            BluetoothPeripheralDetailSection(
                id: "miaomiao",
                title: BluetoothPeripheralType.MiaoMiaoType.rawValue,
                rows: makeLibreBridgeRows(
                    idPrefix: "miaomiao",
                    sensorType: miaoMiao.blePeripheral.libreSensorType?.description,
                    sensorSerialNumber: miaoMiao.blePeripheral.sensorSerialNumber,
                    sensorState: miaoMiao.sensorState.translatedDescription,
                    batteryLevel: miaoMiao.batteryLevel,
                    firmware: miaoMiao.firmware,
                    hardware: miaoMiao.hardware
                )
            )
        ]
    }

    func makeBubbleSections(bluetoothPeripheral: BluetoothPeripheral) -> [BluetoothPeripheralDetailSection] {
        guard let bubble = bluetoothPeripheral as? Bubble else { return [] }

        return [
            BluetoothPeripheralDetailSection(
                id: "bubble",
                title: BluetoothPeripheralType.BubbleType.rawValue,
                rows: makeLibreBridgeRows(
                    idPrefix: "bubble",
                    sensorType: bubble.blePeripheral.libreSensorType?.description,
                    sensorSerialNumber: bubble.blePeripheral.sensorSerialNumber ?? Texts_Common.unknown,
                    sensorState: bubble.sensorState.translatedDescription,
                    batteryLevel: bubble.batteryLevel,
                    firmware: bubble.firmware,
                    hardware: bubble.hardware
                )
            )
        ]
    }

    func makeMedtrumTouchCareNanoSections(bluetoothPeripheral: BluetoothPeripheral) -> [BluetoothPeripheralDetailSection] {
        guard let medtrumNano = bluetoothPeripheral as? MedtrumTouchCareNano else { return [] }

        return [
            BluetoothPeripheralDetailSection(
                id: "medtrum-touchcare-nano",
                title: BluetoothPeripheralType.MedtrumTouchCareNanoType.rawValue,
                rows: [
                    row(
                        id: "medtrum-touchcare-nano-dependency",
                        title: "Requires Medtrum EasyPatch",
                        detail: "EasyPatch must be installed and running for sensor data."
                    ),
                    row(
                        id: "medtrum-touchcare-nano-firmware",
                        title: Texts_Common.firmware,
                        detail: medtrumNano.firmware
                    )
                ]
            )
        ]
    }

    func makeLibreBridgeRows(
        idPrefix: String,
        sensorType: String?,
        sensorSerialNumber: String?,
        sensorState: String?,
        batteryLevel: Int,
        firmware: String?,
        hardware: String?
    ) -> [BluetoothPeripheralDetailRow] {
        [
            row(id: "\(idPrefix)-sensor-type", title: Texts_BluetoothPeripheralView.sensorType, detail: sensorType),
            row(
                id: "\(idPrefix)-sensor-serial-number",
                title: Texts_BluetoothPeripheralView.sensorSerialNumber,
                detail: sensorSerialNumber,
                showsDisclosure: sensorSerialNumber != nil && sensorSerialNumber != Texts_Common.unknown,
                isEnabled: sensorSerialNumber != nil && sensorSerialNumber != Texts_Common.unknown,
                action: { [weak self] in
                    self?.showInfo(title: Texts_HomeView.info, message: sensorSerialNumber.map { Texts_BluetoothPeripheralView.sensorSerialNumber + " " + $0 })
                }
            ),
            row(id: "\(idPrefix)-sensor-state", title: Texts_Common.sensorStatus, detail: sensorState),
            row(
                id: "\(idPrefix)-battery-level",
                title: Texts_BluetoothPeripheralsView.batteryLevel,
                detail: batteryLevel > 0 ? batteryLevel.description + " %" : "",
                detailSymbol: batterySymbol(percent: batteryLevel)
            ),
            row(
                id: "\(idPrefix)-firmware",
                title: Texts_Common.firmware,
                detail: firmware,
                showsDisclosure: firmware != nil,
                isEnabled: firmware != nil,
                action: { [weak self] in
                    self?.showInfo(title: Texts_HomeView.info, message: firmware.map { Texts_Common.firmware + ": " + $0 })
                }
            ),
            row(
                id: "\(idPrefix)-hardware",
                title: Texts_Common.hardware,
                detail: hardware,
                showsDisclosure: hardware != nil,
                isEnabled: hardware != nil,
                action: { [weak self] in
                    self?.showInfo(title: Texts_HomeView.info, message: hardware.map { Texts_Common.hardware + ": " + $0 })
                }
            )
        ]
    }
}

// MARK: - M5Stack / M5StickC

private extension BluetoothPeripheralDetailState {
    func makeM5StackSections(bluetoothPeripheral: BluetoothPeripheral, includesSpecificM5StackSection: Bool) -> [BluetoothPeripheralDetailSection] {
        guard let m5Stack = bluetoothPeripheral as? M5Stack else { return [] }

        var sections = [
            BluetoothPeripheralDetailSection(
                id: "m5-common",
                title: "M5",
                rows: makeM5CommonRows(m5Stack: m5Stack, isM5StickC: !includesSpecificM5StackSection)
            )
        ]

        if includesSpecificM5StackSection {
            sections.append(BluetoothPeripheralDetailSection(
                id: "m5-stack-specific",
                title: "M5Stack",
                rows: makeM5StackSpecificRows(m5Stack: m5Stack)
            ))
        }

        return sections
    }

    func makeM5CommonRows(m5Stack: M5Stack, isM5StickC: Bool) -> [BluetoothPeripheralDetailRow] {
        [
            row(
                id: "m5-help",
                title: isM5StickC ? Texts_M5StackView.m5StickCSoftWhereHelpCellText : Texts_M5StackView.m5StackSoftWhereHelpCellText,
                showsDisclosure: true,
                action: { [weak self] in
                    let url = isM5StickC ? ConstantsM5Stack.githubURLM5StickC : ConstantsM5Stack.githubURLM5Stack
                    self?.showInfo(title: Texts_HomeView.info, message: Texts_M5StackView.m5StackSoftWareHelpText + " " + url)
                }
            ),
            row(id: "m5-password", title: Texts_Common.password, detail: m5Stack.blepassword),
            row(
                id: "m5-text-color",
                title: Texts_SettingsView.m5StackTextColor,
                detail: m5TextColorText(m5Stack: m5Stack),
                showsDisclosure: true,
                action: { [weak self] in
                    self?.requestM5TextColor(m5Stack: m5Stack)
                }
            ),
            row(
                id: "m5-background-color",
                title: Texts_SettingsView.m5StackbackGroundColor,
                detail: m5BackgroundColorText(m5Stack: m5Stack),
                showsDisclosure: true,
                action: { [weak self] in
                    self?.requestM5BackgroundColor(m5Stack: m5Stack)
                }
            ),
            row(
                id: "m5-rotation",
                title: Texts_SettingsView.m5StackRotation,
                detail: m5StackRotationStrings[Int(m5Stack.rotation)],
                showsDisclosure: true,
                action: { [weak self] in
                    self?.requestM5Rotation(m5Stack: m5Stack)
                }
            ),
            toggleRow(
                id: "m5-connect-to-wifi",
                title: Texts_M5StackView.connectToWiFi,
                isOn: m5Stack.connectToWiFi,
                setValue: { [weak self] isOn in
                    self?.setM5ConnectToWiFi(isOn, m5Stack: m5Stack)
                }
            )
        ]
    }

    func makeM5StackSpecificRows(m5Stack: M5Stack) -> [BluetoothPeripheralDetailRow] {
        [
            row(
                id: "m5-battery-level",
                title: Texts_BluetoothPeripheralsView.batteryLevel,
                detail: m5Stack.batteryLevel > 0 ? m5Stack.batteryLevel.description + " %" : "",
                detailSymbol: batterySymbol(percent: m5Stack.batteryLevel)
            ),
            row(
                id: "m5-brightness",
                title: Texts_SettingsView.m5StackBrightness,
                detail: m5StackBrightnessStrings[Int(m5Stack.brightness / 10)],
                showsDisclosure: true,
                action: { [weak self] in
                    self?.requestM5Brightness(m5Stack: m5Stack)
                }
            ),
            row(
                id: "m5-power-off",
                title: Texts_M5StackView.powerOff,
                showsDisclosure: true,
                action: { [weak self] in
                    self?.requestM5PowerOff(m5Stack: m5Stack)
                }
            )
        ]
    }

    func m5TextColorText(m5Stack: M5Stack) -> String {
        if let textColor = M5StackColor(forUInt16: UInt16(m5Stack.textcolor)) {
            return textColor.description
        }

        return UserDefaults.standard.m5StackTextColor?.description ?? ConstantsM5Stack.defaultTextColor.description
    }

    func m5BackgroundColorText(m5Stack: M5Stack) -> String {
        M5StackColor(forUInt16: UInt16(m5Stack.backGroundColor))?.description ?? ConstantsM5Stack.defaultBackGroundColor.description
    }

    func requestM5TextColor(m5Stack: M5Stack) {
        let colors = M5StackColor.allCases
        let data = colors.map { $0.description }
        let selectedRow = M5StackColor(forUInt16: UInt16(m5Stack.textcolor)).flatMap { data.firstIndex(of: $0.description) } ?? UserDefaults.standard.m5StackTextColor.flatMap { data.firstIndex(of: $0.description) }

        presentSelectionListView(BluetoothPeripheralSelectionList(title: Texts_SettingsView.m5StackTextColor, data: data, selectedRow: selectedRow) { [weak self] index in
            self?.setM5TextColor(colors[index], selectedRow: selectedRow, selectedIndex: index, m5Stack: m5Stack)
        })
    }

    func requestM5BackgroundColor(m5Stack: M5Stack) {
        let colors = M5StackColor.allCases
        let data = colors.map { $0.description }
        let selectedRow = M5StackColor(forUInt16: UInt16(m5Stack.backGroundColor)).flatMap { data.firstIndex(of: $0.description) } ?? data.firstIndex(of: ConstantsM5Stack.defaultBackGroundColor.description)

        presentSelectionListView(BluetoothPeripheralSelectionList(title: Texts_SettingsView.m5StackbackGroundColor, data: data, selectedRow: selectedRow) { [weak self] index in
            self?.setM5BackgroundColor(colors[index], selectedRow: selectedRow, selectedIndex: index, m5Stack: m5Stack)
        })
    }

    func requestM5Rotation(m5Stack: M5Stack) {
        let selectedRow = Int(m5Stack.rotation)

        presentSelectionListView(BluetoothPeripheralSelectionList(title: Texts_SettingsView.m5StackRotation, data: m5StackRotationStrings, selectedRow: selectedRow) { [weak self] index in
            self?.setM5Rotation(index, selectedRow: selectedRow, m5Stack: m5Stack)
        })
    }

    func requestM5Brightness(m5Stack: M5Stack) {
        let selectedRow = Int(m5Stack.brightness / 10)

        presentSelectionListView(BluetoothPeripheralSelectionList(title: Texts_SettingsView.m5StackBrightness, data: m5StackBrightnessStrings, selectedRow: selectedRow) { [weak self] index in
            self?.setM5Brightness(index, selectedRow: selectedRow, m5Stack: m5Stack)
        })
    }

    func requestM5PowerOff(m5Stack: M5Stack) {
        guard let m5StackBluetoothTransmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false) as? M5StackBluetoothTransmitter,
              m5StackBluetoothTransmitter.getConnectionStatus() == .connected
        else {
            pendingAlert = BluetoothPeripheralDetailAlert(title: Texts_Common.warning, message: Texts_M5StackView.deviceMustBeConnectedToPowerOff)
            return
        }

        pendingAlert = BluetoothPeripheralDetailAlert(
            title: Texts_M5StackView.powerOffConfirm,
            message: "",
            primaryButtonTitle: Texts_Common.Ok,
            primaryAction: {
                _ = m5StackBluetoothTransmitter.powerOff()
            },
            secondaryButtonTitle: Texts_Common.Cancel
        )
    }

    func setM5TextColor(_ color: M5StackColor, selectedRow: Int?, selectedIndex: Int, m5Stack: M5Stack) {
        guard selectedIndex != selectedRow else { return }

        m5Stack.textcolor = Int32(color.rawValue)

        if let m5StackBluetoothTransmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false) as? M5StackBluetoothTransmitter,
           m5StackBluetoothTransmitter.writeTextColor(textColor: color) {
            refresh()
        } else {
            m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect = true
            refresh()
        }
    }

    func setM5BackgroundColor(_ color: M5StackColor, selectedRow: Int?, selectedIndex: Int, m5Stack: M5Stack) {
        guard selectedIndex != selectedRow else { return }

        m5Stack.backGroundColor = Int32(color.rawValue)

        if let m5StackBluetoothTransmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false) as? M5StackBluetoothTransmitter,
           m5StackBluetoothTransmitter.writeBackGroundColor(backGroundColor: color) {
            refresh()
        } else {
            m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect = true
            refresh()
        }
    }

    func setM5Rotation(_ rotation: Int, selectedRow: Int?, m5Stack: M5Stack) {
        guard rotation != selectedRow else { return }

        m5Stack.rotation = Int32(UInt16(rotation))

        if let m5StackBluetoothTransmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false) as? M5StackBluetoothTransmitter,
           m5StackBluetoothTransmitter.writeRotation(rotation: rotation) {
            refresh()
        } else {
            m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect = true
            refresh()
        }
    }

    func setM5Brightness(_ brightnessIndex: Int, selectedRow: Int?, m5Stack: M5Stack) {
        guard brightnessIndex != selectedRow else { return }

        m5Stack.brightness = Int16(brightnessIndex * 10)

        if let m5StackBluetoothTransmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false) as? M5StackBluetoothTransmitter,
           m5StackBluetoothTransmitter.writeBrightness(brightness: brightnessIndex * 10) {
            refresh()
        } else {
            m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect = true
            refresh()
        }
    }

    func setM5ConnectToWiFi(_ isOn: Bool, m5Stack: M5Stack) {
        m5Stack.connectToWiFi = isOn

        if let m5StackBluetoothTransmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false) as? M5StackBluetoothTransmitter,
           m5StackBluetoothTransmitter.writeConnectToWiFi(connect: isOn) {
            refresh()
        } else {
            m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect = true
            refresh()
        }
    }
}

// MARK: - Delegate Wiring

private extension BluetoothPeripheralDetailState {
    func configureTransmitterDelegates() {
        guard let bluetoothPeripheral = bluetoothPeripheral,
              let bluetoothTransmitter = bluetoothPeripheralManager?.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false)
        else {
            return
        }

        bluetoothTransmitter.bluetoothTransmitterDelegate = self
        configureSpecificDelegate(for: bluetoothTransmitter)
    }

    func configureSpecificDelegate(for bluetoothTransmitter: BluetoothTransmitter) {
        if let m5StackBluetoothTransmitter = bluetoothTransmitter as? M5StackBluetoothTransmitter {
            m5StackBluetoothTransmitter.m5StackBluetoothTransmitterDelegate = self
            _ = m5StackBluetoothTransmitter.readBatteryLevel()
        } else if let cGMG5Transmitter = bluetoothTransmitter as? CGMG5Transmitter {
            cGMG5Transmitter.cGMG5TransmitterDelegate = self
        } else if let cGMG7Transmitter = bluetoothTransmitter as? CGMG7Transmitter {
            cGMG7Transmitter.cGMG7TransmitterDelegate = self
        } else if let cGMLibre2Transmitter = bluetoothTransmitter as? CGMLibre2Transmitter {
            cGMLibre2Transmitter.cGMLibre2TransmitterDelegate = self
        } else if let cGMMiaoMiaoTransmitter = bluetoothTransmitter as? CGMMiaoMiaoTransmitter {
            cGMMiaoMiaoTransmitter.cGMMiaoMiaoTransmitterDelegate = self
        } else if let cGMBubbleTransmitter = bluetoothTransmitter as? CGMBubbleTransmitter {
            cGMBubbleTransmitter.cGMBubbleTransmitterDelegate = self
        }
    }

    func reassignTransmitterDelegatesToBluetoothPeripheralManager() {
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager,
              let bluetoothPeripheral = bluetoothPeripheral,
              let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false)
        else {
            return
        }

        bluetoothTransmitter.bluetoothTransmitterDelegate = bluetoothPeripheralManager

        if let m5StackBluetoothTransmitter = bluetoothTransmitter as? M5StackBluetoothTransmitter {
            m5StackBluetoothTransmitter.m5StackBluetoothTransmitterDelegate = bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate
        } else if let cGMG5Transmitter = bluetoothTransmitter as? CGMG5Transmitter {
            cGMG5Transmitter.cGMG5TransmitterDelegate = bluetoothPeripheralManager as? CGMG5TransmitterDelegate
        } else if let cGMG7Transmitter = bluetoothTransmitter as? CGMG7Transmitter {
            cGMG7Transmitter.cGMG7TransmitterDelegate = bluetoothPeripheralManager as? CGMG7TransmitterDelegate
        } else if let cGMLibre2Transmitter = bluetoothTransmitter as? CGMLibre2Transmitter {
            cGMLibre2Transmitter.cGMLibre2TransmitterDelegate = bluetoothPeripheralManager as? CGMLibre2TransmitterDelegate
        } else if let cGMMiaoMiaoTransmitter = bluetoothTransmitter as? CGMMiaoMiaoTransmitter {
            cGMMiaoMiaoTransmitter.cGMMiaoMiaoTransmitterDelegate = bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate
        } else if let cGMBubbleTransmitter = bluetoothTransmitter as? CGMBubbleTransmitter {
            cGMBubbleTransmitter.cGMBubbleTransmitterDelegate = bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate
        }
    }

    func refreshOnMain() {
        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }

    func showInfo(title: String, message: String?) {
        guard let message = message else { return }

        pendingAlert = BluetoothPeripheralDetailAlert(title: title, message: message)
    }
}

// MARK: - Generic Bluetooth Delegate

extension BluetoothPeripheralDetailState: BluetoothTransmitterDelegate {
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralManager?.didConnectTo(bluetoothTransmitter: bluetoothTransmitter)
        refreshOnMain()
    }

    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralManager?.didDisconnectFrom(bluetoothTransmitter: bluetoothTransmitter)
        refreshOnMain()
    }

    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralManager?.deviceDidUpdateBluetoothState(state: state, bluetoothTransmitter: bluetoothTransmitter)
        refreshOnMain()
    }

    func transmitterNeedsPairing(bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralManager?.transmitterNeedsPairing(bluetoothTransmitter: bluetoothTransmitter)
    }

    func successfullyPaired() {
        bluetoothPeripheralManager?.successfullyPaired()
    }

    func pairingFailed() {
        bluetoothPeripheralManager?.pairingFailed()
    }

    func error(message: String) {
        bluetoothPeripheralManager?.error(message: message)

        DispatchQueue.main.async { [weak self] in
            self?.pendingAlert = BluetoothPeripheralDetailAlert(title: Texts_Common.warning, message: message)
        }
    }

    func heartBeat() {
        bluetoothPeripheralManager?.heartBeat()
    }
}

// MARK: - Specific Transmitter Delegates

extension BluetoothPeripheralDetailState: M5StackBluetoothTransmitterDelegate {
    func receivedBattery(level: Int, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.receivedBattery(level: level, m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
        refreshOnMain()
    }

    func isAskingForAllParameters(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.isAskingForAllParameters(m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
    }

    func isReadyToReceiveData(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.isReadyToReceiveData(m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
    }

    func newBlePassWord(newBlePassword: String, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.newBlePassWord(newBlePassword: newBlePassword, m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)

        if let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack {
            m5StackPeripheral.blepassword = newBlePassword
        }

        refreshOnMain()
    }

    func authentication(success: Bool, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.authentication(success: success, m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)

        guard !success, let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack else { return }

        DispatchQueue.main.async { [weak self] in
            self?.pendingAlert = BluetoothPeripheralDetailAlert(
                title: Texts_Common.warning,
                message: Texts_M5StackView.authenticationFailureWarning + " " + Texts_BluetoothPeripheralView.connect,
                primaryAction: {
                    self?.setShouldConnectToFalse(for: m5StackPeripheral, askUser: false)
                }
            )
        }
    }

    func blePasswordMissing(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.blePasswordMissing(m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
        showM5AuthenticationWarning(for: m5StackBluetoothTransmitter, message: Texts_M5StackView.authenticationFailureWarning + " " + Texts_BluetoothPeripheralView.connect)
    }

    func m5StackResetRequired(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.m5StackResetRequired(m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
        showM5AuthenticationWarning(for: m5StackBluetoothTransmitter, message: Texts_M5StackView.m5StackResetRequiredWarning + " " + Texts_BluetoothPeripheralView.connect)
    }

    private func showM5AuthenticationWarning(for m5StackBluetoothTransmitter: M5StackBluetoothTransmitter, message: String) {
        guard let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack else { return }

        DispatchQueue.main.async { [weak self] in
            self?.pendingAlert = BluetoothPeripheralDetailAlert(
                title: Texts_Common.warning,
                message: message,
                primaryAction: {
                    self?.setShouldConnectToFalse(for: m5StackPeripheral, askUser: false)
                }
            )
        }
    }
}

extension BluetoothPeripheralDetailState: CGMG5TransmitterDelegate {
    func reset(for cGMG5Transmitter: CGMG5Transmitter, successful: Bool) {
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.reset(for: cGMG5Transmitter, successful: successful)

        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = successful ? Texts_HomeView.info : Texts_Common.warning
        notificationContent.body = Texts_BluetoothPeripheralView.transmitterResetResult + " : " + (successful ? Texts_HomeView.success : Texts_HomeView.failed)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: ConstantsNotifications.NotificationIdentifierForResetResult.transmitterResetResult, content: notificationContent, trigger: nil))

        refreshOnMain()
    }

    func received(transmitterBatteryInfo: TransmitterBatteryInfo, cGMG5Transmitter: CGMG5Transmitter) {
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(transmitterBatteryInfo: transmitterBatteryInfo, cGMG5Transmitter: cGMG5Transmitter)
        refreshOnMain()
    }

    func received(firmware: String, cGMG5Transmitter: CGMG5Transmitter) {
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(firmware: firmware, cGMG5Transmitter: cGMG5Transmitter)
        refreshOnMain()
    }

    func received(transmitterStartDate: Date, cGMG5Transmitter: CGMG5Transmitter) {
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(transmitterStartDate: transmitterStartDate, cGMG5Transmitter: cGMG5Transmitter)
        refreshOnMain()
    }

    func received(sensorStartDate: Date?, cGMG5Transmitter: CGMG5Transmitter) {
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(sensorStartDate: sensorStartDate, cGMG5Transmitter: cGMG5Transmitter)
        refreshOnMain()
    }

    func received(sensorStatus: String?, cGMG5Transmitter: CGMG5Transmitter) {
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(sensorStatus: sensorStatus, cGMG5Transmitter: cGMG5Transmitter)
        refreshOnMain()
    }

    func received(isAnubis: Bool, cGMG5Transmitter: CGMG5Transmitter) {
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(isAnubis: isAnubis, cGMG5Transmitter: cGMG5Transmitter)
        refreshOnMain()
    }
}

extension BluetoothPeripheralDetailState: CGMG7TransmitterDelegate {
    func received(sensorStartDate: Date?, cGMG7Transmitter: CGMG7Transmitter) {
        (bluetoothPeripheralManager as? CGMG7TransmitterDelegate)?.received(sensorStartDate: sensorStartDate, cGMG7Transmitter: cGMG7Transmitter)
        refreshOnMain()
    }

    func received(sensorStatus: String?, cGMG7Transmitter: CGMG7Transmitter) {
        (bluetoothPeripheralManager as? CGMG7TransmitterDelegate)?.received(sensorStatus: sensorStatus, cGMG7Transmitter: cGMG7Transmitter)
        refreshOnMain()
    }
}

extension BluetoothPeripheralDetailState: CGMLibre2TransmitterDelegate {
    func received(sensorTimeInMinutes: Int, from cGMLibre2Transmitter: CGMLibre2Transmitter) {
        (bluetoothPeripheralManager as? CGMLibre2TransmitterDelegate)?.received(sensorTimeInMinutes: sensorTimeInMinutes, from: cGMLibre2Transmitter)
        refreshOnMain()
    }

    func received(serialNumber: String, from cGMLibre2Transmitter: CGMLibre2Transmitter) {
        (bluetoothPeripheralManager as? CGMLibre2TransmitterDelegate)?.received(serialNumber: serialNumber, from: cGMLibre2Transmitter)
        refreshOnMain()
    }
}

extension BluetoothPeripheralDetailState: CGMMiaoMiaoTransmitterDelegate {
    func received(libreSensorType: LibreSensorType, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(libreSensorType: libreSensorType, from: cGMMiaoMiaoTransmitter)
        refreshOnMain()
    }

    func received(serialNumber: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(serialNumber: serialNumber, from: cGMMiaoMiaoTransmitter)
        refreshOnMain()
    }

    func received(batteryLevel: Int, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(batteryLevel: batteryLevel, from: cGMMiaoMiaoTransmitter)
        refreshOnMain()
    }

    func received(sensorStatus: LibreSensorState, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(sensorStatus: sensorStatus, from: cGMMiaoMiaoTransmitter)
        refreshOnMain()
    }

    func received(firmware: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(firmware: firmware, from: cGMMiaoMiaoTransmitter)
        refreshOnMain()
    }

    func received(hardware: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(hardware: hardware, from: cGMMiaoMiaoTransmitter)
        refreshOnMain()
    }
}

extension BluetoothPeripheralDetailState: CGMBubbleTransmitterDelegate {
    func received(batteryLevel: Int, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(batteryLevel: batteryLevel, from: cGMBubbleTransmitter)
        refreshOnMain()
    }

    func received(sensorStatus: LibreSensorState, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(sensorStatus: sensorStatus, from: cGMBubbleTransmitter)
        refreshOnMain()
    }

    func received(serialNumber: String, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(serialNumber: serialNumber, from: cGMBubbleTransmitter)
        refreshOnMain()
    }

    func received(firmware: String, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(firmware: firmware, from: cGMBubbleTransmitter)
        refreshOnMain()
    }

    func received(hardware: String, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(hardware: hardware, from: cGMBubbleTransmitter)
        refreshOnMain()
    }

    func received(libreSensorType: LibreSensorType, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(libreSensorType: libreSensorType, from: cGMBubbleTransmitter)
        refreshOnMain()
    }
}
