//
//  NSData+CRC.swift
//  xDripG5
//
//  Created by Nathan Racklyeft on 4/7/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


/**
 CRC-CCITT (XModem)

 [http://www.lammertbies.nl/comm/info/crc-calculation.html]()
 
 [http://web.mit.edu/6.115/www/amulet/xmodem.htm]()
 */
extension Collection where Element == UInt8 {
    private var crcCCITTXModem: UInt16 {
        var crc: UInt16 = 0

        for byte in self {
            crc ^= UInt16(byte) << 8

            for _ in 0..<8 {
                if crc & 0x8000 != 0 {
                    crc = crc << 1 ^ 0x1021
                } else {
                    crc = crc << 1
                }
            }
        }

        return crc
    }

    var crc16: UInt16 {
        return crcCCITTXModem
    }
}


extension UInt8 {
    var crc16: UInt16 {
        return [self].crc16
    }
}


extension Data {
    var isCRCValid: Bool {
        return dropLast(2).crc16 == suffix(2).toInt()
    }

    func appendingCRC() -> Data {
        var data = self
        data.append(crc16)
        return data
    }
}
