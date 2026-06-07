import Foundation

/// opcodes for writing to M5Stack
enum M5StackTransmitterOpCodeTx: UInt8, CaseIterable {
    
    /// client writes nightscouturl
    case writeNightscoutUrlTx = 0x01
    
    /// client writes nightscoutToken
    case writeNightscoutAPIKeyTx = 0x02
    
    /// client writes mgdl, value 0 means mmol is used, value 1 is mgdl
    case writemgdlTx = 0x03
    
    /// client writes brightness1, value between 1 and 100
    case writebrightness1Tx = 0x04
    
    /// client writes brightness2, value between 1 and 100
    case writebrightness2Tx = 0x05
    
    /// client writes brightness3, value between 1 and 100
    case writebrightness3Tx = 0x06
    
    /// client writes wlan ssid, 2nd byte in data is used to indicate which wlan (from 1 to 10), next bytes is ssid as string
    case writeWlanSSIDTx = 0x07
    
    /// client writes wlan Pass, 2nd byte in data is used to indicate which wlan (from 1 to 10), next bytes is Pass as string
    case writeWlanPassTx = 0x08
    
    /// opcode to request the password
    ///
    /// xdrip should only read the password if it doesn't have a password in the settings - M5Stack will send back the password only if it generated a random password during connection, not if it was set in the config ini file. In the latter case, the user should know it and set it in the app settings
    case readBlePassWordTx = 0x09
    
    /// authenticate
    case authenticateTx = 0x0A
    
    /// bg reading
    case bgReadingTx = 0x10

    /// writes local time in seconds , seconds since 1.1.1970
    case writeTimeStampTx = 0x12
    
    /// write slopeName to M5Stack
    case writeSlopeNameTx = 0x13
    
    /// write offset, ie time difference in seconds between local time and utc time
    case writeTimeOffsetTx = 0x14
    
    /// write textColor to M5Stack
    case writeTextColorTx = 0x15

    /// write backGroundColor to M5Stack
    case writeBackGroundColorTx = 0x17
    
    /// write rotation to M5Stack
    case writeRotationTx = 0x18
    
    /// write brightness to M5Stack
    case writeBrightnessTx = 0x19
    
    /// ask batteryLevel to M5Stack
    case readBatteryLevelTx = 0x21
    
    /// send power off to M5Stack
    case writepowerOffTx = 0x22
    
    /// send connectToWifi parameter
    case writeConnectToWiFiTx = 0x23
    
}

/// opcodes for message from M5stack to app
enum M5StackTransmitterOpCodeRx: UInt8, CaseIterable {
    
    /// opcode to receive the password
    ///
    /// xdrip should only read the password if it doesn't have a password in the settings - M5Stack will send back the password only if it generated a random password during first time connection, not if it was set in the config ini file. In the latter case, the user should know it and set it in the app settings
    case readBlePassWordRx = 0x0E

    /// authenticate
    case authenticateSuccessRx = 0x0B
    
    /// authenticate
    case authenticateFailureRx = 0x0C
    
    /// readBlePassword failed, error 1 : User should set correct password in settings
    case readBlePassWordError1Rx = 0x0D

    /// readBlePassword failed, error 2 : Password already known, user should reset M5Stack
    case readBlePassWordError2Rx = 0x0F
    
    /// M5Stack requests timestamp in seconds, local time since 1.1.1970 !!
    case readTimeStampRx = 0x11
    
    /// M5Stack requests all parameters (textcolor, wifi names and passwords,...), this is usually after an M5Stack restart
    case readAllParametersRx = 0x16
    
    /// M5Stack sending battery level
    case readBatteryLevelRx = 0x20

    /// received heartbeat
    case heartbeat = 0x21

}

extension M5StackTransmitterOpCodeRx: CustomStringConvertible {
    public var description: String {
        
        switch self {
        case .readBlePassWordRx:
            return "readBlePassWordRx"
        case .authenticateSuccessRx:
            return "authenticateSuccessRx"
        case .authenticateFailureRx:
            return "authenticateFailureRx"
        case .readBlePassWordError1Rx:
            return "readBlePassWordError1Rx"
        case .readBlePassWordError2Rx:
            return "readBlePassWordError2Rx"
        case .readTimeStampRx:
            return "readTimeStampRx"
        case .readAllParametersRx:
            return "readAllParametersRx"
        case .readBatteryLevelRx:
            return "readBatteryLevelRx"
        case .heartbeat:
            return "heartbeat"
        }
    }
}
