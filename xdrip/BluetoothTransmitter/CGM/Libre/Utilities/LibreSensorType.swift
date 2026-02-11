import Foundation
import os

// sourcre https://github.com/gui-dos/DiaBLE

public enum LibreSensorType: String {
    
    // Libre 1
    case libre1 = "DF"
    
    case libre1A2 = "A2"
    
    case libre2 = "9D"
    
    case libre2C5 = "C5"
    
    case libre2C6 = "C6" // EU Libre 2 Plus (May 2024)
    
    case libre27F = "7F" // EU Libre 2 Plus (May 2025)

    case libre22B = "2B" // LATAM Libre 2 Plus (2B 0A 3A 08) / RU Libre 2 (2B 0A 39 08)

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

        case .libre22B:
            return "Libre 2 Plus LATAM/RU 2B"

        case .libreUS:
            return "Libre US"
            
        case .libreUSE6:
            return "Libre US E6"
            
        case .libreProH:
            return "Libre PRO H"

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
        if self == .libre2 || self == .libre2C5 || self == .libre2C6 || self == .libre27F || self == .libre22B || self == .libreUS || self == .libreUSE6 {
            
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

    /// - reads the first byte in patchInfo and dependent on that value, returns type of sensor
    /// - if patchInfo = nil, then returnvalue is Libre1
    /// - if first byte is unknown, then returns nil
    /// - Full patch info format (4 bytes): [Type][Variant][Generation][Region]
    ///   Example: 2B 0A 3A 08 = LATAM Libre 2 Plus
    ///            2B 0A 39 08 = RU Libre 2 (Gen2)
    static func type(patchInfo: String?) -> LibreSensorType? {

        guard let patchInfo = patchInfo else {return .libre1}

        guard patchInfo.count > 1 else {return nil}

        let firstTwoChars = patchInfo[0..<2].uppercased()
        
        switch firstTwoChars {
            
        case "DF":
            return .libre1
            
        case "A2":
            return .libre1A2
            
        case "9D":
            return .libre2
            
        case "C5":
            return .libre2C5 // new Libre 2 EU type (May 2023)
            
        case "C6":
            return .libre2C6 // new Libre 2 Plus EU type (May 2024)
            
        case "7F":
            return .libre27F // new Libre 2 Plus EU type (May 2025)

        case "2B":
            return .libre22B // LATAM Libre 2 Plus / RU Libre 2 (14-day)

        case "E5":
            return .libreUS
            
        case "E6":
            return .libreUSE6
            
        case "70":
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

        case .libre2, .libre2C5:
            return 14.5

        case .libre22B:
            return 14.5  // LATAM Plus and RU Libre 2 are 14-day sensors

        case .libre2C6, .libre27F:
            return 15.5

        case .libreUS, .libreUSE6:
            return nil

        case .libreProH:
            return 14

        }
        
    }

    /// Determine if a 2B sensor is the Russian Gen2 variant
    ///
    /// Uses full patch info to distinguish between:
    /// - LATAM Libre 2 Plus: 2B 0A 3A 08 (Gen1)
    /// - RU Libre 2: 2B 0A 39 08 (Gen2)
    ///
    /// - Parameter patchInfo: Full patch info string (12 hex chars for 6 bytes)
    /// - Returns: true if Russian Gen2 sensor, false otherwise
    static func isRussianGen2(patchInfo: String?) -> Bool {
        guard let patchInfo = patchInfo?.uppercased() else { return false }

        // Check for Russian Libre 2 Gen2 pattern: 2B 0A 39 08
        // patchInfo format: "2B0A3908" (no spaces) or "2B 0A 39 08" (with spaces)
        let normalized = patchInfo.replacingOccurrences(of: " ", with: "")

        // Must start with 2B and have byte[2] = 39 (byte 4-5 in hex string)
        if normalized.hasPrefix("2B") && normalized.count >= 8 {
            let thirdByte = normalized[4..<6]  // Characters 4-5 = third byte
            return thirdByte == "39"
        }

        return false
    }

    /// Determine if a 2B sensor is the Latin American Plus variant
    ///
    /// - Parameter patchInfo: Full patch info string
    /// - Returns: true if LATAM Libre 2 Plus sensor
    static func isLatinAmericanPlus(patchInfo: String?) -> Bool {
        guard let patchInfo = patchInfo?.uppercased() else { return false }

        let normalized = patchInfo.replacingOccurrences(of: " ", with: "")

        // LATAM pattern: 2B 0A 3A 08
        if normalized.hasPrefix("2B") && normalized.count >= 8 {
            let thirdByte = normalized[4..<6]
            return thirdByte == "3A"  // 3A = LATAM, 39 = RU
        }

        return false
    }


}


