import Foundation

class LibreHistoricGlucoseA2: NSObject, Codable {
    
    /// if quality != 0, it means the value is error
    let quality : Int?
    
    /// the value's sensor time
    let time: Int?
    
    /// glucose value
    let bg : Double?
    
    /// description
    override var description: String {
        
        return "LibreHistoricGlucoseA2 = \nquality = " + (quality != nil ? quality!.description : "nil") + ", time = " + (time != nil ? time!.description : "nil") + ", bg = " + (bg != nil ? bg!.description : "nil")
        
    }
    
}
