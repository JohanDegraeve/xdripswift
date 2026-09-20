import SwiftUI

/// One Watch-local report, downloaded explicitly after the test.
struct DirectLibreDiagnosticsView: View {
    @StateObject private var capture = Libre2CaptureController()
    @ObservedObject private var connection = Libre2PhoneConnection.shared
    @State private var confirmReplacement = false

    var body: some View {
        Form {
            Section {
                Text(capture.description)
                if let error = capture.error { Text(error).foregroundStyle(.red) }
                if capture.isBusy { ProgressView() }
                Button("Refresh status") { capture.refresh() }
                    .disabled(capture.isBusy || !connection.reachable)
                if capture.status?.isRecording == true {
                    Button("Stop and download") { capture.stopAndLoad() }
                        .disabled(capture.isBusy || !connection.reachable)
                } else {
                    Button("Start capture") {
                        if capture.status != nil { confirmReplacement = true }
                        else { capture.start() }
                    }
                    .disabled(capture.isBusy || !connection.reachable || !capture.hasInspected)
                    if capture.status != nil {
                        Button("Download stopped capture") { capture.stopAndLoad() }
                            .disabled(capture.isBusy || !connection.reachable)
                    }
                }
            } header: { Text("Watch connection capture") } footer: {
                Text("Records up to two hours, 5,000 events or 2 MB on the Watch, even without the phone. Open both apps to control or download it. Status is the last confirmed reply. Capture adds no reconnect attempts or background execution time.")
            }
            if let url = capture.reportURL {
                Section("Saved report") {
                    ShareLink(item: url) { Label("Share report", systemImage: "square.and.arrow.up") }
                    if let date = capture.savedAt { Text(date, format: .dateTime).font(.footnote) }
                }
            }
            Section("Pool test") {
                Text("After returning to reliable sensor range, first wait without interacting, then open xDrip without double-tapping, and finally double-tap if needed. Note those times separately. Bluetooth cycling is recorded as radio state changes. Water entry is not detected automatically.")
                Text("Includes Bluetooth requests, callbacks, reset decisions, setup and reading timing. No credentials, raw packets, glucose values or coordinates. Gaps and pending requests do not prove Apple throttling or radio loss.")
            }.font(.footnote)
        }
        .navigationTitle("Connection diagnostics")
        .onAppear { if connection.reachable { capture.refresh() } }
        .alert("Replace Watch capture?", isPresented: $confirmReplacement) {
            Button("Start new capture", role: .destructive) { capture.start() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The previous capture on the Watch will be replaced. Download it first if needed. The last complete report saved on the phone remains until another download succeeds.")
        }
    }
}
