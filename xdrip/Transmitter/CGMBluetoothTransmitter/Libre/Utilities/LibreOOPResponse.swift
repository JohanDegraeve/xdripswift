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

struct GetCalibrationStatus: Codable {
    let error: Bool?
    let command: String?
    let slope: GetCalibrationStatusResult?
    let result: GetCalibrationStatusResult?
}

struct GetCalibrationStatusResult: Codable, CustomStringConvertible{
    let status: String?
    let slopeSlope, slopeOffset, offsetOffset, offsetSlope: Double?
    let uuid: String?
    let isValidForFooterWithReverseCRCs: Double?
    
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
