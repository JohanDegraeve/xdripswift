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
    static let categoryBlueToothTransmitter =           "BlueToothTransmitter          "
    
    /// for use in cgm transmitter miaomiao
    static let categoryCGMMiaoMiao =                    "CGMMiaoMiao                   "
    
    /// for use in cgm transmitter bubble
    static let categoryCGMBubble =                      "CGMBubble                     "
    
    /// for use in cgm xdripg4
    static let categoryCGMxDripG4 =                     "CGMxDripG4                    "
    
    /// for use in firstview
    static let categoryRootView =                       "RootView                      "
    
    /// calibration
    static let categoryCalibration =                    "Calibration                   "

    /// G5
    static let categoryCGMG5 =                          "CGMG5                         "
    
    /// G7
    static let categoryCGMG7 =                          "CGMG7                         "
    
    /// watlaa
    static let categoryWatlaa =                         "Watlaa"
    
    /// GNSEntry
    static let categoryCGMGNSEntry =                    "CGMGNSEntry                   "
    
    /// Blucon
    static let categoryBlucon =                         "Blucon                        "
    
    /// Libre2
    static let categoryCGMLibre2 =                      "Libre2                        "
    
    /// core data manager
    static let categoryCoreDataManager =                "CoreDataManager               "
    
    /// application data bgreadings
    static let categoryApplicationDataBgReadings =      "ApplicationDataBgReadings     "
	
	/// application data Treatments
	static let categoryApplicationDataTreatments =      "ApplicationDataTreatments     "
    
    /// application data calibrations
    static let categoryApplicationDataCalibrations =    "ApplicationDataCalibrations   "
    
    /// application data sensors
    static let categoryApplicationDataSensors =         "ApplicationDataSensors        "
    
    /// application data alerttypes
    static let categoryApplicationDataAlertTypes =      "ApplicationDataAlertTypes     "
    
    /// application data alertentries
    static let categoryApplicationDataAlertEntries =    "ApplicationDataAlertEntries   "
    
    /// application data for M5Stack
    static let categoryApplicationDataM5Stacks =        "ApplicationDataM5Stacks       "
    
    /// application data for M5Stack
    static let categoryApplicationDataWatlaa =          "ApplicationDataWatlaa"
    
    /// application data for BLEPeripheral
    static let categoryApplicationDataBLEPeripheral =
                                                        "ApplicationDataBLEPeripheral"
    
    /// application data for DexcomG5
    static let categoryApplicationDataDexcomG5 =        "ApplicationDataDexcomG5"
    
    /// application for for M5StackName
    static let categoryApplicationDataM5StackNames =    "ApplicationDataM5StackNames   "
    
    /// nightscout uploader
    static let categoryNightscoutSyncManager =          "NightscoutSyncManager         "
    
    /// nightscout follow
    static let categoryNightscoutFollowManager =        "NightscoutFollowManager       "
    
    /// nightscout follow
    static let categoryLibreLinkUpFollowManager =       "LibreLinkUpFollowManager      "
    
    /// nightscout follow
    static let categoryDexcomShareFollowManager =       "DexcomShareFollowManager      "
    
    /// alertmanager
    static let categoryAlertManager =                   "AlertManager                  "
    
    /// playsound
    static let categoryPlaySound =                      "PlaySound                     "
    
    /// healthkit manager
    static let categoryHealthKitManager =               "HealthKitManager              "
    
    /// SettingsViewHealthKitSettingsViewModel
    static let categorySettingsViewHealthKitSettingsViewModel = "SettingsViewHealthKitSettingsViewModel"
    
    /// dexcom share upload manager
    static let categoryDexcomShareUploadManager =       "DexcomShareUploadManager      "
    
    /// droplet 1
    static let categoryCGMDroplet1 =                    "CGMDroplet1                   "
    
    /// bluereader
    static let categoryCGMBlueReader =                  "CGMBlueReader                 "
    
    /// atom
    static let categoryCGMAtom =                        "categoryCGMAtom               "
    
    /// LibreOOPClient
    static let categoryLibreOOPClient =                 "LibreOOPClient                "
    
    /// libreDataParser
    static let categoryLibreDataParser =                "LibreDataParser               "
    
    /// for use in M5Stack
    static let categoryM5StackBluetoothTransmitter =    "M5StackBluetoothTransmitter   "
    
    /// BluetoothPeripheralManager logging
    static let categoryBluetoothPeripheralManager =     "BluetoothPeripheralManager    "

    /// StatusChartsManager logging
    static let categoryGlucoseChartManager =            "GlucoseChartManager           "
    
    /// SettingsViewCalendarEventsSettingsViewModel logging
    static let categorySettingsViewCalendarEventsSettingsViewModel =         "SettingsViewCalendarEventsSettingsViewModel"
    
    /// CalendarManager logging
    static let categoryCalendarManager =                "CalendarManager               "

    /// SettingsViewContactImageSettingsViewModel logging
    static let categorySettingsViewContactImageSettingsViewModel =           "SettingsViewContactImageSettingsViewModel  "

    /// WatchManager logging
    static let categoryWatchManager =                   "WatchManager                  "

    /// ContactImageManager logging
    static let categoryContactImageManager =            "ContactImageManager           "

    /// bluetoothPeripheralViewController
    static let categoryBluetoothPeripheralViewController =   "blePeripheralViewController   "
    
    /// nightscout view model
    static let categoryNightscoutSettingsViewModel =    "nightscoutSettingsViewModel   "
    
    /// trace
    static let categoryTraceSettingsViewModel =         "TraceSettingsViewModel"
    
    /// housekeeping
    static let categoryHouseKeeper =                    "HouseKeeper                   "
    
    /// soonzeParameter accessor
    static let categoryApplicationDataSnoozeParameter = "ApplicationDataSnoozeParameter"
    
    /// libre NFC
    static let categoryLibreNFC =                       "categoryLibreNFC"
    
    /// for use in cgm transmitter bubble
    static let categoryLibreSensorType =             "categoryLibreSensorType       "

    /// for use in Libre2BLEUtilities
    static let categoryLibre2BLEUtilities =             "Libre2BLEUtilities       "

    /// for use in Libre2BLEUtilities
    static let categoryAppDelegate =                            "AppDelegate              "
	
	/// for use in DataExporter
	static let categoryDataExporter =                           "DataExporter             "

    // for use in LoopManager
    static let categoryLoopManager =                            "LoopManager               "
    
    /// for use in Bg Readings view
    static let categoryBgReadingsView =                         "BgReadingsView           "
    
    /// SettingsViewCalendarEventsSettingsViewModel logging
    static let categorySettingsViewDataSourceSettingsViewModel =         "SettingsViewDataSourceSettingsViewModel"
    
    /// SettingsViewNotificationsSettingsViewModel logging
    static let categorySettingsViewNotificationsSettingsViewModel =
                                                     "NotificationsViewModel      "

    /// for use in LiveActivityManager
    static let categoryLiveActivityManager =         "LiveActivityManager           "
    
    /// for use in Libre3HeartBeatTransmitter
    static let categoryHeartBeatLibre3 =                       "HeartBeatLibre3          "
    
    /// for use in DexcomG7HeartBeatTransmitter
    static let categoryHeartBeatG7 =                           "HeartBeatG7              "
    
    /// for use in LibreViewFollowManager
    static let categoryLoopFollowManager =                     "LoopFollowManager        "
    
    /// for use in Omni¨PodHeartBeatTransmitter
    static let categoryHeartBeatOmnipod =                      "HeartBeatOmnipod         "
}

