import Foundation

/// - utilities for Libre 2 data processing, here it's for the case where data is read via bluetooth
/// - if read via NFC or other transmitter, go to PreLibre2
class Libre2BLEUtilities {
    
    public static func streamingUnlockPayload(sensorUID: Data, info: Data, enableTime: UInt32, unlockCount: UInt16) -> [UInt8] {
        
        // First 4 bytes are just int32 of timestamp + unlockCount
        let time = enableTime + UInt32(unlockCount)
        let b: [UInt8] = [
            UInt8(time & 0xFF),
            UInt8((time >> 8) & 0xFF),
            UInt8((time >> 16) & 0xFF),
            UInt8((time >> 24) & 0xFF)
        ]
        
        // Then we need data of activation command and enable command that were sent to sensor
        let ad = PreLibre2.usefulFunction(sensorUID: sensorUID, x: 0x1b, y: 0x1b6a)
        let ed = PreLibre2.usefulFunction(sensorUID: sensorUID, x: 0x1e, y: UInt16(enableTime & 0xFFFF) ^ UInt16(info[5], info[4]))
        
        let t11 = UInt16(ed[1], ed[0]) ^ UInt16(b[3], b[2])
        let t12 = UInt16(ad[1], ad[0])
        let t13 = UInt16(ed[3], ed[2]) ^ UInt16(b[1], b[0])
        let t14 = UInt16(ad[3], ad[2])
        
        let t2 = PreLibre2.processCrypto(input: PreLibre2.prepareVariables2(sensorUID: sensorUID, i1: t11, i2: t12, i3: t13, i4: t14))
        
        // TODO extract if secret
        let t31 = crc16(Data([0xc1, 0xc4, 0xc3, 0xc0, 0xd4, 0xe1, 0xe7, 0xba, UInt8(t2[0] & 0xFF), UInt8((t2[0] >> 8) & 0xFF)])).byteSwapped
        let t32 = crc16(Data([UInt8(t2[1] & 0xFF), UInt8((t2[1] >> 8) & 0xFF),
                              UInt8(t2[2] & 0xFF), UInt8((t2[2] >> 8) & 0xFF),
                              UInt8(t2[3] & 0xFF), UInt8((t2[3] >> 8) & 0xFF)])).byteSwapped
        let t33 = crc16(Data([ad[0], ad[1], ad[2], ad[3], ed[0], ed[1]])).byteSwapped
        let t34 = crc16(Data([ed[2], ed[3], b[0], b[1], b[2], b[3]])).byteSwapped
        
        let t4 = PreLibre2.processCrypto(input: PreLibre2.prepareVariables2(sensorUID: sensorUID, i1: t31, i2: t32, i3: t33, i4: t34))
        
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
    
    /// Decrypts Libre 2 BLE payload
    /// - Parameters:
    ///   - id: ID/Serial of the sensor. Could be retrieved from NFC as uid.
    ///   - data: Encrypted BLE data
    /// - Returns: Decrypted BLE data
    public static func decryptBLE(sensorUID: Data, data: Data) throws -> [UInt8] {
        let d = PreLibre2.usefulFunction(sensorUID: sensorUID, x: 0x1b, y: 0x1b6a)
        let x = UInt16(d[1], d[0]) ^ UInt16(d[3], d[2]) | 0x63
        let y = UInt16(data[1], data[0]) ^ 0x63
        
        var key = [UInt8]()
        var initialKey = PreLibre2.processCrypto(input: PreLibre2.prepareVariables(sensorUID: sensorUID, x: x, y: y))
        
        for _ in 0 ..< 8 {
            key.append(UInt8(truncatingIfNeeded: initialKey[0]))
            key.append(UInt8(truncatingIfNeeded: initialKey[0] >> 8))
            key.append(UInt8(truncatingIfNeeded: initialKey[1]))
            key.append(UInt8(truncatingIfNeeded: initialKey[1] >> 8))
            key.append(UInt8(truncatingIfNeeded: initialKey[2]))
            key.append(UInt8(truncatingIfNeeded: initialKey[2] >> 8))
            key.append(UInt8(truncatingIfNeeded: initialKey[3]))
            key.append(UInt8(truncatingIfNeeded: initialKey[3] >> 8))
            initialKey = PreLibre2.processCrypto(input: initialKey)
        }
        
        let result = data[2...].enumerated().map { i, value in
            value ^ key[i]
        }
        
        guard crc16(Data(result.prefix(42))) == UInt16(result[42], result[43]) else {
            struct DecryptBLEError: LocalizedError {
                var errorDescription: String? { "BLE data decryption failed" }
            }
            throw DecryptBLEError()
        }
        
        return result
    }

    /// - returns:
    ///     - array of LibreMeasurement
    ///     - sensor time in minutes
    public static func parseBLEData( _ data: Data, libre1DerivedAlgorithmParameters : Libre1DerivedAlgorithmParameters?) -> (bleGlucose: [LibreMeasurement], sensorTimeInMinutes: UInt16) {
        
        var bleGlucose: [LibreMeasurement] = []
        
        let wearTimeMinutes = UInt16(data[40...41])
        
        let startDate = Date() - Double(wearTimeMinutes) * 60
        
        let delay = 2
        for i in 0 ..< 10 {
            let raw = LibreCalibrationInfo.readBits(data, i * 4, 0, 0xe)
            let rawTemperature = LibreCalibrationInfo.readBits(data, i * 4, 0xe, 0xc) << 2
            var temperatureAdjustment = LibreCalibrationInfo.readBits(data, i * 4, 0x1a, 0x5) << 2
            let negativeAdjustment = LibreCalibrationInfo.readBits(data, i * 4, 0x1f, 0x1)
            if negativeAdjustment != 0 {
                temperatureAdjustment = -temperatureAdjustment
            }
            
            var id = Int(wearTimeMinutes)
            
            if i < 7 {
                // sparse trend values
                id -= [0, 2, 4, 6, 7, 12, 15][i]
                
            } else {
                // latest three historic values
                id = ((id - delay) / 15) * 15 - 15 * (i - 7)
            }
            
            let date = startDate + Double(id * 60)
            
            let libreMeasurement = LibreMeasurement(rawGlucose: raw, rawTemperature: rawTemperature, minuteCounter: 0, date: date, temperatureAdjustment: temperatureAdjustment, libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters)
            
            bleGlucose.append(libreMeasurement)
            
        }
        
        return (bleGlucose, wearTimeMinutes)
        
    }
    
    private static func crc16(_ data: Data) -> UInt16 {
        let crc16table: [UInt16] = [0, 4489, 8978, 12955, 17956, 22445, 25910, 29887, 35912, 40385, 44890, 48851, 51820, 56293, 59774, 63735, 4225, 264, 13203, 8730, 22181, 18220, 30135, 25662, 40137, 36160, 49115, 44626, 56045, 52068, 63999, 59510, 8450, 12427, 528, 5017, 26406, 30383, 17460, 21949, 44362, 48323, 36440, 40913, 60270, 64231, 51324, 55797, 12675, 8202, 4753, 792, 30631, 26158, 21685, 17724, 48587, 44098, 40665, 36688, 64495, 60006, 55549, 51572, 16900, 21389, 24854, 28831, 1056, 5545, 10034, 14011, 52812, 57285, 60766, 64727, 34920, 39393, 43898, 47859, 21125, 17164, 29079, 24606, 5281, 1320, 14259, 9786, 57037, 53060, 64991, 60502, 39145, 35168, 48123, 43634, 25350, 29327, 16404, 20893, 9506, 13483, 1584, 6073, 61262, 65223, 52316, 56789, 43370, 47331, 35448, 39921, 29575, 25102, 20629, 16668, 13731, 9258, 5809, 1848, 65487, 60998, 56541, 52564, 47595, 43106, 39673, 35696, 33800, 38273, 42778, 46739, 49708, 54181, 57662, 61623, 2112, 6601, 11090, 15067, 20068, 24557, 28022, 31999, 38025, 34048, 47003, 42514, 53933, 49956, 61887, 57398, 6337, 2376, 15315, 10842, 24293, 20332, 32247, 27774, 42250, 46211, 34328, 38801, 58158, 62119, 49212, 53685, 10562, 14539, 2640, 7129, 28518, 32495, 19572, 24061, 46475, 41986, 38553, 34576, 62383, 57894, 53437, 49460, 14787, 10314, 6865, 2904, 32743, 28270, 23797, 19836, 50700, 55173, 58654, 62615, 32808, 37281, 41786, 45747, 19012, 23501, 26966, 30943, 3168, 7657, 12146, 16123, 54925, 50948, 62879, 58390, 37033, 33056, 46011, 41522, 23237, 19276, 31191, 26718, 7393, 3432, 16371, 11898, 59150, 63111, 50204, 54677, 41258, 45219, 33336, 37809, 27462, 31439, 18516, 23005, 11618, 15595, 3696, 8185, 63375, 58886, 54429, 50452, 45483, 40994, 37561, 33584, 31687, 27214, 22741, 18780, 15843, 11370, 7921, 3960]
        var crc = data.reduce(UInt16(0xFFFF)) { ($0 >> 8) ^ crc16table[Int(($0 ^ UInt16($1)) & 0xFF)] }
        var reverseCrc = UInt16(0)
        for _ in 0 ..< 16 {
            reverseCrc = reverseCrc << 1 | crc & 1
            crc >>= 1
        }
        return reverseCrc.byteSwapped
    }
    
}
