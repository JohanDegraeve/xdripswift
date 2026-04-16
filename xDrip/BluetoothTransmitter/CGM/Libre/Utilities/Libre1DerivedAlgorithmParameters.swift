//
//  LibreDerivedAlgorithmRunner.swift
//  SwitftOOPWeb
//
//  Created by Bjørn Inge Berg on 18.10.2018.
//  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
//
// adapted by Johan Degraeve for xdrip ios
import Foundation


/// local algorithm use this
public struct Libre1DerivedAlgorithmParameters: Codable, CustomStringConvertible {
    public var slope_slope: Double
    public var slope_offset: Double
    public var offset_slope: Double
    public var offset_offset: Double
    public var isValidForFooterWithReverseCRCs: Int
    public var extraSlope : Double = 1
    public var extraOffset: Double = 0
    public var serialNumber: String
    
    public var description: String {
        return "LibreDerivedAlgorithmParameters: slopeslope: \(slope_slope), slopeoffset: \(slope_offset), offsetoffset: \(offset_offset), offsetSlope: \(offset_slope), extraSlope: \(extraSlope), extraOffset: \(extraOffset), isValidForFooterWithReverseCRCs: \(isValidForFooterWithReverseCRCs), serialNumber: \(serialNumber)"
    }
    
    public init(slope_slope: Double, slope_offset:Double, offset_slope: Double, offset_offset: Double, isValidForFooterWithReverseCRCs: Int, extraSlope: Double, extraOffset: Double, sensorSerialNumber:String) {
        
        self.slope_slope = slope_slope
        self.slope_offset = slope_offset
        self.offset_slope = offset_slope
        self.offset_offset = offset_offset
        self.isValidForFooterWithReverseCRCs = isValidForFooterWithReverseCRCs
        self.extraSlope = extraSlope
        self.extraOffset = extraOffset
        self.serialNumber = sensorSerialNumber
        
    }
    
    ///     - libreSensorType. if nil means not known.  For transmitters that don't know the sensorType, this will not work for Libre ProH
    public init(bytes: Data, serialNumber: String, libreSensorType: LibreSensorType?) {
        
        self.serialNumber = serialNumber
        
        let thresholds = LibreAlgorithmThresholds(glucoseLowerThreshold: 1000, glucoseUpperThreshold: 3000, temperatureLowerThreshold: 6000, temperatureUpperThreshold: 9000, forSensorIdentifiedBy: 49778)
        
        let libreCalibrationInfo = LibreCalibrationInfo(bytes: bytes, libreSensorType: libreSensorType)
        
        let responseb1 = LibreMeasurement(rawGlucose: Int(thresholds.glucoseLowerThreshold), rawTemperature: Int(thresholds.temperatureLowerThreshold)).roundedGlucoseValueFromRaw2(libreCalibrationInfo: libreCalibrationInfo)
        
        let responseb2 = LibreMeasurement(rawGlucose: Int(thresholds.glucoseUpperThreshold), rawTemperature: Int(thresholds.temperatureLowerThreshold)).roundedGlucoseValueFromRaw2(libreCalibrationInfo: libreCalibrationInfo)
        
        let slope1 = (responseb2 - responseb1) / (Double(thresholds.glucoseUpperThreshold) - Double(thresholds.glucoseLowerThreshold))
        
        let offset1 = responseb2 - (Double(thresholds.glucoseUpperThreshold) * slope1)
        
        let responsef1 = LibreMeasurement(rawGlucose: Int(thresholds.glucoseLowerThreshold), rawTemperature: Int(thresholds.temperatureUpperThreshold)).roundedGlucoseValueFromRaw2(libreCalibrationInfo: libreCalibrationInfo)
        
        let responsef2 = LibreMeasurement(rawGlucose: Int(thresholds.glucoseUpperThreshold), rawTemperature: Int(thresholds.temperatureUpperThreshold)).roundedGlucoseValueFromRaw2(libreCalibrationInfo: libreCalibrationInfo)
        
        let slope2 = (responsef2 - responsef1) / (Double(thresholds.glucoseUpperThreshold) - Double(thresholds.glucoseLowerThreshold)) // ca 0.09260869565
        
        let offset2 = responsef2 - (Double(thresholds.glucoseUpperThreshold) * slope2) //

        slope_slope = (slope1 - slope2) / (Double(thresholds.temperatureLowerThreshold) - Double(thresholds.temperatureUpperThreshold)) // 0.00001562292
        
        offset_slope = slope1 - (slope_slope * Double(thresholds.temperatureLowerThreshold))
        
        slope_offset = (offset1 - offset2) / (Double(thresholds.temperatureLowerThreshold) - Double(thresholds.temperatureUpperThreshold)) //-0.00023267185

        offset_offset = offset2 - (slope_offset * Double(thresholds.temperatureUpperThreshold))
        
        // from SensorData and GlucoseFromRaw
        let footerRange = (libreSensorType == .libreProH ? 72..<176 : 320..<344)
        let footer = Array(bytes[footerRange])
        let b0 = UInt16(footer[1])
        let b1 = UInt16(footer[0])
        let reverseFooterCRC = (b0 << 8) | UInt16(b1)
        isValidForFooterWithReverseCRCs = Int(reverseFooterCRC)

        extraSlope = 1
        
        extraOffset = 0
        
    }
    
}

