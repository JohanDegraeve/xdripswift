//
//  RootTabView.swift
//  xdrip
//
//  Created by Paul Plant on 11/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit

private enum RootTabLayout {
    static let contentBottomPadding: CGFloat = 4
}

@MainActor private enum RootTabOrientationPolicy {
    static var supportedOrientations: UIInterfaceOrientationMask = UserDefaults.standard.allowScreenRotation
        ? .allButUpsideDown
        : .portrait
}

/// Root hosting boundary which exposes the orientation policy selected by RootTabView.
/// SwiftUI does not currently provide an equivalent supported-orientations modifier.
final class RootTabHostingController<Content: View>: UIHostingController<Content> {
    override var shouldAutorotate: Bool {
        return RootTabOrientationPolicy.supportedOrientations != .portrait
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return RootTabOrientationPolicy.supportedOrientations
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }
}

/// Services needed by the native SwiftUI tabs after application startup has completed.
struct RootTabDependencies {
    let coreDataManager: CoreDataManager
    let bluetoothPeripheralManager: BluetoothPeripheralManaging
    let soundPlayer: SoundPlayer
    let nightscoutSyncManager: NightscoutSyncManager
    let rootHomeStateModel: RootHomeStateModel
}

/// Publishes existing application services to the SwiftUI tab hierarchy.
///
/// RootViewController remains their owner during this migration phase. This state model only
/// publishes references once asynchronous Core Data setup has completed; it never creates a
/// second manager or mirrors service data.
@MainActor final class RootTabStateModel: ObservableObject {
    @Published private(set) var dependencies: RootTabDependencies?
    weak var sensorProvider: ActiveSensorProviding?

    func configure(
        coreDataManager: CoreDataManager,
        bluetoothPeripheralManager: BluetoothPeripheralManaging,
        soundPlayer: SoundPlayer,
        nightscoutSyncManager: NightscoutSyncManager,
        rootHomeStateModel: RootHomeStateModel,
        sensorProvider: ActiveSensorProviding
    ) {
        self.sensorProvider = sensorProvider
        dependencies = RootTabDependencies(
            coreDataManager: coreDataManager,
            bluetoothPeripheralManager: bluetoothPeripheralManager,
            soundPlayer: soundPlayer,
            nightscoutSyncManager: nightscoutSyncManager,
            rootHomeStateModel: rootHomeStateModel
        )
    }
}

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

    private let rootViewController: RootViewController
    private let tabTitles: RootTabTitles

    init(
        stateModel: RootTabStateModel,
        rootViewController: RootViewController,
        tabTitles: RootTabTitles
    ) {
        self.rootViewController = rootViewController
        self.tabTitles = tabTitles
        _stateModel = StateObject(wrappedValue: stateModel)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            RootHomeTabView(
                viewController: rootViewController,
                dependencies: stateModel.dependencies
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
        .colorScheme(.dark)
        .onAppear {
            updateSupportedOrientations(for: selectedTab)
        }
        .onChange(of: selectedTab) { selectedTab in
            updateSupportedOrientations(for: selectedTab)
        }
    }

    @ViewBuilder private func tabLabel(title: String, image: String) -> some View {
        Image(image)
            .renderingMode(.template)
        Text(title)
    }

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

    /// Only Home supports the optional landscape chart. The remaining tabs stay portrait just as
    /// they did when their UIKit navigation controllers owned orientation policy.
    private func updateSupportedOrientations(for tab: Tab) {
        let supportedOrientations: UIInterfaceOrientationMask

        if tab == .home && UserDefaults.standard.allowScreenRotation {
            supportedOrientations = .allButUpsideDown
        } else {
            supportedOrientations = .portrait
        }

        RootTabOrientationPolicy.supportedOrientations = supportedOrientations
        (UIApplication.shared.delegate as? AppDelegate)?.restrictRotation = supportedOrientations

        guard let rootController = rootViewController.view.window?.rootViewController else { return }

        rootController.setNeedsUpdateOfSupportedInterfaceOrientations()

        if tab != .home, let windowScene = rootController.view.window?.windowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }
}

/// Switches the Home presentation at the SwiftUI level when the device rotates.
///
/// The previous implementation inserted a landscape child controller from RootViewController's
/// trait callback. That conflicts with TabView layout because UIKit and SwiftUI then update the
/// same tab hierarchy during one rotation. Keeping both presentations here gives rotation one
/// owner and keeps the landscape screen contained inside the Home tab.
private struct RootHomeTabView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let viewController: RootViewController
    let dependencies: RootTabDependencies?

    var body: some View {
        ZStack {
            // Keep the service-owning controller mounted across rotations. Only the visible
            // presentation changes, so its timers and application managers keep one lifecycle.
            RootHomeControllerView(viewController: viewController)

            if verticalSizeClass == .compact, let dependencies {
                RootHomeLandscapeView(dependencies: dependencies)
            }
        }
        .padding(
            .bottom,
            verticalSizeClass == .compact ? 0 : RootTabLayout.contentBottomPadding
        )
        .toolbar(verticalSizeClass == .compact ? .hidden : .automatic, for: .tabBar)
    }
}

/// Observes Home presentation state so locking and unlocking can switch the landscape content
/// immediately without relying on a UIKit rotation or view-controller callback.
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

/// Localized titles retained from the existing Main storyboard strings during the migration.
struct RootTabTitles {
    let home: String
    let treatments: String
    let bluetooth: String
    let settings: String
}

/// Temporary containment bridge for Home while RootViewController still starts app services.
/// All tab and non-home navigation ownership is already native SwiftUI.
private struct RootHomeControllerView: UIViewControllerRepresentable {
    let viewController: RootViewController

    func makeUIViewController(context: Context) -> RootViewController {
        viewController
    }

    func updateUIViewController(_ uiViewController: RootViewController, context: Context) {}
}
