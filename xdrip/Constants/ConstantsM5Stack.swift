import Foundation

enum ConstantsM5Stack {
    
    /// maximum time in milliseconds, between two packets
    ///
    /// this is for the case where M5Stack sends a string to the app, split over multiple packets. There's maximum 17 bytes of useful information per packet. The packets should arrive within a predefined timeframe, otherwise it is to be considered as an error
    static let maximumTimeBetweenTwoPacketsInMs = 200
    
    /// maximum BLE packet size
    static let maximumMBLEPacketsize = 20
    
    /// default text color
    static let defaultTextColor = M5StackTextColor.white
    
}

enum M5StackTextColor:UInt32, CaseIterable {
    
    case red = 0xFF0000
    
    case green = 0x00FF00
    
    case white = 0xFFFFFF
    
    case yellow = 0xFFFF00
    
    var description:String {
        switch self {
        case .red:
            return Texts_Common.red
        case .green:
            return Texts_Common.green
        case .white:
            return Texts_Common.white
        case .yellow:
            return Texts_Common.yellow
        }
    }
    
    init?(forUInt32: UInt32) {
        self.init(rawValue: forUInt32)
    }
}
