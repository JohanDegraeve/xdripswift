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

/// customer content view controller to modify how the notifications are displayed to the user (only used for notifications with the snoozeCategory (which is most of them))
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
        
        // set the text and banner colours based upon the alertUrgencyType
        if let alertUrgencyType = AlertUrgencyType(rawValue: userInfo["alertUrgencyTypeRawValue"] as? Int ?? 2) {
            alertTitleLabel.textColor = alertUrgencyType.bannerTextUIColor
            bannerOutlet.backgroundColor = alertUrgencyType.bannerBackgroundUIColor
        }
        
        // set the text labels from the userInfo dictionary (assuming any of them could be nil)
        alertTitleLabel.text = userInfo["alertTitle"] as? String ?? ""
        bgValueLabel.text = (userInfo["bgValueString"] as? String ?? "") + (userInfo["trendString"] as? String ?? "")
        deltaLabel.text = userInfo["deltaString"] as? String ?? "-"
        unitLabel.text = (userInfo["isMgDl"] as? Bool ?? true) ? Texts_Common.mgdl : Texts_Common.mmol
        
        // set the bg value label color as per the rest of the app UI color
        // it's a bit of a workaround using Ints to keep the dictionary as codable
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
        
        // let's add the last attachment as an image to the view
        // the first attachment is the thumbnail, the expanded image is the second/last one
        if let attachment = notification.request.content.attachments.last {
            if attachment.url.startAccessingSecurityScopedResource() {
                let data = NSData(contentsOfFile: attachment.url.path)
                glucoseChartImage.image = UIImage(data: data! as Data)
                attachment.url.stopAccessingSecurityScopedResource()
            }
        }
    }
}
