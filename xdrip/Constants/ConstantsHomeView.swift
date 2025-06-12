/// constants for home view, ie first view

import UIKit
import SwiftUI

enum ConstantsHomeView {
    
    /// how often to update the labels in the homeview (ie label with latest reading, minutes ago, etc..)
    /// Changed from 15.0 to 60.0 seconds as part of chart caching optimization
    /// - Labels only need updating once per minute for "minutes ago" display
    /// - Libre 2 provides new data every minute anyway
    /// - Reduces timer wake-ups by 75%
    static let updateHomeViewIntervalInSeconds = 60.0
    
    /// info email adres, appears in licenseInfo
    static let infoEmailAddress = "xdrip@proximus.be"
    
    /// application name, appears in licenseInfo as title
    static let applicationName: String = {

        guard let dictionary = Bundle.main.infoDictionary else {return "unknown"}
        
        guard let version = dictionary["CFBundleDisplayName"] as? String else {return "unknown"}
        
        return version
        
    }()
  
    /// URL where the online help should be loaded from
    static let onlineHelpURL = "https://xdrip4ios.readthedocs.io"
    
    /// this is the base locale for the online help. Anybody using the app without having this locale set will be able to translate
    static let onlineHelpBaseLocale = "en" // English
    
    /// example URL to show the online help in Spanish using Google Translate
    /// https://xdrip4ios-readthedocs-io.translate.goog/en/latest/?_x_tr_sl=auto&_x_tr_tl=es&_x_tr_hl=es&_x_tr_pto=nui
    /// we'll use this to spilt into two separate strings
    static let onlineHelpURLTranslated1 = "https://xdrip4ios-readthedocs-io.translate.goog/en/latest/?_x_tr_sl=auto&_x_tr_tl="
    static let onlineHelpURLTranslated2 = "&_x_tr_hl=es&_x_tr_pto=nui"

    /// github.com repository URL for the project
    static let gitHubURL = "https://github.com/JohanDegraeve/xdripswift"
    
    // MARK: - Sensor Info View
    
    /// how many seconds the Nightscout URL (if displayed in the data source info view) should be hidden when double tapped
    static let hideUrlDuringTimeInSeconds: Int = 10
    
    /// progress view
    static let sensorProgressViewProgressColorInitial: UIColor = .white
    static let sensorProgressViewProgressColor: UIColor = .gray
    static let sensorProgressViewTrackingColor: UIColor = UIColor(white: 0.15, alpha: 1.0)
    
    /// warning time left / colour
    static let sensorProgressViewWarningInMinutes: Double = 60 * 24.0 // 24 hours before the sensor reaches max age
    static let sensorProgressViewProgressColorWarning: UIColor = .yellow
    static let sensorProgressViewProgressColorWarningSwiftUI: Color = .yellow
    
    /// urgent time left / colour
    static let sensorProgressViewUrgentInMinutes: Double = 60 * 12.0 // 12 hours before the sensor reaches max age
    static let sensorProgressViewProgressColorUrgent: UIColor = .orange
    static let sensorProgressViewProgressColorUrgentSwiftUI: Color = .orange
    
    /// colour for an expired sensor
    static let sensorProgressExpired: UIColor = .red
    static let sensorProgressExpiredSwiftUI: Color = .red
    
    /// colour for an normal text
    static let sensorProgressNormalTextColor: UIColor = .lightGray
    static let sensorProgressNormalTextColorSwiftUI: Color = .white
    static let sensorProgressViewNormalColorSwiftUI: Color = .gray
    
    // MARK: - Screen lock
    
    /// colour for the dimmed screen lock overlay view
    static let screenLockDimmingOptionsDimmed: UIColor = .black.withAlphaComponent(0.3)
    
    /// colour for the dark screen lock overlay view
    static let screenLockDimmingOptionsDark: UIColor = .black.withAlphaComponent(0.5)
    
    /// colour for the very dark screen lock overlay view
    static let screenLockDimmingOptionsVeryDark: UIColor = .black.withAlphaComponent(0.7)
    
    // MARK: - For loop/AID status
    
    /// after how many seconds should the loop status be shown as a warning
    static let loopShowWarningAfterMinutes: TimeInterval = 60 * 9
    
    /// after how many seconds should the loop status be shown as having no current data to show
    static let loopShowNoDataAfterMinutes: TimeInterval = 60 * 17
    
    /// opacity level for the background of the AID status banner
    static let AIDStatusBannerBackgroundOpacity = 0.1
    
    /// number of hours for the default canula max age (usually 3 days = 72 hours)
    static let CAGEDefaultMaxHours: Int = 72
    
    /// after much time *before max hours* should we show the CAGE as a warning condition (yellow)?
    static let CAGEWarningTimeIntervalBeforeMaxHours: TimeInterval = 60 * 60 * 12
    
    /// after much time *before max hours* should we show the CAGE as an urgent condition (red)?
    static let CAGEUrgentTimeIntervalBeforeMaxHours: TimeInterval = 60 * 60 * 6
    
    /// below how many units should we show the pump reservoir  as a warning condition (yellow)?
    static let pumpReservoirWarning: Double = 30
    
    /// below how many units should we show the pump reservoir as an urgent condition (red)?
    static let pumpReservoirUrgent: Double = 10
    
    /// below what percentage should we show the pump battery as a warning condition (yellow)?
    static let pumpBatteryPercentWarning: Int = 20
    
    /// below what percentage should we show the pump battery as an urgent condition (red)?
    static let pumpBatteryPercentUrgent: Int = 10
    
}
