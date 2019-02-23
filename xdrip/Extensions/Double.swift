import Foundation

extension Double {
    /// converts mgdl to mmol
    func mgdlToMmol() -> Double {
        return self * Constants.BloodGlucose.mgDlToMmoll
    }
    
    /// converts mmol to mgdl
    func mmolToMgdl() -> Double {
        return self * Constants.BloodGlucose.mmollToMgdl
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
}


