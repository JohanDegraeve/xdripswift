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
