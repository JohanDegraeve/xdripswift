//
//  NightscoutImportView.swift
//  xdrip
//
//  Created by Paul Plant on 14/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import os
import SwiftUI

// MARK: - Historical Nightscout Import View

/// Presents the same review, progress and summary rhythm used by the other Data Management tools.
struct NightscoutImportView: View {
    private static let actionColor = Color(.systemBlue)
    private static let successColor = Color.green

    @StateObject private var viewModel: NightscoutImportViewModel
    @State private var showsStartConfirmation = false
    @State private var showsDiscardConfirmation = false

    init(coreDataManager: CoreDataManager) {
        _viewModel = StateObject(wrappedValue: NightscoutImportViewModel(coreDataManager: coreDataManager))
    }

    var body: some View {
        Form {
            if viewModel.importResult == nil {
                sourceBanner
            }

            if viewModel.hasConfiguredSite {
                if let result = viewModel.importResult {
                    successSection
                    resultSummarySection(result)
                    if viewModel.includesBgReadings {
                        bgResultSection(result)
                    }
                    if viewModel.includesTreatments {
                        treatmentResultSection(result)
                    }
                } else if let checkpoint = viewModel.savedCheckpoint {
                    // A saved import is an exclusive workflow state: the user should either resume it
                    // or discard it before configuring a separate historical import.
                    resumeSection(checkpoint)
                } else {
                    selectionSection
                    periodSection
                    startSection
                }
            }
        }
        .disabled(viewModel.isWorking)
        .overlay {
            if viewModel.isWorking {
                progressOverlay
            }
        }
        .alert(Texts_SettingsView.nightscoutImportQuestion, isPresented: $showsStartConfirmation) {
            Button(Texts_SettingsView.dataManagementImportData) { viewModel.startImport() }
            Button(Texts_Common.Cancel, role: .cancel) {}
        } message: {
            Text(viewModel.startConfirmationMessage)
        }
        .alert(Texts_SettingsView.nightscoutImportDiscardQuestion, isPresented: $showsDiscardConfirmation) {
            Button(Texts_SettingsView.nightscoutImportDiscard) { viewModel.discardSavedImport() }
            Button(Texts_Common.Cancel, role: .cancel) {}
        } message: {
            Text(Texts_SettingsView.nightscoutImportDiscardMessage)
        }
        .alert(Texts_SettingsView.nightscoutImportAction, isPresented: errorIsPresented) {
            Button(Texts_Common.Ok) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // Apply the destination tint outside the alert presenters. Otherwise the alerts inherit
        // the Settings navigation stack's yellow tint even though the form itself is system blue.
        .tint(Color(.systemBlue))
        .onAppear {
            viewModel.refreshConfigurationAndCheckpoint()
        }
    }

    // MARK: Source and Options

    private var sourceBanner: some View {
        Section {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.title2)
                    .foregroundStyle(viewModel.hasConfiguredSite ? Self.successColor : Color(.systemRed))
                    .frame(width: 30)

                if let configuredSiteURL = viewModel.configuredSiteURL {
                    Text(configuredSiteURL)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .allowsTightening(true)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .textSelection(.enabled)
                } else {
                    VStack(alignment: .center, spacing: 4) {
                        Text(Texts_SettingsView.nightscoutImportURLMissing)
                            .font(.headline)
                            .foregroundStyle(Color(.systemRed))
                        Text(Texts_SettingsView.nightscoutImportConfigureURL)
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                Color.clear
                    .frame(width: 30, height: 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private var selectionSection: some View {
        Section(Texts_SettingsView.nightscoutImportDataToImport) {
            Toggle(Texts_SettingsView.cleanDataBgReadings, isOn: $viewModel.includesBgReadings)
                .tint(.green)
            Toggle(Texts_SettingsView.cleanDataTreatments, isOn: $viewModel.includesTreatments)
                .tint(.green)
        }
    }

    private var periodSection: some View {
        Section {
            Picker(Texts_SettingsView.nightscoutImportPeriod, selection: $viewModel.period) {
                ForEach(viewModel.availablePeriods) { period in
                    Text(period.title).tag(period)
                }
            }
            LabeledContent(Texts_SettingsView.cleanDataFrom, value: viewModel.proposedFromDate.formatted(date: .abbreviated, time: .shortened))
            LabeledContent(Texts_SettingsView.cleanDataUntil, value: Date().formatted(date: .abbreviated, time: .shortened))
        } header: {
            Text(Texts_SettingsView.cleanDataDateRange)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(Texts_SettingsView.nightscoutImportExistingDataFooter)
                Text(Texts_SettingsView.nightscoutImportRetentionFooter(viewModel.retentionDays))
            }
        }
    }

    private var startSection: some View {
        Section {
            Button {
                showsStartConfirmation = true
            } label: {
                Text(Texts_SettingsView.nightscoutImportAction)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Self.actionColor)
            .disabled(!viewModel.canStartImport)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } footer: {
            Text(Texts_SettingsView.nightscoutImportKeepOpenFooter)
        }
    }

    // MARK: Resume

    private func resumeSection(_ checkpoint: NightscoutImportCheckpoint) -> some View {
        Section {
            LabeledContent(Texts_SettingsView.nightscoutImportPeriodLabel, value: checkpoint.options.period.title)
            LabeledContent(Texts_SettingsView.nightscoutImportCompletedBatches, value: Texts_SettingsView.nightscoutImportBatchCount(checkpoint.completedChunks, checkpoint.totalChunks))
            LabeledContent(Texts_SettingsView.backupBgReadingsAdded, value: checkpoint.counts.bgReadingsAdded.formatted())
            LabeledContent(Texts_SettingsView.backupTreatmentsAdded, value: checkpoint.counts.treatmentsAdded.formatted())

            Button {
                viewModel.resumeImport()
            } label: {
                Text(Texts_SettingsView.nightscoutImportResume)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Self.actionColor)
            .disabled(!viewModel.canResumeImport)

            Button(Texts_SettingsView.nightscoutImportDiscardSaved) {
                showsDiscardConfirmation = true
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text(Texts_SettingsView.nightscoutImportSaved)
        } footer: {
            if !checkpoint.options.period.isSupported {
                Text(Texts_SettingsView.nightscoutImportUnsupportedFooter)
            } else if checkpoint.options.period.rawValue > viewModel.retentionDays {
                Text(Texts_SettingsView.nightscoutImportExceedsRetentionFooter)
            } else {
                Text(Texts_SettingsView.nightscoutImportResumeFooter)
            }
        }
    }

    // MARK: Progress

    private var progressOverlay: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: viewModel.progressFraction)
                    .progressViewStyle(.linear)
                    .tint(.green)
                    .frame(maxWidth: 280)

                Text(viewModel.progressTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(viewModel.progressDetail)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                if viewModel.progressCounts.bgReadingsAdded + viewModel.progressCounts.treatmentsAdded > 0 {
                    VStack(spacing: 4) {
                        Text(Texts_SettingsView.nightscoutImportBgAddedProgress(viewModel.progressCounts.bgReadingsAdded))
                        Text(Texts_SettingsView.nightscoutImportTreatmentsAddedProgress(viewModel.progressCounts.treatmentsAdded))
                    }
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.8))
                }

                Button(Texts_SettingsView.nightscoutImportPause) {
                    viewModel.pauseImport()
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.top, 4)
            }
            .padding(28)
        }
    }

    // MARK: Completion

    private var successSection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Self.successColor)
                Text(Texts_SettingsView.nightscoutImportCompleted)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(ConstantsUI.activeRowBackgroundColor)
        }
    }

    private func resultSummarySection(_ result: NightscoutImportResult) -> some View {
        Section {
            LabeledContent(Texts_SettingsView.cleanDataFrom, value: result.requestedFrom.formatted(date: .abbreviated, time: .shortened))
            LabeledContent(Texts_SettingsView.cleanDataUntil, value: result.requestedTo.formatted(date: .abbreviated, time: .shortened))
        } header: {
            Text(Texts_SettingsView.nightscoutImportSummary)
        } footer: {
            Text(Texts_SettingsView.nightscoutImportSummaryFooter)
        }
    }

    /// Uses the same localized row labels as treatments so the two result sections scan identically.
    private func bgResultSection(_ result: NightscoutImportResult) -> some View {
        Section(Texts_SettingsView.cleanDataBgReadings) {
            LabeledContent(Texts_SettingsView.nightscoutImportDownloaded, value: result.counts.bgDocumentsDownloaded.formatted())
            LabeledContent(Texts_SettingsView.nightscoutImportAdded, value: result.counts.bgReadingsAdded.formatted())
            LabeledContent(Texts_SettingsView.nightscoutImportSkipped, value: result.counts.bgReadingsSkipped.formatted())
            LabeledContent(Texts_SettingsView.nightscoutImportInvalid, value: result.counts.bgDocumentsInvalid.formatted())
        }
    }

    /// Unsupported treatment documents are intentionally folded into Invalid for a concise summary.
    private func treatmentResultSection(_ result: NightscoutImportResult) -> some View {
        Section {
            LabeledContent(Texts_SettingsView.nightscoutImportDownloaded, value: result.counts.treatmentDocumentsDownloaded.formatted())
            LabeledContent(Texts_SettingsView.nightscoutImportAdded, value: result.counts.treatmentsAdded.formatted())
            LabeledContent(Texts_SettingsView.nightscoutImportSkipped, value: result.counts.treatmentsSkipped.formatted())
            LabeledContent(Texts_SettingsView.nightscoutImportInvalid, value: result.counts.treatmentDocumentsUnsupported.formatted())
        } header: {
            Text(Texts_SettingsView.cleanDataTreatments)
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented { viewModel.errorMessage = nil }
        }
    }
}

// MARK: - View Model

/// Keeps UI state on the main actor while the service owns network and Core Data queue confinement.
@MainActor
final class NightscoutImportViewModel: ObservableObject {
    @Published var period: NightscoutImportPeriod = .sevenDays
    @Published var includesBgReadings = true
    @Published var includesTreatments = true
    @Published private(set) var retentionDays = UserDefaults.standard.retentionPeriodInDays
    @Published private(set) var configuredSiteURL: String?
    @Published private(set) var savedCheckpoint: NightscoutImportCheckpoint?
    @Published private(set) var importResult: NightscoutImportResult?
    @Published private(set) var isWorking = false
    @Published private(set) var progressFraction = 0.0
    @Published private(set) var progressTitle = Texts_SettingsView.nightscoutImportingData
    @Published private(set) var progressDetail = ""
    @Published private(set) var progressCounts = NightscoutImportCounts()
    @Published var errorMessage: String?

    private let service: NightscoutImportService
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDataManagement)
    private var importTask: Task<Void, Never>?

    init(coreDataManager: CoreDataManager) {
        service = NightscoutImportService(coreDataManager: coreDataManager)
        refreshConfigurationAndCheckpoint()
    }

    deinit {
        importTask?.cancel()
    }

    var proposedFromDate: Date {
        Date().addingTimeInterval(-TimeInterval(period.rawValue) * 24 * 60 * 60)
    }

    var availablePeriods: [NightscoutImportPeriod] {
        NightscoutImportPeriod.available(retentionDays: retentionDays)
    }

    var canStartImport: Bool {
        hasConfiguredSite
            && savedCheckpoint == nil
            && (includesBgReadings || includesTreatments)
            && !isWorking
    }

    var hasConfiguredSite: Bool {
        configuredSiteURL != nil
    }

    var canResumeImport: Bool {
        guard let savedCheckpoint, hasConfiguredSite else { return false }
        let currentURL = normalizedConfiguredURL
        return currentURL == savedCheckpoint.siteURL
            && savedCheckpoint.options.period.isSupported
            && savedCheckpoint.options.period.rawValue <= retentionDays
            && !isWorking
    }

    var startConfirmationMessage: String {
        let selectedData: String
        if includesBgReadings && includesTreatments {
            selectedData = Texts_SettingsView.nightscoutImportBgAndTreatments
        } else if includesBgReadings {
            selectedData = Texts_SettingsView.nightscoutImportBgOnly
        } else {
            selectedData = Texts_SettingsView.nightscoutImportTreatmentsOnly
        }
        return Texts_SettingsView.nightscoutImportConfirmation(period.rawValue, selectedData)
    }

    func refreshConfigurationAndCheckpoint() {
        retentionDays = UserDefaults.standard.retentionPeriodInDays
        if period.rawValue > retentionDays, let maximumAvailablePeriod = availablePeriods.last {
            period = maximumAvailablePeriod
        }
        savedCheckpoint = service.savedCheckpoint
        guard let urlText = UserDefaults.standard.nightscoutUrl,
              var components = URLComponents(string: urlText)
        else {
            configuredSiteURL = nil
            return
        }
        let port = UserDefaults.standard.nightscoutPort
        if port != 0 {
            guard (1...65_535).contains(port) else {
                configuredSiteURL = nil
                return
            }
            components.port = port
        }
        guard let normalizedSiteURL = NightscoutImportService.normalizedSiteIdentity(from: components) else {
            configuredSiteURL = nil
            return
        }
        configuredSiteURL = normalizedSiteURL
    }

    func startImport() {
        let options = NightscoutImportOptions(
            period: period,
            includesBgReadings: includesBgReadings,
            includesTreatments: includesTreatments
        )
        runImport { [service] progress in
            try await service.start(options: options, progress: progress)
        }
    }

    func resumeImport() {
        if let checkpoint = savedCheckpoint {
            period = checkpoint.options.period
            includesBgReadings = checkpoint.options.includesBgReadings
            includesTreatments = checkpoint.options.includesTreatments
            progressCounts = checkpoint.counts
        }
        runImport { [service] progress in
            try await service.resume(progress: progress)
        }
    }

    func pauseImport() {
        trace(
            "in Nightscout historical import, user requested that the active import be paused",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info
        )
        importTask?.cancel()
    }

    func discardSavedImport() {
        service.discardCheckpoint()
        savedCheckpoint = nil
        progressCounts = NightscoutImportCounts()
    }

    private func runImport(
        operation: @escaping (@escaping @Sendable (NightscoutImportProgress) -> Void) async throws -> NightscoutImportResult
    ) {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        progressFraction = 0
        progressTitle = Texts_SettingsView.nightscoutImportingData
        progressDetail = Texts_SettingsView.nightscoutImportKeepAppOpen

        importTask = Task {
            do {
                let result = try await operation { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.apply(progress)
                    }
                }
                importResult = result
                savedCheckpoint = nil
                progressFraction = 1
                isWorking = false
            } catch is CancellationError {
                isWorking = false
                progressTitle = Texts_SettingsView.nightscoutImportPaused
                refreshConfigurationAndCheckpoint()
                trace(
                    "in Nightscout historical import, active work stopped after the pause request. checkpoint remains available",
                    log: log,
                    category: ConstantsLog.categoryDataManagement,
                    type: .info
                )
            } catch {
                isWorking = false
                refreshConfigurationAndCheckpoint()
                errorMessage = error.localizedDescription
            }
            importTask = nil
        }
    }

    private func apply(_ progress: NightscoutImportProgress) {
        progressFraction = progress.fractionCompleted
        progressCounts = progress.counts
        progressDetail = Texts_SettingsView.nightscoutImportBatchProgress(progress.chunkNumber, progress.totalChunks)
    }

    private var normalizedConfiguredURL: String? {
        guard var components = URLComponents(string: UserDefaults.standard.nightscoutUrl ?? "") else { return nil }
        let port = UserDefaults.standard.nightscoutPort
        if port != 0 {
            guard (1...65_535).contains(port) else { return nil }
            components.port = port
        }
        return NightscoutImportService.normalizedSiteIdentity(from: components)
    }
}
