import SwiftUI

/// Initial switching checkpoint. History synchronisation and runtime options follow separately.
struct DirectLibreSettingsView: View {
    @ObservedObject private var connection = Libre2PhoneConnection.shared

    var body: some View {
        Form {
            Section("Collection") {
                Text(connection.phase == .phone ? "Selected device: iPhone" : "Selected device: Watch / transfer pending")
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
            Section("Recovery") {
                Text("Keep both apps open while switching. If a transfer is interrupted, retry Return to iPhone. A successful ordinary sensor NFC scan on the phone resets the selection, including when the Watch is unreachable. The Watch stops when it receives the reset.")
                Text("This checkpoint displays direct Watch readings locally. History synchronisation to the phone is not implemented yet.")
                    .font(.footnote)
            }
        }
        .onAppear { connection.refresh() }
    }

    private func check(_ title: String, _ passed: Bool) -> some View {
        Label(title, systemImage: passed ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(passed ? Color.primary : Color.secondary)
    }
}
