//
//  RootTabView.swift
//  xdrip
//
//  Created by Paul Plant on 11/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import os
import SwiftUI
import UIKit

// MARK: - Layout

/// Layout values shared by the root tabs.
private enum RootTabLayout {
    static let contentBottomPadding: CGFloat = 4
}

/// Window-based layout classes shared by iPad screens. An iPad in Slide Over deliberately receives
/// the compact composition, and accessibility text avoids dense multi-column arrangements.
enum IPadLayoutClass: Equatable {
    case compact
    case regular
    case wide

    static func resolve(isPad: Bool, width: CGFloat, usesAccessibilityText: Bool) -> Self {
        guard isPad, !usesAccessibilityText else { return .compact }
        if width >= 980 { return .wide }
        if width >= 650 { return .regular }
        return .compact
    }
}

enum RootOrientationPolicy {
    static func supportedOrientations(isPad: Bool, isHome: Bool, allowsHomeRotation: Bool) -> UIInterfaceOrientationMask {
        if isPad { return .all }
        return isHome && allowsHomeRotation ? .allButUpsideDown : .portrait
    }
}

// MARK: - Presentation Requests

/// Simple application alert requested by a manager or delegate callback.
struct RootAlertRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let actionTitle: String
    let cancelTitle: String?
    let action: () -> Void
    let cancel: () -> Void
}

/// Text entry requested outside the visible SwiftUI hierarchy, currently used for calibration.
struct RootTextInputRequest: Identifiable {
    let id = UUID()
    let title: String
    let placeholder: String
    let usesDecimalKeyboard: Bool
    let action: (String) -> Void
}

/// A backup document copied into this app instance and waiting for the restore screen.
struct IncomingBackupRequest: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Application Dependencies

/// Services needed by the native SwiftUI tabs after application startup has completed.
///
/// The coordinator creates these services once. Keeping the references together prevents views
/// from creating duplicate managers as the user changes tabs.
struct RootTabDependencies {
    let coreDataManager: CoreDataManager
    let statisticsManager: StatisticsManager
    let bgReadingsAccessor: BgReadingsAccessor
    let calibrationsAccessor: CalibrationsAccessor
    let treatmentEntryAccessor: TreatmentEntryAccessor
    let alertManager: AlertManager
    let bgPostProcessingManager: BgPostProcessingManager
    let sensorNoiseManager: SensorNoiseManager
    let sensorHealthIssueManager: SensorHealthIssueManager
    let bluetoothPeripheralManager: BluetoothPeripheralManaging
    let soundPlayer: SoundPlayer
    let nightscoutSyncManager: NightscoutSyncManager
    let rootHomeStateModel: RootHomeStateModel
    let rootHomeActions: RootHomeActions
    let activeSensorProvider: () -> Sensor?
    let transmitterProvider: () -> CGMTransmitter?
    let startSensor: (SensorStartRequest) -> Void
    let stopSensor: () -> Void
    let submitCalibration: (CalibrationSubmission) -> String?
    let updateScreenLock: (Bool, Bool) -> Bool
    let selectedFollowerActions: SelectedFollowerActions

    /// Cancels either screen-lock mode without accidentally enabling it when it is already off.
    func cancelScreenLock() {
        guard rootHomeStateModel.state.isScreenLocked else { return }

        _ = updateScreenLock(false, true)
    }
}

/// Publishes existing application services to the SwiftUI tab hierarchy.
///
/// `RootApplicationCoordinator` owns the services. This state model publishes their references once
/// asynchronous Core Data setup has completed. It never creates a second manager or mirrors data.
@MainActor final class RootTabStateModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var dependencies: RootTabDependencies?
    @Published private(set) var snoozeDismissalRequest = 0
    @Published private(set) var incomingBackupRequest: IncomingBackupRequest?
    @Published private(set) var isPreparingIncomingBackup = false
    @Published private(set) var alertRequest: RootAlertRequest?
    @Published private(set) var sensorHealthHomeRequest = 0
    @Published var textInputRequest: RootTextInputRequest?
    @Published var textInput = ""
    @Published var pickerData: SnoozePickerData?
    weak var sensorProvider: ActiveSensorProviding?
    private var pendingAlertRequests: [RootAlertRequest] = []
    private var isAdvancingAlertQueue = false
    private var isAlertDismissalPending = false
    private let dataManagementLog = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categoryDataManagement
    )

    // MARK: - Presentation

    func dismissSnooze() {
        snoozeDismissalRequest += 1
    }

    func presentAlert(
        title: String,
        message: String,
        actionTitle: String = Texts_Common.Ok,
        cancelTitle: String? = nil,
        action: @escaping () -> Void = {},
        cancel: @escaping () -> Void = {}
    ) {
        let request = RootAlertRequest(
            title: title,
            message: message,
            actionTitle: actionTitle,
            cancelTitle: cancelTitle,
            action: action,
            cancel: cancel
        )

        // SwiftUI cannot replace an alert while the previous UIKit presentation is still dismissing
        guard alertRequest == nil, !isAdvancingAlertQueue else {
            pendingAlertRequests.append(request)
            return
        }

        alertRequest = request
    }

    /// Clears a dismissed alert and presents the next request after UIKit has finished its dismissal.
    func updatePresentedAlert(_ request: RootAlertRequest?) {
        guard request == nil, !isAlertDismissalPending else { return }
        isAlertDismissalPending = true

        Task { @MainActor in
            // defer publication until SwiftUI has completed the current alert update
            await Task.yield()
            alertRequest = nil
            isAlertDismissalPending = false

            guard !pendingAlertRequests.isEmpty else {
                isAdvancingAlertQueue = false
                return
            }

            isAdvancingAlertQueue = true
            let nextRequest = pendingAlertRequests.removeFirst()
            try? await Task.sleep(nanoseconds: 300_000_000)
            alertRequest = nextRequest
            isAdvancingAlertQueue = false
        }
    }

    func presentTextInput(
        title: String,
        placeholder: String,
        usesDecimalKeyboard: Bool,
        action: @escaping (String) -> Void
    ) {
        textInput = ""
        textInputRequest = RootTextInputRequest(
            title: title,
            placeholder: placeholder,
            usesDecimalKeyboard: usesDecimalKeyboard,
            action: action
        )
    }

    func presentPicker(_ pickerViewData: PickerViewData) {
        pickerData = SnoozePickerData(pickerViewData)
    }

    /// Returns a notification tap to Home without bypassing the active in-app banner.
    /// The banner owns navigation to Sensor Management or Bluetooth detail.
    func showHomeForSensorHealthNotification() {
        sensorHealthHomeRequest += 1
    }

    /// Copies a document supplied by iOS before handing it to the restore workflow.
    func receiveIncomingBackup(_ sourceURL: URL) {
        // The Live Activity uses xdripswift://open only to bring the app to the foreground.
        guard sourceURL.isFileURL,
              sourceURL.pathExtension.caseInsensitiveCompare("xdripbackup") == .orderedSame else { return }

        guard !isPreparingIncomingBackup else { return }

        isPreparingIncomingBackup = true
        trace(
            "in receiveIncomingBackup, received backup document",
            log: dataManagementLog,
            category: ConstantsLog.categoryDataManagement,
            type: .info
        )

        Task {
            do {
                let localURL = try await Task.detached(priority: .userInitiated) {
                    try BackupService.copyIncomingBackup(from: sourceURL)
                }.value
                incomingBackupRequest = IncomingBackupRequest(url: localURL)
                isPreparingIncomingBackup = false
                trace(
                    "in receiveIncomingBackup, copied backup document and requested restore screen",
                    log: dataManagementLog,
                    category: ConstantsLog.categoryDataManagement,
                    type: .info
                )
            } catch {
                isPreparingIncomingBackup = false
                let description = (error as? BackupError)?.traceDescription ?? String(describing: type(of: error))
                trace(
                    "in receiveIncomingBackup, failed. error = %{public}@",
                    log: dataManagementLog,
                    category: ConstantsLog.categoryDataManagement,
                    type: .error,
                    description
                )
                presentAlert(title: "Backup & Restore", message: error.localizedDescription)
            }
        }
    }

    /// Clears a request after the Settings navigation stack has accepted it.
    func consumeIncomingBackup(id: UUID) {
        guard incomingBackupRequest?.id == id else { return }
        incomingBackupRequest = nil
    }

    // MARK: - Configuration

    /// Publishes the application services after asynchronous startup has completed.
    func configure(
        coreDataManager: CoreDataManager,
        statisticsManager: StatisticsManager,
        bgReadingsAccessor: BgReadingsAccessor,
        calibrationsAccessor: CalibrationsAccessor,
        treatmentEntryAccessor: TreatmentEntryAccessor,
        alertManager: AlertManager,
        bgPostProcessingManager: BgPostProcessingManager,
        sensorNoiseManager: SensorNoiseManager,
        sensorHealthIssueManager: SensorHealthIssueManager,
        bluetoothPeripheralManager: BluetoothPeripheralManaging,
        soundPlayer: SoundPlayer,
        nightscoutSyncManager: NightscoutSyncManager,
        rootHomeStateModel: RootHomeStateModel,
        rootHomeActions: RootHomeActions,
        activeSensorProvider: @escaping () -> Sensor?,
        transmitterProvider: @escaping () -> CGMTransmitter?,
        startSensor: @escaping (SensorStartRequest) -> Void,
        stopSensor: @escaping () -> Void,
        submitCalibration: @escaping (CalibrationSubmission) -> String?,
        updateScreenLock: @escaping (Bool, Bool) -> Bool,
        selectedFollowerActions: SelectedFollowerActions,
        sensorProvider: ActiveSensorProviding
    ) {
        self.sensorProvider = sensorProvider
        dependencies = RootTabDependencies(
            coreDataManager: coreDataManager,
            statisticsManager: statisticsManager,
            bgReadingsAccessor: bgReadingsAccessor,
            calibrationsAccessor: calibrationsAccessor,
            treatmentEntryAccessor: treatmentEntryAccessor,
            alertManager: alertManager,
            bgPostProcessingManager: bgPostProcessingManager,
            sensorNoiseManager: sensorNoiseManager,
            sensorHealthIssueManager: sensorHealthIssueManager,
            bluetoothPeripheralManager: bluetoothPeripheralManager,
            soundPlayer: soundPlayer,
            nightscoutSyncManager: nightscoutSyncManager,
            rootHomeStateModel: rootHomeStateModel,
            rootHomeActions: rootHomeActions,
            activeSensorProvider: activeSensorProvider,
            transmitterProvider: transmitterProvider,
            startSensor: startSensor,
            stopSensor: stopSensor,
            submitCalibration: submitCalibration,
            updateScreenLock: updateScreenLock,
            selectedFollowerActions: selectedFollowerActions
        )
    }
}

// MARK: - Root Tabs

/// Native SwiftUI owner for the app's root tabs and the navigation stack in each non-home tab.
struct RootTabView: View {
    private enum Tab: Hashable {
        case home
        case treatments
        case statistics
        case bluetooth
        case settings
    }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var stateModel: RootTabStateModel
    @State private var selectedTab = Tab.home
    @State private var bluetoothDetailNavigationRequest = 0

    private let applicationCoordinator: RootApplicationCoordinator
    private let tabTitles: RootTabTitles

    /// Creates the permanent root view around the coordinator-owned state model.
    init(
        stateModel: RootTabStateModel,
        applicationCoordinator: RootApplicationCoordinator,
        tabTitles: RootTabTitles
    ) {
        self.applicationCoordinator = applicationCoordinator
        self.tabTitles = tabTitles
        _stateModel = StateObject(wrappedValue: stateModel)
    }

    // MARK: - View

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // Keep the TabView mounted during rotation so UIKit cannot flash its default background.
                ConstantsAppColors.background
                    .ignoresSafeArea()

                adaptiveTabView(isLandscape: isLandscape)
                    .tint(ConstantsAppColors.selectedTab)

                if let dependencies = stateModel.dependencies {
                    RootScreenLockOverlay(
                        stateModel: dependencies.rootHomeStateModel,
                        allowsTapToUnlock: !(isLandscape && UIDevice.current.userInterfaceIdiom != .pad),
                        unlock: dependencies.cancelScreenLock
                    )
                }

                if stateModel.isPreparingIncomingBackup {
                    ZStack {
                        Color.black.opacity(0.75).ignoresSafeArea()
                        VStack(spacing: 18) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)
                            Text("Opening backup…")
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .colorScheme(.dark)
        .onAppear {
            if stateModel.incomingBackupRequest != nil {
                selectedTab = .settings
            }
            updateSupportedOrientations(for: selectedTab)
        }
        .onChange(of: selectedTab) { selectedTab in
            if selectedTab != .home {
                stateModel.dependencies?.cancelScreenLock()
            }

            updateSupportedOrientations(for: selectedTab)
        }
        .onChange(of: scenePhase) { scenePhase in
            if scenePhase == .active {
                updateSupportedOrientations(for: selectedTab)
            }
        }
        .onChange(of: stateModel.incomingBackupRequest?.id) { requestID in
            if requestID != nil {
                selectedTab = .settings
            }
        }
        .onChange(of: stateModel.sensorHealthHomeRequest) { _ in
            selectedTab = .home
        }
        .alert(
            item: Binding(
                get: { stateModel.alertRequest },
                set: { stateModel.updatePresentedAlert($0) }
            )
        ) { request in
            if let cancelTitle = request.cancelTitle {
                return Alert(
                    title: Text(request.title),
                    message: Text(request.message),
                    primaryButton: .default(Text(request.actionTitle), action: request.action),
                    secondaryButton: .cancel(Text(cancelTitle), action: request.cancel)
                )
            }

            return Alert(
                title: Text(request.title),
                message: Text(request.message),
                dismissButton: .default(Text(request.actionTitle), action: request.action)
            )
        }
        .alert(
            stateModel.textInputRequest?.title ?? "",
            isPresented: Binding(
                get: { stateModel.textInputRequest != nil },
                set: { if !$0 { stateModel.textInputRequest = nil } }
            )
        ) {
            if let request = stateModel.textInputRequest {
                TextField(request.placeholder, text: $stateModel.textInput)
                    .keyboardType(request.usesDecimalKeyboard ? .decimalPad : .numberPad)

                Button(Texts_Common.Cancel, role: .cancel) {}
                Button(Texts_Common.Ok) {
                    request.action(stateModel.textInput)
                }
            }
        }
        .overlay {
            // Alert-driven snooze sheets should remain visually distinct from the current screen.
            if stateModel.pickerData != nil {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .sheet(item: $stateModel.pickerData) { pickerData in
            // Root-level requests are alerts; the preference changes their scale, not their actions.
            if UserDefaults.standard.preferLargeSnoozeScreen {
                LargeSnoozePickerView(pickerData: pickerData)
                    .colorScheme(.dark)
            } else {
                StandardAlertSnoozePickerView(pickerData: pickerData)
                    .colorScheme(.dark)
            }
        }
    }

    /// Uses the modern iPad top-tab presentation, which can expand into a sidebar. The existing
    /// iPhone tab bar remains byte-for-byte the same view hierarchy on every supported iOS release.
    @ViewBuilder private func adaptiveTabView(isLandscape: Bool) -> some View {
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            tabs(isLandscape: isLandscape)
                .tabViewStyle(.sidebarAdaptable)
        } else {
            tabs(isLandscape: isLandscape)
        }
    }

    private func tabs(isLandscape: Bool) -> some View {
        TabView(selection: $selectedTab) {
                    RootHomeTabView(
                        applicationCoordinator: applicationCoordinator,
                        dependencies: stateModel.dependencies,
                        snoozeDismissalRequest: stateModel.snoozeDismissalRequest,
                        isLandscape: isLandscape,
                        showBluetooth: {
                            bluetoothDetailNavigationRequest += 1
                            selectedTab = .bluetooth
                        }
                    )
                    .tag(Tab.home)
                    .tabItem {
                        tabLabel(title: tabTitles.home, systemImage: "drop.fill")
                    }

                    tabContent { dependencies in
                        NavigationStack {
                            TreatmentsView(coreDataManager: dependencies.coreDataManager)
                        }
                        .tint(ConstantsAppColors.navigationTint)
                    }
                    .tag(Tab.treatments)
                    .tabItem {
                        tabLabel(title: tabTitles.treatments, systemImage: "list.clipboard.fill")
                    }

                    Group {
                        if let dependencies = stateModel.dependencies {
                            RootStatisticsTabView(dependencies: dependencies)
                        } else {
                            ZStack {
                                ConstantsAppColors.background
                                    .ignoresSafeArea()

                                ProgressView()
                            }
                        }
                    }
                    .tag(Tab.statistics)
                    .tabItem {
                        tabLabel(title: tabTitles.statistics, systemImage: "chart.bar.xaxis")
                    }

                    tabContent { dependencies in
                        BluetoothPeripheralsNavigationView(
                            coreDataManager: dependencies.coreDataManager,
                            bluetoothPeripheralManager: dependencies.bluetoothPeripheralManager,
                            sensorProvider: stateModel.sensorProvider,
                            sensorHealthDetailRequest: bluetoothDetailNavigationRequest
                        )
                    }
                    .tag(Tab.bluetooth)
                    .tabItem {
                        tabLabel(
                            title: tabTitles.devices,
                            systemImage: "antenna.radiowaves.left.and.right"
                        )
                    }

                    tabContent { dependencies in
                        SettingsNavigationView(
                            coreDataManager: dependencies.coreDataManager,
                            soundPlayer: dependencies.soundPlayer,
                            selectedFollowerActions: dependencies.selectedFollowerActions,
                            incomingBackupRequest: stateModel.incomingBackupRequest,
                            consumeIncomingBackup: stateModel.consumeIncomingBackup
                        )
                    }
                    .tag(Tab.settings)
                    .tabItem {
                        tabLabel(title: tabTitles.settings, systemImage: "gearshape.fill")
                    }
        }
    }

    // MARK: - Tab Content

    /// Builds the image and localized title used by the native tab bar.
    @ViewBuilder private func tabLabel(title: String, systemImage: String) -> some View {
        Image(systemName: systemImage)
        Text(title)
    }

    /// Delays a tab's real content until the application services are ready.
    @ViewBuilder private func tabContent<Content: View>(
        @ViewBuilder content: (RootTabDependencies) -> Content
    ) -> some View {
        if let dependencies = stateModel.dependencies {
            content(dependencies)
                .padding(.bottom, RootTabLayout.contentBottomPadding)
        } else {
            ZStack {
                ConstantsAppColors.background
                    .ignoresSafeArea()

                ProgressView()
            }
        }
    }

    /// Home supports the landscape AGP comparison view. The remaining tabs stay portrait.
    private func updateSupportedOrientations(for tab: Tab) {
        let supportedOrientations: UIInterfaceOrientationMask

        supportedOrientations = RootOrientationPolicy.supportedOrientations(
            isPad: UIDevice.current.userInterfaceIdiom == .pad,
            isHome: tab == .home,
            allowsHomeRotation: UserDefaults.standard.allowScreenRotation
        )

        AppDelegate.supportedOrientations = supportedOrientations

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootController = windowScene.keyWindow?.rootViewController
        else {
            return
        }

        rootController.setNeedsUpdateOfSupportedInterfaceOrientations()

        if UIDevice.current.userInterfaceIdiom != .pad,
           tab != .home,
           windowScene.interfaceOrientation.isLandscape {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }
}

// MARK: - Statistics Tab

/// Keeps the normal Statistics navigation portrait-only.
private struct RootStatisticsTabView: View {

    let dependencies: RootTabDependencies

    var body: some View {
        NavigationStack {
            StatisticsView(statisticsManager: dependencies.statisticsManager)
        }
        .tint(ConstantsAppColors.navigationTint)
        .padding(.bottom, RootTabLayout.contentBottomPadding)
    }
}

// MARK: - Home Tab

/// Switches between portrait and landscape Home content within the same tab hierarchy.
private struct RootHomeTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    private enum PresentedView: String, Identifiable {
        case snooze
        case bgReadings
        case sensorManagement
        case sensorCalibration
        case bgAdjustments
        case showHideItems
        case aidStatus
        case careLinkPumpStatus

        var id: String { rawValue }
    }

    @State private var presentedView: PresentedView?
    @State private var showsScreenLockInformation = false

    let applicationCoordinator: RootApplicationCoordinator
    let dependencies: RootTabDependencies?
    let snoozeDismissalRequest: Int
    let isLandscape: Bool
    let showBluetooth: () -> Void

    // MARK: - View

    var body: some View {
        ZStack {
            if let dependencies {
                if isLandscape && UIDevice.current.userInterfaceIdiom != .pad {
                    RootHomeLandscapeView(
                        dependencies: dependencies,
                        showSensorManagement: { presentedView = .sensorManagement },
                        showBluetooth: showBluetooth
                    )
                } else {
                    RootHomeView(
                        stateModel: dependencies.rootHomeStateModel,
                        sensorHealthIssueManager: dependencies.sensorHealthIssueManager,
                        coreDataManager: dependencies.coreDataManager,
                        nightscoutSyncManager: dependencies.nightscoutSyncManager,
                        actions: rootHomeActions(from: dependencies)
                    )
                }

            }
        }
        .padding(
            .bottom,
            isLandscape && UIDevice.current.userInterfaceIdiom != .pad ? 0 : RootTabLayout.contentBottomPadding
        )
        .toolbar(isLandscape && UIDevice.current.userInterfaceIdiom != .pad ? .hidden : .automatic, for: .tabBar)
        .onAppear {
            applicationCoordinator.homeDidBecomeVisible()
            updatePresentedViewOrientationLock()
        }
        .onDisappear {
            dependencies?.cancelScreenLock()
        }
        .sheet(item: $presentedView) { presentedView in
            destinationView(presentedView)
                .colorScheme(.dark)
        }
        .onChange(of: presentedView?.id) { presentedViewID in
            if presentedViewID != nil {
                dependencies?.cancelScreenLock()
            }

            updatePresentedViewOrientationLock()
        }
        .onChange(of: snoozeDismissalRequest) { _ in
            dismissSnoozeIfNeeded()
        }
        .onChange(of: scenePhase) { scenePhase in
            if scenePhase == .background {
                dismissSnoozeIfNeeded()
                showsScreenLockInformation = false
            }
        }
        .alert(Texts_HomeView.screenLockTitle, isPresented: $showsScreenLockInformation) {
            Button(Texts_Common.dontShowAgain, role: .destructive) {
                UserDefaults.standard.lockScreenDontShowAgain = true
            }
            Button(Texts_Common.Ok, role: .cancel) {}
        } message: {
            Text(Texts_HomeView.screenLockInfo)
        }
        .task(id: showsScreenLockInformation) {
            guard showsScreenLockInformation else { return }

            try? await Task.sleep(nanoseconds: 30_000_000_000)
            showsScreenLockInformation = false
        }
    }

    // MARK: - Actions and Presentation

    /// Connects Home commands to the sheets and screen-lock presentation owned by this tab.
    private func rootHomeActions(from dependencies: RootTabDependencies) -> RootHomeActions {
        var actions = dependencies.rootHomeActions
        actions.showSnooze = { presentedView = .snooze }
        actions.queueSensorHealthTest = { dependencies.sensorHealthIssueManager.queueTestIssue($0) }
        actions.showBgReadings = { presentedView = .bgReadings }
        actions.showSensorManagement = { presentedView = .sensorManagement }
        actions.showCalibration = { presentedView = .sensorCalibration }
        actions.showBgAdjustments = { presentedView = .bgAdjustments }
        actions.showHideItems = { presentedView = .showHideItems }
        actions.showAIDStatus = {
            presentedView = UserDefaults.standard.dataFlowPolicy.importsTherapyFromCareLink
                ? .careLinkPumpStatus
                : .aidStatus
        }
        actions.showBluetooth = showBluetooth
        actions.toggleScreenLock = { updateScreenLock(using: dependencies, overrideCurrentState: false, nightMode: true) }
        actions.keepScreenAwake = { updateScreenLock(using: dependencies, overrideCurrentState: true, nightMode: false) }
        return actions
    }

    /// Builds the sheet requested by a Home toolbar or status action.
    @ViewBuilder private func destinationView(_ presentedView: PresentedView) -> some View {
        if let dependencies {
            switch presentedView {
            case .snooze:
                SnoozeView(viewModel: SnoozeViewModel(alertManager: dependencies.alertManager))
                    .ipadSheetMinimumSize(width: 560, height: 620)
            case .bgReadings:
                BgReadingsView()
                    .environmentObject(dependencies.bgReadingsAccessor)
                    .environmentObject(dependencies.nightscoutSyncManager)
                    .ipadSheetMinimumSize(width: 720, height: 720)
            case .sensorManagement, .sensorCalibration:
                SensorManagementView(
                    activeSensorProvider: dependencies.activeSensorProvider,
                    transmitterProvider: dependencies.transmitterProvider,
                    calibrationsAccessor: dependencies.calibrationsAccessor,
                    bgReadingsAccessor: dependencies.bgReadingsAccessor,
                    sensorNoiseManager: dependencies.sensorNoiseManager,
                    onStartSensor: dependencies.startSensor,
                    onStopSensor: dependencies.stopSensor,
                    onSubmitCalibration: dependencies.submitCalibration,
                    initiallyShowsCalibration: presentedView == .sensorCalibration
                )
                .ipadSheetMinimumSize(width: 680, height: 720)
            case .bgAdjustments:
                BgAdjustmentsView(
                    bgReadingsAccessor: dependencies.bgReadingsAccessor,
                    treatmentEntryAccessor: dependencies.treatmentEntryAccessor,
                    bgPostProcessingManager: dependencies.bgPostProcessingManager
                )
                .ipadSheetMinimumSize(width: 720, height: 740)
            case .showHideItems:
                ShowHideItemsView()
                    .ipadSheetMinimumSize(width: 680, height: 680)
            case .aidStatus:
                AIDStatusView()
                    .environmentObject(dependencies.nightscoutSyncManager)
                    .ipadSheetMinimumSize(width: 720, height: 720)
            case .careLinkPumpStatus:
                CareLinkPumpStatusView()
                    .ipadSheetMinimumSize(width: 720, height: 720)
            }
        }
    }

    private func dismissSnoozeIfNeeded() {
        if presentedView == .snooze {
            presentedView = nil
        }
    }

    /// Home can rotate into the dedicated landscape chart, but the toolbar sheets are portrait-only
    /// workflows. While one is open, temporarily tighten the app delegate orientation mask and then
    /// restore the Home policy when it closes.
    private func updatePresentedViewOrientationLock() {
        let supportedOrientations: UIInterfaceOrientationMask

        supportedOrientations = RootOrientationPolicy.supportedOrientations(
            isPad: UIDevice.current.userInterfaceIdiom == .pad,
            isHome: presentedView == nil,
            allowsHomeRotation: UserDefaults.standard.allowScreenRotation
        )

        AppDelegate.supportedOrientations = supportedOrientations

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootController = windowScene.keyWindow?.rootViewController
        else {
            return
        }

        rootController.setNeedsUpdateOfSupportedInterfaceOrientations()

        if UIDevice.current.userInterfaceIdiom != .pad && presentedView != nil {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }

    private func updateScreenLock(using dependencies: RootTabDependencies, overrideCurrentState: Bool, nightMode: Bool) {
        let didEnable = dependencies.updateScreenLock(overrideCurrentState, nightMode)

        if didEnable && !UserDefaults.standard.lockScreenDontShowAgain {
            showsScreenLockInformation = true
        }
    }
}

// MARK: - Screen Lock

/// Covers the complete tab hierarchy while Clock Mode is active and owns tap-to-unlock.
///
/// Keeping the overlay mounted when visual dimming is disabled gives the transparent presentation
/// exactly the same touch handling as the visibly dimmed presentations. iPhone landscape absorbs
/// touches without unlocking; rotating back to portrait restores the established tap-to-unlock.
private struct RootScreenLockOverlay: View {
    @ObservedObject var stateModel: RootHomeStateModel
    let allowsTapToUnlock: Bool
    let unlock: () -> Void

    var body: some View {
        let state = stateModel.state
        let dimmingType = UserDefaults.standard.screenLockDimmingType

        if state.isScreenLocked,
           state.usesScreenLockNightLayout {
            dimmingType.dimmingColor
                .opacity(dimmingType == .disabled ? 0 : 1)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard allowsTapToUnlock else { return }

                    unlock()
                }
        }
    }
}

// MARK: - Landscape Home

/// Observes Home state so locking and unlocking switch landscape content immediately.
private struct RootHomeLandscapeView: View {
    @ObservedObject private var rootHomeStateModel: RootHomeStateModel
    @ObservedObject private var sensorHealthIssueManager: SensorHealthIssueManager
    private let coreDataManager: CoreDataManager
    private let nightscoutSyncManager: NightscoutSyncManager
    private let showSensorManagement: () -> Void
    private let showBluetooth: () -> Void

    init(dependencies: RootTabDependencies, showSensorManagement: @escaping () -> Void, showBluetooth: @escaping () -> Void) {
        rootHomeStateModel = dependencies.rootHomeStateModel
        sensorHealthIssueManager = dependencies.sensorHealthIssueManager
        coreDataManager = dependencies.coreDataManager
        nightscoutSyncManager = dependencies.nightscoutSyncManager
        self.showSensorManagement = showSensorManagement
        self.showBluetooth = showBluetooth
    }

    var body: some View {
        VStack(spacing: 8) {
            if let issue = sensorHealthIssueManager.visibleIssue {
                SensorHealthBannerView(
                    issue: issue,
                    action: {
                        switch issue.destination {
                        case .sensorManagement:
                            showSensorManagement()
                        case .bluetoothPeripheral:
                            showBluetooth()
                        }
                    },
                    dismiss: sensorHealthIssueManager.dismissVisibleIssue
                )
                .padding(.horizontal, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if rootHomeStateModel.state.usesScreenLockNightLayout {
                RootHomeLandscapeValueView(stateModel: rootHomeStateModel)
            } else {
                RootHomeLandscapeChartView(
                    coreDataManager: coreDataManager,
                    nightscoutSyncManager: nightscoutSyncManager
                )
            }
        }
        .animation(.easeOut(duration: 0.22), value: sensorHealthIssueManager.visibleIssue?.id)
    }
}

/// Owns the landscape chart state for the lifetime of one landscape presentation.
private struct RootHomeLandscapeChartView: View {
    @StateObject private var stateModel: LandscapeChartStateModel

    init(coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager) {
        _stateModel = StateObject(wrappedValue: LandscapeChartStateModel(
            coreDataManager: coreDataManager,
            nightscoutSyncManager: nightscoutSyncManager
        ))
    }

    var body: some View {
        LandscapeChartView(stateModel: stateModel)
    }
}

/// Reads the same glucose state as the portrait Home screen while screen lock is active.
private struct RootHomeLandscapeValueView: View {
    @ObservedObject var stateModel: RootHomeStateModel

    var body: some View {
        LandscapeValueView(state: stateModel.state)
    }
}

// MARK: - Localized Titles

/// Localized titles used by the root tab bar.
struct RootTabTitles {
    let home: String
    let treatments: String
    let statistics: String
    let devices: String
    let settings: String
}

extension View {
    /// Keeps form and list content readable on a wide iPad while leaving the original iPhone view
    /// completely unmodified. The outer frame still fills the detail area so backgrounds remain
    /// continuous and split-view toolbars align with the window.
    @ViewBuilder func ipadReadableContentWidth(_ maxWidth: CGFloat = 780) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            self
        }
    }

    @ViewBuilder func ipadSheetMinimumSize(width: CGFloat, height: CGFloat) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            frame(minWidth: width, minHeight: height)
        } else {
            self
        }
    }

    @ViewBuilder func ipadLargeSheet(width: CGFloat, height: CGFloat) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            frame(minWidth: width, minHeight: height)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}
