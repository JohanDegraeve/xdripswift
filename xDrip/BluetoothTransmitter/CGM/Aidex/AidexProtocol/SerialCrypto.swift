import Foundation
import CryptoKit

/// Деривация секрета (F001 challenge) и IV из серийного номера сенсора.
///
/// Transform A (secret): MD5(snToBytes.map { ($0 * 13 + 61) & 0xFF })
/// Transform B (IV):     MD5(snToBytes.map { ($0 * 17 + 19) & 0xFF })
enum SerialCrypto {

    /// Преобразование символа серийного номера в число.
    /// '0'-'9' → 0-9, 'A'-'Z' → 10-35, 'a'-'z' → 10-35
    static func charToNumeric(_ c: Character) -> UInt8 {
        guard let ascii = c.asciiValue else { return 0 }
        switch ascii {
        case 0x30...0x39: return ascii - 0x30       // 0-9
        case 0x41...0x5A: return ascii - 0x41 + 10  // A-Z
        case 0x61...0x7A: return ascii - 0x61 + 10  // a-z
        default: return 0
        }
    }

    /// Серийный номер → числовой массив.
    static func snToBytes(_ sn: String) -> [UInt8] {
        sn.map { charToNumeric($0) }
    }

    /// Извлечение bare serial из имени устройства.
    /// "AiDEX X-2222267V4E" → "2222267V4E"
    static func stripPrefix(_ serial: String) -> String {
        let prefixes = ["AiDEX X-", "AIDEX X-", "AiDex X-", "Linx X-", "Lumiflex X-", "X-"]
        for prefix in prefixes {
            if serial.hasPrefix(prefix) {
                return String(serial.dropFirst(prefix.count))
            }
        }
        // Case-insensitive fallback для "X-"
        if let range = serial.range(of: "X-", options: .caseInsensitive) {
            let after = serial[range.upperBound...]
            if after.count >= 8, after.count <= 14, after.allSatisfy({ $0.isLetter || $0.isNumber }) {
                return String(after)
            }
        }
        return serial
    }

    /// 16-байтный секрет для F001 challenge.
    /// MD5( snBytes.map { ($0 * 13 + 61) & 0xFF } )
    static func deriveSecret(_ sn: String) -> Data {
        let transformed = snToBytes(sn).map { ($0 &* 13 &+ 61) & 0xFF }
        return Data(Insecure.MD5.hash(data: transformed))
    }

    /// 16-байтный IV для всех операций.
    /// MD5( snBytes.map { ($0 * 17 + 19) & 0xFF } )
    static func deriveIV(_ sn: String) -> Data {
        let transformed = snToBytes(sn).map { ($0 &* 17 &+ 19) & 0xFF }
        return Data(Insecure.MD5.hash(data: transformed))
    }
}