/// for use in OSLog
enum ConstantsLog {
    
    /// for use in OSLog
    static let subSystem = "xDrip"
    
    /// for use in NSLog
    static let tracePrefix = "xDrip-NSLog"
    
    /// debuglogging
    static let debuglogging = "xdripdebuglogging"

    /// timestamp format for nslog
    static let dateFormatNSLog = "y-MM-dd HH:mm:ss.SSSS"

    // MARK: - Categories

    /// for use in OSLog
    static let categoryBlueToothTransmitter =               "BlueToothTransmitter          "
    
    /// for use in cgm transmitter miaomiao
    static let categoryCGMMiaoMiao =                        "CGMMiaoMiao                   "
    
    /// for use in cgm transmitter bubble
    static let categoryCGMBubble =                          "CGMBubble                     "
    
    /// for use in cgm xdripg4
    static let categoryCGMxDripG4 =                         "CGMxDripG4                    "
    
    /// for use in firstview
    static let categoryRootView =                           "RootView                      "
    
    /// calibration
    static let categoryCalibration =                        "Calibration                   "

    /// G5
    static let categoryCGMG5 =                              "CGMG5                         "
    
    /// G7
    static let categoryCGMG7 =                              "CGMG7                         "
    
    /// Libre2
    static let categoryCGMLibre2 =                          "Libre2                        "
    
    /// core data manager
    static let categoryCoreDataManager =                    "CoreDataManager               "
    
    /// application data bgreadings
    static let categoryApplicationDataBgReadings =          "ApplicationDataBgReadings     "
	
	/// application data Treatments
	static let categoryApplicationDataTreatments =          "ApplicationDataTreatments     "
    
    /// application data calibrations
    static let categoryApplicationDataCalibrations =        "ApplicationDataCalibrations   "
    
    /// application data sensors
    static let categoryApplicationDataSensors =             "ApplicationDataSensors        "
    
    /// application data alerttypes
    static let categoryApplicationDataAlertTypes =          "ApplicationDataAlertTypes     "
    
    /// application data alertentries
    static let categoryApplicationDataAlertEntries =        "ApplicationDataAlertEntries   "
    
    /// application data for M5Stack
    static let categoryApplicationDataM5Stacks =            "ApplicationDataM5Stacks         "
    
    /// application data for BLEPeripheral
    static let categoryApplicationDataBLEPeripheral =       "ApplicationDataBLEPeripheral  "
    
    /// application data for DexcomG5
    static let categoryApplicationDataDexcomG5 =            "ApplicationDataDexcomG5       "
    
    /// application for for M5StackName
    static let categoryApplicationDataM5StackNames =        "ApplicationDataM5StackNames   "
    
    /// nightscout uploader
    static let categoryNightscoutSyncManager =              "NightscoutSyncManager         "
    
    /// SettingsViewNightscoutSettingsViewModel
    static let categorySettingsViewNightscoutSettingsViewModel = 
                                                            "NightscoutSettingsViewModel   "
    
    /// nightscout follow
    static let categoryNightscoutFollowManager =            "NightscoutFollowManager       "
    
    /// nightscout follow
    static let categoryLibreLinkUpFollowManager =           "LibreLinkUpFollowManager      "
    
    /// nightscout follow
    static let categoryDexcomShareFollowManager =           "DexcomShareFollowManager      "

    /// medtrum easyview follow
    static let categoryMedtrumEasyViewFollowManager =       "MedtrumEasyViewFollowManager  "

    /// alertmanager
    static let categoryAlertManager =                       "AlertManager                  "
    
    /// playsound
    static let categoryPlaySound =                          "PlaySound                     "
    
    /// healthkit manager
    static let categoryHealthKitManager =                   "HealthKitManager              "
    
    /// SettingsViewHealthKitSettingsViewModel
    static let categorySettingsViewHealthKitSettingsViewModel = 
                                                            "HealthKitSettingsViewModel    "
    
    /// dexcom share upload manager
    static let categoryDexcomShareUploadManager =           "DexcomShareUploadManager      "
    
    /// SettingsViewDexcomShareUploadSettingsViewModel
    static let categorySettingsViewDexcomShareUploadSettingsViewModel = 
                                                            "DexcomShareUploadSettngsVwMdl " // spell to fit available space
    
    /// SettingsViewSpeakSettingsViewModel
    static let categorySettingsViewSpeakSettingsViewModel = "SpeakSettingsViewModel        "
    
    /// LibreOOPClient
    static let categoryLibreOOPClient =                     "LibreOOPClient                "
    
    /// libreDataParser
    static let categoryLibreDataParser =                    "LibreDataParser               "
    
    /// for use in M5Stack
    static let categoryM5StackBluetoothTransmitter =        "M5StackBluetoothTransmitter   "
    
    /// BluetoothPeripheralManager logging
    static let categoryBluetoothPeripheralManager =         "BluetoothPeripheralManager    "

    /// StatusChartsManager logging
    static let categoryGlucoseChartManager =                "GlucoseChartManager           "
    
    /// SettingsViewCalendarEventsSettingsViewModel logging
    static let categorySettingsViewCalendarEventsSettingsViewModel =
                                                            "CalendarEventSettngsViewModel " // spell to fit available space
    
    /// CalendarManager logging
    static let categoryCalendarManager =                    "CalendarManager               "

    /// SettingsViewContactImageSettingsViewModel logging
    static let categorySettingsViewContactImageSettingsViewModel = 
                                                            "ContactImageSettingsViewModel "

    /// WatchManager logging
    static let categoryWatchManager =                       "WatchManager                  "
    
    /// SettingsViewAppleWatchSettingsViewModel logging
    static let categorySettingsViewAppleWatchSettingsViewModel = 
                                                            "AppleWatchSettingsViewModel   "

    /// ContactImageManager logging
    static let categoryContactImageManager =                "ContactImageManager           "

    /// bluetoothPeripheralViewController
    static let categoryBluetoothPeripheralViewController =  "BLEPeripheralViewController   "
    
    /// nightscout view model
    static let categoryNightscoutSettingsViewModel =        "NightscoutSettingsViewModel   "
    
    /// trace
    static let categoryTraceSettingsViewModel =             "TraceSettingsViewModel        "
    
    /// housekeeping
    static let categoryHouseKeeper =                        "HouseKeeper                   "
    
    /// soonzeParameter accessor
    static let categoryApplicationDataSnoozeParameter =     "ApplicationDataSnoozeParametr " // spell to fit available space
    
    /// libre NFC
    static let categoryLibreNFC =                           "categoryLibreNFC              "
    
    /// for use in cgm transmitter bubble
    static let categoryLibreSensorType =                    "categoryLibreSensorType       "

    /// for use in Libre2BLEUtilities
    static let categoryLibre2BLEUtilities =                 "Libre2BLEUtilities            "

    /// for use in Libre2BLEUtilities
    static let categoryAppDelegate =                        "AppDelegate                   "
    
	/// for use in DataExporter
	static let categoryDataExporter =                       "DataExporter                  "

    // for use in LoopManager
    static let categoryLoopManager =                        "LoopManager                   "
    
    /// for use in Bg Readings view
    static let categoryBgReadingsView =                     "BgReadingsView                "
    
    /// SettingsViewCalendarEventsSettingsViewModel logging
    static let categorySettingsViewDataSourceSettingsViewModel = 
                                                            "DataSourceSettingsViewModel   "
    
    /// SettingsViewNotificationsSettingsViewModel logging
    static let categorySettingsViewNotificationsSettingsViewModel = 
                                                            "NotificationsViewModel        "

    /// for use in LiveActivityManager
    static let categoryLiveActivityManager =                "LiveActivityManager           "
    
    /// for use in Libre3HeartBeatTransmitter
    static let categoryHeartBeatLibre3 =                    "HeartBeatLibre3               "


    /// for use in DexcomG7HeartBeatTransmitter
    static let categoryHeartBeatG7 =                        "HeartBeatG7                   "
    
    /// for use in LibreViewFollowManager
    static let categoryLoopFollowManager =                  "LoopFollowManager             "
    
    /// for use in Omni¨PodHeartBeatTransmitter
    static let categoryHeartBeatOmnipod =                   "HeartBeatOmnipod              "
}

