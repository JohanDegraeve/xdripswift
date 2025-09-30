import Foundation
import HealthKit
import os

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
    
    /// set of timestamps currently being written to HealthKit to prevent overlap across runs
    private var timeStampsOfBgReadingsCurrentlyBeingSaved = Set<Date>()
    
    /// serial queue to ensure atomic updates of the latest HealthKit store timestamp
    /// the idea is to use this and force all updates to be done
    private let healthKitTimestampUpdateQueue = DispatchQueue(label: "HealthKitManager.timestampUpdate")
    
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
            UserDefaults.standard.storeReadingsInHealthkitAuthorized = false
            return false
        case .sharingAuthorized:
            break
        @unknown default:
            trace("unknown authorizationstatus for healthkit - HealthKitManager.swift", log: log, category: ConstantsLog.categoryHealthKitManager, type: .error)
            UserDefaults.standard.storeReadingsInHealthkitAuthorized = false
            return false
        }
        
        // all checks ok , return true
        return true
    }
    
    /// stores latest readings in healthkit, only if HK supported, authorized, enabled in settings
    public func storeBgReadings() {
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
        let timeStampsCurrentlyInFlight: Set<Date> = healthKitTimestampUpdateQueue.sync { timeStampsOfBgReadingsCurrentlyBeingSaved }
        
        // user setting to allow more frequent HealthKit writes (e.g. Libre 2 Direct 60-second cadence)
        let storeFrequentReadingsInHealthKit = UserDefaults.standard.storeFrequentReadingsInHealthKit
        
        // get readings to store, limit to 2016 = maximum 1 week - just to avoid a huge array is being returned here, applying minimumTimeBetweenTwoReadingsInMinutes filter
        let bgReadingsToStore = bgReadingsAccessor.getLatestBgReadings(limit: 2016, fromDate: UserDefaults.standard.timeStampLatestHealthKitStoreBgReading, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).filter(minimumTimeBetweenTwoReadingsInMinutes: storeFrequentReadingsInHealthKit ? 0 : ConstantsHealthKit.minimiumTimeBetweenTwoReadingsInMinutes, lastConnectionStatusChangeTimeStamp: nil, timeStampLastProcessedBgReading: UserDefaults.standard.timeStampLatestHealthKitStoreBgReading)
        
        let bgReadingsToStoreAfterApplyingStrictBoundaryAndInFlightExclusion = bgReadingsToStore.filter {
            let isAfterStrictBoundary = $0.timeStamp > strictLatestHealthKitStoredTimeStamp
            let respectsFrequentWriteSpacing = !storeFrequentReadingsInHealthKit || ($0.timeStamp.timeIntervalSince(strictLatestHealthKitStoredTimeStamp) > 50)
            let isNotInFlight = !timeStampsCurrentlyInFlight.contains($0.timeStamp)
            return isAfterStrictBoundary && respectsFrequentWriteSpacing && isNotInFlight
        }
        
        let bloodGlucoseUnit = HKUnit(from: "mg/dL")
        
        if bgReadingsToStoreAfterApplyingStrictBoundaryAndInFlightExclusion.count > 0 {
            for (_, bgReading) in bgReadingsToStoreAfterApplyingStrictBoundaryAndInFlightExclusion.enumerated().reversed() { // reversed order because the first element is the youngest
                let quantity = HKQuantity(unit: bloodGlucoseUnit, doubleValue: bgReading.calculatedValue)
                let sample = HKQuantitySample(type: bloodGlucoseType, quantity: quantity, start: bgReading.timeStamp, end: bgReading.timeStamp)
                
                // store the timestamp of the last reading to upload, here in the main thread, because we use a bgReading for it, which is retrieved in the main mangedObjectContext
                let timeStampLastReadingToUpload = bgReading.timeStamp
                
                // mark this timestamp as in-flight to avoid being selected by overlapping runs until completion
                healthKitTimestampUpdateQueue.sync {
                    _ = timeStampsOfBgReadingsCurrentlyBeingSaved.insert(timeStampLastReadingToUpload)
                }
                
                healthStore.save(sample, withCompletion: { [weak self]
                    (success: Bool, error: Error?) in
                        guard let self = self else { return }
                        if success {
                            // Prevent timestamp regression if HealthKit save completions return out of order
                            // This is to avoid duplicate entries as seen here: https://github.com/JohanDegraeve/xdripswift/issues/662#issuecomment-3352013175
                            self.healthKitTimestampUpdateQueue.async {
                                // remove from in-flight set first, then perform atomic, monotonic watermark update
                                self.timeStampsOfBgReadingsCurrentlyBeingSaved.remove(timeStampLastReadingToUpload)
                                
                                let existingTimeStampLatestHealthKitStoreBgReading = UserDefaults.standard.timeStampLatestHealthKitStoreBgReading ?? Date.distantPast
                                let newTimeStampLatestHealthKitStoreBgReading = max(existingTimeStampLatestHealthKitStoreBgReading, timeStampLastReadingToUpload)
                                UserDefaults.standard.timeStampLatestHealthKitStoreBgReading = newTimeStampLatestHealthKitStoreBgReading
                            }
                        } else if let error = error {
                            // ensure in-flight removal even on failure
                            self.healthKitTimestampUpdateQueue.async {
                                self.timeStampsOfBgReadingsCurrentlyBeingSaved.remove(timeStampLastReadingToUpload)
                            }
                            trace("failed store reading in healthkit, error = %{public}@", log: self.log, category: ConstantsLog.categoryHealthKitManager, type: .error, error.localizedDescription)
                        }
                })
            }
        }
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
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.storeReadingsInHealthkitAuthorized.rawValue)
        UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.storeReadingsInHealthkit.rawValue)
    }
}
