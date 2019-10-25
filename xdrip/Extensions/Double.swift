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
    func roundToDecimal(_ fractionDigits: Int) -> Double {
        let multiplier = pow(10, Double(fractionDigits))
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
    
}


