import Foundation

/// Опкоды F002-команд.
enum AidexOpcode: UInt8 {
    case getStartupDeviceInfo   = 0x10
    case getBroadcastData       = 0x11
    case setNewSensor           = 0x20
    case getLocalStartTime      = 0x21
    case getHistoryRange        = 0x22
    case getHistoriesRaw        = 0x23
    case getHistories           = 0x24
    case setCalibration         = 0x25
    case getCalibrationRange    = 0x26
    case getCalibration         = 0x27
    case setDefaultParam        = 0x30
    case getDefaultParam        = 0x31
    case getSensorCheck         = 0x32
    case getAutoUpdateStatus    = 0x33
    case setAutoUpdateStatus    = 0x34
    case setDynamicAdvMode      = 0x35
    case reset                  = 0xF0
    case shelfMode              = 0xF1
    case deleteBond             = 0xF2
    case clearStorage           = 0xF3
}

/// Константы F003-фреймов.
enum AidexFrame {
    static let dataFrameLength = 17
    static let statusFrameLength = 5
    static let calibrationNotificationLength = 13
    static let glucoseMask: Int = 0x03FF
    static let maxValidGlucose = 500
    static let minValidGlucose = 20
    static let sentinelGlucose = 1023
}

/// BLE UUIDs.
public enum AidexUUID {
    public static let service = "0000181F-0000-1000-8000-00805F9B34FB"
    public static let charF001  = "0000F001-0000-1000-8000-00805F9B34FB"
    public static let charF002  = "0000F002-0000-1000-8000-00805F9B34FB"
    public static let charF003  = "0000F003-0000-1000-8000-00805F9B34FB"
    public static let charModelNumber    = "00002A24-0000-1000-8000-00805F9B34FB"
    public static let charSoftwareRev    = "00002A28-0000-1000-8000-00805F9B34FB"
    public static let charManufacturer   = "00002A29-0000-1000-8000-00805F9B34FB"
    public static let charSessionStart   = "00002AAA-0000-1000-8000-00805F9B34FB"
    public static let charSessionRun     = "00002AAB-0000-1000-8000-00805F9B34FB"

    public static let serviceDIS = "0000180A-0000-1000-8000-00805F9B34FB"
    public static let manufacturerID: UInt16 = 0x0059
    public static let knownNamePrefixes = ["AiDex", "AiDEX", "AIDEX", "Linx", "LINX", "CGM"]
}

/// Scaling factor для F003 opcode.
let directScaleOpcodes: Set<UInt8> = [0xA1, 0xA4, 0x5B, 0xD7]
let halfScaleOpcodes: Set<UInt8> = [0xD2]

func scalingFactor(for opcode: UInt8) -> Float {
    if directScaleOpcodes.contains(opcode) { return 1.0 }
    if halfScaleOpcodes.contains(opcode) { return 0.5 }
    return 1.0
}

/// Таймауты (миллисекунды).
enum AidexTimeout {
    static let mtuDelay: UInt64 = 200
    static let keyExchange: UInt64 = 35_000
    static let setupStall: UInt64 = 25_000
    static let gattOperation: UInt64 = 15_000
    static let cccdWriteCallback: UInt64 = 2_500
    static let historyPage: UInt64 = 25_000
    static let historyRequestDelay: UInt64 = 80
    static let initialHistoryRequest: UInt64 = 65_000
    static let clearStorageQuietWindow: UInt64 = 12_000
    static let postResetReconnect: UInt64 = 5_000
    static let postKeyCCCDRefresh: UInt64 = 250
    static let discoveryRetry: UInt64 = 1_500
    static let warmupDuration: UInt64 = 7 * 60_000
    static let bondingSettle: UInt64 = 500
    static let mtusettle: UInt64 = 200

    // Вещественные
    static var warmupDurationSec: TimeInterval { Double(warmupDuration) / 1000.0 }
}