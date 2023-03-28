import Foundation

extension String {
    
    func isFireFly() -> Bool {
        
        // updated 2023-03-27: Dexcom have started re-using the 8Xyyyy format now where X is again a number. So we'll basically just treat *all* G6 transmitters as firefly and only allow native mode for now.
        
        // let's check if it's an older G4/G5 transmitter (4xxxxx). If not, then assume it is a firefly (G6/One)
        if self.startsWith("4") {
            
            return false
            
        } else {
            
            return true
            
        }
        
    }
    
}
