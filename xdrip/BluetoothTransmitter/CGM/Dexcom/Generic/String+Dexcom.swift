import Foundation

extension String {
    
    func isFireFly() -> Bool {
        
        if self.compare("8G") == .orderedDescending {
            
            return true
            
        } else {
            
            return false
            
        }
        
    }
    
}
