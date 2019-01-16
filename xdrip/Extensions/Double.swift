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
}
