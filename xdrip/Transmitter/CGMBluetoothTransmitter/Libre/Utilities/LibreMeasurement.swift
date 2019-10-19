//
//  Measurement.swift
//  LibreMonitor
//
//  Created by Uwe Petersen on 25.08.16.
//  Copyright © 2016 Uwe Petersen. All rights reserved.
//

import Foundation


/// Structure for one glucose measurement including value, date and raw data bytes
struct LibreMeasurement {
    /// The date for this measurement
    let date: Date
    /// The minute counter for this measurement
    let counter: Int
    /// The bytes as read from the sensor. All data is derived from this \"raw data"
    let bytes: [UInt8]
    /// The bytes as String
    let byteString: String
    /// The raw glucose as read from the sensor
    let rawGlucose: Int
    /// The raw temperature as read from the sensor
    let rawTemperature: Int
    /// slope to calculate glucose from raw value in (mg/dl)/raw
    let slope: Double
    /// glucose offset to be added in mg/dl
    let offset: Double
    /// The glucose value in mg/dl
    let glucose: Double
    /// Initialize a new glucose measurement
//    let slope_slope: Double = 0.0
//    let slope_offset: Double = 0.0
//    let offset_slope: Double = 0.0
//    let offset_offset: Double = 0.0
    let temperatureAlgorithmGlucose: Double
    // {"status":"complete","slope_slope":0.00001816666666666667,"slope_offset":-0.00016666666666666666,"offset_offset":-21.5,"offset_slope":0.007499999999999993,"uuid":"calibrationmetadata-e61686dd-1305-44f0-a675-df98aabce67f","isValidForFooterWithReverseCRCs":61141}

    let oopSlope: Double
    let oopOffset: Double
    ///
    let temperatureAlgorithmParameterSet: LibreDerivedAlgorithmParameters?


    ///
    /// - parameter bytes:  raw data bytes as read from the sensor
    /// - parameter slope:  slope to calculate glucose from raw value in (mg/dl)/raw
    /// - parameter offset: glucose offset to be added in mg/dl
    /// - parameter date:   date of the measurement
    ///
    /// - returns: Measurement
    init(bytes: [UInt8], slope: Double = 0.1, offset: Double = 0.0, counter: Int = 0, date: Date, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameters? = nil) {
        self.bytes = bytes
        self.byteString = bytes.reduce("", {$0 + String(format: "%02X", arguments: [$1])})
        self.rawGlucose = (Int(bytes[1] & 0x1F) << 8) + Int(bytes[0]) // switched to 13 bit mask on 2018-03-15
        self.rawTemperature = (Int(bytes[4] & 0x3F) << 8)  + Int(bytes[3]) // 14 bit-mask for raw temperature
        self.slope = slope
        self.offset = offset
        self.glucose = offset + slope * Double(rawGlucose)
        self.date = date
        self.counter = counter
        
        self.temperatureAlgorithmParameterSet = LibreDerivedAlgorithmParameterSet
        if let LibreDerivedAlgorithmParameterSet = self.temperatureAlgorithmParameterSet {
            self.oopSlope = LibreDerivedAlgorithmParameterSet.slope_slope * Double(rawTemperature) + LibreDerivedAlgorithmParameterSet.offset_slope
            self.oopOffset = LibreDerivedAlgorithmParameterSet.slope_offset * Double(rawTemperature) + LibreDerivedAlgorithmParameterSet.offset_offset
            //        self.oopSlope = slope_slope * Double(rawTemperature) + slope_offset
            //        self.oopOffset = offset_slope * Double(rawTemperature) + offset_offset
            let oopGlucose = oopSlope * Double(rawGlucose) + oopOffset
            //self.temperatureAlgorithmGlucose = oopGlucose
            // Final correction, if sensor values are very low and need to be compensated
            self.temperatureAlgorithmGlucose = oopGlucose * LibreDerivedAlgorithmParameterSet.extraSlope + LibreDerivedAlgorithmParameterSet.extraOffset
        } else {
            self.oopSlope = 0
            self.oopOffset = 0
            self.temperatureAlgorithmGlucose = 0
        }
        
    }
    
    
    var description: String {
        var aString = String("Glucose: \(glucose) (mg/dl), date:  \(date), slope: \(slope), offset: \(offset), rawGlucose: \(rawGlucose), rawTemperature: \(rawTemperature), bytes: \(bytes) \n")
        aString.append("OOP: slope_slope: \(String(describing: temperatureAlgorithmParameterSet?.slope_slope)), slope_offset: \(String(describing: temperatureAlgorithmParameterSet?.slope_offset)), offset_slope: \(String(describing: temperatureAlgorithmParameterSet?.offset_slope)), offset_offset: \(String(describing: temperatureAlgorithmParameterSet?.offset_offset))\n")
        aString.append("OOP: slope: \(oopSlope), \noffset: \(oopOffset)")
        aString.append("oopGlucose: \(temperatureAlgorithmGlucose) (mg/dl)" )
        
        return aString

    }
}
