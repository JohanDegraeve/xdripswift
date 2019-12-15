import Foundation

fileprivate let lookupTable = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "T", "U", "V", "W", "X", "Y", "Z"]

/// static functions for Blucon
class BluconUtilities {
    
    /// - parameters:
    ///     - input : data received from Blucon
    /// - returns: The sensor serial number
    ///
    /// decodes serial number, copied forp xdripplus , commit 2b25bfdf6a563aea16de63053aec5e0e3be16e5f
    public static func decodeSerialNumber(input: Data) -> String {
        
        var uuidShort = Data([0, 0, 0, 0, 0, 0, 0, 0])
        
        for i in 2..<8 {
            uuidShort[i - 2] = input[(2 + 8) - i]
        }
        
        uuidShort[6] = 0x00
        uuidShort[7] = 0x00
        
        var binary = ""
        for i in 0..<8 {
            var binS = String(uuidShort[i] & 0xFF, radix: 2)
            while binS.count < 8 {
                binS = "0" + binS
            }
            binary = binary + binS
        }
        var v = "0"
        var pozS = [0, 0, 0, 0, 0]
        for i in 0..<10 {
            for k in 0..<5 {
                let index = (5 * i) + k
                pozS[k] = binary[index..<(index + 1)] == "0" ? 0:1
            }

            let value = pozS[0] * 16 + pozS[1] * 8 + pozS[2] * 4 + pozS[3] * 2 + pozS[4] * 1
            v += lookupTable[value]
        }
        
        return v;
    }
}
