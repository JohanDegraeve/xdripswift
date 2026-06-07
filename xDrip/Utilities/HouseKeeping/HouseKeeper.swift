import Foundation
import os
import CoreData

/// housekeeping like remove old readings from coredata
class HouseKeeper {
    
    // MARK: - private properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHouseKeeper)
    
    /// BgReadingsAccessor instance
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// CalibrationsAccessor instance
    private var calibrationsAccessor:CalibrationsAccessor
    
    /// TreatmentEntryAccessor instance
    private var treatmentsEntryAccessor: TreatmentEntryAccessor
    
    /// CoreDataManager instance
    private var coreDataManager: CoreDataManager

    // up to which date shall we delete old calibrations
    private var toDate: Date

    // MARK: - intializer
    
    init(coreDataManager: CoreDataManager) {
        
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        self.calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        
        self.treatmentsEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
        
        self.coreDataManager = coreDataManager
        
        self.toDate = Date(timeIntervalSinceNow: -Double(UserDefaults.standard.retentionPeriodInDays*24*3600))
        
    }
    
    // MARK: - public functions
    
    /// - housekeeping activities to be done only once per app start up like delete old readings and calibrations in CoreData
    /// - cleanups are done asynchronously (ie function returns without waiting for the actual deletions
    public func doAppStartUpHouseKeeping() {
        
        // create private managed object context
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.parent = coreDataManager.mainManagedObjectContext

        // delete old readings on the private managedObjectContext, asynchronously
        managedObjectContext.perform {
            
            // delete old readings
            self.deleteOldReadings(on: managedObjectContext)
            
        }
        
        // delete old calibrations on the private managedObjectContext, asynchronously
        managedObjectContext.perform {
            
            // delete old calibrations
            self.deleteOldCalibrations(on: managedObjectContext)
            
        }
        
        // delete delete OldTreatments on the private managedObjectContext, asynchronously
        managedObjectContext.perform {
            
            // delete  delete OldTreatments
            self.deleteOldTreatments(on: managedObjectContext)
            
        }
        
    }
    
    // MARK: - private functions
    
    /// deletes old readings. Readings older than ConstantsHousekeeping.retentionPeriodBgReadingsAndCalibrationsAndTreatmentsInDays will be deleted
    ///     - managedObjectContext : the ManagedObjectContext to use
    private func deleteOldReadings(on managedObjectContext: NSManagedObjectContext) {
        
        // get old readings to delete
        let oldReadings = self.bgReadingsAccessor.getBgReadings(from: nil, to: self.toDate, on: managedObjectContext)
        
        if oldReadings.count > 0 {
            
            trace("in deleteOldReadings, number of bg readings to delete : %{public}@, to date = %{public}@", log: self.log, category: ConstantsLog.categoryHouseKeeper, type: .info, oldReadings.count.description, self.toDate.description(with: .current))
            
        }
        
        // delete them
        for oldReading in oldReadings {
            
            bgReadingsAccessor.delete(bgReading: oldReading, on: managedObjectContext)
            
            coreDataManager.saveChanges()
            
        }
        
    }
    
    /// deletes old calibrations. Readings older than ConstantsHousekeeping.retentionPeriodBgReadingsAndCalibrationsAndTreatmentsInDays will be deleted
    private func deleteOldCalibrations(on managedObjectContext: NSManagedObjectContext) {
        
        // get old calibrations to delete
        let oldCalibrations = self.calibrationsAccessor.getCalibrations(from: nil, to: self.toDate, on: managedObjectContext)
        
        if oldCalibrations.count > 0 {
            
            trace("in deleteOldCalibrations, number of calibrations candidate for deletion : %{public}@, to date = %{public}@", log: self.log, category: ConstantsLog.categoryHouseKeeper, type: .info, oldCalibrations.count.description, self.toDate.description(with: .current))
            
        }
        
        // for each calibration that doesn't have any bg readings anymore, delete it
        for oldCalibration in oldCalibrations {

            if (oldCalibration.bgreadings.count > 0 ) {

                trace("in deleteOldCalibrations, calibration with date %{public}@ will not be deleted beause there's still %{public}@ bgreadings", log: self.log, category: ConstantsLog.categoryHouseKeeper, type: .info, oldCalibration.timeStamp.description(with: .current), oldCalibration.bgreadings.count.description)

            } else {

                calibrationsAccessor.delete(calibration: oldCalibration, on: managedObjectContext)
                
                coreDataManager.saveChanges()

            }
            
        }
        
    }
    
    /// deletes old treatments. Treatments older than ConstantsHousekeeping.retentionPeriodBgReadingsAndCalibrationsAndTreatmentsInDays will be deleted
    ///     - managedObjectContext : the ManagedObjectContext to use
    private func deleteOldTreatments(on managedObjectContext: NSManagedObjectContext) {
        
        // get old treatments to delete
        let oldTreatments = self.treatmentsEntryAccessor.getTreatments(fromDate: nil, toDate: Date(timeIntervalSinceNow: -Double(UserDefaults.standard.retentionPeriodInDays*24*3600)), on: managedObjectContext)
        
        if oldTreatments.count > 0 {
            
            trace("in deleteOldTreatments, number of treatments to delete : %{public}@, to date = %{public}@", log: self.log, category: ConstantsLog.categoryHouseKeeper, type: .info, oldTreatments.count.description, self.toDate.description(with: .current))
            
        }
        
        // delete them
        for oldTreatment in oldTreatments {
            
            treatmentsEntryAccessor.delete(treatmentEntry: oldTreatment, on: managedObjectContext)
            
            coreDataManager.saveChanges()
            
        }
        
    }
    


}
