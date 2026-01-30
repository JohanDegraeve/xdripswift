//
//  MedtrumEasyViewModels.swift
//  xdrip
//
//  Copyright © 2025 xDrip4iOS. All rights reserved.
//

import Foundation

// MARK: - Request Models

/// Login request payload
struct MedtrumEasyViewLoginRequest: Codable {
    let user_name: String
    let user_type: String  // Always "P" for login request (response will contain actual type)
    let password: String
}

/// Monitor status query parameter (to be Base64-encoded)
struct MedtrumEasyViewMonitorParam: Codable {
    let ts: [Double]  // [start_timestamp, end_timestamp]
    let tz: Int       // Timezone offset (always 0 for UTC)
}

// MARK: - Response Models

/// Generic server response wrapper
struct MedtrumEasyViewResponse<T: Decodable>: Decodable {
    let error: Int      // 0 = success, 1001 = invalid credentials, 4001 = session expired
    let data: T?

    enum CodingKeys: String, CodingKey {
        case error
        case data
    }
}

/// Login response (note: login endpoint doesn't use the generic wrapper structure)
struct MedtrumEasyViewLoginResponse: Decodable {
    let error: Int
    let uid: Int? // uid must be optional as it isn't returned when there is an error
    let username: String?
    let user_type: String?
    let realname: String?
}

/// Login response data (kept for compatibility, but not used for login endpoint)
struct MedtrumEasyViewLoginData: Decodable {
    let uid: Int
    let username: String?
    let user_type: String?
    let realname: String?
}

/// Monitor status response data
struct MedtrumEasyViewMonitorData: Decodable {
    let chart: MedtrumEasyViewChart?
    let sensor_status: MedtrumEasyViewSensorStatus?
}

/// Chart data containing glucose readings
struct MedtrumEasyViewChart: Decodable {
    let sg: [MedtrumEasyViewGlucoseEntry]?
    let glucose_unit: String?
}

/// Sensor status with current glucose
struct MedtrumEasyViewSensorStatus: Decodable {
    let glucose: Double?
    let glucoseRate: Double?
    let updateTime: Double?
}

/// Individual glucose entry from sg array
/// ACTUAL Array format: [timestamp, glucose1, glucose2, glucose3, status_string]
/// Note: During normal operation, glucose1 contains the actual value in mmol/L
/// Status codes: "C"=Current/Normal, "H"=Warmup, "IC"=InCalib, "NC"=NoCalib, "CE0"/"CE1"=Error
struct MedtrumEasyViewGlucoseEntry: Decodable {
    let timestamp: Double    // Unix timestamp
    let glucose1: Double     // Actual glucose value in mmol/L
    let glucose2: Double
    let glucose3: Double
    let status: String       // Status string ("C", "H", "IC", "NC", "CE0", "CE1")

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        // Parse array elements in order
        self.timestamp = try container.decode(Double.self)
        self.glucose1 = try container.decode(Double.self)
        self.glucose2 = try container.decode(Double.self)
        self.glucose3 = try container.decode(Double.self)
        self.status = try container.decode(String.self)
    }
}

/// Parsed glucose measurement for internal use
struct MedtrumEasyViewGlucoseMeasurement {
    let timestamp: Date
    let glucoseInMmol: Double
    let status: String

    /// Create from API entry
    init(entry: MedtrumEasyViewGlucoseEntry) {
        self.timestamp = Date(timeIntervalSince1970: entry.timestamp)
        // Use glucose1 as the actual reading (in mmol/L)
        self.glucoseInMmol = entry.glucose1
        self.status = entry.status
    }
}

/// Connections response data for caregiver accounts
struct MedtrumEasyViewConnectionsData: Decodable {
    let has_next: Bool
    let has_prev: Bool
    let itemnum: Int
    let items: [MedtrumEasyViewPatientConnection]
    let next_num: Int
    let page: Int
    let pages: Int
    let prev_num: Int
}

/// Individual patient connection from caregiver connections list
struct MedtrumEasyViewPatientConnection: Codable {
    let uid: Int                // Patient's user ID
    let real_name: String       // Patient's name to match against configured name
    let username: String        // Patient's email
    let alias: String?          // Optional alias
    let birth_date: String?     // Birth date
    let gender: String?         // Gender code
    // sensor_status and pump_status fields exist but are not needed for now

    /// Helper to create display name for dropdown
    var displayName: String {
        if let alias = alias, !alias.isEmpty {
            return "\(real_name) (\(alias))"
        }
        return real_name
    }
}

// MARK: - Error Type

enum MedtrumEasyViewFollowError: Error {
    case missingCredentials
    case invalidCredentials
    case sessionExpired
    case decodingError
    case invalidResponse
    case networkError
    case loginPreventedByUser
}
