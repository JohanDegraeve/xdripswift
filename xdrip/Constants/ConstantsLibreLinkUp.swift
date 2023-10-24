//
//  ConstantsLibreLinkUp.swift
//  xdrip
//
//  Created by Paul Plant on 26/9/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsLibreLinkUp {
    
    /// string to hold the LibreLinkUp version number
    static let libreLinkUpVersionDefault: String = "4.7.0"
    
    // TODO: Remove for production if not used in the end. It seems a good idea to move the URL (or URL parts) to a Constants file, but it makes things messy
    static let libreLinkUpUrlGeneric: String = "https://api.libreview.io"
    
    static let libreLinkUpUrlForRegion1: String = "https://api-"
    static let libreLinkUpUrlForRegion2: String = "libreview.io"
    
    static let libreLinkUpLoginEndpoint: String = "/llu/auth/login"
    static let libreLinkUpConnectionsEndpoint: String = "/llu/connections"
    static let libreLinkUpGraphEndpoint: String = "/graph"
    
}
