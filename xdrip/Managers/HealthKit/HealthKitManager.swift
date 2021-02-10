import Foundation
import os
import HealthKit

public class HealthKitManager:NSObject {
    // MARK: - public properties
    
    // MARK: - private properties
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHealthKitManager)
    
    /// reference to coredatamanager
    private var coreDataManager:CoreDataManager
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// is healthkit fully initiazed or not, that includes checking if healthkit is available, created successfully bloodGlucoseType, user authorized - value will get changed 
    private var healthKitInitialized = false
    
    /// bloodGlucoseType - optional because if hk not available it can be initialized
    private var bloodGlucoseType:HKQuantityType?
    
    /// reference to HKHealthStore, should be used only if we're sure HealthKit is supported on the device
    private lazy var healthStore = HKHealthStore()
    
    // MARK: - intialization
    
    init(coreDataManager:CoreDataManager) {
        
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        // call super.init
        super.init()
        
        // listen for changes to userdefaults storeReadingsInHealthkitAuthorized
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.storeReadingsInHealthkitAuthorized.rawValue, options: .new
            , context: nil)
        // listen for changes to userdefaults storeReadingsInHealthkit
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.storeReadingsInHealthkit.rawValue, options: .new
            , context: nil)

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
        guard let bloodGlucoseType = bloodGlucoseType else {return false}
        
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
            trace("unknown authorizationstatus for healthkit - HealthKitManager.swift", log: self.log, category: ConstantsLog.categoryHealthKitManager, type: .error)
        }
        
        // all checks ok , return true
        return true
    }
    
    /// stores latest readings in healthkit, only if HK supported, authorized, enabled in settings
    public func storeBgReadings() {
        
        // healthkit setting must be on, and healthkit must be initialized successfully
        if !UserDefaults.standard.storeReadingsInHealthkit || !healthKitInitialized {
            return
        }
        
        // bloodGlucoseType should not be nil
        guard let bloodGlucoseType = bloodGlucoseType else {return}
        
          // get readings to store, limit to 2016 = maximum 1 week - just to avoid a huge array is being returned here, applying minimumTimeBetweenTwoReadingsInMinutes filter
        let bgReadingsToStore = bgReadingsAccessor.getLatestBgReadings(limit: 2016, fromDate: UserDefaults.standard.timeStampLatestHealthKitStoreBgReading, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false).filter(minimumTimeBetweenTwoReadingsInMinutes: ConstantsHealthKit.minimiumTimeBetweenTwoReadingsInMinutes, lastConnectionStatusChangeTimeStamp: nil, timeStampLastProcessedBgReading: UserDefaults.standard.timeStampLatestHealthKitStoreBgReading)
        
        let bloodGlucoseUnit = HKUnit.init(from: "mg/dL")
        
        if bgReadingsToStore.count > 0 {

            for (_, bgReading) in bgReadingsToStore.enumerated().reversed() {// reversed order because the first element is the youngest
                
                let quantity = HKQuantity.init(unit: bloodGlucoseUnit, doubleValue: bgReading.calculatedValue)
                let sample = HKQuantitySample.init(type: bloodGlucoseType, quantity: quantity, start: bgReading.timeStamp, end: bgReading.timeStamp)
                
                // store the timestamp of the last reading to upload, here in the main thread, because we use a bgReading for it, which is retrieved in the main mangedObjectContext
                let timeStampLastReadingToUpload = bgReading.timeStamp
                
                healthStore.save(sample, withCompletion: {
                    (success:Bool, error:Error?) in
                    if success {
                        UserDefaults.standard.timeStampLatestHealthKitStoreBgReading = timeStampLastReadingToUpload
                    } else {
                        if let error = error {
                            trace("failed store reading in healthkit, error = %{public}@", log: self.log, category: ConstantsLog.categoryHealthKitManager, type: .error, error.localizedDescription)
                        }
                    }
                })
            }
        }
    }
    
    // MARK:- observe function
    
    /// when UserDefaults storeReadingsInHealthkitAuthorized or storeReadingsInHealthkit changes, then reinitialize the property healthKitInitialized
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.storeReadingsInHealthkitAuthorized, UserDefaults.Key.storeReadingsInHealthkit :
                    
                    // check latest change, to avoid there's an endless loop, because initializeHealthKit is actually setting value of storeReadingsInHealthkitAuthorized
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 100)) {
                        
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
}
