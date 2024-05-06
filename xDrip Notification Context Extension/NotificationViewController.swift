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

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    
    @IBOutlet weak var alertIconOutlet: UIImageView!
    @IBOutlet weak var alertTitleLabel: UILabel!
    @IBOutlet weak var bannerOutlet: UIView!
    
    @IBOutlet weak var glucoseChartImage: UIImageView!
    @IBOutlet weak var bgValueLabel: UILabel!
    @IBOutlet weak var deltaLabel: UILabel!
    @IBOutlet weak var unitLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()        
        
        // set the notification view size and update it
        self.preferredContentSize = CGSize(width: UIScreen.main.bounds.size.width, height: 310)
        self.view.setNeedsUpdateConstraints()
        self.view.setNeedsLayout()
    }
    
    func didReceive(_ notification: UNNotification) {
        
        // pull the userInfo dictionary from the received notification
        let userInfo = notification.request.content.userInfo
        
        // set the image and colours based upon the alertUrgencyType
        if let alertUrgencyType = AlertUrgencyType(rawValue: userInfo["alertUrgencyTypeRawValue"] as? Int ?? 0) {
            if let alertImageString = alertUrgencyType.alertImageString {
                alertIconOutlet.image = UIImage(systemName: alertImageString)
                alertIconOutlet.tintColor = alertUrgencyType.bannerTextColor
            }
            
            alertTitleLabel.textColor = alertUrgencyType.bannerTextColor
            bannerOutlet.backgroundColor = alertUrgencyType.bannerBackgroundColor
        }
        
        // set the title label. This is common for all notifications
        alertTitleLabel.text = userInfo["alertTitle"] as? String ?? ""
        
        var bgValueAndTrendString = userInfo["bgValueString"] as? String ?? ""
        
        if let trendString = userInfo["trendString"] as? String {
            bgValueAndTrendString += trendString
        }
        
        bgValueLabel.text = bgValueAndTrendString
        
        // set the bg value label color as per the rest of the app UI color
        // it's a bit of a workaround to keep the dictionary as codable
        if let BgRangeDescriptionAsInt = userInfo["BgRangeDescriptionAsInt"] as? Int {
            switch BgRangeDescriptionAsInt {
            case 0: // inRange
                bgValueLabel.textColor = .green
            case 1: // notUrgent
                bgValueLabel.textColor = .yellow
            default: // urgent
                bgValueLabel.textColor = .red
            }
        }
        
        deltaLabel.text = userInfo["deltaString"] as? String ?? "-"
        unitLabel.text = (userInfo["isMgDl"] as? Bool ?? true) ? Texts_Common.mgdl : Texts_Common.mmol
        
        // let's add the last attachment as an image to the view
        // the first attachment is the thumbnail, the expanded image is the second/last one.
        if let attachment = notification.request.content.attachments.last {
            if attachment.url.startAccessingSecurityScopedResource() {
                let data = NSData(contentsOfFile: attachment.url.path)
                self.glucoseChartImage.image = UIImage(data: data! as Data)
                attachment.url.stopAccessingSecurityScopedResource()
            }
        }
    }
}
