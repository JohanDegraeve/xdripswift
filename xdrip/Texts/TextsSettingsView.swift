import Foundation

/// all texts for Settings Views related texts
class Texts_SettingsView {
    static private let filename = "SettingsViews"
    
    // MARK: - Title of the first settings screen
    
    static let screenTitle: String = {
        return NSLocalizedString("settingsviews_settingstitle", tableName: filename, bundle: Bundle.main, value: "Settings", comment: "shown on top of the first settings screen, literally 'Settings'")
    }()

    // MARK: - Section General
    
    static let sectionTitleGeneral: String = {
        return NSLocalizedString("settingsviews_sectiontitlegeneral", tableName: filename, bundle: Bundle.main, value: "General", comment: "general settings, section title")
    }()

    static let labelSelectBgUnit:String = {
        return NSLocalizedString("settingsviews_selectbgunit", tableName: filename, bundle: Bundle.main, value: "Select Unit", comment: "for text in pop up where user can select bg unit")
    }()
    
    static let labelLowValue: String = {
        return NSLocalizedString("settingsviews_lowValue", tableName: filename, bundle: Bundle.main, value: "Low Value", comment: "general settings, low value")
    }()

    static let labelHighValue: String = {
        return NSLocalizedString("settingsviews_highValue", tableName: filename, bundle: Bundle.main, value: "High Value", comment: "general settings, high value")
    }()
    
    static let labelMasterOrFollower: String = {
        return NSLocalizedString("settingsviews_masterorfollower", tableName: filename, bundle: Bundle.main, value: "Master or Follower ?", comment: "general settings, master or follower")
    }()
    
    static let master: String = {
        return NSLocalizedString("settingsviews_master", tableName: filename, bundle: Bundle.main, value: "Master", comment: "general settings, literally master")
    }()
    
    static let follower: String = {
        return NSLocalizedString("settingsviews_follower", tableName: filename, bundle: Bundle.main, value: "Follower", comment: "general settings, literally follower")
    }()
    
    // MARK: - Section Transmitter
    
    static let sectionTitleTransmitter: String = {
        return NSLocalizedString("settingsviews_sectiontitletransmitter", tableName: filename, bundle: Bundle.main, value: "Transmitter", comment: "transmitter settings, section title")
    }()
    
    static let labelTransmitterType:String = {
        return NSLocalizedString("settingsviews_transmittertype", tableName: filename, bundle: Bundle.main, value: "Transmitter Type", comment: "transmitter settings, just the words that explain that the settings is about transmitter type")
    }()

    static let labelTransmitterId:String = {
        return NSLocalizedString("settingsviews_transmitterid", tableName: filename, bundle: Bundle.main, value: "Transmitter Id", comment: "transmitter settings, just the words that explain that the settings is about transmitter id")
    }()
    
    static let labelGiveTransmitterId:String = {
        return NSLocalizedString("settingsviews_givetransmitterid", tableName: filename, bundle: Bundle.main, value: "Enter Transmitter Id", comment: "transmitter settings, pop up that asks user to inter transmitter id")
    }()
    
    // MARK: - Section Alerts
    
    static let sectionTitleAlerting: String = {
        return NSLocalizedString("settingsviews_sectiontitlealerting", tableName: filename, bundle: Bundle.main, value: "Alerting", comment: "alerting settings, section title")
    }()
    
    static let labelAlertTypes: String = {
        return NSLocalizedString("settingsviews_row_alert_types", tableName: filename, bundle: Bundle.main, value: "Alert Types", comment: "alerting settings, row alert types")
    }()
    
    static let labelAlerts: String = {
        return NSLocalizedString("settingsviews_row_alerts", tableName: filename, bundle: Bundle.main, value: "Alerts", comment: "alerting settings, row alerts")
    }()
    
    // MARK: - Section Healthkit
    
    static let sectionTitleHealthKit: String = {
        return NSLocalizedString("settingsviews_sectiontitlehealthkit", tableName: filename, bundle: Bundle.main, value: "Healthkit", comment: "healthkit settings, section title")
    }()
    
    static let labelHealthKit:String = {
        return NSLocalizedString("settingsviews_healthkit", tableName: filename, bundle: Bundle.main, value: "HealthKit", comment: "healthkit settings, literally 'healthkit'")
    }()
    
    // MARK: - Section Dexcom Share
    
    static let sectionTitleDexcomShare: String = {
        return NSLocalizedString("settingsviews_sectiontitledexcomshare", tableName: filename, bundle: Bundle.main, value: "Dexcom Share", comment: "dexcom share settings, section title")
    }()
    
    static let labelUploadReadingstoDexcomShare = {
        return NSLocalizedString("settingsviews_uploadReadingstoDexcomShare", tableName: filename, bundle: Bundle.main, value: "Dexcom Share Upload", comment: "dexcom share settings, where user can select if readings should be uploaded to dexcom share yes or no")
    }()

    static let labelDexcomShareSerialNumber = {
        return NSLocalizedString("settingsviews_dexcomShareSerialNumber", tableName: filename, bundle: Bundle.main, value: "Serial", comment: "dexcom share settings settings, where user can set dexcom serial number to be used for dexcom share upload")
    }()
    
    static let labelUseUSDexcomShareurl = {
        return NSLocalizedString("settingsviews_useUSDexcomShareurl", tableName: filename, bundle: Bundle.main, value: "Use US url ?", comment: "dexcom share settings, where user can choose to use use url or not")
    }()
    
    static let labelDexcomShareAccountName = {
        return NSLocalizedString("settingsviews_dexcomShareAccountName", tableName: filename, bundle: Bundle.main, value: "Account", comment: "dexcom share settings, where user can set the dexcom share account name")
    }()

    static let giveDexcomShareAccountName = {
        return NSLocalizedString("settingsviews_giveDexcomShareAccountName", tableName: filename, bundle: Bundle.main, value: "Enter Dexcom Share Account Name", comment: "dexcom share settings, pop up that asks user to enter dexcom share account name")
    }()
    
    static let giveDexcomSharePassword = {
        return NSLocalizedString("settingsviews_giveDexcomSharePassword", tableName: filename, bundle: Bundle.main, value: "Enter Dexcom Share Password", comment: "dexcom share settings, pop up that asks user to enter dexcom share password")
    }()
    
    static let giveDexcomShareSerialNumber = {
        return NSLocalizedString("settingsviews_giveDexcomShareSerialNumber", tableName: filename, bundle: Bundle.main, value: "Enter Dexcom Share Serial Number", comment: "dexcom share settings, pop up that asks user to enter dexcom share serial number")
    }()
    
    // MARK: - Section NightScout
    
    static let sectionTitleNightScout: String = {
        return NSLocalizedString("settingsviews_sectiontitlenightscout", tableName: filename, bundle: Bundle.main, value: "NightScout", comment: "nightscout settings, section title")
    }()
    
    static let labelNightScoutEnabled = {
        return NSLocalizedString("settingsviews_nightScoutEnabled", tableName: filename, bundle: Bundle.main, value: "Nightscout enabled", comment: "nightscout settings, where user can enable or disable nightscout")
    }()

    static let labelNightScoutUrl = {
        return NSLocalizedString("settingsviews_nightScoutUrl", tableName: filename, bundle: Bundle.main, value: "Url", comment: "nightscout settings, where user can set the nightscout url")
    }()
    
    static let giveNightScoutUrl = {
        return NSLocalizedString("settingsviews_giveNightScoutUrl", tableName: filename, bundle: Bundle.main, value: "Enter NightScout Url", comment: "nightscout  settings, pop up that asks user to enter nightscout url")
    }()

    static let labelNightScoutAPIKey = {
        return NSLocalizedString("settingsviews_nightScoutAPIKey", tableName: filename, bundle: Bundle.main, value: "API Secret", comment: "nightscout settings, where user can set the nightscout api key")
    }()
    
    static let giveNightScoutAPIKey = {
        return NSLocalizedString("settingsviews_giveNightScoutAPIKey", tableName: filename, bundle: Bundle.main, value: "Enter NightScout API Key", comment: "nightscout settings, pop up that asks user to enter nightscout api key")
    }()
    
    // MARK: - Section Speak
    
    static let sectionTitleSpeak: String = {
        return NSLocalizedString("settingsviews_sectiontitlespeak", tableName: filename, bundle: Bundle.main, value: "Speak", comment: "speak settings, section title")
    }()

    static let labelSpeakBgReadings = {
        return NSLocalizedString("settingsviews_speakBgReadings", tableName: filename, bundle: Bundle.main, value: "Speak BG Readings", comment: "speak settings, where user can enable or disable speak readings")
    }()
    
    static let labelSpeakTrend = {
        return NSLocalizedString("settingsviews_speakTrend", tableName: filename, bundle: Bundle.main, value: "Speak Trend", comment: "speak settings, where enable or disable speak trend")
    }()
    
    static let labelSpeakDelta = {
        return NSLocalizedString("settingsviews_speakDelta", tableName: filename, bundle: Bundle.main, value: "Speak Delta", comment: "speak settings, where user can enable or disable speak delta")
    }()

    static let labelSpeakInterval = {
        return NSLocalizedString("settingsviews_speakInterval", tableName: filename, bundle: Bundle.main, value: "Interval", comment: "speak settings, where user can set the speak interval, speak each reading, each two readings ...")
    }()
}
