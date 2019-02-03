import Foundation

enum TransmitterBatteryInfo {
    /// for transmitters to give battery in percentage
    case percentage (percentage:Int)
    
    /// Dexcom G5 (and also G6 ?) voltageA, voltageB and resist
    case DexcomG5 (voltageA:Int, voltageB:Int, resist:Int)
    
    /// Dexcom G4, batteryinfo (215 or something like that)
    case DexcomG4 (level:Int)
    
    var description: String {
        switch (self) {
        case .DexcomG4(let level):
            return "Battery Level = " + level.description
        case .DexcomG5(let voltA, let voltB, let res):
            return "VoltageA = " + voltA.description + " Voltage B = " + voltB.description + " resistance = " + res.description
        case .percentage(let perc):
            return "Battery Percentage = " + perc.description
        }
    }
}
