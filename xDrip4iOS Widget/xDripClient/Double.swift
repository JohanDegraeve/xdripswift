import Foundation

extension Double {
    
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
    
    /// converts mgdl to mmol
    func mgdlToMmol() -> Double {
        return self * ConstantsBloodGlucose.mgDlToMmoll
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
    
}
