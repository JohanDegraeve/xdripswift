import Foundation

extension String {
    
    func isFireFly() -> Bool {
        
        if self.startsWith("4") {
            
            return false
            
        }
        
        // changed from 8G to 8A as Dexcom seemed to have gone through the alphabet and started again for G6 transmitters as from summer 2022
        if self >= "8A" {
            
            return true
            
        } else if self >= "8" {
            
            return false
            
        } else {
            
            return true
            
        }
        
    }
    
}
