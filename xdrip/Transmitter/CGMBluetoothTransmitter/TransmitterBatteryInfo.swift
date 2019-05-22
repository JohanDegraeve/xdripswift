import Foundation

enum TransmitterBatteryInfo {
    
    /// for transmitters to give battery in percentage
    case percentage (percentage:Int)
    
    /// Dexcom G5 (and also G6 ?) voltageA, voltageB and resist
    case DexcomG5 (voltageA:Int, voltageB:Int, resist:Int, runtime:Int, temperature:Int)
    
    /// Dexcom G4, batteryinfo (215 or something like that)
    case DexcomG4 (level:Int)
    
    /// gives textual description of the battery level, example for percentage based, this is just the value followed by % sign
    var description: String {
        switch (self) {
        case .DexcomG4(let level):
            return level.description
        case .DexcomG5(let voltA, let voltB, let res, let runt, let temp):
            return "VoltageA = " + voltA.description + ", Voltage B = " + voltB.description + ", resistance = " + res.description + ", runtime = " + runt.description + ", temperature = " + temp.description
        case .percentage(let perc):
            return  perc.description + "%"
        }
    }

    /// data is created with function toData, this init will convert the data back into an instance of TransmitterBatteryInfo
    ///
    /// used to store TransmitterBatteryInfo as NSData in UserDefaults
    ///
    /// would need to be extended if new cases are added to TransmitterBatteryInfo
    init(data:Data) {
        if data.count < 1 {fatalError("in TransmitterBatteryInfo init with data, length < 1")}
        
        let type = data.uint8(position: 0)
        
        let uint64size = 8
        
        switch type {
        case 0:// percentage
            if data.count < 5 {fatalError("in TransmitterBatteryInfo init with data, type is percentage but length < 5")}
            let percentage = Int(data.uint64(position: 1))
            self = .percentage(percentage: percentage)
        case 1://dexcomg5
            if data.count < 21 {fatalError("in TransmitterBatteryInfo init with data, type is dexcomg5 but length < 21")}
            let voltageA = Int(data.uint64(position: 1))
            let voltageB = Int(data.uint64(position: 1 + uint64size * 1))
            let resist = Int(data.uint64(position: 1 + uint64size * 2))
            let runtime = Int(data.uint64(position: 1 + uint64size * 3))
            let temperature = Int(data.uint64(position: 1 + uint64size * 4))
            self = .DexcomG5(voltageA: voltageA, voltageB: voltageB, resist: resist, runtime: runtime, temperature: temperature)
        case 2://dexcomG4
            if data.count < 5 {fatalError("in TransmitterBatteryInfo init with data, type is dexcomG4 but length < 5")}
            let level = Int(data.uint64(position: 1))
            self = .DexcomG4(level: level)

        default://assume percentage
            if data.count < 5 {fatalError("in TransmitterBatteryInfo init with data, type is percentage but length < 5")}
            let percentage = Int(data.uint64(position: 1))
            self = .percentage(percentage: percentage)

        }
        
    }
    
    /// creates Data object, initializer can recreate instance with a parameter created by this function
    ///
    /// used to store TransmitterBatteryInfo as NSData in UserDefaults
    ///
    /// would need to be extended if new cases are added to TransmitterBatteryInfo
    func toData() -> Data {
        
        /// first bit will indicate enum with 0 = percentage, 1 = DexcomG5, 2 = DexcomG4
        
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

        case .DexcomG4(let level):
            returnValueAsArray = [2]
            returnValueAsArray.append(contentsOf: level.toByteArray())

        }
        
        return Data(returnValueAsArray)
    }
}
