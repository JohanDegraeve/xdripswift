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
    var bgReadingDatesAsDouble: [Double] = []
    var isMgDl: Bool?
    var slopeOrdinal: Int?
    var deltaValueInUserUnit: Double?
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
    var timeStampOfLastFollowerConnection: Double?
    var secondsUntilFollowerDisconnectWarning: Int?
    var timeStampOfLastHeartBeat: Double?
    var secondsUntilHeartBeatDisconnectWarning: Int?
    var keepAliveIsDisabled: Bool?
    var liveDataIsEnabled: Bool?
    var remainingComplicationUserInfoTransfers: Int?
    
    var asDictionary: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }
}
