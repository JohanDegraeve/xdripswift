//
//  RootTabView.swift
//  xdrip
//
//  Created by Paul Plant on 11/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - Layout

/// Layout values shared by the root tabs.
private enum RootTabLayout {
    static let contentBottomPadding: CGFloat = 4
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

// MARK: - Application Dependencies

/// Services needed by the native SwiftUI tabs after application startup has completed.
///
/// The coordinator creates these services once. Keeping the references together prevents views
/// from creating duplicate managers as the user changes tabs.
struct RootTabDependencies {
    let coreDataManager: CoreDataManager
    let bgReadingsAccessor: BgReadingsAccessor
    let calibrationsAccessor: CalibrationsAccessor
    let treatmentEntryAccessor: TreatmentEntryAccessor
    let alertManager: AlertManager
    let bgPostProcessingManager: BgPostProcessingManager
    let bluetoothPeripheralManager: BluetoothPeripheralManaging
    let soundPlayer: SoundPlayer
    let nightscoutSyncManager: NightscoutSyncManager
    let rootHomeStateModel: RootHomeStateModel
    let rootHomeActions: RootHomeActions
    let activeSensorProvider: () -> Sensor?
    let transmitterProvider: () -> CGMTransmitter?
    let startSensor: (Date, String?) -> Void
    let stopSensor: () -> Void
    let submitCalibration: (Double) -> String?
    let updateScreenLock: (Bool, Bool) -> Bool
}

/// Publishes existing application services to the SwiftUI tab hierarchy.
///
/// `RootApplicationCoordinator` owns the services. This state model publishes their references once
/// asynchronous Core Data setup has completed; it never creates a second manager or mirrors data.
@MainActor final class RootTabStateModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var dependencies: RootTabDependencies?
    @Published private(set) var snoozeDismissalRequest = 0
    @Published var alertRequest: RootAlertRequest?
    @Published var textInputRequest: RootTextInputRequest?
    @Published var textInput = ""
    @Published var pickerData: SnoozePickerData?
    weak var sensorProvider: ActiveSensorProviding?

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
        alertRequest = RootAlertRequest(
            title: title,
            message: message,
            actionTitle: actionTitle,
            cancelTitle: cancelTitle,
            action: action,
            cancel: cancel
        )
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

    // MARK: - Configuration

    /// Publishes the application services after asynchronous startup has completed.
    func configure(
        coreDataManager: CoreDataManager,
        bgReadingsAccessor: BgReadingsAccessor,
        calibrationsAccessor: CalibrationsAccessor,
        treatmentEntryAccessor: TreatmentEntryAccessor,
        alertManager: AlertManager,
        bgPostProcessingManager: BgPostProcessingManager,
        bluetoothPeripheralManager: BluetoothPeripheralManaging,
        soundPlayer: SoundPlayer,
        nightscoutSyncManager: NightscoutSyncManager,
        rootHomeStateModel: RootHomeStateModel,
        rootHomeActions: RootHomeActions,
        activeSensorProvider: @escaping () -> Sensor?,
        transmitterProvider: @escaping () -> CGMTransmitter?,
        startSensor: @escaping (Date, String?) -> Void,
        stopSensor: @escaping () -> Void,
        submitCalibration: @escaping (Double) -> String?,
        updateScreenLock: @escaping (Bool, Bool) -> Bool,
        sensorProvider: ActiveSensorProviding
    ) {
        self.sensorProvider = sensorProvider
        dependencies = RootTabDependencies(
            coreDataManager: coreDataManager,
            bgReadingsAccessor: bgReadingsAccessor,
            calibrationsAccessor: calibrationsAccessor,
            treatmentEntryAccessor: treatmentEntryAccessor,
            alertManager: alertManager,
            bgPostProcessingManager: bgPostProcessingManager,
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
            updateScreenLock: updateScreenLock
        )
    }
}

// MARK: - Root Tabs

/// Native SwiftUI owner for the app's root tabs and the navigation stack in each non-home tab.
struct RootTabView: View {
    private enum Tab: Hashable {
        case home
        case treatments
        case bluetooth
        case settings
    }

    @StateObject private var stateModel: RootTabStateModel
    @State private var selectedTab = Tab.home

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
        ZStack {
            TabView(selection: $selectedTab) {
                RootHomeTabView(
                    applicationCoordinator: applicationCoordinator,
                    dependencies: stateModel.dependencies,
                    snoozeDismissalRequest: stateModel.snoozeDismissalRequest
                )
                .tag(Tab.home)
                .tabItem {
                    tabLabel(title: tabTitles.home, image: "Home")
                }

                tabContent { dependencies in
                    NavigationStack {
                        TreatmentsView(coreDataManager: dependencies.coreDataManager)
                    }
                    .tint(.yellow)
                }
                .tag(Tab.treatments)
                .tabItem {
                    tabLabel(title: tabTitles.treatments, image: "Treatments")
                }

                tabContent { dependencies in
                    BluetoothPeripheralsNavigationView(
                        coreDataManager: dependencies.coreDataManager,
                        bluetoothPeripheralManager: dependencies.bluetoothPeripheralManager,
                        sensorProvider: stateModel.sensorProvider
                    )
                }
                .tag(Tab.bluetooth)
                .tabItem {
                    tabLabel(title: tabTitles.bluetooth, image: "Bluetooth")
                }

                tabContent { dependencies in
                    SettingsNavigationView(
                        coreDataManager: dependencies.coreDataManager,
                        soundPlayer: dependencies.soundPlayer
                    )
                }
                .tag(Tab.settings)
                .tabItem {
                    tabLabel(title: tabTitles.settings, image: "Settings")
                }
            }

            if let dependencies = stateModel.dependencies {
                RootScreenLockOverlay(
                    stateModel: dependencies.rootHomeStateModel,
                    unlock: { _ = dependencies.updateScreenLock(false, true) }
                )
            }
        }
        .colorScheme(.dark)
        .onAppear {
            updateSupportedOrientations(for: selectedTab)
        }
        .onChange(of: selectedTab) { selectedTab in
            updateSupportedOrientations(for: selectedTab)
        }
        .alert(item: $stateModel.alertRequest) { request in
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
        .sheet(item: $stateModel.pickerData) { pickerData in
            SnoozePickerView(pickerData: pickerData)
                .colorScheme(.dark)
        }
    }

    // MARK: - Tab Content

    /// Builds the image and localized title used by the native tab bar.
    @ViewBuilder private func tabLabel(title: String, image: String) -> some View {
        Image(image)
            .renderingMode(.template)
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

    /// Only Home supports the optional landscape chart. The remaining tabs stay portrait.
    private func updateSupportedOrientations(for tab: Tab) {
        let supportedOrientations: UIInterfaceOrientationMask

        if tab == .home && UserDefaults.standard.allowScreenRotation {
            supportedOrientations = .allButUpsideDown
        } else {
            supportedOrientations = .portrait
        }

        AppDelegate.supportedOrientations = supportedOrientations

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootController = windowScene.keyWindow?.rootViewController
        else {
            return
        }

        rootController.setNeedsUpdateOfSupportedInterfaceOrientations()

        if tab != .home {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
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
        case bgAdjustments
        case showHideItems
        case aidStatus

        var id: String { rawValue }
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var presentedView: PresentedView?
    @State private var showsScreenLockInformation = false

    let applicationCoordinator: RootApplicationCoordinator
    let dependencies: RootTabDependencies?
    let snoozeDismissalRequest: Int

    // MARK: - View

    var body: some View {
        ZStack {
            if let dependencies {
                if verticalSizeClass == .compact {
                    RootHomeLandscapeView(dependencies: dependencies)
                } else {
                    RootHomeView(
                        stateModel: dependencies.rootHomeStateModel,
                        coreDataManager: dependencies.coreDataManager,
                        nightscoutSyncManager: dependencies.nightscoutSyncManager,
                        actions: rootHomeActions(from: dependencies)
                    )
                }
            }
        }
        .padding(
            .bottom,
            verticalSizeClass == .compact ? 0 : RootTabLayout.contentBottomPadding
        )
        .toolbar(verticalSizeClass == .compact ? .hidden : .automatic, for: .tabBar)
        .onAppear {
            applicationCoordinator.homeDidBecomeVisible()
        }
        .sheet(item: $presentedView) { presentedView in
            destinationView(presentedView)
                .colorScheme(.dark)
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
        actions.showBgReadings = { presentedView = .bgReadings }
        actions.showSensorManagement = { presentedView = .sensorManagement }
        actions.showBgAdjustments = { presentedView = .bgAdjustments }
        actions.showHideItems = { presentedView = .showHideItems }
        actions.showAIDStatus = { presentedView = .aidStatus }
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
            case .bgReadings:
                BgReadingsView()
                    .environmentObject(dependencies.bgReadingsAccessor)
                    .environmentObject(dependencies.nightscoutSyncManager)
            case .sensorManagement:
                SensorManagementView(
                    activeSensorProvider: dependencies.activeSensorProvider,
                    transmitterProvider: dependencies.transmitterProvider,
                    calibrationsAccessor: dependencies.calibrationsAccessor,
                    bgReadingsAccessor: dependencies.bgReadingsAccessor,
                    onStartSensor: dependencies.startSensor,
                    onStopSensor: dependencies.stopSensor,
                    onSubmitCalibration: dependencies.submitCalibration
                )
            case .bgAdjustments:
                BgAdjustmentsView(
                    bgReadingsAccessor: dependencies.bgReadingsAccessor,
                    treatmentEntryAccessor: dependencies.treatmentEntryAccessor,
                    bgPostProcessingManager: dependencies.bgPostProcessingManager
                )
            case .showHideItems:
                ShowHideItemsView()
            case .aidStatus:
                AIDStatusView()
                    .environmentObject(dependencies.nightscoutSyncManager)
            }
        }
    }

    private func dismissSnoozeIfNeeded() {
        if presentedView == .snooze {
            presentedView = nil
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

/// Covers the complete tab hierarchy while the full night screen lock is active and owns tap-to-unlock.
private struct RootScreenLockOverlay: View {
    @ObservedObject var stateModel: RootHomeStateModel
    let unlock: () -> Void

    var body: some View {
        let state = stateModel.state
        let dimmingType = UserDefaults.standard.screenLockDimmingType

        if state.isScreenLocked,
           state.usesScreenLockNightLayout,
           dimmingType != .disabled {
            dimmingType.dimmingColor
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: unlock)
        }
    }
}

// MARK: - Landscape Home

/// Observes Home state so locking and unlocking switch landscape content immediately.
private struct RootHomeLandscapeView: View {
    @ObservedObject private var rootHomeStateModel: RootHomeStateModel
    private let coreDataManager: CoreDataManager
    private let nightscoutSyncManager: NightscoutSyncManager

    init(dependencies: RootTabDependencies) {
        rootHomeStateModel = dependencies.rootHomeStateModel
        coreDataManager = dependencies.coreDataManager
        nightscoutSyncManager = dependencies.nightscoutSyncManager
    }

    var body: some View {
        if rootHomeStateModel.state.isScreenLocked {
            RootHomeLandscapeValueView(stateModel: rootHomeStateModel)
        } else {
            RootHomeLandscapeChartView(
                coreDataManager: coreDataManager,
                nightscoutSyncManager: nightscoutSyncManager
            )
        }
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
        LandscapeValueView(glucoseState: stateModel.state.glucose)
    }
}

// MARK: - Localized Titles

/// Localized titles used by the root tab bar.
struct RootTabTitles {
    let home: String
    let treatments: String
    let bluetooth: String
    let settings: String
}
