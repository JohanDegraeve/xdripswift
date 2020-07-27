import Foundation

/// a readings value, id (time in minutes since sensor start) and dataQuality
class LibreRawGlucoseOOPGlucose: NSObject, Codable {
    
    /// if dataQuality != 0, it means the value is error
    let dataQuality : Int?
    
    /// the time of this reading, in minutes, since sensor start
    let id: Int?
    
    /// glucose value
    let value : Double?
    
    /// description
    override var description: String {
        
        return "LibreRawGlucoseOOPGlucose = \ndataQuality = " + (dataQuality != nil ? dataQuality!.description : "nil") + ", id = " + (id != nil ? id!.description : "nil") + ", value = " + (value != nil ? value!.description : "nil")
        
    }
    
}


