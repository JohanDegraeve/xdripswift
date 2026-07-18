import Foundation

/// all texts for Settings Views related texts
class Texts_SettingsView {
    static private let filename = "SettingsViews"
    
    // MARK: - Generic for all Settings Views
    
    static let valueIsRequired: String = {
        return NSLocalizedString("settingsviews_valueIsRequired", tableName: filename, bundle: Bundle.main, value: "⚠️ Required", comment: "this setting is required")
    }()
    
    // MARK: - Title of the first settings screen
    
    static let screenTitle: String = {
        return NSLocalizedString("settingsviews_settingstitle", tableName: filename, bundle: Bundle.main, value: "Settings", comment: "shown on top of the first settings screen, literally 'Settings'")
    }()

    static let glucoseDisplaySectionTitle: String = {
        return NSLocalizedString("settingsviews_glucoseDisplaySectionTitle", tableName: filename, bundle: Bundle.main, value: "Glucose Display", comment: "settings group title for glucose display options")
    }()

    static let glucoseRangesSectionTitle: String = {
        return NSLocalizedString("settingsviews_glucoseRangesSectionTitle", tableName: filename, bundle: Bundle.main, value: "Glucose Ranges", comment: "settings section title for glucose range threshold values")
    }()

    static let glucoseRangesSectionFooter: String = {
        return NSLocalizedString("settingsviews_glucoseRangesSectionFooter", tableName: filename, bundle: Bundle.main, value: "Glucose Ranges only affect the main chart display colours. They are not related to Alarm values.", comment: "settings footer explaining what glucose ranges affect")
    }()

    static let alertsAndNotificationsSectionTitle: String = {
        return NSLocalizedString("settingsviews_alertsAndNotificationsSectionTitle", tableName: filename, bundle: Bundle.main, value: "Alerts and Notifications", comment: "settings group title for alerts and notifications")
    }()

    static let sharingAndServicesSectionTitle: String = {
        return NSLocalizedString("settingsviews_sharingAndServicesSectionTitle", tableName: filename, bundle: Bundle.main, value: "Sharing and Services", comment: "settings group title for sharing and external services")
    }()

    static let osAidLoopShareSectionTitle: String = {
        return NSLocalizedString("settingsviews_osAidLoopShareSectionTitle", tableName: filename, bundle: Bundle.main, value: "OS-AID Share", comment: "settings section title for OS-AID sharing")
    }()

    static let issueReportSectionTitle: String = {
        return NSLocalizedString("settingsviews_issueReportSectionTitle", tableName: filename, bundle: Bundle.main, value: "Issue Report", comment: "settings section title for sending issue report logs")
    }()

    static let issueReportSectionFooter: String = {
        return NSLocalizedString("settingsviews_issueReportSectionFooter", tableName: filename, bundle: Bundle.main, value: "Do not send an Issue Report unless requested by an xDrip4iOS developer or your report will be automatically deleted.", comment: "settings footer warning users not to send issue reports unless requested")
    }()

    static func appBannerVersion(_ version: String) -> String {
        return String(format: NSLocalizedString("settingsviews_appBannerVersion", tableName: filename, bundle: Bundle.main, value: "Version %@", comment: "settings banner, app version label"), version)
    }

    // MARK: - Online Help
    
    static let showOnlineHelp: String = {
        return NSLocalizedString("settingsviews_showOnlineHelp", tableName: filename, bundle: Bundle.main, value: "Open Online Help", comment: "help settings, open the online help")
    }()
    
    static let translateOnlineHelp: String = {
        return NSLocalizedString("settingsviews_translateOnlineHelp", tableName: filename, bundle: Bundle.main, value: "Translate Documentation", comment: "help settings, should the online documentation be translated automatically if needed")
    }()
    
    // MARK: - Notifications
        
    static let labelLiveActivityType: String = {
        return NSLocalizedString("settingsviews_labelLiveActivityType", tableName: filename, bundle: Bundle.main, value: "Live Activities", comment: "notification settings, type of live activities that should be enabled")
    }()
    
    static let liveActivityTypeDisabled: String = {
        return NSLocalizedString("settingsviews_liveActivityTypeDisabled", tableName: filename, bundle: Bundle.main, value: "Disabled", comment: "notification settings, disable live activities")
    }()
    
    static let liveActivityDisabledInFollowerMode: String = {
        return NSLocalizedString("settingsviews_liveActivityDisabledInFollowerMode", tableName: filename, bundle: Bundle.main, value: "Disabled in follower mode", comment: "notification settings, live activities are not available in follower mode")
    }()
    
    static let liveActivityDisabledInFollowerModeMessage: String = {
        return NSLocalizedString("settingsviews_liveActivityDisabledInFollowerModeMessage", tableName: filename, bundle: Bundle.main, value: "Live Activities are disabled in Follower Mode unless an external heartbeat is used for background keep-alive.", comment: "notification settings, live activities are not available in follower mode")
    }()
    
    static let liveActivityTypeMinimal: String = {
        return NSLocalizedString("settingsviews_liveActivityTypeMinimal", tableName: filename, bundle: Bundle.main, value: "Minimal", comment: "notification settings, live activity size minimal")
    }()
    
    static let liveActivityTypeNormal: String = {
        return NSLocalizedString("settingsviews_liveActivityTypeNormal", tableName: filename, bundle: Bundle.main, value: "Normal", comment: "notification settings, live activity size normal")
    }()
    
    static let liveActivityTypeLarge: String = {
        return NSLocalizedString("settingsviews_liveActivityTypeLarge", tableName: filename, bundle: Bundle.main, value: "Large", comment: "notification settings, live activity size large")
    }()
    
    
    // MARK: - Section Data Source

    static let sectionTitleDataSource: String = {
        return NSLocalizedString("settingsviews_sectionTitleDataSource", tableName: filename, bundle: Bundle.main, value: "Data Source", comment: "data source settings, section title")
    }()
    
    static let labelMasterOrFollower: String = {
        return NSLocalizedString("settingsviews_masterorfollower", tableName: filename, bundle: Bundle.main, value: "Use as Master or Follower", comment: "data source settings, master or follower")
    }()
    
    static let warningChangeFromMasterToFollower: String = {
        return NSLocalizedString("warningChangeFromMasterToFollower", tableName: filename, bundle: Bundle.main, value: "Switching from Master to Follower will stop your current sensor. Do you want to continue?", comment: "general settings, when switching from master to follower, if confirmation is asked, this message will be shown.")
    }()
    
    static let warningChangeFromMasterToFollowerDexcomShare: String = {
        return NSLocalizedString("warningChangeFromMasterToFollowerDexcomShare", tableName: filename, bundle: Bundle.main, value: "Switch from Master to Dexcom Share Follower will stop your current sensor and will also disable 'Upload to Dexcom Share'. Do you want to continue?", comment: "general settings, when switching from master to follower if upload to dexcom share is enabled, if confirmation is asked, this message will be shown.")
    }()
    
    static let warningChangeToFollowerDexcomShare: String = {
        return NSLocalizedString("warningChangeToFollowerDexcomShare", tableName: filename, bundle: Bundle.main, value: "Switching to Dexcom Share Follower mode will disable 'Upload to Dexcom Share'.", comment: "general settings, if he user selects dexcom share follower and upload to dexcom share is enabled, we will disable the upload function")
    }()
    
    static let labelFollowerDataSourceType: String = {
        return NSLocalizedString("settingsviews_labelFollowerDataSourceType", tableName: filename, bundle: Bundle.main, value: "Data Source", comment: "data source settings, data source")
    }()
    
    static let labelUploadDataToNightscout: String = {
        return NSLocalizedString("settingsviews_labelUploadDataToNightscout", tableName: filename, bundle: Bundle.main, value: "Upload to Nightscout", comment: "data source settings, enable Nightscout upload")
    }()
    
    static let labelfollowerKeepAliveType: String = {
        return NSLocalizedString("settingsviews_labelfollowerKeepAliveType", tableName: filename, bundle: Bundle.main, value: "Background Keep-alive", comment: "data source settings, enable background keep alive")
    }()
    
    static let followerKeepAliveTypeDisabled: String = {
        return NSLocalizedString("settingsviews_followerKeepAliveTypeDisabled", tableName: filename, bundle: Bundle.main, value: "Disabled", comment: "data source settings, keep-alive mode is set to disabled")
    }()
    
    static let followerKeepAliveTypeNormal: String = {
        return NSLocalizedString("settingsviews_followerKeepAliveTypeNormal", tableName: filename, bundle: Bundle.main, value: "Normal", comment: "data source settings, keep-alive mode is set to normal")
    }()
    
    static let followerKeepAliveTypeAggressive: String = {
        return NSLocalizedString("settingsviews_followerKeepAliveTypeAggressive", tableName: filename, bundle: Bundle.main, value: "Aggressive", comment: "data source settings, keep-alive mode is set to aggressive")
    }()
    
    static let followerKeepAliveTypeHeartbeat: String = {
        return NSLocalizedString("settingsviews_followerKeepAliveTypeHeartbeat", tableName: filename, bundle: Bundle.main, value: "Heartbeat", comment: "data source settings, keep-alive mode is set to use an external heartbeat")
    }()
    
    static let followerKeepAliveTypeDisabledMessage: String = {
        return NSLocalizedString("settingsviews_followerKeepAliveTypeDisabledMessage", tableName: filename, bundle: Bundle.main, value: "Background keep-alive is disabled.\n\nWhen the app is not on screen, no alarms, app badges, notifications or BG updates will take place.\n\nThe app will remain sleeping until you open it again.\n\nThis mode has very little impact on the battery of your device.", comment: "data source settings, keep-alive mode is set to disabled")
    }()
    
    static let followerKeepAliveTypeNormalMessage: String = {
        return NSLocalizedString("settingsviews_followerKeepAliveTypeNormalMessage", tableName: filename, bundle: Bundle.main, value: "Background keep-alive is set to normal operation.\n\nWhen the app is not on screen, we will attempt to keep it running for you in the background so that BG updates are received and alarms can be triggered.\n\nThis mode has a noticeable impact on the battery of your device.", comment: "data source settings, keep-alive mode is set to normal")
    }()
    
    static let followerKeepAliveTypeAggressiveMessage: String = {
        return NSLocalizedString("settingsviews_followerKeepAliveTypeAggressiveMessage", tableName: filename, bundle: Bundle.main, value: "Background keep-alive is set to aggressive.\n\nWhen the app is not on screen, we will aggressively attempt to keep it running for you in the background so that BG updates are received and alarms can be triggered.\n\nThis mode has a very noticeable impact on the battery of your device and should only be used if absolutely necessary.", comment: "data source settings, keep-alive mode is set to aggressive")
    }()
    
    static let followerKeepAliveTypeHeartbeatMessage: String = {
        return NSLocalizedString("settingsviews_followerKeepAliveTypeHeartbeatMessage", tableName: filename, bundle: Bundle.main, value: "Background keep-alive is set to use an external heartbeat.\n\nWhen the app is not on screen, the external heartbeat will wake it up in the background so that BG updates are received and alarms can be triggered.\n\nMake sure you add a valid heartbeat device in the Bluetooth screen.\n\nThis mode has very little impact on the battery of your device but will only work if a valid heartbeat is running.", comment: "data source settings, keep-alive mode is set to use an external heartbeat")
    }()
    
    static let followerPatientName: String = {
        return NSLocalizedString("settingsviews_followerPatientName", tableName: filename, bundle: Bundle.main, value: "Patient Name", comment: "data source settings, the name of the person we are following")
    }()
    
    static let followerPatientNameMessage: String = {
        return NSLocalizedString("settingsviews_followerPatientNameMessage", tableName: filename, bundle: Bundle.main, value: "Here you can optionally write the name of the person you are following.", comment: "data source settings, ask the user to enter the name of the person we are following if they want to")
    }()
    
    static let followerServiceStatus: String = {
        return NSLocalizedString("settingsviews_followerServiceStatus", tableName: filename, bundle: Bundle.main, value: "Status", comment: "data source settings, the status of the web follower service")
    }()
    
    static let nightscoutNotEnabled: String = {
        return NSLocalizedString("settingsviews_nightscoutNotEnabled", tableName: filename, bundle: Bundle.main, value: "Nightscout is disabled\n\nTo upload BG values to Nightscout, you must enable it in the Nightscout section.", comment: "data source settings, enable Nightscout in the Nightscout section")
    }()
    
    static let nightscoutNotEnabledRowText: String = {
        return NSLocalizedString("settingsviews_nightscoutNotEnabledRowText", tableName: filename, bundle: Bundle.main, value: "Disabled", comment: "data source settings, show that Nightscout is disabled")
    }()
    
    static let labelFollowerDataSourceRegion: String = {
        return NSLocalizedString("settingsviews_labelFollowerDataSourceRegion", tableName: filename, bundle: Bundle.main, value: "Region", comment: "data source settings, data source server or account region")
    }()
    
    // this is a default text for the settings row and should never really be used as we'll
    // hide the row anyway if we can't get the serial number to see if it's a Libre 2 or Libre 3
    static let labelFollowerIs15DaySensor: String = {
        return NSLocalizedString("settingsviews_labelFollowerIs15DaySensor", tableName: filename, bundle: Bundle.main, value: "Is a Libre Plus?", comment: "data source settings, should the app consider this sensor as a 15 day Plus version")
    }()
    
    static let enterUsername = {
        return NSLocalizedString("settingsviews_enterUsername", tableName: filename, bundle: Bundle.main, value: "Enter your username", comment: "follower settings, pop up that asks user to enter their username")
    }()
    
    static let enterPassword = {
        return NSLocalizedString("settingsviews_enterPassword", tableName: filename, bundle: Bundle.main, value: "Enter your password", comment: "follower settings, pop up that asks user to enter their password")
    }()
    
    static let libreLinkUpReAcceptNeeded = {
        return NSLocalizedString("settingsviews_libreLinkUpReAcceptNeeded", tableName: filename, bundle: Bundle.main, value: "Need to accept terms", comment: "libre link up follower settings, pop up that asks user to enter their region")
    }()
    
    static let libreLinkUpNoActiveSensor = {
        return NSLocalizedString("settingsviews_libreLinkUpNoActiveSensor", tableName: filename, bundle: Bundle.main, value: "No active sensor data", comment: "libre link up follower settings, no active sensor")
    }()
    
    static let medtrumSelectedPatient = {
        return NSLocalizedString("settingsviews_medtrumSelectedPatient", tableName: filename, bundle: Bundle.main, value: "Selected Patient", comment: "medtrum follower settings, select a patient from the list")
    }()
    
    static let medtrumSelectPatient = {
        return NSLocalizedString("settingsviews_medtrumSelectPatient", tableName: filename, bundle: Bundle.main, value: "Select Patient", comment: "medtrum follower settings, select a patient")
    }()
    
    static let medtrumSelectPatientFromList = {
        return NSLocalizedString("settingsviews_medtrumSelectPatientFromList", tableName: filename, bundle: Bundle.main, value: "Select Patient From List", comment: "medtrum follower settings, choose a patient from the list")
    }()
    
    // MARK: - Section Notifications
    
    static let sectionTitleNotifications: String = {
        return NSLocalizedString("settingsviews_sectiontitleNotifications", tableName: filename, bundle: Bundle.main, value: "Notifications", comment: "general settings, section title")
    }()

    static let labelSelectBgUnit:String = {
        return NSLocalizedString("settingsviews_selectbgunit", tableName: filename, bundle: Bundle.main, value: "Blood Glucose Units:", comment: "for text in pop up where user can select bg unit")
    }()
    
    static let master: String = {
        return NSLocalizedString("settingsviews_master", tableName: filename, bundle: Bundle.main, value: "Master", comment: "general settings, literally master")
    }()
    
    static let follower: String = {
        return NSLocalizedString("settingsviews_follower", tableName: filename, bundle: Bundle.main, value: "Follower", comment: "general settings, literally follower")
    }()
    
    static let showReadingInNotification: String = {
        return NSLocalizedString("settingsviews_showReadingInNotification", tableName: filename, bundle: Bundle.main, value: "Glucose Notifications", comment: "general settings, should reading be shown in notification yes or no")
    }()
    
    static let labelShowReadingInAppBadge: String = {
        return NSLocalizedString("settingsviews_labelShowReadingInAppBadge", tableName: filename, bundle: Bundle.main, value: "App Badge", comment: "general settings, should reading be shown in app badge yes or no")
    }()
    
    static let multipleAppBadgeValueWith10: String = {
        return NSLocalizedString("settingsviews_multipleAppBadgeValueWith10", tableName: filename, bundle: Bundle.main, value: "App Badge x10", comment: "general settings, should reading be multiplied with 10 yes or no")
    }()
    
    static let settingsviews_IntervalTitle = {
        return NSLocalizedString("settingsviews_IntervalTitle", tableName: filename, bundle: Bundle.main, value: "Notification Interval", comment: "When clicking the notification interval setting, a pop up asks for minimum number of minutes between two readings, this is the pop up message - this is used for setting the interval between two readings in BG notifications, Speak readings, Apple Watch")
    }()
    
    static let settingsviews_IntervalMessage = {
        return NSLocalizedString("settingsviews_IntervalMessage", tableName: filename, bundle: Bundle.main, value: "Minimum interval between two notifications", comment: "When clicking the interval setting, a pop up asks for minimum number of minutes between two notifications, this is the pop up message - this is used for setting the interval between two readings in BG notifications, Speak readings, Apple Watch")
    }()
    
    // MARK: - Section Home Screen
    
    static let sectionTitleHomeScreen: String = {
        return NSLocalizedString("settingsviews_sectiontitlehomescreen", tableName: filename, bundle: Bundle.main, value: "Home Screen", comment: "home screen settings, section title")
    }()

    static let homeScreenChartDisplaySectionTitle: String = {
        return NSLocalizedString("settingsviews_homeScreenChartDisplaySectionTitle", tableName: filename, bundle: Bundle.main, value: "Chart Display", comment: "home screen settings, section title for main chart display options")
    }()

    static let homeScreenMainChartSectionFooter: String = {
        return NSLocalizedString("settingsviews_homeScreenMainChartSectionFooter", tableName: filename, bundle: Bundle.main, value: "These options control how glucose data is displayed on the main chart.", comment: "home screen settings, footer explaining main chart display options")
    }()

    static let homeScreenSensorLifetimeSectionTitle: String = {
        return NSLocalizedString("settingsviews_homeScreenSensorLifetimeSectionTitle", tableName: filename, bundle: Bundle.main, value: "Sensor Lifetime", comment: "home screen settings, section title for sensor lifetime display options")
    }()

    static let homeScreenSensorLifetimeSectionFooter: String = {
        return NSLocalizedString("settingsviews_homeScreenSensorLifetimeSectionFooter", tableName: filename, bundle: Bundle.main, value: "Controls whether sensor lifetime is shown as elapsed time or as a countdown on iPhone and Apple Watch.", comment: "home screen settings, footer explaining the sensor lifetime display preference")
    }()

    static let homeScreenScreenLockSectionTitle: String = {
        return NSLocalizedString("settingsviews_homeScreenScreenLockSectionTitle", tableName: filename, bundle: Bundle.main, value: "Screen Lock", comment: "home screen settings, section title for screen lock options")
    }()

    static let homeScreenScreenLockSectionFooter: String = {
        return NSLocalizedString("settingsviews_homeScreenScreenLockSectionFooter", tableName: filename, bundle: Bundle.main, value: "These options control how the Home screen behaves when the app is left open or locked.", comment: "home screen settings, footer explaining screen lock and rotation options")
    }()
    
    static let showClockWhenScreenIsLocked: String = {
        return NSLocalizedString("settingsviews_showClockWhenScreenIsLocked", tableName: filename, bundle: Bundle.main, value: "Lock Screen Clock", comment: "home screen settings, should the clock also be displayed when the screen is locked")
    }()
    
    static let screenLockDimmingTypeWhenScreenIsLocked: String = {
        return NSLocalizedString("settingsviews_screenLockDimmingTypeWhenScreenIsLocked", tableName: filename, bundle: Bundle.main, value: "Lock Screen Dimming", comment: "home screen settings, should the screen be dimmed when the screen is locked")
    }()
    
    static let screenLockDimmingTypeDisabled: String = {
        return NSLocalizedString("settingsviews_screenLockDimmingTypeDisabled", tableName: filename, bundle: Bundle.main, value: "Disabled", comment: "screen dimming is disabled")
    }()
    
    static let screenLockDimmingTypeDimmed: String = {
        return NSLocalizedString("settingsviews_screenLockDimmingTypeDimmed", tableName: filename, bundle: Bundle.main, value: "Dimmed", comment: "screen dimming is dimmed")
    }()
    
    static let screenLockDimmingTypeDark: String = {
        return NSLocalizedString("settingsviews_screenLockDimmingTypeDark", tableName: filename, bundle: Bundle.main, value: "Dark", comment: "screen dimming is dark")
    }()
    
    static let screenLockDimmingTypeVeryDark: String = {
        return NSLocalizedString("settingsviews_screenLockDimmingTypeVeryDark", tableName: filename, bundle: Bundle.main, value: "Very Dark", comment: "screen dimming is very dark")
    }()
    
    static let allowScreenRotation: String = {
        return NSLocalizedString("settingsviews_allowScreenRotation", tableName: filename, bundle: Bundle.main, value: "Chart Rotation", comment: "home screen settings, should the main glucose chart screen be allowed")
    }()
    
    static let showMiniChart: String = {
        return NSLocalizedString("settingsviews_showMiniChart", tableName: filename, bundle: Bundle.main, value: "Show Mini-Chart", comment: "home screen settings, should the mini-chart be shown")
    }()
    
    static let allowMainChartAutoReset: String = {
        return NSLocalizedString("settingsviews_allowMainChartAutoReset", tableName: filename, bundle: Bundle.main, value: "Auto Reset Chart", comment: "home screen settings, should the main chart automatically reset the y-axis and date to current values every 15 seconds")
    }()
    
    static let showOriginalBGReadings: String = {
        return NSLocalizedString("settingsviews_showOriginalBGReadings", tableName: filename, bundle: Bundle.main, value: "Original Values", comment: "home screen settings, should the original glucose values be shown on the main chart when post processing is enabled")
    }()

    static let showSensorNoiseOnChart: String = {
        return NSLocalizedString("settingsviews_showSensorNoiseOnChart", tableName: filename, bundle: Bundle.main, value: "Show Sensor Noise", comment: "home screen settings, should short-term sensor noise be shown as background bands on the main chart")
    }()

    static let labelUrgentHighValue: String = {
        return NSLocalizedString("settingsviews_urgentHighValue", tableName: filename, bundle: Bundle.main, value: "Urgent High Value", comment: "home screen settings, urgent high value")
    }()

    static let urgentHighValueMessage: String = {
        return NSLocalizedString("settingsviews_urgentHighValueMessage", tableName: filename, bundle: Bundle.main, value: "Enter the glucose value for the urgent high threshold.", comment: "home screen settings, ask the user to enter the urgent high glucose value")
    }()
    
    static let labelHighValue: String = {
        return NSLocalizedString("settingsviews_highValue", tableName: filename, bundle: Bundle.main, value: "High Value", comment: "home screen settings, high value")
    }()

    static let highValueMessage: String = {
        return NSLocalizedString("settingsviews_highValueMessage", tableName: filename, bundle: Bundle.main, value: "Enter the glucose value for the high threshold.", comment: "home screen settings, ask the user to enter the high glucose value")
    }()
    
    static let labelTargetValue: String = {
        return NSLocalizedString("settingsviews_targetValue", tableName: filename, bundle: Bundle.main, value: "Target Value", comment: "home screen settings, target value")
    }()
    
    static let targetValueMessage: String = {
        return NSLocalizedString("settingsviews_targetValueMessage", tableName: filename, bundle: Bundle.main, value: "Set to 0 to disable the target", comment: "home screen settings, target value can be disabled by making this value zero")
    }()
    
    static let labelLowValue: String = {
        return NSLocalizedString("settingsviews_lowValue", tableName: filename, bundle: Bundle.main, value: "Low Value", comment: "home screen settings, low value")
    }()

    static let lowValueMessage: String = {
        return NSLocalizedString("settingsviews_lowValueMessage", tableName: filename, bundle: Bundle.main, value: "Enter the glucose value for the low threshold.", comment: "home screen settings, ask the user to enter the low glucose value")
    }()
    
    static let labelUrgentLowValue: String = {
        return NSLocalizedString("settingsviews_urgentLowValue", tableName: filename, bundle: Bundle.main, value: "Urgent Low Value", comment: "home screen settings, urgent low value")
    }()

    static let urgentLowValueMessage: String = {
        return NSLocalizedString("settingsviews_urgentLowValueMessage", tableName: filename, bundle: Bundle.main, value: "Enter the glucose value for the urgent low threshold.", comment: "home screen settings, ask the user to enter the urgent low glucose value")
    }()
    
    static let labelShowTarget: String = {
        return NSLocalizedString("settingsviews_showtarget", tableName: filename, bundle: Bundle.main, value: "Target Line", comment: "home screen settings, show target line")
    }()
    
    // MARK: - Section Treatments
    
    static let sectionTitleTreatments: String = {
        return NSLocalizedString("settingsviews_sectiontitletreatments", tableName: filename, bundle: Bundle.main, value: "Treatments", comment: "treatments settings, section title")
    }()

    static let settingsviews_showTreatments: String = {
        return NSLocalizedString("settingsviews_showTreatments", tableName: filename, bundle: Bundle.main, value: "Show Treatments", comment: "treatments settings, show the treatments on main chart")
    }()
    
    static let settingsviews_smallBolusTreatmentThreshold = {
        return NSLocalizedString("settingsviews_smallBolusTreatmentThreshold", tableName: filename, bundle: Bundle.main, value: "Micro-bolus Threshold:", comment: "When clicking the threshold setting, a pop up asks for the number of units under which a bolus should be considered a micro-bolus")
    }()
    
    static let settingsviews_smallBolusTreatmentThresholdMessage = {
        return NSLocalizedString("settingsviews_smallBolusTreatmentThresholdMessage", tableName: filename, bundle: Bundle.main, value: "Below how many units should we consider a bolus as a micro-bolus?\n\n(Recommended value: 1.0U)", comment: "When clicking the threshold setting, a pop up asks for the number of units under which a bolus should be considered a micro-bolus")
    }()
    
    // MARK: - Section Statistics
    
    static let sectionTitleStatistics: String = {
        return NSLocalizedString("settingsviews_sectiontitlestatistics", tableName: filename, bundle: Bundle.main, value: "Statistics", comment: "statistics settings, section title")
    }()

    static let labelShowStatistics: String = {
        return NSLocalizedString("settingsviews_showStatistics", tableName: filename, bundle: Bundle.main, value: "Show Statistics", comment: "statistics settings, show statistics on home screen")
    }()

    static let labelDaysToUseStatisticsTitle: String = {
        return NSLocalizedString("settingsviews_daysToUseStatisticsTitle", tableName: filename, bundle: Bundle.main, value: "Days to Calculate", comment: "statistics settings, how many days to use for calculations")
    }()
    
    static let labelDaysToUseStatisticsMessage: String = {
        return NSLocalizedString("settingsviews_daysToUseStatisticsMessage", tableName: filename, bundle: Bundle.main, value: "How many days should we use to calculate the statistics? (Enter 0 to calculate today since midnight)", comment: "statistics settings, how many days to use for calculations")
    }()
    
    static let labelTimeInRangeType: String = {
        return NSLocalizedString("settingsviews_labelTimeInRangeType", tableName: filename, bundle: Bundle.main, value: "Time In Range", comment: "statistics settings, the type of time in range selected")
    }()
    
    static let timeInRangeTypeStandardRange: String = {
        return NSLocalizedString("settingsviews_timeInRangeTypeStandardRange", tableName: filename, bundle: Bundle.main, value: "Standard Range", comment: "statistics settings, prefer standard time in range")
    }()
    
    static let timeInRangeTypeTightRange: String = {
        return NSLocalizedString("settingsviews_timeInRangeTypeTightRange", tableName: filename, bundle: Bundle.main, value: "Tight Range", comment: "statistics settings, prefer time in tight range")
    }()
    
    static let timeInRangeTypeUserDefinedRange: String = {
        return NSLocalizedString("settingsviews_timeInRangeTypeUserDefinedRange", tableName: filename, bundle: Bundle.main, value: "User Range", comment: "statistics settings, prefer user-defined range")
    }()
    
    static let labelUseIFFCA1C: String = {
        return NSLocalizedString("settingsviews_useIFCCA1C", tableName: filename, bundle: Bundle.main, value: "HbA1c in mmols/mol", comment: "statistics settings, use IFCC method for HbA1c")
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
    
    static let labelBluetoothDeviceName:String = {
        return NSLocalizedString("settingsviews_bluetoothDeviceName", tableName: filename, bundle: Bundle.main, value: "Device Name", comment: "transmitter settings, just the words that explain that the settings is about the bluetooth device name")
    }()
    
    static let heartbeatLibreMessage:String = {
        return NSLocalizedString("settingsviews_heartbeatLibreMessage", tableName: filename, bundle: Bundle.main, value: "IMPORTANT: You MUST force-close the master app (LibreLink, Medtrum, etc.) first before adding the heartbeat.\n\nEnter the device name shown in the iPhone Settings -> Bluetooth devices list.\n\nOnce you have connected, you can reopen the master app if needed.", comment: "transmitter settings, instructions for adding a generic or Libre heartbeat")
    }()
    
    static let heartbeatG7Message:String = {
        return NSLocalizedString("settingsviews_heartbeatG7Message", tableName: filename, bundle: Bundle.main, value: "Enter the Dexcom G7/ONE+/Stelo bluetooth name shown in the iPhone Settings -> Bluetooth devices list.", comment: "transmitter settings, instructions for adding a G7 type heartbeat")
    }()
    
    static let dexcomG7Message:String = {
        return NSLocalizedString("settingsviews_dexcomG7Message", tableName: filename, bundle: Bundle.main, value: "Press OK to automatically try to find your sensor.\n\nIf you have trouble connecting then you can manually enter the bluetooth name shown in the iPhone Settings -> Bluetooth devices list.", comment: "transmitter settings, instructions for adding a G7 type transmitter")
    }()
    
    static let labelTransmitterIdTextForButton:String = {
        return NSLocalizedString("settingsviews_transmitterid_text_for_button", tableName: filename, bundle: Bundle.main, value: "Transmitter ID", comment: "transmitter settings, this is for the button, when clicked then user will be requested to give transmitter id. The only difference with settingsviews_transmitterid is that ':' is not added")
    }()
    
    static let labelGiveTransmitterId:String = {
        return NSLocalizedString("settingsviews_givetransmitterid", tableName: filename, bundle: Bundle.main, value: "Enter Transmitter ID", comment: "transmitter settings, pop up that asks user to inter transmitter id")
    }()
    
    static let labelResetTransmitter: String = {
        return NSLocalizedString("settingsviews_resettransmitter", tableName: filename, bundle: Bundle.main, value: "Anubis Transmitter", comment: "transmitter settings, to explain that settings is about special functions for anubis transmitters")
    }()
    
    static let resetDexcomTransmitterMessage: String = {
        return NSLocalizedString("settingsviews_resetDexcomTransmitterMessage", tableName: filename, bundle: Bundle.main, value: "This option will attempt to reset your Anubis transmitter on the next connection.", comment: "transmitter settings, to explain that the reset option only works for certain transmitters")
    }()
    
    static let labelWebOOPTransmitter:String = {
        return NSLocalizedString("settingsviews_webooptransmitter", tableName: filename, bundle: Bundle.main, value: "Transmitter Algorithm", comment: "web oop settings in bluetooth peripheral view : enabled or not")
    }()
    
    static let labelWebOOP:String = {
        return NSLocalizedString("settingsviews_labelWebOOP", tableName: filename, bundle: Bundle.main, value: "xDrip or Transmitter Algorithm", comment: "weboop settings, title of the dialogs where user can select between xdrip or transmitter algorithm")
    }()
    
    static let labelNonFixedTransmitter:String = {
        return NSLocalizedString("settingsviews_nonfixedtransmitter", tableName: filename, bundle: Bundle.main, value: "Multi-point Calibration", comment: "non fixed calibration slopes settings in bluetooth peripheral view : enabled or not")
    }()
    
    static let labelNonFixed:String = {
        return NSLocalizedString("settingsviews_labelNonFixed", tableName: filename, bundle: Bundle.main, value: "Multi-point Calibration", comment: "non fixed settings, title of the section")
    }()
    
    static let labelAlgorithmType:String = {
        return NSLocalizedString("settingsviews_labelAlgorithmType", tableName: filename, bundle: Bundle.main, value: "Algorithm Type", comment: "weboop settings, title of the dialogs where user can select between xdrip or transmitter algorithm")
    }()
    
    static let labelCalibrationTitle:String = {
        return NSLocalizedString("settingsviews_labelCalibrationTitle", tableName: filename, bundle: Bundle.main, value: "Sensor Calibration", comment: "non fixed settings, title of the section")
    }()
    
    static let labelCalibrationType:String = {
        return NSLocalizedString("settingsviews_labelCalibrationType", tableName: filename, bundle: Bundle.main, value: "Calibration Type", comment: "non fixed settings, title of the section")
    }()
    
    // MARK: - Section Alerts
    
    static let sectionTitleAlerting: String = {
        return NSLocalizedString("settingsviews_sectiontitlealerting", tableName: filename, bundle: Bundle.main, value: "Alarms", comment: "alerting settings, section title")
    }()
    
    static let labelAlertTypes: String = {
        return NSLocalizedString("settingsviews_row_alert_types", tableName: filename, bundle: Bundle.main, value: "Alarm Types", comment: "alerting settings, row alert types")
    }()
    
    static let labelAlerts: String = {
        return NSLocalizedString("settingsviews_row_alerts", tableName: filename, bundle: Bundle.main, value: "Alarms", comment: "alerting settings, row alerts")
    }()

    static let volumeTestsSectionTitle: String = {
        return NSLocalizedString("settingsviews_volume_tests_section_title", tableName: filename, bundle: Bundle.main, value: "Test Alarm Volume", comment: "alerting settings, section title for volume test rows")
    }()

    static let alertTypesSectionFooter: String = {
        return NSLocalizedString("settingsviews_alert_types_section_footer", tableName: filename, bundle: Bundle.main, value: "Alarm Types define how alarms behave, including sound, vibration, snooze and mute override settings.", comment: "alerting settings, footer explaining alarm types")
    }()

    static let alertsSectionFooter: String = {
        return NSLocalizedString("settingsviews_alerts_section_footer", tableName: filename, bundle: Bundle.main, value: "Alarms define when the app should notify you for glucose levels, missed readings and other conditions.", comment: "alerting settings, footer explaining alarms")
    }()
    
    // MARK: - Section Healthkit
    
    static let sectionTitleHealthKit: String = {
        return NSLocalizedString("settingsviews_sectiontitlehealthkit", tableName: filename, bundle: Bundle.main, value: "Apple Health", comment: "healthkit settings, section title")
    }()
    
    static let labelHealthKit: String = {
        return NSLocalizedString("settingsviews_healthkit", tableName: filename, bundle: Bundle.main, value: "Write to Apple Health", comment: "healthkit settings, literally 'healthkit'")
    }()
    
    // MARK: - Section Dexcom Share (including Share Follower)
    
    static let sectionTitleDexcomShareUpload: String = {
        return NSLocalizedString("settingsviews_sectiontitledexcomshareupload", tableName: filename, bundle: Bundle.main, value: "Dexcom Share", comment: "dexcom share upload settings, section title")
    }()
    
    static let labelUploadReadingstoDexcomShare = {
        return NSLocalizedString("settingsviews_uploadReadingstoDexcomShare", tableName: filename, bundle: Bundle.main, value: "Upload", comment: "dexcom share settings, where user can select if readings should be uploaded to dexcom share yes or no")
    }()
    
    static let labelUploadReadingstoDexcomShareDisabledMessage = {
        return NSLocalizedString("settingsviews_uploadReadingstoDexcomShareDisabledMessage", tableName: filename, bundle: Bundle.main, value: "Upload to Dexcom Share is disabled when using Dexcom Share Follower Mode", comment: "dexcom share settings, tell the user that upload to dexcom share is disabled when using dexcom share follower mode")
    }()

    static let labeldexcomShareUploadSerialNumber = {
        return NSLocalizedString("settingsviews_dexcomShareUploadSerialNumber", tableName: filename, bundle: Bundle.main, value: "Receiver Serial Number:", comment: "dexcom share settings settings, where user can set dexcom serial number to be used for dexcom share upload")
    }()
    
    static let labelUseUSDexcomShareurl = {
        return NSLocalizedString("settingsviews_useUSDexcomShareurl", tableName: filename, bundle: Bundle.main, value: "US Servers", comment: "dexcom share settings, where user can choose to use US url or not")
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
    
    static let givedexcomShareUploadSerialNumber = {
        return NSLocalizedString("settingsviews_givedexcomShareUploadSerialNumber", tableName: filename, bundle: Bundle.main, value: "Enter the Dexcom Receiver Serial Number", comment: "dexcom share settings, pop up that asks user to enter dexcom share serial number")
    }()
    
    // MARK: - Section Nightscout
    
    static let sectionTitleNightscout: String = {
        return NSLocalizedString("settingsviews_sectiontitlenightscout", tableName: filename, bundle: Bundle.main, value: "Nightscout", comment: "nightscout settings, section title")
    }()

    static let nightscoutUploadOptionsSectionTitle: String = {
        return NSLocalizedString("settingsviews_nightscoutUploadOptionsSectionTitle", tableName: filename, bundle: Bundle.main, value: "Upload Options", comment: "nightscout settings, section title for upload options")
    }()
    
    static let labelNightscoutEnabled = {
        return NSLocalizedString("settingsviews_nightscoutEnabled", tableName: filename, bundle: Bundle.main, value: "Enable Nightscout", comment: "nightscout settings, where user can enable or disable nightscout")
    }()

    static let labelNightscoutUrl = {
        return NSLocalizedString("settingsviews_nightscoutUrl", tableName: filename, bundle: Bundle.main, value: "URL:", comment: "nightscout settings, where user can set the nightscout url")
    }()
    
    static let labelNightscoutFollowType = {
        return NSLocalizedString("settingsviews_nightscoutFollowType", tableName: filename, bundle: Bundle.main, value: "AID Type", comment: "nightscout settings, select the type of follower to use")
    }()
    
    static let nightscoutFollowTypeNone = {
        return NSLocalizedString("nightscoutFollowTypeNone", tableName: filename, bundle: Bundle.main, value: "None", comment: "nightscout settings, no AID follower type")
    }()
    
    static let nightscoutFollowTypeNoneExpanded = {
        return NSLocalizedString("nightscoutFollowTypeNoneExpanded", tableName: filename, bundle: Bundle.main, value: "None (just treatments)", comment: "nightscout settings, basic follower type explanation")
    }()
    
    static let nightscoutFollowTypeLoop = {
        return NSLocalizedString("nightscoutFollowTypeLoop", tableName: filename, bundle: Bundle.main, value: "Loop", comment: "nightscout settings, loop follower type")
    }()
    
    static let nightscoutFollowTypeLoopExpanded = {
        return NSLocalizedString("nightscoutFollowTypeLoopExpanded", tableName: filename, bundle: Bundle.main, value: "Loop", comment: "nightscout settings, loop follower type explanation")
    }()
    
    static let nightscoutFollowTypeOpenAPS = {
        return NSLocalizedString("nightscoutFollowTypeOpenAPS", tableName: filename, bundle: Bundle.main, value: "OpenAPS-based", comment: "nightscout settings, openaps based follower type")
    }()
    
    static let nightscoutFollowTypeOpenAPSExpanded = {
        return NSLocalizedString("nightscoutFollowTypeOpenAPSExpanded", tableName: filename, bundle: Bundle.main, value: "OpenAPS/Trio/iAPS/AAPS", comment: "nightscout settings, openaps based follower type explanation")
    }()
    
    static let useSchedule = {
        return NSLocalizedString("settingsviews_useSchedule", tableName: filename, bundle: Bundle.main, value: "Use Upload Schedule", comment: "nightscout settings, where user can select to use schedule or not")
    }()
    
    static let schedule = {
        return NSLocalizedString("schedule", tableName: filename, bundle: Bundle.main, value: "Schedule:", comment: "nightscout or dexcom share settings, where user can select to edit the schedule")
    }()
    
    static let giveNightscoutUrl = {
        return NSLocalizedString("settingsviews_giveNightscoutUrl", tableName: filename, bundle: Bundle.main, value: "Enter your Nightscout URL", comment: "nightscout  settings, pop up that asks user to enter nightscout url")
    }()

    static let labelNightscoutAPIKey = {
        return NSLocalizedString("settingsviews_nightscoutAPIKey", tableName: filename, bundle: Bundle.main, value: "API_SECRET:", comment: "nightscout settings, where user can set the nightscout api key")
    }()
    
    static let giveNightscoutAPIKey = {
        return NSLocalizedString("settingsviews_giveNightscoutAPIKey", tableName: filename, bundle: Bundle.main, value: "Enter API_SECRET", comment: "nightscout settings, pop up that asks user to enter nightscout api key")
    }()
    
    static let editScheduleTimePickerSubtitle: String = {
        return NSLocalizedString("editScheduleTimePickerSubtitle", tableName: filename, bundle: Bundle.main, value: "Change: ", comment: "used for editing schedule for Nightscout upload and Dexcom Share upload")
    }()
    
    static let timeScheduleViewTitle: String = {
        return NSLocalizedString("timeScheduleViewTitle", tableName: filename, bundle: Bundle.main, value: "On/Off Time Schedule", comment: "When creating schedule for Nightscout or Dexcom Share upload, this is the top label text")
    }()
    
    static let uploadSensorStartTime: String = {
        return NSLocalizedString("uploadSensorStartTime", tableName: filename, bundle: Bundle.main, value: "Upload Sensor Start Time", comment: "nightscout settings, title of row")
    }()
    
    static let testUrlAndAPIKey: String = {
        return NSLocalizedString("testUrlAndAPIKey", tableName: filename, bundle: Bundle.main, value: "Test Connection", comment: "nightscout settings, when clicking the cell, test the url and api key")
    }()

    static let nightscoutPort: String = {
        return NSLocalizedString("nightscoutPort", tableName: filename, bundle: Bundle.main, value: "Port:", comment: "nightscout settings, port to use")
    }()

    static let enterNightscoutPortNumber: String = {
        return NSLocalizedString("enterNightscoutPortNumber", tableName: filename, bundle: Bundle.main, value: "Enter Port Number", comment: "nightscout settings, row label when entering the port number")
    }()
    
    static let nightscoutToken: String = {
        return NSLocalizedString("nightscoutToken", tableName: filename, bundle: Bundle.main, value: "Token", comment: "nightscout settings, token to use")
    }()

    static let giveNightscoutToken: String = {
        return NSLocalizedString("giveNightscoutToken", tableName: filename, bundle: Bundle.main, value: "Enter Token", comment: "nightscout settings, pop up that asks user to enter token")
    }()
    
    static let openNightscout: String = {
        return NSLocalizedString("openNightscout", tableName: filename, bundle: Bundle.main, value: "Open Nightscout", comment: "nightscout settings, when clicking the cell, open the nightscout url")
    }()

    // MARK: - Section Speak
    
    static let sectionTitleSpeak: String = {
        return NSLocalizedString("settingsviews_speakBgReadings", tableName: filename, bundle: Bundle.main, value: "Speak Glucose", comment: "speak settings, where user can enable or disable speak readings")
    }()

    static let labelSpeakBgReadings = {
        return NSLocalizedString("settingsviews_speakBgReadings", tableName: filename, bundle: Bundle.main, value: "Speak Glucose", comment: "speak settings, where user can enable or disable speak readings")
    }()
    
    static let labelSpeakLanguage = {
        return NSLocalizedString("settingsviews_speakBgReadingslanguage", tableName: filename, bundle: Bundle.main, value: "Language:", comment: "speak settings, where user can select the language")
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
    
    static let settingsviews_SpeakIntervalTitle = {
        return NSLocalizedString("settingsviews_SpeakIntervalTitle", tableName: filename, bundle: Bundle.main, value: "Speak Interval", comment: "When clicking the speak interval setting, a pop up asks for minimum number of minutes between two speech events, this is the pop up message - this is used for setting the interval between two spoken bg announcements")
    }()
    
    static let settingsviews_SpeakIntervalMessage = {
        return NSLocalizedString("settingsviews_SpeakIntervalMessage", tableName: filename, bundle: Bundle.main, value: "Minimum interval between two voice announcements", comment: "When clicking the interval setting, a pop up asks for minimum number of minutes between two bg announcements, this is the pop up message - this is used for setting the interval between two readings in BG announcements, Speak readings, Apple Watch")
    }()
    
    
    // MARK: - Section About Info
    
    static let sectionTitleAbout: String = {
        return String(format: NSLocalizedString("settingsviews_sectiontitleAbout", tableName: filename, bundle: Bundle.main, value: "About %@", comment: "about settings, section title"), ConstantsHomeView.applicationName)
    }()
    
    static let version = {
        return NSLocalizedString("settingsviews_Version", tableName: filename, bundle: Bundle.main, value: "Version:", comment: "used in settings, section Info, title of the version setting")
    }()

    static let installedSince = {
        return NSLocalizedString("settingsviews_appInstalledSince", tableName: filename, bundle: Bundle.main, value: "Installed", comment: "used in settings, section Info, title of the app install date setting")
    }()

    static let license = {
        return NSLocalizedString("settingsviews_license", tableName: filename, bundle: Bundle.main, value: "License", comment: "used in settings, section Info, title of the license setting")
    }()
    
    static let showGitHub = {
        return NSLocalizedString("settingsviews_showGitHub", tableName: filename, bundle: Bundle.main, value: "GitHub", comment: "used in settings, section Info, open the GitHub page of the project")
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
    
    static let allowStandByHighContrast: String = {
        return NSLocalizedString("allowStandByHighContrast", tableName: filename, bundle: Bundle.main, value: "StandBy Night Mode", comment: "should we allow the StandBy mode to show a specific high contrast view at night")
    }()
    
    static let forceStandByBigNumbers: String = {
        return NSLocalizedString("forceStandByBigNumbers", tableName: filename, bundle: Bundle.main, value: "StandBy Big Numbers", comment: "should we force the StandBy mode to show big numbers only")
    }()
    
    // MARK: - Calendar Events
    
    static let calendarEventsSectionTitle: String = {
        return NSLocalizedString("calendarEventsSectionTitle", tableName: filename, bundle: Bundle.main, value: "Calendar Events", comment: "Calendar Events Settings - section title")
    }()
    
    static let createCalendarEvent: String = {
        return NSLocalizedString("createCalendarEvent", tableName: filename, bundle: Bundle.main, value: "Create Calendar Events", comment: "Calendar Events Settings - text in row where create event is enabled or disabled ")
    }()

    static let calenderId: String = {
        return NSLocalizedString("calenderId", tableName: filename, bundle: Bundle.main, value: "Calendar To Use", comment: "Calendar Events Settings - text in row where user needs to select a calendar")
    }()

    static let displayTrendInCalendarEvent: String = {
        return NSLocalizedString("settingsviews_displayTrendInCalendarEvent", tableName: filename, bundle: Bundle.main, value: "Trend", comment: "Calendar Events Settings - text in row where user needs to say if trend should be displayed or not")
    }()
    
    static let displayUnitInCalendarEvent: String = {
        return NSLocalizedString("displayUnitInCalendarEvent", tableName: filename, bundle: Bundle.main, value: "Unit", comment: "Calendar Events Settings - text in row where user needs to say if unit should be displayed or not")
    }()
    
    static let displayDeltaInCalendarEvent: String = {
        return NSLocalizedString("displayDeltaInCalendarEvent", tableName: filename, bundle: Bundle.main, value: "Delta", comment: "Calendar Events Settings - text in row where user needs to say if delta should be displayed or not")
    }()
    
    static let infoCalendarAccessDeniedByUser: String = {
        return String(format: NSLocalizedString("infoCalendarAccessDeniedByUser", tableName: filename, bundle: Bundle.main, value: "Full Access is required to your contacts.\n\nGo to iPhone Settings > Apps > %@ > Contacts and enable Full Access.", comment: "If user has earlier denied access to calendar, and then tries to activate creation of events in calendar, this message will be shown"), ConstantsHomeView.applicationName)
    }()
    
    static let infoCalendarAccessWriteOnly: String = {
        return String(format: NSLocalizedString("infoCalendarAccessWriteOnly", tableName: filename, bundle: Bundle.main, value: "You cannot use Calendar Events until you update the calendar access permission from 'Add Events Only' to 'Full Access'.\n\nGo to iPhone Settings > Apps > %@ > Calendars and select 'Full Access'.", comment: "The user needs to update their calendar permissions"), ConstantsHomeView.applicationName)
    }()
    
    static let infoCalendarAccessRestricted: String = {
        return String(format: NSLocalizedString("infoCalendarAccessRestricted", tableName: filename, bundle: Bundle.main, value: "You cannot give authorization to %@ to access your calendar. This is possibly due to active restrictions such as parental controls being in place.", comment: "If user is not allowed to give any app access to the Calendar, due to restrictions. And then tries to activate creation of events in calendar, this message will be shown"), ConstantsHomeView.applicationName)
    }()

    static let displayVisualIndicatorInCalendar: String = {
        return NSLocalizedString("settingsviews_displayVisualIndicatorInCalendarEvent", tableName: filename, bundle: Bundle.main, value: "Visual Indicator", comment: "Calendar Events Settings - text in row where user needs to say if the visual target indicator should be displayed or not")
    }()
    
    static let settingsviews_CalenderIntervalTitle = {
        return NSLocalizedString("settingsviews_CalenderIntervalTitle", tableName: filename, bundle: Bundle.main, value: "Event Interval:", comment: "When clicking the event interval setting, a pop up asks for minimum number of minutes between two events, this is the pop up message - this is used for setting the interval between two calendar events")
    }()
    
    static let settingsviews_CalenderIntervalMessage = {
        return NSLocalizedString("settingsviews_CalenderIntervalMessage", tableName: filename, bundle: Bundle.main, value: "Minimum interval between two calendar events", comment: "When clicking the interval setting, a pop up asks for minimum number of minutes between two calendar events, this is the pop up message - this is used for setting the interval between two calendar events, Speak readings, Apple Watch")
    }()
        
    // MARK: - Contact image
    
    static let infoContactsKeepAliveDisabled: String = {
        return String(format: NSLocalizedString("settingsviews_infoContactsKeepAliveDisabled", tableName: filename, bundle: Bundle.main, value: "You are using Follower mode with background keep-alive disabled.\n\nContact Image function cannot work without a background keep-alive.", comment: "If user is in follower mode with background keep-alive disabled, show this message when they tap the row"), ConstantsHomeView.applicationName)
    }()
    
    static let infoContactsAccessDeniedByUser: String = {
        return String(format: NSLocalizedString("infoContactsAccessDeniedByUser", tableName: filename, bundle: Bundle.main, value: "Full Access is required to your contacts.\n\nGo to iPhone Settings > Apps > %@ > Contacts and enable Full Access.", comment: "If user has earlier denied full access to contacts, and then tries to activate the contact image, this message will be shown"), ConstantsHomeView.applicationName)
    }()
    
    static let infoContactsAccessRestricted: String = {
        return String(format: NSLocalizedString("settingsviews_infoContactsAccessRestricted", tableName: filename, bundle: Bundle.main, value: "You cannot give authorization to %@ to access your contacts. This is possibly due to active restrictions such as parental controls being in place.", comment: "If user is not allowed to give any app access to the Contacts, due to restrictions. And then tries to activate the contact image, this message will be shown"), ConstantsHomeView.applicationName)
    }()
    
    static let infoContactsAccessLimited: String = {
        return String(format: NSLocalizedString("settingsviews_infoContactsAccessLimited", tableName: filename, bundle: Bundle.main, value: "Only limited access has been given to access your contacts.\n\nGo to iPhone Settings > Apps > %@ > Contacts and enable Full Access.", comment: "If user has only given limited access to the Contacts and then tries to activate the contact image, this message will be shown"), ConstantsHomeView.applicationName)
    }()
    
    static let contactImageSectionTitle: String = {
        return NSLocalizedString("settingsviews_contactImageSectionTitle", tableName: filename, bundle: Bundle.main, value: "Contact Image", comment: "Contact Image - section title")
    }()
    
    static let enableContactImage: String = {
        return NSLocalizedString("settingsviews_enableContactImage", tableName: filename, bundle: Bundle.main, value: "Contact Image", comment: "Contact Image Settings - text in row where contact image is enabled or disabled ")
    }()
    
    static let displayTrendInContactImage: String = {
        return NSLocalizedString("settingsviews_displayTrendInContactImage", tableName: filename, bundle: Bundle.main, value: "Show Trend", comment: "Contact Image Settings - text in row where user needs to say if trend should be displayed or not")
    }()
    
    static let useHighContrastContactImage: String = {
        return NSLocalizedString("settingsviews_useHighContrastContactImage", tableName: filename, bundle: Bundle.main, value: "High Contrast", comment: "Contact Image Settings - text in row where user needs to say if they prefer to use a high contrast contact image or not")
    }()
    
    static let contactImageCreatedByString: String = {
        return NSLocalizedString("settingsviews_contactImageCreatedByString", tableName: filename, bundle: Bundle.main, value: "Contact automatically created by", comment: "Add a note to the contact so that user knows it was the app that automatically created it")
    }()

    // MARK: - Issue Reporting
    
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
        return String(format: NSLocalizedString("describeProblem", tableName: filename, bundle: Bundle.main, value: "Explain why you need to send the trace file with as much detail as possible. If you have already reported your problem in the Facebook support group '%@', then mention your facebook name in the e-mail", comment: "Text in pop up shown when user wants to send the trace file"), ConstantsHomeView.applicationName)
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
        return NSLocalizedString("volumeTestSoundPlayer", tableName: filename, bundle: Bundle.main, value: "When Silent Mode is enabled", comment: "In Settings, Alerts section, row title for testing alarm volume when silent mode is enabled")
    }()
    
    static let volumeTestiOSSound: String = {
        return NSLocalizedString("volumeTestiOSSound", tableName: filename, bundle: Bundle.main, value: "When Silent Mode is disabled", comment: "In Settings, Alerts section, row title for testing alarm volume when silent mode is disabled")
    }()

    static let volumeTestiOSSoundExplanation: String = {
        return NSLocalizedString("volumeTestiOSSoundExplanation", tableName: filename, bundle: Bundle.main, value: "An alarm sound is now being played with the same volume that will be used for an Alarm Type with 'Override Mute' = Off\n\n(Also used always for Missed Reading alarms which use the iOS volume.)\n\nPress one of the volume buttons to stop the sound, then change the volume with the volume buttons to the desired volume and test again.", comment: "In Settings, Alerts section, there's an option to test the volume settings, this is text explaining the test when clicking the row - this is for ios sound volume test")
    }()
    
    // MARK: - Section Developer
    
    static let developerSettings: String = {
        return NSLocalizedString("developerSettings", tableName: filename, bundle: Bundle.main, value: "Advanced Settings", comment: "Advanced Settings, section title")
    }()
    
    static let suppressUnLockPayLoad: String = {
        return NSLocalizedString("suppressUnLockPayLoad", tableName: filename, bundle: Bundle.main, value: "Suppress Unlock Payload", comment: "When enabled, then it should be possible to run xDrip4iOS/Libre 2 in parallel with other app(s)")
    }()
    
    static let loopShare: String = {
        return NSLocalizedString("loopShare", tableName: filename, bundle: Bundle.main, value: "Share with OS-AID", comment: "Should the BG readings be shared with an AID system via the shared app group?")
    }()
    
    static let loopShareToLoop: String = {
        return NSLocalizedString("loopShareToLoop", tableName: filename, bundle: Bundle.main, value: "Loop/iAPS", comment: "text for Loop and iAPS")
    }()
    
    static let loopShareToTrio: String = {
        return NSLocalizedString("loopShareToTrio", tableName: filename, bundle: Bundle.main, value: "Trio", comment: "text for Trio")
    }()
    
    static let loopShareMedtrumFollowerDisabled: String = {
        return NSLocalizedString("settingsviews_loopShareMedtrumFollowerDisabled", tableName: filename, bundle: Bundle.main, value: "OS-AID Share is disabled in Medtrum Follower Mode due to safety concerns over sensor accuracy.", comment: "developer settings, Medtrum follower is disabled to share values to shared app group")
    }()
    
    static let selectTime: String = {
        return NSLocalizedString("Select Time", tableName: filename, bundle: Bundle.main, value: "Select Time", comment: "Settings screen for loop delay")
    }()

    static let expanatoryTextSelectTime: String = {
        return NSLocalizedString("expanatoryTextSelectTime", tableName: filename, bundle: Bundle.main, value: "As of what time should the value apply", comment: "Settings screen for loop delay, explanatory text for time")
    }()

    static let selectValue: String = {
        return NSLocalizedString("Select Value", tableName: filename, bundle: Bundle.main, value: "Select Value", comment: "Settings screen for loop delay")
    }()

    static let loopDelaysScreenTitle: String = {
        return NSLocalizedString("loopDelaysScreenTitle", tableName: filename, bundle: Bundle.main, value: "OS-AID Share Delays", comment: "Title for screen where loop delays are configured.")
    }()

    static let expanatoryTextSelectValue: String = {
        return NSLocalizedString("expanatoryTextSelectValue", tableName: filename, bundle: Bundle.main, value: "Delay in minutes, applied to readings shared with OS-AID", comment: "Settings screen for loop delay, explanatory text for value")
    }()

    static let warningLoopDelayAlreadyExists: String = {
        return NSLocalizedString("warningLoopDelayAlreadyExists", tableName: filename, bundle: Bundle.main, value: "There is already a loopDelay for this time.", comment: "When user creates new loopdelay, with a timestamp that already exists - this is the warning text")
    }()
    
    static let showDeveloperSettings: String = {
        return NSLocalizedString("showDeveloperSettings", tableName: filename, bundle: Bundle.main, value: "Show Advanced Settings", comment: "advanced settings, show them or hide them")
    }()

    static let preferSensorCountdown: String = {
        return NSLocalizedString("preferSensorCountdown", tableName: filename, bundle: Bundle.main, value: "Prefer Sensor Countdown", comment: "home screen settings, show remaining sensor lifetime instead of elapsed lifetime")
    }()

    static let sensorNoiseSensitivity: String = {
        return NSLocalizedString("sensorNoiseSensitivity", tableName: filename, bundle: Bundle.main, value: "Sensor Sensitivity", comment: "sensor noise picker, how strictly stored sensor noise values should be interpreted")
    }()

    static let sensorNoiseSensitivityFooter: String = {
        return NSLocalizedString("sensorNoiseSensitivityFooter", tableName: filename, bundle: Bundle.main, value: "Sensor Sensitivity adjusts how strictly sensor noise is classified. Use Sensitive to warn earlier, Normal for standard limits, or Permissive for naturally jumpier sensors. Stored noise values are not changed.", comment: "sensor noise picker footer explaining sensor sensitivity")
    }()

    static let sensorNoiseSensitivitySensitive: String = {
        return NSLocalizedString("sensorNoiseSensitivitySensitive", tableName: filename, bundle: Bundle.main, value: "Sensitive", comment: "sensor noise sensitivity option that warns earlier")
    }()

    static let sensorNoiseSensitivityNormal: String = {
        return NSLocalizedString("sensorNoiseSensitivityNormal", tableName: filename, bundle: Bundle.main, value: "Normal", comment: "default sensor noise sensitivity option")
    }()

    static let sensorNoiseSensitivityPermissive: String = {
        return NSLocalizedString("sensorNoiseSensitivityPermissive", tableName: filename, bundle: Bundle.main, value: "Permissive", comment: "sensor noise sensitivity option that allows more sensor jumpiness")
    }()

    static let nsLog: String = {
        return NSLocalizedString("nslog", tableName: filename, bundle: Bundle.main, value: "NSLog", comment: "developer settings, row title for NSLog - with NSLog enabled, a developer can view log information as explained here https://github.com/JohanDegraeve/xdripswift/wiki/NSLog")
    }()
    
    static let osLog: String = {
        return NSLocalizedString("oslog", tableName: filename, bundle: Bundle.main, value: "OSLog", comment: "developer settings, row title for OSLog - with OSLog enabled, a developer can view log information as explained here https://developer.apple.com/documentation/os/oslog")
    }()
    
    static let libreLinkUpVersion: String = {
        return NSLocalizedString("libreLinkUpVersion", tableName: filename, bundle: Bundle.main, value: "LibreLinkUp version", comment: "developer settings, libre link up version number")
    }()
    
    static let libreLinkUpVersionMessage = {
        return String(format: NSLocalizedString("libreLinkUpVersionMessage", tableName: filename, bundle: Bundle.main, value: "Setting this value incorrectly could result in your LibreLinkUp account being locked.\n\nDo not touch this setting unless instructed by an xDrip4iOS developer.\n\nThe default version is: %@", comment: "developer settings, ask the user for the libre link up version"), ConstantsLibreLinkUp.libreLinkUpVersionDefault)
    }()
    
    static let CAGEMaxHours: String = {
        return NSLocalizedString("CAGEMaxHours", tableName: filename, bundle: Bundle.main, value: "CAGE Max Hours", comment: "developer settings, maximum hours for canula until it expires")
    }()
    
    static let CAGEMaxHoursMessage = {
        return String(format: NSLocalizedString("CAGEMaxHoursMessage", tableName: filename, bundle: Bundle.main, value: "How many hours until the canula should be considered as expired\n\nEnter 0 to set it back to the default value of %@ hours", comment: "developer settings, message asking the user to enter the number of hours until the canula should be considered as expired"), ConstantsHomeView.CAGEDefaultMaxHours.description)
    }()
    
    // MARK: - Section Housekeeper

    static let sectionTitleHousekeeper: String = {
        return NSLocalizedString("settingsviews_sectionTitleHousekeeper", tableName: filename, bundle: Bundle.main, value: "Data Management", comment: "Housekeeper settings, section title")
    }()

    static let settingsviews_housekeeperRetentionPeriod: String = {
        return NSLocalizedString("settingsviews_housekeeperRetentionPeriod", tableName: filename, bundle: Bundle.main, value: "Retention Period", comment: "Housekeeper retention period, for how long to store data")
    }()

    static let settingsviews_housekeeperRetentionPeriodMessage = {
        return NSLocalizedString("settingsviews_housekeeperRetentionPeriodMessage", tableName: filename, bundle: Bundle.main, value: "For how many days should data be stored? (Min 90, Max 365)\n\n(Recommended: 90 days)", comment: "When clicking the retention setting, a pop up asks for how many days should data be stored")
    }()
    
    static let labelStoreFrequentReadingsInNightscout: String = {
        return NSLocalizedString("settingsviews_storeFrequentReadingsInNightscout", tableName: filename, bundle: Bundle.main, value: "Frequent Nightscout Uploads", comment: "developer settings, should we allow the app to perform very frequent uploads to nightscout if the CGM data is more often than every 5 minutes")
    }()
    
    static let labelStoreFrequentReadingsInNightscoutKitMessage: String = {
        return NSLocalizedString("settingsviews_storeFrequentReadingsInNightscoutMessage", tableName: filename, bundle: Bundle.main, value: "This option will override the 5-minute upload limits and allow much frequent BG data to be uploaded to Nightscout. Such as for 60-second Libre 2 Direct values.\n\nPlease only enable this option if you really need/want more frequent data. Most users should leave this option disabled.", comment: "developer settings, should we allow the app to perform very frequent uploads to Nightscout if the CGM data is more often than every 5 minutes")
    }()
    
    static let labelStoreFrequentReadingsInHealthKit: String = {
        return NSLocalizedString("settingsviews_storeFrequentReadingsInHealthKit", tableName: filename, bundle: Bundle.main, value: "Frequent HealthKit Writes", comment: "developer settings, should we allow the app to perform very frequent writes to healthkit if the CGM data is more often than every 5 minutes")
    }()
    
    static let labelStoreFrequentReadingsInHealthKitMessage: String = {
        return NSLocalizedString("settingsviews_storeFrequentReadingsInHealthKitMessage", tableName: filename, bundle: Bundle.main, value: "This option will override the 5-minute write limits and allow much frequent data to be added to Apple Health. Such as for 60-second Libre 2 Direct values.\n\nPlease only enable this option if you really need/want more frequent data. Most users should leave this option disabled.", comment: "developer settings, should we allow the app to perform very frequent writes to healthkit if the CGM data is more often than every 5 minutes")
    }()

    // MARK: - Data Management

    static let dataManagementStorageInfo = NSLocalizedString("settingsviews_dataManagementStorageInfo", tableName: filename, bundle: Bundle.main, value: "Storage Info", comment: "data management, storage information screen title")
    static let dataManagementManageData = NSLocalizedString("settingsviews_dataManagementManageData", tableName: filename, bundle: Bundle.main, value: "Manage Data", comment: "data management, retention and deletion screen title")
    static let dataManagementDataRetention = NSLocalizedString("settingsviews_dataManagementDataRetention", tableName: filename, bundle: Bundle.main, value: "Data Retention", comment: "data management, automatic retention screen title")
    static let dataManagementDataDeletion = NSLocalizedString("settingsviews_dataManagementDataDeletion", tableName: filename, bundle: Bundle.main, value: "Data Deletion", comment: "data management, permanent deletion screen title")
    static let dataManagementImportData = NSLocalizedString("settingsviews_dataManagementImportData", tableName: filename, bundle: Bundle.main, value: "Import Data", comment: "data management, import source screen title")
    static let dataManagementLastHousekeeping = NSLocalizedString("settingsviews_dataManagementLastHousekeeping", tableName: filename, bundle: Bundle.main, value: "Last Housekeeping", comment: "data retention, last automatic housekeeping section title")
    static let storageInfoDatabase = NSLocalizedString("settingsviews_storageInfoDatabase", tableName: filename, bundle: Bundle.main, value: "Database", comment: "storage information, database section title")
    static let storageInfoDatabaseSize = NSLocalizedString("settingsviews_storageInfoDatabaseSize", tableName: filename, bundle: Bundle.main, value: "Database Size", comment: "storage information, Core Data store size")
    static let storageInfoTrackedRecords = NSLocalizedString("settingsviews_storageInfoTrackedRecords", tableName: filename, bundle: Bundle.main, value: "Tracked Records", comment: "storage information, total of the listed historical record types")
    static let storageInfoDevices = NSLocalizedString("settingsviews_storageInfoDevices", tableName: filename, bundle: Bundle.main, value: "Devices", comment: "storage information, stored Bluetooth device records")
    static let storageInfoSensors = NSLocalizedString("settingsviews_storageInfoSensors", tableName: filename, bundle: Bundle.main, value: "Sensors", comment: "storage information, stored sensor session records")
    static let storageInfoHistory = NSLocalizedString("settingsviews_storageInfoHistory", tableName: filename, bundle: Bundle.main, value: "Stored History", comment: "storage information, overall stored date range section title")
    static let storageInfoEarliestRecord = NSLocalizedString("settingsviews_storageInfoEarliestRecord", tableName: filename, bundle: Bundle.main, value: "Earliest Record", comment: "storage information, earliest listed historical record")
    static let storageInfoLatestRecord = NSLocalizedString("settingsviews_storageInfoLatestRecord", tableName: filename, bundle: Bundle.main, value: "Latest Record", comment: "storage information, latest listed historical record")
    static let storageInfoCheckingStatus = NSLocalizedString("settingsviews_storageInfoCheckingStatus", tableName: filename, bundle: Bundle.main, value: "Checking storage…", comment: "storage information, inventory progress status")

    static func storageInfoRetentionFooter(_ days: Int) -> String {
        return String(format: NSLocalizedString("settingsviews_storageInfoRetentionFooter", tableName: filename, bundle: Bundle.main, value: "The configured data retention period is %d days.", comment: "storage information, configured retention period reminder"), days)
    }

    // MARK: - Data Deletion and Retention
    static let cleanDataAutomaticHousekeeping = NSLocalizedString("settingsviews_cleanDataAutomaticHousekeeping", tableName: filename, bundle: Bundle.main, value: "Automatic Housekeeping", comment: "clean data, automatic cleanup setting and section title")
    static let cleanDataKeepHistoricalData = NSLocalizedString("settingsviews_cleanDataKeepHistoricalData", tableName: filename, bundle: Bundle.main, value: "Keep Historical Data", comment: "clean data, automatic retention period picker")
    static let cleanDataLastHousekeepingCompleted = NSLocalizedString("settingsviews_cleanDataLastHousekeepingCompleted", tableName: filename, bundle: Bundle.main, value: "Last Completed", comment: "clean data, last successful automatic housekeeping date")
    static let cleanDataLastHousekeepingResult = NSLocalizedString("settingsviews_cleanDataLastHousekeepingResult", tableName: filename, bundle: Bundle.main, value: "Last Result", comment: "clean data, last automatic housekeeping result")
    static let cleanDataNoHousekeepingRequired = NSLocalizedString("settingsviews_cleanDataNoHousekeepingRequired", tableName: filename, bundle: Bundle.main, value: "No cleanup required", comment: "clean data, automatic housekeeping removed no records")
    static let cleanDataAutomaticHousekeepingFooter = NSLocalizedString("settingsviews_cleanDataAutomaticHousekeepingFooter", tableName: filename, bundle: Bundle.main, value: "Runs at most once per day when the app opens. BG readings, treatments and unused calibrations older than the selected period are removed locally.", comment: "clean data, automatic housekeeping explanation")
    static let cleanDataAutomaticHousekeepingDisabledFooter = NSLocalizedString("settingsviews_cleanDataAutomaticHousekeepingDisabledFooter", tableName: filename, bundle: Bundle.main, value: "Historical data will only be removed manually from Data Deletion.", comment: "data retention, disabled automatic housekeeping explanation")
    static let cleanDataStorageUsed = NSLocalizedString("settingsviews_cleanDataStorageUsed", tableName: filename, bundle: Bundle.main, value: "Storage Used", comment: "clean data, storage occupied by the database")
    static let cleanDataStoredData = NSLocalizedString("settingsviews_cleanDataStoredData", tableName: filename, bundle: Bundle.main, value: "Stored Data", comment: "clean data, stored data section title")
    static let cleanDataBgReadings = NSLocalizedString("settingsviews_cleanDataBgReadings", tableName: filename, bundle: Bundle.main, value: "BG Readings", comment: "clean data, blood glucose readings")
    static let cleanDataTreatments = NSLocalizedString("settingsviews_cleanDataTreatments", tableName: filename, bundle: Bundle.main, value: "Treatments", comment: "clean data, treatment entries")
    static let cleanDataCalibrations = NSLocalizedString("settingsviews_cleanDataCalibrations", tableName: filename, bundle: Bundle.main, value: "Calibrations", comment: "clean data, calibration entries")
    static let cleanDataSelectData = NSLocalizedString("settingsviews_cleanDataSelectData", tableName: filename, bundle: Bundle.main, value: "Data to Delete", comment: "data deletion, data type selection section title")
    static let cleanDataCleanupMethod = NSLocalizedString("settingsviews_cleanDataCleanupMethod", tableName: filename, bundle: Bundle.main, value: "Cleanup Method", comment: "clean data, deletion range method")
    static let cleanDataKeepRecent = NSLocalizedString("settingsviews_cleanDataKeepRecent", tableName: filename, bundle: Bundle.main, value: "Keep Recent", comment: "clean data, retain recent data option")
    static let cleanDataDateRange = NSLocalizedString("settingsviews_cleanDataDateRange", tableName: filename, bundle: Bundle.main, value: "Date Range", comment: "clean data, custom date range option and section title")
    static let cleanDataDeleteAll = NSLocalizedString("settingsviews_cleanDataDeleteAll", tableName: filename, bundle: Bundle.main, value: "Delete All", comment: "clean data, delete all selected data option")
    static let cleanDataKeep = NSLocalizedString("settingsviews_cleanDataKeep", tableName: filename, bundle: Bundle.main, value: "Keep", comment: "clean data, number of recent days to retain")
    static let cleanDataFrom = NSLocalizedString("settingsviews_cleanDataFrom", tableName: filename, bundle: Bundle.main, value: "From", comment: "clean data, inclusive start date")
    static let cleanDataUntil = NSLocalizedString("settingsviews_cleanDataUntil", tableName: filename, bundle: Bundle.main, value: "Until", comment: "clean data, inclusive end date")
    static let cleanDataOlderDataFooter = NSLocalizedString("settingsviews_cleanDataOlderDataFooter", tableName: filename, bundle: Bundle.main, value: "Older data will be deleted. Recent data will be kept.", comment: "clean data, retain recent data explanation")
    static let cleanDataInclusiveDatesFooter = NSLocalizedString("settingsviews_cleanDataInclusiveDatesFooter", tableName: filename, bundle: Bundle.main, value: "Both dates are inclusive.", comment: "clean data, custom date range explanation")
    static let cleanDataDeleteAllFooter = NSLocalizedString("settingsviews_cleanDataDeleteAllFooter", tableName: filename, bundle: Bundle.main, value: "All selected data will be deleted.", comment: "clean data, delete all explanation")
    static let cleanDataContinue = NSLocalizedString("settingsviews_cleanDataContinue", tableName: filename, bundle: Bundle.main, value: "Continue", comment: "clean data, continue to next confirmation step")
    static let cleanDataReviewFooter = NSLocalizedString("settingsviews_cleanDataReviewFooter", tableName: filename, bundle: Bundle.main, value: "You will review the deletion before anything is removed.", comment: "clean data, preview reassurance")
    static let cleanDataPermanentDeletion = NSLocalizedString("settingsviews_cleanDataPermanentDeletion", tableName: filename, bundle: Bundle.main, value: "Permanent Data Deletion", comment: "clean data, destructive action warning title")
    static let cleanDataCannotUndo = NSLocalizedString("settingsviews_cleanDataCannotUndo", tableName: filename, bundle: Bundle.main, value: "This cannot be undone.", comment: "clean data, destructive action warning")
    static let cleanDataUnusedCalibrations = NSLocalizedString("settingsviews_cleanDataUnusedCalibrations", tableName: filename, bundle: Bundle.main, value: "Unused Calibrations", comment: "clean data, unused calibrations included in deletion")
    static let cleanDataEarliestStoredData = NSLocalizedString("settingsviews_cleanDataEarliestStoredData", tableName: filename, bundle: Bundle.main, value: "Earliest stored data", comment: "clean data, beginning of all stored data")
    static let cleanDataDataToDelete = NSLocalizedString("settingsviews_cleanDataDataToDelete", tableName: filename, bundle: Bundle.main, value: "Data to Be Deleted", comment: "clean data, deletion summary section title")
    static let cleanDataEnterCode = NSLocalizedString("settingsviews_cleanDataEnterCode", tableName: filename, bundle: Bundle.main, value: "Enter this six-digit code to confirm", comment: "clean data, captcha instruction")
    static let cleanDataSixDigitCode = NSLocalizedString("settingsviews_cleanDataSixDigitCode", tableName: filename, bundle: Bundle.main, value: "Six-digit code", comment: "clean data, captcha entry field accessibility label")
    static let cleanDataConfirmDelete = NSLocalizedString("settingsviews_cleanDataConfirmDelete", tableName: filename, bundle: Bundle.main, value: "CONFIRM DELETE", comment: "clean data, final destructive confirmation button")
    static let cleanDataSuccessfullyDeleted = NSLocalizedString("settingsviews_cleanDataSuccessfullyDeleted", tableName: filename, bundle: Bundle.main, value: "Data Successfully Deleted", comment: "clean data, deletion success banner")
    static let cleanDataCompleted = NSLocalizedString("settingsviews_cleanDataCompleted", tableName: filename, bundle: Bundle.main, value: "Completed", comment: "clean data, deletion completion date")
    static let cleanDataBgReadingsDeleted = NSLocalizedString("settingsviews_cleanDataBgReadingsDeleted", tableName: filename, bundle: Bundle.main, value: "BG Readings Deleted", comment: "clean data, deleted blood glucose reading count")
    static let cleanDataTreatmentsDeleted = NSLocalizedString("settingsviews_cleanDataTreatmentsDeleted", tableName: filename, bundle: Bundle.main, value: "Treatments Deleted", comment: "clean data, deleted treatment count")
    static let cleanDataStorageBefore = NSLocalizedString("settingsviews_cleanDataStorageBefore", tableName: filename, bundle: Bundle.main, value: "Storage Before", comment: "clean data, database storage before deletion")
    static let cleanDataStorageAfter = NSLocalizedString("settingsviews_cleanDataStorageAfter", tableName: filename, bundle: Bundle.main, value: "Storage After", comment: "clean data, database storage after deletion")
    static let cleanDataCleanupSummary = NSLocalizedString("settingsviews_cleanDataCleanupSummary", tableName: filename, bundle: Bundle.main, value: "Cleanup Summary", comment: "clean data, completion summary section title")
    static let cleanDataDatabaseReuseFooter = NSLocalizedString("settingsviews_cleanDataDatabaseReuseFooter", tableName: filename, bundle: Bundle.main, value: "The database may keep its current size and reuse the freed space.", comment: "clean data, database file size explanation")
    static let cleanDataCheckingStatus = NSLocalizedString("settingsviews_cleanDataCheckingStatus", tableName: filename, bundle: Bundle.main, value: "Checking stored data…", comment: "clean data, inventory progress status")
    static let cleanDataCountingStatus = NSLocalizedString("settingsviews_cleanDataCountingStatus", tableName: filename, bundle: Bundle.main, value: "Counting data to delete…", comment: "clean data, deletion preview progress status")
    static let cleanDataDeletingStatus = NSLocalizedString("settingsviews_cleanDataDeletingStatus", tableName: filename, bundle: Bundle.main, value: "Permanently deleting data…\nPlease keep the app open.", comment: "clean data, deletion progress status")
    static let cleanDataInvalidDateRangeError = NSLocalizedString("settingsviews_cleanDataInvalidDateRangeError", tableName: filename, bundle: Bundle.main, value: "The start date must be before the end date.", comment: "clean data, invalid date range error")
    static let cleanDataNoSelectionError = NSLocalizedString("settingsviews_cleanDataNoSelectionError", tableName: filename, bundle: Bundle.main, value: "Select at least one type of data to delete.", comment: "clean data, no data type selected error")
    static let cleanDataNoMatchingDataError = NSLocalizedString("settingsviews_cleanDataNoMatchingDataError", tableName: filename, bundle: Bundle.main, value: "There is no selected data in this date range.", comment: "clean data, no data in selected range error")
    static let cleanDataChangedError = NSLocalizedString("settingsviews_cleanDataChangedError", tableName: filename, bundle: Bundle.main, value: "Stored data changed after the summary was created. Review the updated data before confirming again.", comment: "clean data, stored data changed during confirmation error")
    static let cleanDataDeleteFailedError = NSLocalizedString("settingsviews_cleanDataDeleteFailedError", tableName: filename, bundle: Bundle.main, value: "The selected data could not be deleted. No further cleanup was attempted.", comment: "clean data, deletion failed error")

    // MARK: - Nightscout Import Summary

    static let nightscoutImportCompleted = NSLocalizedString("settingsviews_nightscoutImportCompleted", tableName: filename, bundle: Bundle.main, value: "Nightscout Import Completed", comment: "nightscout import, completion banner")
    static let nightscoutImportSummary = NSLocalizedString("settingsviews_nightscoutImportSummary", tableName: filename, bundle: Bundle.main, value: "Import Summary", comment: "nightscout import, summary section title")
    static let nightscoutImportURLMissing = NSLocalizedString("settingsviews_nightscoutImportURLMissing", tableName: filename, bundle: Bundle.main, value: "No Nightscout URL configured", comment: "nightscout import, missing source URL banner title")
    static let nightscoutImportConfigureURL = NSLocalizedString("settingsviews_nightscoutImportConfigureURL", tableName: filename, bundle: Bundle.main, value: "Configure a Nightscout URL in Nightscout Settings before importing data.", comment: "nightscout import, missing source URL banner instruction")
    static let nightscoutImportDownloaded = NSLocalizedString("settingsviews_nightscoutImportDownloaded", tableName: filename, bundle: Bundle.main, value: "Downloaded", comment: "nightscout import, downloaded record count")
    static let nightscoutImportAdded = NSLocalizedString("settingsviews_nightscoutImportAdded", tableName: filename, bundle: Bundle.main, value: "Added", comment: "nightscout import, added record count")
    static let nightscoutImportSkipped = NSLocalizedString("settingsviews_nightscoutImportSkipped", tableName: filename, bundle: Bundle.main, value: "Skipped", comment: "nightscout import, duplicate record count")
    static let nightscoutImportInvalid = NSLocalizedString("settingsviews_nightscoutImportInvalid", tableName: filename, bundle: Bundle.main, value: "Invalid", comment: "nightscout import, invalid document count")
    static let nightscoutImportSummaryFooter = NSLocalizedString("settingsviews_nightscoutImportSummaryFooter", tableName: filename, bundle: Bundle.main, value: "Records already stored locally were skipped. Invalid Nightscout documents were not imported.", comment: "nightscout import, summary count explanation")
    static let nightscoutImportingData = NSLocalizedString("settingsviews_nightscoutImportingData", tableName: filename, bundle: Bundle.main, value: "Importing Data", comment: "nightscout import, static progress headline")

    // MARK: - Backup and Restore

    static let backupCreate = NSLocalizedString("settingsviews_backupCreate", tableName: filename, bundle: Bundle.main, value: "Create Backup", comment: "backup, create backup screen title")
    static let backupRestore = NSLocalizedString("settingsviews_backupRestore", tableName: filename, bundle: Bundle.main, value: "Restore Backup", comment: "backup, restore backup screen title and action")
    static let backupCreated = NSLocalizedString("settingsviews_backupCreated", tableName: filename, bundle: Bundle.main, value: "Backup Successfully Created", comment: "backup, successful creation banner")
    static let backupRestored = NSLocalizedString("settingsviews_backupRestored", tableName: filename, bundle: Bundle.main, value: "Backup Successfully Restored", comment: "backup, successful restore banner")
    static let backupReplaceQuestion = NSLocalizedString("settingsviews_backupReplaceQuestion", tableName: filename, bundle: Bundle.main, value: "Replace Existing Data?", comment: "backup restore, destructive confirmation title")
    static let backupReplaceData = NSLocalizedString("settingsviews_backupReplaceData", tableName: filename, bundle: Bundle.main, value: "Replace Data", comment: "backup restore, destructive confirmation action")
    static let backupReplaceWarning = NSLocalizedString("settingsviews_backupReplaceWarning", tableName: filename, bundle: Bundle.main, value: "Existing BG readings and treatments within the backup date ranges will be deleted before the backup is restored.", comment: "backup restore, destructive confirmation explanation")
    static let backupAndRestore = NSLocalizedString("settingsviews_backupAndRestore", tableName: filename, bundle: Bundle.main, value: "Backup & Restore", comment: "backup and restore, error alert title")
    static let backupAppSettingsAndAlerts = NSLocalizedString("settingsviews_backupAppSettingsAndAlerts", tableName: filename, bundle: Bundle.main, value: "App Settings and Alerts", comment: "backup, app settings and alerts option")
    static let backupEncrypt = NSLocalizedString("settingsviews_backupEncrypt", tableName: filename, bundle: Bundle.main, value: "Encrypt Backup", comment: "backup, encryption option")
    static let backupAccounts = NSLocalizedString("settingsviews_backupAccounts", tableName: filename, bundle: Bundle.main, value: "Backup Accounts", comment: "backup, account details option")
    static let backupConfirmPassword = NSLocalizedString("settingsviews_backupConfirmPassword", tableName: filename, bundle: Bundle.main, value: "Confirm Password", comment: "backup, password confirmation field")
    static let backupPasswordProtection = NSLocalizedString("settingsviews_backupPasswordProtection", tableName: filename, bundle: Bundle.main, value: "Password Protection", comment: "backup, password protection section title and summary row")
    static let backupPasswordProtectionFooter = NSLocalizedString("settingsviews_backupPasswordProtectionFooter", tableName: filename, bundle: Bundle.main, value: "Adding password protection also allows accounts containing sensitive details to be backed up.", comment: "backup, password protection explanation")
    static let backupAccountDetailsFooter = NSLocalizedString("settingsviews_backupAccountDetailsFooter", tableName: filename, bundle: Bundle.main, value: "Account details may include server URLs, usernames, passwords and access tokens.", comment: "backup, sensitive account details explanation")
    static let backupCreateAndShare = NSLocalizedString("settingsviews_backupCreateAndShare", tableName: filename, bundle: Bundle.main, value: "Create and Share Backup", comment: "backup, final creation action")
    static let backupEncryptedCreationFooter = NSLocalizedString("settingsviews_backupEncryptedCreationFooter", tableName: filename, bundle: Bundle.main, value: "Encrypted backups take longer to create. Keep the app open and please be patient.", comment: "backup, encrypted creation duration warning")
    static let backupCreatedAt = NSLocalizedString("settingsviews_backupCreatedAt", tableName: filename, bundle: Bundle.main, value: "Created", comment: "backup, creation date row")
    static let backupEarliestData = NSLocalizedString("settingsviews_backupEarliestData", tableName: filename, bundle: Bundle.main, value: "Earliest Data", comment: "backup, earliest stored data row")
    static let backupSettingsAndAlerts = NSLocalizedString("settingsviews_backupSettingsAndAlerts", tableName: filename, bundle: Bundle.main, value: "Settings and Alerts", comment: "backup, settings and alerts summary row")
    static let backupAccountDetails = NSLocalizedString("settingsviews_backupAccountDetails", tableName: filename, bundle: Bundle.main, value: "Account Details", comment: "backup, account details summary row")
    static let backupIncluded = NSLocalizedString("settingsviews_backupIncluded", tableName: filename, bundle: Bundle.main, value: "Included", comment: "backup, item is included")
    static let backupNotIncluded = NSLocalizedString("settingsviews_backupNotIncluded", tableName: filename, bundle: Bundle.main, value: "Not included", comment: "backup, item is not included")
    static let backupNotEnabled = NSLocalizedString("settingsviews_backupNotEnabled", tableName: filename, bundle: Bundle.main, value: "Not enabled", comment: "backup, option is not enabled")
    static let backupSummary = NSLocalizedString("settingsviews_backupSummary", tableName: filename, bundle: Bundle.main, value: "Backup Summary", comment: "backup, completion summary section title")
    static let backupChooseFile = NSLocalizedString("settingsviews_backupChooseFile", tableName: filename, bundle: Bundle.main, value: "Choose Backup File", comment: "backup restore, file selection action")
    static let backupFile = NSLocalizedString("settingsviews_backupFile", tableName: filename, bundle: Bundle.main, value: "Backup File", comment: "backup restore, file selection section title")
    static let backupFileCheckFooter = NSLocalizedString("settingsviews_backupFileCheckFooter", tableName: filename, bundle: Bundle.main, value: "The backup is checked before any existing data is changed.", comment: "backup restore, validation reassurance")
    static let backupSelected = NSLocalizedString("settingsviews_backupSelected", tableName: filename, bundle: Bundle.main, value: "Selected Backup", comment: "backup restore, selected backup section title")
    static let backupPasswordRequired = NSLocalizedString("settingsviews_backupPasswordRequired", tableName: filename, bundle: Bundle.main, value: "Required", comment: "backup restore, required password field placeholder")
    static let backupUnlock = NSLocalizedString("settingsviews_backupUnlock", tableName: filename, bundle: Bundle.main, value: "Unlock Backup", comment: "backup restore, unlock encrypted backup action")
    static let backupEncryptedNotice = NSLocalizedString("settingsviews_backupEncryptedNotice", tableName: filename, bundle: Bundle.main, value: "This backup is encrypted and must be unlocked.", comment: "backup restore, encrypted backup banner")
    static let backupSettings = NSLocalizedString("settingsviews_backupSettings", tableName: filename, bundle: Bundle.main, value: "Settings", comment: "backup restore, settings summary row")
    static let backupRestoreOptions = NSLocalizedString("settingsviews_backupRestoreOptions", tableName: filename, bundle: Bundle.main, value: "Restore Options", comment: "backup restore, restore options section title")
    static let backupDataHandling = NSLocalizedString("settingsviews_backupDataHandling", tableName: filename, bundle: Bundle.main, value: "Data Handling", comment: "backup restore, merge mode picker")
    static let backupKeepCurrentData = NSLocalizedString("settingsviews_backupKeepCurrentData", tableName: filename, bundle: Bundle.main, value: "Keep Current Data", comment: "backup restore, keep current data merge mode")
    static let backupFillGaps = NSLocalizedString("settingsviews_backupFillGaps", tableName: filename, bundle: Bundle.main, value: "Fill Gaps", comment: "backup restore, fill missing data merge mode")
    static let backupReplaceRange = NSLocalizedString("settingsviews_backupReplaceRange", tableName: filename, bundle: Bundle.main, value: "Replace Backup Range", comment: "backup restore, replace date range merge mode")
    static let backupIgnoreData = NSLocalizedString("settingsviews_backupIgnoreData", tableName: filename, bundle: Bundle.main, value: "Ignore Data", comment: "backup restore, do not restore historical data merge mode")
    static let backupRestoreSettingsAndAlerts = NSLocalizedString("settingsviews_backupRestoreSettingsAndAlerts", tableName: filename, bundle: Bundle.main, value: "Restore App Settings and Alerts", comment: "backup restore, settings restore option")
    static let backupRestoreAccounts = NSLocalizedString("settingsviews_backupRestoreAccounts", tableName: filename, bundle: Bundle.main, value: "Restore Accounts", comment: "backup restore, accounts restore option")
    static let backupReplaceAndRestore = NSLocalizedString("settingsviews_backupReplaceAndRestore", tableName: filename, bundle: Bundle.main, value: "Replace and Restore", comment: "backup restore, destructive restore action")
    static let backupRestoreSummary = NSLocalizedString("settingsviews_backupRestoreSummary", tableName: filename, bundle: Bundle.main, value: "Restore Summary", comment: "backup restore, completion summary section title")
    static let backupBgReadingsAppliedFrom = NSLocalizedString("settingsviews_backupBgReadingsAppliedFrom", tableName: filename, bundle: Bundle.main, value: "BG Readings Applied From", comment: "backup restore, first applied reading date")
    static let backupBgReadingsAdded = NSLocalizedString("settingsviews_backupBgReadingsAdded", tableName: filename, bundle: Bundle.main, value: "BG Readings Added", comment: "backup restore, added reading count")
    static let backupBgReadingsSkipped = NSLocalizedString("settingsviews_backupBgReadingsSkipped", tableName: filename, bundle: Bundle.main, value: "BG Readings Skipped", comment: "backup restore, skipped reading count")
    static let backupTreatmentsAdded = NSLocalizedString("settingsviews_backupTreatmentsAdded", tableName: filename, bundle: Bundle.main, value: "Treatments Added", comment: "backup restore, added treatment count")
    static let backupTreatmentsSkipped = NSLocalizedString("settingsviews_backupTreatmentsSkipped", tableName: filename, bundle: Bundle.main, value: "Treatments Skipped", comment: "backup restore, skipped treatment count")
    static let backupSettingsRestored = NSLocalizedString("settingsviews_backupSettingsRestored", tableName: filename, bundle: Bundle.main, value: "Settings Restored", comment: "backup restore, restored settings count")
    static let backupAccountRestore = NSLocalizedString("settingsviews_backupAccountRestore", tableName: filename, bundle: Bundle.main, value: "Account Restore", comment: "backup restore, account result section title")
    static let backupCreatingEncryptedStatus = NSLocalizedString("settingsviews_backupCreatingEncryptedStatus", tableName: filename, bundle: Bundle.main, value: "Creating and encrypting your backup securely…\nPlease be patient.", comment: "backup, encrypted creation progress")
    static let backupCreatingStatus = NSLocalizedString("settingsviews_backupCreatingStatus", tableName: filename, bundle: Bundle.main, value: "Creating backup…", comment: "backup, creation progress")
    static let backupCheckingStatus = NSLocalizedString("settingsviews_backupCheckingStatus", tableName: filename, bundle: Bundle.main, value: "Checking backup…", comment: "backup restore, validation progress")
    static let backupDecryptingStatus = NSLocalizedString("settingsviews_backupDecryptingStatus", tableName: filename, bundle: Bundle.main, value: "Decrypting and checking your backup…\nPlease be patient.", comment: "backup restore, decryption progress")
    static let backupRestoringEncryptedStatus = NSLocalizedString("settingsviews_backupRestoringEncryptedStatus", tableName: filename, bundle: Bundle.main, value: "Restoring your encrypted backup…\nPlease be patient.", comment: "backup restore, encrypted restore progress")
    static let backupRestoringStatus = NSLocalizedString("settingsviews_backupRestoringStatus", tableName: filename, bundle: Bundle.main, value: "Restoring backup…", comment: "backup restore, restore progress")
    static let backupErrorInvalidFile = NSLocalizedString("settingsviews_backupErrorInvalidFile", tableName: filename, bundle: Bundle.main, value: "This is not a valid app backup.", comment: "backup restore, invalid file error")
    static let backupErrorIncorrectPassword = NSLocalizedString("settingsviews_backupErrorIncorrectPassword", tableName: filename, bundle: Bundle.main, value: "The password is incorrect or the protected backup is damaged.", comment: "backup restore, incorrect password error")
    static let backupErrorMissingPassword = NSLocalizedString("settingsviews_backupErrorMissingPassword", tableName: filename, bundle: Bundle.main, value: "Enter the password used to protect this backup.", comment: "backup restore, missing password error")

    // MARK: - Nightscout Import Workflow

    static let nightscoutImportQuestion = NSLocalizedString("settingsviews_nightscoutImportQuestion", tableName: filename, bundle: Bundle.main, value: "Import from Nightscout?", comment: "nightscout import, start confirmation title")
    static let nightscoutImportAction = NSLocalizedString("settingsviews_nightscoutImportAction", tableName: filename, bundle: Bundle.main, value: "Import from Nightscout", comment: "nightscout import, screen action and alert title")
    static let nightscoutImportDiscardQuestion = NSLocalizedString("settingsviews_nightscoutImportDiscardQuestion", tableName: filename, bundle: Bundle.main, value: "Discard Saved Import?", comment: "nightscout import, discard confirmation title")
    static let nightscoutImportDiscard = NSLocalizedString("settingsviews_nightscoutImportDiscard", tableName: filename, bundle: Bundle.main, value: "Discard Import", comment: "nightscout import, discard confirmation action")
    static let nightscoutImportDiscardSaved = NSLocalizedString("settingsviews_nightscoutImportDiscardSaved", tableName: filename, bundle: Bundle.main, value: "Discard Saved Import", comment: "nightscout import, discard checkpoint action")
    static let nightscoutImportDiscardMessage = NSLocalizedString("settingsviews_nightscoutImportDiscardMessage", tableName: filename, bundle: Bundle.main, value: "Saved progress will be removed. Imported data will remain safely stored and will be skipped if you start again.", comment: "nightscout import, discard checkpoint explanation")
    static let nightscoutImportDataToImport = NSLocalizedString("settingsviews_nightscoutImportDataToImport", tableName: filename, bundle: Bundle.main, value: "Data to Import", comment: "nightscout import, data type section title")
    static let nightscoutImportPeriod = NSLocalizedString("settingsviews_nightscoutImportPeriod", tableName: filename, bundle: Bundle.main, value: "Import Period", comment: "nightscout import, period picker")
    static let nightscoutImportExistingDataFooter = NSLocalizedString("settingsviews_nightscoutImportExistingDataFooter", tableName: filename, bundle: Bundle.main, value: "Existing local data is kept. BG readings within 30 seconds of an existing reading and treatments already identified by Nightscout are skipped.", comment: "nightscout import, duplicate handling explanation")
    static let nightscoutImportKeepOpenFooter = NSLocalizedString("settingsviews_nightscoutImportKeepOpenFooter", tableName: filename, bundle: Bundle.main, value: "Keep the app open until the import finishes. Progress is saved after each completed batch, so an interrupted import can be resumed.", comment: "nightscout import, operation duration explanation")
    static let nightscoutImportPeriodLabel = NSLocalizedString("settingsviews_nightscoutImportPeriodLabel", tableName: filename, bundle: Bundle.main, value: "Period", comment: "nightscout import, saved import period row")
    static let nightscoutImportCompletedBatches = NSLocalizedString("settingsviews_nightscoutImportCompletedBatches", tableName: filename, bundle: Bundle.main, value: "Completed Batches", comment: "nightscout import, completed batch count")
    static let nightscoutImportResume = NSLocalizedString("settingsviews_nightscoutImportResume", tableName: filename, bundle: Bundle.main, value: "Resume Import", comment: "nightscout import, resume action")
    static let nightscoutImportSaved = NSLocalizedString("settingsviews_nightscoutImportSaved", tableName: filename, bundle: Bundle.main, value: "Saved Import", comment: "nightscout import, saved checkpoint section title")
    static let nightscoutImportUnsupportedFooter = NSLocalizedString("settingsviews_nightscoutImportUnsupportedFooter", tableName: filename, bundle: Bundle.main, value: "This import uses an unsupported period. Discard it to start again.", comment: "nightscout import, unsupported checkpoint explanation")
    static let nightscoutImportExceedsRetentionFooter = NSLocalizedString("settingsviews_nightscoutImportExceedsRetentionFooter", tableName: filename, bundle: Bundle.main, value: "This import exceeds your current retention period. Discard it to start again.", comment: "nightscout import, checkpoint retention explanation")
    static let nightscoutImportResumeFooter = NSLocalizedString("settingsviews_nightscoutImportResumeFooter", tableName: filename, bundle: Bundle.main, value: "The previous import stopped before all requested batches completed. Resuming continues from its last saved checkpoint.", comment: "nightscout import, resume explanation")
    static let nightscoutImportPause = NSLocalizedString("settingsviews_nightscoutImportPause", tableName: filename, bundle: Bundle.main, value: "Pause Import", comment: "nightscout import, pause action")
    static let nightscoutImportBgAndTreatments = NSLocalizedString("settingsviews_nightscoutImportBgAndTreatments", tableName: filename, bundle: Bundle.main, value: "BG readings and treatments", comment: "nightscout import, selected data description")
    static let nightscoutImportBgOnly = NSLocalizedString("settingsviews_nightscoutImportBgOnly", tableName: filename, bundle: Bundle.main, value: "BG readings", comment: "nightscout import, selected readings description")
    static let nightscoutImportTreatmentsOnly = NSLocalizedString("settingsviews_nightscoutImportTreatmentsOnly", tableName: filename, bundle: Bundle.main, value: "treatments", comment: "nightscout import, selected treatments description")
    static let nightscoutImportKeepAppOpen = NSLocalizedString("settingsviews_nightscoutImportKeepAppOpen", tableName: filename, bundle: Bundle.main, value: "Keep the app open.", comment: "nightscout import, progress reminder")
    static let nightscoutImportPaused = NSLocalizedString("settingsviews_nightscoutImportPaused", tableName: filename, bundle: Bundle.main, value: "Import paused", comment: "nightscout import, paused progress title")
    static let nightscoutImportErrorNoSelection = NSLocalizedString("settingsviews_nightscoutImportErrorNoSelection", tableName: filename, bundle: Bundle.main, value: "Select BG readings, treatments or both.", comment: "nightscout import, no data selected error")
    static let nightscoutImportErrorUnsupportedPeriod = NSLocalizedString("settingsviews_nightscoutImportErrorUnsupportedPeriod", tableName: filename, bundle: Bundle.main, value: "The saved import uses a period that is no longer supported. Discard it and start again.", comment: "nightscout import, unsupported period error")
    static let nightscoutImportErrorRetention = NSLocalizedString("settingsviews_nightscoutImportErrorRetention", tableName: filename, bundle: Bundle.main, value: "The selected import period exceeds the current data retention setting.", comment: "nightscout import, retention period error")
    static let nightscoutImportErrorMissingURL = NSLocalizedString("settingsviews_nightscoutImportErrorMissingURL", tableName: filename, bundle: Bundle.main, value: "Enter a Nightscout URL in Nightscout Settings before starting an import.", comment: "nightscout import, missing URL error")
    static let nightscoutImportErrorInvalidURL = NSLocalizedString("settingsviews_nightscoutImportErrorInvalidURL", tableName: filename, bundle: Bundle.main, value: "The configured Nightscout URL is not valid. Check it in Nightscout Settings and try again.", comment: "nightscout import, invalid URL error")
    static let nightscoutImportErrorCheckpointUnavailable = NSLocalizedString("settingsviews_nightscoutImportErrorCheckpointUnavailable", tableName: filename, bundle: Bundle.main, value: "The saved Nightscout import can no longer be resumed. Start a new import.", comment: "nightscout import, unavailable checkpoint error")
    static let nightscoutImportErrorSiteChanged = NSLocalizedString("settingsviews_nightscoutImportErrorSiteChanged", tableName: filename, bundle: Bundle.main, value: "The configured Nightscout site has changed since this import started. Discard the saved import or restore the previous Nightscout URL.", comment: "nightscout import, changed site error")
    static let nightscoutImportErrorAuthentication = NSLocalizedString("settingsviews_nightscoutImportErrorAuthentication", tableName: filename, bundle: Bundle.main, value: "Nightscout denied access. Check the API secret or access token in Nightscout Settings.", comment: "nightscout import, authentication error")
    static let nightscoutImportErrorEndpoint = NSLocalizedString("settingsviews_nightscoutImportErrorEndpoint", tableName: filename, bundle: Bundle.main, value: "The Nightscout data endpoint was not found. Check the configured URL and site version.", comment: "nightscout import, endpoint error")
    static let nightscoutImportErrorRateLimited = NSLocalizedString("settingsviews_nightscoutImportErrorRateLimited", tableName: filename, bundle: Bundle.main, value: "Nightscout is receiving too many requests. Wait a moment and resume the import.", comment: "nightscout import, rate limit error")
    static let nightscoutImportErrorInvalidResponse = NSLocalizedString("settingsviews_nightscoutImportErrorInvalidResponse", tableName: filename, bundle: Bundle.main, value: "Nightscout returned data that could not be read safely. No data from the affected batch was imported.", comment: "nightscout import, invalid response error")
    static let nightscoutImportErrorResponseLimit = NSLocalizedString("settingsviews_nightscoutImportErrorResponseLimit", tableName: filename, bundle: Bundle.main, value: "A Nightscout batch remained too large after being divided into small time ranges. No truncated data was imported.", comment: "nightscout import, response limit error")

    static func cleanDataDays(_ days: Int) -> String {
        return String(format: NSLocalizedString("settingsviews_cleanDataDays", tableName: filename, bundle: Bundle.main, value: "%d days", comment: "clean data, number of days to retain"), days)
    }

    static func nightscoutImportRetentionFooter(_ days: Int) -> String {
        return String(format: NSLocalizedString("settingsviews_nightscoutImportRetentionFooter", tableName: filename, bundle: Bundle.main, value: "Limited to your %d-day retention period. Older data is removed by housekeeping.", comment: "nightscout import, retention limit explanation"), days)
    }

    static func cleanDataHousekeepingRecordsRemoved(_ count: Int) -> String {
        let key = count == 1 ? "settingsviews_cleanDataOneHousekeepingRecordRemoved" : "settingsviews_cleanDataHousekeepingRecordsRemoved"
        let value = count == 1 ? "%@ record removed" : "%@ records removed"
        return String(format: NSLocalizedString(key, tableName: filename, bundle: Bundle.main, value: value, comment: "clean data, records removed by automatic housekeeping"), count.formatted())
    }

    static func cleanDataConfirmationCode(_ code: String) -> String {
        return String(format: NSLocalizedString("settingsviews_cleanDataConfirmationCode", tableName: filename, bundle: Bundle.main, value: "Confirmation code %@", comment: "clean data, accessibility label for captcha code"), code)
    }

    static func backupCreatedWithAppVersion(_ appVersion: String) -> String {
        return String(format: NSLocalizedString("settingsviews_backupCreatedWithAppVersion", tableName: filename, bundle: Bundle.main, value: "Backup created with app version %@.", comment: "backup, creating app version footer"), appVersion)
    }

    static func backupErrorUnsupportedVersion(_ version: Int) -> String {
        return String(format: NSLocalizedString("settingsviews_backupErrorUnsupportedVersion", tableName: filename, bundle: Bundle.main, value: "Backup format version %d is not supported by this version of the app.", comment: "backup restore, unsupported format error"), version)
    }

    static func backupErrorFinalValueMismatch(_ identifier: String) -> String {
        return String(format: NSLocalizedString("settingsviews_backupErrorFinalValueMismatch", tableName: filename, bundle: Bundle.main, value: "Stored glucose values do not reproduce the backed-up final value for reading %@.", comment: "backup restore, reading validation error"), identifier)
    }

    static func nightscoutImportBatchCount(_ completed: Int, _ total: Int) -> String {
        return String(format: NSLocalizedString("settingsviews_nightscoutImportBatchCount", tableName: filename, bundle: Bundle.main, value: "%1$d of %2$d", comment: "nightscout import, completed batches out of total batches"), completed, total)
    }

    static func nightscoutImportBgAddedProgress(_ count: Int) -> String {
        return String(format: NSLocalizedString("settingsviews_nightscoutImportBgAddedProgress", tableName: filename, bundle: Bundle.main, value: "BG readings added: %@", comment: "nightscout import, live added reading count"), count.formatted())
    }

    static func nightscoutImportTreatmentsAddedProgress(_ count: Int) -> String {
        return String(format: NSLocalizedString("settingsviews_nightscoutImportTreatmentsAddedProgress", tableName: filename, bundle: Bundle.main, value: "Treatments added: %@", comment: "nightscout import, live added treatment count"), count.formatted())
    }

    static func nightscoutImportConfirmation(_ days: Int, _ selectedData: String) -> String {
        return String(format: NSLocalizedString("settingsviews_nightscoutImportConfirmation", tableName: filename, bundle: Bundle.main, value: "Import the last %1$d days of %2$@? Existing local records will be kept and duplicates will be skipped.", comment: "nightscout import, start confirmation message"), days, selectedData)
    }

    static func nightscoutImportBatchProgress(_ current: Int, _ total: Int) -> String {
        return String(format: NSLocalizedString("settingsviews_nightscoutImportBatchProgress", tableName: filename, bundle: Bundle.main, value: "Batch %1$d of %2$d", comment: "nightscout import, current batch progress"), current, total)
    }

    static func nightscoutImportErrorServer(_ status: Int) -> String {
        return String(format: NSLocalizedString("settingsviews_nightscoutImportErrorServer", tableName: filename, bundle: Bundle.main, value: "Nightscout returned a temporary server error (HTTP %d). Resume the import later.", comment: "nightscout import, temporary server error"), status)
    }

    static func nightscoutImportErrorUnexpectedStatus(_ status: Int) -> String {
        return String(format: NSLocalizedString("settingsviews_nightscoutImportErrorUnexpectedStatus", tableName: filename, bundle: Bundle.main, value: "Nightscout returned an unexpected response (HTTP %d).", comment: "nightscout import, unexpected HTTP status error"), status)
    }
    
}
