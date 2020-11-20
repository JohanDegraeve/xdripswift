import Foundation
import os

/// housekeeping like remove old readings from coredata
class HouseKeeper {
    
    // MARK: - private properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHouseKeeper)
    
    /// BgReadingsAccessor instance
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// CalibrationsAccessor instance
    private var calibrationsAccessor:CalibrationsAccessor

    // up to which date shall we delete old calibrations
    private var toDate: Date

    // MARK: - intializer
    
    init(bgReadingsAccessor: BgReadingsAccessor, calibrationsAccessor: CalibrationsAccessor) {
        
        self.bgReadingsAccessor = bgReadingsAccessor
        
        self.calibrationsAccessor = calibrationsAccessor
        
        self.toDate = Date(timeIntervalSinceNow: -ConstantsHousekeeping.retentionPeriodBgReadingsInDays*24*3600)
        
    }
    
    // MARK: - public functions
    
    /// housekeeping activities to be done only once per app start up like delete old readings
    public func doAppStartUpHouseKeeping() {
        
        DispatchQueue.global().async {
            
            // delete old readings
            self.deleteOldReadings()
            
            // delete old calibrations
            self.deleteOldCalibrations()
            
        }
    }
    
    // MARK: - private functions
    
    /// deletes old readings. Readings older than ConstantsHousekeeping.retentionPeriodBgReadingsInDays will be deleted
    private func deleteOldReadings() {
        
        // get old readings to delete
        let oldReadings = self.bgReadingsAccessor.getBgReadingsOnPrivateManagedObjectContext(from: nil, to: self.toDate)
        
        if oldReadings.count > 0 {
            
            trace("in deleteOldReadings, number of bg readings to delete : %{public}@, to date = %{public}@", log: self.log, category: ConstantsLog.categoryHouseKeeper, type: .info, oldReadings.count.description, self.toDate.description(with: .current))
            
        }
        
        // delete them
        for oldReading in oldReadings {
            
            bgReadingsAccessor.deleteReadingOnPrivateManagedObjectContext(bgReading: oldReading)
            
        }
        
    }
    
    /// deletes old calibrations. Readings older than ConstantsHousekeeping.retentionPeriodBgReadingsInDays will be deleted
    private func deleteOldCalibrations() {
        
        // get old calibrations to delete
        let oldCalibrations = self.calibrationsAccessor.getCalibrationsOnPrivateManagedObjectContext(from: nil, to: self.toDate)
        
        if oldCalibrations.count > 0 {
            
            trace("in deleteOldCalibrations, number of calibrations candidate for deletion : %{public}@, to date = %{public}@", log: self.log, category: ConstantsLog.categoryHouseKeeper, type: .info, oldCalibrations.count.description, self.toDate.description(with: .current))
            
        }
        
        // for each calibration that doesn't have any bg readings anymore, delete it
        for oldCalibration in oldCalibrations {

            if (oldCalibration.bgreadings.count > 0 ) {

                trace("in deleteOldCalibrations, calibration with date %{public}@ will not be deleted beause there's still %{public}@ bgreadings", log: self.log, category: ConstantsLog.categoryHouseKeeper, type: .info, oldCalibration.timeStamp.description(with: .current), oldCalibration.bgreadings.count.description)

            } else {

                calibrationsAccessor.deleteCalibrationOnPrivateManagedObjectContext(calibration: oldCalibration)

            }
            
        }
        
    }

}
