import Foundation

class LibreRawGlucoseOOPA2List: NSObject, Codable {
    
    var content: LibreRawGlucoseOOPA2Cotent?
    
    /// description
    override var description: String {
        
        guard let content = content else {return "LibreRawGlucoseOOPA2List = \ncontent = nil (type LibreRawGlucoseOOPA2List)"}
        
        return "LibreRawGlucoseOOPA2List = \ncontent = " + content.description
        
    }
    
}
