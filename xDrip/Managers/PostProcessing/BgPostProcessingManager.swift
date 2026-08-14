//
//  BgPostProcessingManager.swift
//  xdrip
//
//  Created by Paul Plant on 1/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import os
import CoreData

/// manages glucose post processing, including adjustment, smoothing and downstream updates
class BgPostProcessingManager {

    // MARK: - Properties

    private struct BgReadingStateBeforeProcessing {
        let adjustedValue: NSNumber?
        let smoothedValue: NSNumber?
        let finalValue: Double
        let isSuppressedByFiveMinuteCadence: Bool
        let calculatedValueSlope: Double
        let hideSlope: Bool
    }

    private struct BgReadingDownstreamChange {
        let finalValueChanged: Bool
        let suppressionChanged: Bool

        var affectsOlderDownstreamHistory: Bool {
            return finalValueChanged || suppressionChanged
        }
    }

    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataBgReadings)
    private var lastAutomaticSmoothingTraceAt: Date?
    private var lastAutomaticSmoothingTraceSignature: String?

    private let coreDataManager: CoreDataManager
    private let bgReadingsAccessor: BgReadingsAccessor
    private let bgAdjustmentsAccessor: BgAdjustmentsAccessor
    private let treatmentEntryAccessor: TreatmentEntryAccessor
    private let bLEPeripheralAccessor: BLEPeripheralAccessor
    private let sensorsAccessor: SensorsAccessor

    private static let automaticSmoothingTraceInterval: TimeInterval = .minutes(30)

    private weak var nightscoutSyncManager: NightscoutSyncManager?
    private weak var healthKitManager: HealthKitManager?

    // MARK: - initializer

    init(coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager?, healthKitManager: HealthKitManager?) {

        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.bgAdjustmentsAccessor = BgAdjustmentsAccessor(coreDataManager: coreDataManager)
        self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
        self.bLEPeripheralAccessor = BLEPeripheralAccessor(coreDataManager: coreDataManager)
        self.sensorsAccessor = SensorsAccessor(coreDataManager: coreDataManager)
        self.nightscoutSyncManager = nightscoutSyncManager
        self.healthKitManager = healthKitManager

    }

    // MARK: - public functions

    /// reprocess the latest readings for the current source context
    ///
    /// Automatic live processing should run immediately. If post processing is
    /// active, the recent visible downstream history is rewritten straight away
    /// using the bounded automatic processing window.
    @discardableResult
    func processLatestReadings() -> Bool {
        return processBgReadings(processingStartDateOverride: nil, allowHistoricalDownstreamRewrite: true)
    }

    /// compare the resolved source context against the stored one and reset the
    /// current post processing state if the user has switched to a different source
    /// or changed the credentials and identity details behind that source
    func refreshSourceContext() {
        let sourceContextIdentifier = currentSourceContextIdentifier()
        let previousSourceContextIdentifier = UserDefaults.standard.postProcessingSourceContextIdentifier

        guard let sourceContextIdentifier = sourceContextIdentifier else {
            syncAdjustmentAvailabilityForCurrentSource()
            return
        }

        guard let previousSourceContextIdentifier = previousSourceContextIdentifier else {
            UserDefaults.standard.postProcessingSourceContextIdentifier = sourceContextIdentifier
            syncAdjustmentAvailabilityForCurrentSource()
            return
        }

        if previousSourceContextIdentifier != sourceContextIdentifier {
            if UserDefaults.standard.enableAdjustment || UserDefaults.standard.enableSmoothing {
                trace("in refreshSourceContext, resetting BG post processing because the source context changed from %{public}@ to %{public}@. BG adjustment enabled = %{public}@. Smoothing enabled = %{public}@", log: log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .info, previousSourceContextIdentifier, sourceContextIdentifier, UserDefaults.standard.enableAdjustment.description, UserDefaults.standard.enableSmoothing.description)
            }

            handleSourceContextChanged()
            UserDefaults.standard.postProcessingSourceContextIdentifier = sourceContextIdentifier
        }

        syncAdjustmentAvailabilityForCurrentSource()
    }

    /// applies adjustment and smoothing to the requested readings
    ///
    /// Automatic processing may immediately rewrite recent downstream history
    /// when post processing is active. Manual historical apply explicitly opts
    /// into a full selected-window rewrite.
    @discardableResult
    func processBgReadings(processingStartDateOverride: Date?, fiveMinuteReadingsStartTimeStampOverride: Date? = nil, forceFullDownstreamRewrite: Bool = false, allowHistoricalDownstreamRewrite: Bool = false) -> Bool {
        refreshSourceContext()

        guard let sourceContextIdentifier = currentSourceContextIdentifier() else {
            trace("in processLatestReadings, sourceContextIdentifier is nil", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .info)
            return false
        }

        let hasActivePostProcessing = hasActiveDownstreamPostProcessing()
        let isExplicitHistoricalPass = allowHistoricalDownstreamRewrite
            && (processingStartDateOverride != nil || forceFullDownstreamRewrite)

        // Automatic reading updates have nothing to recalculate when adjustment, smoothing and
        // cadence reduction are all disabled. Explicit settings changes still process their
        // requested history so disabling an existing configuration clears its stored values.
        guard hasActivePostProcessing || isExplicitHistoricalPass else { return false }

        let currentSensor = UserDefaults.standard.isMaster ? sensorsAccessor.fetchActiveSensor() : nil
        let fromDate = processingStartDate(for: processingStartDateOverride, currentSensor: currentSensor)

        // Work in ascending time order so each processing step can move forward
        // through the readings without needing to constantly look backwards. In master mode,
        // the sensor session's time window is authoritative. Do not filter by the current
        // Sensor relationship because that relationship can change during one physical session.
        let bgReadings = Array(
            bgReadingsAccessor.getLatestBgReadings(
                limit: nil,
                fromDate: fromDate,
                forSensor: nil,
                ignoreRawData: true,
                ignoreCalculatedValue: true,
                includingSuppressed: true
            ).reversed()
        )

        guard bgReadings.count > 0 else { return false }

        var statesBeforeProcessing = [NSManagedObjectID: BgReadingStateBeforeProcessing]()
        for bgReading in bgReadings {
            statesBeforeProcessing[bgReading.objectID] = BgReadingStateBeforeProcessing(
                adjustedValue: bgReading.adjustedValue,
                smoothedValue: bgReading.smoothedValue,
                finalValue: bgReading.finalValue,
                isSuppressedByFiveMinuteCadence: bgReading.isSuppressedByFiveMinuteCadence,
                calculatedValueSlope: bgReading.calculatedValueSlope,
                hideSlope: bgReading.hideSlope
            )
        }

        recomputeAdjustedValues(bgReadings: bgReadings, sourceContextIdentifier: sourceContextIdentifier)
        recomputeSmoothedValues(bgReadings: bgReadings)
        recomputeFiveMinuteCadenceSuppression(
            bgReadings: bgReadings,
            fiveMinuteReadingsStartTimeStampOverride: fiveMinuteReadingsStartTimeStampOverride,
            rebuildCadenceFromStart: fiveMinuteReadingsStartTimeStampOverride != nil
        )
        recomputeSlopes(bgReadings: bgReadings)

        let latestVisibleBgReading = bgReadings.last(where: { !$0.isSuppressedByFiveMinuteCadence })
        let automaticRewriteStartDate = latestVisibleBgReading?.timeStamp.addingTimeInterval(-ConstantsBgSmoothing.automaticDownstreamRewriteLookbackInterval)

        // Automatic processing uses the wider fetched segment as calculation context only.
        // Restore older managed objects before saving so every historical value changed in
        // Core Data belongs to the same tail that is replaced in Nightscout and HealthKit.
        if processingStartDateOverride == nil {
            let contextOnlyBgReadings = bgReadings.filter { bgReading in
                guard let automaticRewriteStartDate = automaticRewriteStartDate else { return true }
                return bgReading.timeStamp < automaticRewriteStartDate
            }

            for bgReading in contextOnlyBgReadings {
                guard let stateBeforeProcessing = statesBeforeProcessing[bgReading.objectID] else { continue }

                bgReading.adjustedValue = stateBeforeProcessing.adjustedValue
                bgReading.smoothedValue = stateBeforeProcessing.smoothedValue
                bgReading.isSuppressedByFiveMinuteCadence = stateBeforeProcessing.isSuppressedByFiveMinuteCadence
                bgReading.calculatedValueSlope = stateBeforeProcessing.calculatedValueSlope
                bgReading.hideSlope = stateBeforeProcessing.hideSlope
            }
        }

        coreDataManager.saveChanges()

        let downstreamChangesByObjectID = Dictionary(uniqueKeysWithValues: bgReadings.map { bgReading in
            let stateBeforeProcessing = statesBeforeProcessing[bgReading.objectID]
            let change = BgReadingDownstreamChange(
                finalValueChanged: stateBeforeProcessing == nil ? true : abs(stateBeforeProcessing!.finalValue - bgReading.finalValue) > 0.001,
                suppressionChanged: stateBeforeProcessing == nil ? true : stateBeforeProcessing!.isSuppressedByFiveMinuteCadence != bgReading.isSuppressedByFiveMinuteCadence
            )
            return (bgReading.objectID, change)
        })

        // Manual historical apply rewrites the full selected window.
        // Automatic live processing rewrites only the changed visible readings
        // inside the bounded recent processing window.
        let shouldRewriteFullDownstreamWindow = allowHistoricalDownstreamRewrite && (processingStartDateOverride != nil || forceFullDownstreamRewrite)
        guard allowHistoricalDownstreamRewrite else { return false }

        let bgReadingsToReplaceDownstream: [BgReading]
        if shouldRewriteFullDownstreamWindow {
            bgReadingsToReplaceDownstream = bgReadings.filter { !$0.isSuppressedByFiveMinuteCadence }
        } else if let latestVisibleBgReading = latestVisibleBgReading, let automaticRewriteStartDate = automaticRewriteStartDate {
            let automaticRewriteCandidates = bgReadings.filter { bgReading in
                return bgReading.timeStamp >= automaticRewriteStartDate
                    && bgReading.objectID != latestVisibleBgReading.objectID
                    && !bgReading.isSuppressedByFiveMinuteCadence
            }

            if UserDefaults.standard.enableSmoothing {
                // Live smoothing recomputes a recent history tail on every cycle.
                // Sending only locally changed readings can leave Nightscout and HealthKit with values
                // from an earlier smoothing pass. When smoothing is enabled,
                // rewrite the whole recent visible tail so downstream stores stay
                // aligned with the current smoothed Core Data values.
                bgReadingsToReplaceDownstream = automaticRewriteCandidates
            } else {
                bgReadingsToReplaceDownstream = automaticRewriteCandidates.filter { bgReading in
                    guard let change = downstreamChangesByObjectID[bgReading.objectID] else { return false }
                    return change.affectsOlderDownstreamHistory
                }
            }
        } else {
            bgReadingsToReplaceDownstream = []
        }
        let downstreamReadingsToReplace = bgReadingsToReplaceDownstream

        if downstreamReadingsToReplace.count > 0 {
            if shouldRewriteFullDownstreamWindow, let earliestBgReading = bgReadings.first, let latestBgReading = bgReadings.last {
                nightscoutSyncManager?.replaceBgReadingsInNightscout(bgReadings: downstreamReadingsToReplace, deleteFromTimeStamp: earliestBgReading.timeStamp, deleteToTimeStamp: latestBgReading.timeStamp)
            } else {
                nightscoutSyncManager?.replaceBgReadingsInNightscout(bgReadings: downstreamReadingsToReplace)
            }
            healthKitManager?.replaceBgReadingsInHealthKit(bgReadings: downstreamReadingsToReplace)
            return true
        }

        return false
    }

    /// reset source-specific post processing whenever the active master sensor
    /// or follower source changes
    func handleSourceContextChanged() {
        let previousTroubleshootingSettings = troubleshootingPostProcessingSettings()

        // Source-specific processing must not leak into a new master sensor session
        // or a different follower stream. Reset the entire editing state so any
        // new source starts from neutral values and disabled post processing.
        UserDefaults.standard.enableAdjustment = false
        updateSmoothingSettings(enableSmoothing: false, useFiveMinuteReadings: ConstantsBgSmoothing.defaultUseFiveMinuteReadings, smoothingPeriodInMinutes: ConstantsBgSmoothing.defaultSmoothingPeriodInMinutes, smoothingStrength: ConstantsBgSmoothing.defaultSmoothingStrength, smoothingAlgorithm: ConstantsBgSmoothing.defaultSmoothingAlgorithm)
        UserDefaults.standard.fiveMinuteReadingsStartTimeStamp = nil
        UserDefaults.standard.postProcessingStartTimeStamp = sourceHistoryStartTimeStamp()
        UserDefaults.standard.postProcessingApplyFromTimeStamp = UserDefaults.standard.postProcessingStartTimeStamp
        UserDefaults.standard.postProcessingSourceContextIdentifier = nil

        let currentTroubleshootingSettings = troubleshootingPostProcessingSettings()
        if previousTroubleshootingSettings != currentTroubleshootingSettings {
            traceTroubleshootingPostProcessingSettings(currentTroubleshootingSettings)
        }
    }

    private func sourceHistoryStartTimeStamp() -> Date {
        if UserDefaults.standard.isMaster, let activeSensor = sensorsAccessor.fetchActiveSensor() {
            return activeSensor.startDate
        }

        return bgReadingsAccessor.getLatestBgReadings(limit: 1, fromDate: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: true, includingSuppressed: true).first?.timeStamp ?? Date()
    }

    func latestActiveBgAdjustment() -> BgAdjustment? {
        guard let sourceContextIdentifier = currentSourceContextIdentifier() else { return nil }

        if let latestBgReading = latestBgReadingForCurrentSourceContext() {
            return bgAdjustmentsAccessor.latestApplicableBgAdjustment(forSourceContextIdentifier: sourceContextIdentifier, readingTimeStamp: latestBgReading.timeStamp, on: coreDataManager.mainManagedObjectContext)
        }

        return bgAdjustmentsAccessor.latestActiveBgAdjustment(forSourceContextIdentifier: sourceContextIdentifier, on: coreDataManager.mainManagedObjectContext)
    }

    /// Builds the one consumer-safe snapshot used for every post-processing Activity Log row.
    ///
    /// Only bounded settings cross this boundary. The user's entered comparison glucose, source
    /// glucose, Core Data identifiers and the verbose developer description are intentionally not
    /// represented by `TroubleshootingPostProcessingSettings` and therefore cannot be shared.
    private func troubleshootingPostProcessingSettings(
        applyRange: TroubleshootingPostProcessingApplyRange? = nil
    ) -> TroubleshootingPostProcessingSettings {
        let defaults = UserDefaults.standard
        let activeAdjustment = defaults.enableAdjustment ? latestActiveBgAdjustment() : nil
        let adjustmentShape = activeAdjustment
            .flatMap { BgAdjustmentShapeType(rawValue: $0.adjustmentShapeType) }
            ?? ConstantsBgAdjustment.defaultShapeType
        let fiveMinuteReadings: TroubleshootingFiveMinuteReadingsMode
        if !currentSourceCanUseFiveMinuteReadings() {
            fiveMinuteReadings = .notApplicable
        } else {
            fiveMinuteReadings = defaults.useFiveMinuteReadings ? .enabled : .disabled
        }

        return TroubleshootingPostProcessingSettings(
            adjustmentEnabled: defaults.enableAdjustment && activeAdjustment != nil,
            adjustmentSlope: activeAdjustment?.slope,
            adjustmentIntercept: activeAdjustment?.intercept,
            adjustmentEmphasis: TroubleshootingAdjustmentEmphasis(adjustmentShape),
            smoothingEnabled: defaults.enableSmoothing,
            smoothingAlgorithm: TroubleshootingSmoothingAlgorithm(defaults.bgSmoothingAlgorithm),
            smoothingPeriodMinutes: defaults.bgSmoothingPeriodInMinutes,
            smoothingStrength: defaults.bgSmoothingStrength,
            fiveMinuteReadings: fiveMinuteReadings,
            applyRange: applyRange
        )
    }

    /// Sends the complete state through the normal trace bridge so developer and consumer logging
    /// retain one call path while still keeping their payloads strictly separate.
    private func traceTroubleshootingPostProcessingSettings(
        _ settings: TroubleshootingPostProcessingSettings
    ) {
        trace(
            "post-processing settings applied",
            log: log,
            category: ConstantsLog.categoryApplicationDataBgReadings,
            type: .info,
            troubleshooting: .standard(.configuration(.postProcessingSettings(settings)))
        )
    }

    /// store the current smoothing settings and immediately reprocess the latest readings
    func updateSmoothing(enableSmoothing: Bool, useFiveMinuteReadings: Bool, smoothingPeriodInMinutes: Int, smoothingStrength: Int, smoothingAlgorithm: BgSmoothingAlgorithm = UserDefaults.standard.bgSmoothingAlgorithm) {
        let previousTroubleshootingSettings = troubleshootingPostProcessingSettings()
        if UserDefaults.standard.useFiveMinuteReadings != useFiveMinuteReadings {
            UserDefaults.standard.fiveMinuteReadingsStartTimeStamp = latestBgReadingForCurrentSourceContext()?.timeStamp ?? Date()
        }

        updateSmoothingSettings(enableSmoothing: enableSmoothing, useFiveMinuteReadings: useFiveMinuteReadings, smoothingPeriodInMinutes: smoothingPeriodInMinutes, smoothingStrength: smoothingStrength, smoothingAlgorithm: smoothingAlgorithm)
        let currentTroubleshootingSettings = troubleshootingPostProcessingSettings()
        if previousTroubleshootingSettings != currentTroubleshootingSettings {
            traceTroubleshootingPostProcessingSettings(currentTroubleshootingSettings)
        }
        let rewriteStartDate = UserDefaults.standard.postProcessingApplyFromTimeStamp ?? UserDefaults.standard.postProcessingStartTimeStamp
        _ = processBgReadings(processingStartDateOverride: rewriteStartDate, fiveMinuteReadingsStartTimeStampOverride: rewriteStartDate, allowHistoricalDownstreamRewrite: true)
        notifyBgPostProcessingDidUpdate()
    }

    func applyPostProcessing(enableAdjustment: Bool, slope: Double?, intercept: Double?, adjustmentShapeType: BgAdjustmentShapeType, applyFromTimeStamp: Date, isBasicAdjustment: Bool, enteredBgValue: Double?, sourceCalculatedValue: Double?, enableSmoothing: Bool, useFiveMinuteReadings: Bool, smoothingPeriodInMinutes: Int, smoothingStrength: Int, smoothingAlgorithm: BgSmoothingAlgorithm = UserDefaults.standard.bgSmoothingAlgorithm, processingStartDateOverride: Date? = nil, troubleshootingApplyRange: TroubleshootingPostProcessingApplyRange = .now) {
        trace("%{public}@", log: log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .info, applyPostProcessingDescription(enableAdjustment: enableAdjustment, slope: slope, intercept: intercept, adjustmentShapeType: adjustmentShapeType, applyFromTimeStamp: applyFromTimeStamp, enteredBgValue: enteredBgValue, sourceCalculatedValue: sourceCalculatedValue, enableSmoothing: enableSmoothing, useFiveMinuteReadings: useFiveMinuteReadings, smoothingStrength: smoothingStrength, smoothingAlgorithm: smoothingAlgorithm, processingStartDateOverride: processingStartDateOverride))

        if enableAdjustment, let slope = slope, let intercept = intercept {
            createAdjustment(slope: slope, intercept: intercept, adjustmentShapeType: adjustmentShapeType, applyFromTimeStamp: applyFromTimeStamp, isBasicAdjustment: isBasicAdjustment, enteredBgValue: enteredBgValue, sourceCalculatedValue: sourceCalculatedValue)
        } else {
            disableCurrentAdjustment()
        }

        if UserDefaults.standard.useFiveMinuteReadings != useFiveMinuteReadings {
            UserDefaults.standard.fiveMinuteReadingsStartTimeStamp = applyFromTimeStamp
        }

        // After "Apply from Now", the next automatic processing pass must not start
        // from the older source start timestamp and reach back into historical
        // readings. Keep the source history boundary unchanged, but store the
        // active apply-from timestamp separately so future live cycles only
        // reprocess the intended range.
        UserDefaults.standard.postProcessingApplyFromTimeStamp = applyFromTimeStamp

        updateSmoothingSettings(enableSmoothing: enableSmoothing, useFiveMinuteReadings: useFiveMinuteReadings, smoothingPeriodInMinutes: smoothingPeriodInMinutes, smoothingStrength: smoothingStrength, smoothingAlgorithm: smoothingAlgorithm)

        // Treat Apply as one user action. The Activity Log receives the complete resulting state,
        // never three inferred statements about which individual toggles the user did or did not
        // touch. The semantic range comes directly from the selected UI option, so delayed follower
        // readings cannot turn "3 hours ago" into an inaccurate timestamp-derived estimate.
        traceTroubleshootingPostProcessingSettings(
            troubleshootingPostProcessingSettings(applyRange: troubleshootingApplyRange)
        )

        let rewriteStartDate = processingStartDateOverride ?? applyFromTimeStamp
        _ = processBgReadings(processingStartDateOverride: rewriteStartDate, fiveMinuteReadingsStartTimeStampOverride: rewriteStartDate, allowHistoricalDownstreamRewrite: true)
        replacePostProcessingNote(enableAdjustment: enableAdjustment, slope: slope, intercept: intercept, adjustmentShapeType: adjustmentShapeType, applyFromTimeStamp: applyFromTimeStamp, enableSmoothing: enableSmoothing, useFiveMinuteReadings: useFiveMinuteReadings, smoothingStrength: smoothingStrength, noteWindowStartDate: rewriteStartDate)

        notifyBgPostProcessingDidUpdate()
    }

    func currentSourceDescriptionForPostProcessing() -> String? {
        return currentSourceDescription()
    }

    func currentSensorForPostProcessing() -> Sensor? {
        return UserDefaults.standard.isMaster ? sensorsAccessor.fetchActiveSensor() : nil
    }

    /// smoothing can be enabled for every source, but BG adjustment should stay
    /// disabled when the current master source already has its own calibration flow
    func shouldAllowBgAdjustmentForCurrentSource() -> Bool {
        return adjustmentDisabledReasonForCurrentSource() == nil
    }

    /// return a footer message for the adjustment section when the current source
    /// should not allow offset and scale editing
    func bgAdjustmentDisabledMessageForCurrentSource() -> String? {
        guard let adjustmentDisabledReason = adjustmentDisabledReasonForCurrentSource() else { return nil }

        switch adjustmentDisabledReason {
        case .masterLibreUsesCalibration:
            return Texts_HomeView.postProcessingAdjustmentDisabledUseNativeAlgorithm
        case .masterDexcomG6UsesCalibration:
            return Texts_HomeView.postProcessingAdjustmentDisabledBecauseSensorIsCalibrated
        }
    }

    func shouldAllowNightscoutBgPostProcessingWrites() -> Bool {
        return nightscoutSyncManager?.shouldAllowNightscoutBgPostProcessingWrites() ?? false
    }

    private func replacePostProcessingNote(enableAdjustment: Bool, slope: Double?, intercept: Double?, adjustmentShapeType: BgAdjustmentShapeType, applyFromTimeStamp: Date, enableSmoothing: Bool, useFiveMinuteReadings: Bool, smoothingStrength: Int, noteWindowStartDate: Date) {
        let appliedAtTimeStamp = Date()
        let noteWindowEndDate = appliedAtTimeStamp
        let appName = ConstantsHomeView.applicationName
        var notesToDelete = [TreatmentEntry]()
        var noteToUpload: TreatmentEntry?

        coreDataManager.mainManagedObjectContext.performAndWait {
            let existingNotes = treatmentEntryAccessor.getTreatments(fromDate: noteWindowStartDate, toDate: noteWindowEndDate, on: coreDataManager.mainManagedObjectContext).filter { treatmentEntry in
                !treatmentEntry.treatmentdeleted
                    && treatmentEntry.treatmentType == .Note
                    && treatmentEntry.enteredBy == appName
                    && (treatmentEntry.notes?.hasPrefix(ConstantsNightscout.postProcessingNotePrefix) ?? false)
            }

            for existingNote in existingNotes {
                existingNote.treatmentdeleted = true
                existingNote.uploaded = false
            }

            let noteBody = postProcessingNoteText(enableAdjustment: enableAdjustment, slope: slope, intercept: intercept, adjustmentShapeType: adjustmentShapeType, appliedAtTimeStamp: appliedAtTimeStamp, enableSmoothing: enableSmoothing, useFiveMinuteReadings: useFiveMinuteReadings, smoothingStrength: smoothingStrength, smoothingAlgorithm: UserDefaults.standard.bgSmoothingAlgorithm)
            let newNote = TreatmentEntry(date: applyFromTimeStamp, value: 0, treatmentType: .Note, nightscoutEventType: ConstantsNightscout.noteEventType, enteredBy: appName, notes: noteBody, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

            notesToDelete = existingNotes
            noteToUpload = newNote

            coreDataManager.saveChanges()
        }

        if let noteToUpload = noteToUpload {
            nightscoutSyncManager?.replacePostProcessingNotesInNightscout(notesToDelete: notesToDelete, noteToUpload: noteToUpload)
        }
    }

    private func postProcessingNoteText(enableAdjustment: Bool, slope: Double?, intercept: Double?, adjustmentShapeType: BgAdjustmentShapeType, appliedAtTimeStamp: Date, enableSmoothing: Bool, useFiveMinuteReadings: Bool, smoothingStrength: Int, smoothingAlgorithm: BgSmoothingAlgorithm) -> String {
        var noteComponents = [String]()

        noteComponents.append(ConstantsNightscout.postProcessingNotePrefix)

        if enableAdjustment, let slope = slope, let intercept = intercept {
            noteComponents.append("Adjustment: offset \(intercept.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes), scale \(slope.round(toDecimalPlaces: 2).stringWithoutTrailingZeroes), emphasis \(adjustmentShapeType.description). " + smoothingNoteText(enableSmoothing: enableSmoothing, smoothingStrength: smoothingStrength, smoothingAlgorithm: smoothingAlgorithm, useFiveMinuteReadings: useFiveMinuteReadings))
        } else {
            noteComponents.append("Adjustment: disabled. " + smoothingNoteText(enableSmoothing: enableSmoothing, smoothingStrength: smoothingStrength, smoothingAlgorithm: smoothingAlgorithm, useFiveMinuteReadings: useFiveMinuteReadings))
        }

        noteComponents.append("Applied at \(appliedAtTimeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .short)).")

        return noteComponents.joined(separator: "\n")
    }

    private func smoothingNoteText(enableSmoothing: Bool, smoothingStrength: Int, smoothingAlgorithm: BgSmoothingAlgorithm, useFiveMinuteReadings: Bool) -> String {
        var noteText = enableSmoothing ? "Smoothing: \(smoothingAlgorithm.description), \(smoothingStrengthDescription(smoothingStrength))." : "Smoothing: disabled."

        if useFiveMinuteReadings {
            noteText += " 5-minute readings: enabled."
        }

        return noteText
    }

    /// Returns whether the current source has an effective downstream change to apply.
    ///
    /// Stored flags can remain true after an offset, smoothing or cadence reduction stops being
    /// effective. Checking the effective state prevents suppression of normal Nightscout uploads.
    func hasActiveDownstreamPostProcessing() -> Bool {
        if hasEffectiveAdjustmentForCurrentSource() {
            return true
        }

        if UserDefaults.standard.enableSmoothing {
            return true
        }

        if UserDefaults.standard.useFiveMinuteReadings && currentSourceCanUseFiveMinuteReadings() {
            return true
        }

        return false
    }

    /// 5 minute reduction only makes sense when the source normally produces
    /// readings faster than 5 minutes. Use the median interval so one duplicate,
    /// backfill value or missed reading does not enable the option by itself.
    func sourceCanUseFiveMinuteReadings(readingDates: [Date]) -> Bool {
        guard let medianReadingGapInMinutes = medianReadingGapInMinutes(readingDates: readingDates) else { return false }

        return medianReadingGapInMinutes < ConstantsBgSmoothing.fiveMinuteCadenceMinimumTimeBetweenReadingsInMinutes
    }
    
    /// preview uses the same cadence reduction path as stored processing so the
    /// user can see which readings would stay visible downstream
    func visibleReadingIndexesAfterApplyingFiveMinuteCadence(readingDates: [Date], enableFiveMinuteReadings: Bool) -> [Int] {
        if !enableFiveMinuteReadings {
            return Array(readingDates.indices)
        }

        var visibleReadingIndexes = [Int]()
        let readingGroups = contiguousReadingIndexGroups(readingDates: readingDates)
        let minimumTimeBetweenVisibleReadingsInSeconds = ConstantsBgSmoothing.fiveMinuteCadenceMinimumTimeBetweenReadingsInMinutes * 60.0

        for readingGroup in readingGroups {
            var latestVisibleReadingTimeStamp: Date?

            for readingIndex in readingGroup {
                let readingDate = readingDates[readingIndex]

                if let latestVisibleReadingTimeStamp = latestVisibleReadingTimeStamp, readingDate.timeIntervalSince(latestVisibleReadingTimeStamp) < minimumTimeBetweenVisibleReadingsInSeconds {
                    continue
                }

                visibleReadingIndexes.append(readingIndex)
                latestVisibleReadingTimeStamp = readingDate
            }
        }

        return visibleReadingIndexes
    }

    // MARK: - private functions

    private func applyPostProcessingDescription(enableAdjustment: Bool, slope: Double?, intercept: Double?, adjustmentShapeType: BgAdjustmentShapeType, applyFromTimeStamp: Date, enteredBgValue: Double?, sourceCalculatedValue: Double?, enableSmoothing: Bool, useFiveMinuteReadings: Bool, smoothingStrength: Int, smoothingAlgorithm: BgSmoothingAlgorithm, processingStartDateOverride: Date?) -> String {
        var description = "in applyPostProcessing, user has chosen to apply from " + applyFromDescription(applyFromTimeStamp: applyFromTimeStamp, processingStartDateOverride: processingStartDateOverride) + "."

        if enableAdjustment, let intercept = intercept {
            description += " BG adjustment enabled."
            description += " Offset set to " + formattedBgDeltaValue(intercept)

            if let sourceCalculatedValue = sourceCalculatedValue, let enteredBgValue = enteredBgValue {
                description += " (source glucose = " + formattedBgValue(sourceCalculatedValue) + ", adjusted glucose = " + formattedBgValue(enteredBgValue) + ")."
            } else {
                description += "."
            }
        } else {
            description += " BG adjustment not enabled."
        }

        if enableAdjustment, let slope = slope, abs(slope - 1.0) > 0.0001 {
            description += " Scale set to " + String(format: "%.2f", slope) + " with " + adjustmentShapeType.description.lowercased() + " emphasis."
        } else {
            description += " Scale is not applied."
        }

        if enableSmoothing {
            description += " Smoothing applied with " + smoothingAlgorithm.description + " using " + smoothingStrengthDescription(smoothingStrength).lowercased() + " strength."
        } else {
            description += " Smoothing is not enabled."
        }

        if enableSmoothing && useFiveMinuteReadings {
            description += " 5-minute readings enabled."
        } else {
            description += " 5-minute readings not enabled."
        }

        return description
    }

    private func applyFromDescription(applyFromTimeStamp: Date, processingStartDateOverride: Date?) -> String {
        guard let processingStartDateOverride = processingStartDateOverride else {
            return "now"
        }

        if let latestBgReading = latestBgReadingForCurrentSourceContext() {
            let hoursToApply = Int(round(abs(latestBgReading.timeStamp.timeIntervalSince(processingStartDateOverride)) / 3600.0))

            if hoursToApply > 0 {
                return "-" + hoursToApply.description + "h"
            }
        }

        return processingStartDateOverride == applyFromTimeStamp ? "now" : processingStartDateOverride.toStringForTrace(timeStyle: .short, dateStyle: .short)
    }

    private func smoothingStrengthDescription(_ smoothingStrength: Int) -> String {
        switch smoothingStrength {
        case 0:
            return Texts_HomeView.postProcessingLight
        case 1:
            return Texts_HomeView.postProcessingMedium
        case 2:
            return Texts_HomeView.postProcessingStrong
        default:
            return smoothingStrength.description
        }
    }

    private func formattedBgValue(_ valueInMgDl: Double) -> String {
        let unitString = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
        let valueInUserUnit = valueInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

        return valueInUserUnit.bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + " " + unitString
    }

    private func formattedBgDeltaValue(_ valueInMgDl: Double) -> String {
        let unitString = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
        let valueInUserUnit = valueInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        let prefix = valueInUserUnit > 0 ? "+" : valueInUserUnit < 0 ? "-" : ""
        let absoluteValueString = abs(valueInUserUnit).bgValueToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

        return prefix + absoluteValueString + " " + unitString
    }

    private func processingStartDate(for processingStartDateOverride: Date?, currentSensor: Sensor?) -> Date? {
        if let processingStartDateOverride = processingStartDateOverride {
            return startDateClampedToCurrentSensorSession(processingStartDateOverride, currentSensor: currentSensor)
        }

        let configuredStartDate = UserDefaults.standard.postProcessingApplyFromTimeStamp ?? UserDefaults.standard.postProcessingStartTimeStamp
        let sourceWindowStartDate = startDateClampedToCurrentSensorSession(configuredStartDate, currentSensor: currentSensor)

        guard let latestBgReading = bgReadingsAccessor.getLatestBgReadings(
            limit: 1,
            fromDate: sourceWindowStartDate,
            forSensor: nil,
            ignoreRawData: true,
            ignoreCalculatedValue: true,
            includingSuppressed: true
        ).first else {
            return sourceWindowStartDate
        }

        let boundedAutomaticStartDate = latestBgReading.timeStamp.addingTimeInterval(-ConstantsBgSmoothing.automaticProcessingLookbackInterval)

        if let sourceWindowStartDate = sourceWindowStartDate {
            return max(sourceWindowStartDate, boundedAutomaticStartDate)
        }

        return boundedAutomaticStartDate
    }

    private func startDateClampedToCurrentSensorSession(_ requestedStartDate: Date?, currentSensor: Sensor?) -> Date? {
        guard UserDefaults.standard.isMaster, let currentSensor = currentSensor else {
            return requestedStartDate
        }

        guard let requestedStartDate = requestedStartDate else {
            return currentSensor.startDate
        }

        return max(requestedStartDate, currentSensor.startDate)
    }

    private func recomputeAdjustedValues(bgReadings: [BgReading], sourceContextIdentifier: String) {
        if !UserDefaults.standard.enableAdjustment || !shouldAllowBgAdjustmentForCurrentSource() {
            for bgReading in bgReadings {
                bgReading.adjustedValue = nil
            }

            return
        }

        let bgAdjustments = bgAdjustmentsAccessor.getBgAdjustments(forSourceContextIdentifier: sourceContextIdentifier, on: coreDataManager.mainManagedObjectContext).filter({ $0.isEnabled })

        if bgAdjustments.count == 0 {
            for bgReading in bgReadings {
                bgReading.adjustedValue = nil
            }

            return
        }

        var bgAdjustmentIndex = 0
        var currentBgAdjustment = bgAdjustments.first

        for bgReading in bgReadings {
            // Move to the newest adjustment whose applyFromTimeStamp is now in scope
            // for this reading. This lets one historical rewrite contain multiple
            // adjustment segments without repeatedly scanning the whole array.
            while bgAdjustmentIndex + 1 < bgAdjustments.count && bgAdjustments[bgAdjustmentIndex + 1].applyFromTimeStamp <= bgReading.timeStamp {
                bgAdjustmentIndex += 1
                currentBgAdjustment = bgAdjustments[bgAdjustmentIndex]
            }

            guard let bgAdjustment = currentBgAdjustment, bgAdjustment.applyFromTimeStamp <= bgReading.timeStamp else {
                bgReading.adjustedValue = nil
                continue
            }

            let scaleCenterInMgDl = BgAdjustmentShapeType(rawValue: bgAdjustment.adjustmentShapeType)?.scaleCenterInMgDl ?? ConstantsBgAdjustment.defaultShapeType.scaleCenterInMgDl
            let adjustedValue = scaleCenterInMgDl + bgAdjustment.slope * (bgReading.calculatedValue - scaleCenterInMgDl) + bgAdjustment.intercept
            bgReading.adjustedValue = NSNumber(value: adjustedValue)
        }
    }

    private func createAdjustment(slope: Double, intercept: Double, adjustmentShapeType: BgAdjustmentShapeType, applyFromTimeStamp: Date, isBasicAdjustment: Bool, enteredBgValue: Double?, sourceCalculatedValue: Double?) {
        guard shouldAllowBgAdjustmentForCurrentSource() else {
            disableCurrentAdjustment()
            return
        }

        guard let sourceContextIdentifier = currentSourceContextIdentifier() else { return }

        bgAdjustmentsAccessor.disableBgAdjustments(forSourceContextIdentifier: sourceContextIdentifier, fromApplyFromTimeStamp: applyFromTimeStamp, on: coreDataManager.mainManagedObjectContext)

        _ = bgAdjustmentsAccessor.createBgAdjustment(timeStamp: Date(), applyFromTimeStamp: applyFromTimeStamp, slope: slope, intercept: intercept, adjustmentShapeType: adjustmentShapeType.rawValue, isEnabled: true, isBasicAdjustment: isBasicAdjustment, enteredBgValue: enteredBgValue, sourceCalculatedValue: sourceCalculatedValue, sourceDescription: currentSourceDescription(), sourceContextIdentifier: sourceContextIdentifier, on: coreDataManager.mainManagedObjectContext)

        coreDataManager.saveChanges()

        UserDefaults.standard.enableAdjustment = true
    }

    private func disableCurrentAdjustment() {
        guard let sourceContextIdentifier = currentSourceContextIdentifier() else {
            UserDefaults.standard.enableAdjustment = false
            return
        }

        if let latestBgAdjustment = bgAdjustmentsAccessor.latestActiveBgAdjustment(forSourceContextIdentifier: sourceContextIdentifier, on: coreDataManager.mainManagedObjectContext) {
            bgAdjustmentsAccessor.disable(bgAdjustment: latestBgAdjustment, on: coreDataManager.mainManagedObjectContext)
            coreDataManager.saveChanges()
        }

        UserDefaults.standard.enableAdjustment = false
    }

    private func updateSmoothingSettings(enableSmoothing: Bool, useFiveMinuteReadings: Bool, smoothingPeriodInMinutes: Int, smoothingStrength: Int, smoothingAlgorithm: BgSmoothingAlgorithm) {
        UserDefaults.standard.enableSmoothing = enableSmoothing
        UserDefaults.standard.useFiveMinuteReadings = useFiveMinuteReadings
        UserDefaults.standard.bgSmoothingPeriodInMinutes = smoothingPeriodInMinutes
        UserDefaults.standard.bgSmoothingStrength = smoothingStrength
        UserDefaults.standard.bgSmoothingAlgorithm = smoothingAlgorithm
    }

    private func recomputeSmoothedValues(bgReadings: [BgReading]) {
        if !UserDefaults.standard.enableSmoothing {
            for bgReading in bgReadings {
                bgReading.smoothedValue = nil
            }

            return
        }

        // Preview and stored live values can diverge if they use different smoothing windows. Recompute the
        // full fetched processing segment here so every automatic and historical
        // pass uses the same smoothing scope.
        let readingsToSmooth = bgReadings

        for bgReading in readingsToSmooth {
            bgReading.smoothedValue = nil
        }

        traceAutomaticSmoothingConfigurationIfNeeded(bgReadings: readingsToSmooth)

        let inputValues = readingsToSmooth.map { valueToSmooth(bgReading: $0) }
        let smoothedValues = smoothedValuesSeparatedByReadingGap(values: inputValues, readingDates: readingsToSmooth.map { $0.timeStamp }, smoothingStrength: UserDefaults.standard.bgSmoothingStrength)

        for readingIndex in 0..<readingsToSmooth.count {
            readingsToSmooth[readingIndex].smoothedValue = NSNumber(value: smoothedValues[readingIndex])
        }
    }

    /// Keep all source readings in Core Data, but suppress the extra visible points
    /// when the user has chosen to reduce a faster CGM stream down to 5 minute output.
    /// This way the original values are still available for overlays, reprocessing and
    /// debugging while normal downstream consumers only see the reduced cadence stream.
    private func recomputeFiveMinuteCadenceSuppression(bgReadings: [BgReading], fiveMinuteReadingsStartTimeStampOverride: Date?, rebuildCadenceFromStart: Bool) {
        let sourceStartTimeStamp = UserDefaults.standard.postProcessingStartTimeStamp ?? .distantPast
        let fiveMinuteReadingsStartTimeStamp = fiveMinuteReadingsStartTimeStampOverride ?? UserDefaults.standard.fiveMinuteReadingsStartTimeStamp ?? sourceStartTimeStamp

        if !UserDefaults.standard.useFiveMinuteReadings {
            // Five minute output remains an independent downstream option when smoothing is disabled.
            // Only an explicit settings change may reveal readings again. Automatic processing uses a
            // rolling window and must not progressively clear suppression as that window advances.
            if rebuildCadenceFromStart {
                clearFiveMinuteCadenceSuppression(bgReadings: bgReadings, from: fiveMinuteReadingsStartTimeStamp)
            }

            return
        }

        // Cadence detection only sees the fetched processing slice. A rolling slice can eventually
        // contain only five-minute points even when older one-minute points were deliberately hidden.
        // Preserve those stored decisions instead of treating them as stale and revealing history.
        guard sourceCanUseFiveMinuteReadings(bgReadings: bgReadings) else { return }

        let readingGroups = contiguousReadingIndexGroups(readingDates: bgReadings.map { $0.timeStamp })
        let minimumTimeBetweenVisibleReadingsInSeconds = ConstantsBgSmoothing.fiveMinuteCadenceMinimumTimeBetweenReadingsInMinutes * 60.0

        for readingGroup in readingGroups {
            var latestVisibleReadingTimeStamp: Date?

            for readingIndex in readingGroup {
                let bgReading = bgReadings[readingIndex]

                if bgReading.timeStamp < fiveMinuteReadingsStartTimeStamp {
                    if !bgReading.isSuppressedByFiveMinuteCadence {
                        latestVisibleReadingTimeStamp = bgReading.timeStamp
                    }

                    continue
                }

                if let existingLatestVisibleReadingTimeStamp = latestVisibleReadingTimeStamp {
                    if bgReading.timeStamp.timeIntervalSince(existingLatestVisibleReadingTimeStamp) < minimumTimeBetweenVisibleReadingsInSeconds {
                        bgReading.isSuppressedByFiveMinuteCadence = true
                    } else {
                        bgReading.isSuppressedByFiveMinuteCadence = false
                        latestVisibleReadingTimeStamp = bgReading.timeStamp
                    }
                } else if rebuildCadenceFromStart || !bgReading.isSuppressedByFiveMinuteCadence {
                    // An explicit apply owns the whole selected range and establishes a new anchor.
                    // An automatic rolling pass must retain leading suppressed readings until it
                    // reaches the first previously visible anchor inside the fetched slice.
                    bgReading.isSuppressedByFiveMinuteCadence = false
                    latestVisibleReadingTimeStamp = bgReading.timeStamp
                }
            }
        }
    }

    private func clearFiveMinuteCadenceSuppression(bgReadings: [BgReading], from startTimeStamp: Date) {
        for bgReading in bgReadings {
            guard bgReading.timeStamp >= startTimeStamp else { continue }

            bgReading.isSuppressedByFiveMinuteCadence = false
        }
    }

    private func sourceCanUseFiveMinuteReadings(bgReadings: [BgReading]) -> Bool {
        return sourceCanUseFiveMinuteReadings(readingDates: bgReadings.map { $0.timeStamp })
    }

    private func medianReadingGapInMinutes(readingDates: [Date]) -> Double? {
        let readingGapsInMinutes = readingGapsInMinutesForCadenceDetection(readingDates: readingDates)

        guard readingGapsInMinutes.count > 0 else { return nil }

        let sortedReadingGapsInMinutes = readingGapsInMinutes.sorted()
        let middleIndex = sortedReadingGapsInMinutes.count / 2

        if sortedReadingGapsInMinutes.count.isMultiple(of: 2) {
            return (sortedReadingGapsInMinutes[middleIndex - 1] + sortedReadingGapsInMinutes[middleIndex]) / 2.0
        }

        return sortedReadingGapsInMinutes[middleIndex]
    }

    private func readingGapsInMinutesForCadenceDetection(readingDates: [Date]) -> [Double] {
        guard readingDates.count > 1 else { return [] }

        var readingGapsInMinutes = [Double]()

        for readingIndex in 1..<readingDates.count {
            let readingGapInMinutes = readingDates[readingIndex].timeIntervalSince(readingDates[readingIndex - 1]) / 60.0

            if readingGapInMinutes > 0 && readingGapInMinutes <= Double(ConstantsBgSmoothing.maximumGapBetweenReadingsInMinutes) {
                readingGapsInMinutes.append(readingGapInMinutes)
            }
        }

        return readingGapsInMinutes
    }

    private func recomputeSlopes(bgReadings: [BgReading]) {
        var lastVisibleBgReading: BgReading?

        for bgReading in bgReadings {
            if bgReading.isSuppressedByFiveMinuteCadence {
                bgReading.calculatedValueSlope = 0.0
                bgReading.hideSlope = true
                continue
            }

            if let lastVisibleBgReading = lastVisibleBgReading {
                let (calculatedValueSlope, hideSlope) = bgReading.calculateSlope(lastBgReading: lastVisibleBgReading)
                bgReading.calculatedValueSlope = calculatedValueSlope
                bgReading.hideSlope = hideSlope
            } else {
                bgReading.calculatedValueSlope = 0.0
                bgReading.hideSlope = true
            }

            lastVisibleBgReading = bgReading
        }
    }

    /// preview smoothing uses the same grouped path as stored processing so
    /// the chart always mirrors the values that would actually be written
    func smoothedValuesSeparatedByReadingGap(values: [Double], readingDates: [Date], smoothingStrength: Int, smoothingAlgorithm: BgSmoothingAlgorithm = UserDefaults.standard.bgSmoothingAlgorithm) -> [Double] {
        guard values.count == readingDates.count else { return values }
        guard values.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { return values }

        var groupedSmoothedValues = values

        // A long gap marks the start of a new glucose segment.
        // This avoids the unpredictable edge behaviour seen in testing where a
        // reading such as 110 mg/dL before a long gap was being pulled toward
        // the first high reading after it.
        for contiguousReadingIndexes in contiguousReadingIndexGroups(readingDates: readingDates) {
            guard contiguousReadingIndexes.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { continue }

            let contiguousValues = contiguousReadingIndexes.map { values[$0] }
            let contiguousReadingDates = contiguousReadingIndexes.map { readingDates[$0] }
            let smoothedValues = smoothingAlgorithm.plugin.smoothedValues(values: contiguousValues, readingDates: contiguousReadingDates, smoothingStrength: smoothingStrength, support: smoothingSupport())

            for (segmentIndex, readingIndex) in contiguousReadingIndexes.enumerated() {
                groupedSmoothedValues[readingIndex] = smoothedValues[segmentIndex]
            }
        }

        return groupedSmoothedValues
    }

    private func traceAutomaticSmoothingConfigurationIfNeeded(bgReadings: [BgReading]) {
        guard bgReadings.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { return }

        let smoothingAlgorithm = UserDefaults.standard.bgSmoothingAlgorithm
        let smoothingStrength = UserDefaults.standard.bgSmoothingStrength
        let isFastCadence = sourceCanUseFiveMinuteReadings(readingDates: bgReadings.map { $0.timeStamp })
        let traceSignature = [
            smoothingAlgorithm.rawValue,
            String(smoothingStrength),
            isFastCadence.description,
            UserDefaults.standard.useFiveMinuteReadings.description
        ].joined(separator: "|")
        let now = Date()
        let shouldTraceBecauseConfigurationChanged = traceSignature != lastAutomaticSmoothingTraceSignature
        let shouldTraceBecauseIntervalElapsed = lastAutomaticSmoothingTraceAt.map {
            now.timeIntervalSince($0) >= Self.automaticSmoothingTraceInterval
        } ?? true

        guard shouldTraceBecauseConfigurationChanged || shouldTraceBecauseIntervalElapsed else { return }

        trace(
            "in recomputeSmoothedValues, automatic smoothing active. algorithm = %{public}@, strength = %{public}@, fast cadence = %{public}@, 5-minute readings = %{public}@, readings = %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataBgReadings,
            type: .info,
            smoothingAlgorithm.description,
            smoothingStrengthDescription(smoothingStrength),
            isFastCadence.description,
            UserDefaults.standard.useFiveMinuteReadings.description,
            bgReadings.count.description
        )

        lastAutomaticSmoothingTraceAt = now
        lastAutomaticSmoothingTraceSignature = traceSignature
    }

    private func fastCadenceSmoothedValues(values: [Double], readingDates: [Date], smoothingStrength: Int) -> [Double] {
        guard values.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { return values }
        guard let medianReadingGapInMinutes = medianReadingGapInMinutes(readingDates: readingDates), medianReadingGapInMinutes > 0 else {
            return savitzkyGolaySmoothedValues(values: values, smoothingStrength: smoothingStrength)
        }

        // Minute-cadence Libre values need two smoothing stages: first on the minute stream, then on
        // points spaced roughly five minutes apart. This ensures faster streams
        // still get meaningful smoothing inside the shared manager.
        let readingsPerFiveMinutes = max(2, Int((5.0 / medianReadingGapInMinutes).rounded()))
        var fullySmoothedValues = values

        for _ in 0..<ConstantsBgSmoothing.fastCadenceNativeRepeatCount {
            fullySmoothedValues = savitzkyGolayFilteredValues(values: fullySmoothedValues, filterWidth: ConstantsBgSmoothing.fastCadenceNativeFilterWidth)
        }

        fullySmoothedValues = sparseCadenceSmoothedValues(values: fullySmoothedValues, readingsPerVisibleStep: readingsPerFiveMinutes, filterWidth: ConstantsBgSmoothing.fastCadenceFiveMinuteFilterWidth, iterations: ConstantsBgSmoothing.fastCadenceFiveMinuteRepeatCount)

        let blendWeight = ConstantsBgSmoothing.fastCadenceBlendWeight(forSmoothingStrength: smoothingStrength)
        let blendedValues = zip(values, fullySmoothedValues).map { originalValue, smoothedValue in
            originalValue + ((smoothedValue - originalValue) * blendWeight)
        }

        return clampedMostRecentSmoothedValues(inputValues: values, smoothedValues: blendedValues, smoothingStrength: smoothingStrength)
    }

    private func savitzkyGolaySmoothedValues(values: [Double], smoothingStrength: Int) -> [Double] {
        let smoothedValues = savitzkyGolayFilteredValues(values: values, filterWidth: ConstantsBgSmoothing.filterWidth(forSmoothingStrength: smoothingStrength))

        return clampedMostRecentSmoothedValues(inputValues: values, smoothedValues: smoothedValues, smoothingStrength: smoothingStrength)
    }

    private func savitzkyGolayStyleSmoothedValues(values: [Double], readingDates: [Date], smoothingStrength: Int) -> [Double] {
        if sourceCanUseFiveMinuteReadings(readingDates: readingDates) {
            return fastCadenceSmoothedValues(values: values, readingDates: readingDates, smoothingStrength: smoothingStrength)
        }

        return savitzkyGolaySmoothedValues(values: values, smoothingStrength: smoothingStrength)
    }

    private func savitzkyGolayFilteredValues(values: [Double], filterWidth: Int) -> [Double] {
        guard values.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { return values }

        var smoothedValues = values

        // Reuse the existing Savitzky-Golay utility that is already used elsewhere
        // in the project for glucose smoothing.
        smoothedValues.smoothSavitzkyGolayQuaDratic(withFilterWidth: filterWidth)

        return smoothedValues
    }

    private func clampedMostRecentSmoothedValues(inputValues: [Double], smoothedValues: [Double], smoothingStrength: Int) -> [Double] {
        guard inputValues.count == smoothedValues.count else { return smoothedValues }

        var clampedSmoothedValues = smoothedValues

        // The newest reading still needs a small guard so the live edge does not drift
        // too far away from the actual reading that the user just received.
        // This keeps the historical curve smoothly filtered while preventing the latest
        // value from looking artificially detached from the real incoming value.
        if let latestInputValue = inputValues.last, let latestSmoothedValue = clampedSmoothedValues.last {
            let maximumDeviation = ConstantsBgSmoothing.maximumDeviationForMostRecentReading(forSmoothingStrength: smoothingStrength)
            clampedSmoothedValues[clampedSmoothedValues.count - 1] = min(max(latestSmoothedValue, latestInputValue - maximumDeviation), latestInputValue + maximumDeviation)
        }

        return clampedSmoothedValues
    }

    private func sparseCadenceSmoothedValues(values: [Double], readingsPerVisibleStep: Int, filterWidth: Int, iterations: Int) -> [Double] {
        guard readingsPerVisibleStep > 1 else { return values }
        guard values.count >= (readingsPerVisibleStep * 3) + 1 else { return values }

        let sourceValues = values
        var sparseSmoothedValues = values

        for valueIndex in 0..<values.count {
            var valuesToSmooth = [sourceValues[valueIndex]]
            var indexOfValueBeingSmoothed = 0

            for offsetIndex in 1...5 {
                let previousValueIndex = valueIndex - (readingsPerVisibleStep * offsetIndex)

                if previousValueIndex >= 0 {
                    valuesToSmooth.insert(sourceValues[previousValueIndex], at: 0)
                    indexOfValueBeingSmoothed = offsetIndex
                }
            }

            for offsetIndex in 1...5 {
                let nextValueIndex = valueIndex + (readingsPerVisibleStep * offsetIndex)

                if nextValueIndex < sourceValues.count {
                    valuesToSmooth.append(sourceValues[nextValueIndex])
                }
            }

            for _ in 0..<iterations {
                valuesToSmooth = savitzkyGolayFilteredValues(values: valuesToSmooth, filterWidth: filterWidth)
            }

            sparseSmoothedValues[valueIndex] = valuesToSmooth[indexOfValueBeingSmoothed]
        }

        return sparseSmoothedValues
    }

    private func contiguousReadingIndexGroups(readingDates: [Date]) -> [[Int]] {
        guard readingDates.count > 0 else { return [] }

        var readingIndexGroups = [[0]]

        for readingIndex in 1..<readingDates.count {
            let previousReadingDate = readingDates[readingIndex - 1]
            let currentReadingDate = readingDates[readingIndex]
            let minutesBetweenReadings = currentReadingDate.timeIntervalSince(previousReadingDate) / 60.0

            if minutesBetweenReadings > Double(ConstantsBgSmoothing.maximumGapBetweenReadingsInMinutes) {
                readingIndexGroups.append([readingIndex])
            } else {
                readingIndexGroups[readingIndexGroups.count - 1].append(readingIndex)
            }
        }

        return readingIndexGroups
    }

    private func notifyBgPostProcessingDidUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(ConstantsNotifications.NotificationIdentifierForBgPostProcessing.bgPostProcessingDidUpdate), object: nil)
        }
    }

    /// smoothing always runs after adjustment, so the smoothing input should
    /// prefer adjusted values when they exist
    private func valueToSmooth(bgReading: BgReading) -> Double {
        return bgReading.adjustedValue?.doubleValue ?? bgReading.calculatedValue
    }

    private func smoothingSupport() -> BgSmoothingSupport {
        return BgSmoothingSupport(
            canUseFiveMinuteReadings: { [weak self] readingDates in
                return self?.sourceCanUseFiveMinuteReadings(readingDates: readingDates) ?? false
            },
            medianReadingGapInMinutes: { [weak self] readingDates in
                return self?.medianReadingGapInMinutes(readingDates: readingDates)
            },
            savitzkyGolayStyleSmoothedValues: { [weak self] values, readingDates, smoothingStrength in
                return self?.savitzkyGolayStyleSmoothedValues(values: values, readingDates: readingDates, smoothingStrength: smoothingStrength) ?? values
            },
            sparseCadenceSmoothedValues: { [weak self] values, readingsPerVisibleStep, filterWidth, iterations in
                return self?.sparseCadenceSmoothedValues(values: values, readingsPerVisibleStep: readingsPerVisibleStep, filterWidth: filterWidth, iterations: iterations) ?? values
            },
            clampedMostRecentSmoothedValues: { [weak self] inputValues, smoothedValues, smoothingStrength in
                return self?.clampedMostRecentSmoothedValues(inputValues: inputValues, smoothedValues: smoothedValues, smoothingStrength: smoothingStrength) ?? smoothedValues
            }
        )
    }

    private func latestBgReadingForCurrentSourceContext() -> BgReading? {
        let currentSensor = UserDefaults.standard.isMaster ? sensorsAccessor.fetchActiveSensor() : nil
        let fromDate = startDateClampedToCurrentSensorSession(UserDefaults.standard.postProcessingStartTimeStamp, currentSensor: currentSensor)

        return bgReadingsAccessor.getLatestBgReadings(limit: 1, fromDate: fromDate, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: true, includingSuppressed: true).first
    }

    private func hasEffectiveAdjustmentForCurrentSource() -> Bool {
        guard UserDefaults.standard.enableAdjustment else { return false }
        guard shouldAllowBgAdjustmentForCurrentSource() else { return false }
        guard let latestBgAdjustment = latestActiveBgAdjustment() else { return false }

        return abs(latestBgAdjustment.intercept) > 0.0001 || abs(latestBgAdjustment.slope - 1.0) > 0.0001
    }

    /// Returns whether the current source has a stable cadence that can be reduced to five minutes.
    func currentSourceCanUseFiveMinuteReadings() -> Bool {
        let currentSensor = UserDefaults.standard.isMaster ? sensorsAccessor.fetchActiveSensor() : nil
        let fromDate = startDateClampedToCurrentSensorSession(Date(timeIntervalSinceNow: -24 * 60 * 60), currentSensor: currentSensor)

        // getLatestBgReadings returns newest first. Sort oldest first before
        // calculating gaps or every interval is negative and cadence detection fails.
        let currentSourceReadingDates = bgReadingsAccessor.getLatestBgReadings(
            limit: 288,
            fromDate: fromDate,
            forSensor: nil,
            ignoreRawData: true,
            ignoreCalculatedValue: true,
            includingSuppressed: true
        )
        .map(\.timeStamp)
        .sorted()

        return sourceCanUseFiveMinuteReadings(readingDates: currentSourceReadingDates)
    }

    private func currentSourceContextIdentifier() -> String? {
        if UserDefaults.standard.isMaster {
            guard let activeSensor = sensorsAccessor.fetchActiveSensor() else { return nil }
            return "master|\(activeSensor.id)|\(activeSensor.startDate.toMillisecondsAsDouble())"
        }

        switch UserDefaults.standard.followerDataSourceType {
        case .nightscout:
            return "nightscout|\(UserDefaults.standard.nightscoutUrl ?? "unknown")"
        case .libreLinkUp, .libreLinkUpRussia:
            return "librelinkup|\(UserDefaults.standard.libreLinkUpEmail ?? "unknown")|\(UserDefaults.standard.followerPatientName ?? "unknown")"
        case .dexcomShare:
            return "dexcomshare|\(UserDefaults.standard.dexcomShareAccountName ?? "unknown")"
        case .medtrumEasyView:
            return "medtrumeasyview|\(UserDefaults.standard.medtrumEasyViewEmail ?? "unknown")|\(UserDefaults.standard.medtrumEasyViewSelectedPatientUid)"
        case .calendar:
            return "calendar|\(UserDefaults.standard.calendarFollowCalendarId ?? "unknown")|\(UserDefaults.standard.followerPatientName ?? "unknown")"
        case .careLink:
            // Region and selected patient define a non-secret follower identity without tokens.
            return "carelink|\(UserDefaults.standard.careLinkRegion ?? "unknown")|\(UserDefaults.standard.careLinkSelectedPatientID ?? "unknown")"
        }
    }

    private func currentSourceDescription() -> String? {
        if UserDefaults.standard.isMaster {
            return UserDefaults.standard.activeSensorDescription
        }

        return UserDefaults.standard.followerDataSourceType.description
    }

    private enum AdjustmentDisabledReason {
        case masterLibreUsesCalibration
        case masterDexcomG6UsesCalibration
    }

    private func adjustmentDisabledReasonForCurrentSource() -> AdjustmentDisabledReason? {
        guard UserDefaults.standard.isMaster else { return nil }
        guard let cgmTransmitterType = UserDefaults.standard.cgmTransmitterType else { return nil }

        switch cgmTransmitterType {
        case .Bubble, .miaomiao, .Libre2:
            return currentMasterLibreUsesNativeAlgorithm() ? nil : .masterLibreUsesCalibration
        case .dexcom:
            return currentMasterSourceIsDexcomG6() ? .masterDexcomG6UsesCalibration : nil
        case .dexcomG7, .medtrumTouchCareNano:
            return nil
        }
    }

    /// Adjustment must stay separate from transmitter-side calibration.
    /// Libre native algorithm can still use a simple post processing offset or scale,
    /// but once the user switches to the xDrip calibration path the adjustment row
    /// should be disabled so two calibration systems are not stacked together.
    private func currentMasterLibreUsesNativeAlgorithm() -> Bool {
        guard let currentCGMBLEPeripheral = currentCGMBLEPeripheral() else { return false }

        return currentCGMBLEPeripheral.webOOPEnabled
    }

    private func currentMasterSourceIsDexcomG6() -> Bool {
        if let activeSensorTransmitterId = UserDefaults.standard.activeSensorTransmitterId, activeSensorTransmitterId.starts(with: "8") {
            return true
        }

        return UserDefaults.standard.activeSensorDescription?.contains("G6") ?? false
    }

    private func currentCGMBLEPeripheral() -> BLEPeripheral? {
        let connectedCGMPeripherals = bLEPeripheralAccessor.getBLEPeripherals().filter { $0.shouldconnect }

        switch UserDefaults.standard.cgmTransmitterType {
        case .dexcom:
            return connectedCGMPeripherals.first { $0.dexcomG5 != nil }
        case .Bubble:
            return connectedCGMPeripherals.first { $0.bubble != nil }
        case .miaomiao:
            return connectedCGMPeripherals.first { $0.miaoMiao != nil }
        case .Libre2:
            return connectedCGMPeripherals.first { $0.libre2 != nil }
        case .dexcomG7:
            return connectedCGMPeripherals.first { $0.dexcomG7 != nil }
        case .medtrumTouchCareNano:
            return connectedCGMPeripherals.first { $0.medtrumTouchCareNano != nil }
        case nil:
            return nil
        }
    }

    /// If the source changes from an adjustment-compatible path to one that already
    /// calibrates internally, disable the existing BG adjustment immediately so the
    /// next processing pass cannot keep applying an invalid offset or scale.
    private func syncAdjustmentAvailabilityForCurrentSource() {
        guard let adjustmentDisabledReason = adjustmentDisabledReasonForCurrentSource() else { return }
        guard UserDefaults.standard.enableAdjustment || latestActiveBgAdjustment() != nil else { return }

        trace("in syncAdjustmentAvailabilityForCurrentSource, disabling BG adjustment because the current source no longer allows it. reason = %{public}@", log: log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .info, String(describing: adjustmentDisabledReason))

        disableCurrentAdjustment()
        // This is an automatic state correction rather than a direct toggle tap. Report the complete
        // resulting configuration so the Activity Log does not imply a user explicitly disabled it.
        traceTroubleshootingPostProcessingSettings(troubleshootingPostProcessingSettings())
        notifyBgPostProcessingDidUpdate()
    }
}
