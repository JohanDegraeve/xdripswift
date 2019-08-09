////
////  CreateRequestResponse.swift
////  SwitftOOPWeb
////
////  Created by Bjørn Inge Berg on 08.04.2018.
////  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
////
//
//import Foundation
//
//struct OOPCurrentValue: Codable {
//    let currentTrend: Int
//    let currentBg: Double
//    let currentTime: Int
//    let historyValues: [OOPHistoryValue]
//    let serialNumber: String?
//    let timestamp: Int
//
//    enum CodingKeys: String, CodingKey {
//        case currentTrend = "currenTrend"  // TODO: rename currenTrend to currentTrend
//        case currentBg
//        case currentTime
//        case historyValues = "historicBg"
//        case serialNumber
//        case timestamp
//    }
//}
//
//struct OOPHistoryValue: Codable {
//    let bg: Double
//    let quality: Int
//    let time: Int
//
//    enum Codingkeys: String, CodingKey {
//        case bg
//        case quality
//        case time
//    }
//}
//
//struct LibreOOPResponse: Codable {
//    let error: Bool
//    let command: String
//    let message: String?
//    let result: LibreReadingResult?
//
//    enum CodingKeys: String, CodingKey {
//        case error = "Error"
//        case command = "Command"
//        case message = "Message"
//        case result = "Result"
//    }
//}
//
//struct LibreReadingResult: Codable {
//    let createdOn, modifiedOn, uuid, b64Contents: String
//    let status: String
//    let result: String?
//
//    enum CodingKeys: String, CodingKey {
//        case createdOn = "CreatedOn"
//        case modifiedOn = "ModifiedOn"
//        case uuid
//        case b64Contents = "b64contents"
//        case status, result
//    }
//}
//
//// MARK: Encode/decode helpers
//
//class JSONNull: Codable {
//    public init() {}
//
//    public required init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        if !container.decodeNil() {
//            throw DecodingError.typeMismatch(JSONNull.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONNull"))
//        }
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encodeNil()
//    }
//}
//
//
//
//

//
//  CreateRequestResponse.swift
//  SwitftOOPWeb
//
//  Created by Bjørn Inge Berg on 08.04.2018.
//  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
//
import Foundation



struct OOPCurrentValue: Codable {
    let currentTrend: Int?
    var currentBg: Double?
    let currentTime: Int?
    let historyValues: [OOPHistoryValue]?
    var serialNumber: String?
    let timestamp: Int?
    
    enum CodingKeys: String, CodingKey {
        case currentTrend = "currenTrend"  // TODO: rename currenTrend to currentTrend
        case currentBg
        case currentTime
        case historyValues = "historicBg"
        case serialNumber
        case timestamp
    }
}

struct OOPHistoryValue: Codable {
    let bg: Double
    let quality: Int
    let time: Int
    
    enum Codingkeys: String, CodingKey {
        case bg
        case quality
        case time
    }
}

struct LibreOOPResponse: Codable {
    let error: Bool?
    let command: String?
    let message: String?
    let result: LibreReadingResult?
    
    enum CodingKeys: String, CodingKey {
        case error = "Error"
        case command = "Command"
        case message = "Message"
        case result = "Result"
    }
}

struct LibreReadingResult: Codable {
    let createdOn, modifiedOn, uuid, b64Contents: String
    let status: String
    let result: String?
    var newState: String?
    
    enum CodingKeys: String, CodingKey {
        case createdOn = "CreatedOn"
        case modifiedOn = "ModifiedOn"
        case uuid
        case b64Contents = "b64contents"
        case status, result, newState
    }
}

extension LibreReadingResult {
    var created: Date? {
        get {
            return Date.dateFromISOString(string: self.createdOn)
        }
    }
    
    init(created: String, b64Contents: String, uuid: String="") {
        
        self.init(createdOn: created, modifiedOn: created, uuid: uuid, b64Contents: b64Contents, status: "init", result: "", newState: "")
        
    }
}
// MARK: Encode/decode helpers
struct CalibrationResponse: Codable {
    let error: Bool
    let command: String
    let result: CalibrationResult?
    
    enum CodingKeys: String, CodingKey {
        case error = "Error"
        case command = "Command"
        case result = "Result"
    }
}

struct CalibrationResult: Codable {
    let createdOn, modifiedOn, uuid: String
    let metadata: CalibrationMetadata
    let requestids: [String]
    
    enum CodingKeys: String, CodingKey {
        case createdOn = "CreatedOn"
        case modifiedOn = "ModifiedOn"
        case uuid, metadata, requestids
    }
}

struct CalibrationMetadata: Codable {
    let glucoseLowerBound, glucoseUpperBound, rawTemp1, rawTemp2: Int
    
    enum CodingKeys: String, CodingKey {
        case glucoseLowerBound = "GLUCOSE_LOWER_BOUND"
        case glucoseUpperBound = "GLUCOSE_UPPER_BOUND"
        case rawTemp1 = "RAW_TEMP1"
        case rawTemp2 = "RAW_TEMP2"
    }
}

class JSONNull: Codable {
    public init() {}
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            throw DecodingError.typeMismatch(JSONNull.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONNull"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

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
