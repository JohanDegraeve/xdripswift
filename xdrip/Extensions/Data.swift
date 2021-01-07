import Foundation

extension Data {
    private static let hexAlphabet = "0123456789abcdef".unicodeScalars.map { $0 }
    
    // String conversion methods, adapted from https://stackoverflow.com/questions/40276322/hex-binary-string-conversion-in-swift/40278391#40278391
    /// initializer with hexadecimalstring as input
    init?(hexadecimalString: String) {
        self.init(capacity: hexadecimalString.utf16.count / 2)
        
        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(u: UInt16) -> UInt8? {
            switch u {
            case 0x30 ... 0x39:  // '0'-'9'
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:  // 'A'-'F'
                return UInt8(u - 0x41 + 10)  // 10 since 'A' is 10, not 0
            case 0x61 ... 0x66:  // 'a'-'f'
                return UInt8(u - 0x61 + 10)  // 10 since 'a' is 10, not 0
            default:
                return nil
            }
        }
        
        var even = true
        var byte: UInt8 = 0
        for c in hexadecimalString.utf16 {
            guard let val = decodeNibble(u: c) else { return nil }
            if even {
                byte = val << 4
            } else {
                byte += val
                self.append(byte)
            }
            even = !even
        }
        guard even else { return nil }
    }
    
    // From Stackoverflow, see https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex-string-in-swift
    /// conert to hexencoded string
    public func hexEncodedString() -> String {
        return String(self.reduce(into: "".unicodeScalars, { (result, value) in
            result.append(Data.hexAlphabet[Int(value/16)])
            result.append(Data.hexAlphabet[Int(value%16)])
        }))
    }
    
    ///takes 8 bytes starting at position and converts to Uint32
    func uint64 (position:Int)-> UInt64 {
        let start = position
        let end = start.advanced(by: 8)
        let number: UInt64 =  self.subdata(in: start..<end).toInt()
        return number
    }
    
    ///takes 4 bytes starting at position and converts to Uint32
    func uint32 (position:Int)-> UInt32 {
        let start = position
        let end = start.advanced(by: 4)
        let number: UInt32 =  self.subdata(in: start..<end).toInt()
        return number
    }

    ///takes 2 bytes starting at position and converts to Uint16
    func uint16 (position:Int)-> UInt16 {
        let start = position
        let end = start.advanced(by: 2)
        let number: UInt16 =  self.subdata(in: start..<end).toInt()
        return number
    }
    
    ///takes 1 byte starting at position and converts to Uint8
    func uint8 (position:Int)-> UInt8 {
        let start = position
        let end = start.advanced(by: 1)
        let number: UInt8 =  self.subdata(in: start..<end).toInt()
        return number
    }
    
    func to<T>(_: T.Type) -> T where T: ExpressibleByIntegerLiteral {
        var value: T = 0
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
        return value
    }
    
    func toInt<T: FixedWidthInteger>() -> T {
        return to(T.self)
    }
    
    mutating func append<T: FixedWidthInteger>(_ newElement: T) {
        
        Swift.withUnsafeBytes(of: newElement.littleEndian) { self.append(contentsOf: $0) }
        
    }
    
    func getByteAt(position:Int) -> Int {
        return Int(self[position])
    }
 
    // from DiaBLE
    func hexDump(address: Int = -1, header: String = "") -> String {
        var offset = startIndex
        var offsetEnd = offset
        var str = header.isEmpty ? "" : "\(header)\n"
        while offset < endIndex {
            _ = formIndex(&offsetEnd, offsetBy: 8, limitedBy: endIndex)
            if address != -1 { str += String(format: "%04X", address + offset) + "  " }
            str += "\(self[offset ..< offsetEnd].reduce("", { $0 + String(format: "%02X", $1) + " "}))"
            str += String(repeating: "   ", count: 8 - distance(from: offset, to: offsetEnd))
            str += "\(self[offset ..< offsetEnd].reduce(" ", { $0 + ((isprint(Int32($1)) != 0) ? String(Unicode.Scalar($1)) : "." ) }))\n"
            _ = formIndex(&offset, offsetBy: 8, limitedBy: endIndex)
        }
        str.removeLast()
        return str
    }
    
    // from DiaBLE
    var hexAddress: String { String(self.reduce("", { $0 + String(format: "%02X", $1) + ":"}).dropLast(1)) }

}



