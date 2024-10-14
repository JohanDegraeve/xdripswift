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
    
    /// converts mgDl to mmol
    func mgDlToMmol() -> Double {
        return self * ConstantsBloodGlucose.mgDlToMmoll
    }
    
    /// converts mgDl to mmol if parameter mgDl = false. If mgDl = true then just returns self
    func mgDlToMmol(mgDl: Bool) -> Double {
        if mgDl {
            return self
        } else {
            return self * ConstantsBloodGlucose.mgDlToMmoll
        }
    }
    
    /// converts mmol to mgDl if parameter mgDl = false. If mgDl = true then just returns self
    func mmolToMgdl(mgDl:Bool) -> Double {
        if mgDl {
            return self
        } else {
            return self.mmolToMgdl()
        }
    }
    
    /// converts mmol to mgDl
    func mmolToMgdl() -> Double {
        return self * ConstantsBloodGlucose.mmollToMgdl
    }
    
    /// returns the value rounded to fractionDigits
    func round(toDecimalPlaces: Int) -> Double {
        let multiplier = pow(10, Double(toDecimalPlaces))
        return Darwin.round(self * multiplier) / multiplier
    }
    
    /// takes self as Double as bloodglucose value, converts value to string, round. Number of digits after decimal seperator depends on the unit. For mg/dl 0 digits after decimal seperator, for mmol, 1 digit after decimal seperator
    func bgValueToString(mgDl:Bool) -> String {
        if mgDl {
            return String(format:"%.0f", self)
        } else {
            return String(format:"%.1f", self)
        }
    }
    
    /// if mgDl, then returns self, unchanged. If not mgDl, return self rounded to 1 decimal place
    func bgValueRounded(mgDl: Bool) -> Double {
        
        if mgDl {
            
            return self.round(toDecimalPlaces: 0)
            
        } else {
            
            return self.round(toDecimalPlaces: 1)
            
        }
        
    }
    
    /// converts mmol to mgdl if parametermgdl = false and, converts value to string, round. Number of digits after decimal seperator depends on the unit. For mg/dl 0 digits after decimal seperator, for mmol, 1 digit after decimal seperator
    ///
    /// this function is actually a combination of mmolToMgDl if mgDl = true and bgValueToString
    func mgDlToMmolAndToString(mgDl: Bool) -> String {
        if mgDl {
            return String(format:"%.0f", self)
        } else {
            return String(format:"%.1f", self.mgDlToMmol())
        }
    }
    
    /// converts mmol value to a string with 1 digit after decimal seperator
    func mmolToString() -> String {
        return String(format:"%.1f", self)
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


