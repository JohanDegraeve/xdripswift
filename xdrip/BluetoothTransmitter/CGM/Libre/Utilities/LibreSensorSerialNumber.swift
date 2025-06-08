//
//  FreestyleLibreSensor.swift
//  LibreMonitor
//
//  Created by Uwe Petersen on 01.04.18.
//  Copyright © 2018 Uwe Petersen. All rights reserved.
//

import Foundation

public struct LibreSensorSerialNumber: CustomStringConvertible {
    
    let uid: Data
    
    let libreSensorType: LibreSensorType?

    fileprivate let lookupTable = ["0","1","2","3","4","5","6","7","8","9","A","C","D","E","F","G","H","J","K","L","M","N","P","Q","R","T","U","V","W","X","Y","Z"]
    
    init?(withUID uid: Data, with libreSensorType: LibreSensorType?) {
        
        guard uid.count == 8 else {return nil}
        
        self.uid = uid
        
        self.libreSensorType = libreSensorType
        
    }

    // MARK: - computed properties
    
    var serialNumber: String  {

        // The serial number of the sensor can be derived from its uid.
        //
        // The numbers an letters of the serial number are coded a compressed scheme that uses only 32 numbers and letters,
        // by omitting the letters B, I, O and S. This information is stored in consecutive units of five bits.
        //
        // The encoding thus is as follows:
        //   index: 0 1 2 3 4 5 6 7 8 9 10     11 12 13 14 15 16     17 18 19 20 21     22 23 24      25 26 27 28 29 30 31
        //   char:  0 1 2 3 4 5 6 7 8 9  A (B)  C  D  E  F  G  H (I)  J  K  L  M  N (O)  P  Q  R (S)   T  U  V  W  X  Y  Z
        //
        // Example:  75 ce 86 00 00 a0 07 e0
        //    Uid is E0 07 A0 00 00 25 90 5E, and the corresponding serial number is "0M00009DHCR"
        //           \   / \              /
        //            -+-   -----+--------
        //             |         |
        //             |         +-- This part encodes the serial number, see below
        //             +-- Standard first two bytes, where 0x07 is the code for "Texas Instruments Tag-it™", see https://en.wikipedia.org/wiki/ISO/IEC_15693
        //
        //   1.) Convert the part without E007, i.e. A0 00 00 25 90 5E to binary representation
        //
        //            A    0     0    0     0    0     2    5     9    0     5    E
        //          1010 0000  0000 0000  0000 0000  0010 0101  1001 0000  0101 1110
        //
        //   2.) Split this binary array in units of five bits length from the beginning and pad with two zeros at the end and
        //       calculate the corresponding integer and retreive the corresponding char from the table above
        //
        // Byte #       0           1          2          3          4          5
        // Bit  #   8765 4321  8765 4321  8765 4321  8765 4321  8765 4321  8765 4321
        //
        //     +--  1010 0000  0000 0000  0000 0000  0010 0101  1001 0000  0101 1110  + 00
        //     |    \    /\     /\    /\     / \     /\    /\     /\    /  \    /\       /
        //     +->  10100  00000  00000 00000   00000  01001 01100  10000   01011 11000
        //            |      |      |      |      |      |      |      |      |      |
        //            |      |      |      |      |      |      |      |      |      +- = 24 -> "R" (Byte 6) << 2                  Mask 0x1F
        //            |      |      |      |      |      |      |      |      +-------- = 11 -> "C" (Byte 5) >> 3                  Mask 0x1F
        //            |      |      |      |      |      |      |      +--------------- = 16 -> "H" (Byte 4)                       Mask 0x1F
        //            |      |      |      |      |      |      +---------------------- = 12 -> "D" (Byte 3) << 2 + (Byte 4) >> 5  Mask 0x1F
        //            |      |      |      |      |      +----------------------------- =  9 -> "9" (Byte 3) >> 2                  Mask 0x1F
        //            |      |      |      |      +------------------------------------ =  0 -> "0" (Byte 2) << 1 + (Byte 3) >> 7  Mask 0x1F
        //            |      |      |      +------------------------------------------- =  0 -> "0" (Byte 1) << 4 + (Byte 2) >> 4  Mask 0x1F
        //            |      |      +-------------------------------------------------- =  0 -> "0" (Byte 1) >> 1                  Mask 0x1F
        //            |      +--------------------------------------------------------- =  0 -> "0" (Byte 0) << 2 + (Byte 1) >> 6  Mask 0x1F
        //            +---------------------------------------------------------------- = 20 -> "M" (byte 0) >> 3                  Mask 0x1F
        //
        //
        //   3.) Prepend "0" at the beginning an thus receive "0M00009DHCR"
        
        guard uid.count == 8 else {return "invalid uid"}
        
        let bytes = Array(uid.reversed().suffix(6))  // 5E 90 25 00 00 A0 07 E0" -> E0 07 A0 00 00 25 90 5E -> A0 00 00 25 90 5E

        //  A0 00 00 25 90 5E -> "M00009DHCR"
        var fiveBitsArray = [UInt8]() // Mask later with 0x1F to use only five bits

        fiveBitsArray.append( bytes[0] >> 3 )
        fiveBitsArray.append( bytes[0] << 2 + bytes[1] >> 6 )
        fiveBitsArray.append( bytes[1] >> 1 )
        fiveBitsArray.append( bytes[1] << 4 + bytes[2] >> 4 )
        fiveBitsArray.append( bytes[2] << 1 + bytes[3] >> 7 )
        fiveBitsArray.append( bytes[3] >> 2 )
        fiveBitsArray.append( bytes[3] << 3 + bytes[4] >> 5 )
        fiveBitsArray.append( bytes[4] )
        fiveBitsArray.append( bytes[5] >> 3 )
        fiveBitsArray.append( bytes[5] << 2 )

        var first = "0"
        
        if let libreSensorType = libreSensorType {
            
            switch libreSensorType {
            
            case .libreProH:
                
                first = "1"
                
            case .libre2, .libre2C5, .libre2C6, .libre27F:
            
                first = "3"
                
            case .libre1, .libreUS, .libreUSE6:
                
                first = "0"
                
                
            default:
                
                first = "0"
                
            }
            
        }
        
        let serialNumber = fiveBitsArray.reduce(first, { // prepend with "0" according to step 3.)
            $0 + lookupTable[ Int(0x1F & $1) ]  // Mask with 0x1F to only take the five relevant bits
        })
        
        return serialNumber
    }
    
    var uidString: String {
        return Data(self.uid).hexEncodedString()
    }
    
    var prettyUidString: String {
        let stringArray = self.uid.map({String(format: "%02X", $0)})
        return stringArray.dropFirst().reduce(stringArray.first!,  {$0 + ":" + $1} )
    }

    // MARK: - CustomStringConvertible Protocol
    
    public var description: String {
        return "Uid is \(prettyUidString) and derived serial number is \(serialNumber)"
    }
    
}
