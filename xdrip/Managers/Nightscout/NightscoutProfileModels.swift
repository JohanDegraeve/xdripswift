//
//  NightscoutProfileModels.swift
//  xdrip
//
//  Created by Paul Plant on 23/10/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK: Internal Profile

/// Struct to hold internal Nightscout profile
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

// MARK: External downloaded Nightscout Profile

/// Struct to decode Nightscout profile response
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
