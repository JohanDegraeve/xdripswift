//
//  DataDeletionView.swift
//  xdrip
//
//  Created by Paul Plant on 13/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import os
import SwiftUI

// MARK: - Data Deletion View

struct DataDeletionView: View {
    private static let successColor = Color.green

    @StateObject private var viewModel: DataDeletionViewModel
    @FocusState private var confirmationCodeFieldIsFocused: Bool

    init(coreDataManager: CoreDataManager) {
        _viewModel = StateObject(wrappedValue: DataDeletionViewModel(coreDataManager: coreDataManager))
    }

    var body: some View {
        Form {
            if let result = viewModel.deletionResult {
                successSection
                deletionResultSection(result)
            } else if let deletionPlan = viewModel.deletionPlan {
                warningSection
                if viewModel.showsCaptchaConfirmation {
                    confirmationSection
                } else {
                    deletionPlanSection(deletionPlan)
                    deletionSummaryConfirmationSection
                }
            } else if let inventory = viewModel.inventory {
                dateRangeSection
                selectionSection(inventory)
                reviewSection
            }
        }
        .padding(.top, viewModel.deletionPlan != nil && viewModel.deletionResult == nil ? 4 : 0)
        .tint(Color(.systemBlue))
        .disabled(viewModel.isWorking)
        .overlay {
            if viewModel.isWorking {
                ZStack {
                    Color.black.opacity(0.75).ignoresSafeArea()
                    VStack(spacing: 18) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                        Text(viewModel.status)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .frame(maxWidth: 300)
                    }
                    .padding(28)
                }
            }
        }
        .alert(Texts_SettingsView.dataManagementDataDeletion, isPresented: errorIsPresented) {
            Button(Texts_Common.Ok) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.loadInventoryIfNeeded()
        }
    }

    // MARK: - Range and Selection

    private func selectionSection(_ inventory: CleanDataInventory) -> some View {
        Section {
            Toggle(isOn: $viewModel.includesBgReadings) {
                selectionLabel(title: Texts_SettingsView.cleanDataBgReadings, count: inventory.bgReadings.count)
            }
            .tint(.green)
            .disabled(inventory.bgReadings.count == 0)
            .onChange(of: viewModel.includesBgReadings) { _ in viewModel.selectionChanged() }

            Toggle(isOn: $viewModel.includesTreatments) {
                selectionLabel(title: Texts_SettingsView.cleanDataTreatments, count: inventory.treatments.count)
            }
            .tint(.green)
            .disabled(inventory.treatments.count == 0)
            .onChange(of: viewModel.includesTreatments) { _ in viewModel.selectionChanged() }
        } header: {
            Text(Texts_SettingsView.cleanDataSelectData)
        }
    }

    private var dateRangeSection: some View {
        Section {
            Picker(Texts_SettingsView.cleanDataCleanupMethod, selection: $viewModel.rangeMode) {
                ForEach(CleanDataRangeMode.allCases) { rangeMode in
                    Text(rangeMode.title).tag(rangeMode)
                }
            }
            .onChange(of: viewModel.rangeMode) { _ in viewModel.rangeModeChanged() }

            switch viewModel.rangeMode {
            case .keepRecent:
                Picker(Texts_SettingsView.cleanDataKeep, selection: $viewModel.recentDataDays) {
                    ForEach(DataDeletionViewModel.availableRecentDataDays, id: \.self) { days in
                        Text(Texts_SettingsView.cleanDataDays(days)).tag(days)
                    }
                }
            case .custom:
                DatePicker(
                    Texts_SettingsView.cleanDataFrom,
                    selection: $viewModel.customFromDate,
                    in: viewModel.availableDateRange,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DatePicker(
                    Texts_SettingsView.cleanDataUntil,
                    selection: $viewModel.customThroughDate,
                    in: viewModel.availableDateRange,
                    displayedComponents: [.date, .hourAndMinute]
                )
            case .all:
                EmptyView()
            }
        } header: {
            Text(Texts_SettingsView.cleanDataDateRange)
        } footer: {
            switch viewModel.rangeMode {
            case .keepRecent:
                Text(Texts_SettingsView.cleanDataOlderDataFooter)
            case .custom:
                Text(Texts_SettingsView.cleanDataInclusiveDatesFooter)
            case .all:
                Text(Texts_SettingsView.cleanDataDeleteAllFooter)
            }
        }
    }

    private var reviewSection: some View {
        Section {
            Button {
                viewModel.prepareDeletionPlan()
            } label: {
                Text(Texts_SettingsView.cleanDataContinue)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!viewModel.canPrepareDeletionPlan)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } footer: {
            Text(Texts_SettingsView.cleanDataReviewFooter)
        }
    }

    // MARK: - Confirmation

    private var warningSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Texts_SettingsView.cleanDataPermanentDeletion)
                        .font(.headline)
                    Text(Texts_SettingsView.cleanDataCannotUndo)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(ConstantsUI.warningSectionBackgroundColor)
        }
    }

    private func deletionPlanSection(_ deletionPlan: CleanDataDeletionPlan) -> some View {
        Section {
            if deletionPlan.selection.includesBgReadings {
                LabeledContent(Texts_SettingsView.cleanDataBgReadings, value: deletionPlan.bgReadingCount.formatted())
            }
            if deletionPlan.selection.includesTreatments {
                LabeledContent(Texts_SettingsView.cleanDataTreatments, value: deletionPlan.treatmentCount.formatted())
            }
            if deletionPlan.calibrationCount > 0 {
                LabeledContent(Texts_SettingsView.cleanDataUnusedCalibrations, value: deletionPlan.calibrationCount.formatted())
            }
            if let fromDate = deletionPlan.fromDate {
                LabeledContent(Texts_SettingsView.cleanDataFrom, value: formattedDate(fromDate))
            } else {
                LabeledContent(Texts_SettingsView.cleanDataFrom, value: Texts_SettingsView.cleanDataEarliestStoredData)
            }
            LabeledContent(Texts_SettingsView.cleanDataUntil, value: formattedDate(deletionPlan.throughDate))
        } header: {
            Text(Texts_SettingsView.cleanDataDataToDelete)
        }
    }

    private var deletionSummaryConfirmationSection: some View {
        Section {
            Button {
                viewModel.confirmDeletionSummary()
            } label: {
                Text(Texts_SettingsView.cleanDataContinue)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var confirmationSection: some View {
        Section {
            VStack(spacing: 12) {
                Text(Texts_SettingsView.cleanDataEnterCode)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                Text(viewModel.confirmationCode)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(.yellow)
                    .tracking(8)
                    .padding(.leading, 8)
                    .accessibilityLabel(Texts_SettingsView.cleanDataConfirmationCode(viewModel.confirmationCode))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            TextField(
                Texts_SettingsView.cleanDataSixDigitCode,
                text: $viewModel.enteredConfirmationCode,
                prompt: Text("123456")
                    .foregroundColor(Color(.secondaryLabel))
            )
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(.title, design: .monospaced, weight: .bold))
            .tracking(8)
            .padding(.leading, 8)
            .padding(.vertical, 8)
            .focused($confirmationCodeFieldIsFocused)
            .onChange(of: viewModel.enteredConfirmationCode) { enteredCode in
                viewModel.confirmationCodeChanged(enteredCode)
            }

            Button {
                viewModel.confirmAndDelete()
            } label: {
                Text(Texts_SettingsView.cleanDataConfirmDelete)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!viewModel.confirmationCodeMatches)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .onAppear {
            confirmationCodeFieldIsFocused = true
        }
    }

    // MARK: - Result

    private var successSection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Self.successColor)
                Text(Texts_SettingsView.cleanDataSuccessfullyDeleted)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(ConstantsUI.activeRowBackgroundColor)
        }
    }

    private func deletionResultSection(_ result: CleanDataDeletionResult) -> some View {
        Section {
            LabeledContent(Texts_SettingsView.cleanDataCompleted, value: formattedDate(result.completedAt))
            LabeledContent(Texts_SettingsView.cleanDataBgReadingsDeleted, value: result.bgReadingCount.formatted())
            LabeledContent(Texts_SettingsView.cleanDataTreatmentsDeleted, value: result.treatmentCount.formatted())
            LabeledContent(Texts_SettingsView.cleanDataStorageBefore, value: formattedByteCount(result.storeSizeBeforeInBytes))
            LabeledContent(Texts_SettingsView.cleanDataStorageAfter, value: formattedByteCount(result.storeSizeAfterInBytes))
        } header: {
            Text(Texts_SettingsView.cleanDataCleanupSummary)
        } footer: {
            Text(Texts_SettingsView.cleanDataDatabaseReuseFooter)
        }
    }

    // MARK: - View Helpers

    private func selectionLabel(title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(count.formatted())
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func formattedByteCount(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    private var errorIsPresented: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented { viewModel.errorMessage = nil }
        }
    }
}

// MARK: - Data Deletion View Model

@MainActor
final class DataDeletionViewModel: ObservableObject {
    static let availableRecentDataDays = [30, 60, 90, 180, 365]

    @Published var inventory: CleanDataInventory?
    @Published var includesBgReadings = false
    @Published var includesTreatments = false
    @Published var rangeMode = CleanDataRangeMode.keepRecent
    @Published var recentDataDays = 90
    @Published var customFromDate = Date()
    @Published var customThroughDate = Date()
    @Published var deletionPlan: CleanDataDeletionPlan?
    @Published var deletionResult: CleanDataDeletionResult?
    @Published var showsCaptchaConfirmation = false
    @Published var confirmationCode = ""
    @Published var enteredConfirmationCode = ""
    @Published var confirmationCodeMatches = false
    @Published var isWorking = false
    @Published var status = ""
    @Published var errorMessage: String?

    private let service: DataManagementService
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDataManagement)

    init(coreDataManager: CoreDataManager) {
        service = DataManagementService(coreDataManager: coreDataManager)
    }

    var canPrepareDeletionPlan: Bool {
        let hasSelection = includesBgReadings || includesTreatments
        return hasSelection && (rangeMode != .custom || customFromDate <= customThroughDate)
    }

    var availableDateRange: ClosedRange<Date> {
        let firstDate = firstStoredDate ?? Date()
        let lastDate = max(lastStoredDate ?? firstDate, firstDate)
        return firstDate ... lastDate
    }

    func loadInventoryIfNeeded() async {
        guard inventory == nil, !isWorking else { return }
        start(status: Texts_SettingsView.cleanDataCheckingStatus)
        do {
            inventory = try await service.inventory()
            resetCustomDateRange()
            finish()
        } catch {
            fail(error, operation: "cleanDataInventory")
        }
    }

    func selectionChanged() {
        trace(
            "in cleanDataSelectionChanged, BG readings selected = %{public}@, treatments selected = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            includesBgReadings.description,
            includesTreatments.description
        )
    }

    func rangeModeChanged() {
        if rangeMode == .custom { resetCustomDateRange() }
        trace(
            "in cleanDataRangeModeChanged, mode = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            rangeMode.rawValue
        )
    }

    func prepareDeletionPlan() {
        guard canPrepareDeletionPlan else { return }
        let dates = deletionDates()
        let selection = CleanDataSelection(
            includesBgReadings: includesBgReadings,
            includesTreatments: includesTreatments
        )
        start(status: Texts_SettingsView.cleanDataCountingStatus)
        Task {
            do {
                deletionPlan = try await service.deletionPlan(
                    selection: selection,
                    rangeMode: rangeMode,
                    fromDate: dates.fromDate,
                    throughDate: dates.throughDate
                )
                showsCaptchaConfirmation = false
                finish()
            } catch {
                fail(error, operation: "cleanDataDeletionPlan")
            }
        }
    }

    func confirmationCodeChanged(_ enteredCode: String) {
        let digitsOnly = String(enteredCode.filter(\.isNumber).prefix(6))
        if enteredConfirmationCode != digitsOnly {
            enteredConfirmationCode = digitsOnly
            return
        }
        let matches = digitsOnly.count == 6 && digitsOnly == confirmationCode
        trace(
            "in cleanDataCaptchaCheck, captcha comparison completed. displayed code = %{public}@, entered attempt = %{public}@, matched = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            confirmationCode,
            digitsOnly,
            matches.description
        )
        confirmationCodeMatches = matches
    }

    func confirmDeletionSummary() {
        guard let deletionPlan else { return }
        let confirmationDate = Date()
        trace(
            "in cleanDataUserConfirmedSummary, direct user confirmation of deletion summary received. confirmation timestamp = %{public}@, BG readings = %{public}@, treatments = %{public}@, unused calibrations = %{public}@, from = %{public}@, through = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            confirmationDate.description(with: .current),
            deletionPlan.bgReadingCount.description,
            deletionPlan.treatmentCount.description,
            deletionPlan.calibrationCount.description,
            deletionPlan.fromDate?.description(with: .current) ?? "earliest stored data",
            deletionPlan.throughDate.description(with: .current)
        )
        createConfirmationCode()
        showsCaptchaConfirmation = true
    }

    func confirmAndDelete() {
        guard confirmationCodeMatches, let deletionPlan else { return }
        let confirmationDate = Date()
        trace(
            "in cleanDataUserConfirmedDeletion, final DELETE confirmation received. confirmation timestamp = %{public}@, displayed code = %{public}@, entered attempt = %{public}@, captcha matched = true, BG readings = %{public}@, treatments = %{public}@, unused calibrations = %{public}@, from = %{public}@, through = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            confirmationDate.description(with: .current),
            confirmationCode,
            enteredConfirmationCode,
            deletionPlan.bgReadingCount.description,
            deletionPlan.treatmentCount.description,
            deletionPlan.calibrationCount.description,
            deletionPlan.fromDate?.description(with: .current) ?? "earliest stored data",
            deletionPlan.throughDate.description(with: .current)
        )
        start(status: Texts_SettingsView.cleanDataDeletingStatus)
        Task {
            do {
                deletionResult = try await service.delete(plan: deletionPlan)
                confirmationCode = ""
                enteredConfirmationCode = ""
                confirmationCodeMatches = false
                finish()
            } catch {
                fail(error, operation: "cleanDataDelete")
            }
        }
    }

    private var selectedFirstDate: Date? {
        guard let inventory else { return nil }
        var dates = [Date]()
        if includesBgReadings, let date = inventory.bgReadings.firstDate { dates.append(date) }
        if includesTreatments, let date = inventory.treatments.firstDate { dates.append(date) }
        return dates.min()
    }

    private var firstStoredDate: Date? {
        guard let inventory else { return nil }
        return [inventory.bgReadings.firstDate, inventory.treatments.firstDate]
            .compactMap { $0 }
            .min()
    }

    private var lastStoredDate: Date? {
        guard let inventory else { return nil }
        return [inventory.bgReadings.lastDate, inventory.treatments.lastDate]
            .compactMap { $0 }
            .max()
    }

    private var selectedLastDate: Date? {
        guard let inventory else { return nil }
        var dates = [Date]()
        if includesBgReadings, let date = inventory.bgReadings.lastDate { dates.append(date) }
        if includesTreatments, let date = inventory.treatments.lastDate { dates.append(date) }
        return dates.max()
    }

    private func resetCustomDateRange() {
        guard let firstDate = firstStoredDate, let lastDate = lastStoredDate else { return }
        customFromDate = firstDate
        customThroughDate = max(lastDate, firstDate)
    }

    private func deletionDates() -> (fromDate: Date?, throughDate: Date) {
        switch rangeMode {
        case .keepRecent:
            let throughDate = Calendar.current.date(byAdding: .day, value: -recentDataDays, to: Date()) ?? Date()
            return (selectedFirstDate, throughDate)
        case .custom:
            return (customFromDate, customThroughDate)
        case .all:
            return (nil, selectedLastDate ?? Date())
        }
    }

    private func createConfirmationCode() {
        confirmationCode = String(Int.random(in: 100_000 ... 999_999))
        enteredConfirmationCode = ""
        confirmationCodeMatches = false
        trace(
            "in cleanDataCreateCaptcha, new six-digit confirmation challenge created",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info
        )
    }

    private func start(status: String) {
        isWorking = true
        self.status = status
        errorMessage = nil
    }

    private func finish() {
        isWorking = false
        status = ""
    }

    private func fail(_ error: Error, operation: String) {
        trace(
            "in %{public}@, failed. error = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .error,
            operation,
            error.localizedDescription
        )
        isWorking = false
        status = ""
        errorMessage = error.localizedDescription
    }
}
