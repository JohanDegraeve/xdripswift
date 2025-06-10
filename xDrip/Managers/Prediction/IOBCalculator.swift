import Foundation
import CoreData
import os.log

/// Calculates Insulin on Board (IOB) from treatment entries
public class IOBCalculator {
    
    /// Log for IOB calculations
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: "IOBCalculator")
    
    /// Core data manager for accessing treatments
    private let coreDataManager: CoreDataManager
    
    /// Treatment entry accessor
    private let treatmentEntryAccessor: TreatmentEntryAccessor
    
    public init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
    }
    
    /// Calculate current IOB at a specific time
    /// - Parameters:
    ///   - at: Time to calculate IOB for
    ///   - insulinType: Type of insulin to use for calculations
    ///   - insulinSensitivity: ISF in mg/dL per unit
    /// - Returns: IOB value with associated insulin activity
    public func calculateIOB(at date: Date, insulinType: InsulinType, insulinSensitivity: Double) -> IOBValue {
        let profile = insulinType.profile
        let cutoffTime = date.addingTimeInterval(-profile.durationMinutes * 60)
        
        // Get all treatments within the DIA window
        let allTreatments = treatmentEntryAccessor.getTreatments(
            fromDate: cutoffTime,
            toDate: date,
            on: coreDataManager.privateManagedObjectContext
        )
        
        // Filter for insulin treatments only
        let insulinTreatments = allTreatments.filter { $0.treatmentType == .Insulin }
        
        var totalIOB: Double = 0.0
        var totalActivity: Double = 0.0
        
        for treatment in insulinTreatments {
            let treatmentDate = treatment.date
            let units = treatment.value
            
            guard units > 0 else { continue }
            
            let minutesAgo = date.timeIntervalSince(treatmentDate) / 60.0
            
            // Skip if outside of DIA window
            guard minutesAgo >= 0 && minutesAgo <= profile.durationMinutes else { continue }
            
            // Calculate remaining IOB for this bolus
            let iobFraction = profile.iobFraction(at: minutesAgo)
            let remainingUnits = units * iobFraction
            totalIOB += remainingUnits
            
            // Calculate current activity for this bolus
            let activityFraction = profile.activity(at: minutesAgo)
            let bolusActivity = units * activityFraction
            totalActivity += bolusActivity
        }
        
        // Calculate glucose impact
        // Activity represents the current rate of insulin action
        // Convert to glucose drop rate (mg/dL per minute)
        let glucoseDropRatePerMinute = totalActivity * insulinSensitivity / profile.durationMinutes
        
        os_log("IOB Calculation - Total IOB: %{public}.2f units, Activity: %{public}.2f units/hr, Glucose drop rate: %{public}.2f mg/dL/min",
               log: log, type: .info, totalIOB, totalActivity * 60, glucoseDropRatePerMinute)
        
        return IOBValue(
            iob: totalIOB,
            activity: totalActivity,
            glucoseDropRatePerMinute: glucoseDropRatePerMinute,
            lastCalculated: date
        )
    }
    
    /// Calculate IOB curve for prediction
    /// - Parameters:
    ///   - from: Start time
    ///   - duration: Duration to calculate for
    ///   - interval: Time interval between calculations (default 5 minutes)
    ///   - insulinType: Type of insulin
    ///   - insulinSensitivity: ISF in mg/dL per unit
    /// - Returns: Array of IOB values over time
    public func calculateIOBCurve(
        from startDate: Date,
        duration: TimeInterval,
        interval: TimeInterval = 300, // 5 minutes
        insulinType: InsulinType,
        insulinSensitivity: Double
    ) -> [IOBValue] {
        
        var iobCurve: [IOBValue] = []
        var currentTime = startDate
        let endTime = startDate.addingTimeInterval(duration)
        
        while currentTime <= endTime {
            let iobValue = calculateIOB(at: currentTime, insulinType: insulinType, insulinSensitivity: insulinSensitivity)
            iobCurve.append(iobValue)
            currentTime = currentTime.addingTimeInterval(interval)
        }
        
        return iobCurve
    }
}

/// Represents IOB value at a point in time
public struct IOBValue {
    /// Total insulin on board in units
    public let iob: Double
    
    /// Current insulin activity (units per hour)
    public let activity: Double
    
    /// Rate of glucose drop in mg/dL per minute
    public let glucoseDropRatePerMinute: Double
    
    /// When this IOB was calculated
    public let lastCalculated: Date
    
    /// Total expected glucose drop from current IOB
    public var totalExpectedGlucoseDrop: Double {
        // This is a simplified calculation
        // In reality, would need to integrate the remaining activity curve
        return iob * UserDefaults.standard.insulinSensitivityMgDl
    }
}