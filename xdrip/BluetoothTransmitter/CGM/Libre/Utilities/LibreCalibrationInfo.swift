import Foundation

public struct LibreCalibrationInfo: Codable {
    
        var i1: Int
        var i2: Int
        var i3: Double
        var i4: Double
        var i5: Double
        var i6: Double
        
    
    init(bytes: Data, libreSensorType: LibreSensorType?) {
        
        i1 = Self.readBits(bytes, (libreSensorType == .libreProH ? 26 : 2), 0, 3)
        
        i2 = Self.readBits(bytes, (libreSensorType == .libreProH ? 26 : 2), 3, 0xa)
        
        i3 = Double(Self.readBits(bytes, (libreSensorType == .libreProH ? 56 : 0x150), 0, 8))
        if Self.readBits(bytes, (libreSensorType == .libreProH ? 56 : 0x150), 0x21, 1) != 0 {
            i3 = -i3
        }
        
        i4 = Double(Self.readBits(bytes, (libreSensorType == .libreProH ? 56 : 0x150), 8, 0xe))
        
        i5 = Double(Self.readBits(bytes, (libreSensorType == .libreProH ? 56 : 0x150), 0x28, 0xc) << 2)
        
        i6 = Double(Self.readBits(bytes, (libreSensorType == .libreProH ? 56 : 0x150), 0x34, 0xc) << 2)
        
    }
    
    static func readBits(_ buffer: Data, _ byteOffset: Int, _ bitOffset: Int, _ bitCount: Int) -> Int {
        guard bitCount != 0 else {
            return 0
        }
        var res = 0
        for i in stride(from: 0, to: bitCount, by: 1) {
            let totalBitOffset = byteOffset * 8 + bitOffset + i
            let abyte = Int(floor(Float(totalBitOffset) / 8))
            let abit = totalBitOffset % 8
            if totalBitOffset >= 0 && ((buffer[abyte] >> abit) & 0x1) == 1 {
                res = res | (1 << i)
            }
        }
        return res
    }
    
    static func writeBits(_ buffer: Data, _ byteOffset: Int, _ bitOffset: Int, _ bitCount: Int, _ value: Int) -> Data{
        
        var res = buffer; // Make a copy
        for i in stride(from: 0, to: bitCount, by: 1) {
            let totalBitOffset = byteOffset * 8 + bitOffset + i;
            let byte = Int(floor(Double(totalBitOffset) / 8))
            let bit = totalBitOffset % 8;
            let bitValue = (value >> i) & 0x1;
            res[byte] = (res[byte] & ~(1 << bit) | (UInt8(bitValue) << bit));
        }
        return res;
    }
    
}
