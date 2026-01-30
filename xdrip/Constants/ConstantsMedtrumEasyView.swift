//
//  ConstantsMedtrumEasyView.swift
//  xdrip
//
//  Copyright © 2025 xDrip4iOS. All rights reserved.
//

import Foundation

enum ConstantsMedtrumEasyView {

    /// Base URL for Medtrum EasyView API
    static let baseUrl = "https://easyview.medtrum.eu"

    /// Polling interval in seconds (60 seconds like LibreLinkUp)
    static let pollingIntervalSeconds: Double = 60

    /// Conversion factor from mmol/L to mg/dL
    static let mmolToMgdlFactor: Double = 18.0182

    /// HTTP headers required by the Medtrum EasyView API
    static let requestHeaders = [
        "Content-Type": "application/json",
        "Accept": "application/json, text/plain, */*",
        "AppTag": "v=3.0.2(15);n=eyvw",
    ]

    /// Maximum time range to fetch (in seconds) - 24 hours
    static let maxTimeRangeSeconds: Double = 86400

}
