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
    
    static let labelShowReadingInNotification: String = {
        return NSLocalizedString("showReadingInNotification", tableName: filename, bundle: Bundle.main, value: "Reading in notification", comment: "general settings, should reading be shown in notification yes or no")
    }()
    
    static let labelShowReadingInAppBadge: String = {
        return NSLocalizedString("labelShowReadingInAppBadge", tableName: filename, bundle: Bundle.main, value: "Reading in app badge", comment: "general settings, should reading be shown in app badge yes or no")
    }()
    
    static let multipleAppBadgeValueWith10: String = {
        return NSLocalizedString("multipleAppBadgeValueWith10", tableName: filename, bundle: Bundle.main, value: "Multiply reading by 10", comment: "general settings, should reading be multiplied with 10 yes or no")
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
    
    static let labelResetTransmitter:String = {
        return NSLocalizedString("settingsviews_resettransmitter", tableName: filename, bundle: Bundle.main, value: "Reset Transmitter", comment: "transmitter settings, to explain that settings is about resetting the transmitter")
    }()
    
    static let labelWebOOPTransmitter:String = {
        return NSLocalizedString("settingsviews_webooptransmitter", tableName: filename, bundle: Bundle.main, value: "Web OOP Enabled", comment: "transmitter settings, to enable or didsable web oop")
    }()
    
    static let labelWebOOPSite:String = {
        return NSLocalizedString("settingsviews_labelWebOOPSite", tableName: filename, bundle: Bundle.main, value: "Web OOP site", comment: "transmitter settings, the web oop site url")
    }()
    
    static let labelWebOOPtoken:String = {
        return NSLocalizedString("settingsviews_labelWebOOPtoken", tableName: filename, bundle: Bundle.main, value: "Web OOP token", comment: "transmitter settings, the web oop token")
    }()
    
    static let labelWebOOPSiteExplainingText:String = {
        return NSLocalizedString("settingsviews_labelWebOOPSiteExplainingText", tableName: filename, bundle: Bundle.main, value: "Web OOP site (leave empty to use default value)", comment: "transmitter settings, the web oop site url, explaining text in dialog")
    }()
    
    static let labelWebOOPtokenExplainingText:String = {
        return NSLocalizedString("settingsviews_labelWebOOPtokenExplainingText", tableName: filename, bundle: Bundle.main, value: "Web OOP token (leave empty to use default value)", comment: "transmitter settings, the web oop token, explaining text in dialog")
    }()
    
    static let labelWebOOP:String = {
        return NSLocalizedString("settingsviews_labelWebOOP", tableName: filename, bundle: Bundle.main, value: "Web OOP", comment: "transmitter settings, title of the dialogs where site and token are asked")
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
    
    static let useSchedule = {
        return NSLocalizedString("settingsviews_useSchedule", tableName: filename, bundle: Bundle.main, value: "Use schedule", comment: "nightscout settings, where user can select to use schedule or not")
    }()
    
    static let schedule = {
        return NSLocalizedString("schedule", tableName: filename, bundle: Bundle.main, value: "Schedule", comment: "nightscout or dexcom share settings, where user can select to edit the schedule")
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
    
    static let editScheduleTimePickerSubtitle: String = {
        return NSLocalizedString("editScheduleTimePickerSubtitle", tableName: filename, bundle: Bundle.main, value: "change : ", comment: "used for editing schedule for NightScout upload and Dexcom Share upload")
    }()
    
    static let timeScheduleViewTitle: String = {
        return NSLocalizedString("timeScheduleViewTitle", tableName: filename, bundle: Bundle.main, value: "On/Off time schedule for ", comment: "When creating schedule for Nightscout or Dexcom Share upload, this is the top label text")
    }()

    // MARK: - Section Speak
    
    static let sectionTitleSpeak: String = {
        return NSLocalizedString("settingsviews_sectiontitlespeak", tableName: filename, bundle: Bundle.main, value: "Speak", comment: "speak settings, section title")
    }()

    static let labelSpeakBgReadings = {
        return NSLocalizedString("settingsviews_speakBgReadings", tableName: filename, bundle: Bundle.main, value: "Speak BG Readings", comment: "speak settings, where user can enable or disable speak readings")
    }()
    
    static let labelSpeakLanguage = {
        return NSLocalizedString("settingsviews_speakBgReadingslanguage", tableName: filename, bundle: Bundle.main, value: "Language", comment: "speak settings, where user can select the language")
    }()
    
    static let speakReadingLanguageSelection:String = {
        return NSLocalizedString("settingsviews_speakreadingslanguageselection", tableName: filename, bundle: Bundle.main, value: "Select Language", comment: "speak reading settings, text in pop up where user can select the language")
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
    
    static let speakIntervalMessage = {
        return NSLocalizedString("settingsviews_speakIntervalMessage", tableName: filename, bundle: Bundle.main, value: "Minimum interval between two readings, in minutes", comment: "When clicking the interval setting, a pop up asks for number of minutes between two spoken readings, this is the message displayed in the pop up")
    }()
    
    static let labelSpeakRate = {
        return NSLocalizedString("settingsviews_speakRate", tableName: filename, bundle: Bundle.main, value: "Speak Rate", comment: "speak settings, where user can set the speak rate")
    }()
    static let labelSpeakRateMessage = {
        return NSLocalizedString("settingsviews_speakRateMessage", tableName: filename, bundle: Bundle.main, value: "Value between 0 and 1", comment: "When clicking the rate setting, a pop up asks for the rate, this is the message displayed in the pop up")
    }()
    
    // MARK: - Section Info
    
    static let version = {
        return NSLocalizedString("settingsviews_Version", tableName: filename, bundle: Bundle.main, value: "Version", comment: "used in settings, section Info, title of the version setting")
    }()

    static let build = {
        return NSLocalizedString("settingsviews_build", tableName: filename, bundle: Bundle.main, value: "Build", comment: "used in settings, section Info, title of the build setting")
    }()
    
    static let license = {
        return NSLocalizedString("settingsviews_license", tableName: filename, bundle: Bundle.main, value: "License", comment: "used in settings, section Info, title of the license setting")
    }()
    
    // MARK: - Section M5Stack
    
    static let m5StackSettingsViewScreenTitle: String = {
        return NSLocalizedString("m5stack_settingsviews_settingstitle", tableName: filename, bundle: Bundle.main, value: "M5 Stack Settings", comment: "shown on top of the first settings screen")
    }()
    
    static let m5StackTextColor: String = {
        return NSLocalizedString("m5stack_settingsviews_textColor", tableName: filename, bundle: Bundle.main, value: "Text Color", comment: "name of setting for text color")
    }()
    
    static let m5StackbackGroundColor: String = {
        return NSLocalizedString("m5stack_settingsviews_backGroundColor", tableName: filename, bundle: Bundle.main, value: "Background Color", comment: "name of setting for back ground color")
    }()

    static let m5StackRotation: String = {
        return NSLocalizedString("m5stack_settingsviews_rotation", tableName: filename, bundle: Bundle.main, value: "Rotation", comment: "name of setting for rotation")
    }()
    
    static let m5StackSectionTitleBluetooth: String = {
        return NSLocalizedString("m5stack_settingsviews_sectiontitlebluetooth", tableName: filename, bundle: Bundle.main, value: "Bluetooth", comment: "bluetooth settings, section title - also used in bluetooth peripheral view, eg when viewing M5Stack details. This is the title of the first section")
    }()
    
    static let giveBlueToothPassword: String = {
        return NSLocalizedString("m5stack_settingsviews_giveBluetoothPassword", tableName: filename, bundle: Bundle.main, value: "Enter Bluetooth password", comment: "M5 stack bluetooth  settings, pop up that asks user to enter the password")
    }()

    static let m5StackBrightness: String = {
        return NSLocalizedString("m5stack_settingsviews_brightness", tableName: filename, bundle: Bundle.main, value: "Brightness", comment: "M5 stack setting, brightness")
    }()
    
}
