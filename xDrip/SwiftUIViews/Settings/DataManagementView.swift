//
//  DataManagementView.swift
//  xdrip
//
//  Created by Paul Plant on 13/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import os
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Section

// Defines the root Data Management section and its native backup destinations.
struct SettingsViewDataManagementSettingsViewModel: SettingsViewModelProtocol, SettingsNativeSectionProvider {
    private let dataManagementService: DataManagementService?

    init(coreDataManager: CoreDataManager?) {
        dataManagementService = coreDataManager.map(DataManagementService.init)
    }

    func settingsRows(sectionID _: Int) -> [SettingsRow] {
        [
            SettingsRow(
                id: "dataManagement.storageInfo",
                title: Texts_SettingsView.dataManagementStorageInfo,
                detail: databaseSizeDescription,
                accessory: .disclosure,
                action: .dataManagement(.storageInfo)
            ),
            SettingsRow(
                id: "dataManagement.createBackup",
                title: Texts_SettingsView.backupCreate,
                accessory: .disclosure,
                action: .dataManagement(.create)
            ),
            SettingsRow(
                id: "dataManagement.restoreBackup",
                title: Texts_SettingsView.backupRestore,
                accessory: .disclosure,
                action: .dataManagement(.restore)
            ),
            SettingsRow(
                id: "dataManagement.importData",
                title: Texts_SettingsView.dataManagementImportData,
                accessory: .disclosure,
                action: .dataManagement(.importData)
            ),
            SettingsRow(
                id: "dataManagement.manageData",
                title: Texts_SettingsView.dataManagementManageData,
                accessory: .disclosure,
                action: .dataManagement(.manageData)
            ),
        ]
    }

    func sectionTitle() -> String? { Texts_SettingsView.sectionTitleHousekeeper }
    func settingsRowText(index: Int) -> String {
        switch index {
        case 0: Texts_SettingsView.dataManagementStorageInfo
        case 1: Texts_SettingsView.backupCreate
        case 2: Texts_SettingsView.backupRestore
        case 3: Texts_SettingsView.dataManagementImportData
        default: Texts_SettingsView.dataManagementManageData
        }
    }

    func accessoryType(index _: Int) -> SettingsAccessory { .disclosure }
    func detailedText(index _: Int) -> String? { nil }
    func numberOfRows() -> Int { 5 }
    func onRowSelect(index _: Int) -> SettingsSelectedRowAction { .nothing }
    func isEnabled(index _: Int) -> Bool { true }
    func completeSettingsViewRefreshNeeded(index _: Int) -> Bool { false }
    func storeMessageHandler(messageHandler _: @escaping ((String, String) -> Void)) {}
    func storeRowReloadClosure(rowReloadClosure _: @escaping ((Int) -> Void)) {}

    private var databaseSizeDescription: String? {
        guard let storeSizeInBytes = dataManagementService?.currentStoreSizeInBytes() else { return nil }
        return ByteCountFormatter.string(fromByteCount: storeSizeInBytes, countStyle: .file)
    }
}

enum DataManagementFlow {
    case storageInfo
    case manageData
    case create
    case restore
    case importData

    var navigationTitle: String {
        switch self {
        case .storageInfo: Texts_SettingsView.dataManagementStorageInfo
        case .manageData: Texts_SettingsView.dataManagementManageData
        case .create: Texts_SettingsView.backupCreate
        case .restore: Texts_SettingsView.backupRestore
        case .importData: Texts_SettingsView.dataManagementImportData
        }
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    private static let backupType = UTType(exportedAs: "com.xdripswift.backup")
    private static let successColor = Color.green

    @StateObject private var viewModel: DataManagementViewModel
    private let coreDataManager: CoreDataManager
    private let flow: DataManagementFlow
    private let initialBackupURL: URL?
    private let initialBackupDidOpen: () -> Void
    @State private var isImporting = false
    @State private var showsReplaceConfirmation = false
    @State private var hasOpenedInitialBackup = false

    init(
        coreDataManager: CoreDataManager,
        flow: DataManagementFlow,
        initialBackupURL: URL? = nil,
        initialBackupDidOpen: @escaping () -> Void = {}
    ) {
        self.coreDataManager = coreDataManager
        self.flow = flow
        self.initialBackupURL = initialBackupURL
        self.initialBackupDidOpen = initialBackupDidOpen
        _viewModel = StateObject(wrappedValue: DataManagementViewModel(coreDataManager: coreDataManager))
    }

    @ViewBuilder
    var body: some View {
        switch flow {
        case .storageInfo:
            StorageInfoView(coreDataManager: coreDataManager)
        case .manageData:
            ManageDataView(coreDataManager: coreDataManager)
        case .importData:
            ImportDataView(coreDataManager: coreDataManager)
        case .create, .restore:
            backupAndRestoreView
        }
    }

    private var backupAndRestoreView: some View {
        Form {
            switch flow {
            case .create:
                if let manifest = viewModel.createdBackupManifest {
                    successSection(Texts_SettingsView.backupCreated)
                    backupSummarySection(manifest)
                } else {
                    backupSection
                    passwordProtectionSection
                    createBackupSection
                }
            case .restore:
                if let result = viewModel.restoreResult {
                    successSection(Texts_SettingsView.backupRestored)
                    resultSection(result)
                    if result.accountsRestored > 0 {
                        accountsSummarySection(result)
                    }
                } else if viewModel.selectedBackupURL == nil {
                    restoreFileSection
                } else if viewModel.isWaitingForBackupPassword {
                    encryptedBackupNotice
                    lockedBackupSection
                } else if let inspection = viewModel.inspection {
                    backupContentsSection(inspection.payload)
                    restoreOptionsSection
                }
            case .storageInfo, .manageData, .importData:
                EmptyView()
            }
        }
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
        .sheet(item: $viewModel.shareItem, onDismiss: viewModel.finishSharingBackup) { item in
            BackupShareSheet(url: item.url) { completed, error in
                viewModel.recordShareCompletion(completed: completed, error: error)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [Self.backupType, .data],
            allowsMultipleSelection: false
        ) { result in
            viewModel.open(result)
        }
        .alert(Texts_SettingsView.backupReplaceQuestion, isPresented: $showsReplaceConfirmation) {
            Button(Texts_SettingsView.backupReplaceData, role: .destructive) {
                viewModel.restore()
            }
            Button(Texts_Common.Cancel, role: .cancel) {}
        } message: {
            Text(Texts_SettingsView.backupReplaceWarning)
        }
        .alert(Texts_SettingsView.backupAndRestore, isPresented: errorIsPresented) {
            Button(Texts_Common.Ok) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // Keep the system alert actions blue instead of inheriting the Settings stack's yellow tint.
        .tint(Color(.systemBlue))
        .onAppear(perform: openInitialBackupIfNeeded)
    }

    // MARK: - Create Backup

    private var backupSection: some View {
        Section(Texts_SettingsView.backupCreate) {
            Toggle(Texts_SettingsView.backupAppSettingsAndAlerts, isOn: $viewModel.options.includesSettings)
                .tint(.green)
            Toggle(Texts_SettingsView.cleanDataBgReadings, isOn: $viewModel.options.includesBgReadings)
                .tint(.green)
            Toggle(Texts_SettingsView.cleanDataTreatments, isOn: $viewModel.options.includesTreatments)
                .tint(.green)
        }
    }

    private var passwordProtectionSection: some View {
        Section {
            Toggle(Texts_SettingsView.backupEncrypt, isOn: $viewModel.passwordProtectsBackup)
                .tint(.green)
                .onChange(of: viewModel.passwordProtectsBackup) { enabled in
                    if !enabled { viewModel.options.includesAccounts = false }
                }

            if viewModel.passwordProtectsBackup {
                Toggle(Texts_SettingsView.backupAccounts, isOn: $viewModel.options.includesAccounts)
                    .tint(.green)
                SecureField(Texts_Common.password, text: $viewModel.backupPassphrase)
                    .textContentType(.newPassword)
                SecureField(Texts_SettingsView.backupConfirmPassword, text: $viewModel.backupPassphraseConfirmation)
                    .textContentType(.newPassword)
            }
        } header: {
            Text(Texts_SettingsView.backupPasswordProtection)
        } footer: {
            if !viewModel.passwordProtectsBackup {
                Text(Texts_SettingsView.backupPasswordProtectionFooter)
            } else if viewModel.options.includesAccounts {
                Text(Texts_SettingsView.backupAccountDetailsFooter)
            }
        }
    }

    private var createBackupSection: some View {
        Section {
            Button {
                viewModel.createBackup()
            } label: {
                Text(Texts_SettingsView.backupCreateAndShare)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Self.successColor)
            .disabled(!viewModel.canCreateBackup)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } footer: {
            if viewModel.passwordProtectsBackup {
                Text(Texts_SettingsView.backupEncryptedCreationFooter)
            }
        }
    }

    private func backupSummarySection(_ manifest: BackupManifest) -> some View {
        Section {
            LabeledContent(Texts_SettingsView.backupCreatedAt, value: manifest.createdAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent(Texts_SettingsView.backupEarliestData, value: earliestDataDescription(manifest))
            LabeledContent(Texts_SettingsView.cleanDataBgReadings, value: manifest.bgReadingCount.formatted())
            LabeledContent(Texts_SettingsView.cleanDataTreatments, value: manifest.treatmentCount.formatted())
            LabeledContent(Texts_SettingsView.backupSettingsAndAlerts, value: manifest.includesSettings ? Texts_SettingsView.backupIncluded : Texts_SettingsView.backupNotIncluded)
            LabeledContent(Texts_SettingsView.backupAccountDetails, value: manifest.includesAccounts ? Texts_SettingsView.backupIncluded : Texts_SettingsView.backupNotIncluded)
            LabeledContent(Texts_SettingsView.backupPasswordProtection, value: manifest.isPasswordProtected ? Texts_Common.enabled : Texts_SettingsView.backupNotEnabled)
        } header: {
            Text(Texts_SettingsView.backupSummary)
        } footer: {
            Text(Texts_SettingsView.backupCreatedWithAppVersion(manifest.appVersion))
        }
    }

    // MARK: - Restore Backup

    private var restoreFileSection: some View {
        Section {
            Button(Texts_SettingsView.backupChooseFile) {
                isImporting = true
            }
            .tint(Color(.systemBlue))
        } header: {
            Text(Texts_SettingsView.backupFile)
        } footer: {
            Text(Texts_SettingsView.backupFileCheckFooter)
        }
    }

    private var lockedBackupSection: some View {
        Section(Texts_SettingsView.backupSelected) {
            if let backupDate = viewModel.selectedBackupDate {
                LabeledContent(
                    Texts_SettingsView.backupCreatedAt,
                    value: backupDate.formatted(date: .abbreviated, time: .shortened)
                )
            }

            LabeledContent(Texts_Common.password) {
                SecureField(Texts_SettingsView.backupPasswordRequired, text: $viewModel.restorePassphrase)
                    .textContentType(.password)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 180)
            }

            Button {
                viewModel.unlockBackup()
            } label: {
                Text(Texts_SettingsView.backupUnlock)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.systemBlue))
            .disabled(viewModel.restorePassphrase.isEmpty)
        }
    }

    private var encryptedBackupNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.red)
            Text(Texts_SettingsView.backupEncryptedNotice)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func backupContentsSection(_ payload: BackupPayload) -> some View {
        let manifest = payload.manifest
        return Section {
            LabeledContent(Texts_SettingsView.backupCreatedAt, value: manifest.createdAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent(Texts_SettingsView.backupEarliestData, value: earliestDataDescription(payload))
            LabeledContent(Texts_SettingsView.cleanDataBgReadings, value: manifest.bgReadingCount.formatted())
            LabeledContent(Texts_SettingsView.cleanDataTreatments, value: manifest.treatmentCount.formatted())
            LabeledContent(Texts_SettingsView.backupSettings, value: manifest.includesSettings ? Texts_SettingsView.backupIncluded : Texts_SettingsView.backupNotIncluded)
            LabeledContent(Texts_SettingsView.backupAccountDetails) {
                HStack(spacing: 5) {
                    if manifest.includesAccounts {
                        Image(systemName: "lock.open.fill")
                            .foregroundStyle(Self.successColor)
                    }
                    Text(manifest.includesAccounts ? Texts_SettingsView.backupIncluded : Texts_SettingsView.backupNotIncluded)
                }
            }
        } header: {
            Text(Texts_SettingsView.backupSelected)
        } footer: {
            Text(Texts_SettingsView.backupCreatedWithAppVersion(manifest.appVersion))
        }
    }

    private var restoreOptionsSection: some View {
        Section(Texts_SettingsView.backupRestoreOptions) {
            Picker(Texts_SettingsView.backupDataHandling, selection: $viewModel.mergeMode) {
                Text(Texts_SettingsView.backupKeepCurrentData).tag(BackupMergeMode.keepCurrent)
                Text(Texts_SettingsView.backupFillGaps).tag(BackupMergeMode.fillGaps)
                Text(Texts_SettingsView.backupReplaceRange).tag(BackupMergeMode.replaceRange)
                Text(Texts_SettingsView.backupIgnoreData).tag(BackupMergeMode.ignore)
            }
            Toggle(Texts_SettingsView.backupRestoreSettingsAndAlerts, isOn: $viewModel.restoresSettings)
                .tint(.green)
                .disabled(viewModel.inspection?.payload.manifest.includesSettings != true)
            Toggle(Texts_SettingsView.backupRestoreAccounts, isOn: restoreAccountsBinding)
                .tint(.green)
                .disabled(!viewModel.hasRestorableAccounts)
            if viewModel.restoresAccounts {
                ForEach(BackupAccountCategory.allCases) { category in
                    Toggle(isOn: accountCategoryBinding(for: category)) {
                        Text(category.title)
                            .padding(.leading, 16)
                    }
                    .tint(.green)
                    .disabled(!viewModel.availableAccountCategories.contains(category))
                }
            }

            Button {
                if viewModel.mergeMode == .replaceRange {
                    showsReplaceConfirmation = true
                } else {
                    viewModel.restore()
                }
            } label: {
                Text(viewModel.mergeMode == .replaceRange ? Texts_SettingsView.backupReplaceAndRestore : Texts_SettingsView.backupRestore)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Self.successColor)
            .disabled(!viewModel.canRestore)
        }
    }

    private func accountCategoryBinding(for category: BackupAccountCategory) -> Binding<Bool> {
        Binding(
            get: { viewModel.restoredAccountCategories.contains(category) },
            set: { viewModel.setAccountCategory(category, isEnabled: $0) }
        )
    }

    private var restoreAccountsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.restoresAccounts },
            set: { viewModel.setRestoresAccounts($0) }
        )
    }

    private func resultSection(_ result: BackupRestoreResult) -> some View {
        Section(Texts_SettingsView.backupRestoreSummary) {
            LabeledContent(
                Texts_SettingsView.backupBgReadingsAppliedFrom,
                value: result.firstBgReadingAppliedAt?.formatted(date: .abbreviated, time: .shortened) ?? Texts_Common.notAvailable
            )
            LabeledContent(Texts_SettingsView.backupBgReadingsAdded, value: result.bgReadingsAdded.formatted())
            LabeledContent(Texts_SettingsView.backupBgReadingsSkipped, value: result.bgReadingsSkipped.formatted())
            LabeledContent(Texts_SettingsView.backupTreatmentsAdded, value: result.treatmentsAdded.formatted())
            LabeledContent(Texts_SettingsView.backupTreatmentsSkipped, value: result.treatmentsSkipped.formatted())
            LabeledContent(Texts_SettingsView.backupSettingsRestored, value: result.settingsRestored.formatted())
        }
    }

    private func earliestDataDescription(_ payload: BackupPayload) -> String {
        earliestDataDescription(
            payload.manifest,
            fallbackFirstTreatmentDate: payload.treatments.map(\.date).min()
        )
    }

    private func earliestDataDescription(
        _ manifest: BackupManifest,
        fallbackFirstTreatmentDate: Date? = nil
    ) -> String {
        let earliestDate = [
            manifest.firstBgReadingDate,
            manifest.firstTreatmentDate ?? fallbackFirstTreatmentDate,
        ]
        .compactMap { $0 }
        .min()
        guard let earliestDate else { return Texts_Common.notAvailable }
        return earliestDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short)
            + " (" + earliestDate.daysAndHoursAgo(showOnlyDays: true) + ")"
    }

    private func accountsSummarySection(_ result: BackupRestoreResult) -> some View {
        Section(Texts_SettingsView.backupAccountRestore) {
            ForEach(BackupAccountCategory.allCases) { category in
                let status = result.accountStatuses[category] ?? .unavailable
                LabeledContent {
                    if status == .unavailable {
                        Text(accountRestoreDescription(status))
                            .foregroundStyle(Color(.secondaryLabel))
                    } else {
                        Text(accountRestoreDescription(status))
                    }
                } label: {
                    Text(category.title)
                }
            }
        }
    }

    private func successSection(_ title: String) -> some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Self.successColor)
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(ConstantsUI.activeRowBackgroundColor)
        }
    }

    private func accountRestoreDescription(_ status: BackupAccountRestoreStatus) -> String {
        switch status {
        case .restored: Texts_Common.yes
        case .notRestored: Texts_Common.no
        case .unavailable: Texts_Common.notAvailable
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented { viewModel.errorMessage = nil }
        }
    }

    /// Opens a document supplied by another app instance without showing the file importer.
    private func openInitialBackupIfNeeded() {
        guard !hasOpenedInitialBackup, let initialBackupURL else { return }

        hasOpenedInitialBackup = true
        viewModel.open(initialBackupURL)
        initialBackupDidOpen()
    }
}

// MARK: - View Model

// Keeps the create and restore workflows independent from the Settings navigation layer.
@MainActor
final class DataManagementViewModel: ObservableObject {
    @Published var options = BackupOptions()
    @Published var backupPassphrase = ""
    @Published var backupPassphraseConfirmation = ""
    @Published var passwordProtectsBackup = false
    @Published var restorePassphrase = ""
    @Published var inspection: BackupInspection?
    @Published var encryptedBackupURL: URL?
    @Published var selectedBackupURL: URL?
    @Published var selectedBackupRequiresPassword = false
    @Published var restorePasswordIsVerified = false
    @Published var mergeMode = BackupMergeMode.keepCurrent
    @Published var restoresSettings = true
    @Published var restoresAccounts = false
    @Published var restoredAccountCategories = Set<BackupAccountCategory>()
    @Published var restoreResult: BackupRestoreResult?
    @Published var shareItem: BackupShareItem?
    @Published var createdBackupManifest: BackupManifest?
    @Published var isWorking = false
    @Published var status = ""
    @Published var errorMessage: String?

    private let service: BackupService
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDataManagement)
    private var pendingCreatedBackupManifest: BackupManifest?

    init(coreDataManager: CoreDataManager) {
        service = BackupService(coreDataManager: coreDataManager)
    }

    var hasBackupContent: Bool {
        options.includesSettings || options.includesBgReadings || options.includesTreatments
    }

    var canCreateBackup: Bool {
        guard hasBackupContent else { return false }
        guard passwordProtectsBackup else { return true }
        return backupPassphrase.count >= 4
            && backupPassphraseConfirmation.count >= 4
            && backupPassphrase == backupPassphraseConfirmation
    }

    var selectedBackupFileName: String? {
        selectedBackupURL?.lastPathComponent
    }

    var selectedBackupDate: Date? {
        guard let fileName = selectedBackupFileName else { return nil }
        var displayName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        if displayName.hasSuffix("_encrypted") {
            displayName.removeLast("_encrypted".count)
        }
        let dateLength = "yyyy-MM-dd_HHmm".count
        guard displayName.count > dateLength else { return nil }
        let dateStart = displayName.index(displayName.endIndex, offsetBy: -dateLength)
        guard displayName[displayName.index(before: dateStart)] == "_" else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.date(from: String(displayName[dateStart...]))
    }

    var isWaitingForBackupPassword: Bool {
        selectedBackupRequiresPassword && !restorePasswordIsVerified
    }

    var canRestore: Bool {
        inspection != nil && (!selectedBackupRequiresPassword || restorePasswordIsVerified)
    }

    var availableAccountCategories: Set<BackupAccountCategory> {
        guard let accounts = inspection?.payload.accounts else { return [] }
        let accountKeys = Set(accounts.keys)
        return Set(BackupAccountCategory.allCases.filter {
            !$0.availabilityKeys.isDisjoint(with: accountKeys)
        })
    }

    var hasRestorableAccounts: Bool {
        !availableAccountCategories.isEmpty
    }

    func createBackup() {
        var selectedOptions = options
        selectedOptions.passphrase = passwordProtectsBackup ? backupPassphrase : nil
        start(status: passwordProtectsBackup
            ? Texts_SettingsView.backupCreatingEncryptedStatus
            : Texts_SettingsView.backupCreatingStatus)
        let service = service
        Task {
            do {
                let createdBackup = try await Task.detached(priority: .userInitiated) {
                    try await service.createBackup(options: selectedOptions)
                }.value
                pendingCreatedBackupManifest = createdBackup.manifest
                shareItem = BackupShareItem(url: createdBackup.url)
                trace(
                    "in createBackup, presenting backup share sheet",
                    log: log,
                    category: ConstantsLog.categoryDataManagement,
                    type: .info
                )
                finish()
            } catch {
                fail(error, operation: "createBackup")
            }
        }
    }

    func finishSharingBackup() {
        trace(
            "in finishSharingBackup, backup share sheet dismissed",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info
        )
        createdBackupManifest = pendingCreatedBackupManifest
        pendingCreatedBackupManifest = nil
    }

    func recordShareCompletion(completed: Bool, error: Error?) {
        if let error {
            traceFailure(error, operation: "shareBackup")
        } else {
            trace(
                "in shareBackup, share sheet completed = %{public}@",
                log: log,
                category: ConstantsLog.categoryDataManagement,
                type: .info,
                completed.description
            )
        }
    }

    func open(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let requiresPassword = try service.backupRequiresPassphrase(at: url)
            trace(
                "in openBackup, backup file selected. encrypted = %{public}@",
                log: log,
                category: ConstantsLog.categoryDataManagement,
                type: .info,
                requiresPassword.description
            )
            selectedBackupURL = url
            selectedBackupRequiresPassword = requiresPassword
            restorePasswordIsVerified = false
            inspection = nil
            restoreResult = nil
            if requiresPassword {
                encryptedBackupURL = url
                restorePassphrase = ""
            } else {
                encryptedBackupURL = nil
                inspectBackup(at: url, passphrase: nil, status: Texts_SettingsView.backupCheckingStatus)
            }
        } catch {
            fail(error, operation: "openBackup")
        }
    }

    func open(_ url: URL) {
        open(.success([url]))
    }

    func unlockBackup() {
        guard let encryptedBackupURL else { return }
        trace(
            "in unlockBackup, attempting to unlock encrypted backup",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info
        )
        inspectBackup(
            at: encryptedBackupURL,
            passphrase: restorePassphrase,
            status: Texts_SettingsView.backupDecryptingStatus
        )
    }

    private func inspectBackup(at url: URL, passphrase: String?, status: String) {
        start(status: status)
        let service = service
        Task {
            do {
                let inspection = try await Task.detached(priority: .userInitiated) {
                    try service.inspectBackup(at: url, passphrase: passphrase)
                }.value
                setInspection(inspection)
                finish()
            } catch {
                fail(error, operation: "inspectBackup")
            }
        }
    }

    func restore() {
        guard let inspection else { return }
        start(status: inspection.payload.manifest.isPasswordProtected
            ? Texts_SettingsView.backupRestoringEncryptedStatus
            : Texts_SettingsView.backupRestoringStatus)
        let service = service
        let mode = mergeMode
        let shouldRestoreSettings = restoresSettings
        let accountCategories = restoresAccounts ? restoredAccountCategories : []
        Task {
            do {
                restoreResult = try await Task.detached(priority: .userInitiated) {
                    try await service.restore(
                        inspection: inspection,
                        mode: mode,
                        restoresSettings: shouldRestoreSettings,
                        restoredAccountCategories: accountCategories
                    )
                }.value
                finish()
            } catch {
                fail(error, operation: "restoreBackup")
            }
        }
    }

    func setAccountCategory(_ category: BackupAccountCategory, isEnabled: Bool) {
        if isEnabled {
            restoredAccountCategories.insert(category)
        } else {
            restoredAccountCategories.remove(category)
        }
    }

    func setRestoresAccounts(_ restoresAccounts: Bool) {
        self.restoresAccounts = restoresAccounts
        restoredAccountCategories = restoresAccounts ? availableAccountCategories : []
    }

    private func start(status: String) {
        isWorking = true
        self.status = status
        errorMessage = nil
    }

    private func setInspection(_ inspection: BackupInspection) {
        self.inspection = inspection
        restorePasswordIsVerified = selectedBackupRequiresPassword
        restoresSettings = inspection.payload.manifest.includesSettings
        restoresAccounts = false
        restoredAccountCategories = []
        restoreResult = nil
    }

    private func finish() {
        isWorking = false
        status = ""
    }

    private func fail(_ error: Error, operation: String) {
        traceFailure(error, operation: operation)
        isWorking = false
        status = ""
        errorMessage = error.localizedDescription
    }

    private func traceFailure(_ error: Error, operation: String) {
        let description = (error as? BackupError)?.traceDescription ?? String(describing: type(of: error))
        trace(
            "in %{public}@, failed. error = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .error,
            operation,
            description
        )
    }
}

// MARK: - System Sharing

struct BackupShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct BackupShareSheet: UIViewControllerRepresentable {
    let url: URL
    let completion: (Bool, Error?) -> Void

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in
            completion(completed, error)
        }
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
