import SwiftUI

/// One Watch-local report, downloaded explicitly after the test.
struct DirectLibreDiagnosticsView: View {
    @StateObject private var capture = Libre2CaptureController()
    @ObservedObject private var connection = Libre2PhoneConnection.shared
    @State private var confirmReplacement = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text(capture.description).font(.footnote).foregroundStyle(ConstantsAppColors.rowDetailText)
                    Spacer()
                    if capture.isBusy { ProgressView() }
                }
                if let error = capture.error { Text(error).font(.footnote).foregroundStyle(.red) }
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
            } header: {
                DirectLibreSectionHeader(title: "Watch connection capture", symbol: "antenna.radiowaves.left.and.right")
            } footer: {
                Text("Records up to 24 hours, 100,000 events or 10 MB on the Watch, whichever comes first, even without the phone. Open both apps to control or download it. Status is the last confirmed reply. Capture adds no reconnect attempts or background execution time.")
                    .font(.footnote)
                    .foregroundStyle(ConstantsUI.listSectionFooterTextColor)
                    .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
            }
            if let url = capture.reportURL {
                Section {
                    ShareLink(item: url) { Label("Share report", systemImage: "square.and.arrow.up") }
                    if let date = capture.savedAt {
                        Text(date, format: .dateTime).font(.footnote).foregroundStyle(ConstantsAppColors.rowDetailText)
                    }
                } header: {
                    DirectLibreSectionHeader(title: "Saved report", symbol: "doc.text")
                }
            }
            Section {
                Text("Includes Bluetooth requests, callbacks, reset decisions, setup and reading timing. No credentials, raw packets, glucose values or coordinates. Gaps and pending requests do not prove Apple throttling or radio loss.")
                    .font(.footnote).foregroundStyle(ConstantsAppColors.rowDetailText)
            } header: {
                DirectLibreSectionHeader(title: "About the capture", symbol: "info.circle")
            }
        }
        .font(.subheadline)
        .settingsListStyle(title: "Connection diagnostics", titleDisplayMode: .inline)
        .onAppear { if connection.reachable { capture.refresh() } }
        .alert("Replace Watch capture?", isPresented: $confirmReplacement) {
            Button("Start new capture", role: .destructive) { capture.start() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The previous capture on the Watch will be replaced. Download it first if needed. The last complete report saved on the phone remains until another download succeeds.")
        }
    }
}
