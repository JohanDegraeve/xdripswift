import Foundation
import CoreData
import HealthKit
import os
import UIKit

public class HealthKitManager: NSObject {
    // MARK: - public properties
    
    // MARK: - private properties
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper: KeyValueObserverTimeKeeper = .init()
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHealthKitManager)
    
    /// reference to coredatamanager
    private var coreDataManager: CoreDataManager
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor
    
    /// is healthkit fully initiazed or not, that includes checking if healthkit is available, created successfully bloodGlucoseType, user authorized - value will get changed
    private var healthKitInitialized = false
    
    /// bloodGlucoseType - optional because if hk not available it can be initialized
    private var bloodGlucoseType: HKQuantityType?
    
    /// reference to HKHealthStore, should be used only if we're sure HealthKit is supported on the device
    private lazy var healthStore = HKHealthStore()
    
    /// Main-thread-only timestamps currently being written to HealthKit to prevent overlap across runs.
    private var timeStampsOfBgReadingsCurrentlyBeingSaved = Set<Date>()

    /// Main-thread-only replacement IDs and their latest requested values. Persist them so
    /// a locked phone or a restart cannot strand corrections outside the smoothing window.
    private var pendingHealthKitReplacements = UserDefaults.standard.dictionary(forKey: "pendingHealthKitReplacements") as? [String: Double] ?? [:] {
        didSet {
            UserDefaults.standard.set(pendingHealthKitReplacements, forKey: "pendingHealthKitReplacements")
        }
    }
    
    /// metadata key used to identify individual BG readings in HealthKit
    private let bgReadingIdMetadataKey = "BgReadingId"
    
    // MARK: - intialization
    
    init(coreDataManager: CoreDataManager) {
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        // call super.init
        super.init()
        
        // listen for changes to userdefaults storeReadingsInHealthkitAuthorized
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.storeReadingsInHealthkitAuthorized.rawValue, options: .new, context: nil)
        // listen for changes to userdefaults storeReadingsInHealthkit
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.storeReadingsInHealthkit.rawValue, options: .new, context: nil)

        // call initializeHealthKit, set healthKitInitialized according to result of initialization
        healthKitInitialized = initializeHealthKit()

        NotificationCenter.default.addObserver(self, selector: #selector(storeBgReadings), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(storeBgReadings), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // do first store
        storeBgReadings()
    }
    
    // MARK: - private functions
    
    /// checks if healthkit available, creates bloodGlucoseType, and checks if user authorized storing readings in healtkit
    /// - returns:
    ///     - result which indicates if initialize was successful or not, autorization request is done from within Settings views, when user enables HealthKit
    ///
    /// the return value of the function does not depend on UserDefaults.standard.storeReadingsInHealthkit - this setting needs to be verified each time there's  an new reading to store
    ///
    /// if authorizationStatus is notDetermined or sharingDenied, then UserDefaults.standard.storeReadingsInHealthkitAuthorized is set to false by this function
    private func initializeHealthKit() -> Bool {
        // if healthkit not available (ipad) then no further processing
        if !HKHealthStore.isHealthDataAvailable() {
            return false
        }
        
        // initialize bloodGlucoseType
        bloodGlucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose)
        
        // if bloodGlucseType not correctly initialized then result is false
        guard let bloodGlucoseType = bloodGlucoseType else { return false }
        
        // set value of UserDefaults storeReadingsInHealthkitAuthorized according to actual value in HealthKit Store
        // because user might have first authorized, then remove the authorization - if it's not authorized, then set storeReadingsInHealthkitAuthorized to false
        let authorizationStatus = healthStore.authorizationStatus(for: bloodGlucoseType)
        switch authorizationStatus {
        case .notDetermined, .sharingDenied:
            if UserDefaults.standard.storeReadingsInHealthkit {
                trace("HealthKit sharing is not authorized", log: log, category: ConstantsLog.categoryHealthKitManager, type: .info, troubleshooting: .detailed(.integration(name: .healthKit, activity: .permissionDenied)))
            }
            UserDefaults.standard.storeReadingsInHealthkitAuthorized = false
            return false
        case .sharingAuthorized:
            break
        @unknown default:
            trace("unknown authorizationstatus for healthkit - HealthKitManager.swift", log: log, category: ConstantsLog.categoryHealthKitManager, type: .error, troubleshooting: .detailed(.integration(name: .healthKit, activity: .failed)))
            UserDefaults.standard.storeReadingsInHealthkitAuthorized = false
            return false
        }
        
        // all checks ok , return true
        return true
    }
    
    /// stores latest readings in healthkit, only if HK supported, authorized, enabled in settings
    @objc public func storeBgReadings() {
        // ensure this function runs on main thread because it accesses objects from the main managedObjectContext
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.storeBgReadings()
            }
            return
        }
        // healthkit setting must be on, and healthkit must be initialized successfully
        if !UserDefaults.standard.storeReadingsInHealthkit || !healthKitInitialized {
            return
        }
        
        // bloodGlucoseType should not be nil
        guard let bloodGlucoseType = bloodGlucoseType else { return }
        
        // snapshot of the latest saved timestamp (strict boundary) and in-flight timestamps (to avoid re-saving while previous saves are not completed)
        let strictLatestHealthKitStoredTimeStamp = UserDefaults.standard.timeStampLatestHealthKitStoreBgReading ?? Date.distantPast
        let timeStampsCurrentlyInFlight: Set<Date> = timeStampsOfBgReadingsCurrentlyBeingSaved
        
        // user setting to allow more frequent HealthKit writes (e.g. Libre 2 Direct 60-second cadence)
        let storeFrequentReadingsInHealthKit = UserDefaults.standard.storeFrequentReadingsInHealthKit
        
        // get readings to store, limit to 2016 = maximum 1 week - just to avoid a huge array is being returned here, applying minimumTimeBetweenTwoReadingsInMinutes filter
        let bgReadingsToStore = bgReadingsAccessor.getLatestBgReadingSnapshots(limit: 2016, fromDate: UserDefaults.standard.timeStampLatestHealthKitStoreBgReading, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).filter(minimumTimeBetweenTwoReadingsInMinutes: storeFrequentReadingsInHealthKit ? 0 : ConstantsHealthKit.minimiumTimeBetweenTwoReadingsInMinutes, lastConnectionStatusChangeTimeStamp: nil, timeStampLastProcessedBgReading: UserDefaults.standard.timeStampLatestHealthKitStoreBgReading)
        
        let bgReadingsToStoreAfterApplyingStrictBoundaryAndInFlightExclusion = bgReadingsToStore.filter {
            let isAfterStrictBoundary = $0.timeStamp > strictLatestHealthKitStoredTimeStamp
            let respectsFrequentWriteSpacing = !storeFrequentReadingsInHealthKit || ($0.timeStamp.timeIntervalSince(strictLatestHealthKitStoredTimeStamp) > 50)
            let isNotInFlight = !timeStampsCurrentlyInFlight.contains($0.timeStamp)
            return isAfterStrictBoundary && respectsFrequentWriteSpacing && isNotInFlight
        }
        
        let bloodGlucoseUnit = HKUnit(from: "mg/dL")
        
        if bgReadingsToStoreAfterApplyingStrictBoundaryAndInFlightExclusion.count > 0 {
            for (_, bgReading) in bgReadingsToStoreAfterApplyingStrictBoundaryAndInFlightExclusion.enumerated().reversed() { // reversed order because the first element is the youngest
                saveBgReadingInHealthKit(bgReading: bgReading, bloodGlucoseType: bloodGlucoseType, bloodGlucoseUnit: bloodGlucoseUnit, shouldUpdateLatestTimeStamp: true)
            }
        }

        if !pendingHealthKitReplacements.isEmpty, UIApplication.shared.isProtectedDataAvailable {
            // Reload current values, not stale smoothed snapshots saved before a restart.
            // Deleted/suppressed readings must not be resurrected by a delayed retry.
            let request = BgReading.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@ AND calculatedValue > 0 AND isSuppressedByFiveMinuteCadence == NO", Array(pendingHealthKitReplacements.keys))
            do {
                let readings = try coreDataManager.mainManagedObjectContext.fetch(request)
                let readingIDs = Set(readings.map { $0.id })
                pendingHealthKitReplacements = pendingHealthKitReplacements.filter { readingIDs.contains($0.key) }
                replaceBgReadingsInHealthKit(bgReadings: readings)
            } catch {
                trace("failed fetch pending healthkit BG readings, error = %{public}@", log: log, category: ConstantsLog.categoryHealthKitManager, type: .error, error.localizedDescription)
            }
        }
    }
    
    public func replaceBgReadingsInHealthKit(bgReadings: [BgReading]) {
        let bgReadingSnapshots = bgReadings.map {
            BgReadingSnapshot(timeStamp: $0.timeStamp, calculatedValue: $0.calculatedValue, rawData: $0.rawData, finalValue: $0.finalValue, adjustedValue: $0.adjustedValue?.doubleValue, smoothedValue: $0.smoothedValue?.doubleValue, backfilledAt: $0.backfilledAt, calculatedValueSlope: $0.calculatedValueSlope, hideSlope: $0.hideSlope, id: $0.id, deviceName: $0.deviceName, calibrationSnapshot: $0.calibration.map { CalibrationSnapshot(id: $0.id, timeStamp: $0.timeStamp, slope: $0.slope, intercept: $0.intercept, bg: $0.bg, rawValue: $0.rawValue) }, sensorID: $0.sensor?.id, objectID: $0.objectID)
        }
        
        replaceBgReadingsInHealthKit(bgReadings: bgReadingSnapshots)
    }
    
    public func replaceBgReadingsInHealthKit(bgReadings: [BgReadingSnapshot]) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.replaceBgReadingsInHealthKit(bgReadings: bgReadings)
            }
            return
        }
        
        if !UserDefaults.standard.storeReadingsInHealthkit || !healthKitInitialized {
            return
        }
        
        guard let bloodGlucoseType = bloodGlucoseType else { return }
        
        let bloodGlucoseUnit = HKUnit(from: "mg/dL")

        var pendingReplacements = pendingHealthKitReplacements
        for bgReading in bgReadings {
            pendingReplacements[bgReading.id] = bgReading.finalValue
        }
        pendingHealthKitReplacements = pendingReplacements

        // HealthKit can accept writes while locked but cannot read the old samples.
        // Keep replacements pending until we can safely migrate any legacy samples.
        guard UIApplication.shared.isProtectedDataAvailable else { return }
        
        for bgReading in bgReadings {
            // Reserve the whole query/delete/save operation, not just its final save.
            guard timeStampsOfBgReadingsCurrentlyBeingSaved.insert(bgReading.timeStamp).inserted else { continue }
            deleteExistingBgReadingsFromHealthKit(bgReading: bgReading, bloodGlucoseType: bloodGlucoseType, bloodGlucoseUnit: bloodGlucoseUnit)
        }
    }

    /// Removes readings hidden by an explicit five-minute cadence rebuild without
    /// touching the samples that remain visible and will be updated separately.
    public func deleteBgReadingsFromHealthKit(bgReadingIDs: [String]) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.deleteBgReadingsFromHealthKit(bgReadingIDs: bgReadingIDs)
            }
            return
        }

        guard UserDefaults.standard.storeReadingsInHealthkit,
              healthKitInitialized,
              let bloodGlucoseType = bloodGlucoseType,
              bgReadingIDs.count > 0
        else { return }

        let suppressedIDs = Set(bgReadingIDs)
        pendingHealthKitReplacements = pendingHealthKitReplacements.filter { !suppressedIDs.contains($0.key) }

        let metadataPredicate = HKQuery.predicateForObjects(withMetadataKey: bgReadingIdMetadataKey, allowedValues: bgReadingIDs)
        let sampleQuery = HKSampleQuery(sampleType: bloodGlucoseType, predicate: metadataPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let self = self else { return }

            if let error = error {
                trace("failed query suppressed healthkit BG readings, error = %{public}@", log: self.log, category: ConstantsLog.categoryHealthKitManager, type: .error, error.localizedDescription)
                return
            }

            guard let samples = samples, samples.count > 0 else { return }

            self.healthStore.delete(samples) { success, deleteError in
                if !success, let deleteError = deleteError {
                    trace("failed delete suppressed healthkit BG readings, error = %{public}@", log: self.log, category: ConstantsLog.categoryHealthKitManager, type: .error, deleteError.localizedDescription)
                }
            }
        }

        healthStore.execute(sampleQuery)
    }
    
    // MARK: - observe function
    
    /// when UserDefaults storeReadingsInHealthkitAuthorized or storeReadingsInHealthkit changes, then reinitialize the property healthKitInitialized
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                switch keyPathEnum {
                case UserDefaults.Key.storeReadingsInHealthkitAuthorized, UserDefaults.Key.storeReadingsInHealthkit:
                    
                    // check latest change, to avoid there's an endless loop, because initializeHealthKit is actually setting value of storeReadingsInHealthkitAuthorized
                    if keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 100) {
                        // doesn't matter which if the two settings got changed, it's ok to call initialize
                        healthKitInitialized = initializeHealthKit()
                        
                        // doesn't matter which if the two settings got changed, it's ok to call initialize
                        storeBgReadings()
                    }

                default:
                    break
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.storeReadingsInHealthkitAuthorized.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.storeReadingsInHealthkit.rawValue)
    }
    
    private func deleteExistingBgReadingsFromHealthKit(bgReading: BgReadingSnapshot, bloodGlucoseType: HKQuantityType, bloodGlucoseUnit: HKUnit) {
        let metadataPredicate = HKQuery.predicateForObjects(withMetadataKey: bgReadingIdMetadataKey, allowedValues: [bgReading.id])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [metadataPredicate, HKQuery.predicateForObjects(from: HKSource.default())])
        let sampleQuery = HKSampleQuery(sampleType: bloodGlucoseType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let self = self else { return }
            
            guard error == nil, let samples = samples else {
                trace("failed query existing healthkit BG reading, error = %{public}@", log: self.log, category: ConstantsLog.categoryHealthKitManager, type: .error, error?.localizedDescription ?? "missing query results")
                // An inaccessible store is not an empty store. Saving here creates duplicates.
                DispatchQueue.main.async {
                    self.timeStampsOfBgReadingsCurrentlyBeingSaved.remove(bgReading.timeStamp)
                }
                return
            }
            
            // New samples are replaced atomically by HealthKit's sync metadata. Only
            // pre-fix samples need explicit deletion; retain modern samples if saving fails.
            let legacySamples = samples.filter { $0.metadata?[HKMetadataKeySyncIdentifier] == nil }
            guard !legacySamples.isEmpty else {
                self.saveBgReadingInHealthKit(bgReading: bgReading, bloodGlucoseType: bloodGlucoseType, bloodGlucoseUnit: bloodGlucoseUnit, shouldUpdateLatestTimeStamp: false)
                return
            }
            
            self.healthStore.delete(legacySamples) { success, deleteError in
                guard success else {
                    trace("failed delete existing healthkit BG reading, error = %{public}@", log: self.log, category: ConstantsLog.categoryHealthKitManager, type: .error, deleteError?.localizedDescription ?? "unknown error")
                    DispatchQueue.main.async {
                        self.timeStampsOfBgReadingsCurrentlyBeingSaved.remove(bgReading.timeStamp)
                    }
                    return
                }
                
                self.saveBgReadingInHealthKit(bgReading: bgReading, bloodGlucoseType: bloodGlucoseType, bloodGlucoseUnit: bloodGlucoseUnit, shouldUpdateLatestTimeStamp: false)
            }
        }
        
        healthStore.execute(sampleQuery)
    }
    
    private func saveBgReadingInHealthKit(bgReading: BgReadingSnapshot, bloodGlucoseType: HKQuantityType, bloodGlucoseUnit: HKUnit, shouldUpdateLatestTimeStamp: Bool) {
        // Replacement queries also call this from HealthKit's callback queue.
        // Keep bookkeeping on main. Synchronously waiting for a queue that writes
        // UserDefaults can deadlock against a main-queue defaults observer.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.saveBgReadingInHealthKit(bgReading: bgReading, bloodGlucoseType: bloodGlucoseType, bloodGlucoseUnit: bloodGlucoseUnit, shouldUpdateLatestTimeStamp: shouldUpdateLatestTimeStamp)
            }
            return
        }

        // Use the newest requested value if smoothing ran again during the query.
        // A removed pending entry means the reading was deleted or suppressed meanwhile.
        guard let valueToStore = shouldUpdateLatestTimeStamp ? bgReading.finalValue : pendingHealthKitReplacements[bgReading.id] else {
            timeStampsOfBgReadingsCurrentlyBeingSaved.remove(bgReading.timeStamp)
            return
        }

        let quantity = HKQuantity(unit: bloodGlucoseUnit, doubleValue: valueToStore)
        // BgReadingId alone is only custom metadata, not a uniqueness constraint.
        // A persisted, increasing version makes retries/revisions replace the same sample,
        // including after relaunch or a backwards clock change.
        let syncVersion = max(UserDefaults.standard.integer(forKey: "healthKitSyncVersion") + 1, Int(Date().timeIntervalSince1970 * 1_000_000))
        UserDefaults.standard.set(syncVersion, forKey: "healthKitSyncVersion")
        let metadata: [String: Any] = [bgReadingIdMetadataKey: bgReading.id, HKMetadataKeySyncIdentifier: bgReading.id, HKMetadataKeySyncVersion: syncVersion]
        let sample = HKQuantitySample(type: bloodGlucoseType, quantity: quantity, start: bgReading.timeStamp, end: bgReading.timeStamp, metadata: metadata)
        let timeStampLastReadingToUpload = bgReading.timeStamp
        
        timeStampsOfBgReadingsCurrentlyBeingSaved.insert(timeStampLastReadingToUpload)
        
        healthStore.save(sample, withCompletion: { [weak self]
            (success: Bool, error: Error?) in
                // Remove the in-flight marker and advance the timestamp together on main.
                // Always clear the marker, including failures without an Error payload.
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.timeStampsOfBgReadingsCurrentlyBeingSaved.remove(timeStampLastReadingToUpload)
                    if success {
                        // A newer smoothing pass may have arrived during this operation.
                        // Clear only the value we actually saved; leave newer corrections queued.
                        if !shouldUpdateLatestTimeStamp, self.pendingHealthKitReplacements[bgReading.id] == valueToStore {
                            self.pendingHealthKitReplacements.removeValue(forKey: bgReading.id)
                        }
                        if shouldUpdateLatestTimeStamp {
                            let existingTimeStampLatestHealthKitStoreBgReading = UserDefaults.standard.timeStampLatestHealthKitStoreBgReading ?? Date.distantPast
                            let newTimeStampLatestHealthKitStoreBgReading = max(existingTimeStampLatestHealthKitStoreBgReading, timeStampLastReadingToUpload)
                            UserDefaults.standard.timeStampLatestHealthKitStoreBgReading = newTimeStampLatestHealthKitStoreBgReading
                        }
                        trace("stored reading in HealthKit", log: self.log, category: ConstantsLog.categoryHealthKitManager, type: .debug, troubleshooting: .detailed(.integration(name: .healthKit, activity: .succeeded(itemCount: 1))))
                    } else if let error = error {
                        trace("failed store reading in healthkit, error = %{public}@", log: self.log, category: ConstantsLog.categoryHealthKitManager, type: .error, troubleshooting: .detailed(.integration(name: .healthKit, activity: .failed)), error.localizedDescription)
                    }
                }
        })
    }
}
