//
//  PreLibre2.swift
//  DiaBox
//
//  Created by Yan Hu on 2020/8/17.
//  Copyright © 2020 DiaBox. All rights reserved.
//

import Foundation

/// for libre2 to decrypt 344 data like libre1 data
class PreLibre2 {
    
    static let key: [UInt16] = [0xA0C5, 0x6860, 0x0000, 0x14C6]
    
    public static func op(_ value: UInt16, _ l1: UInt16, _ l2: UInt16) -> UInt16 {
        var res = value >> 2 // Result does not include these last 2 bits
        if ((value & 1) == 1) {
            res ^= l2
        }
        
        if ((value & 2) == 2) {// If second last bit is 1
            res ^= l1
        }
        return res
    }
    
    public static func word(_ high: UInt8, _ low: UInt8) -> UInt64 {
        return (UInt64(high) << 8) + UInt64(low & 0xff)
    }
    
    public static func decryptFRAM(_ sensorId: [UInt8], _ sensorInfo: [UInt8], _ FRAMData: [UInt8]) -> [UInt8] {
        let l1: UInt16 = 0xa0c5
        let l2: UInt16 = 0x6860
        let l3: UInt16 = 0x14c6
        let l4: UInt16 = 0x0000
    
        var result = [UInt8]()
        for i in 0 ..< 43 {
            let i64 = UInt64(i)
            var y = word(sensorInfo[5], sensorInfo[4])
            if (i < 3 || i >= 40) {
                y = 0xcadc
            }
            var s1: UInt16 = 0
            if (sensorInfo[0] == 0xE5) {
                let ss1 = (word(sensorId[5], sensorId[4]) + y + i64)
                s1 = UInt16(ss1 & 0xffff)
            } else {
                let ss1 = ((word(sensorId[5], sensorId[4]) + (word(sensorInfo[5], sensorInfo[4]) ^ 0x44)) + i64)
                s1 = UInt16(ss1 & 0xffff)
            }
            
            let s2 = UInt16((word(sensorId[3], sensorId[2]) + UInt64(l4)) & 0xffff)
            let s3 = UInt16((word(sensorId[1], sensorId[0]) + (i64 << 1)) & 0xffff)
            let s4 = ((0x241a ^ l3))
            let key = processCrypto2(s1, s2, s3, s4, l1, l2)
            result.append((FRAMData[i * 8 + 0] ^ UInt8(key[3] & 0xff)))
            result.append((FRAMData[i * 8 + 1] ^ UInt8((key[3] >> 8) & 0xff)))
            result.append((FRAMData[i * 8 + 2] ^ UInt8(key[2] & 0xff)))
            result.append((FRAMData[i * 8 + 3] ^ UInt8((key[2] >> 8) & 0xff)))
            result.append((FRAMData[i * 8 + 4] ^ UInt8(key[1] & 0xff)))
            result.append((FRAMData[i * 8 + 5] ^ UInt8((key[1] >> 8) & 0xff)))
            result.append((FRAMData[i * 8 + 6] ^ UInt8(key[0] & 0xff)))
            result.append((FRAMData[i * 8 + 7] ^ UInt8((key[0] >> 8) & 0xff)))
        }
        
        return result[0..<344].map{ $0 }
    }
    
    static func usefulFunction(sensorUID: Data, x: UInt16, y: UInt16) -> [UInt8] {

        let blockKey = processCrypto(input: prepareVariables(sensorUID: sensorUID, x: x, y: y))
        let low = blockKey[0]
        let high = blockKey[1]
        
        let r1 = low ^ 0x4163
        let r2 = high ^ 0x4344
        
        return [
            UInt8(truncatingIfNeeded: r1),
            UInt8(truncatingIfNeeded: r1 >> 8),
            UInt8(truncatingIfNeeded: r2),
            UInt8(truncatingIfNeeded: r2 >> 8)
        ]
    }

    static func streamingUnlockPayload(sensorUID: Data, info: Data, enableTime: UInt32, unlockCount: UInt16) -> [UInt8] {
        
        // First 4 bytes are just int32 of timestamp + unlockCount
        let time = enableTime + UInt32(unlockCount)
        let b: [UInt8] = [
            UInt8(time & 0xFF),
            UInt8((time >> 8) & 0xFF),
            UInt8((time >> 16) & 0xFF),
            UInt8((time >> 24) & 0xFF)
        ]
        
        // Then we need data of activation command and enable command that were sent to sensor
        let ad = usefulFunction(sensorUID: sensorUID, x: 0x1b, y: 0x1b6a)
        let ed = usefulFunction(sensorUID: sensorUID, x: 0x1e, y: UInt16(enableTime & 0xFFFF) ^ UInt16(info[5], info[4]))
        
        let t11 = UInt16(ed[1], ed[0]) ^ UInt16(b[3], b[2])
        let t12 = UInt16(ad[1], ad[0])
        let t13 = UInt16(ed[3], ed[2]) ^ UInt16(b[1], b[0])
        let t14 = UInt16(ad[3], ad[2])
        
        let t2 = processCrypto(input: prepareVariables2(sensorUID: sensorUID, i1: t11, i2: t12, i3: t13, i4: t14))
        
        // TODO extract if secret
        let t31 = (Data([0xc1, 0xc4, 0xc3, 0xc0, 0xd4, 0xe1, 0xe7, 0xba, UInt8(t2[0] & 0xFF), UInt8((t2[0] >> 8) & 0xFF)])).crc16.byteSwapped
        let t32 = (Data([UInt8(t2[1] & 0xFF), UInt8((t2[1] >> 8) & 0xFF),
                              UInt8(t2[2] & 0xFF), UInt8((t2[2] >> 8) & 0xFF),
                              UInt8(t2[3] & 0xFF), UInt8((t2[3] >> 8) & 0xFF)])).crc16.byteSwapped
        let t33 = (Data([ad[0], ad[1], ad[2], ad[3], ed[0], ed[1]])).crc16.byteSwapped
        let t34 = (Data([ed[2], ed[3], b[0], b[1], b[2], b[3]])).crc16.byteSwapped
        
        let t4 = processCrypto(input: prepareVariables2(sensorUID: sensorUID, i1: t31, i2: t32, i3: t33, i4: t34))
        
        let res = [
            UInt8(t4[0] & 0xFF),
            UInt8((t4[0] >> 8) & 0xFF),
            UInt8(t4[1] & 0xFF),
            UInt8((t4[1] >> 8) & 0xFF),
            UInt8(t4[2] & 0xFF),
            UInt8((t4[2] >> 8) & 0xFF),
            UInt8(t4[3] & 0xFF),
            UInt8((t4[3] >> 8) & 0xFF)
        ]
        
        return [b[0], b[1], b[2], b[3], res[0], res[1], res[2], res[3], res[4], res[5], res[6], res[7]]
    }
    
    static func prepareVariables2(sensorUID: Data, i1: UInt16, i2: UInt16, i3: UInt16, i4: UInt16) -> [UInt16] {
        let s1 = UInt16(truncatingIfNeeded: UInt(UInt16(sensorUID[5], sensorUID[4])) + UInt(i1))
        let s2 = UInt16(truncatingIfNeeded: UInt(UInt16(sensorUID[3], sensorUID[2])) + UInt(i2))
        let s3 = UInt16(truncatingIfNeeded: UInt(UInt16(sensorUID[1], sensorUID[0])) + UInt(i3) + UInt(key[2]))
        let s4 = UInt16(truncatingIfNeeded: UInt(i4) + UInt(key[3]))
        
        return [s1, s2, s3, s4]
    }

    static func prepareVariables(sensorUID: Data, x: UInt16, y: UInt16) -> [UInt16] {
        let s1 = UInt16(truncatingIfNeeded: UInt(UInt16(sensorUID[5], sensorUID[4])) + UInt(x) + UInt(y))
        let s2 = UInt16(truncatingIfNeeded: UInt(UInt16(sensorUID[3], sensorUID[2])) + UInt(key[2]))
        let s3 = UInt16(truncatingIfNeeded: UInt(UInt16(sensorUID[1], sensorUID[0])) + UInt(x) * 2)
        let s4 = 0x241a ^ key[3]
        
        return [s1, s2, s3, s4]
    }

    static func processCrypto2(_ s1: UInt16, _ s2: UInt16, _ s3: UInt16, _ s4: UInt16, _ l1: UInt16, _ l2: UInt16) -> [UInt16] {
        let r0 = op(s1, l1, l2) ^ s4
        let r1 = op(r0, l1, l2) ^ s3
        
        let r2 = op(r1, l1, l2) ^ s2
        let r3 = op(r2, l1, l2) ^ s1
        let r4 = op(r3, l1, l2)
        let r5 = op(r4 ^ r0, l1, l2)
        let r6 = op(r5 ^ r1, l1, l2)
        let r7 = op(r6 ^ r2, l1, l2)
        let f1 = ((r0 ^ r4))
        let f2 = ((r1 ^ r5))
        let f3 = ((r2 ^ r6))
        let f4 = ((r3 ^ r7))
        
        return [f1, f2, f3, f4]
    }
    
    static func processCrypto(input: [UInt16]) -> [UInt16] {
        func op(_ value: UInt16) -> UInt16 {
            // We check for last 2 bits and do the xor with specific value if bit is 1
            var res = value >> 2 // Result does not include these last 2 bits
            
            if value & 1 != 0 { // If last bit is 1
                res = res ^ key[1]
            }
            
            if value & 2 != 0 { // If second last bit is 1
                res = res ^ key[0]
            }
            
            return res
        }
        
        let r0 = op(input[0]) ^ input[3]
        let r1 = op(r0) ^ input[2]
        let r2 = op(r1) ^ input[1]
        let r3 = op(r2) ^ input[0]
        let r4 = op(r3)
        let r5 = op(r4 ^ r0)
        let r6 = op(r5 ^ r1)
        let r7 = op(r6 ^ r2)
        
        let f1 = r0 ^ r4
        let f2 = r1 ^ r5
        let f3 = r2 ^ r6
        let f4 = r3 ^ r7
        
        return [f4, f3, f2, f1];
    }
    
}
