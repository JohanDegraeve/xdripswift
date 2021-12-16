import Foundation

extension String {
    
    func isFireFly() -> Bool {
        
        if self.startsWith("4") {
            
            return false
            
        }
        
        if self >= "8G" {
            
            return true
            
        } else if self >= "8" {
            
            return false
            
        } else {
            
            return true
            
        }
        
    }
    
}
