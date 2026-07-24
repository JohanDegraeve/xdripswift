/// constants for home view, ie first view

import SwiftUI

enum ConstantsHomeView {

    /// Standard corner radius for Home panels and compact status views.
    static let standardCornerRadius: CGFloat = 10
    
    /// how often to update the labels in the homeview (ie label with latest reading, minutes ago, etc..)
    static let updateHomeViewIntervalInSeconds = 15.0
    
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

    /// URL where the calibration documentation should be loaded from
    static let calibrationHelpURL = "https://xdrip4ios.readthedocs.io/en/latest/configure/calibrate/"

    /// example URL to show the calibration documentation in Spanish using Google Translate
    /// https://xdrip4ios-readthedocs-io.translate.goog/en/latest/configure/calibrate/?_x_tr_sl=auto&_x_tr_tl=es&_x_tr_hl=es&_x_tr_pto=nui
    static let calibrationHelpURLTranslated1 = "https://xdrip4ios-readthedocs-io.translate.goog/en/latest/configure/calibrate/?_x_tr_sl=auto&_x_tr_tl="
    static let calibrationHelpURLTranslated2 = "&_x_tr_hl=es&_x_tr_pto=nui"

    /// github.com repository URL for the project
    static let gitHubURL = "https://github.com/JohanDegraeve/xdripswift"

    /// github.com repository name for the project
    static let gitHubRepositoryName = "xdripswift"

    /// license type for the project
    static let licenseType = "GNU GPL v3"
    
    // MARK: - Sensor Info View
    
    /// how many seconds the Nightscout URL (if displayed in the data source info view) should be hidden when double tapped
    static let hideUrlDuringTimeInSeconds: Int = 10
    
    /// warning time left / colour
    static let sensorProgressViewWarningInMinutes: Double = 60 * 24.0 // 24 hours before the sensor reaches max age
    static let sensorProgressViewProgressColorWarningSwiftUI: Color = .yellow
    
    /// urgent time left / colour
    static let sensorProgressViewUrgentInMinutes: Double = 60 * 12.0 // 12 hours before the sensor reaches max age
    static let sensorProgressViewProgressColorUrgentSwiftUI: Color = .orange
    
    /// colour for an expired sensor
    static let sensorProgressExpiredSwiftUI: Color = .red
    
    /// colour for an normal text
    static let sensorProgressNormalTextColorSwiftUI: Color = .white
    static let sensorProgressViewNormalColorSwiftUI: Color = .gray
    
    // MARK: - Screen lock
    
    /// colour for the dimmed screen lock overlay view
    static let screenLockDimmingOptionsDimmed = Color.black.opacity(0.3)
    
    /// colour for the dark screen lock overlay view
    static let screenLockDimmingOptionsDark = Color.black.opacity(0.5)
    
    /// colour for the very dark screen lock overlay view
    static let screenLockDimmingOptionsVeryDark = Color.black.opacity(0.7)
    
    // MARK: - For loop/AID status
    
    /// after how many seconds should the loop status be shown as a warning
    static let loopShowWarningAfterMinutes: TimeInterval = 60 * 9
    
    /// after how many seconds should the loop status be shown as having no current data to show
    static let loopShowNoDataAfterMinutes: TimeInterval = 60 * 17

    /// symbol to show when the loop has run recently
    static let loopStatusRecentSystemImage = "circle"

    /// symbol to show when the loop is older but still within the acceptable window
    static let loopStatusAcceptableSystemImage = "circle"

    /// symbol to show when device status is current but there is no recent loop
    static let loopStatusNotLoopingSystemImage = "circle.slash"

    /// symbol to show when device status is stale or missing
    static let loopStatusNoDataSystemImage = "circle.slash"
    
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
