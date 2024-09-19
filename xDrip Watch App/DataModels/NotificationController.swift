//
//  NotificationController.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 24/5/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import WatchKit
import SwiftUI
import UserNotifications

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    var alertTitle: String?
    var bgReadingValues: [Double]?
    var bgReadingDates: [Date]?
    var isMgDl: Bool?
    var slopeOrdinal: Int?
    var deltaChangeInMgDl: Double?
    var urgentLowLimitInMgDl: Double?
    var lowLimitInMgDl: Double?
    var highLimitInMgDl: Double?
    var urgentHighLimitInMgDl: Double?
    var alertUrgencyType: AlertUrgencyType?
    
    var bgUnitString: String?
    var bgValueInMgDl: Double?
    var bgReadingDate: Date?
    var bgValueStringInUserChosenUnit: String?
    
    override var body: NotificationView {
        NotificationView(
            alertTitle: alertTitle,
            bgReadingValues: bgReadingValues,
            bgReadingDates: bgReadingDates,
            isMgDl: isMgDl,
            slopeOrdinal: slopeOrdinal,
            deltaChangeInMgDl: deltaChangeInMgDl,
            urgentLowLimitInMgDl: urgentLowLimitInMgDl,
            lowLimitInMgDl: lowLimitInMgDl,
            highLimitInMgDl: highLimitInMgDl,
            urgentHighLimitInMgDl: urgentHighLimitInMgDl,
            alertUrgencyType: alertUrgencyType,
            bgUnitString: bgUnitString,
            bgValueInMgDl: bgValueInMgDl,
            bgReadingDate: bgReadingDate,
            bgValueStringInUserChosenUnit: bgValueStringInUserChosenUnit
        )
    }
    
    override func didReceive(_ notification: UNNotification) {
        // pull the userInfo dictionary from the received notification
        let userInfo = notification.request.content.userInfo
        
        // set the title label. This is common for all notifications
        alertTitle = userInfo["alertTitle"] as? String ?? ""
        
        // set the image and colours based upon the alertUrgencyType
        alertUrgencyType = AlertUrgencyType(rawValue: userInfo["alertUrgencyTypeRawValue"] as? Int ?? 0)
        
        bgReadingValues = userInfo["bgReadingValues"] as? [Double] ?? [0]
        isMgDl = userInfo["isMgDl"] as? Bool ?? true
        slopeOrdinal = userInfo["slopeOrdinal"] as? Int ?? 0
        deltaChangeInMgDl = userInfo["deltaChangeInMgDl"] as? Double ?? 0
        urgentLowLimitInMgDl = userInfo["urgentLowLimitInMgDl"] as? Double ?? 0
        lowLimitInMgDl = userInfo["lowLimitInMgDl"] as? Double ?? 0
        highLimitInMgDl = userInfo["highLimitInMgDl"] as? Double ?? 0
        urgentHighLimitInMgDl = userInfo["urgentHighLimitInMgDl"] as? Double ?? 0
        
        let bgReadingDatesFromDictionary: [Double] = userInfo["bgReadingDatesAsDouble"] as? [Double] ?? [0]
        bgReadingDates = bgReadingDatesFromDictionary.map { (bgReadingDateAsDouble) -> Date in
            return Date(timeIntervalSince1970: bgReadingDateAsDouble)
        }
        
        bgUnitString = isMgDl ?? true ? Texts_Common.mgdl : Texts_Common.mmol
        bgValueInMgDl = (bgReadingValues?.count ?? 0) > 0 ? bgReadingValues?[0] : nil
        bgReadingDate = (bgReadingDates?.count ?? 0) > 0 ? bgReadingDates?[0] : nil
        
        bgValueStringInUserChosenUnit = (bgReadingValues?.count ?? 0) > 0 ? bgReadingValues?[0].mgdlToMmolAndToString(mgdl: isMgDl ?? true) ?? "" : ""
        
    }
}
