import Foundation

/// CRC-16/CCITT-FALSE — используется для контрольных сумм команд и ответов F002,
/// а также для F003 data-фреймов.
///
/// Полином: 0x1021
/// Начальное значение: 0xFFFF
/// XOR на выходе: 0x0000
/// Reflect in: false
/// Reflect out: false
enum CRC16 {
    private static let polynomial: UInt16 = 0x1021

    static func checksum(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in data {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                if (crc & 0x8000) != 0 {
                    crc = (crc << 1) ^ polynomial
                } else {
                    crc <<= 1
                }
            }
        }
        return crc
    }

    /// Добавляет 2 байта CRC-16 (Little-Endian) в конец Data.
    static func append(_ data: Data) -> Data {
        let crc = checksum(data)
        var result = data
        result.append(contentsOf: [UInt8(crc & 0xFF), UInt8(crc >> 8)])
        return result
    }

    /// Проверяет CRC-16 в конце ответа. Возвращает true если CRC корректен.
    static func validateResponse(_ data: Data) -> Bool {
        guard data.count >= 3 else { return true } // слишком короткий — не можем проверить
        let payload = data.prefix(data.count - 2)
        let expected = checksum(payload)
        let actual = UInt16(data[data.count - 2]) | (UInt16(data[data.count - 1]) << 8)
        return expected == actual
    }
}