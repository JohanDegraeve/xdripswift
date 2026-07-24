//
//  ManageDataView.swift
//  xdrip
//
//  Created by Paul Plant on 14/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import os
import SwiftUI

// MARK: - Manage Data View

/// Keeps retention policy and permanent deletion discoverable without combining their workflows.
struct ManageDataView: View {
    private let coreDataManager: CoreDataManager

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    DataRetentionView()
                        .navigationTitle(Texts_SettingsView.dataManagementDataRetention)
                        .navigationBarTitleDisplayMode(.large)
                } label: {
                    Text(Texts_SettingsView.dataManagementDataRetention)
                }

                NavigationLink {
                    DataDeletionView(coreDataManager: coreDataManager)
                        .navigationTitle(Texts_SettingsView.dataManagementDataDeletion)
                        .navigationBarTitleDisplayMode(.large)
                } label: {
                    Text(Texts_SettingsView.dataManagementDataDeletion)
                }
            }
        }
        .tint(Color(.systemBlue))
    }
}

// MARK: - Storage Info View

struct StorageInfoView: View {
    @StateObject private var viewModel: StorageInfoViewModel

    init(coreDataManager: CoreDataManager) {
        _viewModel = StateObject(wrappedValue: StorageInfoViewModel(coreDataManager: coreDataManager))
    }

    var body: some View {
        Form {
            if let inventory = viewModel.inventory {
                databaseSection(inventory)
                storedRecordsSection(inventory)
                if let firstDate = viewModel.firstStoredDate,
                   let lastDate = viewModel.lastStoredDate
                {
                    historySection(firstDate: firstDate, lastDate: lastDate)
                }
            }
        }
        .disabled(viewModel.isWorking)
        .overlay {
            if viewModel.isWorking {
                ProgressView(Texts_SettingsView.storageInfoCheckingStatus)
            }
        }
        .alert(Texts_SettingsView.dataManagementStorageInfo, isPresented: errorIsPresented) {
            Button(Texts_Common.Ok) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .tint(Color(.systemBlue))
        .task {
            await viewModel.loadInventoryIfNeeded()
        }
        .refreshable {
            await viewModel.refreshInventory()
        }
    }

    private func databaseSection(_ inventory: CleanDataInventory) -> some View {
        Section {
            LabeledContent(
                Texts_SettingsView.storageInfoDatabaseSize,
                value: ByteCountFormatter.string(fromByteCount: inventory.storeSizeInBytes, countStyle: .file)
            )
            LabeledContent(Texts_SettingsView.storageInfoTrackedRecords, value: viewModel.totalRecordCount.formatted())
        } header: {
            Text(Texts_SettingsView.storageInfoDatabase)
        }
    }

    private func storedRecordsSection(_ inventory: CleanDataInventory) -> some View {
        Section {
            LabeledContent(Texts_SettingsView.cleanDataBgReadings, value: inventory.bgReadings.count.formatted())
            LabeledContent(Texts_SettingsView.cleanDataTreatments, value: inventory.treatments.count.formatted())
            LabeledContent(Texts_SettingsView.cleanDataCalibrations, value: inventory.calibrations.count.formatted())
            LabeledContent(Texts_SettingsView.storageInfoSensors, value: inventory.sensors.formatted())
            LabeledContent(Texts_SettingsView.storageInfoDevices, value: inventory.devices.formatted())
        } header: {
            Text(Texts_SettingsView.cleanDataStoredData)
        }
    }

    private func historySection(firstDate: Date, lastDate: Date) -> some View {
        Section {
            LabeledContent(
                Texts_SettingsView.storageInfoEarliestRecord,
                value: firstDate.formatted(date: .abbreviated, time: .shortened)
            )
            LabeledContent(
                Texts_SettingsView.storageInfoLatestRecord,
                value: lastDate.formatted(date: .abbreviated, time: .shortened)
            )
        } header: {
            Text(Texts_SettingsView.storageInfoHistory)
        } footer: {
            Text(Texts_SettingsView.storageInfoRetentionFooter(UserDefaults.standard.retentionPeriodInDays))
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

// MARK: - Storage Info View Model

@MainActor
final class StorageInfoViewModel: ObservableObject {
    @Published private(set) var inventory: CleanDataInventory?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private let service: DataManagementService
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDataManagement)

    init(coreDataManager: CoreDataManager) {
        service = DataManagementService(coreDataManager: coreDataManager)
    }

    var totalRecordCount: Int {
        guard let inventory else { return 0 }
        return inventory.bgReadings.count
            + inventory.treatments.count
            + inventory.calibrations.count
            + inventory.sensors
            + inventory.devices
    }

    var firstStoredDate: Date? {
        inventoryDates.compactMap(\.firstDate).min()
    }

    var lastStoredDate: Date? {
        inventoryDates.compactMap(\.lastDate).max()
    }

    func loadInventoryIfNeeded() async {
        guard inventory == nil else { return }
        await refreshInventory()
    }

    func refreshInventory() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        do {
            inventory = try await service.inventory()
            isWorking = false
        } catch {
            trace(
                "in storageInfoInventory, failed. error = %{public}@",
                log: log,
                category: ConstantsLog.categoryDataManagement,
                type: .error,
                error.localizedDescription
            )
            isWorking = false
            errorMessage = error.localizedDescription
        }
    }

    private var inventoryDates: [CleanDataCategoryInventory] {
        guard let inventory else { return [] }
        return [inventory.bgReadings, inventory.treatments, inventory.calibrations]
    }
}

// MARK: - Data Retention View

struct DataRetentionView: View {
    @StateObject private var viewModel = DataRetentionViewModel()

    var body: some View {
        Form {
            Section {
                Toggle(Texts_SettingsView.cleanDataAutomaticHousekeeping, isOn: $viewModel.automaticHousekeepingEnabled)
                    .tint(.green)
                    .onChange(of: viewModel.automaticHousekeepingEnabled) { _ in
                        viewModel.automaticHousekeepingEnabledChanged()
                    }

                Picker(Texts_SettingsView.cleanDataKeepHistoricalData, selection: $viewModel.automaticRetentionDays) {
                    ForEach(viewModel.availableAutomaticRetentionDays, id: \.self) { days in
                        Text(Texts_SettingsView.cleanDataDays(days)).tag(days)
                    }
                }
                .disabled(!viewModel.automaticHousekeepingEnabled)
                .onChange(of: viewModel.automaticRetentionDays) { _ in
                    viewModel.automaticRetentionDaysChanged()
                }
            } header: {
                Text(Texts_SettingsView.dataManagementDataRetention)
            } footer: {
                Text(viewModel.automaticHousekeepingEnabled
                    ? Texts_SettingsView.cleanDataAutomaticHousekeepingFooter
                    : Texts_SettingsView.cleanDataAutomaticHousekeepingDisabledFooter)
            }

            if let lastHousekeepingDate = viewModel.lastHousekeepingDate {
                Section {
                    LabeledContent(
                        Texts_SettingsView.cleanDataLastHousekeepingCompleted,
                        value: lastHousekeepingDate.formatted(date: .abbreviated, time: .shortened)
                    )
                    LabeledContent(
                        Texts_SettingsView.cleanDataLastHousekeepingResult,
                        value: viewModel.lastHousekeepingResultDescription
                    )
                } header: {
                    Text(Texts_SettingsView.dataManagementLastHousekeeping)
                }
            }
        }
        .tint(Color(.systemBlue))
        .onAppear(perform: viewModel.refresh)
    }
}

// MARK: - Data Retention View Model

@MainActor
final class DataRetentionViewModel: ObservableObject {
    @Published var automaticHousekeepingEnabled = UserDefaults.standard.automaticHousekeepingEnabled
    @Published var automaticRetentionDays = UserDefaults.standard.retentionPeriodInDays
    @Published private(set) var lastHousekeepingDate = UserDefaults.standard.lastHousekeepingDate
    @Published private(set) var lastHousekeepingBgReadingsDeleted = UserDefaults.standard.lastHousekeepingBgReadingsDeleted
    @Published private(set) var lastHousekeepingTreatmentsDeleted = UserDefaults.standard.lastHousekeepingTreatmentsDeleted
    @Published private(set) var lastHousekeepingCalibrationsDeleted = UserDefaults.standard.lastHousekeepingCalibrationsDeleted

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDataManagement)

    var availableAutomaticRetentionDays: [Int] {
        ConstantsHousekeeping.retentionPeriodsInDays
    }

    var lastHousekeepingResultDescription: String {
        let totalDeleted = lastHousekeepingBgReadingsDeleted
            + lastHousekeepingTreatmentsDeleted
            + lastHousekeepingCalibrationsDeleted
        guard totalDeleted > 0 else { return Texts_SettingsView.cleanDataNoHousekeepingRequired }
        return Texts_SettingsView.cleanDataHousekeepingRecordsRemoved(totalDeleted)
    }

    func refresh() {
        let defaults = UserDefaults.standard
        automaticHousekeepingEnabled = defaults.automaticHousekeepingEnabled
        automaticRetentionDays = defaults.retentionPeriodInDays
        lastHousekeepingDate = defaults.lastHousekeepingDate
        lastHousekeepingBgReadingsDeleted = defaults.lastHousekeepingBgReadingsDeleted
        lastHousekeepingTreatmentsDeleted = defaults.lastHousekeepingTreatmentsDeleted
        lastHousekeepingCalibrationsDeleted = defaults.lastHousekeepingCalibrationsDeleted
    }

    func automaticHousekeepingEnabledChanged() {
        UserDefaults.standard.automaticHousekeepingEnabled = automaticHousekeepingEnabled
        trace(
            "in automaticHousekeepingEnabledChanged, enabled = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            automaticHousekeepingEnabled.description
        )
    }

    func automaticRetentionDaysChanged() {
        UserDefaults.standard.retentionPeriodInDays = automaticRetentionDays
        automaticRetentionDays = UserDefaults.standard.retentionPeriodInDays
        trace(
            "in automaticRetentionDaysChanged, retention period = %{public}@ days",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            automaticRetentionDays.description
        )
    }
}
