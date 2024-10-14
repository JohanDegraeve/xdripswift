//
//  NotificationViewController.swift
//  xDrip Notification Context Extension
//
//  Created by Paul Plant on 6/5/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import SwiftUI

/// customer content view controller to modify how the notifications are displayed to the user (only used for notifications with the snoozeCategory (which is most of them))
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    
    @IBOutlet weak var notificationViewContainer: UIView!
        
    var alertTitle: String?
    var bgReadingValues: [Double]?
    var bgReadingDates: [Date]?
    var isMgDl: Bool?
    var slopeOrdinal: Int?
    var deltaValueInUserUnit: Double?
    var urgentLowLimitInMgDl: Double?
    var lowLimitInMgDl: Double?
    var highLimitInMgDl: Double?
    var urgentHighLimitInMgDl: Double?
    var alertUrgencyType: AlertUrgencyType?
    
    var bgUnitString: String?
    var bgValueInMgDl: Double?
    var bgReadingDate: Date?
    var bgValueStringInUserChosenUnit: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func didReceive(_ notification: UNNotification) {
        // pull the userInfo dictionary from the received notification
        let userInfo = notification.request.content.userInfo
        
        // set the title label. This is common for all notifications
        alertTitle = userInfo["alertTitle"] as? String ?? ""
        
        // set the image and colours based upon the alertUrgencyType
        alertUrgencyType = AlertUrgencyType(rawValue: userInfo["alertUrgencyTypeRawValue"] as? Int ?? 0)
        
        bgReadingValues = userInfo["bgReadingValues"] as? [Double] ?? [0]
        isMgDl = userInfo["isMgDl"] as? Bool ?? true
        slopeOrdinal = userInfo["slopeOrdinal"] as? Int ?? 0
        deltaValueInUserUnit = userInfo["deltaValueInUserUnit"] as? Double ?? 0
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
        
        bgValueStringInUserChosenUnit = (bgReadingValues?.count ?? 0) > 0 ? bgReadingValues?[0].mgDlToMmolAndToString(mgDl: isMgDl ?? true) ?? "" : ""
        
        let vc = UIHostingController(rootView: NotificationView(
            alertTitle: alertTitle,
            bgReadingValues: bgReadingValues,
            bgReadingDates: bgReadingDates,
            isMgDl: isMgDl,
            slopeOrdinal: slopeOrdinal,
            deltaValueInUserUnit: deltaValueInUserUnit,
            urgentLowLimitInMgDl: urgentLowLimitInMgDl,
            lowLimitInMgDl: lowLimitInMgDl,
            highLimitInMgDl: highLimitInMgDl,
            urgentHighLimitInMgDl: urgentHighLimitInMgDl,
            alertUrgencyType: alertUrgencyType,
            bgUnitString: bgUnitString,
            bgValueInMgDl: bgValueInMgDl,
            bgReadingDate: bgReadingDate,
            bgValueStringInUserChosenUnit: bgValueStringInUserChosenUnit
        ))

        let swiftuiView = vc.view!
        swiftuiView.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(vc)
        view.addSubview(swiftuiView)
        
        NSLayoutConstraint.activate([
            swiftuiView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            swiftuiView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            swiftuiView.widthAnchor.constraint(equalTo: self.view.widthAnchor),
            swiftuiView.heightAnchor.constraint(equalTo: self.view.heightAnchor)
        ])
        vc.didMove(toParent: self)
        
        // set the notification view size and update it
        self.preferredContentSize = CGSize(width: UIScreen.main.bounds.size.width, height: 320)
        self.view.setNeedsUpdateConstraints()
        self.view.setNeedsLayout()
    }
}
