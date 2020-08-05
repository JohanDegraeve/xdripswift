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
    private let minuteCounter: Int
    
    /// The raw glucose as read from the sensor
    let rawGlucose: Int
    
    /// The raw temperature as read from the sensor
    let rawTemperature: Int
    
    /// slope to calculate glucose from raw value in (mg/dl)/raw
    let slope: Double
    
    /// glucose offset to be added in mg/dl
    let offset: Double
    
    /// The glucose value in mg/dl
    private let glucose: Double
    
    let temperatureAlgorithmGlucose: Double

    private let oopSlope: Double

    private let oopOffset: Double

    private let temperatureAlgorithmParameterSet: Libre1DerivedAlgorithmParameters?


    /// - parameters :
    ///     - bytes:  raw data bytes as read from the sensor
    ///     - slope:  slope to calculate glucose from raw value in (mg/dl)/raw
    ///     - offset: glucose offset to be added in mg/dl
    ///     - date:   date of the measurement
    ///     - minuteCounter : minute counter of this measurement
    ///     - libre1DerivedAlgorithmParameters : Libre1DerivedAlgorithmParameters for the sensor
    init(bytes: [UInt8], slope: Double = 0.1, offset: Double = 0.0, minuteCounter: Int = 0, date: Date, libre1DerivedAlgorithmParameters: Libre1DerivedAlgorithmParameters? = nil) {
        
        self.rawGlucose = (Int(bytes[1] & 0x1F) << 8) + Int(bytes[0]) // switched to 13 bit mask on 2018-03-15
        self.rawTemperature = (Int(bytes[4] & 0x3F) << 8)  + Int(bytes[3]) // 14 bit-mask for raw temperature
        self.slope = slope
        self.offset = offset
        self.glucose = offset + slope * Double(rawGlucose)
        self.date = date
        self.minuteCounter = minuteCounter
        
        // local algorithm
        self.temperatureAlgorithmParameterSet = libre1DerivedAlgorithmParameters
        if let libreDerivedAlgorithmParameterSet = self.temperatureAlgorithmParameterSet {
            self.oopSlope = libreDerivedAlgorithmParameterSet.slope_slope * Double(rawTemperature) + libreDerivedAlgorithmParameterSet.offset_slope
            self.oopOffset = libreDerivedAlgorithmParameterSet.slope_offset * Double(rawTemperature) + libreDerivedAlgorithmParameterSet.offset_offset
            //        self.oopSlope = slope_slope * Double(rawTemperature) + slope_offset
            //        self.oopOffset = offset_slope * Double(rawTemperature) + offset_offset
            let oopGlucose = oopSlope * Double(rawGlucose) + oopOffset
            //self.temperatureAlgorithmGlucose = oopGlucose
            // Final correction, if sensor values are very low and need to be compensated
            self.temperatureAlgorithmGlucose = oopGlucose * libreDerivedAlgorithmParameterSet.extraSlope + libreDerivedAlgorithmParameterSet.extraOffset
        } else {
            self.oopSlope = 0
            self.oopOffset = 0
            self.temperatureAlgorithmGlucose = 0
        }
    }
    
}
