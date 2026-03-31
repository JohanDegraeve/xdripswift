import Foundation

struct DexcomCalibrationParameters {
    
    let parameter1: Int16
    
    let parameter2: Int16
    
    /// - sets parameter1 and parameter2 according to sensorCode
    /// - if sensorCode == nil or "0000" then initialized with parameter1 and parameter2 equal to 0, meaning considered as a transmitter that doesn't need a sensorcode
    init?(sensorCode: String?) {
        
        guard let sensorCode = sensorCode else {
            
            parameter1 = 0
            
            parameter2 = 0
            
            return
            
        }
        
        switch (sensorCode) {
            
            // special null code
        case "0000":
            parameter1 = 0
            parameter2 = 0
            break
            
        case "5915","9759":
            parameter1 = 3100
            parameter2 = 3600
            break
            
        case "5917","9357":
            parameter1 = 3000
            parameter2 = 3500
            break
            
        case "5931","9137":
            parameter1 = 2900
            parameter2 = 3400
            break
            
        case "5937","7197":
            parameter1 = 2800
            parameter2 = 3300
            break
            
        case "5951","9517":
            parameter1 = 3100
            parameter2 = 3500
            break
            
        case "5955","9179":
            parameter1 = 3000
            parameter2 = 3400
            break
            
        case "7171","7539":
            parameter1 = 2700
            parameter2 = 3300
            break
            
        case "9117","7135":
            parameter1 = 2700
            parameter2 = 3200
            break
            
        case "9159","5397":
            parameter1 = 2600
            parameter2 = 3200
            break
            
        case "9311","5391":
            parameter1 = 2600
            parameter2 = 3100
            break
            
        case "9371","5375":
            parameter1 = 2500
            parameter2 = 3100
            break
            
        case "9515","5795":
            parameter1 = 2500
            parameter2 = 3000
            break
            
        case "9551","5317":
            parameter1 = 2400
            parameter2 = 3000
            break
            
        case "9577","5177":
            parameter1 = 2400
            parameter2 = 2900
            break
            
        case "9713","5171":
            parameter1 = 2300
            parameter2 = 2900
            break
            
        default:
            return nil
            
        }
        
    }
    
}

