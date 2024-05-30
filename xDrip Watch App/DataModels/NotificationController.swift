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
    var bgValueAndTrend: String?
    var delta: String?
    var unit: String?
    var alertUrgencyType: AlertUrgencyType?
    var bgRangeDescriptionAsInt: Int?
    var glucoseChartImage: UIImage?
    
    override var body: NotificationView {
        NotificationView(
            alertTitle: alertTitle,
            bgValueAndTrend: bgValueAndTrend,
            delta: delta,
            unit: unit,
            alertUrgencyType: alertUrgencyType,
            bgRangeDescriptionAsInt: bgRangeDescriptionAsInt,
            glucoseChartImage: glucoseChartImage
        )
    }
    
    override func didReceive(_ notification: UNNotification) {
        // pull the userInfo dictionary from the received notification
        let userInfo = notification.request.content.userInfo
        
        // set the image and colours based upon the alertUrgencyType
        alertUrgencyType = AlertUrgencyType(rawValue: userInfo["alertUrgencyTypeRawValue"] as? Int ?? 0)
        
        // set the title label. This is common for all notifications
        alertTitle = userInfo["alertTitle"] as? String ?? ""
        
        // set the bg value and trend arrow if available
        bgValueAndTrend = (userInfo["bgValueString"] as? String ?? "") + (userInfo["trendString"] as? String ?? "")
        
        // set the bg value label color as per the rest of the app UI color
        // it's a bit of a workaround to keep the dictionary as codable
        bgRangeDescriptionAsInt = userInfo["BgRangeDescriptionAsInt"] as? Int ?? 0
        
        delta = userInfo["deltaString"] as? String ?? "-"
        unit = (userInfo["isMgDl"] as? Bool ?? true) ? Texts_Common.mgdl : Texts_Common.mmol
        
        // recode the image from the sent userInfo
        if let watchNotificationImageData = userInfo["watchNotificationImageAsString"] as? String, let imageData = Data(base64Encoded: watchNotificationImageData, options: .ignoreUnknownCharacters) {
            glucoseChartImage = UIImage(data: imageData)
        }
    }
}
