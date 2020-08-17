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

    private var oopSlope: Double = 0

    private var oopOffset: Double = 0

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
        
        // default parameter
        var parameterSet = Libre1DerivedAlgorithmParameters(slope_slope: 0,
                                                            slope_offset: 0,
                                                            offset_slope: 0.113,
                                                            offset_offset: -20.15,
                                                            isValidForFooterWithReverseCRCs: 1,
                                                            extraSlope: 1.0,
                                                            extraOffset: 0.0,
                                                            sensorSerialNumber: "")
        
        if let LibreDerivedAlgorithmParameterSet = libre1DerivedAlgorithmParameters {
            parameterSet = LibreDerivedAlgorithmParameterSet
        }
        self.temperatureAlgorithmParameterSet = parameterSet
        
        var glucose = parameterSet.offset_slope * Double(rawGlucose) +
            parameterSet.slope_offset * Double(rawTemperature) +
            parameterSet.slope_slope * Double(rawTemperature * rawGlucose) +
            parameterSet.offset_offset;
        
        if glucose < 39 { glucose = 39 }
        if glucose > 501 { glucose = 501 }
        self.temperatureAlgorithmGlucose = glucose
    }
    
}
