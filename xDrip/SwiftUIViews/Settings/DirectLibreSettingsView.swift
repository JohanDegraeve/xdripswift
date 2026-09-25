import SwiftUI

/// Experimental collection and synchronisation controls remain under Advanced Settings.
struct DirectLibreSettingsView: View {
    @ObservedObject private var connection = Libre2PhoneConnection.shared
    @Environment(\.settingsNavigationActions) private var navigationActions
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var deletion: Libre2UnresolvedReadings?

    var body: some View {
        List {
            collectionSection
            checklistSection
            DirectLibreRuntimeSettingsView()
            troubleshootingSection
        }
        .font(.subheadline)
        .settingsListStyle(title: "Direct Libre (Experimental)")
        .onAppear {
            isVisible = true
            updateVisibility()
        }
        .onDisappear {
            isVisible = false
            updateVisibility()
        }
        .onChange(of: scenePhase) { _ in updateVisibility() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).receive(on: RunLoop.main)) { _ in
            if isVisible && scenePhase == .active { connection.refresh() }
        }
        .task(id: readingExpiration) {
            guard let expiration = readingExpiration else { return }
            do {
                // Refresh readiness only when the reading expires while this page is visible.
                try await Task.sleep(for: .seconds(max(0, expiration.timeIntervalSinceNow)))
                try Task.checkCancellation()
                connection.refresh()
            } catch { /* The page closed, backgrounded, or received a newer reading. */ }
        }
        .alert("Delete unresolved readings?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), presenting: deletion) { confirmed in
            Button("Delete \(confirmed.count) readings", role: .destructive) { connection.deleteUnresolvedReadings(confirmed) }
            Button("Cancel", role: .cancel) {}
        } message: { confirmed in
            Text("These \(confirmed.count) readings could not be matched to their original phone sensor. Deletion cannot be undone. Pending uploads and readings already saved on the phone are kept.")
        }
    }

    private var collectionSection: some View {
        Section {
            SettingsRowTextView(title: "Selected device", detail: selectionTitle, isEnabled: true)
            if connection.busy || connection.transferFailed {
                HStack {
                    Text(connection.status).font(.footnote)
                        .foregroundStyle(connection.transferFailed ? Color(.systemRed) : ConstantsAppColors.rowDetailText)
                    Spacer()
                    if connection.busy { ProgressView() }
                }
            }
            Button {
                connection.switchDevice()
            } label: {
                Text(connection.phase == .phone ? "Switch to Watch" : "Return to iPhone")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!connection.canSwitchDevice)
            .listRowInsets(ConstantsUI.bluetoothPeripheralStatusButtonRowInsets)
            if connection.busy {
                Button("Cancel transfer", role: .cancel) { connection.cancelTransfer() }
            }
        } header: {
            DirectLibreSectionHeader(title: "Collection", symbol: "arrow.left.arrow.right")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Keep both apps open while switching. Stop sensor connections in other iPhone apps; xDrip can release only its own connection.")
                if needsRecovery {
                    Text("Open both apps and return to iPhone to finish an interrupted transfer, or use the ordinary sensor NFC scan on the phone to reset collection.")
                }
            }
            .font(.footnote)
            .foregroundStyle(ConstantsUI.listSectionFooterTextColor)
            .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
        }
    }

    private var checklistSection: some View {
        Section {
            if connection.phase == .phone {
                check("Libre 2 sensor", connection.sensorConfigured, yes: "Configured", no: "Missing")
                if connection.sensorConfigured {
                    check("Libre Native Algorithm", connection.nativeAlgorithmEnabled, yes: "Enabled", no: "Disabled")
                    check("Unlock payload", connection.unlockPayloadEnabled, yes: "Enabled", no: "Suppressed")
                    check("iPhone connection", connection.phoneConnected, yes: "Connected", no: "Disconnected")
                    check("Reading after phone unlock", connection.recentReading, yes: "Fresh", no: "Waiting")
                }
            } else if connection.phase == .watch || connection.phase == .returningToPhone {
                SettingsRowTextView(title: "iPhone collection", detail: "Paused", isEnabled: true)
            }
            check("Watch app", connection.reachable, yes: "Reachable", no: "Unreachable")
        } header: {
            DirectLibreSectionHeader(title: "Connection checklist", symbol: "checklist")
        } footer: {
            if connection.phase == .phone {
                Text("A fresh reading must be less than three minutes old and received after a successful phone unlock on the current connection.")
                    .font(.footnote)
                    .foregroundStyle(ConstantsUI.listSectionFooterTextColor)
                    .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
            }
        }
    }

    private var troubleshootingSection: some View {
        Section {
            SettingsStaticRowView(title: "Recent activity", detail: "Last hour", isEnabled: true, showsDisclosure: true) {
                navigationActions?.push("Recent activity") { _ in AnyView(DirectLibreActivityView()) }
            }
            SettingsStaticRowView(title: "Connection diagnostics", detail: nil, isEnabled: true, showsDisclosure: true) {
                navigationActions?.push("Connection diagnostics") { _ in AnyView(DirectLibreDiagnosticsView()) }
            }
            if connection.hasExperiment { unresolvedReadings }
            SettingsStaticRowView(title: "Help", detail: nil, isEnabled: true, showsDisclosure: true) {
                navigationActions?.push("Direct Libre help") { _ in AnyView(DirectLibreHelpView()) }
            }
        } header: {
            DirectLibreSectionHeader(title: "Troubleshooting", symbol: "wrench.and.screwdriver")
        }
    }

    private var unresolvedReadings: some View {
        DisclosureGroup {
            Text("History stays on the Watch until the phone confirms storage. Readings that cannot be matched to their original phone sensor can be inspected and deleted here.")
                .font(.footnote).foregroundStyle(ConstantsAppColors.rowDetailText)
            Button("Check unresolved readings") { connection.inspectUnresolvedReadings() }
                .disabled(!connection.reachable)
            if !connection.historyStatus.isEmpty {
                Text(connection.historyStatus).font(.footnote).foregroundStyle(ConstantsAppColors.rowDetailText)
            }
            if let unresolved = connection.unresolvedReadings, unresolved.count > 0 {
                Button("Delete unresolved readings", role: .destructive) { deletion = unresolved }
                    .disabled(!connection.reachable)
            }
        } label: {
            SettingsRowTextView(title: "Unresolved Watch readings", detail: nil, isEnabled: true)
        }
    }

    private var selectionTitle: String {
        switch connection.phase {
        case .phone: return "iPhone"
        case .preparingWatch: return "Preparing Watch"
        case .watch: return "Watch"
        case .returningToPhone: return "Returning to iPhone"
        case nil: return "Unavailable"
        }
    }

    private var needsRecovery: Bool {
        connection.transferFailed || (!connection.busy && connection.phase != .phone && !connection.reachable)
    }

    private var readingExpiration: Date? {
        isVisible && scenePhase == .active ? connection.readingExpiration : nil
    }

    private func updateVisibility() {
        connection.settingsVisible = isVisible && scenePhase == .active
        if connection.settingsVisible { connection.refresh() }
    }

    private func check(_ title: String, _ passed: Bool, yes: String, no: String) -> some View {
        HStack(spacing: 8) {
            SettingsRowTextView(title: title, detail: passed ? yes : no, isEnabled: true)
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundStyle(passed ? Color.green : Color.gray)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shared heading hierarchy for the experimental page and its child pages.
struct DirectLibreSectionHeader: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(ConstantsUI.settingsSectionHeaderIconColor)
                .accessibilityHidden(true)
            Text(title).foregroundStyle(ConstantsUI.tableViewHeaderTextColor)
        }
        .font(.headline)
    }
}

private struct DirectLibreActivityView: View {
    @ObservedObject private var connection = Libre2PhoneConnection.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        let days = Dictionary(grouping: connection.activity.reversed()) { Calendar.current.startOfDay(for: $0.date) }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if connection.activity.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.page")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(Color(.colorTertiary))
                        Text("No connection or transfer events in the last hour.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color(.colorSecondary))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .accessibilityElement(children: .combine)
                } else {
                    ForEach(days.keys.sorted(by: >), id: \.self) { day in
                        daySection(day, events: days[day] ?? [])
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ConstantsUI.listBackGroundColor.ignoresSafeArea())
        .navigationTitle("Recent activity")
        .navigationBarTitleDisplayMode(.inline)
        .colorScheme(.dark)
        .onAppear { isVisible = true; connection.refresh() }
        .onDisappear { isVisible = false }
        .onChange(of: scenePhase) { if isVisible && $0 == .active { connection.refresh() } }
        .task(id: activityExpiration) {
            guard let expiration = activityExpiration else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, expiration.timeIntervalSinceNow)))
                try Task.checkCancellation()
                connection.refresh()
            } catch { /* Expiry updates run only while this page is visible. */ }
        }
    }

    private var activityExpiration: Date? {
        isVisible && scenePhase == .active ? connection.activityExpiration : nil
    }

    /// Matches Activity Log's compact timestamp/message rows and rounded daily groups.
    private func daySection(_ day: Date, events: [Libre2PhoneConnection.Activity]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(day, format: .dateTime.day().month(.wide).year())
                .font(.headline)
                .foregroundStyle(Color(.colorPrimary))
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .firstTextBaseline) {
                        Text(event.date, format: .dateTime.hour().minute().second())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color(.colorSecondary))
                        Text(event.message)
                            .font(.caption)
                            .foregroundStyle(Color(.colorPrimary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .accessibilityElement(children: .combine)
                    if index < events.count - 1 { Divider().padding(.leading, 8) }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct DirectLibreHelpView: View {
    var body: some View {
        List {
            Section {
                helpText("The selected device tells you where collection is assigned. Confirm that it is working by checking for a new glucose reading and its timestamp.")
                helpText("On the Watch, green means Bluetooth connected; orange means scanning or connecting, with blinking during scanning. Grey means no active connection attempt is reported or Bluetooth is unavailable. A green antenna alone does not confirm fresh readings.")
            } header: {
                DirectLibreSectionHeader(title: "Check the status", symbol: "antenna.radiowaves.left.and.right")
            }
            Section {
                helpText("Before switching to Watch, enable Libre Native Algorithm and the unlock payload, then wait for a fresh phone reading after a successful unlock. If the phone connected with unlock suppressed, reconnect it first. The checklist must show a reading less than three minutes old and a reachable Watch app.")
                helpText("Keep both apps open. Choose Switch to Watch to collect on the Watch, or Return to iPhone to collect on the phone. Other apps must release their own sensor connections.")
            } header: {
                DirectLibreSectionHeader(title: "Switching", symbol: "arrow.left.arrow.right")
            }
            Section {
                helpItem("1. Open and interact", "Bring the Watch within sensor range, open xDrip and swipe between its pages. Opening alone has not always been enough in testing. Allow the existing attempt to reconnect and check for a fresh reading.")
                helpItem("2. Restart the connection", "If readings do not resume, double-tap the large reading. This starts a new connection attempt. Brief grey during initialization can occur.")
                helpItem("3. Cycle Watch Bluetooth", "If resetting does not help, turn Bluetooth off and back on in the Watch's Settings. Reopen xDrip, swipe between pages and double-tap if needed.")
                helpItem("4. Relaunch xDrip", "If still stuck, close and relaunch the Watch app. Saved selection and sensor credentials are retained. Open the app to resume any enabled background location support.")
            } header: {
                DirectLibreSectionHeader(title: "Recover Watch readings", symbol: "arrow.clockwise")
            }
            Section {
                helpItem("Retry the return", "Open both apps and choose Return to iPhone. Cancel transfer stops the transaction; it does not itself restore phone collection.")
                helpItem("Release a retained connection", "If a device still appears to hold the sensor connection, cycling Bluetooth on that device may help. iPhone Bluetooth cycling also interrupts phone–Watch communication: turn it back on, reopen both apps and check the selected device before retrying. This is a fallback, not a routine switching step.")
                helpItem("Reclaim through NFC", "If normal return cannot complete, perform an ordinary sensor NFC scan on the phone. Only a successful scan resets collection. An unavailable Watch stops when it receives the reset; it may still be collecting until then.")
            } header: {
                DirectLibreSectionHeader(title: "Recover a stalled transfer", symbol: "arrow.triangle.2.circlepath")
            }
            Section {
                helpText("Enable Background location while xDrip is open on the Watch and allow location access. Updates run only while Watch collection is selected. Locations are not saved or shared. This uses extra battery and does not guarantee continuous collection.")
                helpText("Choose 100 m, 1 km or 3 km accuracy. Coarser accuracy may reduce battery use, but does not set the update interval. Use Refresh runtime status after granting permission; the displayed status is the last confirmed Watch reply.")
            } header: {
                DirectLibreSectionHeader(title: "Background collection", symbol: "location.fill")
            }
            Section {
                helpText("If the Watch has fresh readings but the phone is behind, use Test Watch notification under Background connection. A notification appearing on the Watch has restored prompt phone updates in testing, but this is not guaranteed and does not reconnect the sensor.")
                helpText("Open both apps and schedule the test. Once confirmed, return to the watch face and lock the phone. The notification is scheduled for 30 seconds later. Let it appear on the Watch, then compare reading times; tapping it is not required. Focus and notification settings may prevent it appearing.")
            } header: {
                DirectLibreSectionHeader(title: "Delayed phone updates", symbol: "bell")
            }
            Section {
                helpText("Recent activity shows the last hour of phone-side transfer and connection events. For detailed Watch recovery information, start Connection diagnostics before the problem occurs. Leave the capture running through recovery, note when you take each action, then stop and download it with both apps open.")
            } header: {
                DirectLibreSectionHeader(title: "Collect diagnostics", symbol: "doc.text.magnifyingglass")
            }
        }
        .settingsListStyle(title: "Direct Libre help", titleDisplayMode: .inline)
    }

    private func helpText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(ConstantsAppColors.rowDetailText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func helpItem(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ConstantsAppColors.rowTitleText)
            helpText(detail)
        }
    }
}
