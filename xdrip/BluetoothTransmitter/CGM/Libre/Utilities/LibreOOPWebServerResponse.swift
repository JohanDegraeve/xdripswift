import Foundation

/// empty protocol used as generic response type for data received from web server
protocol LibreOOPWebServerResponseData: Decodable {
    
    /// if the server value is error  return true - this is implemented by objects that conform to LibreRawGlucoseWeb,  classes that do not conform to LibreRawGlucoseWeb still need to implement this (eg OopWebCalibrationStatus)
    var isError: Bool { get }
    
    /// if the server returns an error, then msg describes the error - this is implemented by objects that conform to LibreRawGlucoseWeb,  classes that do not conform to LibreRawGlucoseWeb still need to implement this (eg OopWebCalibrationStatus)
    var msg: String? { get }
    
    // if the server returns an error, then this is the error code received from the server - this is implemented by objects that conform to LibreRawGlucoseWeb,  classes that do not conform to LibreRawGlucoseWeb still need to implement this (eg OopWebCalibrationStatus)
    var errcode: Int? { get }
    
}
