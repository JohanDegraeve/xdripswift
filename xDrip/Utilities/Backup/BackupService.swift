//
//  BackupService.swift
//  xdrip
//
//  Created by Paul Plant on 13/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import Foundation
import os

// Creates and restores self-contained archives without carrying live sensor or connection state.
final class BackupService: @unchecked Sendable {
    private static let magic = Data("XDRIPBKP1".utf8)
    private static let accountKeys = BackupAccountCategory.allKeys
    // Runtime, sensor-specific and current post-processing values must not move between app instances.
    private static let excludedSettingKeys: Set<String> = [
        UserDefaults.Key.timeStampOfLastFollowerConnection.rawValue,
        UserDefaults.Key.medtrumEasyViewCachedConnections.rawValue,
        UserDefaults.Key.medtrumEasyViewConnectionsFetchFailed.rawValue,
        UserDefaults.Key.medtrumEasyViewPreventLogin.rawValue,
        UserDefaults.Key.medtrumEasyViewUserType.rawValue,
        UserDefaults.Key.libreLinkUpPreventLogin.rawValue,
        UserDefaults.Key.libreLinkUpCountry.rawValue,
        UserDefaults.Key.libreLinkUpVersion.rawValue,
        UserDefaults.Key.libreLinkUpReAcceptNeeded.rawValue,
        UserDefaults.Key.libreLinkUpIs15DaySensor.rawValue,
        UserDefaults.Key.snoozeAllAlertsFromDate.rawValue,
        UserDefaults.Key.snoozeAllAlertsUntilDate.rawValue,
        UserDefaults.Key.enableAdjustment.rawValue,
        UserDefaults.Key.enableSmoothing.rawValue,
        UserDefaults.Key.bgSmoothingPeriodInMinutes.rawValue,
        UserDefaults.Key.bgSmoothingStrength.rawValue,
        UserDefaults.Key.bgSmoothingAlgorithm.rawValue,
        UserDefaults.Key.useFiveMinuteReadings.rawValue,
        UserDefaults.Key.fiveMinuteReadingsStartTimeStamp.rawValue,
        UserDefaults.Key.postProcessingStartTimeStamp.rawValue,
        UserDefaults.Key.postProcessingApplyFromTimeStamp.rawValue,
        UserDefaults.Key.postProcessingSourceContextIdentifier.rawValue,
        UserDefaults.Key.postProcessingPreviewChartHoursToShow.rawValue,
        UserDefaults.Key.activeSensorSerialNumber.rawValue,
        UserDefaults.Key.activeSensorTransmitterId.rawValue,
        UserDefaults.Key.activeSensorDescription.rawValue,
        UserDefaults.Key.activeSensorStartDate.rawValue,
        UserDefaults.Key.activeSensorMaxSensorAgeInDays.rawValue,
        UserDefaults.Key.activeSensorMaxSensorAgeInDaysOverridenAnubis.rawValue,
        UserDefaults.Key.is15DayDexcomG7.rawValue,
        UserDefaults.Key.nightscoutSyncRequired.rawValue,
        UserDefaults.Key.nightscoutTreatmentsUpdateCounter.rawValue,
        UserDefaults.Key.nightscoutDeviceStatus.rawValue,
        UserDefaults.Key.nightscoutDeviceStatusWasUpdated.rawValue,
        UserDefaults.Key.nightscoutProfile.rawValue,
        UserDefaults.Key.storeReadingsInHealthkitAuthorized.rawValue,
        UserDefaults.Key.timeStampLatestHealthKitStoreBgReading.rawValue,
        UserDefaults.Key.dexcomShareLoginFailedTimestamp.rawValue,
        UserDefaults.Key.missedReadingAlertChanged.rawValue,
        UserDefaults.Key.timeStampAppLaunch.rawValue,
        UserDefaults.Key.timeStampLatestNSUploadedBgReadingToNightscout.rawValue,
        UserDefaults.Key.timeStampLatestNightscoutSyncRequest.rawValue,
        UserDefaults.Key.timeStampLatestNSUploadedCalibrationToNightscout.rawValue,
        UserDefaults.Key.timeStampLatestDexcomShareUploadedBgReading.rawValue,
        UserDefaults.Key.transmitterBatteryInfo.rawValue,
        UserDefaults.Key.timeStampOfLastBatteryReading.rawValue,
        UserDefaults.Key.readingsStoredInSharedUserDefaultsAsDictionary.rawValue,
        UserDefaults.Key.timeStampLatestLoopSharedBgReading.rawValue,
        UserDefaults.Key.nfcScanFailed.rawValue,
        UserDefaults.Key.nfcScanSuccessful.rawValue,
        UserDefaults.Key.stopActiveSensor.rawValue,
        UserDefaults.Key.libre1DerivedAlgorithmParameters.rawValue,
        UserDefaults.Key.previousRawLibreValues.rawValue,
        UserDefaults.Key.previousRawGlucoseValues.rawValue,
        UserDefaults.Key.previousRawTemperatureValues.rawValue,
        UserDefaults.Key.previousTemperatureAdjustmentValues.rawValue,
        UserDefaults.Key.cgmTransmitterDeviceAddress.rawValue,
        UserDefaults.Key.appInForeGround.rawValue,
        UserDefaults.Key.libreActiveSensorUnlockCode.rawValue,
        UserDefaults.Key.libreActiveSensorUnlockCount.rawValue,
        UserDefaults.Key.libreSensorUID.rawValue,
        UserDefaults.Key.librePatchInfo.rawValue,
        UserDefaults.Key.timeStampOfLastHeartBeat.rawValue,
        UserDefaults.Key.updateSnoozeStatus.rawValue,
        UserDefaults.Key.calenderId.rawValue,
        UserDefaults.Key.lastHousekeepingDate.rawValue,
        UserDefaults.Key.lastHousekeepingAttemptDate.rawValue,
        UserDefaults.Key.lastHousekeepingAttemptRetentionPeriodInDays.rawValue,
        UserDefaults.Key.lastHousekeepingRetentionPeriodInDays.rawValue,
        UserDefaults.Key.lastHousekeepingBgReadingsDeleted.rawValue,
        UserDefaults.Key.lastHousekeepingTreatmentsDeleted.rawValue,
        UserDefaults.Key.lastHousekeepingCalibrationsDeleted.rawValue,
    ]

    private let coreDataManager: CoreDataManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryDataManagement)

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    // MARK: - Incoming Documents

    /// Copies a document opened by iOS into this app instance before the source access expires.
    static func copyIncomingBackup(from sourceURL: URL) throws -> URL {
        guard sourceURL.pathExtension.lowercased() == "xdripbackup" else {
            throw BackupError.invalidFile
        }

        let accessedSecurityScopedResource = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScopedResource {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let cachesURL = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let requestDirectory = cachesURL
            .appendingPathComponent("Incoming Backups", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: requestDirectory, withIntermediateDirectories: true)
        let destinationURL = requestDirectory.appendingPathComponent(sourceURL.lastPathComponent)

        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: sourceURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try fileManager.copyItem(at: coordinatedURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }

        if let error = copyError ?? coordinationError {
            try? fileManager.removeItem(at: requestDirectory)
            throw error
        }

        return destinationURL
    }

    // MARK: - Archive Creation and Inspection

    func createBackup(options: BackupOptions) async throws -> CreatedBackup {
        let startedAt = Date()
        trace(
            "in createBackup, starting. encrypted = %{public}@, settings = %{public}@, accounts = %{public}@, BG readings = %{public}@, treatments = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            (options.passphrase?.isEmpty == false).description,
            options.includesSettings.description,
            options.includesAccounts.description,
            options.includesBgReadings.description,
            options.includesTreatments.description
        )
        let settings = options.includesSettings ? try storedValues(excluding: Self.accountKeys.union(Self.excludedSettingKeys)) : nil
        guard !options.includesAccounts || options.passphrase?.isEmpty == false else {
            throw BackupError.missingPassphrase
        }
        let storedAccounts = options.includesAccounts ? try storedValues(including: Self.accountKeys) : nil
        let accounts = storedAccounts?.isEmpty == false ? storedAccounts : nil

        let context = coreDataManager.privateChildManagedObjectContext()
        let snapshot = try await context.perform {
            let alertTypes = options.includesSettings ? try self.exportAlertTypes(context: context) : []
            let bgReadings = options.includesBgReadings ? try self.exportBgReadings(context: context) : []
            let treatments = options.includesTreatments ? try self.exportTreatments(context: context) : []
            return (alertTypes, bgReadings, treatments)
        }

        let info = Bundle.main.infoDictionary
        let manifest = BackupManifest(
            format: "xdrip-backup",
            formatVersion: BackupManifest.currentFormatVersion,
            createdAt: Date(),
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info?["CFBundleVersion"] as? String ?? "unknown",
            bgReadingCount: snapshot.1.count,
            treatmentCount: snapshot.2.count,
            firstBgReadingDate: snapshot.1.map(\.timeStamp).min(),
            lastBgReadingDate: snapshot.1.map(\.timeStamp).max(),
            firstTreatmentDate: snapshot.2.map(\.date).min(),
            includesSettings: options.includesSettings,
            includesAccounts: accounts?.isEmpty == false,
            isPasswordProtected: options.passphrase?.isEmpty == false
        )
        let payload = BackupPayload(
            manifest: manifest,
            settings: settings,
            accounts: accounts,
            alertTypes: snapshot.0,
            bgReadings: snapshot.1,
            treatments: snapshot.2
        )
        let json = try encoder.encode(payload)
        let compressed = try (json as NSData).compressed(using: .lzfse) as Data
        var archive = Self.magic
        if let passphrase = options.passphrase, !passphrase.isEmpty {
            archive.append(contentsOf: [UInt8(1)])
            try archive.append(encoder.encode(BackupCrypto.encrypt(compressed, passphrase: passphrase)))
        } else {
            archive.append(contentsOf: [UInt8(0)])
            archive.append(compressed)
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                fileName(for: manifest.createdAt, isEncrypted: manifest.isPasswordProtected)
            )
        try archive.write(to: outputURL, options: .atomic)
        trace(
            "in createBackup, completed. duration = %{public}@ ms, archive bytes = %{public}@, BG readings = %{public}@, treatments = %{public}@, settings = %{public}@, accounts = %{public}@, encrypted = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            elapsedMilliseconds(since: startedAt),
            archive.count.description,
            manifest.bgReadingCount.description,
            manifest.treatmentCount.description,
            manifest.includesSettings.description,
            manifest.includesAccounts.description,
            manifest.isPasswordProtected.description
        )
        return CreatedBackup(url: outputURL, manifest: manifest)
    }

    func backupRequiresPassphrase(at url: URL) throws -> Bool {
        let archive = try readArchive(at: url)
        return try protectionFlag(in: archive) == 1
    }

    func inspectBackup(at url: URL, passphrase: String? = nil) throws -> BackupInspection {
        let startedAt = Date()
        trace(
            "in inspectBackup, starting backup inspection",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info
        )
        let archive = try readArchive(at: url)
        let protected = try protectionFlag(in: archive) == 1
        let body = Data(archive.dropFirst(Self.magic.count + 1))
        let compressed: Data
        if protected {
            guard let passphrase, !passphrase.isEmpty else { throw BackupError.missingPassphrase }
            compressed = try BackupCrypto.decrypt(
                decoder.decode(BackupEncryptedData.self, from: body),
                passphrase: passphrase
            )
        } else {
            compressed = body
        }
        let json = try (compressed as NSData).decompressed(using: .lzfse) as Data
        let payload = try decoder.decode(BackupPayload.self, from: json)
        guard payload.manifest.isPasswordProtected == protected else { throw BackupError.invalidFile }
        guard payload.manifest.format == "xdrip-backup" else { throw BackupError.invalidFile }
        guard payload.manifest.formatVersion <= BackupManifest.currentFormatVersion else {
            throw BackupError.unsupportedVersion(payload.manifest.formatVersion)
        }
        try validate(payload)
        trace(
            "in inspectBackup, completed. duration = %{public}@ ms, format version = %{public}@, archive bytes = %{public}@, encrypted = %{public}@, BG readings = %{public}@, treatments = %{public}@, settings = %{public}@, accounts = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            elapsedMilliseconds(since: startedAt),
            payload.manifest.formatVersion.description,
            archive.count.description,
            protected.description,
            payload.manifest.bgReadingCount.description,
            payload.manifest.treatmentCount.description,
            payload.manifest.includesSettings.description,
            payload.manifest.includesAccounts.description
        )
        return BackupInspection(payload: payload)
    }

    private func protectionFlag(in archive: Data) throws -> UInt8 {
        guard archive.starts(with: Self.magic), archive.count > Self.magic.count else {
            throw BackupError.invalidFile
        }
        let flag = archive[Self.magic.count]
        guard flag == 0 || flag == 1 else { throw BackupError.invalidFile }
        return flag
    }

    private func readArchive(at url: URL) throws -> Data {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { url.stopAccessingSecurityScopedResource() }
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    // MARK: - Restore

    func restore(
        inspection: BackupInspection,
        mode: BackupMergeMode,
        restoresSettings: Bool,
        restoredAccountCategories: Set<BackupAccountCategory>
    ) async throws -> BackupRestoreResult {
        let startedAt = Date()
        let payload = inspection.payload
        trace(
            "in restore, starting. mode = %{public}@, settings = %{public}@, account categories = %{public}@, BG readings = %{public}@, treatments = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            mode.rawValue,
            restoresSettings.description,
            restoredAccountCategories.count.description,
            payload.manifest.bgReadingCount.description,
            payload.manifest.treatmentCount.description
        )
        let restoredAccountKeys = restoredAccountCategories.reduce(into: Set<String>()) {
            $0.formUnion($1.keys)
        }
        let accountValues = (payload.accounts ?? [:]).filter { restoredAccountKeys.contains($0.key) }

        let context = coreDataManager.privateChildManagedObjectContext()
        let counts = try await context.perform {
            if mode == .replaceRange {
                try self.deleteExistingData(in: payload, context: context)
            }
            let bgCounts: (added: Int, skipped: Int, firstAddedAt: Date?)
            let treatmentCounts: (added: Int, skipped: Int)
            if mode == .ignore {
                bgCounts = (0, payload.bgReadings.count, nil)
                treatmentCounts = (0, payload.treatments.count)
            } else {
                bgCounts = try self.restoreBgReadings(payload.bgReadings, mode: mode, context: context)
                treatmentCounts = try self.restoreTreatments(payload.treatments, context: context)
            }
            if restoresSettings {
                try self.replaceAlertTypes(payload.alertTypes, context: context)
            }
            try context.save()
            return (bgCounts, treatmentCounts)
        }
        coreDataManager.saveChanges()

        let restoredValueCounts = try await MainActor.run {
            let settingsCount = restoresSettings ? try restoreStoredValues(payload.settings ?? [:]) : 0
            let accountsCount = try restoreStoredValues(accountValues)
            return (settingsCount, accountsCount)
        }
        let payloadAccountKeys = Set((payload.accounts ?? [:]).keys)
        let accountStatuses = Dictionary(uniqueKeysWithValues: BackupAccountCategory.allCases.map { category in
            let isAvailable = !category.availabilityKeys.isDisjoint(with: payloadAccountKeys)
            let status: BackupAccountRestoreStatus = if !isAvailable {
                .unavailable
            } else if restoredAccountCategories.contains(category) {
                .restored
            } else {
                .notRestored
            }
            return (category, status)
        })
        let result = BackupRestoreResult(
            bgReadingsAdded: counts.0.added,
            bgReadingsSkipped: counts.0.skipped,
            firstBgReadingAppliedAt: counts.0.firstAddedAt,
            treatmentsAdded: counts.1.added,
            treatmentsSkipped: counts.1.skipped,
            settingsRestored: restoredValueCounts.0,
            accountsRestored: restoredValueCounts.1,
            accountStatuses: accountStatuses
        )
        trace(
            "in restore, completed. duration = %{public}@ ms, BG readings added = %{public}@, BG readings skipped = %{public}@, treatments added = %{public}@, treatments skipped = %{public}@, settings restored = %{public}@, account values restored = %{public}@",
            log: log,
            category: ConstantsLog.categoryDataManagement,
            type: .info,
            elapsedMilliseconds(since: startedAt),
            result.bgReadingsAdded.description,
            result.bgReadingsSkipped.description,
            result.treatmentsAdded.description,
            result.treatmentsSkipped.description,
            result.settingsRestored.description,
            result.accountsRestored.description
        )
        return result
    }

    // MARK: - Core Data Export

    private func exportBgReadings(context: NSManagedObjectContext) throws -> [BackupBgReading] {
        let request: NSFetchRequest<BgReading> = BgReading.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgReading.timeStamp), ascending: true)]
        request.fetchBatchSize = 1000
        return try context.fetch(request).map {
            BackupBgReading(
                id: $0.id,
                timeStamp: $0.timeStamp,
                a: $0.a,
                adjustedValue: $0.adjustedValue?.doubleValue,
                ageAdjustedRawValue: $0.ageAdjustedRawValue,
                backfilledAt: $0.backfilledAt,
                b: $0.b,
                c: $0.c,
                calculatedValue: $0.calculatedValue,
                calculatedValueSlope: $0.calculatedValueSlope,
                calibrationFlag: $0.calibrationFlag,
                deviceName: $0.deviceName,
                finalValue: $0.finalValue,
                hideSlope: $0.hideSlope,
                isSuppressedByFiveMinuteCadence: $0.isSuppressedByFiveMinuteCadence,
                ra: $0.ra,
                rawData: $0.rawData,
                rb: $0.rb,
                rc: $0.rc,
                smoothedValue: $0.smoothedValue?.doubleValue
            )
        }
    }

    private func exportTreatments(context: NSManagedObjectContext) throws -> [BackupTreatment] {
        let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(TreatmentEntry.date), ascending: true)]
        request.fetchBatchSize = 500
        return try context.fetch(request).map {
            BackupTreatment(
                date: $0.date,
                enteredBy: $0.enteredBy,
                id: $0.id,
                nightscoutEventType: $0.nightscoutEventType,
                notes: $0.notes,
                treatmentDeleted: $0.treatmentdeleted,
                treatmentType: $0.treatmentType.rawValue,
                uploaded: $0.uploaded,
                value: $0.value,
                valueSecondary: $0.valueSecondary
            )
        }
    }

    private func exportAlertTypes(context: NSManagedObjectContext) throws -> [BackupAlertType] {
        let request = NSFetchRequest<AlertType>(entityName: "AlertType")
        return try context.fetch(request).map { alertType in
            let entries = (alertType.alertEntries as? Set<AlertEntry> ?? []).map {
                BackupAlertEntry(
                    alertKind: $0.alertkind,
                    isDisabled: $0.isDisabled,
                    start: $0.start,
                    triggerValue: $0.triggerValue,
                    value: $0.value
                )
            }
            return BackupAlertType(
                enabled: alertType.enabled,
                name: alertType.name,
                overrideMute: alertType.overridemute,
                snooze: alertType.snooze,
                snoozePeriod: alertType.snoozeperiod,
                soundName: alertType.soundname,
                vibrate: alertType.vibrate,
                entries: entries.sorted { $0.start < $1.start }
            )
        }
    }

    // MARK: - Core Data Restore

    private func restoreBgReadings(
        _ readings: [BackupBgReading],
        mode: BackupMergeMode,
        context: NSManagedObjectContext
    ) throws -> (added: Int, skipped: Int, firstAddedAt: Date?) {
        let request: NSFetchRequest<BgReading> = BgReading.fetchRequest()
        let existing = try context.fetch(request)
        var ids = Set(existing.map(\.id))
        let timestamps = existing.map(\.timeStamp).sorted()
        var added = 0
        var skipped = 0
        var firstAddedAt: Date?
        for record in readings {
            let hasNearbyReading = timestamps.contains {
                abs($0.timeIntervalSince(record.timeStamp)) <= 30
            }
            let overlaps: Bool = switch mode {
            case .replaceRange:
                false
            case .fillGaps:
                hasNearbyReading
            case .keepCurrent:
                hasNearbyReading
                    || isInsideCoveredPeriod(record.timeStamp, existingTimestamps: timestamps)
            case .ignore:
                true
            }
            guard !ids.contains(record.id), !overlaps else {
                skipped += 1
                continue
            }
            let reading = BgReading(
                timeStamp: record.timeStamp,
                sensor: nil,
                calibration: nil,
                rawData: record.rawData,
                deviceName: record.deviceName,
                nsManagedObjectContext: context
            )
            reading.id = record.id
            reading.a = record.a
            reading.adjustedValue = record.adjustedValue.map(NSNumber.init(value:))
            reading.ageAdjustedRawValue = record.ageAdjustedRawValue
            reading.backfilledAt = record.backfilledAt
            reading.b = record.b
            reading.c = record.c
            reading.calculatedValue = record.calculatedValue
            reading.calculatedValueSlope = record.calculatedValueSlope
            reading.calibrationFlag = record.calibrationFlag
            reading.hideSlope = record.hideSlope
            reading.isSuppressedByFiveMinuteCadence = record.isSuppressedByFiveMinuteCadence
            reading.ra = record.ra
            reading.rb = record.rb
            reading.rc = record.rc
            reading.smoothedValue = record.smoothedValue.map(NSNumber.init(value:))
            ids.insert(record.id)
            added += 1
            firstAddedAt = min(firstAddedAt ?? record.timeStamp, record.timeStamp)
        }
        return (added, skipped, firstAddedAt)
    }

    private func restoreTreatments(
        _ treatments: [BackupTreatment],
        context: NSManagedObjectContext
    ) throws -> (added: Int, skipped: Int) {
        let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
        let existing = try context.fetch(request)
        var ids = Set(existing.map(\.id).filter { !$0.isEmpty })
        var fingerprints = Set(existing.map(treatmentFingerprint))
        var added = 0
        var skipped = 0
        for record in treatments {
            let fingerprint = treatmentFingerprint(record)
            guard record.id.isEmpty || !ids.contains(record.id), !fingerprints.contains(fingerprint),
                  let type = TreatmentType(rawValue: record.treatmentType)
            else {
                skipped += 1
                continue
            }
            let treatment = TreatmentEntry(
                id: record.id,
                date: record.date,
                value: record.value,
                valueSecondary: record.valueSecondary,
                treatmentType: type,
                uploaded: record.uploaded,
                nightscoutEventType: record.nightscoutEventType,
                enteredBy: record.enteredBy,
                notes: record.notes,
                nsManagedObjectContext: context
            )
            treatment.treatmentdeleted = record.treatmentDeleted
            if !record.id.isEmpty {
                ids.insert(record.id)
            }
            fingerprints.insert(fingerprint)
            added += 1
        }
        return (added, skipped)
    }

    private func replaceAlertTypes(_ alertTypes: [BackupAlertType], context: NSManagedObjectContext) throws {
        try context.fetch(NSFetchRequest<AlertEntry>(entityName: "AlertEntry")).forEach(context.delete)
        try context.fetch(NSFetchRequest<AlertType>(entityName: "AlertType")).forEach(context.delete)
        for record in alertTypes {
            let alertType = AlertType(
                enabled: record.enabled,
                name: record.name,
                overrideMute: record.overrideMute,
                snooze: record.snooze,
                snoozePeriod: Int(record.snoozePeriod),
                vibrate: record.vibrate,
                soundName: record.soundName,
                alertEntries: nil,
                nsManagedObjectContext: context
            )
            for entry in record.entries {
                guard let kind = AlertKind(rawValue: Int(entry.alertKind)) else { continue }
                _ = AlertEntry(
                    isDisabled: entry.isDisabled,
                    value: Int(entry.value),
                    triggerValue: Int(entry.triggerValue),
                    alertKind: kind,
                    start: Int(entry.start),
                    alertType: alertType,
                    nsManagedObjectContext: context
                )
            }
        }
    }

    private func deleteExistingData(in payload: BackupPayload, context: NSManagedObjectContext) throws {
        if let first = payload.manifest.firstBgReadingDate, let last = payload.manifest.lastBgReadingDate {
            let request: NSFetchRequest<BgReading> = BgReading.fetchRequest()
            request.predicate = NSPredicate(format: "timeStamp >= %@ AND timeStamp <= %@", first as NSDate, last as NSDate)
            try context.fetch(request).forEach(context.delete)
        }
        guard let first = payload.treatments.map(\.date).min(), let last = payload.treatments.map(\.date).max() else { return }
        let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", first as NSDate, last as NSDate)
        try context.fetch(request).forEach(context.delete)
    }

    // MARK: - Validation and Matching

    private func validateFinalValue(_ reading: BackupBgReading) throws {
        // finalValue is calculated rather than stored by Core Data, so verify its source values here.
        let reproduced = reading.smoothedValue ?? reading.adjustedValue ?? reading.calculatedValue
        guard abs(reproduced - reading.finalValue) < 0.000_001 else {
            throw BackupError.finalValueMismatch(reading.id)
        }
    }

    private func validate(_ payload: BackupPayload) throws {
        let manifest = payload.manifest
        let firstBgReadingDate = payload.bgReadings.map(\.timeStamp).min()
        let lastBgReadingDate = payload.bgReadings.map(\.timeStamp).max()
        let firstTreatmentDate = payload.treatments.map(\.date).min()
        guard manifest.bgReadingCount == payload.bgReadings.count,
              manifest.treatmentCount == payload.treatments.count,
              manifest.firstBgReadingDate == firstBgReadingDate,
              manifest.lastBgReadingDate == lastBgReadingDate,
              manifest.firstTreatmentDate == firstTreatmentDate,
              manifest.includesSettings == (payload.settings != nil),
              manifest.includesAccounts == (payload.accounts?.isEmpty == false),
              manifest.includesSettings || payload.alertTypes.isEmpty,
              payload.treatments.allSatisfy({ TreatmentType(rawValue: $0.treatmentType) != nil })
        else {
            throw BackupError.invalidFile
        }

        try payload.bgReadings.forEach(validateFinalValue)
        try payload.settings?.values.forEach { _ = try $0.decoded() }
        try payload.accounts?.values.forEach { _ = try $0.decoded() }
    }

    private func isInsideCoveredPeriod(_ date: Date, existingTimestamps: [Date]) -> Bool {
        guard let first = existingTimestamps.first, let last = existingTimestamps.last,
              date >= first, date <= last else { return false }
        var previous = first
        for current in existingTimestamps.dropFirst() {
            if date >= previous, date <= current {
                return current.timeIntervalSince(previous) <= 15 * 60
            }
            previous = current
        }
        return false
    }

    private func treatmentFingerprint(_ treatment: TreatmentEntry) -> String {
        treatmentFingerprint(BackupTreatment(
            date: treatment.date,
            enteredBy: treatment.enteredBy,
            id: treatment.id,
            nightscoutEventType: treatment.nightscoutEventType,
            notes: treatment.notes,
            treatmentDeleted: treatment.treatmentdeleted,
            treatmentType: treatment.treatmentType.rawValue,
            uploaded: treatment.uploaded,
            value: treatment.value,
            valueSecondary: treatment.valueSecondary
        ))
    }

    private func treatmentFingerprint(_ treatment: BackupTreatment) -> String {
        let timestampBucket = Int64(treatment.date.timeIntervalSince1970 / 30)
        let notes = treatment.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return "\(timestampBucket)|\(treatment.treatmentType)|\(treatment.value)|\(treatment.valueSecondary)|\(notes)"
    }

    // MARK: - User Defaults

    private func storedValues(excluding excludedKeys: Set<String>) throws -> [String: BackupPropertyListValue] {
        let values = persistentDefaults().filter { !excludedKeys.contains($0.key) }
        return try values.mapValues(BackupPropertyListValue.init)
    }

    private func storedValues(including includedKeys: Set<String>) throws -> [String: BackupPropertyListValue] {
        let values = persistentDefaults().filter { includedKeys.contains($0.key) }
        return try values.mapValues(BackupPropertyListValue.init)
    }

    private func persistentDefaults() -> [String: Any] {
        guard let identifier = Bundle.main.bundleIdentifier else { return [:] }
        return UserDefaults.standard.persistentDomain(forName: identifier) ?? [:]
    }

    private func restoreStoredValues(_ values: [String: BackupPropertyListValue]) throws -> Int {
        for (key, value) in values {
            try UserDefaults.standard.set(value.decoded(), forKey: key)
        }
        return values.count
    }

    // MARK: - File Naming

    private func fileName(for date: Date, isEncrypted: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let encryptionSuffix = isEncrypted ? "_encrypted" : ""
        return "\(ConstantsHomeView.applicationName)_\(formatter.string(from: date))\(encryptionSuffix).xdripbackup"
    }

    private func elapsedMilliseconds(since startDate: Date) -> String {
        Int(Date().timeIntervalSince(startDate) * 1000).description
    }
}
