import Foundation
import CoreData
import os.log

/// Calculates Carbs on Board (COB) from treatment entries
public class COBCalculator {
    
    /// Log for COB calculations
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: "COBCalculator")
    
    /// Core data manager for accessing treatments
    private let coreDataManager: CoreDataManager
    
    /// Treatment entry accessor
    private let treatmentEntryAccessor: TreatmentEntryAccessor
    
    public init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
    }
    
    /// Calculate current COB at a specific time
    /// - Parameters:
    ///   - at: Time to calculate COB for
    ///   - absorptionRate: Carb absorption rate in grams per hour
    ///   - delay: Initial delay before absorption starts (minutes)
    ///   - carbRatio: Grams of carbs per unit of insulin (for glucose impact)
    ///   - insulinSensitivity: ISF in mg/dL per unit (for glucose impact)
    /// - Returns: COB value with associated glucose impact
    public func calculateCOB(
        at date: Date,
        absorptionRate: Double,
        delay: Double,
        carbRatio: Double,
        insulinSensitivity: Double
    ) -> COBValue {
        
        // Maximum time to look back for carbs (6 hours should cover most meals)
        let maxAbsorptionTime: TimeInterval = 6 * 3600
        let cutoffTime = date.addingTimeInterval(-maxAbsorptionTime)
        
        // Get all treatments within the window
        let allTreatments = treatmentEntryAccessor.getTreatments(
            fromDate: cutoffTime,
            toDate: date,
            on: coreDataManager.privateManagedObjectContext
        )
        
        // Filter for carb treatments only
        let carbTreatments = allTreatments.filter { $0.treatmentType == .Carbs }
        
        var totalCOB: Double = 0.0
        var totalAbsorptionRate: Double = 0.0
        
        for treatment in carbTreatments {
            let treatmentDate = treatment.date
            let carbs = treatment.value
            
            guard carbs > 0 else { continue }
            
            let minutesAgo = date.timeIntervalSince(treatmentDate) / 60.0
            
            // Skip if in delay period
            guard minutesAgo >= delay else {
                // All carbs still on board during delay
                totalCOB += carbs
                continue
            }
            
            // Calculate absorbed carbs using linear absorption model
            let minutesSinceAbsorptionStarted = minutesAgo - delay
            let hoursAbsorbing = minutesSinceAbsorptionStarted / 60.0
            let carbsAbsorbed = min(carbs, hoursAbsorbing * absorptionRate)
            let carbsRemaining = carbs - carbsAbsorbed
            
            if carbsRemaining > 0 {
                totalCOB += carbsRemaining
                // This entry is still absorbing at the standard rate
                totalAbsorptionRate += min(absorptionRate, carbsRemaining * 60 / 60) // Convert to g/min
            }
        }
        
        // Calculate glucose impact
        // Carbs raise glucose based on carb ratio and insulin sensitivity
        // 1g carb requires 1/carbRatio units of insulin
        // 1 unit of insulin drops glucose by insulinSensitivity mg/dL
        // Therefore, 1g carb raises glucose by insulinSensitivity/carbRatio mg/dL
        let glucosePerGramCarb = insulinSensitivity / carbRatio
        let glucoseRiseRatePerMinute = (totalAbsorptionRate / 60.0) * glucosePerGramCarb
        
        os_log("COB Calculation - Total COB: %{public}.1f g, Absorption rate: %{public}.1f g/hr, Glucose rise rate: %{public}.2f mg/dL/min",
               log: log, type: .info, totalCOB, totalAbsorptionRate, glucoseRiseRatePerMinute)
        
        return COBValue(
            cob: totalCOB,
            absorptionRate: totalAbsorptionRate,
            glucoseRiseRatePerMinute: glucoseRiseRatePerMinute,
            lastCalculated: date
        )
    }
    
    /// Calculate COB curve for prediction
    /// - Parameters:
    ///   - from: Start time
    ///   - duration: Duration to calculate for
    ///   - interval: Time interval between calculations (default 5 minutes)
    ///   - absorptionRate: Carb absorption rate in grams per hour
    ///   - delay: Initial delay before absorption starts
    ///   - carbRatio: ICR
    ///   - insulinSensitivity: ISF
    /// - Returns: Array of COB values over time
    public func calculateCOBCurve(
        from startDate: Date,
        duration: TimeInterval,
        interval: TimeInterval = 300, // 5 minutes
        absorptionRate: Double,
        delay: Double,
        carbRatio: Double,
        insulinSensitivity: Double
    ) -> [COBValue] {
        
        var cobCurve: [COBValue] = []
        var currentTime = startDate
        let endTime = startDate.addingTimeInterval(duration)
        
        while currentTime <= endTime {
            let cobValue = calculateCOB(
                at: currentTime,
                absorptionRate: absorptionRate,
                delay: delay,
                carbRatio: carbRatio,
                insulinSensitivity: insulinSensitivity
            )
            cobCurve.append(cobValue)
            currentTime = currentTime.addingTimeInterval(interval)
        }
        
        return cobCurve
    }
}

/// Represents COB value at a point in time
public struct COBValue {
    /// Total carbs on board in grams
    public let cob: Double
    
    /// Current carb absorption rate (grams per hour)
    public let absorptionRate: Double
    
    /// Rate of glucose rise in mg/dL per minute
    public let glucoseRiseRatePerMinute: Double
    
    /// When this COB was calculated
    public let lastCalculated: Date
    
    /// Total expected glucose rise from current COB
    public var totalExpectedGlucoseRise: Double {
        // Simplified calculation
        let carbRatio = UserDefaults.standard.carbRatio
        let insulinSensitivity = UserDefaults.standard.insulinSensitivityMgDl
        return cob * (insulinSensitivity / carbRatio)
    }
}