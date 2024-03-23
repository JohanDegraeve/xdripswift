//
//  WatchState.swift
//  xdrip
//
//  Created by Paul Plant on 21/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// model of the data we'll use to manage the watch views
struct WatchState: Codable {
    var bgReadingValues: [Double] = []
    var bgReadingDates: [Date] = []
    var isMgDl: Bool?
    var slopeOrdinal: Int?
    var deltaChangeInMgDl: Double?
    var urgentLowLimitInMgDl: Double?
    var lowLimitInMgDl: Double?
    var highLimitInMgDl: Double?
    var urgentHighLimitInMgDl: Double?
    var updatedDate: Date?
    var activeSensorDescription: String?
    var sensorAgeInMinutes: Double?
    var sensorMaxAgeInMinutes: Double?
    var isMaster: Bool?
    var followerDataSourceTypeRawValue: Int?
    var followerBackgroundKeepAliveTypeRawValue: Int?
    var timeStampOfLastFollowerConnection: Date?
    var secondsUntilFollowerDisconnectWarning: Int?
    var timeStampOfLastHeartBeat: Date?
    var secondsUntilHeartBeatDisconnectWarning: Int?
    var disableComplications: Bool?
}
