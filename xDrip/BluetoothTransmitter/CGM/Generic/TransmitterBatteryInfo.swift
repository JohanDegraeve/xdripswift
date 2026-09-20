import Foundation

/// Identifies the Dexcom hardware family whose battery produced a voltage measurement.
///
/// G5, G6 and ONE share the long-life transmitter voltage behaviour represented by `.g5`.
/// G7, ONE+ and Stelo use the disposable-sensor behaviour represented by `.g7`. Keep this
/// family beside the measurement so alerts never have to infer battery semantics from a global
/// transmitter selection that may already have changed.
enum DexcomBatteryFamily: Int16, Codable, Equatable {
    case g5 = 1
    case g7 = 2

    /// Raw Voltage B values are stored in the Dexcom protocol's 10 mV unit.
    /// A value below this boundary is the first value classified as red.
    var redBelow: Int {
        switch self {
        case .g5:
            return 270
        case .g7:
            // Android xDrip+ uses the same 215 boundary. Our initial G7-family field set also
            // separates the two rapidly failing expired sensors from the working 2250 mV G7 15-day.
            return 215
        }
    }

    /// A value at or above this boundary is classified as green.
    var greenFrom: Int {
        switch self {
        case .g5:
            return 280
        case .g7:
            // Current working ONE+ and Stelo samples are above 2500 mV. Values from 2150 through
            // 2490 mV remain a caution state while the family data set grows.
            return 250
        }
    }
}

/// App-derived presentation of Dexcom Voltage B. This is deliberately separate from the status
/// byte sent by the transmitter and from the sensor algorithm's warm-up/failure state.
enum DexcomBatteryStatus: String, Codable, Equatable {
    case unknown
    case red
    case yellow
    case green

    init(voltageB: Int, family: DexcomBatteryFamily) {
        if voltageB <= 0 {
            self = .unknown
        } else if voltageB < family.redBelow {
            self = .red
        } else if voltageB < family.greenFrom {
            self = .yellow
        } else {
            self = .green
        }
    }

    static func millivolts(fromRawVoltage voltage: Int) -> Int {
        voltage * 10
    }
}

enum TransmitterBatteryInfo: Equatable {
    
    /// for transmitters to give battery in percentage
    case percentage (percentage:Int)
    
    /// Dexcom voltage, resistance, runtime and temperature values with their battery family.
    /// Family is interpretation metadata rather than a wire field: G5/G6 use one set of voltage
    /// limits and G7/ONE+/Stelo use another while retaining the same five-value payload.
    case dexcom(family: DexcomBatteryFamily, voltageA: Int, voltageB: Int, resist: Int, runtime: Int, temperature: Int)
    
    /// gives textual description of the battery level, example for percentage based, this is just the value followed by % sign
    var description: String {
        switch (self) {
        case .dexcom(_, let voltA, let voltB, _, _, _):
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
            
            
        case .dexcom(family: _, voltageA: _, voltageB: let voltageB, resist: _, runtime: _, temperature: _):
            
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
            
        case 1, 3: // Existing G5/G6 value or the new family-explicit G7 value.
            
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
                // Type 1 has existed since before G7 support and therefore always means the G5
                // battery family. Type 3 is new and preserves the G7 family across app restarts.
                self = .dexcom(
                    family: type == 1 ? .g5 : .g7,
                    voltageA: voltageA,
                    voltageB: voltageB,
                    resist: resist,
                    runtime: runtime,
                    temperature: temperature
                )
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
        
        /// The first byte identifies 0 = percentage, 1 = legacy/G5-family Dexcom, 3 = G7-family.
        /// Never reuse a historical tag because this Data is persisted in UserDefaults.
        
        // start with empty array, actual result should never be empty
        var returnValueAsArray:[UInt8] = []
        
        switch self {
            
        case .percentage(let percentage):
            returnValueAsArray = [0]
            returnValueAsArray.append(contentsOf: percentage.toByteArray())
            
        case .dexcom(let family, let voltageA, let voltageB, let resist, let runtime, let temperature):
            returnValueAsArray = [family == .g5 ? 1 : 3]
            returnValueAsArray.append(contentsOf: voltageA.toByteArray())
            returnValueAsArray.append(contentsOf: voltageB.toByteArray())
            returnValueAsArray.append(contentsOf: resist.toByteArray())
            returnValueAsArray.append(contentsOf: runtime.toByteArray())
            returnValueAsArray.append(contentsOf: temperature.toByteArray())
        }
        
        return Data(returnValueAsArray)
    }
}
