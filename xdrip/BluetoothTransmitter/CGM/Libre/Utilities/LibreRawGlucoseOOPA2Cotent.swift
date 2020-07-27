import Foundation

class LibreRawGlucoseOOPA2Cotent: NSObject, Codable {
    
    /// current sensor time
    var currentTime: Int?
    
    /// histories
    var historicBg: [LibreHistoricGlucoseA2]?
    
    /// current glucose value
    var currentBg: Double?
    
    /// description
    override var description: String {
        
        var returnValue = "LibreRawGlucoseOOPA2Cotent = \ncurrentTime = " + (currentTime != nil ? currentTime!.description : "nil") + "\n"
        
        if let historicBg = historicBg {
            
            for bg in historicBg {
                
                returnValue = returnValue + bg.description + "\n"
                
            }
        }
        
        if let currentBg = currentBg {returnValue = returnValue + currentBg.description}
        
        return returnValue
        
    }
    
}

