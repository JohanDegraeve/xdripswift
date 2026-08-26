import Combine
import SwiftUI
import UIKit

/// Main-actor bridge between the queue-confined store and SwiftUI.
///
/// The store posts only after a useful record changes. Observing on the main queue gives an already
/// open screen live updates without exposing the store's mutable cache or file queue to the view.
@MainActor
final class TroubleshootingLogViewModel: ObservableObject {
    @Published private(set) var entries = [TroubleshootingLogEntry]()
    @Published private(set) var appInfo: TroubleshootingLogAppInfo
    @Published private(set) var refreshedAt = Date()

    private let store: TroubleshootingLogStore
    private let appInfoProvider: () -> TroubleshootingLogAppInfo
    private var changeObserver: NSObjectProtocol?

    init(
        store: TroubleshootingLogStore = .shared,
        appInfoProvider: @escaping () -> TroubleshootingLogAppInfo = { .current() }
    ) {
        self.store = store
        self.appInfoProvider = appInfoProvider
        appInfo = appInfoProvider()
        // `snapshot()` waits behind queued writes, so the first frame and every later reload see a
        // complete history rather than racing an append that triggered the notification.
        reload()
        changeObserver = NotificationCenter.default.addObserver(
            forName: .troubleshootingLogDidChange,
            object: store,
            queue: .main
        ) { [weak self] _ in
            // NotificationCenter's closure is not actor-annotated even when its delivery queue is
            // `.main`. Make the actor hop explicit so future strict-concurrency builds preserve the
            // same guarantee rather than relying on an implementation detail of the callback queue.
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    func reload() {
        entries = store.snapshot()
        // Cadence is read from the latest Core Data history once per reload. Keeping the resulting
        // value in this main-actor snapshot avoids repeating a database query for every visible row.
        appInfo = appInfoProvider()
        // The header is intentionally fresh. Copy and Share should say when this exact snapshot was
        // generated, not when the view model happened to be constructed.
        refreshedAt = Date()
    }
}

/// Consumer-facing view of the safe activity history.
///
/// Every retained troubleshooting entry is available, with an optional presentation-only text
/// filter over the same controlled sentence shown in each row. The typed query is applied only when
/// the user submits Search so the keyboard can be dismissed before they read the results. Copy and
/// Share deliberately retain the complete report so a temporary screen filter cannot silently
/// produce incomplete support information. App and device information remains export-only, and
/// developer trace attachments remain on the parent Troubleshooting screen and are never read here.
struct TroubleshootingLogView: View {
    @StateObject private var viewModel: TroubleshootingLogViewModel
    @State private var copied = false
    @State private var filterText = ""
    @State private var appliedFilterText = ""
    @FocusState private var filterFieldIsFocused: Bool

    init(
        store: TroubleshootingLogStore = .shared,
        coreDataManager: CoreDataManager? = nil
    ) {
        // Reuse the production cadence detector instead of guessing from a source name. This
        // manager instance is read-only in this view: the report asks it only for recent cadence,
        // so opening Activity Log cannot reprocess or otherwise modify glucose history.
        let bgPostProcessingManager = coreDataManager.map {
            BgPostProcessingManager(coreDataManager: $0, nightscoutSyncManager: nil, healthKitManager: nil)
        }
        _viewModel = StateObject(wrappedValue: TroubleshootingLogViewModel(
            store: store,
            appInfoProvider: {
                // Read the current G5/G6 channel for each report snapshot. The effective accessor
                // applies the default in memory without materializing it merely by opening this view.
                let dexcomG5 = coreDataManager.flatMap { coreDataManager in
                    BLEPeripheralAccessor(coreDataManager: coreDataManager)
                        .getBLEPeripherals()
                        .first(where: { $0.shouldconnect && $0.dexcomG5 != nil })?
                        .dexcomG5
                }
                return .current(
                    currentSourceCanUseFiveMinuteReadings: bgPostProcessingManager?.currentSourceCanUseFiveMinuteReadings(),
                    dexcomBluetoothChannel: dexcomG5.map {
                        TroubleshootingDexcomBluetoothChannel(
                            $0.effectiveDexcomG6BluetoothSlot()
                        )
                    }
                )
            }
        ))
    }

    var body: some View {
        // Filtering formats every candidate through the same controlled report sentence. Capture the
        // grouped result once per body update so an empty-state check does not repeat that work.
        let visibleDayGroups = dayGroups

        VStack(spacing: 0) {
            filterField

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if report.entries.isEmpty {
                        emptyState
                    } else if visibleDayGroups.isEmpty {
                        noResultsState
                    } else {
                        ForEach(visibleDayGroups) { group in
                            daySection(group)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(ConstantsUI.listBackGroundColor.ignoresSafeArea())
        // The parent destination is already named Troubleshooting. Naming the viewer Activity Log
        // preserves that hierarchy instead of repeating "Troubleshooting" on consecutive screens.
        .navigationTitle(Texts_SettingsView.activityLogSectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                OnlineHelpButton(topic: .activityLog)

                Button(action: copyReport) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .tint(ConstantsAppColors.toolbarAction)
                .accessibilityLabel(copied ? "Copied" : "Copy Troubleshooting Log")

                ShareLink(item: report.reportText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .tint(ConstantsAppColors.toolbarAction)
                .accessibilityLabel("Share Troubleshooting Log")
            }
        }
        .onAppear(perform: viewModel.reload)
    }

    /// Lives outside the `ScrollView` so the user can always refine or clear the query, including
    /// when the submitted text matches no entries. Editing does not repeatedly rebuild a covered
    /// list; the keyboard Search action applies the completed query and then reveals the results.
    private var filterField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(.colorSecondary))
                .accessibilityHidden(true)

            TextField(Texts_SettingsView.activityLogFilterPlaceholder, text: $filterText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .focused($filterFieldIsFocused)
                .onSubmit(applyFilter)
                .onChange(of: filterText) { newValue in
                    // Clearing the field has only one useful interpretation, so restore the complete
                    // list immediately instead of requiring Search to submit an empty query.
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        appliedFilterText = ""
                    }
                }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func applyFilter() {
        appliedFilterText = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        filterFieldIsFocused = false
    }

    /// Single wording source for visible rows and both complete export actions.
    ///
    /// The filter derives matches from `message(for:)` without replacing this builder's full entry
    /// list. `appInfo` is supplied even though it is export-only because Copy and Share place that
    /// context at the top of the plain text sent to support.
    private var report: TroubleshootingLogReportBuilder {
        TroubleshootingLogReportBuilder(
            entries: viewModel.entries,
            usesMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
            appInfo: viewModel.appInfo,
            generatedAt: viewModel.refreshedAt,
            timeZone: .current
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.page")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color(.colorTertiary))

            Text("No troubleshooting information was recorded during the previous 24 hours.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(.colorSecondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .accessibilityElement(children: .combine)
    }

    /// Distinguishes a valid search with no matches from an Activity Log that has no retained history.
    /// Keep this intentionally brief and visually consistent with native unavailable-content states.
    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color(.colorTertiary))

            Text(Texts_SettingsView.activityLogNoResults)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(.colorSecondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .accessibilityElement(children: .combine)
    }

    /// Groups the newest-first visible entries without changing their order inside each local day.
    private var dayGroups: [TroubleshootingLogDayGroup] {
        var groups = [TroubleshootingLogDayGroup]()
        let calendar = Calendar.current

        for entry in report.entries(matching: appliedFilterText) {
            let day = calendar.startOfDay(for: entry.timestamp)
            if groups.last?.day == day {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append(TroubleshootingLogDayGroup(day: day, entries: [entry]))
            }
        }
        return groups
    }

    private func daySection(_ group: TroubleshootingLogDayGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = group.entries.first {
                Text(report.dayText(for: first))
                    .font(.headline)
                    .foregroundStyle(Color(.colorPrimary))
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
            }

            VStack(spacing: 0) {
                ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                    troubleshootingRow(entry)
                    if index < group.entries.count - 1 {
                        Divider().padding(.leading, 8)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func troubleshootingRow(_ entry: TroubleshootingLogEntry) -> some View {
        // These items deliberately use SwiftUI's standard HStack spacing. Fixed icon and timestamp
        // columns introduced invisible trailing space inside both views, which made the row appear
        // to have several unrelated gaps even though its declared stack spacing was small.
        HStack(alignment: .firstTextBaseline) {
            // Temporarily hide the semantic row symbol while evaluating the denser text-first layout.
            // Keep the mapping below intact so restoring the symbols after device testing is trivial.
//            Image(systemName: symbol(for: entry))
//                .font(compactRowFont.weight(.semibold))
//                .foregroundStyle(color(for: entry))

            Text(report.timeText(for: entry))
                .font(compactRowFont.monospacedDigit())
                .foregroundStyle(Color(.colorSecondary))

            Text(report.message(for: entry))
                .font(compactRowFont)
                .foregroundStyle(Color(.colorPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        // VoiceOver receives the same controlled sentence as Copy and Share, with the visual columns
        // combined into one natural utterance.
        .accessibilityLabel("\(report.timeText(for: entry)), \(report.message(for: entry))")
    }

    /// A semantic caption keeps the visible timestamp and message compact while continuing to follow
    /// the user's Dynamic Type setting. No fixed widths are imposed, so scaling cannot create
    /// artificial whitespace. The hidden symbol uses this same font when enabled again.
    private var compactRowFont: Font { .caption }

    private func symbol(for entry: TroubleshootingLogEntry) -> String {
        switch entry.kind {
        case .glucoseAccepted: return "drop.fill"
        case let .bluetooth(activity):
            switch activity {
            case .connectionFailed, .connectionTimedOut, .poweredOff, .unauthorized, .pairingFailed:
                return "antenna.radiowaves.left.and.right.slash"
            case .scanning, .connecting, .connected, .connectionRestored, .disconnected,
                 .pairingRequested, .pairingSucceeded:
                return "antenna.radiowaves.left.and.right"
            }
        case .bluetoothDevice: return "antenna.radiowaves.left.and.right"
        case .cgm: return "sensor.tag.radiowaves.forward.fill"
        case let .follower(_, activity):
            switch activity {
            case .loginStarted: return "person.crop.circle"
            case .loginSucceeded, .recovered: return "person.crop.circle.badge.checkmark"
            case .loginFailed: return "person.crop.circle.badge.xmark"
            case .loggedOut: return "rectangle.portrait.and.arrow.right"
            case .sessionExpired: return "person.crop.circle.badge.clock"
            case .downloadStarted, .downloadSucceeded, .downloadFailed, .noReadings, .retryScheduled:
                return "network"
            }
        case .sensor: return "sensor.tag.radiowaves.forward.fill"
        case .sensorLabelScan: return "barcode.viewfinder"
        case .sensorNoise: return "waveform.path.ecg"
        case .sensorHealthAlert: return "exclamationmark.triangle.fill"
        case .transmitterReadSuccess: return "antenna.radiowaves.left.and.right"
        case .calibrationAccepted: return "scope"
        case let .alert(_, activity):
            return activity == .notificationsDenied || activity == .suppressedBySnooze || activity == .notificationDismissed || activity == .disabled ? "bell.slash.fill" : "bell.fill"
        case let .integration(.watch, activity):
            switch activity {
            case .failed, .permissionDenied:
                return "exclamationmark.applewatch"
            case .succeeded, .recovered:
                return "checkmark.applewatch"
            case .started, .noData, .restarted, .ended:
                return "applewatch"
            }
        case let .integration(name, _):
            switch name {
            case .nightscout, .nightscoutImport, .nightscoutBackfill: return "cloud.fill"
            case .healthKit: return "heart.text.square.fill"
            case .liveActivity: return "iphone"
            case .calendar: return "calendar"
            case .contactImage: return "person.crop.circle"
            case .osAid: return "arrow.left.arrow.right"
            case .watch: return "applewatch"
            }
        case .heartbeatReceived: return "heart.circle.fill"
        case let .configuration(activity):
            switch activity {
            case .modeChanged: return "person.2.fill"
            case .followerSourceChanged: return "arrow.triangle.branch"
            case .cgmSourceChanged, .cgmSourceDisconnected: return "sensor.tag.radiowaves.forward.fill"
            case .keepAliveChanged: return "gearshape.2.fill"
            case .dexcomConnectionModeChanged: return "person.2.fill"
            case .dexcomBluetoothChannelChanged: return "antenna.radiowaves.left.and.right"
            case .therapySourceChanged: return "cross.case.fill"
            case .liveActivityChanged: return "iphone"
            case .aidFollowerChanged: return "waveform.path.ecg"
            case .patientAliasChanged: return "person.text.rectangle.fill"
            case .credentialChanged: return "key.fill"
            case .postProcessingSettings: return "waveform.path.ecg.rectangle"
            }
        case let .dataManagement(activity):
            switch activity {
            case .deletionCompleted, .cleanupCompleted: return "trash.fill"
            case .automaticCleanupChanged, .retentionChanged, .backupCreated, .backupRestored: return "externaldrive.fill"
            case .operationFailed: return "externaldrive.badge.exclamationmark"
            }
        case let .glucoseManagement(activity):
            switch activity {
            case .changed: return "pencil"
            case .deleted: return "trash.fill"
            }
        case let .treatment(activity):
            switch activity {
            case .added: return "plus.circle.fill"
            case .edited: return "pencil"
            case .deleted: return "trash.fill"
            }
        case .app: return "text.document"
        }
    }

    private func color(for entry: TroubleshootingLogEntry) -> Color {
        switch entry.kind {
        case let .bluetooth(activity) where [.connectionFailed, .connectionTimedOut, .poweredOff, .unauthorized, .pairingFailed].contains(activity):
            return .orange
        case let .cgm(_, activity) where [.nfcScanFailed, .nfcScanTimedOut, .nfcUnavailable].contains(activity):
            return .orange
        case let .follower(_, activity) where activity == .loginFailed || activity == .downloadFailed:
            return .orange
        case let .integration(_, activity) where activity == .failed || activity == .permissionDenied:
            return .orange
        case .sensorLabelScan(.failed):
            return .orange
        case let .alert(_, activity) where activity == .notificationsDenied:
            return .orange
        case .dataManagement(.operationFailed):
            return .orange
        case let .calibrationAccepted(_, readiness):
            switch readiness?.overall {
            case .good: return ConstantsAppColors.normal
            case .caution: return ConstantsAppColors.caution
            case .bad: return ConstantsAppColors.urgent
            case nil: return ConstantsAppColors.navigationTint
            }
        default:
            return ConstantsAppColors.navigationTint
        }
    }

    private func copyReport() {
        // Do not reconstruct text for the pasteboard. `reportText` is the parity contract shared with
        // `ShareLink`, including every retained entry, the export-only header and empty-state wording.
        UIPasteboard.general.string = report.reportText
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}

/// Lightweight presentation grouping only; it is never persisted as a second history format.
private struct TroubleshootingLogDayGroup: Identifiable {
    let day: Date
    var entries: [TroubleshootingLogEntry]

    var id: Date { day }
}
