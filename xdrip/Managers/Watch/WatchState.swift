//
//  WatchState.swift
//  xdrip
//
//  Created by Paul Plant on 21/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

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
    var lastHeartBeatTimeStamp: Date?
    var heartbeatShowDisconnectedTimeInSeconds: Int?
    var disableComplications: Bool?
}
