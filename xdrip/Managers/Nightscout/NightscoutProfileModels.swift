//
//  NightscoutProfileModels.swift
//  xdrip
//
//  Created by Paul Plant on 23/10/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK: Internal NightscoutProfile

/// Struct to hold internal Nightscout profile
/// Initialize from a NightscoutProfileResponse
struct NightscoutProfile: Codable {
    struct TimeValue: Codable, Hashable {
        var timeAsSecondsFromMidnight: Int
        var value: Double
        
        func toDate(date: Date) -> Date {
            return date.addingTimeInterval(Double(timeAsSecondsFromMidnight))
        }
    }
    
    var updatedDate: Date = .distantPast
    var lastCheckedDate: Date = .distantPast
    
    var basal: [TimeValue]?
    var carbratio: [TimeValue]?
    var sensitivity: [TimeValue]?
    var timezone: String?
    var dia: Double?
    var isMgDl: Bool?
    var startDate: Date = .distantPast
    var createdAt: Date = .distantPast
    var profileName: String?
    var enteredBy: String?
    
    // return true if data has been written after initialization
    func hasData() -> Bool {
        return updatedDate != .distantPast
    }
}

// MARK: Internal NightscoutProfile Initializer

extension NightscoutProfile {
    /// Initialize from a NightscoutProfileResponse
    init(from response: NightscoutProfileResponse) {
        self.init()
        
        // Parse startDate
        let startDateString = response.startDate
        self.startDate = ISO8601DateFormatter.withFractionalSeconds.date(from: startDateString) ?? ISO8601DateFormatter().date(from: startDateString) ?? .distantPast
        self.profileName = response.defaultProfile
        self.enteredBy = response.enteredBy
        self.updatedDate = .now
        
        // Use the first profile in the store (usually "Default")
        if let profile = response.store[response.defaultProfile] ?? response.store.first?.value {
            self.timezone = profile.timezone
            self.dia = profile.dia
            self.isMgDl = profile.units.lowercased() == "mg/dl"
            self.basal = profile.basal.map { TimeValue(timeAsSecondsFromMidnight: $0.timeAsSeconds, value: $0.value) }
            self.carbratio = profile.carbratio.map { TimeValue(timeAsSecondsFromMidnight: $0.timeAsSeconds, value: $0.value) }
            self.sensitivity = profile.sens.map { TimeValue(timeAsSecondsFromMidnight: $0.timeAsSeconds, value: $0.value) }
        }
    }
}

// MARK: - External downloaded NightscoutProfileResponse

/// Robust, tolerant unified model for decoding Nightscout profile endpoint
struct NightscoutProfileResponse: Codable {
    struct Profile: Codable {
        struct ProfileEntry: Codable {
            let time: String
            let value: Double
            let timeAsSeconds: Int
        }
        
        let basal: [ProfileEntry]
        let carbratio: [ProfileEntry]
        let sens: [ProfileEntry]
        let targetLow: [ProfileEntry]
        let targetHigh: [ProfileEntry]
        let timezone: String
        let dia: Double
        let units: String
        
        private enum CodingKeys: String, CodingKey {
            case carbratio
            case sens
            case targetHigh = "target_high"
            case timezone
            case dia
            case targetLow = "target_low"
            case basal
            case units
        }
    }
    
    let id: String
    let store: [String: Profile]
    let units: String?
    let defaultProfile: String
    let startDate: String
    let enteredBy: String?
    
    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case units
        case startDate
        case defaultProfile
        case enteredBy
        case store
    }
}
