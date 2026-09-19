import SwiftUI
import WatchConnectivity

/// Runtime options are interactive Watch settings, independent of the sensor transfer.
struct DirectLibreRuntimeSettingsView: View {
    @ObservedObject private var connection = Libre2PhoneConnection.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var enabled: Bool?
    @State private var accuracy: Libre2LocationRequest.Accuracy?
    @State private var status = ""
    @State private var isBusy = false
    @State private var isVisible = false
    @State private var showsHelp = false

    var body: some View {
        Section {
            Toggle("Background location", isOn: Binding(
                get: { enabled ?? false },
                set: { request(.setEnabled($0)) }))
                .disabled(enabled == nil || isBusy || !connection.reachable)
            if enabled == true, let accuracy {
                Picker("Requested location accuracy", selection: Binding(
                    get: { self.accuracy ?? accuracy },
                    set: { if $0 != self.accuracy { request(.setAccuracy($0)) } })) {
                    Text("100 m").tag(Libre2LocationRequest.Accuracy.hundredMeters)
                    Text("1 km").tag(Libre2LocationRequest.Accuracy.kilometer)
                    Text("3 km").tag(Libre2LocationRequest.Accuracy.threeKilometers)
                }
                .pickerStyle(.segmented)
                .disabled(isBusy || !connection.reachable)
            }
            if isBusy { ProgressView() }
            Text(connection.reachable ? status : "Open xDrip on the Watch to read or change these settings.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Refresh runtime status") { request(.inspect) }
                .disabled(isBusy || !connection.reachable)
            DirectLibreNotificationTestButton()
        } header: {
            HStack {
                Text("Background connection")
                Spacer()
                Button { showsHelp = true } label: { Image(systemName: "info.circle") }
                    .accessibilityLabel("About background connection")
            }
        } footer: {
            Text("Optional location updates may help collection continue in the background. Uses extra battery; continuous collection is not guaranteed.")
        }
        .alert("Background connection", isPresented: $showsHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable while xDrip is open on the Watch and allow location access. Updates run only while Watch collection is selected. Locations are never saved or shared.\n\n100 m matches the prototype. 1 km and 3 km request coarser accuracy and may reduce energy use, but savings and background reliability need device testing. These choices do not set a polling interval.\n\nThe status is the last reply from the Watch. Refresh after granting permission to confirm it has received a location update.")
        }
        .onAppear { isVisible = true; request(.inspect) }
        .onDisappear { isVisible = false }
        .onChange(of: connection.reachable) { if $0 { request(.inspect) } }
        .onChange(of: connection.phase) { _ in request(.inspect) }
        .onChange(of: scenePhase) { if $0 == .active { request(.inspect) } }
    }

    private func request(_ request: Libre2LocationRequest) {
        guard isVisible, scenePhase == .active, !isBusy,
              WCSession.default.activationState == .activated, connection.reachable else { return }
        do {
            let message = try request.dictionary
            isBusy = true
            WCSession.default.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    isBusy = false
                    guard let value = reply["enabled"] as? Bool,
                          let detail = reply["status"] as? String,
                          let rawAccuracy = reply["accuracy"] as? Int,
                          let confirmedAccuracy = Libre2LocationRequest.Accuracy(rawValue: rawAccuracy) else {
                        unconfirmed()
                        return
                    }
                    enabled = value
                    accuracy = confirmedAccuracy
                    status = "Last Watch status: \(detail)"
                }
            }, errorHandler: { _ in
                DispatchQueue.main.async { isBusy = false; unconfirmed() }
            })
        } catch { unconfirmed() }
    }

    private func unconfirmed() {
        // A lost reply cannot establish whether the Watch applied the setting.
        enabled = nil
        accuracy = nil
        status = "Could not confirm the Watch setting. Open both apps and refresh runtime status."
    }
}

/// One explicit test; a lost reply never causes an automatic resend.
private struct DirectLibreNotificationTestButton: View {
    @ObservedObject private var connection = Libre2PhoneConnection.shared
    @State private var isScheduling = false
    @State private var status = ""
    @State private var showsHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Test Watch notification") { schedule() }
                    .disabled(isScheduling || !connection.reachable)
                if isScheduling { ProgressView() }
                Spacer()
                Button { showsHelp = true } label: { Image(systemName: "info.circle") }
                    .accessibilityLabel("About the notification test")
            }
            .buttonStyle(.borderless)
            Text("May restore immediate phone updates when the Watch is collecting but the phone lags. Schedules one Watch notification in 30 seconds.")
                .font(.footnote).foregroundStyle(.secondary)
            if !status.isEmpty { Text(status).font(.footnote) }
        }
        .alert("Test Watch notification", isPresented: $showsHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("In prototype testing, a notification appearing on the Watch restored immediate delivery of new readings while both apps stayed in the background. Updates continued after the notification closed, without tapping it. This is an experimental workaround, not a guaranteed connection.\n\nOpen both apps to schedule the test. After confirmation, return to the watch face and lock the phone. Let the notification appear on the Watch and check subsequent reading times without opening either app. Notification settings and Focus may affect presentation. Another press replaces the pending test.")
        }
    }

    private func schedule() {
        let session = WCSession.default
        guard !isScheduling, session.activationState == .activated, session.isReachable else { return }
        isScheduling = true
        status = ""
        session.sendMessage([Libre2NotificationTest.requestKey: true], replyHandler: { reply in
            DispatchQueue.main.async {
                isScheduling = false
                if let error = reply["error"] as? String {
                    status = error
                } else if let timestamp = reply[Libre2NotificationTest.scheduledAtKey] as? Double,
                          timestamp.isFinite, timestamp > 0 {
                    let date = Date(timeIntervalSince1970: timestamp).formatted(date: .omitted, time: .standard)
                    status = "Watch test scheduled for \(date). Return to the watch face and lock the phone."
                    connection.recordActivity(status)
                } else {
                    unconfirmed()
                }
            }
        }, errorHandler: { _ in
            DispatchQueue.main.async { isScheduling = false; unconfirmed() }
        })
    }

    private func unconfirmed() {
        status = "Watch scheduling was not confirmed. A notification may still appear. Open both apps before retrying."
    }
}
