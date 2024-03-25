import Foundation

extension Double: RawRepresentable {

    //MARK: - copied from https://github.com/LoopKit/LoopKit
    
    public typealias RawValue = Double
    
    public init?(rawValue: RawValue) {
        self = rawValue
    }
    
    public var rawValue: RawValue {
        return self
    }
    
    // MARK: - own code
	
	/// Converts to a string and removes trailing .0
	public var stringWithoutTrailingZeroes: String {
		var description = String(self.description)
		// Checks if ends with .0 and removes if so
		if description.suffix(2) == ".0" {
			description = String(description.dropLast(2))
		}
		return description
	}
    
    /// converts mgdl to mmol
    func mgdlToMmol() -> Double {
        return self * ConstantsBloodGlucose.mgDlToMmoll
    }
    
    /// converts mgdl to mmol if parameter mgdl = false. If mgdl = true then just returns self
    func mgdlToMmol(mgdl:Bool) -> Double {
        if mgdl {
            return self
        } else {
            return self * ConstantsBloodGlucose.mgDlToMmoll
        }
    }
    
    /// converts mmol to mgdl if parameter mgdl = false. If mgdl = true then just returns self
    func mmolToMgdl(mgdl:Bool) -> Double {
        if mgdl {
            return self
        } else {
            return self.mmolToMgdl()
        }
    }
    
    /// converts mmol to mgdl
    func mmolToMgdl() -> Double {
        return self * ConstantsBloodGlucose.mmollToMgdl
    }
    
    /// returns the value rounded to fractionDigits
    func round(toDecimalPlaces: Int) -> Double {
        let multiplier = pow(10, Double(toDecimalPlaces))
        return Darwin.round(self * multiplier) / multiplier
    }
    
    /// takes self as Double as bloodglucose value, converts value to string, round. Number of digits after decimal seperator depends on the unit. For mg/dl 0 digits after decimal seperator, for mmol, 1 digit after decimal seperator
    func bgValuetoString(mgdl:Bool) -> String {
        if mgdl {
            return String(format:"%.0f", self)
        } else {
            return String(format:"%.1f", self)
        }
    }
    
    /// if mgdl, then returns self, unchanged. If not mgdl, return self rounded to 1 decimal place
    func bgValueRounded(mgdl: Bool) -> Double {
        
        if mgdl {
            
            return self.round(toDecimalPlaces: 0)
            
        } else {
            
            return self.round(toDecimalPlaces: 1)
            
        }
        
    }
    
    /// converts mmol to mgdl if parametermgdl = false and, converts value to string, round. Number of digits after decimal seperator depends on the unit. For mg/dl 0 digits after decimal seperator, for mmol, 1 digit after decimal seperator
    ///
    /// this function is actually a combination of mmolToMgdl if mgdl = true and bgValuetoString
    func mgdlToMmolAndToString(mgdl:Bool) -> String {
        if mgdl {
            return String(format:"%.0f", self)
        } else {
            return String(format:"%.1f", self.mgdlToMmol())
        }
    }
    
    /// treats the double as timestamp in milliseconds, since 1970 and prints as date string
    func asTimeStampInMilliSecondsToString() -> String {
        let asDate = Date(timeIntervalSince1970: self/1000)
        return asDate.description(with: .current)
    }
    
    /// returns the Nightscout style string showing the days and hours for the number of minutes
    /// Example: 9300.minutesToDaysAndHours() would return -> "6d11h"
    /// Example: 78.minutesToDaysAndHours() would return -> "1h18m"
    /// Example: 12.minutesToDaysAndHours() would return -> "12m"
    func minutesToDaysAndHours() -> String {
        
        // set a default value assuming that we're unable to calculate the hours + days
        var daysAndHoursString: String = "n/a"
                
        let days = Int(floor(self / (24 * 60)))
        let hours = Int(self.truncatingRemainder(dividingBy: 24 * 60) / 60)
        let minutes = Int(self.truncatingRemainder(dividingBy: 24 * 60 * 60)) - (hours * 60)
        
        if days == 0 && hours < 1 {
            
            // show just minutes for less than one hour
            daysAndHoursString = abs(minutes).description + "m"
            
        } else if days == 0 && hours < 12 {
            
            // show just hours and minutes for less than twelve hours
            daysAndHoursString = abs(hours).description + "h" + abs(minutes).description + "m"
            
        } else {
            
            // default show days and hours
            daysAndHoursString = Int(days).description + "d" + Int(hours).description + "h"
            
        }
        

        return daysAndHoursString
        
    }
    
}


