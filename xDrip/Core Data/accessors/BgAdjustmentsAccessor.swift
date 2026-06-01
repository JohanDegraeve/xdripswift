//
//  BgAdjustmentsAccessor.swift
//  xdrip
//
//  Created by Paul Plant on 1/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData
import os

/// accessor for creating, fetching and disabling stored glucose adjustment entries
class BgAdjustmentsAccessor {
    
    // MARK: - Properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataCalibrations)
    
    /// CoreDataManager to use
    private let coreDataManager: CoreDataManager
    
    // MARK: - initializer
    
    init(coreDataManager: CoreDataManager) {
        
        self.coreDataManager = coreDataManager
        
    }
    
    // MARK: - functions
    
    func createBgAdjustment(timeStamp: Date, applyFromTimeStamp: Date, slope: Double, intercept: Double, adjustmentShapeType: Int16, isEnabled: Bool, isBasicAdjustment: Bool, enteredBgValue: Double?, sourceCalculatedValue: Double?, sourceDescription: String?, sourceContextIdentifier: String, on managedObjectContext: NSManagedObjectContext) -> BgAdjustment {
        return BgAdjustment(timeStamp: timeStamp, applyFromTimeStamp: applyFromTimeStamp, slope: slope, intercept: intercept, adjustmentShapeType: adjustmentShapeType, isEnabled: isEnabled, isBasicAdjustment: isBasicAdjustment, enteredBgValue: enteredBgValue, sourceCalculatedValue: sourceCalculatedValue, sourceDescription: sourceDescription, sourceContextIdentifier: sourceContextIdentifier, nsManagedObjectContext: managedObjectContext)
    }
    
    func latestActiveBgAdjustment(forSourceContextIdentifier sourceContextIdentifier: String, on managedObjectContext: NSManagedObjectContext) -> BgAdjustment? {
        let fetchRequest: NSFetchRequest<BgAdjustment> = BgAdjustment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgAdjustment.timeStamp), ascending: false)]
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "sourceContextIdentifier == %@", sourceContextIdentifier),
            NSPredicate(format: "isEnabled == %@", NSNumber(value: true))
        ])
        
        var bgAdjustments = [BgAdjustment]()
        
        managedObjectContext.performAndWait {
            do {
                bgAdjustments = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in latestActiveBgAdjustment, Unable to Execute BgAdjustment Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataCalibrations, type: .error, fetchError.localizedDescription)
            }
        }
        
        return bgAdjustments.first
    }
    
    func latestApplicableBgAdjustment(forSourceContextIdentifier sourceContextIdentifier: String, readingTimeStamp: Date, on managedObjectContext: NSManagedObjectContext) -> BgAdjustment? {
        let fetchRequest: NSFetchRequest<BgAdjustment> = BgAdjustment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgAdjustment.applyFromTimeStamp), ascending: false)]
        fetchRequest.fetchLimit = 1
        // We want the newest enabled adjustment whose applyFromTimeStamp is not
        // later than the reading we are evaluating.
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "sourceContextIdentifier == %@", sourceContextIdentifier),
            NSPredicate(format: "isEnabled == %@", NSNumber(value: true)),
            NSPredicate(format: "applyFromTimeStamp <= %@", NSDate(timeIntervalSince1970: readingTimeStamp.timeIntervalSince1970))
        ])
        
        var bgAdjustments = [BgAdjustment]()
        
        managedObjectContext.performAndWait {
            do {
                bgAdjustments = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in latestApplicableBgAdjustment, Unable to Execute BgAdjustment Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataCalibrations, type: .error, fetchError.localizedDescription)
            }
        }
        
        return bgAdjustments.first
    }
    
    func getBgAdjustments(forSourceContextIdentifier sourceContextIdentifier: String, on managedObjectContext: NSManagedObjectContext) -> [BgAdjustment] {
        let fetchRequest: NSFetchRequest<BgAdjustment> = BgAdjustment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgAdjustment.applyFromTimeStamp), ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "sourceContextIdentifier == %@", sourceContextIdentifier)
        
        var bgAdjustments = [BgAdjustment]()
        
        managedObjectContext.performAndWait {
            do {
                bgAdjustments = try fetchRequest.execute()
            } catch {
                let fetchError = error as NSError
                trace("in getBgAdjustments, Unable to Execute BgAdjustment Fetch Request : %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataCalibrations, type: .error, fetchError.localizedDescription)
            }
        }
        
        return bgAdjustments
    }

    func disableBgAdjustments(forSourceContextIdentifier sourceContextIdentifier: String, fromApplyFromTimeStamp applyFromTimeStamp: Date, on managedObjectContext: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<BgAdjustment> = BgAdjustment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BgAdjustment.applyFromTimeStamp), ascending: true)]
        // When a new adjustment is created for a time window, any later enabled
        // adjustments in the same source context should no longer apply.
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: [
            NSPredicate(format: "sourceContextIdentifier == %@", sourceContextIdentifier),
            NSPredicate(format: "isEnabled == %@", NSNumber(value: true)),
            NSPredicate(format: "applyFromTimeStamp >= %@", NSDate(timeIntervalSince1970: applyFromTimeStamp.timeIntervalSince1970))
        ])

        managedObjectContext.performAndWait {
            do {
                let bgAdjustments = try fetchRequest.execute()

                for bgAdjustment in bgAdjustments {
                    bgAdjustment.isEnabled = false
                }

                if bgAdjustments.count > 0 {
                    try managedObjectContext.save()
                }
            } catch {
                trace("in disableBgAdjustments, Unable to Save Changes, error.localizedDescription  = %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataCalibrations, type: .error, error.localizedDescription)
            }
        }
    }
    
    func disable(bgAdjustment: BgAdjustment, on managedObjectContext: NSManagedObjectContext) {
        managedObjectContext.performAndWait {
            bgAdjustment.isEnabled = false
            
            do {
                try managedObjectContext.save()
            } catch {
                trace("in disable bgAdjustment, Unable to Save Changes, error.localizedDescription  = %{public}@", log: self.log, category: ConstantsLog.categoryApplicationDataCalibrations, type: .error, error.localizedDescription)
            }
        }
    }
}
