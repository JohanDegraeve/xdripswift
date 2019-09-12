import Foundation

enum ConstantsM5Stack {
    
    /// maximum time in milliseconds, between two packets
    ///
    /// this is for the case where M5Stack sends a string to the app, split over multiple packets. There's maximum 17 bytes of useful information per packet. The packets should arrive within a predefined timeframe, otherwise it is to be considered as an error
    static let maximumTimeBetweenTwoPacketsInMs = 200
    
    /// maximum BLE packet size
    static let maximumMBLEPacketsize = 20
}
