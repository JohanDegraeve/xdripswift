//
//  DirectWatchSetupView.swift
//  xDrip
//
//  Created by Paul Plant on 12/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

struct DirectWatchSetupContext {
    let transmitterID: String
    let isAnubis: Bool
    let phoneSlot: UInt8
    let nativeGlucose: Bool
    var family: DirectWatchTransmitterFamily = .g6
    var pairingCode: String? = nil
    var deviceName: String? = nil
}

struct DirectWatchSetupView: View {
    let context: DirectWatchSetupContext
    @State private var selectedSlot = 1
    @State private var configuration: DirectWatchConfiguration?
    @State private var showMedicalWarning = false
    @State private var showWatchSlotWarning = false
    @State private var showPairingGuidance = false
    @State private var unavailableReason: String?
    @State private var statusNow = Date()
    @State private var watchPaused = false
    @State private var cloudUploadEnabled = false
    @State private var showActivationAdvice = false
    @State private var lastConnectedAt: Date?
    @State private var lastCollectedAt: Date?

    // Keep unavailable/paused setups editable without asking the user to add them again.
    private var enabled: Bool { configuration?.transmitterID == context.transmitterID && configuration?.transmitterFamily == context.family }
    // The iPhone role is excluded from selection, but remains visible as a disabled row.
    private var availableSlots: [Int] {
        context.family.availableSlots(isAnubis: context.isAnubis).map(Int.init).filter { $0 != Int(context.phoneSlot) }
    }
    private var canAdd: Bool {
        availableSlots.contains(selectedSlot) && context.nativeGlucose && UserDefaults.standard.activeSensorStartDate != nil
    }

    var body: some View {
        Form {
            Section {
                statusBanner
                    .listRowInsets(ConstantsUI.bluetoothPeripheralStatusBannerRowInsets)
                    .listRowBackground(statusBanner.rowBackgroundColor)
            }

            if enabled {
                Section {
                    DirectWatchCollectionControlButton(isPaused: watchPaused) {
                        DirectWatchSettings.pauseWatch(!watchPaused)
                        reload()
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            if !enabled {
                Section {
                    Text(TextsDirectWatch.intro)
                } footer: {
                    Text(TextsDirectWatch.backgroundAdvice)
                }
            }

            slotSelectionSection

            if !enabled {
                Section {
                    Button {
                        if selectedSlot == 1 { showMedicalWarning = true }
                        else if context.family == .g7 && selectedSlot == 3 { showWatchSlotWarning = true }
                        else { enable() }
                    } label: {
                        Text(TextsDirectWatch.addConnection)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAdd)
                } footer: {
                    if !context.nativeGlucose {
                        Text(TextsDirectWatch.nativeRequired)
                    } else if UserDefaults.standard.activeSensorStartDate == nil {
                        Text(TextsDirectWatch.startSensor)
                    } else if availableSlots.isEmpty {
                        Text(TextsDirectWatch.noSlot)
                    }
                }
            }

            if enabled {
                Section {
                    Toggle(TextsDirectWatch.cloudUpload, isOn: Binding(get: { cloudUploadEnabled }, set: {
                        UserDefaults.standard.set($0, forKey: DirectWatchUploadSettings.enabledKey)
                        if $0 { UserDefaults.standard.set(Date(), forKey: DirectWatchUploadSettings.enabledSinceKey) }
                        NotificationCenter.default.post(name: DirectWatchUploadSettings.changed, object: nil)
                        reload()
                    }))
                    if cloudUploadEnabled {
                        cloudUploadStatusRow(Texts_SettingsView.sectionTitleNightscout, isEnabled: nightscoutAvailable)
                        cloudUploadStatusRow(Texts_SettingsView.sectionTitleDexcomShareUpload, isEnabled: dexcomShareAvailable)
                    }
                } header: {
                    Label(TextsDirectWatch.uploadReadings, systemImage: "icloud.and.arrow.up")
                } footer: {
                    Text(TextsDirectWatch.cloudUploadAdvice)
                }
            }

            Section {
                NavigationLink(TextsDirectWatch.testingLogs) {
                    DirectWatchConnectionToolsView(transmitterID: context.transmitterID, family: context.family)
                }
            }

            if enabled {
                Section {
                    Button(TextsDirectWatch.removeConnection, role: .destructive) {
                        DirectWatchSettings.save(nil)
                        reload()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .colorScheme(.dark)
        .navigationTitle(TextsDirectWatch.title)
        .navigationBarTitleDisplayMode(.large)
        .onlineHelp(.directToWatch)
        .onAppear {
            reload()
            selectedSlot = enabled ? Int(configuration?.slot ?? 1)
                : ([3, 1, 2].first { availableSlots.contains($0) } ?? 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: DirectWatchSettings.changed)) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: DirectWatchSettings.statusChanged)) { _ in reload() }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in reload() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { statusNow = $0 }
        .alert(TextsDirectWatch.title, isPresented: $showActivationAdvice) {
            Button(Texts_Common.Ok, role: .cancel) { showPairingGuidance = true }
        } message: {
            Text(TextsDirectWatch.activationAdvice)
        }
        .alert(TextsDirectWatch.added, isPresented: $showPairingGuidance) {
            Button(Texts_Common.Ok, role: .cancel) {}
        } message: {
            Text(TextsDirectWatch.pairingGuidance)
        }
        .alert(TextsDirectWatch.medicalSlot, isPresented: $showMedicalWarning) {
            Button(TextsDirectWatch.cancel, role: .cancel) {}
            Button(TextsDirectWatch.confirmUnusedSlot) { enable() }
        } message: {
            Text(TextsDirectWatch.medicalWarning)
        }
        .alert(TextsDirectWatch.watchSlot, isPresented: $showWatchSlotWarning) {
            Button(TextsDirectWatch.cancel, role: .cancel) {}
            Button(TextsDirectWatch.confirmUnusedSlot) { enable() }
        } message: {
            Text(TextsDirectWatch.watchSlotWarning)
        }
    }
    private var slotSelectionSection: some View {
        Section {
            ForEach(enabled ? [Int(configuration?.slot ?? UInt8(selectedSlot))] : Array(1...3), id: \.self) { slot in
                slotSelectionRow(slot)
            }
        } header: {
            Text(TextsDirectWatch.bluetoothSlot)
        } footer: {
            if !enabled {
                Text(TextsDirectWatch.separateSlots)
            }
        }
    }

    private var nightscoutAvailable: Bool {
        let defaults = UserDefaults.standard
        let destination = DirectWatchNightscoutConfiguration.normalizedDestination(
            defaults.nightscoutUrl?.trimmingCharacters(in: .whitespacesAndNewlines), port: defaults.nightscoutPort)
        let apiKey = defaults.nightscoutAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines).toNilIfLength0()
        let token = defaults.nightscoutToken?.trimmingCharacters(in: .whitespacesAndNewlines).toNilIfLength0()
        return cloudUploadEnabled && defaults.dataFlowPolicy.exportsGlucoseToNightscout
            && destination != nil && (apiKey != nil || token != nil)
    }

    private var dexcomShareAvailable: Bool {
        let defaults = UserDefaults.standard
        func hasValue(_ value: String?) -> Bool {
            value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        return cloudUploadEnabled && defaults.uploadReadingstoDexcomShare && defaults.isMaster
            && hasValue(defaults.dexcomShareAccountName)
            && defaults.dexcomSharePassword?.isEmpty == false
            && hasValue(defaults.dexcomShareUploadSerialNumber)
    }

    private func cloudUploadStatusRow(_ title: String, isEnabled: Bool) -> some View {
        let active = isEnabled && !watchPaused && unavailableReason == nil
        let detail = active ? Texts_Common.enabled
            : isEnabled && watchPaused ? TextsDirectWatch.pausedShort : Texts_Common.disabled
        return HStack(spacing: 8) {
            Text(title)
            Spacer()
            SettingsIndicatorView(indicator: SettingsIndicator(
                color: active ? .green : .gray,
                accessibilityLabel: detail))
            Text(detail)
                .foregroundStyle(active ? ConstantsAppColors.rowDetailText : ConstantsAppColors.disabledText)
        }
        .accessibilityElement(children: .combine)
    }
    private func slotSelectionRow(_ slot: Int) -> DirectWatchSlotSelectionRow {
        let title = slotTitle(slot)
        let detail = slotDetail(slot)
        let isAvailable = slotIsAvailable(slot)
        let description = title.appending(", ").appending(detail)
        let selectedLabel = String(format: TextsDirectWatch.selectedFormat, title)
        let accessibilityLabel: String

        if enabled {
            accessibilityLabel = selectedLabel
        } else if selectedSlot == slot && isAvailable {
            accessibilityLabel = String(format: TextsDirectWatch.selectedFormat, description)
        } else {
            accessibilityLabel = description
        }

        return DirectWatchSlotSelectionRow(
            title: title,
            detail: detail,
            isAvailable: isAvailable,
            isSelected: selectedSlot == slot,
            isConfigured: enabled,
            accessibilityLabel: accessibilityLabel,
            selectedAccessibilityLabel: selectedLabel,
            onSelect: { selectedSlot = slot }
        )
    }
    private func slotIsAvailable(_ slot: Int) -> Bool { availableSlots.contains(slot) }
    // The glucose clock controls status, while resume/connection time controls the counter.
    private var statusBanner: DirectWatchStatusBanner {
        let reading = lastCollectedAt.flatMap { date in
            date >= (configuration?.sensorStartDate ?? .distantFuture) ? date : nil
        }
        return DirectWatchStatusBanner(isConfigured: enabled, isSuspended: unavailableReason != nil, isPaused: watchPaused,
                                       latestReadingAt: reading, lastConnectedAt: lastConnectedAt,
                                       resumedAt: DirectWatchSettings.collectionControl?.resumedAt(for: configuration?.connectionIdentity),
                                       pausedAt: watchPaused ? DirectWatchSettings.collectionControl?.changedAt : nil, now: statusNow)
    }

    private func slotTitle(_ slot: Int) -> String {
        switch slot {
        case 1: TextsDirectWatch.slotMedical
        case 2: TextsDirectWatch.slotMobile
        default: context.family == .g7 ? TextsDirectWatch.slotWatch : TextsDirectWatch.slotAnubis
        }
    }

    private func slotDetail(_ slot: Int) -> String {
        if enabled && slot == Int(configuration?.slot ?? 0) { return TextsDirectWatch.usedWatch }
        if slot == Int(context.phoneSlot) { return TextsDirectWatch.usedPhone }
        switch slot {
        case 1: return TextsDirectWatch.slotMedicalDetail
        case 2: return TextsDirectWatch.slotMobileDetail
        default: return context.family == .g7 ? TextsDirectWatch.recommendedWatch : context.isAnubis ? TextsDirectWatch.recommendedTransmitter : TextsDirectWatch.anubisOnly
        }
    }

    private func reload() {
        DirectWatchCompatibility.migrateSettings()
        statusNow = Date()
        lastConnectedAt = UserDefaults.standard.object(forKey: DirectWatchSettings.lastConnectedDateKey) as? Date
        lastCollectedAt = UserDefaults.standard.object(forKey: DirectWatchSettings.lastCollectedDateKey) as? Date
        unavailableReason = UserDefaults.standard.string(forKey: DirectWatchSettings.unavailableReasonKey)
        configuration = DirectWatchSettings.configuration
        cloudUploadEnabled = UserDefaults.standard.bool(forKey: DirectWatchUploadSettings.enabledKey)
        watchPaused = enabled && DirectWatchSettings.watchIsPaused
        if enabled { selectedSlot = Int(configuration?.slot ?? 1) }
    }

    private func enable() {
        guard let start = UserDefaults.standard.activeSensorStartDate, canAdd else { return }
        let configuration = DirectWatchConfiguration(transmitterID: context.transmitterID, slot: UInt8(selectedSlot), isAnubis: context.isAnubis,
                                                sensorStartDate: start, isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
                                                low: UserDefaults.standard.lowMarkValue, high: UserDefaults.standard.highMarkValue,
                                                family: context.family, pairingCode: context.pairingCode,
                                                deviceName: context.deviceName)
        guard configuration.isValid(phoneSlot: context.phoneSlot) else { return }
        DirectWatchSettings.save(configuration)
        showActivationAdvice = true
        reload()
    }
}

private struct DirectWatchSlotSelectionRow: View {
    let title: String
    let detail: String
    let isAvailable: Bool
    let isSelected: Bool
    let isConfigured: Bool
    let accessibilityLabel: String
    let selectedAccessibilityLabel: String
    let onSelect: () -> Void

    @ViewBuilder
    var body: some View {
        if isConfigured {
            row.accessibilityLabel(selectedAccessibilityLabel)
        } else {
            Button(action: onSelect) { row }
                .buttonStyle(.plain)
                .disabled(!isAvailable)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private var row: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(isAvailable ? Color.primary : Color.secondary)
                if !isConfigured {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if isConfigured {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: isAvailable ? (isSelected ? "checkmark.circle.fill" : "circle") : "minus")
                    .foregroundStyle(isAvailable && isSelected ? Color.green : Color.secondary)
            }
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }
}
private struct DirectWatchConnectionToolsView: View {
    let transmitterID: String
    let family: DirectWatchTransmitterFamily
    @State private var watchStatus = TextsDirectWatch.openForStatus
    @State private var watchStatusDate: Date?
    @State private var phonePaused = false
    @State private var readingSyncBlocked = false
    @State private var hasLogs = false
    @State private var lastLogsReceivedAt: Date?
    @State private var waitingForLogs = false
    @State private var logsFailed = false
    @State private var requestThrottled = false
    @State private var highlightedReceipt: Date?
    @ScaledMetric(relativeTo: .body) private var logActionIconSize: CGFloat = 18

    private var watchCollectionIsActive: Bool {
        DirectWatchSettings.watchCollectionIsActive(for: transmitterID, family: family)
    }

    var body: some View {
        Form {
            Section {
                Text(watchStatus)
            } header: {
                Text(TextsDirectWatch.watchStatus)
            } footer: {
                if let watchStatusDate {
                    Text(String(format: TextsDirectWatch.receivedFormat, watchStatusDate.formatted(date: .abbreviated, time: .shortened)))
                }
            }
            Section {
                Toggle(TextsDirectWatch.pausePhone, isOn: Binding(get: { phonePaused }, set: {
                    DirectWatchSettings.pausePhone($0, transmitterID: transmitterID)
                    reload()
                }))
                .disabled(!watchCollectionIsActive)
            } header: {
                Text(TextsDirectWatch.testingDiagnosis)
            } footer: {
                Text(TextsDirectWatch.phoneCollectionAdvice)
            }
            Section {
                Toggle(TextsDirectWatch.blockPhoneSync, isOn: Binding(get: { readingSyncBlocked }, set: {
                    DirectWatchSettings.blockReadingImport($0)
                    reload()
                }))
                .disabled(!watchCollectionIsActive)
            } footer: {
                Text(TextsDirectWatch.blockPhoneSyncAdvice)
            }
            Section(TextsDirectWatch.logs) {
                Button {
                    requestThrottled = true
                    waitingForLogs = true
                    logsFailed = false
                    NotificationCenter.default.post(name: DirectWatchSettings.requestLogs, object: nil)
                } label: {
                    logActionLabel(TextsDirectWatch.getLogs,
                        symbol: logsFailed ? "exclamationmark.circle" : "arrow.down.circle",
                        iconColor: logsFailed ? .red : ConstantsAppColors.navigationTint)
                }
                .disabled(requestThrottled)
                .accessibilityHint(Text(logsFailed ? TextsDirectWatch.logsFailed : ""))
                HStack {
                    Text(TextsDirectWatch.lastLogsReceived)
                        .foregroundStyle(ConstantsAppColors.rowTitleText)
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        if waitingForLogs { ProgressView().controlSize(.small) }
                        Text(lastLogsReceivedAt?.toStringInUserLocale(timeStyle: .short, dateStyle: .short) ?? "-")
                            .foregroundStyle(highlightedReceipt != nil ? Color.green : ConstantsAppColors.rowDetailText)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if hasLogs {
                    ShareLink(item: DirectWatchSettings.receivedLogURL) {
                        logActionLabel(TextsDirectWatch.shareLogs, symbol: "square.and.arrow.up")
                    }
                }
            }
            .tint(ConstantsAppColors.navigationTint)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .colorScheme(.dark)
        .navigationTitle(TextsDirectWatch.testingLogs)
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: DirectWatchSettings.changed)) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: DirectWatchSettings.statusChanged)) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: DirectWatchSettings.logsChanged)) { _ in
            let previous = lastLogsReceivedAt
            reload()
            if let receivedAt = lastLogsReceivedAt, receivedAt != previous {
                highlightedReceipt = receivedAt
            }
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in reload() }
        .task(id: requestThrottled) {
            guard requestThrottled else { return }
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                requestThrottled = false
            } catch { }
        }
        .task(id: highlightedReceipt) {
            guard highlightedReceipt != nil else { return }
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                highlightedReceipt = nil
            } catch { }
        }
    }

    // ShareLink's automatic Label style gives its symbol a different size and text inset.
    // Both actions use one scalable icon box and spacing.
    private func logActionLabel(_ title: String, symbol: String, iconColor: Color = ConstantsAppColors.navigationTint) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: logActionIconSize, height: logActionIconSize)
                .foregroundStyle(iconColor)
            Text(title)
        }
        .font(.body)
    }

    private func reload() {
        readingSyncBlocked = DirectWatchSettings.readingImportBlocked
        phonePaused = DirectWatchSettings.phoneIsPaused(transmitterID)
        hasLogs = FileManager.default.fileExists(atPath: DirectWatchSettings.receivedLogURL.path)
        // Existing exports predate receipt tracking. Their file date provides a useful
        // initial value, while every new receipt gets an explicit persisted timestamp.
        lastLogsReceivedAt = UserDefaults.standard.object(forKey: DirectWatchSettings.logsReceivedDateKey) as? Date
            ?? (try? FileManager.default.attributesOfItem(atPath: DirectWatchSettings.receivedLogURL.path)[.modificationDate] as? Date)
        waitingForLogs = UserDefaults.standard.object(forKey: DirectWatchSettings.logsRequestedDateKey) is Date
        logsFailed = UserDefaults.standard.bool(forKey: DirectWatchSettings.logsFailedKey)
        if let status = UserDefaults.standard.string(forKey: DirectWatchSettings.lastStatusKey),
           let date = UserDefaults.standard.object(forKey: DirectWatchSettings.lastStatusDateKey) as? Date {
            // The pending delimiter is a wire-format field. Only its visible heading is localized.
            watchStatus = status
                .replacingOccurrences(of: " (up to 5 minutes)", with: "")
                .replacingOccurrences(of: "; pending=", with: "\n\(TextsDirectWatch.pending): ")
            watchStatusDate = date
        }
    }
}
