import Foundation
import os

// sourcre https://github.com/gui-dos/DiaBLE

public enum LibreSensorType: String {
    
    // Libre 1
    case libre1    = "DF"
    
    case libre1A2 =  "A2"
    
    case libre2    = "9D"
    
    case libreUS   = "E5"
   
    case libreProH = "70"
    
    var description: String {
        
        switch self {
            
        case .libre1:
            return "Libre 1"
            
        case .libre1A2:
            return "Libre 1 A2"
            
        case .libre2:
            return "Libre 2"
            
        case .libreUS:
            return "Libre US"
            
        case .libreProH:
            return "Libre PRO H"

        }
        
    }
    
    /// some of the Libre types can not work without webOOP. In case returnvalue is true, then user can not change the value
    ///
    /// note that this value can be overriden by BluetoothPeripheral function overrideNeedsWebOOP, for transmitters that support decryption
    func needsWebOOP() -> Bool {
        
        switch self {
            
        case .libre1A2, .libre1, .libreProH:
            return false
            
        case .libre2, .libreUS:
            return true
            
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
        if self == .libre2 || self == .libreUS {
            
            var libreData = rxBuffer.subdata(in: headerLength..<(rxBufferEnd + 1))

            if let info = patchInfo?.hexadecimal() {
                
                if let log = log {
                    trace("    decrypting libre data", log: log, category: ConstantsLog.categoryLibreSensorType, type: .info)
                }
                
                libreData = Data(PreLibre2.decryptFRAM(uid, info.bytes, libreData.bytes))
                
            } else {
                
                return false
                
            }
            
            // replace 344 bytes to Decrypted data
            rxBuffer.replaceSubrange(headerLength..<(rxBufferEnd + 1), with: libreData)
            
            return true

        }
        
        return false
        
    }
    
    /// checks crc if needed for the sensor type (not for libreProH)
    func crcIsOk(rxBuffer:inout Data, headerLength: Int, log: OSLog?) -> Bool {
        
        switch self {
            
        case .libreProH:
            
            if let log = log {
                trace("    libreProH sensor, no CRC check", log: log, category: ConstantsLog.categoryCGMBubble, type: .info)
            }
            
        case .libre1, .libre1A2, .libre2, .libreUS:
            
            guard Crc.LibreCrc(data: &rxBuffer, headerOffset: headerLength) else {
                
                if let log = log {
                    trace("    in crcIsOk, CRC check failed", log: log, category: ConstantsLog.categoryCGMBubble, type: .info)
                }
                
                return false
            }
            
        }
        
        return true
        
    }

    /// - reads the first byte in patchInfo and dependent on that value, returns type of sensor
    /// - if patchInfo = nil, then returnvalue is Libre1
    /// - if first byte is unknown, then returns nil
    static func type(patchInfo: String?) -> LibreSensorType? {
        
        guard let patchInfo = patchInfo else {return .libre1}
        
        guard patchInfo.count > 1 else {return nil}
        
        let firstTwoChars = patchInfo[0..<2]
        
        switch firstTwoChars {
            
        case "DF":
            return .libre1
            
        case "A2":
            return .libre1A2
            
        case "9D":
            return .libre2
            
        case "E5":
            return .libreUS
            
        case "70":
            return .libreProH
            
        default:
            return nil
            
        }
            
    }
    
}


