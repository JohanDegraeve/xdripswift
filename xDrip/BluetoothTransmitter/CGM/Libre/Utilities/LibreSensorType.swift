import Foundation
import os

public enum LibreSensorType: String {
    
    // Libre 1
    case libre1 = "DF"
    
    case libre1A2 = "A2"
    
    case libre2 = "9D"
    
    case libre2C5 = "C5"
    
    case libre2C6 = "C6" // EU Libre 2 Plus (May 2024)
    
    case libre27F = "7F" // EU Libre 2 Plus (May 2025)

    case libre27FNonPlus = "7F30" // EU Libre 2 (May 2025), source: https://github.com/gui-dos/DiaBLE
    
    case libreUS = "E5"
    
    case libreUSE6 = "E6"
   
    case libreProH = "70"
    
    var description: String {
        
        switch self {
            
        case .libre1:
            return "Libre 1"
            
        case .libre1A2:
            return "Libre 1 A2"
            
        case .libre2:
            return "Libre 2 EU"
            
        case .libre2C5:
            return "Libre 2 EU C5"
            
        case .libre2C6:
            return "Libre 2 Plus EU C6"
            
        case .libre27F:
            return "Libre 2 Plus EU 7F"

        case .libre27FNonPlus:
            return "Libre 2 EU 7F"
            
        case .libreUS:
            return "Libre US"
            
        case .libreUSE6:
            return "Libre US E6"
            
        case .libreProH:
            return "Libre PRO H"

        }
        
    }

    /// True when the sensor's FRAM uses the Libre 2 encryption handled by PreLibre2.
    var requiresLibre2Decryption: Bool {
        switch self {
        case .libre2, .libre2C5, .libre2C6, .libre27F, .libre27FNonPlus, .libreUS, .libreUSE6:
            return true

        case .libre1, .libre1A2, .libreProH:
            return false
        }
    }

    /// The newer 7F Libre 2 sensors advertise their MAC address instead of ABBOTT plus the serial number.
    var usesMacAddressAsBluetoothName: Bool {
        switch self {
        case .libre27F, .libre27FNonPlus:
            return true

        default:
            return false
        }
    }
    
    /// decrypts for libre2 and libreUs,
    func decryptIfPossibleAndNeeded(rxBuffer:inout Data, headerLength: Int, log: OSLog?, patchInfo: String?, uid: [UInt8]) -> Bool {
        
        // index of last byte to process
        let rxBufferEnd = headerLength + 344 - 1
        
        // rxBuffer size should be at least headerLength + 344, if not don't further process
        guard rxBuffer.count >= headerLength + 344 else {
            return false
        }
        
        // decrypt if libre2 or libreUS
        if requiresLibre2Decryption {
            
            var libreData = rxBuffer.subdata(in: headerLength..<(rxBufferEnd + 1))

            if let info = patchInfo?.hexadecimal() {
                
                if let log = log {
                    trace("    decrypting libre data", log: log, category: ConstantsLog.categoryLibreSensorType, type: .info)
                }
                
                libreData = Data(PreLibre2.decryptFRAM(uid, Array(info), Array(libreData)))
                
            } else {
                
                return false
                
            }
            
            // replace 344 bytes to Decrypted data
            rxBuffer.replaceSubrange(headerLength..<(rxBufferEnd + 1), with: libreData)
            
            return true

        }
        
        return false
        
    }
    
    /// checks crc if needed for the sensor type
    func crcIsOk(rxBuffer:inout Data, headerLength: Int, log: OSLog?) -> Bool {
        
        guard Crc.LibreCrc(data: &rxBuffer, headerOffset: headerLength, libreSensorType: self) else {
            
            if let log = log {
                trace("    in crcIsOk, CRC check failed", log: log, category: ConstantsLog.categoryCGMBubble, type: .info)
            }
            
            return false
        }

        return true

    }

    /// - reads the sensor type from patchInfo and returns the matching Libre type
    /// - if patchInfo = nil, then returnvalue is Libre1
    /// - if first byte is unknown, then returns nil
    static func type(patchInfo: String?) -> LibreSensorType? {
        
        guard let patchInfo = patchInfo else {return .libre1}
        
        guard let patchInfoBytes = Data(hexadecimalString: patchInfo), let sensorType = patchInfoBytes.first else {return nil}
        
        switch sensorType {
            
        case 0xDF:
            return .libre1
            
        case 0xA2:
            return .libre1A2
            
        case 0x9D:
            return .libre2
            
        case 0xC5:
            return .libre2C5 // new Libre 2 EU type (May 2023)
            
        case 0xC6:
            return .libre2C6 // new Libre 2 Plus EU type (May 2024)
            
        case 0x7F:
            // The low nibble of the third patch-info byte differentiates the two 7F sensors.
            // 7F 0E 30 01 is Libre 2 and 7F 0E 31 01 is Libre 2 Plus. Both use the same
            // Libre 2 encryption and MAC-address BLE discovery. See:
            // https://github.com/JohanDegraeve/xdripswift/issues/714
            // https://github.com/JohanDegraeve/xdripswift/pull/720
            guard patchInfoBytes.count >= 3 else {
                // Preserve the previous Plus classification if incomplete patch info is received.
                return .libre27F
            }

            return patchInfoBytes[2] & 0x0F == 0 ? .libre27FNonPlus : .libre27F
            
        case 0xE5:
            return .libreUS
            
        case 0xE6:
            return .libreUSE6
            
        case 0x70:
            return .libreProH

        default:
            return nil
            
        }
            
    }
    
    /// maximum sensor age in days, nil if no maximum
    func maxSensorAgeInDays() -> Double? {
        
        switch self {
        
        case .libre1:
            return 14.5
            
        case .libre1A2:
            return 14.5

        case .libre2, .libre2C5, .libre27FNonPlus:
            return 14.5
            
        case .libre2C6, .libre27F:
            return 15.5

        case .libreUS, .libreUSE6:
            return nil

        case .libreProH:
            return 14

        }
        
    }
    

    
}
