//
//  WatchState.swift
//  xdrip
//
//  Created by Paul Plant on 21/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

protocol WatchPayload: Codable {
    var asDictionary: [String: Any]? { get }
}

extension WatchPayload {
    var asDictionary: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }
}

/// current status data used to manage watch views
struct WatchStatus: WatchPayload {
    var generatedAt: Double = Date().timeIntervalSince1970
    var isMgDl: Bool = true
    var urgentLowLimitInMgDl: Double = 60
    var lowLimitInMgDl: Double = 80
    var highLimitInMgDl: Double = 170
    var urgentHighLimitInMgDl: Double = 250
    var activeSensorDescription: String?
    var sensorAgeInMinutes: Double = 0
    var sensorMaxAgeInMinutes: Double = 0
    var preferSensorCountdown: Bool = false
    var isMaster: Bool = true
    var followerDataSourceTypeRawValue: Int = 0
    var followerBackgroundKeepAliveTypeRawValue: Int = 0
    var timeStampOfLastFollowerConnection: Double?
    var secondsUntilFollowerDisconnectWarning: Int?
    var timeStampOfLastHeartBeat: Double?
    var secondsUntilHeartBeatDisconnectWarning: Int?
    var keepAliveIsDisabled: Bool = false

    // use this to track the AID/looping status if sent
    var deviceStatusAvailable: Bool?
    var deviceStatusCreatedAt: Double?
    var deviceStatusLastLoopDate: Double?
    var deviceStatusIOB: Double?
    var deviceStatusCOB: Double?
}

/// current BG chart data used to manage watch views
struct WatchBgReadings: WatchPayload {
    var generatedAt: Double = Date().timeIntervalSince1970
    var hoursIncluded: Double = 12
    var bgReadingValues: [Double] = []
    var bgReadingDatesAsDouble: [Double] = []
    var slopeOrdinal: Int = 1
    var deltaValueInUserUnit: Double = 0
}
