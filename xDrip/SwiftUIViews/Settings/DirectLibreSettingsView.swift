import SwiftUI

/// Experimental collection and synchronisation controls remain under Advanced Settings.
struct DirectLibreSettingsView: View {
    @ObservedObject private var connection = Libre2PhoneConnection.shared

    @State private var deletion: Libre2UnresolvedReadings?

    var body: some View {
        Form {
            Section("Collection") {
                Text(selectionTitle)
                Text(connection.status).font(.footnote)
                if connection.phase == .phone || connection.phase == .preparingWatch {
                    Button("Switch to Watch") { connection.switchToWatch() }
                        .disabled(connection.busy || !connection.canSwitchToWatch)
                } else {
                    Button("Return to iPhone") { connection.returnToPhone() }
                        .disabled(connection.busy || !connection.reachable)
                }
                if connection.busy {
                    Button("Cancel transfer") { connection.cancelTransfer() }
                }
            }
            Section("Connection checklist") {
                check("Watch app reachable", connection.reachable)
                check("iPhone connected", connection.transmitter?.getConnectionStatus() == .connected)
                check("Recent Libre BLE reading", connection.recentReading)
                check("Libre Native Algorithm enabled", connection.transmitter?.isWebOOPEnabled() == true)
                check("Unlock payload enabled", !UserDefaults.standard.suppressUnLockPayLoad)
            }
            Section("Watch readings") {
                Text("The latest reading is sent separately from saved history. History stays on the Watch until the phone confirms storage. Background delivery timing is controlled by watchOS.")
                    .font(.footnote)
                Button("Check unresolved readings") { connection.inspectUnresolvedReadings() }
                    .disabled(!connection.reachable)
                if !connection.historyStatus.isEmpty { Text(connection.historyStatus).font(.footnote) }
                if let unresolved = connection.unresolvedReadings, unresolved.count > 0 {
                    Button("Delete unresolved readings", role: .destructive) { deletion = unresolved }
                        .disabled(!connection.reachable)
                }
            }
            Section("Recovery") {
                Text("Stop sensor connections in other iPhone apps before switching. xDrip can release only its own connection.")
                Text("Keep both apps open while switching. If a transfer is interrupted, retry Return to iPhone. A successful ordinary sensor NFC scan on the phone resets the selection, including when the Watch is unreachable. The Watch stops when it receives the reset.")
            }
        }
        .onAppear { connection.refresh() }
        .alert("Delete unresolved readings?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), presenting: deletion) { confirmed in
            Button("Delete \(confirmed.count) readings", role: .destructive) { connection.deleteUnresolvedReadings(confirmed) }
            Button("Cancel", role: .cancel) {}
        } message: { confirmed in
            Text("These \(confirmed.count) readings could not be matched to their original phone sensor. Deletion cannot be undone. Pending uploads and readings already saved on the phone are kept.")
        }
    }

    private var selectionTitle: String {
        switch connection.phase {
        case .phone: return "Selected device: iPhone"
        case .preparingWatch: return "Preparing Watch"
        case .watch: return "Selected device: Watch"
        case .returningToPhone: return "Returning to iPhone"
        case nil: return "Selection unavailable"
        }
    }

    private func check(_ title: String, _ passed: Bool) -> some View {
        Label(title, systemImage: passed ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(passed ? Color.primary : Color.secondary)
    }
}
