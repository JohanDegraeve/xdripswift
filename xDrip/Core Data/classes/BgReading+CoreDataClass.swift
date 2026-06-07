import Foundation
import CoreData
import UIKit

public class BgReading: NSManagedObject {

    /// creates BgReading with given parameters.
    ///
    /// properties that are not in the parameter list get either value 0 or false (depending on type). id gets new value
    init(timeStamp: Date, sensor: Sensor?, calibration:Calibration?, rawData: Double, deviceName: String?, nsManagedObjectContext: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "BgReading", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        self.timeStamp = timeStamp
        self.sensor = sensor
        self.calibration = calibration
        self.rawData = rawData
        self.deviceName = deviceName
        
        ageAdjustedRawValue = 0
        calibrationFlag = false
        calculatedValue = 0
        calculatedValueSlope = 0
        a = 0
        b = 0
        c = 0
        ra = 0
        rb = 0
        rc = 0 
        hideSlope = false
        id = UniqueId.createEventId()
    }

    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    /// log the contents to a string
    public func log(_ indentation: String) -> String {
        var r:String = "bgreading = "
        r += "\n" + indentation + "timestamp = " + timeStamp.description + "\n"
        r += "\n" + indentation + "uniqueid = " + id
        r += "\n" + indentation + "a = " + a.description
        r += "\n" + indentation + "ageAdjustedRawValue = " + ageAdjustedRawValue.description
        r += "\n" + indentation + "b = " + b.description
        r += "\n" + indentation + "c = " + c.description
        r += "\n" + indentation + "calculatedValue = " + calculatedValue.description
        r += "\n" + indentation + "calculatedValueSlope = " + calculatedValueSlope.description
        if let calibration = calibration {
            r += "\n" + indentation + "calibration = " + calibration.log("      ")
        }
        r += "\n" + indentation + "calibrationFlag = " + calibrationFlag.description
        r += "\n" + indentation + "hideSlope = " + hideSlope.description
        r += "\n" + indentation + "ra = " + ra.description
        r += "\n" + indentation + "rawData = " + rawData.description
        r += "\n" + indentation + "rb = " + rb.description
        r += "\n" + indentation + "rc = " + rc.description
        if let sensor = sensor {
            r += "\n" + indentation + "sensor = " + sensor.log(indentation: "      ")
        }
        return r
    }
    
    /// returns a string with an arrow representation of the slope
    func slopeArrow() -> String {
        let slope_by_minute = calculatedValueSlope * 60000
        if (slope_by_minute <= (-3.5)) {
            return "\u{2193}\u{2193}" // ↓↓
        } else if (slope_by_minute <= (-2)) {
            return "\u{2193}" // ↓
        } else if (slope_by_minute <= (-1)) {
            return "\u{2198}" // ↘
        } else if (slope_by_minute <= (1)) {
            return "\u{2192}" // →
        } else if (slope_by_minute <= (2)) {
            return "\u{2197}" // ↗
        } else if (slope_by_minute <= (3.5)) {
            return "\u{2191}" // ↑
        } else {
            return "\u{2191}\u{2191}" // ↑↑
        }
    }
    
    func slopeOrdinal() -> Int {
        let slope_by_minute = calculatedValueSlope * 60000
        var ordinal = 0
        if(!hideSlope) {
            if (slope_by_minute <= (-3.5)) {
                ordinal = 7
            } else if (slope_by_minute <= (-2)) {
                ordinal = 6
            } else if (slope_by_minute <= (-1)) {
                ordinal = 5
            } else if (slope_by_minute <= (1)) {
                ordinal = 4
            } else if (slope_by_minute <= (2)) {
                ordinal = 3
            } else if (slope_by_minute <= (3.5)) {
                ordinal = 2
            } else {
                ordinal = 1
            }
        }
        return ordinal
    }
    
    /// creates string with bg value in correct unit or "HIGH" or "LOW", or other like ???
    func unitizedString(unitIsMgDl: Bool) -> String {
        var returnValue: String
        
        if (calculatedValue >= 400) {
            returnValue = Texts_Common.HIGH
        } else if (calculatedValue >= 40) {
            returnValue = calculatedValue.mgDlToMmolAndToString(mgDl: unitIsMgDl)
        } else if (calculatedValue > 12) {
            returnValue = Texts_Common.LOW
        } else {
            switch(calculatedValue) {
            case 0:
                returnValue = "??0"
                break
            case 1:
                returnValue = "?SN"
                break
            case 2:
                returnValue = "??2"
                break
            case 3:
                returnValue = "?NA"
                break
            case 5:
                returnValue = "?NC"
                break
            case 6:
                returnValue = "?CD"
                break
            case 9:
                returnValue = "?AD"
                break
            case 12:
                returnValue = "?RF"
                break
            default:
                returnValue = "???"
                break
            }
        }
        return returnValue
    }
    
    /// creates string with difference from previous reading and also unit
    func unitizedDeltaString(previousBgReading: BgReading?, showUnit: Bool, highGranularity: Bool, mgDl: Bool) -> String {
        
        guard let previousBgReading = previousBgReading else {
            return "???"
        }
        
        if timeStamp.timeIntervalSince(previousBgReading.timeStamp) > Double(ConstantsBGGraphBuilder.maxSlopeInMinutes * 60) {
            // don't show delta if there are not enough values or the values are more than 20 mintes apart
            return "???"
        }

        var previousValueInUserUnit = previousBgReading.calculatedValue.mgDlToMmol(mgDl: mgDl)
        var actualValueInUserUnit = calculatedValue.mgDlToMmol(mgDl: mgDl)
        
        // if the values are in mmol/L, then round them to the nearest decimal point in order to get the same precision out of the next operation
        if !mgDl {
            previousValueInUserUnit = (previousValueInUserUnit * 10).rounded() / 10
            actualValueInUserUnit = (actualValueInUserUnit * 10).rounded() / 10
        }
        
        let deltaValueInUserUnit = actualValueInUserUnit - previousValueInUserUnit
        
        // a delta > 100mg/dL will not happen with real BG values -> problematic sensor data
        if abs(deltaValueInUserUnit.mmolToMgdl(mgDl: mgDl)) > 100 {
            return "ERR"
        }
        
        // let's carefully convert the delta value into a string
        // if in mmol/L, then use a different function to keep everything aligned
        let deltaValueAsString = mgDl ? deltaValueInUserUnit.mgDlToMmolAndToString(mgDl: mgDl) : deltaValueInUserUnit.mmolToString()
        
        var deltaSign: String = ""
        
        if deltaValueInUserUnit > 0 {
            deltaSign = "+"
        }
        
        // quickly check "value" and prevent "-0mg/dl" or "-0.0mmol/l" being displayed
        // show unitized zero deltas as +0 or +0.0 as per Nightscout format
        if deltaValueInUserUnit == 0.0 {
            return (mgDl ? "+0" : "+0.0") + (showUnit ? (" " + (mgDl ? Texts_Common.mgdl : Texts_Common.mmol)) : "")
        } else {
            return deltaSign + deltaValueAsString + (showUnit ? (" " + (mgDl ? Texts_Common.mgdl : Texts_Common.mmol)) : "")
        }
    }
    
    func currentSlope(previousBgReading: BgReading?) -> Double {
        
        if let previousBgReading = previousBgReading {
            let (slope,_) = calculateSlope(lastBgReading: previousBgReading)
            return slope
        } else {
            return 0.0
        }

    }
    
    /// Return the BgRange description/type of the current BgReading value based on the configured objectives
    func bgRangeDescription() -> BgRangeDescription {
        
        // Prepare the bgReading value
        let bgValue = self.calculatedValue.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        
        if (bgValue >= UserDefaults.standard.urgentHighMarkValueInUserChosenUnit
            || bgValue <= UserDefaults.standard.urgentLowMarkValueInUserChosenUnit){
            // BG is higher than urgentHigh or lower than urgentLow objectives
            return BgRangeDescription.urgent
        }
        
        if (bgValue >= UserDefaults.standard.highMarkValueInUserChosenUnit
            || bgValue <= UserDefaults.standard.lowMarkValueInUserChosenUnit){
            // BG is between urgentHigh/high and low/urgentLow objectives
            return BgRangeDescription.notUrgent
        }
        
        // BG is not high or low so considered "in range"
        return BgRangeDescription.inRange
    }
    
    /// taken over form xdripplus
    ///
    /// - parameters:
    ///     - currentBgReading : reading for which slope is calculated
    ///     - lastBgReading : last reading result of call to BgReadings.getLatestBgReadings(1, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false
    /// - returns:
    ///     - calculated slope and hideSlope
    func calculateSlope(lastBgReading:BgReading) -> (Double, Bool) {
        if timeStamp == lastBgReading.timeStamp || timeStamp.toMillisecondsAsDouble() - lastBgReading.timeStamp.toMillisecondsAsDouble() > Double(ConstantsBGGraphBuilder.maxSlopeInMinutes * 60 * 1000) {
            return (0, true)
        }
        
        return ((lastBgReading.calculatedValue - calculatedValue) / (lastBgReading.timeStamp.toMillisecondsAsDouble() - timeStamp.toMillisecondsAsDouble()), false)
    }
    
    /// slopeName for upload to Nightscout
    public var slopeName:String {
        let slope_by_minute:Double = calculatedValueSlope * 60000
        var arrow = "NONE"
        if (slope_by_minute <= (-3.5)) {
            arrow = "DoubleDown" // ↓↓
        } else if (slope_by_minute <= (-2)) {
            arrow = "SingleDown" // ↓
        } else if (slope_by_minute <= (-1)) {
            arrow = "FortyFiveDown" // ↘
        } else if (slope_by_minute <= (1)) {
            arrow = "Flat" // →
        } else if (slope_by_minute <= (2)) {
            arrow = "FortyFiveUp" // ↗
        } else if (slope_by_minute <= (3.5)) {
            arrow = "SingleUp" // ↑
        } else if (slope_by_minute <= (40)) {
            arrow = "DoubleUp" // ↑↑
        }
        
        if(hideSlope) {
            arrow = "NOT COMPUTABLE"
        }
        return arrow
    }
}

// MARK: - SNAPSHOT STRUCT

/// Thread/Queue-safe snapshot of a BgReading (detached from Core Data)
public struct BgReadingSnapshot: Sendable {
    public let timeStamp: Date
    public let calculatedValue: Double
    public let rawData: Double
    public let sensorID: String?
    public let objectID: NSManagedObjectID
}
