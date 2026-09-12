//
//  BluetoothPeripheralsView.swift
//  xdrip
//
//  Created by Paul Plant on 19/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

// MARK: - Navigation

/// Native SwiftUI navigation owner for the Bluetooth tab.
struct BluetoothPeripheralsNavigationView: View {
    @StateObject private var router: BluetoothPeripheralsRouter
    @StateObject private var viewModel: BluetoothPeripheralsViewModel
    @State private var lastSensorHealthDetailRequest = 0

    private let coreDataManager: CoreDataManager
    private let bluetoothPeripheralManager: BluetoothPeripheralManaging
    private let sensorProvider: ActiveSensorProviding?
    private let sensorHealthDetailRequest: Int

    init(
        coreDataManager: CoreDataManager,
        bluetoothPeripheralManager: BluetoothPeripheralManaging,
        sensorProvider: ActiveSensorProviding?,
        sensorHealthDetailRequest: Int = 0
    ) {
        self.coreDataManager = coreDataManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        self.sensorProvider = sensorProvider
        self.sensorHealthDetailRequest = sensorHealthDetailRequest
        _router = StateObject(wrappedValue: BluetoothPeripheralsRouter())
        _viewModel = StateObject(wrappedValue: BluetoothPeripheralsViewModel(
            bluetoothPeripheralManager: bluetoothPeripheralManager
        ))
    }

    var body: some View {
        navigationContent
        .tint(ConstantsAppColors.navigationTint)
        .colorScheme(.dark)
        .onAppear(perform: handleSensorHealthDetailRequest)
        .onChange(of: sensorHealthDetailRequest) { _ in handleSensorHealthDetailRequest() }
    }

    @ViewBuilder private var navigationContent: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                BluetoothPeripheralsView(viewModel: viewModel, router: router)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 430)
            } detail: {
                NavigationStack(path: $router.path) {
                    BluetoothIPadPlaceholderView()
                        .navigationDestination(for: BluetoothPeripheralsRoute.self, destination: destination)
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack(path: $router.path) {
                BluetoothPeripheralsView(viewModel: viewModel, router: router)
                    .navigationDestination(for: BluetoothPeripheralsRoute.self, destination: destination)
            }
        }
    }

    @ViewBuilder private func destination(for route: BluetoothPeripheralsRoute) -> some View {
        switch route.destination {
        case .categories:
            BluetoothPeripheralCategorySelectionView(viewModel: viewModel, router: router)

        case let .types(category):
            BluetoothPeripheralTypeSelectionView(category: category, viewModel: viewModel, router: router)

        case let .dexcomConnectionMode(type):
            DexcomConnectionModeSelectionView(type: type, router: router)

        case let .sensorCodeCapture(capture):
            SensorStartCodeView(
                configuration: capture.configuration,
                initialCode: capture.initialCode,
                initialLabel: capture.initialLabel,
                onCancel: router.closeCurrentView,
                onManualEntry: { selectCode in
                    router.showManualSensorCodeEntry(DexcomManualSensorCodeEntry(
                        title: capture.configuration.title,
                        message: capture.configuration.manualEntryMessage,
                        placeholder: capture.configuration.placeholder,
                        onSelect: { code in
                            selectCode(code)
                            router.closeCurrentView()
                        }
                    ))
                },
                onSubmit: { code, label in
                    capture.onSubmit(code, label)
                    if capture.dismissAfterSubmit {
                        router.closeCurrentView()
                    }
                }
            )

        case let .manualSensorCodeEntry(entry):
            SensorManualCodeEntryView(
                title: entry.title,
                message: entry.message,
                placeholder: entry.placeholder,
                onSelect: entry.onSelect
            )

        case let .peripheral(bluetoothPeripheral, bluetoothPeripheralType, dexcomConfiguration):
            BluetoothPeripheralDetailContainerView(
                bluetoothPeripheral: bluetoothPeripheral,
                bluetoothPeripheralType: bluetoothPeripheralType,
                dexcomConfiguration: dexcomConfiguration,
                coreDataManager: coreDataManager,
                bluetoothPeripheralManager: bluetoothPeripheralManager,
                sensorProvider: sensorProvider,
                router: router,
                viewModel: viewModel
            )

        case let .textEntry(textEntry):
            BluetoothPeripheralTextEntryView(textEntry: textEntry, close: router.closeCurrentView)

        case let .selectionList(selectionList):
            BluetoothPeripheralSelectionListView(selectionList: selectionList, close: router.closeCurrentView)

        case let .readSuccess(display, transmitterTitle):
            TransmitterReadSuccessView(display: display, transmitterTitle: transmitterTitle)

        case let .batteryHistory(peripheralObjectID):
            BatteryHistoryView(
                peripheralObjectID: peripheralObjectID,
                manager: BatteryHistoryManager(coreDataManager: coreDataManager)
            )
        }
    }

    /// Opens the current transmitter detail only after the user taps its in-app banner.
    private func handleSensorHealthDetailRequest() {
        guard sensorHealthDetailRequest > 0,
              sensorHealthDetailRequest != lastSensorHealthDetailRequest,
              let transmitter = bluetoothPeripheralManager.getCGMTransmitter() as? BluetoothTransmitter,
              let peripheral = bluetoothPeripheralManager.getBluetoothPeripheral(for: transmitter) else { return }

        lastSensorHealthDetailRequest = sensorHealthDetailRequest
        router.path.removeAll()
        router.openPeripheral(peripheral, type: peripheral.bluetoothPeripheralType())
    }
}

private struct BluetoothIPadPlaceholderView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color(.colorTertiary))

            Text(Texts_BluetoothPeripheralsView.screenTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(.colorPrimary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ConstantsUI.listBackGroundColor.ignoresSafeArea())
        .accessibilityElement(children: .combine)
    }
}

/// Owns one peripheral detail state for as long as its NavigationStack destination is visible.
private struct BluetoothPeripheralDetailContainerView: View {
    @StateObject private var state: BluetoothPeripheralDetailState
    private let isOnboarding: Bool
    private let closeOnboarding: () -> Void

    init(
        bluetoothPeripheral: BluetoothPeripheral?,
        bluetoothPeripheralType: BluetoothPeripheralType,
        dexcomConfiguration: DexcomAddConfiguration?,
        coreDataManager: CoreDataManager,
        bluetoothPeripheralManager: BluetoothPeripheralManaging,
        sensorProvider: ActiveSensorProviding?,
        router: BluetoothPeripheralsRouter,
        viewModel: BluetoothPeripheralsViewModel
    ) {
        isOnboarding = dexcomConfiguration != nil
        closeOnboarding = {
            router.path.removeAll()
            viewModel.reload()
        }
        _state = StateObject(wrappedValue: BluetoothPeripheralDetailState(
            bluetoothPeripheral: bluetoothPeripheral,
            expectedBluetoothPeripheralType: bluetoothPeripheralType,
            dexcomConfiguration: dexcomConfiguration,
            coreDataManager: coreDataManager,
            bluetoothPeripheralManager: bluetoothPeripheralManager,
            sensorProvider: sensorProvider,
            closeDetailView: {
                if dexcomConfiguration != nil {
                    router.path.removeAll()
                } else {
                    router.closeCurrentView()
                }
                viewModel.reload()
            },
            presentTextEntryView: router.showTextEntry,
            presentSelectionListView: router.showSelectionList,
            presentReadSuccessView: router.showReadSuccess,
            presentBatteryHistoryView: router.showBatteryHistory
        ))
    }

    var body: some View {
        BluetoothPeripheralDetailView(state: state)
            .navigationBarBackButtonHidden(isOnboarding)
            .toolbar {
                if isOnboarding {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: closeOnboarding) {
                            Image(systemName: "chevron.left")
                        }
                        .foregroundStyle(ConstantsAppColors.toolbarNeutralAction)
                    }
                }
            }
            .onDisappear(perform: state.stop)
    }
}

// MARK: - Peripheral List

/// Lists configured peripherals and keeps their connection status current while visible.
struct BluetoothPeripheralsView: View {
    @ObservedObject var viewModel: BluetoothPeripheralsViewModel
    @ObservedObject var router: BluetoothPeripheralsRouter

    var body: some View {
        List {
            if viewModel.sections.isEmpty {
                Text(Texts_BluetoothPeripheralsView.noBluetoothPeripheralsConfigured)
                    .foregroundStyle(Color(.colorSecondary))
            } else {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            Button {
                                open(row: row)
                            } label: {
                                BluetoothPeripheralListRowView(row: row)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .listRowBackground(row.connectionStatus.rowBackgroundColor)
                        }
                    } header: {
                        if section.showsHeader {
                            BluetoothPeripheralSectionHeaderView(section: section)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(Texts_BluetoothPeripheralsView.screenTitle)
        .navigationBarTitleDisplayMode(.large)
        .colorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                OnlineHelpButton(topic: .devices)

                Button(action: showAddFlow) {
                    Image(systemName: "plus")
                }
                .tint(ConstantsAppColors.toolbarAction)
            }
        }
        .alert(item: $viewModel.pendingAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(Texts_Common.Ok))
            )
        }
        .onAppear(perform: startStatusUpdates)
        .onDisappear(perform: stopStatusUpdates)
    }

    private func showAddFlow() {
        router.showAddPeripheralCategories()
    }

    private func open(row: BluetoothPeripheralListRow) {
        router.openPeripheral(row.bluetoothPeripheral, type: row.bluetoothPeripheral.bluetoothPeripheralType())
    }

    private func startStatusUpdates() {
        viewModel.startStatusUpdates()
    }

    private func stopStatusUpdates() {
        viewModel.stopStatusUpdates()
    }
}

// MARK: - Add Peripheral

/// First add-peripheral step, selecting the required device category.
struct BluetoothPeripheralCategorySelectionView: View {
    @ObservedObject var viewModel: BluetoothPeripheralsViewModel
    @ObservedObject var router: BluetoothPeripheralsRouter

    var body: some View {
        List {
            Section {
                ForEach(BluetoothPeripheralCategory.allCases, id: \.rawValue) { category in
                    Button {
                        select(category: category)
                    } label: {
                        BluetoothPeripheralSelectionRow(
                            title: category.rawValue,
                            subtitle: subtitle(for: category),
                            systemImage: category.systemImage()
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(Texts_BluetoothPeripheralsView.selectCategory)
        .navigationBarTitleDisplayMode(.large)
        .onlineHelp(.devices)
        .colorScheme(.dark)
        .alert(item: $viewModel.pendingAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(Texts_Common.Ok))
            )
        }
    }

    private func select(category: BluetoothPeripheralCategory) {
        guard viewModel.validateCanAdd(category: category) else { return }

        router.showPeripheralTypes(category: category)
    }

    private func subtitle(for category: BluetoothPeripheralCategory) -> String {
        let count = viewModel.bluetoothPeripheralTypes(for: category).count
        return count == 1 ? "1 type" : "\(count) types"
    }

}

/// Second add-peripheral step, selecting a supported peripheral type.
struct BluetoothPeripheralTypeSelectionView: View {
    let category: BluetoothPeripheralCategory

    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: BluetoothPeripheralsViewModel
    @ObservedObject var router: BluetoothPeripheralsRouter

    var body: some View {
        List {
            Section {
                ForEach(viewModel.bluetoothPeripheralTypes(for: category), id: \.rawValue) { bluetoothPeripheralType in
                    Button {
                        open(type: bluetoothPeripheralType)
                    } label: {
                        BluetoothPeripheralSelectionRow(
                            title: bluetoothPeripheralType.bluetoothPeripheralDisplayTitle,
                            subtitle: nil,
                            systemImage: category.systemImage()
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            } footer: {
                footerView
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .onlineHelp(category.onlineHelpTopic)
        .colorScheme(.dark)
    }

    private func open(type bluetoothPeripheralType: BluetoothPeripheralType) {
        switch bluetoothPeripheralType {
        case .DexcomType, .DexcomG7Type:
            router.showDexcomConnectionMode(type: bluetoothPeripheralType)
        default:
            router.openPeripheral(nil, type: bluetoothPeripheralType)
        }
    }

    @ViewBuilder private var footerView: some View {
        switch category {
        case .HeartBeat:
            footerText(Texts_BluetoothPeripheralsView.heartbeatDeviceFooter)
        case .M5Stack:
            VStack(alignment: .leading, spacing: 6) {
                footerText(Texts_BluetoothPeripheralsView.m5StackDeviceFooter)

                Button {
                    if let url = URL(string: "https://m5stack.com") {
                        openURL(url)
                    }
                } label: {
                    Text("m5stack.com")
                }
            }
        case .CGM:
            EmptyView()
        }
    }

    private func footerText(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(ConstantsUI.listSectionFooterTextColor)
            .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
    }
}

/// Choose the connection mode before adding a G6 or G7.
private struct DexcomConnectionModeSelectionView: View {
    let type: BluetoothPeripheralType
    @ObservedObject var router: BluetoothPeripheralsRouter

    @State private var selectedMode: DexcomConnectionMode?

    var body: some View {
        List {
            Section {
                modeButton(mode: .primary, title: Texts_BluetoothPeripheralView.primaryModePickerOption)
                modeButton(mode: .coexistence, title: Texts_BluetoothPeripheralView.coexistenceModePickerOption)
            }

            if let selectedMode {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        DexcomConnectionModeDiagram(mode: selectedMode)
                            .padding(.horizontal, 12)
                            .accessibilityHidden(true)

                        Text(selectedMode == .primary
                            ? Texts_BluetoothPeripheralView.primaryModeAddFlowMessage
                            : Texts_BluetoothPeripheralView.coexistenceModeAddFlowMessage)
                            .font(.subheadline)
                            .foregroundStyle(ConstantsAppColors.rowDetailText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } footer: {
                    if type == .DexcomType {
                        Text(Texts_BluetoothPeripheralView.dexcomG6ModeSelectionFooter)
                            .foregroundStyle(ConstantsUI.listSectionFooterTextColor)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor.ignoresSafeArea())
        .navigationTitle(Texts_BluetoothPeripheralView.connectionMode)
        .navigationBarTitleDisplayMode(.large)
        .colorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(Texts_Common.Ok) {
                    guard let selectedMode else { return }
                    // Selecting a row only changes the explanation. OK starts the selected flow.
                    let configuration = DexcomAddConfiguration(useOtherApp: selectedMode == .coexistence)
                    if type == .DexcomG7Type, selectedMode == .primary {
                        captureDexcomG7SensorCode(configuration)
                    } else {
                        router.showDexcomTransmitterID(type: type, configuration: configuration)
                    }
                }
                .tint(ConstantsAppColors.toolbarAction)
                .disabled(selectedMode == nil)
            }
        }
    }

    private func modeButton(mode: DexcomConnectionMode, title: String) -> some View {
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.systemImage)
                    .foregroundStyle(mode.color)
                    .font(.title3)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(ConstantsAppColors.rowTitleText)
                Spacer(minLength: 8)
                Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundStyle(selectedMode == mode ? Color.green : Color(.colorQuaternary).opacity(0.5))
                    .font(.title3)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
    }

    private func captureDexcomG7SensorCode(_ configuration: DexcomAddConfiguration) {
        router.showSensorCodeCapture(DexcomSensorCodeCapture(
            configuration: .g7,
            initialCode: "",
            initialLabel: nil,
            dismissAfterSubmit: false,
            onSubmit: { code, label in
                guard code.count == 4 else { return }
                // Keep the pairing code with the selected mode before asking for the Bluetooth name.
                var updatedConfiguration = configuration
                updatedConfiguration.sensorLabel = label ?? DexcomG6SensorLabel(
                    sensorCode: code,
                    lotNumber: "",
                    serialNumber: ""
                )
                router.showDexcomTransmitterID(type: .DexcomG7Type, configuration: updatedConfiguration)
            }
        ))
    }
}

/// Show which app controls the connection and where xDrip receives readings.
private struct DexcomConnectionModeDiagram: View {
    let mode: DexcomConnectionMode

    var body: some View {
        GeometryReader { geometry in
            let appWidth = min(136.0, geometry.size.width * 0.48)
            let sensorX = geometry.size.width - 30
            let connectionEnd = sensorX - 32
            let connectionStart = appWidth + 5

            // The primary connection stays on the top row.
            let primaryY = 32.0

            ZStack(alignment: .topLeading) {
                // The primary connection has an arrow at both ends.
                Path { path in
                    path.move(to: CGPoint(x: connectionStart, y: primaryY))
                    path.addLine(to: CGPoint(x: connectionEnd - 3, y: primaryY))

                    path.move(to: CGPoint(x: connectionStart + 6, y: primaryY - 5))
                    path.addLine(to: CGPoint(x: connectionStart, y: primaryY))
                    path.addLine(to: CGPoint(x: connectionStart + 6, y: primaryY + 5))

                    path.move(to: CGPoint(x: connectionEnd - 9, y: primaryY - 5))
                    path.addLine(to: CGPoint(x: connectionEnd - 3, y: primaryY))
                    path.addLine(to: CGPoint(x: connectionEnd - 9, y: primaryY + 5))
                }
                .stroke(mode == .primary ? ConstantsAppColors.dexcomPrimaryMode : Color(white: 0.55), style: StrokeStyle(lineWidth: mode == .primary ? 3.5 : 1.5, lineCap: .round, lineJoin: .round))

                connectionLabel(Texts_BluetoothPeripheralView.primaryMode, width: connectionEnd - connectionStart - 10)
                    .offset(x: connectionStart + 8, y: primaryY - 19)

                if mode == .coexistence {
                    connectionLabel(Texts_BluetoothPeripheralView.coexistenceMode, width: connectionEnd - connectionStart - 10)
                        .offset(x: connectionStart + 8, y: 77)

                    // Draw the dotted line separately so the arrow into xDrip stays solid.
                    Path { path in
                        path.move(to: CGPoint(x: connectionStart, y: 96))
                        path.addLine(to: CGPoint(x: connectionEnd - 3, y: 96))
                    }
                    .stroke(ConstantsAppColors.dexcomCoexistenceMode, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [1, 6]))

                    Path { path in
                        path.move(to: CGPoint(x: connectionStart + 6, y: 91))
                        path.addLine(to: CGPoint(x: connectionStart, y: 96))
                        path.addLine(to: CGPoint(x: connectionStart + 6, y: 101))
                    }
                    .stroke(ConstantsAppColors.dexcomCoexistenceMode, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                }

                appTile(ConstantsHomeView.applicationName, width: appWidth, showsAppIcon: true)
                    .position(x: appWidth / 2, y: mode == .primary ? 32 : 96)

                if mode == .coexistence {
                    appTile(Texts_BluetoothPeripheralView.connectionDiagramOtherApp, width: appWidth)
                        .position(x: appWidth / 2, y: 32)
                }

                // In Coexistence mode the sensor spans both app rows so both connections stay straight.
                VStack(spacing: 5) {
                    Image(systemName: "sensor.radiowaves.left.and.right")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.green)
                    Text(verbatim: "Dexcom")
                        .font(.system(size: 12.8))
                        .foregroundStyle(Color(white: 0.775))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 60, height: mode == .primary ? 64 : 108)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 2)
                }
                .position(x: sensorX, y: mode == .primary ? 32 : 64)
            }
        }
        .frame(height: mode == .primary ? 64 : 128)
    }

    // Allow translated labels to fit the space left between the frames.
    private func connectionLabel(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .regular))
            .foregroundStyle(Color(white: 0.775))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: max(0, width), alignment: .leading)
    }

    // Use the app icon and mode colour for xDrip, with a neutral frame for Other App.
    private func appTile(_ title: String, width: CGFloat, showsAppIcon: Bool = false) -> some View {
        HStack(spacing: 6) {
            if showsAppIcon {
                Image("AppIconPreview")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "apps.iphone")
                    .font(.system(size: 17))
                    .foregroundStyle(Color(white: 0.65))
            }
            Text(verbatim: title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(white: 0.775))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: 44)
        .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(showsAppIcon ? mode.color : Color(white: 0.55), lineWidth: showsAppIcon ? 2 : 1)
        }
    }
}

extension SensorStartCodeView.Configuration {
    static let g7 = SensorStartCodeView.Configuration(
        title: Texts_BluetoothPeripheralView.sensorCode,
        message: Texts_HomeView.dexcomG7SelectSensorCodeMessage,
        codeSectionTitle: Texts_BluetoothPeripheralView.sensorCode,
        placeholder: "----",
        manualEntryMessage: Texts_BluetoothPeripheralView.dexcomG7PairingCodeMessage,
        allowsNoCode: false,
        scanner: .g7,
        showsCancelButton: false,
        noLabelFoundMessage: Texts_BluetoothPeripheralView.dexcomG7NoSensorLabelFound,
        invalidLabelMessage: Texts_BluetoothPeripheralView.dexcomG7InvalidSensorLabelFound
    )
}

// MARK: - Rows

/// Configured peripheral title, connection state and disclosure presentation.
private struct BluetoothPeripheralListRowView: View {
    let row: BluetoothPeripheralListRow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.connectionStatus.antennaSystemImage)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(row.connectionStatus.tintColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .fontWeight(row.connectionStatus.isActive ? .bold : .regular)
                    .foregroundStyle(ConstantsAppColors.rowTitleText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 4) {
                    if let mode = row.dexcomConnectionMode {
                        Image(systemName: mode.systemImage)
                            .foregroundStyle(mode.color)
                            .accessibilityLabel(dexcomModeAccessibilityLabel(mode))
                    }

                    Text(row.typeTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .font(.footnote)
                .foregroundStyle(ConstantsAppColors.rowDetailText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.connectionStatus.statusText)
                .font(.subheadline)
                .foregroundStyle(ConstantsAppColors.rowDetailText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.colorTertiary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func dexcomModeAccessibilityLabel(_ mode: DexcomConnectionMode) -> String {
        mode == .coexistence
            ? Texts_BluetoothPeripheralView.runningInCoexistenceMode
            : Texts_BluetoothPeripheralView.runningInPrimaryMode
    }
}

/// Category heading and optional connected-peripheral summary.
private struct BluetoothPeripheralSectionHeaderView: View {
    let section: BluetoothPeripheralsSection

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: section.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ConstantsUI.settingsSectionHeaderIconColor)
                .frame(width: 16)

            if let title = section.title {
                Text(title)
                    .foregroundStyle(ConstantsUI.tableViewHeaderTextColor)
            }
        }
    }
}

private extension BluetoothPeripheralDisplayStatus {
    var tintColor: Color {
        switch self {
        case .notScanning:
            return Color(.colorTertiary)
        case .discovering, .connecting, .reconnecting:
            return Color(.systemYellow)
        case .waitingForNextReading, .connected:
            return .green
        }
    }

    var isActive: Bool {
        switch self {
        case .notScanning:
            return false
        case .discovering, .connecting, .reconnecting, .waitingForNextReading, .connected:
            return true
        }
    }

    var rowBackgroundColor: Color {
        switch self {
        case .notScanning:
            return Color(.secondarySystemGroupedBackground)
        case .discovering, .connecting, .reconnecting:
            return ConstantsUI.connectingRowBackgroundColor
        case .waitingForNextReading, .connected:
            return ConstantsUI.activeRowBackgroundColor
        }
    }

    var antennaSystemImage: String {
        switch self {
        case .notScanning:
            return "antenna.radiowaves.left.and.right.slash"
        case .discovering, .connecting, .reconnecting, .waitingForNextReading, .connected:
            return "antenna.radiowaves.left.and.right"
        }
    }

    var statusText: String {
        compactStatusText
    }
}

/// One selectable value used by peripheral detail configuration lists.
private struct BluetoothPeripheralSelectionRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.colorSecondary))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(ConstantsAppColors.rowTitleText)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(ConstantsAppColors.rowDetailText)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.colorTertiary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
