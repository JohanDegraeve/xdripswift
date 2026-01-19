import Foundation

enum TransmitterBatteryInfo: Equatable {
    
    /// for transmitters to give battery in percentage
    case percentage (percentage:Int)
    
    /// Dexcom G5 (and also G6 ?) voltageA, voltageB and resist
    case DexcomG5 (voltageA:Int, voltageB:Int, resist:Int, runtime:Int, temperature:Int)
    
    /// gives textual description of the battery level, example for percentage based, this is just the value followed by % sign
    var description: String {
        switch (self) {
        case .DexcomG5(let voltA, let voltB, _, _, _):
            if (voltA == 0 || voltB == 0) {
                return Texts_HomeView.waitingForDataSource // "waiting for data..."
            } else {
                return "Voltage A: " + voltA.description + "0mV\nVoltage B: " + voltB.description + "0mV"
            }
        case .percentage(let perc):
            return  perc.description + "%"
        }
    }
    
    /// returns key and value to be used in json representation
    var batteryLevel: (key: String, value: Any) {
        
        switch (self) {
        
        case .percentage(percentage: let percentage):
            
            return ("battery" , percentage)
            
            
        case .DexcomG5(voltageA: _, voltageB: let voltageB, resist: _, runtime: _, temperature: _):
            
            return ("batteryVoltage" , voltageB)

        }
    }

    /// data is created with function toData, this init will convert the data back into an instance of TransmitterBatteryInfo
    ///
    /// used to store TransmitterBatteryInfo as NSData in UserDefaults
    ///
    /// would need to be extended if new cases are added to TransmitterBatteryInfo
    init?(data:Data) {
        
        if data.count < 1 {return nil}
        
        let type = data.uint8(position: 0)
        
        switch type {
        case 0,2: // percentage
            
            // get value,
            var percentageOrLevel:Int?
            switch data.count {// check total length 5 or 9, if values are stored with 4 bytes, then it will be 5 otherwise 9
            case 5:
                percentageOrLevel = Int(data.uint32(position: 1))
            case 9:
                percentageOrLevel = Int(data.uint64(position: 1))
            default:
                break
            }
            
            // if percentageOrLevel found, return it as percentage
            if let percentageOrLevel = percentageOrLevel {
                self = .percentage(percentage: percentageOrLevel)
            } else {
                return nil
            }
            
        case 1://dexcomg5 or dexcomg6
            
            // intialize values as nil
            var voltageA:Int?
            var voltageB:Int?
            var resist:Int?
            var runtime:Int?
            var temperature:Int?
            
            switch data.count {// check total length 5 or 9, if values are stored with 4 bytes, then it will be 5 otherwise 9
            case 21:// if values are stored with 4 bytes per int
                voltageA = Int(data.uint32(position: 1))
                voltageB = Int(data.uint32(position: 1 + 4))
                resist = Int(data.uint32(position: 1 + 8))

                // see BatteryStatusRxMessage
                // in some cases there's no runtime, in that case value -1 is used
                // which results in 4 times 255
                // check that and if there's 8 times 255 then assign -1 to runtime
                if data[(1+8)..<(1+12)].hexEncodedString() == "ffffffff" {
                    runtime = -1
                } else {
                    runtime = Int(data.uint32(position: 1 + 12))
                }
                temperature = Int(data.uint32(position: 1 + 16))
                
            case 41:// if values are stored with 8 bytes per int
                voltageA = Int(data.uint64(position: 1))
                voltageB = Int(data.uint64(position: 1 + 8))
                resist = Int(data.uint64(position: 1 + 16))
                
                // see BatteryStatusRxMessage
                // in some cases there's no runtime, in that case value -1 is used
                // which results in 8 times 255
                // check that and if there's 8 times 255 then assign -1 to runtime
                if data[(1+24)..<(1+32)].hexEncodedString() == "ffffffffffffffff" {
                    runtime = -1
                } else {
                    runtime = Int(data.uint64(position: 1 + 24))
                }
                temperature = Int(data.uint64(position: 1 + 32))
                
            default:
                break
            }

            if let voltageA = voltageA, let voltageB = voltageB, let resist = resist, let runtime = runtime, let temperature = temperature {
                self = .DexcomG5(voltageA: voltageA, voltageB: voltageB, resist: resist, runtime: runtime, temperature: temperature)
            } else {
                return nil
            }

        default:
            return nil

        }
        
    }
    
    /// creates Data object, initializer can recreate instance with a parameter created by this function
    ///
    /// used to store TransmitterBatteryInfo as NSData in UserDefaults
    ///
    /// would need to be extended if new cases are added to TransmitterBatteryInfo
    func toData() -> Data {
        
        /// first bit will indicate enum with 0 = percentage, 1 = DexcomG5
        
        // start with empty array, actual result should never be empty
        var returnValueAsArray:[UInt8] = []
        
        switch self {
            
        case .percentage(let percentage):
            returnValueAsArray = [0]
            returnValueAsArray.append(contentsOf: percentage.toByteArray())
            
        case .DexcomG5(let voltageA, let voltageB, let resist, let runtime, let temperature):
            returnValueAsArray = [1]
            returnValueAsArray.append(contentsOf: voltageA.toByteArray())
            returnValueAsArray.append(contentsOf: voltageB.toByteArray())
            returnValueAsArray.append(contentsOf: resist.toByteArray())
            returnValueAsArray.append(contentsOf: runtime.toByteArray())
            returnValueAsArray.append(contentsOf: temperature.toByteArray())
        }
        
        return Data(returnValueAsArray)
    }
}
