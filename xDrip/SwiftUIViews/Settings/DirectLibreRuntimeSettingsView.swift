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

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { enabled ?? false },
                set: { request(.setEnabled($0)) })) {
                    Text("Background location").foregroundStyle(ConstantsAppColors.rowTitleText)
                }
            .disabled(enabled == nil || isBusy || !connection.reachable)
            if enabled == true, let accuracy {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Requested location accuracy").foregroundStyle(ConstantsAppColors.rowTitleText)
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
            }
            if isBusy || !status.isEmpty || !connection.reachable {
                HStack {
                    Text(connection.reachable ? (isBusy ? "Updating Watch settings…" : status) : "Open xDrip on the Watch to read or change these settings.")
                        .font(.footnote).foregroundStyle(ConstantsAppColors.rowDetailText)
                    Spacer()
                    if isBusy { ProgressView() }
                }
            }
            Button("Refresh runtime status") { request(.inspect) }
                .disabled(isBusy || !connection.reachable)
            DirectLibreNotificationTestButton()
        } header: {
            DirectLibreSectionHeader(title: "Background connection", symbol: "location.fill")
        } footer: {
            Text("Optional location updates may help collection continue in the background. Uses extra battery; continuous collection is not guaranteed.")
                .font(.footnote)
                .foregroundStyle(ConstantsUI.listSectionFooterTextColor)
                .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Test Watch notification") { schedule() }
                    .disabled(isScheduling || !connection.reachable)
                if isScheduling { ProgressView() }
                Spacer()
            }
            .buttonStyle(.borderless)
            Text("May restore immediate phone updates when the Watch is collecting but the phone lags. Schedules one Watch notification in 30 seconds.")
                .font(.footnote).foregroundStyle(ConstantsAppColors.rowDetailText)
            if !status.isEmpty {
                Text(status).font(.footnote).foregroundStyle(ConstantsAppColors.rowDetailText)
            }
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
