import SwiftUI

/// Experimental collection and synchronisation controls remain under Advanced Settings.
struct DirectLibreSettingsView: View {
    @ObservedObject private var connection = Libre2PhoneConnection.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var showAllActivity = false
    @State private var deletion: Libre2UnresolvedReadings?

    var body: some View {
        Form {
            collectionSection
            checklistSection
            if needsRecovery { recoverySection }
            if connection.hasExperiment { readingsSection }
            activitySection
        }
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
                // One local expiry update, cancelled when the page closes or a new reading arrives.
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
            LabeledContent("Selected device", value: selectionTitle)
            if connection.busy || connection.transferFailed {
                Text(connection.status).font(.footnote)
            }
            Button(connection.phase == .phone ? "Switch to Watch" : "Return to iPhone") {
                connection.switchDevice()
            }
            .disabled(!connection.canSwitchDevice)
            if connection.busy {
                Button("Cancel transfer", role: .cancel) { connection.cancelTransfer() }
            }
        } header: {
            Text("Collection")
        } footer: {
            Text("Keep both apps open while switching. Stop sensor connections in other iPhone apps; xDrip can release only its own connection.")
        }
    }

    private var checklistSection: some View {
        Section("Connection checklist") {
            if connection.phase == .phone {
                check("Libre 2 sensor configured", connection.sensorConfigured)
                if connection.sensorConfigured {
                    check("Libre Native Algorithm enabled", connection.nativeAlgorithmEnabled)
                    check("Unlock payload enabled", connection.unlockPayloadEnabled)
                    check("iPhone connected to sensor", connection.phoneConnected)
                    check("Libre BLE reading within 3 minutes", connection.recentReading)
                }
            } else if connection.phase == .watch || connection.phase == .returningToPhone {
                check("iPhone collection paused", true)
            }
            check("Watch app reachable", connection.reachable)
        }
    }

    private var recoverySection: some View {
        Section("Recovery") {
            if connection.phase != nil && connection.phase != .phone {
                Text("Open both apps and select Return to iPhone to finish an interrupted transfer. Cancelling a transfer does not change the selected device.")
            }
            Text("To reset collection, use the ordinary sensor NFC scan on the phone. A successful scan resets the selection even when the Watch is unavailable; the Watch stops when it receives that reset.")
        }
        .font(.footnote)
    }

    private var readingsSection: some View {
        Section {
            DisclosureGroup("Unresolved Watch readings") {
                Text("History stays on the Watch until the phone confirms storage. Readings that cannot be matched to their original phone sensor can be inspected and deleted here.")
                    .font(.footnote)
                Button("Check unresolved readings") { connection.inspectUnresolvedReadings() }
                    .disabled(!connection.reachable)
                if !connection.historyStatus.isEmpty { Text(connection.historyStatus).font(.footnote) }
                if let unresolved = connection.unresolvedReadings, unresolved.count > 0 {
                    Button("Delete unresolved readings", role: .destructive) { deletion = unresolved }
                        .disabled(!connection.reachable)
                }
            }
        }
    }

    private var activitySection: some View {
        Section("Recent activity") {
            if connection.activity.isEmpty {
                Text("Connection and transfer events will appear here.").foregroundStyle(.secondary)
            }
            ForEach(Array(connection.activity.suffix(showAllActivity ? Libre2PhoneConnection.maximumActivityEntries : 5).reversed())) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.message)
                    Text(event.date, format: .dateTime.month().day().hour().minute().second())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if connection.activity.count > 5 {
                Button(showAllActivity ? "Show less" : "Show more (\(connection.activity.count))") {
                    showAllActivity.toggle()
                }
            }
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

    private func check(_ title: String, _ passed: Bool) -> some View {
        Label(title, systemImage: passed ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(passed ? Color.primary : Color.secondary)
    }
}
