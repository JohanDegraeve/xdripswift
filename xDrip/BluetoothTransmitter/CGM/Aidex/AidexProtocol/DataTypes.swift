import Foundation

// MARK: - F003 Data Frame

/// 17-байтовый data frame с F003 (после дешифрования).
struct GlucoseFrame {
    let opcode: UInt8
    let timeOffsetMinutes: Int       // секунды / 60
    let glucoseMgDl: Float           // после применения scaling factor
    let rawGlucosePacked: Int        // 10-bit значение до scaling
    let i1: Float                    // raw channel 1 (u16 / 100)
    let i2: Float                    // raw channel 2 (u16 / 100)
    let crc16: UInt16
    let isValid: Bool

    /// rawValue = i1 * 10 (для xDrip-совместимости)
    var rawValue: Float { i1 * 10.0 }
    /// sensorGlucose = i1 * 18.0182 (конвертация mmol/L → mg/dL)
    var sensorGlucose: Float { i1 * 18.0182 }
}

// MARK: - History Records

/// Запись из GET_HISTORIES_RAW (0x23) — калиброванная глюкоза.
public struct CalibratedHistoryEntry {
    public let timeOffsetMinutes: Int
    public let glucoseMgDl: Int             // 10-bit
    public let statusBit: Bool
    public let isSentinel: Bool
}

/// Запись из GET_HISTORIES (0x24) — raw ADC данные.
public struct AdcHistoryEntry: Hashable {
    public let timeOffsetMinutes: Int
    public let i1: Float       // u16 / 100
    public let i2: Float       // u16 / 100
    public let vc: Float       // u8 / 100
    public let rawValue: Float      // i1 * 10
    public let sensorGlucose: Float // i1 * 18.0182
}

/// Запись калибровки из GET_CALIBRATION (0x27).
public struct CalibrationRecord: Hashable {
    public let index: Int
    public let timeOffsetMinutes: Int
    public let referenceGlucoseMgDl: Int
    public let calibrationFactor: Float   // u16 / 100
    public let calibrationOffset: Float   // s16 / 100
}

// MARK: - Metadata

/// Результат парсинга GET_STARTUP_DEVICE_INFO (0x10).
public struct StartupDeviceInfo {
    public let firmwareVersion: String
    public let hardwareVersion: String
    public let wearDays: Int
    public let modelName: String
}

/// Результат парсинга CGM Session Start Time (0x2AAA) или 0x21.
struct LocalStartTime {
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let second: Int
    let tzQuarters: Int
    let dstQuarters: Int

    var isAllZeros: Bool {
        year == 0 && month == 0 && day == 0 && hour == 0 && minute == 0 && second == 0
    }

    /// Конвертация в epoch (миллисекунды).
    func toEpochMs() -> Int64? {
        guard !isAllZeros else { return nil }

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        comps.timeZone = TimeZone(secondsFromGMT: 0)

        guard let date = Calendar.current.date(from: comps) else { return nil }

        let tzOffsetSeconds = tzQuarters * 15 * 60 + (dstQuarters == 4 ? 3600 : 0)
        let ms = Int64(date.timeIntervalSince1970 * 1000) - Int64(tzOffsetSeconds * 1000)
        return ms
    }
}

// MARK: - History Range

public struct HistoryRange {
    public let briefStart: Int    // oldest offset for 0x24
    public let rawStart: Int      // oldest offset for 0x23
    public let newestOffset: Int
}

// MARK: - Default Params

struct DefaultParamChunk {
    let leadByte: UInt8
    let totalWords: Int
    let startIndex: Int
    let rawChunk: Data

    var nextStartIndex: Int { startIndex + (rawChunk.count / 2) }
    var isComplete: Bool { nextStartIndex > totalWords }
}

// MARK: - Calibration Range

struct CalibrationRange {
    let startIndex: Int
    let endIndex: Int
}

// MARK: - Transport

/// Унифицированное показание глюкозы для доставки потребителю.
struct GlucoseReading: Hashable, Identifiable {
    let timestamp: Date
    let sensorSerial: String
    let autoValue: Float?
    let rawValue: Float?
    let sensorGlucose: Float?
    let rawI1: Float?
    let rawI2: Float?
    let timeOffsetMinutes: Int?

    var id: String { "\(Int(timestamp.timeIntervalSince1970 * 1000))_\(sensorSerial)" }
}

/// Статус соединения.
struct ConnectionState {
    let serial: String
    let displayName: String
    let status: String
    let detailedStatus: String
    let phase: ConnectionPhase
    let rssi: Int
    let batteryMillivolts: Int
    let sensorExpired: Bool
    let sensorRemainingHours: Int
    let sensorAgeHours: Int
    let firmwareVersion: String
    let hardwareVersion: String
    let modelName: String
    let wearDays: Int
    let viewMode: Int
}

public enum ConnectionPhase: Equatable {
    case idle
    case scanning
    case connecting(String)   // peripheral identifier
    case discoveringServices
    case enablingNotifications
    case keyExchange
    case streaming
    case disconnected
}

// MARK: - Enums

enum CalibrationSource {
    case generic
    case aidex
}

public enum SensorUiFamily: String {
    case generic
    case aidex
    case linx
    case lumiflex
}

// MARK: - Sensor snapshot

public struct SensorSnapshot {
    public let serial: String
    public let displayName: String
    public let deviceAddress: String
    public let uiFamily: SensorUiFamily
    public let connectionStatus: String
    public let detailedStatus: String
    public let subtitleStatus: String
    public let startTimeMs: Int64
    public let officialEndMs: Int64
    public let isActive: Bool
    public let isVendorPaired: Bool
    public let isVendorConnected: Bool
    public let rssi: Int
    public let batteryMillivolts: Int
    public let isSensorExpired: Bool
    public let sensorRemainingHours: Int
    public let sensorAgeHours: Int
    public let vendorFirmware: String
    public let vendorHardware: String
    public let vendorModel: String
    public let calibrations: [CalibrationRecord]
}