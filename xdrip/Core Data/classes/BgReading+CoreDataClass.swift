import Foundation
import CoreData
import UIKit

public class BgReading: NSManagedObject {

    /// creates BgReading with given parameters.
    ///
    /// properties that are not in the parameter list get either value 0 or false (depending on type). id gets new value
    init(
        timeStamp:Date,
        sensor:Sensor?,
        calibration:Calibration?,
        rawData:Double,
        deviceName:String?,
        nsManagedObjectContext:NSManagedObjectContext
    ) {
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
    public func log(_ indentation:String) -> String {
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
    
    var mmol: MmolL {
        return MmolL(calculatedValue.mgdlToMmol())
    }
    
    var mgdl: MgDl {
        return MgDl(calculatedValue)
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
    
    /**
     `func` to return the ordinal of the current slope.
     
     This calculates the slope/minute as a `Double` and then returns an ordinal to describe the slope:
     
     slope/minute <= -3.5, Ordinal = 7
     slope/minute <= -2.0, Ordinal = 6
     slope/minute <= -1.0, Ordinal = 5
     slope/minute <= +1.0, Ordinal = 4
     slope/minute <= +2.0, Ordinal = 3
     slope/minute <= +3.5, Ordinal = 2
     slope/minute > +3.5, Ordinal = 1
     
     - Returns: `Int` ordinal.
     */
    func slopeOrdinal() -> Int {
        let slope_by_minute = calculatedValueSlope * 60000
        var ordinal = 0
        if(!hideSlope) {
            if (slope_by_minute <= -3.5) {
                ordinal = 7
            } else if (slope_by_minute <= -2) {
                ordinal = 6
            } else if (slope_by_minute <= -1) {
                ordinal = 5
            } else if (slope_by_minute <= 1) {
                ordinal = 4
            } else if (slope_by_minute <= 2) {
                ordinal = 3
            } else if (slope_by_minute <= 3.5) {
                ordinal = 2
            } else {
                ordinal = 1
            }
        }
        return ordinal
    }
    
    /**
     Creates string with bg value in correct unit or "HIGH" or "LOW", or other like ???
     
     Uses the `calculatedValue` to construct a `String` for displaying the BG reading.
     
     (Internally the `calculatedValue` is stored as mg/dL)
     
     `calculatedValue` >= 400, `String` is the `Texts_Common.HIGH`
     
     `calculatedValue` >= 40, `String` is the value as a formatted `String`
     
     `calculatedValue` >= 12, `String` is the `Texts_Common.LOW`
     
     `calculatedValue` == 0, `String` is `??0`
     
     `calculatedValue` == 1, `String` is `?SN`
     
     `calculatedValue` == 2, `String` is `??2`
     
     `calculatedValue` == 3, `String` is `?NA`
     
     `calculatedValue` == 4, `String` is `???` (no `case` option)
     
     `calculatedValue` == 5, `String` is `?NC`
     
     `calculatedValue` == 6, `String` is `?CD`
     
     `calculatedValue` == 7, `String` is `???` (no `case` option)
     
     `calculatedValue` == 8, `String` is `???` (no `case` option)
     
     `calculatedValue` == 9, `String` is `?AD`
     
     `calculatedValue` == 10, `String` is `???` (no `case` option)
     
     `calculatedValue` == 11, `String` is `???` (no `case` option)
     
     `calculatedValue` == 12, `String` is `?RF`
     
     - Returns: a `String` depending on the current BG value
     */
    static func _unitizedString(calculatedValue: Double, unitIsMgDl:Bool) -> String {
        var returnValue:String
        if (calculatedValue >= 400) {
            // mg/dL definitely too high
            returnValue = Texts_Common.HIGH
        } else if (calculatedValue >= 40) {
            // mg/dL within a displayable range so convert to string dependant on user unit prefs
            returnValue = calculatedValue.mgdlToMmolAndToString(thisIsMgDl: unitIsMgDl)
        } else if (calculatedValue > 12) {
            // mg/dL definitely too low
            returnValue = Texts_Common.LOW
        } else {
            // We have a special case value of <= 12
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
    
    func unitizedString(unitIsMgDl:Bool) -> String {
        return BgReading._unitizedString(calculatedValue: calculatedValue, unitIsMgDl: unitIsMgDl)
    }
    
    /// creates string with difference from previous reading and also unit
    func unitizedDeltaString(previousBgReading:BgReading?, showUnit:Bool, highGranularity:Bool, mgdl:Bool) -> (string: String, doubleValue: Double) {
        
        guard let previousBgReading = previousBgReading else {
            return (string: "???", doubleValue: 0.0)
        }
        
        if timeStamp.timeIntervalSince(previousBgReading.timeStamp) > Double(ConstantsBGGraphBuilder.maxSlopeInMinutes * 60) {
            // don't show delta if there are not enough values or the values are more than 20 mintes apart
            return (string: "???", doubleValue: 0.0)
        }
        
        // delta value recalculated aligned with time difference between previous and this reading
        let value = currentSlope(previousBgReading: previousBgReading) * timeStamp.timeIntervalSince(previousBgReading.timeStamp) * 1000;

        if(abs(value) > 100){
            // a delta > 100 will not happen with real BG values -> problematic sensor data
            return (string: "ERR", doubleValue: 0.0)
        }
        
        let valueAsString = value.mgdlToMmolAndToString(thisIsMgDl: mgdl)
        
        var deltaSign:String = ""
        if (value > 0) { deltaSign = "+"; }
        
        // quickly check "value" and prevent "-0mg/dl" or "-0.0mmol/l" being displayed
        // show unitized zero deltas as +0 or +0.0 as per Nightscout format
        if (value > -1) && (value < 1) {
            return (string: "+0" + (showUnit ? (" " + Texts_Common.UsersUnits):""), doubleValue: 0.0)
        }
        
        return (string: deltaSign + valueAsString + (showUnit ? (" " + Texts_Common.UsersUnits):""), doubleValue: value)
    }
    
    /**
     Convenience function to return only the current slope as a `Double`.
     This `func` calls `calculateSlope(_:)` and then dispenses with the `hideSlope`
     element of the `Tuple`
     
     - Parameter previousBgReading: an `Optional` previous reading.
     - Returns: a `Double` denoting the slope (returns `0.0` is the `previousBgReading` is `nil`)
     */
    func currentSlope(previousBgReading:BgReading?) -> Double {
        
        if let previousBgReading = previousBgReading {
            let (slope,_) = calculateSlope(lastBgReading: previousBgReading);
            return slope
        } else {
            return 0.0
        }

    }

    /**
     Chooses an appropriate `BgRangeDescription` case for the current `calculatedValue`.
     
     - Returns: a case from the `enum` `BgRangeDescription`
     */
    func bgRangeDescription() -> BgRangeDescription {
        
        // Prepare the bgReading value
        let bgValue = self.calculatedValue.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        
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
    
    /**
     Taken over from xdripplus.
     This function takes the current reading and the last reading and divides by the time interval between them (in msecs) to get a slope value.
     
     - Parameter currentBgReading : reading for which slope is calculated
     - Parameter lastBgReading : last reading result of call to BgReadings.getLatestBgReadings(1, sensor) sensor the current sensor and ignore calculatedValue and ignoreRawData both set to false
     
     - Returns: `Tuple (Double, Bool)` containing calculated slope and `hideSlope`. `hideSlope` currently hard-coded to be `false`
     */
    func calculateSlope(lastBgReading:BgReading) -> (Double, Bool) {
        if timeStamp == lastBgReading.timeStamp
            ||
            timeStamp.toMillisecondsAsDouble() - lastBgReading.timeStamp.toMillisecondsAsDouble() > Double(ConstantsBGGraphBuilder.maxSlopeInMinutes * 60 * 1000) {
            return (0,true)
        }
        return ((lastBgReading.calculatedValue - calculatedValue) / (lastBgReading.timeStamp.toMillisecondsAsDouble() - timeStamp.toMillisecondsAsDouble()), false)
    }
    
    /// slopeName for upload to NightScout
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
