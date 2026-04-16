//
//  LibreLinkUpModels.swift
//  xdrip
//
//  Created by Paul Plant on 26/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK: LibreLinkUpRegion Enum

/// different regions for LibreLinkUp
public enum LibreLinkUpRegion: Int, CaseIterable {
    // when adding regions, add new cases at the end (ie 11, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    // the order of the data source types will in the uiview is determined by the initializer init(forRowAt row: Int)

    case notConfigured = 0
    case ae = 1
    case ap = 2
    case au = 3
    case ca = 4
    case de = 5
    case eu = 6
    case eu2 = 7
    case fr = 8
    case jp = 9
    case la = 10
    case us = 11
    
    init?() {
        self = .notConfigured
    }
    
    /// optional initializer from string - this is used to set the new region when the server response has a redirect with a "country" value
    init?(from string: String) {
        switch string.lowercased() {
        case "ae":
            self = .ae
        case "ap":
            self = .ap
        case "au":
            self = .au
        case "ca":
            self = .ca
        case "de":
            self = .de
        case "eu":
            self = .eu
        case "eu2":
            self = .eu2
        case "fr":
            self = .fr
        case "jp":
            self = .jp
        case "la":
            self = .la
        case "us":
            self = .us
        default:
            self = .notConfigured
        }
    }
    
    /// text description of the region as a string
    var description: String {
        switch self {
        case .notConfigured:
            return "Global"
        case .ae:
            return "United Arab Emirates"
        case .ap:
            return "Asia/Pacific"
        case .au:
            return "Australia"
        case .ca:
            return "Canada"
        case .de:
            return "Germany"
        case .eu:
            return "Europe"
        case .eu2:
            return "Great Britain"
        case .fr:
            return "France"
        case .jp:
            return "Japan"
        case .la:
            return "Latin America"
        case .us:
            return "United States"
        }
    }
    
    // MARK: URLs per LibreLinkUpRegion
    
    /// returns the URL for the login request based upon self (i.e. the region)
    var urlLogin: String {
        if UserDefaults.standard.followerDataSourceType != .libreLinkUpRussia {
            switch self {
            case .notConfigured:
                return "https://api.libreview.io/llu/auth/login"
            default:
                return "https://api-\(self).libreview.io/llu/auth/login"
            }
        } else {
            return "https://api.libreview.ru/llu/auth/login"
        }
    }
    
    /// returns the URL for the connections request based upon self (i.e. the region)
    var urlConnections: String {
        if UserDefaults.standard.followerDataSourceType != .libreLinkUpRussia {
            switch self {
            case .notConfigured:
                return "https://api.libreview.io/llu/connections"
            default:
                return "https://api-\(self).libreview.io/llu/connections"
            }
        } else {
            return "https://api.libreview.ru/llu/connections"
        }
    }
    
    /// returns the URL for the graph request based upon self (i.e. the region) and also the passed patient Id
    func urlGraph(patientId: String) -> String {
        if UserDefaults.standard.followerDataSourceType != .libreLinkUpRussia {
            switch self {
            case .notConfigured:
                return "https://api.libreview.io/llu/connections/\(patientId)/graph"
            default:
                return "https://api-\(self).libreview.io/llu/connections/\(patientId)/graph"
            }
        } else {
            return "https://api.libreview.ru/llu/connections/\(patientId)/graph"
        }
    }
    
    /// gives the raw value of the libreLinkUpRegion for a specific section in a uitableview, is the opposite of the initializer
    static func libreLinkUpRegionRawValue(rawValue: Int) -> Int {
        switch rawValue {
        case 0: // notConfigured
            return 0
        case 1: // ae
            return 1
        case 2: // ap
            return 2
        case 3: // au
            return 3
        case 4: // ca
            return 4
        case 5: // de
            return 5
        case 6: // eu
            return 6
        case 7: // eu2
            return 7
        case 8: // fr
            return 8
        case 9: // jp
            return 9
        case 10: // la
            return 10
        case 11: // us
            return 11
        default:
            fatalError("in libreLinkUpRawValue, unknown case")
        }
    }
}

// MARK: JSON Struct Generic Server Response

/// Generic struct to handle all HTTP responses
struct Response<T: Codable>: Codable {
    // status is used to catch the server response
    // status 2 means that the user credentials were wrong
    // status 4 means that the user needs to accept the latest privacy policy or other document change
    let status: Int
    
    // data is where the main payload of the response is held
    let data: T?
}

// MARK: JSON Structs Login Response

/// struct to define data.xxxxxx
struct RequestLoginResponse: Codable {
    let user: RequestLoginResponseUser?
    
    let authTicket: RequestLoginResponseAuthTicket?
    
    // these last two will only exist if the user tries to login with an incorrect region/country
    // to check if this is the case, we need to see if they exist and also if redirect == true && region != empty
    let redirect: Bool?
    
    let region: String?
}

/// struct to define data.user.xxxxxx
struct RequestLoginResponseUser: Codable {
    let id: String?
    
    // we'll use this to display the country abbreviation ("ES", "DE", GB") just for interest as sometimes the servers do not force a redirect to the "correct" region (which is fine, but it's interesting to note)
    let country: String?
}

/// struct to define data.authTicket.xxxxxx
struct RequestLoginResponseAuthTicket: Codable {
    // not optional as the server always returns them even if the token is nil
    let token: String
    
    let expires: Double
}

// MARK: JSON Structs Connections Response

/// struct to define data.xxxxxx
struct RequestConnectionsResponse: Codable {
    let patientId: String?
}

// MARK: JSON Structs Graph Response

/// struct to define data.xxxxxx
struct RequestGraphResponse: Codable {
    let connection: RequestGraphResponseConnection?
    
    let activeSensors: [RequestGraphResponseActiveSensors]?
    
    let graphData: [RequestGraphResponseGlucoseMeasurement]?
}

/// struct to define data.connection.xxxxx
struct RequestGraphResponseConnection: Codable {
    let glucoseMeasurement: RequestGraphResponseGlucoseMeasurement?
    
    let sensor: RequestGraphResponseSensor?
}

/// struct to define data.glucoseMeasurement.xxxxx and also data.graphData.[x].xxxxx
struct RequestGraphResponseGlucoseMeasurement: Codable {
    // the glucose measurement "factory" timestamp which is in UTC timezone
    let FactoryTimestamp: Date
    
    // the glucose measurement value in mg/dL
    let ValueInMgPerDl: Double
}

/// struct to define data.activeSensors.[x].sensor.xxxxx
struct RequestGraphResponseActiveSensors: Codable {
    let sensor: RequestGraphResponseSensor?
}

/// struct to define data.activeSensors.[x].sensor.xxxxx (or also data.connection.sensor.xxxxx)
struct RequestGraphResponseSensor: Codable {
    // the sensor serial number
    let sn: String
    
    // the sensor start date
    let a: Double
}
