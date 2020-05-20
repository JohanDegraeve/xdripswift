////
////  CreateRequestResponse.swift
////  SwitftOOPWeb
////
////  Created by Bjørn Inge Berg on 08.04.2018.
////  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
////
//// adapted by Johan Degraeve for xdrip ios
import Foundation

// MARK: Encode/decode helpers

struct GetCalibrationStatus: Codable, CustomStringConvertible {
    var error: Bool?
    var command: String?
    var slope: GetCalibrationStatusResult?
    
    var description: String {
        return """
        slope_slope = \(slope?.slopeSlope ?? 0)
        slope_offset = \(slope?.slopeOffset ?? 0)
        offset_slope = \(slope?.offsetSlope ?? 0)
        offset_offset = \(slope?.offsetOffset ?? 0)
        """
    }
}

struct GetCalibrationStatusResult: Codable {
    var status: String?
    var slopeSlope: Double?
    var slopeOffset: Double?
    var offsetOffset: Double?
    var offsetSlope: Double?
    var uuid: String?
    var isValidForFooterWithReverseCRCs: Double?
    
    enum CodingKeys: String, CodingKey {
        case status
        case slopeSlope = "slope_slope"
        case slopeOffset = "slope_offset"
        case offsetOffset = "offset_offset"
        case offsetSlope = "offset_slope"
        case uuid
        case isValidForFooterWithReverseCRCs  = "isValidForFooterWithReverseCRCs"
    }
    
    var description: String {
        return "calibrationparams:: slopeslope: \(String(describing: slopeSlope)), slopeoffset: \(String(describing: slopeOffset)), offsetoffset: \(String(describing: offsetOffset)), offsetSlope: \(String(describing: offsetSlope)), isValidForFooterWithReverseCRCs: \(String(describing: isValidForFooterWithReverseCRCs))"
    }
}
