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
        return NSLocalizedString("settingsviews_selectbgunit", tableName: filename, bundle: Bundle.main, value: "Blood Glucose Units:", comment: "for text in pop up where user can select bg unit")
    }()
    
    static let labelMasterOrFollower: String = {
        return NSLocalizedString("settingsviews_masterorfollower", tableName: filename, bundle: Bundle.main, value: "Use as Master or Follower?", comment: "general settings, master or follower")
    }()
    
    static let master: String = {
        return NSLocalizedString("settingsviews_master", tableName: filename, bundle: Bundle.main, value: "Master", comment: "general settings, literally master")
    }()
    
    static let follower: String = {
        return NSLocalizedString("settingsviews_follower", tableName: filename, bundle: Bundle.main, value: "Follower", comment: "general settings, literally follower")
    }()
    
    static let labelShowReadingInNotification: String = {
        return NSLocalizedString("showReadingInNotification", tableName: filename, bundle: Bundle.main, value: "Show BG in Notifications?", comment: "general settings, should reading be shown in notification yes or no")
    }()
    
    static let labelShowReadingInAppBadge: String = {
        return NSLocalizedString("labelShowReadingInAppBadge", tableName: filename, bundle: Bundle.main, value: "Show BG in the App Badge?", comment: "general settings, should reading be shown in app badge yes or no")
    }()
    
    static let multipleAppBadgeValueWith10: String = {
        return NSLocalizedString("multipleAppBadgeValueWith10", tableName: filename, bundle: Bundle.main, value: "Multiply App Badge Reading by 10?", comment: "general settings, should reading be multiplied with 10 yes or no")
    }()
    
    static let warningChangeFromMasterToFollower: String = {
        return NSLocalizedString("warningChangeFromMasterToFollower", tableName: filename, bundle: Bundle.main, value: "Switch from master to follower will stop your current sensor. Do you want to continue ?", comment: "general settings, when switching from master to follower, if confirmation is asked, this message will be shown.")
    }()
    
    // MARK: - Section Home Screen
    
    static let sectionTitleHomeScreen: String = {
        return NSLocalizedString("settingsviews_sectiontitlehomescreen", tableName: filename, bundle: Bundle.main, value: "Home Screen", comment: "home screen settings, section title")
    }()

    static let labelUseObjectives: String = {
        return NSLocalizedString("settingsviews_useobjectives", tableName: filename, bundle: Bundle.main, value: "Show Objectives in Graph?", comment: "home screen settings, use objectives in graph")
    }()

    static let labelUrgentHighValue: String = {
        return NSLocalizedString("settingsviews_urgenthighValue", tableName: filename, bundle: Bundle.main, value: "Urgent High Value:", comment: "home screen settings, urgent high value")
    }()
    
    static let labelHighValue: String = {
        return NSLocalizedString("settingsviews_highValue", tableName: filename, bundle: Bundle.main, value: "High Value:", comment: "home screen settings, high value")
    }()
    
    static let labelTargetValue: String = {
        return NSLocalizedString("settingsviews_targetValue", tableName: filename, bundle: Bundle.main, value: "Target Value:", comment: "home screen settings, target value")
    }()
    
    static let labelLowValue: String = {
        return NSLocalizedString("settingsviews_lowValue", tableName: filename, bundle: Bundle.main, value: "Low Value:", comment: "home screen settings, low value")
    }()
    
    static let labelUrgentLowValue: String = {
        return NSLocalizedString("settingsviews_urgentlowValue", tableName: filename, bundle: Bundle.main, value: "Urgent Low Value:", comment: "home screen settings, urgent low value")
    }()
    
    static let labelShowColoredObjectives: String = {
        return NSLocalizedString("settingsviews_showcoloredobjectives", tableName: filename, bundle: Bundle.main, value: "Show Colored Lines?", comment: "home screen settings, show colored objectives lines")
    }()
    
    static let labelShowTarget: String = {
        return NSLocalizedString("settingsviews_showtarget", tableName: filename, bundle: Bundle.main, value: "Show Target Line?", comment: "home screen settings, show target line")
    }()
    
    
    // MARK: - Section Transmitter
    
    static let sectionTitleTransmitter: String = {
        return NSLocalizedString("settingsviews_sectiontitletransmitter", tableName: filename, bundle: Bundle.main, value: "Transmitter", comment: "transmitter settings, section title")
    }()
    
    static let labelTransmitterType:String = {
        return NSLocalizedString("settingsviews_transmittertype", tableName: filename, bundle: Bundle.main, value: "Transmitter Type:", comment: "transmitter settings, just the words that explain that the settings is about transmitter type")
    }()

    static let labelTransmitterId:String = {
        return NSLocalizedString("settingsviews_transmitterid", tableName: filename, bundle: Bundle.main, value: "Transmitter ID:", comment: "transmitter settings, just the words that explain that the settings is about transmitter id")
    }()
    
    static let labelGiveTransmitterId:String = {
        return NSLocalizedString("settingsviews_givetransmitterid", tableName: filename, bundle: Bundle.main, value: "Enter Transmitter ID", comment: "transmitter settings, pop up that asks user to inter transmitter id")
    }()
    
    static let labelResetTransmitter:String = {
        return NSLocalizedString("settingsviews_resettransmitter", tableName: filename, bundle: Bundle.main, value: "Reset Transmitter", comment: "transmitter settings, to explain that settings is about resetting the transmitter")
    }()
    
    static let labelWebOOPTransmitter:String = {
        return NSLocalizedString("settingsviews_webooptransmitter", tableName: filename, bundle: Bundle.main, value: "Use Libre Algorithm?", comment: "web oop settings in bluetooth peripheral view : enabled or not")
    }()
    
    static let labelWebOOP:String = {
        return NSLocalizedString("settingsviews_labelWebOOP", tableName: filename, bundle: Bundle.main, value: "xDrip or Libre Algorithm", comment: "weboop settings, title of the dialogs where site and token are asked - also used when viewing bluetoothperipheral settings, the title of the section")
    }()
    
    static let labelNonFixedTransmitter:String = {
        return NSLocalizedString("settingsviews_nonfixedtransmitter", tableName: filename, bundle: Bundle.main, value: "Use Multi-point Calibration?", comment: "non fixed calibration slopes settings in bluetooth peripheral view : enabled or not")
    }()
    
    static let labelNonFixed:String = {
        return NSLocalizedString("settingsviews_labelNonFixed", tableName: filename, bundle: Bundle.main, value: "Multi-point Calibration", comment: "non fixed settings, title of the section")
    }()
    
    static let transmitterId8OrHigherNotSupported: String = {
        return NSLocalizedString("transmitterId8OrHigherNotSupported", tableName: filename, bundle: Bundle.main, value: "Transmitters with ID 8Gxxxx or newer are not currently supported!", comment: "User sets a transmitter id with id 8G or higher. This is not supported")
    }()
    
    // MARK: - Section Alerts
    
    static let sectionTitleAlerting: String = {
        return NSLocalizedString("settingsviews_sectiontitlealerting", tableName: filename, bundle: Bundle.main, value: "Alarm", comment: "alerting settings, section title")
    }()
    
    static let labelAlertTypes: String = {
        return NSLocalizedString("settingsviews_row_alert_types", tableName: filename, bundle: Bundle.main, value: "Alarm Types", comment: "alerting settings, row alert types")
    }()
    
    static let labelAlerts: String = {
        return NSLocalizedString("settingsviews_row_alerts", tableName: filename, bundle: Bundle.main, value: "Alarms", comment: "alerting settings, row alerts")
    }()
    
    // MARK: - Section Healthkit
    
    static let sectionTitleHealthKit: String = {
        return NSLocalizedString("settingsviews_sectiontitlehealthkit", tableName: filename, bundle: Bundle.main, value: "Apple Health", comment: "healthkit settings, section title")
    }()
    
    static let labelHealthKit:String = {
        return NSLocalizedString("settingsviews_healthkit", tableName: filename, bundle: Bundle.main, value: "Write Data to Apple Health?", comment: "healthkit settings, literally 'healthkit'")
    }()
    
    // MARK: - Section Dexcom Share
    
    static let sectionTitleDexcomShare: String = {
        return NSLocalizedString("settingsviews_sectiontitledexcomshare", tableName: filename, bundle: Bundle.main, value: "Dexcom Share", comment: "dexcom share settings, section title")
    }()
    
    static let labelUploadReadingstoDexcomShare = {
        return NSLocalizedString("settingsviews_uploadReadingstoDexcomShare", tableName: filename, bundle: Bundle.main, value: "Upload to Dexcom Share?", comment: "dexcom share settings, where user can select if readings should be uploaded to dexcom share yes or no")
    }()

    static let labelDexcomShareSerialNumber = {
        return NSLocalizedString("settingsviews_dexcomShareSerialNumber", tableName: filename, bundle: Bundle.main, value: "Receiver Serial Number:", comment: "dexcom share settings settings, where user can set dexcom serial number to be used for dexcom share upload")
    }()
    
    static let labelUseUSDexcomShareurl = {
        return NSLocalizedString("settingsviews_useUSDexcomShareurl", tableName: filename, bundle: Bundle.main, value: "Use Dexcom US Servers?", comment: "dexcom share settings, where user can choose to use US url or not")
    }()
    
    static let labelDexcomShareAccountName = {
        return NSLocalizedString("settingsviews_dexcomShareAccountName", tableName: filename, bundle: Bundle.main, value: "Account Name:", comment: "dexcom share settings, where user can set the dexcom share account name")
    }()

    static let giveDexcomShareAccountName = {
        return NSLocalizedString("settingsviews_giveDexcomShareAccountName", tableName: filename, bundle: Bundle.main, value: "Enter Dexcom Share Account Name", comment: "dexcom share settings, pop up that asks user to enter dexcom share account name")
    }()
    
    static let giveDexcomSharePassword = {
        return NSLocalizedString("settingsviews_giveDexcomSharePassword", tableName: filename, bundle: Bundle.main, value: "Enter Dexcom Share Password", comment: "dexcom share settings, pop up that asks user to enter dexcom share password")
    }()
    
    static let giveDexcomShareSerialNumber = {
        return NSLocalizedString("settingsviews_giveDexcomShareSerialNumber", tableName: filename, bundle: Bundle.main, value: "Enter the Dexcom Receiver Serial Number", comment: "dexcom share settings, pop up that asks user to enter dexcom share serial number")
    }()
    
    // MARK: - Section NightScout
    
    static let sectionTitleNightScout: String = {
        return NSLocalizedString("settingsviews_sectiontitlenightscout", tableName: filename, bundle: Bundle.main, value: "NightScout", comment: "nightscout settings, section title")
    }()
    
    static let labelNightScoutEnabled = {
        return NSLocalizedString("settingsviews_nightScoutEnabled", tableName: filename, bundle: Bundle.main, value: "Enable Nightscout?", comment: "nightscout settings, where user can enable or disable nightscout")
    }()

    static let labelNightScoutUrl = {
        return NSLocalizedString("settingsviews_nightScoutUrl", tableName: filename, bundle: Bundle.main, value: "URL:", comment: "nightscout settings, where user can set the nightscout url")
    }()
    
    static let useSchedule = {
        return NSLocalizedString("settingsviews_useSchedule", tableName: filename, bundle: Bundle.main, value: "Use Upload Schedule?", comment: "nightscout settings, where user can select to use schedule or not")
    }()
    
    static let schedule = {
        return NSLocalizedString("schedule", tableName: filename, bundle: Bundle.main, value: "Schedule:", comment: "nightscout or dexcom share settings, where user can select to edit the schedule")
    }()
    
    static let giveNightScoutUrl = {
        return NSLocalizedString("settingsviews_giveNightScoutUrl", tableName: filename, bundle: Bundle.main, value: "Enter your NightScout URL", comment: "nightscout  settings, pop up that asks user to enter nightscout url")
    }()

    static let labelNightScoutAPIKey = {
        return NSLocalizedString("settingsviews_nightScoutAPIKey", tableName: filename, bundle: Bundle.main, value: "API_SECRET:", comment: "nightscout settings, where user can set the nightscout api key")
    }()
    
    static let giveNightScoutAPIKey = {
        return NSLocalizedString("settingsviews_giveNightScoutAPIKey", tableName: filename, bundle: Bundle.main, value: "Enter your API_SECRET", comment: "nightscout settings, pop up that asks user to enter nightscout api key")
    }()
    
    static let editScheduleTimePickerSubtitle: String = {
        return NSLocalizedString("editScheduleTimePickerSubtitle", tableName: filename, bundle: Bundle.main, value: "Change: ", comment: "used for editing schedule for NightScout upload and Dexcom Share upload")
    }()
    
    static let timeScheduleViewTitle: String = {
        return NSLocalizedString("timeScheduleViewTitle", tableName: filename, bundle: Bundle.main, value: "On/Off Time Schedule for ", comment: "When creating schedule for Nightscout or Dexcom Share upload, this is the top label text")
    }()
    
    static let uploadSensorStartTime: String = {
        return NSLocalizedString("uploadSensorStartTime", tableName: filename, bundle: Bundle.main, value: "Upload Sensor Start Time?", comment: "nightscout settings, title of row")
    }()
    
    static let testUrlAndAPIKey: String = {
        return NSLocalizedString("testUrlAndAPIKey", tableName: filename, bundle: Bundle.main, value: "Test Nightscout URL and API_SECRET?", comment: "nightscout settings, when clicking the cell, test the url and api key")
    }()

    static let nightScoutPort: String = {
        return NSLocalizedString("nightScoutPort", tableName: filename, bundle: Bundle.main, value: "Port", comment: "nightscout settings, port to use")
    }()

    // MARK: - Section Speak
    
    static let sectionTitleSpeak: String = {
        return NSLocalizedString("settingsviews_sectiontitlespeak", tableName: filename, bundle: Bundle.main, value: "Voice", comment: "speak settings, section title")
    }()

    static let labelSpeakBgReadings = {
        return NSLocalizedString("settingsviews_speakBgReadings", tableName: filename, bundle: Bundle.main, value: "Speak BG Readings?", comment: "speak settings, where user can enable or disable speak readings")
    }()
    
    static let labelSpeakLanguage = {
        return NSLocalizedString("settingsviews_speakBgReadingslanguage", tableName: filename, bundle: Bundle.main, value: "Language:", comment: "speak settings, where user can select the language")
    }()
    
    static let speakReadingLanguageSelection:String = {
        return NSLocalizedString("settingsviews_speakreadingslanguageselection", tableName: filename, bundle: Bundle.main, value: "Select Language", comment: "speak reading settings, text in pop up where user can select the language")
    }()
    
    static let labelSpeakTrend = {
        return NSLocalizedString("settingsviews_speakTrend", tableName: filename, bundle: Bundle.main, value: "Speak Trend?", comment: "speak settings, where enable or disable speak trend")
    }()
    
    static let labelSpeakDelta = {
        return NSLocalizedString("settingsviews_speakDelta", tableName: filename, bundle: Bundle.main, value: "Speak Delta?", comment: "speak settings, where user can enable or disable speak delta")
    }()

    static let labelSpeakInterval = {
        return NSLocalizedString("settingsviews_speakInterval", tableName: filename, bundle: Bundle.main, value: "Interval:", comment: "speak settings, where user can set the speak interval, speak each reading, each two readings ...")
    }()
    
    static let speakIntervalMessage = {
        return NSLocalizedString("settingsviews_speakIntervalMessage", tableName: filename, bundle: Bundle.main, value: "Minimum interval between two readings (mins)", comment: "When clicking the interval setting, a pop up asks for number of minutes between two spoken readings, this is the message displayed in the pop up")
    }()
    
    // MARK: - Section About Info
    
    static let sectionTitleAbout: String = {
        return NSLocalizedString("settingsviews_sectiontitleAbout", tableName: filename, bundle: Bundle.main, value: "About xDrip4iOS", comment: "about settings, section title")
    }()
    
    static let version = {
        return NSLocalizedString("settingsviews_Version", tableName: filename, bundle: Bundle.main, value: "Version:", comment: "used in settings, section Info, title of the version setting")
    }()

    static let build = {
        return NSLocalizedString("settingsviews_build", tableName: filename, bundle: Bundle.main, value: "Build:", comment: "used in settings, section Info, title of the build setting")
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
        return NSLocalizedString("m5stack_settingsviews_giveBluetoothPassword", tableName: filename, bundle: Bundle.main, value: "Enter Bluetooth Password", comment: "M5 stack bluetooth  settings, pop up that asks user to enter the password")
    }()

    static let m5StackBrightness: String = {
        return NSLocalizedString("m5stack_settingsviews_brightness", tableName: filename, bundle: Bundle.main, value: "Screen Brightness", comment: "M5 stack setting, brightness")
    }()
    
    // MARK: - Section Apple Watch
    
    static let appleWatchSectionTitle: String = {
        return NSLocalizedString("appleWatchSectionTitle", tableName: filename, bundle: Bundle.main, value: "Apple Watch", comment: "Apple Watch Settings - section title")
    }()
    
    static let createCalendarEvent: String = {
        return NSLocalizedString("createCalendarEvent", tableName: filename, bundle: Bundle.main, value: "Create Calendar Events?", comment: "Apple Watch Settings - text in row where create event is enabled or disabled ")
    }()

    static let calenderId: String = {
        return NSLocalizedString("calenderId", tableName: filename, bundle: Bundle.main, value: "Calendar To Use?", comment: "Apple Watch Settings - text in row where user needs to select a calendar")
    }()

    static let displayTrendInCalendarEvent: String = {
        return NSLocalizedString("displayTrendInCalendarEvent", tableName: filename, bundle: Bundle.main, value: "Display Trend?", comment: "Apple Watch Settings - text in row where user needs to say if trend should be displayed or not")
    }()
    
    static let displayUnitInCalendarEvent: String = {
        return NSLocalizedString("displayUnitInCalendarEvent", tableName: filename, bundle: Bundle.main, value: "Dispaly Unit?", comment: "Apple Watch Settings - text in row where user needs to say if unit should be displayed or not")
    }()
    
    static let displayDeltaInCalendarEvent: String = {
        return NSLocalizedString("displayDeltaInCalendarEvent", tableName: filename, bundle: Bundle.main, value: "Dispaly Delta?", comment: "Apple Watch Settings - text in row where user needs to say if delta should be displayed or not")
    }()
    
    static let infoCalendarAccessDeniedByUser: String = {
        return NSLocalizedString("infoCalendarAccessDeniedByUser", tableName: filename, bundle: Bundle.main, value: "You previously denied access to your Calendar.\n\nTo enable it go to your device settings, privacy, calendars and enable it", comment: "If user has earlier denied access to calendar, and then tries to activate creation of events in calendar, this message will be shown")
    }()
    
    static let infoCalendarAccessRestricted: String = {
        return NSLocalizedString("infoCalendarAccessRestricted", tableName: filename, bundle: Bundle.main, value: "You cannot give authorization to xDrip4iOS to access your calendar. This is possibly due to active restrictions such as parental controls being in place.", comment: "If user is not allowed to give any app access to the Calendar, due to restrictions. And then tries to activate creation of events in calendar, this message will be shown")
    }()
    
    static let sectionTitleTrace: String = {
        return NSLocalizedString("sectionTitleTrace", tableName: filename, bundle: Bundle.main, value: "Issue Reporting", comment: "in Settings, section title for Trace")
    }()
    
    static let sendTraceFile: String = {
        return NSLocalizedString("sendTraceFile", tableName: filename, bundle: Bundle.main, value: "Send Issue Report", comment: "in Settings, row title to send settings")
    }()
    
    static let debugLevel: String = {
        return NSLocalizedString("debugLevel", tableName: filename, bundle: Bundle.main, value: "Include Debug Level", comment: "in Settings, to enable debug level in trace file")
    }()
    
    static let describeProblem: String = {
        return NSLocalizedString("describeProblem", tableName: filename, bundle: Bundle.main, value: "Explain why you need to send the trace file with as much detail as possible. If you have already reported your problem in the Facebook support group 'xDrip4iOS', then mention your facebook name in the e-mail", comment: "Text in pop up shown when user wants to send the trace file")
    }()
    
    static let emailNotConfigured: String = {
        return NSLocalizedString("emailNotConfigured", tableName: filename, bundle: Bundle.main, value: "You must configure an e-mail account on your iOS device.", comment: "user tries to send trace file but there's no native email account configured")
    }()
    
    static let emailbodyText: String = {
        return NSLocalizedString("emailbodyText", tableName: filename, bundle: Bundle.main, value: "Problem Description: ", comment: "default text in email body, when user wants to send trace file.")
    }()
    
    static let failedToSendEmail: String = {
        return NSLocalizedString("failedToSendEmail", tableName: filename, bundle: Bundle.main, value: "Failed to Send Email", comment: "In case user tries to send trace file via email but error occurs.")
    }()
    
    static let volumeTestSoundPlayerExplanation: String = {
        return NSLocalizedString("volumeTestSoundPlayerExplanation", tableName: filename, bundle: Bundle.main, value: "An alarm sound is now being played with the same volume that will be used for an Alarm Type with 'Override Mute' = On\n\n(Used for all alarms except Missed Reading alerts which always use the iOS volume.)\n\nChange the volume with the volume buttons and press OK when done.", comment: "In Settings, Alerts section, there's an option to test the volume settings, this is text explaining the test when clicking the row - this is for sound player volume test")
    }()
    
    static let volumeTestSoundPlayer: String = {
        return NSLocalizedString("volumeTestSoundPlayer", tableName: filename, bundle: Bundle.main, value: "Volume Test (with Override Mute On)", comment: "In Settings, Alerts section, there's an option to test the volume of the sound player, this is the title of the row")
    }()
    
    static let volumeTestiOSSound: String = {
        return NSLocalizedString("volumeTestiOSSound", tableName: filename, bundle: Bundle.main, value: "Volume Test (Current iPhone Volume)", comment: "In Settings, Alerts section, there's an option to test the volume of ios sound, this is the title of the row")
    }()

    static let volumeTestiOSSoundExplanation: String = {
        return NSLocalizedString("volumeTestiOSSoundExplanation", tableName: filename, bundle: Bundle.main, value: "An alarm sound is now being played with the same volume that will be used for an Alarm Type with 'Override Mute' = Off\n\n(Also used always for Missed Reading alarms which use the iOS volume.)\n\nPress one of the volume buttons to stop the sound, then change the volume with the volume buttons to the desired volume and test again.", comment: "In Settings, Alerts section, there's an option to test the volume settings, this is text explaining the test when clicking the row - this is for ios sound volume test")
    }()
    
}

