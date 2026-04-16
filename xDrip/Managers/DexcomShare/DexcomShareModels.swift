//
//  DexcomShareModels.swift
//  xdrip
//
//  Created by Paul Plant on 4/9/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK: - Dexcom Share models
struct DexcomShareLoginRequest: Codable {
    let accountName: String
    let applicationId: String
    let password: String
}

struct DexcomEGV: Codable {
    let DT: String
    let ST: String
    let WT: String
//    let Trend: Int
    let Value: Int
}

/// Dexcom Share server regions with descriptions and URLs
enum DexcomShareRegion: Int, CaseIterable, Codable {
    case none = 0
    case us = 1
    case global = 2
    case jp = 3

    var description: String {
        switch self {
        case .none:
            return "None"
        case .us:
            return "US"
        case .global:
            return "Global"
        case .jp:
            return "Japan"
        }
    }
    
    var regionServerNumber: String {
        switch self {
        case .none:
            return ""
        case .us:
            return "1"
        case .global:
            return "2"
        case .jp:
            return "3"
        }
    }
    
    var regionCountriesDescription: String {
        switch self {
        case .none:
            return ""
        case .us:
            return "United States"
        case .global:
            return "Australia, Canada, Europe, Hong Kong, Korea, Malaysia, Middle East, New Zealand, South Africa, South America, United Kingdom"
        case .jp:
            return "Japan, Singapore"
        }
    }

    // https://github.com/LoopKit/dexcom-share-client-swift/blob/82a9179d444b3e79d5e9cfe99bbe7f298c4e8b40/ShareClient/ShareClient.swift#L30
    var baseURL: URL {
        switch self {
        case .us:
            return URL(string: ConstantsDexcomShare.usBaseShareUrl)!
        case .jp:
            return URL(string: ConstantsDexcomShare.japanBaseShareUrl)!
        default:
            return URL(string: ConstantsDexcomShare.globalBaseShareUrl)!
        }
    }
    
    // https://github.com/LoopKit/dexcom-share-client-swift/blob/82a9179d444b3e79d5e9cfe99bbe7f298c4e8b40/ShareClient/ShareClient.swift#L37
    var applicationID: String {
        switch self {
        case .jp:
            return ConstantsDexcomShare.applicationIdJapan
        default:
            // all other markets use the original Application ID
            return ConstantsDexcomShare.applicationId
        }
    }
}
