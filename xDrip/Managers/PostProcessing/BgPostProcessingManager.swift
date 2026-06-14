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
        let finalValue: Double
        let slopeName: String
        let hideSlope: Bool
    }
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataBgReadings)
    
    private let coreDataManager: CoreDataManager
    private let bgReadingsAccessor: BgReadingsAccessor
    private let bgAdjustmentsAccessor: BgAdjustmentsAccessor
    private let bLEPeripheralAccessor: BLEPeripheralAccessor
    private let sensorsAccessor: SensorsAccessor
    
    private weak var nightscoutSyncManager: NightscoutSyncManager?
    private weak var healthKitManager: HealthKitManager?
    
    // MARK: - initializer
    
    init(coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager?, healthKitManager: HealthKitManager?) {
        
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.bgAdjustmentsAccessor = BgAdjustmentsAccessor(coreDataManager: coreDataManager)
        self.bLEPeripheralAccessor = BLEPeripheralAccessor(coreDataManager: coreDataManager)
        self.sensorsAccessor = SensorsAccessor(coreDataManager: coreDataManager)
        self.nightscoutSyncManager = nightscoutSyncManager
        self.healthKitManager = healthKitManager
        
    }
    
    // MARK: - public functions
    
    /// reprocess the latest readings for the current source context
    func processLatestReadings() {
        processBgReadings(processingStartDateOverride: nil, smoothingWindowStartDateOverride: nil)
    }
    
    /// compare the resolved source context against the stored one and reset the
    /// current post processing state if the user has switched to a different source
    /// or changed the credentials and identity details behind that source
    func refreshSourceContext() {
        let sourceContextIdentifier = currentSourceContextIdentifier()
        let previousSourceContextIdentifier = UserDefaults.standard.postProcessingSourceContextIdentifier
        
        if previousSourceContextIdentifier != sourceContextIdentifier {
            if UserDefaults.standard.enableAdjustment || UserDefaults.standard.enableSmoothing {
                trace("in refreshSourceContext, resetting BG post processing because the source context changed from %{public}@ to %{public}@. BG adjustment enabled = %{public}@. Smoothing enabled = %{public}@", log: log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .info, previousSourceContextIdentifier ?? "nil", sourceContextIdentifier ?? "nil", UserDefaults.standard.enableAdjustment.description, UserDefaults.standard.enableSmoothing.description)
            }
            
            handleSourceContextChanged()
            UserDefaults.standard.postProcessingSourceContextIdentifier = sourceContextIdentifier
        }
        
        syncAdjustmentAvailabilityForCurrentSource()
    }

    /// applies adjustment and smoothing to the requested readings, then updates
    /// any downstream consumers that should reflect the new final values
    func processBgReadings(processingStartDateOverride: Date?, smoothingWindowStartDateOverride: Date?) {
        refreshSourceContext()
        
        guard let sourceContextIdentifier = currentSourceContextIdentifier() else {
            trace("in processLatestReadings, sourceContextIdentifier is nil", log: self.log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .info)
            return
        }
        
        let currentSensor = UserDefaults.standard.isMaster ? sensorsAccessor.fetchActiveSensor() : nil
        let fromDate = processingStartDateOverride ?? UserDefaults.standard.postProcessingStartTimeStamp
        
        // Work in ascending time order so each processing step can move forward
        // through the readings without needing to constantly look backwards.
        let bgReadings = Array(bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: fromDate, forSensor: currentSensor, ignoreRawData: true, ignoreCalculatedValue: true).reversed())
        
        guard bgReadings.count > 0 else { return }
        
        var statesBeforeProcessing = [NSManagedObjectID: BgReadingStateBeforeProcessing]()
        for bgReading in bgReadings {
            statesBeforeProcessing[bgReading.objectID] = BgReadingStateBeforeProcessing(finalValue: bgReading.finalValue, slopeName: bgReading.slopeName, hideSlope: bgReading.hideSlope)
        }
        
        recomputeAdjustedValues(bgReadings: bgReadings, sourceContextIdentifier: sourceContextIdentifier)
        recomputeSmoothedValues(bgReadings: bgReadings, smoothingWindowStartDateOverride: smoothingWindowStartDateOverride)
        recomputeSlopes(bgReadings: bgReadings)
        
        coreDataManager.saveChanges()
        
        let changedBgReadings = bgReadings.filter { bgReading in
            guard let stateBeforeProcessing = statesBeforeProcessing[bgReading.objectID] else { return true }
            
            if abs(stateBeforeProcessing.finalValue - bgReading.finalValue) > 0.001 {
                return true
            }
            
            if stateBeforeProcessing.slopeName != bgReading.slopeName {
                return true
            }
            
            if stateBeforeProcessing.hideSlope != bgReading.hideSlope {
                return true
            }
            
            return false
        }
        
        // A manual historical apply should always rewrite the full selected window.
        // Automatic processing only needs to push the readings that actually changed.
        let bgReadingsToReplaceDownstream = processingStartDateOverride == nil ? changedBgReadings : bgReadings
        
        if bgReadingsToReplaceDownstream.count > 0 {
            if processingStartDateOverride != nil, let earliestBgReading = bgReadingsToReplaceDownstream.first, let latestBgReading = bgReadingsToReplaceDownstream.last {
                nightscoutSyncManager?.replaceBgReadingsInNightscout(bgReadings: bgReadingsToReplaceDownstream, deleteFromTimeStamp: earliestBgReading.timeStamp, deleteToTimeStamp: latestBgReading.timeStamp)
            } else {
                nightscoutSyncManager?.replaceBgReadingsInNightscout(bgReadings: bgReadingsToReplaceDownstream)
            }
            healthKitManager?.replaceBgReadingsInHealthKit(bgReadings: bgReadingsToReplaceDownstream)
        }
    }
    
    /// reset source-specific post processing whenever the active master sensor
    /// or follower source changes
    func handleSourceContextChanged() {
        // Source-specific processing must not leak into a new master sensor session
        // or a different follower stream. Reset the entire editing state so any
        // new source starts from neutral values and disabled post processing.
        UserDefaults.standard.enableAdjustment = false
        updateSmoothingSettings(enableSmoothing: false, smoothingPeriodInMinutes: ConstantsBgSmoothing.defaultSmoothingPeriodInMinutes, smoothingStrength: ConstantsBgSmoothing.defaultSmoothingStrength)
        UserDefaults.standard.postProcessingStartTimeStamp = Date()
        UserDefaults.standard.postProcessingSourceContextIdentifier = nil
    }
    
    func latestActiveBgAdjustment() -> BgAdjustment? {
        guard let sourceContextIdentifier = currentSourceContextIdentifier() else { return nil }

        if let latestBgReading = latestBgReadingForCurrentSourceContext() {
            return bgAdjustmentsAccessor.latestApplicableBgAdjustment(forSourceContextIdentifier: sourceContextIdentifier, readingTimeStamp: latestBgReading.timeStamp, on: coreDataManager.mainManagedObjectContext)
        }
        
        return bgAdjustmentsAccessor.latestActiveBgAdjustment(forSourceContextIdentifier: sourceContextIdentifier, on: coreDataManager.mainManagedObjectContext)
    }
    
    /// store the current smoothing settings and immediately reprocess the latest readings
    func updateSmoothing(enableSmoothing: Bool, smoothingPeriodInMinutes: Int, smoothingStrength: Int) {
        updateSmoothingSettings(enableSmoothing: enableSmoothing, smoothingPeriodInMinutes: smoothingPeriodInMinutes, smoothingStrength: smoothingStrength)
        processLatestReadings()
        notifyBgPostProcessingDidUpdate()
    }
    
    func applyPostProcessing(enableAdjustment: Bool, slope: Double?, intercept: Double?, adjustmentShapeType: BgAdjustmentShapeType, applyFromTimeStamp: Date, isBasicAdjustment: Bool, enteredBgValue: Double?, sourceCalculatedValue: Double?, enableSmoothing: Bool, smoothingPeriodInMinutes: Int, smoothingStrength: Int, processingStartDateOverride: Date? = nil, smoothingWindowStartDateOverride: Date? = nil) {
        trace("%{public}@", log: log, category: ConstantsLog.categoryApplicationDataBgReadings, type: .info, applyPostProcessingDescription(enableAdjustment: enableAdjustment, slope: slope, intercept: intercept, adjustmentShapeType: adjustmentShapeType, applyFromTimeStamp: applyFromTimeStamp, enteredBgValue: enteredBgValue, sourceCalculatedValue: sourceCalculatedValue, enableSmoothing: enableSmoothing, smoothingStrength: smoothingStrength, processingStartDateOverride: processingStartDateOverride))
        
        if enableAdjustment, let slope = slope, let intercept = intercept {
            createAdjustment(slope: slope, intercept: intercept, adjustmentShapeType: adjustmentShapeType, applyFromTimeStamp: applyFromTimeStamp, isBasicAdjustment: isBasicAdjustment, enteredBgValue: enteredBgValue, sourceCalculatedValue: sourceCalculatedValue)
        } else {
            disableCurrentAdjustment()
        }
        
        updateSmoothingSettings(enableSmoothing: enableSmoothing, smoothingPeriodInMinutes: smoothingPeriodInMinutes, smoothingStrength: smoothingStrength)
        
        processBgReadings(processingStartDateOverride: processingStartDateOverride, smoothingWindowStartDateOverride: smoothingWindowStartDateOverride)
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
    
    // MARK: - private functions
    
    private func applyPostProcessingDescription(enableAdjustment: Bool, slope: Double?, intercept: Double?, adjustmentShapeType: BgAdjustmentShapeType, applyFromTimeStamp: Date, enteredBgValue: Double?, sourceCalculatedValue: Double?, enableSmoothing: Bool, smoothingStrength: Int, processingStartDateOverride: Date?) -> String {
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
            description += " Smoothing applied with " + smoothingStrengthDescription(smoothingStrength).lowercased() + " strength."
        } else {
            description += " Smoothing is not enabled."
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
    
    private func updateSmoothingSettings(enableSmoothing: Bool, smoothingPeriodInMinutes: Int, smoothingStrength: Int) {
        UserDefaults.standard.enableSmoothing = enableSmoothing
        UserDefaults.standard.bgSmoothingPeriodInMinutes = smoothingPeriodInMinutes
        UserDefaults.standard.bgSmoothingStrength = smoothingStrength
    }
    
    private func recomputeSmoothedValues(bgReadings: [BgReading], smoothingWindowStartDateOverride: Date?) {
        if !UserDefaults.standard.enableSmoothing {
            for bgReading in bgReadings {
                bgReading.smoothedValue = nil
            }
            
            return
        }
        
        let defaultSmoothingWindowStartDate = Date().addingTimeInterval(-Double(UserDefaults.standard.bgSmoothingPeriodInMinutes) * 60)
        
        // An explicit historical apply must use the exact window chosen by the user.
        // The postProcessingStartTimeStamp guard is still useful for automatic/live
        // processing, but should not silently shrink a manual historical rewrite.
        let smoothingWindowStartDate = smoothingWindowStartDateOverride ?? max(UserDefaults.standard.postProcessingStartTimeStamp ?? .distantPast, defaultSmoothingWindowStartDate)
        let readingsInSmoothingWindow = bgReadings.filter({ $0.timeStamp >= smoothingWindowStartDate })
        
        for bgReading in readingsInSmoothingWindow {
            bgReading.smoothedValue = nil
        }
        
        // During testing it was found that a long data gap could make smoothing behave
        // unpredictably at both edges of the break. The last value before the gap
        // could jump upward and the first value after the gap could jump downward.
        // The cause was the centered filter treating both sides of the gap as one
        // continuous 5 minute series. Split the readings first so each glucose group
        // is smoothed independently and missing time is never "smoothed through".
        for contiguousReadingIndexes in contiguousReadingIndexGroups(readingDates: readingsInSmoothingWindow.map { $0.timeStamp }) {
            let contiguousReadings = contiguousReadingIndexes.map { readingsInSmoothingWindow[$0] }
            guard contiguousReadings.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { continue }
            
            let inputValues = contiguousReadings.map { valueToSmooth(bgReading: $0) }
            let smoothedValues = savitzkyGolaySmoothedValues(values: inputValues, smoothingStrength: UserDefaults.standard.bgSmoothingStrength)
            
            for readingIndex in 0..<contiguousReadings.count {
                contiguousReadings[readingIndex].smoothedValue = NSNumber(value: smoothedValues[readingIndex])
            }
        }
    }
    
    private func recomputeSlopes(bgReadings: [BgReading]) {
        for (index, bgReading) in bgReadings.enumerated() {
            if index == 0 {
                bgReading.calculatedValueSlope = 0.0
                bgReading.hideSlope = true
            } else {
                let (calculatedValueSlope, hideSlope) = bgReading.calculateSlope(lastBgReading: bgReadings[index - 1])
                bgReading.calculatedValueSlope = calculatedValueSlope
                bgReading.hideSlope = hideSlope
            }
        }
    }
    
    /// preview smoothing uses the same grouped path as stored processing so
    /// the chart always mirrors the values that would actually be written
    func smoothedValuesSeparatedByReadingGap(values: [Double], readingDates: [Date], smoothingStrength: Int) -> [Double] {
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
            let smoothedValues = savitzkyGolaySmoothedValues(values: contiguousValues, smoothingStrength: smoothingStrength)
            
            for (segmentIndex, readingIndex) in contiguousReadingIndexes.enumerated() {
                groupedSmoothedValues[readingIndex] = smoothedValues[segmentIndex]
            }
        }
        
        return groupedSmoothedValues
    }
    
    private func savitzkyGolaySmoothedValues(values: [Double], smoothingStrength: Int) -> [Double] {
        guard values.count >= ConstantsBgSmoothing.minimumReadingsForSmoothing else { return values }
        
        var smoothedValues = values
        
        // Reuse the existing Savitzky-Golay utility that is already used elsewhere
        // in the project for glucose smoothing.
        smoothedValues.smoothSavitzkyGolayQuaDratic(withFilterWidth: ConstantsBgSmoothing.filterWidth(forSmoothingStrength: smoothingStrength))
        
        // The newest reading still needs a small guard so the live edge does not drift
        // too far away from the actual reading that the user just received.
        // This keeps the historical curve smoothly filtered while preventing the latest
        // value from looking artificially detached from the real incoming value.
        if let latestInputValue = values.last, let latestSmoothedValue = smoothedValues.last {
            let maximumDeviation = ConstantsBgSmoothing.maximumDeviationForMostRecentReading(forSmoothingStrength: smoothingStrength)
            smoothedValues[smoothedValues.count - 1] = min(max(latestSmoothedValue, latestInputValue - maximumDeviation), latestInputValue + maximumDeviation)
        }
        
        return smoothedValues
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

    private func latestBgReadingForCurrentSourceContext() -> BgReading? {
        let currentSensor = UserDefaults.standard.isMaster ? sensorsAccessor.fetchActiveSensor() : nil
        let fromDate = UserDefaults.standard.postProcessingStartTimeStamp
        
        return bgReadingsAccessor.getLatestBgReadings(limit: 1, fromDate: fromDate, forSensor: currentSensor, ignoreRawData: true, ignoreCalculatedValue: true).first
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
        }
    }
    
    private func currentSourceDescription() -> String? {
        if UserDefaults.standard.isMaster {
            return UserDefaults.standard.activeSensorDescription
        }
        
        return UserDefaults.standard.followerDataSourceType.fullDescription
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
        case .dexcomG7:
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
        notifyBgPostProcessingDidUpdate()
    }
}
