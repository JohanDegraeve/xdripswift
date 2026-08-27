import Foundation

/// all texts related to calibration
enum Texts_HomeView {
    static private let filename = "HomeView"

    static let expandChart: String = {
        return NSLocalizedString("home_expandChart", tableName: filename, bundle: Bundle.main, value: "Expand chart", comment: "accessibility label for the iPad full screen chart button")
    }()
    
    static let snoozeButton:String = {
        return NSLocalizedString("presnooze", tableName: filename, bundle: Bundle.main, value: "Snooze", comment: "Text in button on home screen")
    }()

    static let snoozeAllTitle:String = {
        return NSLocalizedString("snoozeAllTitle", tableName: filename, bundle: Bundle.main, value: "Snooze All Alarms", comment: "snooze all text in snooze screen")
    }()

    static let snoozeAllDisabled:String = {
        return NSLocalizedString("snoozeAllDisabled", tableName: filename, bundle: Bundle.main, value: "No urgent alarms are snoozed", comment: "no urgent alarms are snoozed text in snooze screen")
    }()
    
    static let snoozeAllSnoozed:String = {
        return NSLocalizedString("snoozeAllSnoozed", tableName: filename, bundle: Bundle.main, value: "All alarms are snoozed!", comment: "snooze all text in snooze screen")
    }()
    
    static let snoozeAllSnoozedUntil:String = {
        return NSLocalizedString("snoozeAllSnoozedUntil", tableName: filename, bundle: Bundle.main, value: "All alarms are snoozed until", comment: "snooze all until text in snooze screen")
    }()
    
    static let snoozeUrgentAlarms:String = {
        return NSLocalizedString("snoozeUrgentAlarms", tableName: filename, bundle: Bundle.main, value: "Some urgent alarms are snoozed", comment: "text to inform that some of the urgent alarms are snoozed")
    }()
    
    static let sensor:String = {
        return NSLocalizedString("sensor", tableName: filename, bundle: Bundle.main, value: "Sensor", comment: "Literally 'Sensor', used as name in the button in the home screen, but also in text in pop ups")
    }()
    
    static let calibrationButton:String = {
        return NSLocalizedString("calibrate", tableName: filename, bundle: Bundle.main, value: "Calibrate", comment: "Text in button on home screen")
    }()

    static let sensorManagementTitle:String = {
        return NSLocalizedString("sensorManagementTitle", tableName: filename, bundle: Bundle.main, value: "Sensor", comment: "navigation title for the sensor management screen")
    }()

    static let sensorManagementSummaryTitle:String = {
        return NSLocalizedString("sensorManagementSummaryTitle", tableName: filename, bundle: Bundle.main, value: "Sensor Session", comment: "section title for sensor information")
    }()

    static let sensorManagementNoiseTitle:String = {
        return NSLocalizedString("sensorManagementNoiseTitle", tableName: filename, bundle: Bundle.main, value: "Sensor Noise", comment: "section title for sensor signal noise information")
    }()

    static let sensorManagementNoiseShortTerm:String = {
        return NSLocalizedString("sensorManagementNoiseShortTerm", tableName: filename, bundle: Bundle.main, value: "Last 30 Minutes", comment: "title for the short-term sensor noise measurement")
    }()

    static let sensorManagementNoiseLongTerm:String = {
        return NSLocalizedString("sensorManagementNoiseLongTerm", tableName: filename, bundle: Bundle.main, value: "Last 4 Hours", comment: "title for the long-term sensor noise measurement")
    }()

    static let sensorManagementNoiseCollecting:String = {
        return NSLocalizedString("sensorManagementNoiseCollecting", tableName: filename, bundle: Bundle.main, value: "Collecting data", comment: "sensor noise state while there are not enough readings")
    }()

    static let sensorManagementNoiseLow:String = {
        return NSLocalizedString("sensorManagementNoiseLow", tableName: filename, bundle: Bundle.main, value: "Low", comment: "low sensor noise state")
    }()

    static let sensorManagementNoiseElevated:String = {
        return NSLocalizedString("sensorManagementNoiseElevated", tableName: filename, bundle: Bundle.main, value: "Elevated", comment: "elevated sensor noise state")
    }()

    static let sensorManagementNoiseVeryHigh:String = {
        return NSLocalizedString("sensorManagementNoiseVeryHigh", tableName: filename, bundle: Bundle.main, value: "Very High", comment: "very high sensor noise state")
    }()

    static let sensorManagementNoiseExtreme:String = {
        return NSLocalizedString("sensorManagementNoiseExtreme", tableName: filename, bundle: Bundle.main, value: "Extreme", comment: "extreme sensor noise state")
    }()

    static let sensorManagementNoiseFlatline:String = {
        return NSLocalizedString("sensorManagementNoiseFlatline", tableName: filename, bundle: Bundle.main, value: "The sensor has likely failed.", comment: "warning that repeated identical sensor readings probably indicate sensor failure")
    }()

    static let sensorNoiseHistoryTitle:String = {
        return NSLocalizedString("sensorNoiseHistoryTitle", tableName: filename, bundle: Bundle.main, value: "Noise History", comment: "navigation title for sensor noise history")
    }()

    static let sensorNoiseHistoryCurrentTitle:String = {
        return NSLocalizedString("sensorNoiseHistoryCurrentTitle", tableName: filename, bundle: Bundle.main, value: "Current Measurements", comment: "section title for current sensor noise measurements")
    }()

    static let sensorNoiseHistoryChartTitle:String = {
        return NSLocalizedString("sensorNoiseHistoryChartTitle", tableName: filename, bundle: Bundle.main, value: "Noise Over Time", comment: "title for the sensor noise history chart")
    }()

    static let sensorNoiseHistoryRangeTitle:String = {
        return NSLocalizedString("sensorNoiseHistoryRangeTitle", tableName: filename, bundle: Bundle.main, value: "Time Range", comment: "accessibility title for the sensor noise chart range picker")
    }()

    static let sensorNoiseHistoryDayRange:String = {
        return NSLocalizedString("sensorNoiseHistoryDayRange", tableName: filename, bundle: Bundle.main, value: "1d", comment: "one day sensor noise chart range")
    }()

    static let sensorNoiseHistoryThreeDayRange:String = {
        return NSLocalizedString("sensorNoiseHistoryThreeDayRange", tableName: filename, bundle: Bundle.main, value: "3d", comment: "three day sensor noise chart range")
    }()

    static let sensorNoiseHistoryWeekRange:String = {
        return NSLocalizedString("sensorNoiseHistoryWeekRange", tableName: filename, bundle: Bundle.main, value: "7d", comment: "one week sensor noise chart range")
    }()

    static let sensorNoiseHistoryAllRange:String = {
        return NSLocalizedString("sensorNoiseHistoryAllRange", tableName: filename, bundle: Bundle.main, value: "All", comment: "complete sensor session noise chart range")
    }()

    static let sensorNoiseHistoryShortCompact:String = {
        return NSLocalizedString("sensorNoiseHistoryShortCompact", tableName: filename, bundle: Bundle.main, value: "30 min", comment: "compact label for short-term sensor noise")
    }()

    static let sensorNoiseHistoryLongCompact:String = {
        return NSLocalizedString("sensorNoiseHistoryLongCompact", tableName: filename, bundle: Bundle.main, value: "4 h", comment: "compact label for long-term sensor noise")
    }()

    static let sensorNoiseHistoryPersistentCompact: String = {
        return NSLocalizedString(
            "sensorNoiseHistoryPersistentCompact",
            tableName: filename,
            bundle: Bundle.main,
            value: "12 h",
            comment: "compact label for the rolling twelve-hour sensor noise median"
        )
    }()

    static let sensorManagementNoisePersistent: String = {
        return NSLocalizedString(
            "sensorManagementNoisePersistent",
            tableName: filename,
            bundle: Bundle.main,
            value: "Last 12 Hours",
            comment: "sensor noise history row title for the rolling twelve-hour median"
        )
    }()

    static let sensorNoiseHistoryLoading:String = {
        return NSLocalizedString("sensorNoiseHistoryLoading", tableName: filename, bundle: Bundle.main, value: "Building sensor history", comment: "message while historic sensor noise is calculated")
    }()

    static let sensorNoiseHistoryNoDataTitle:String = {
        return NSLocalizedString("sensorNoiseHistoryNoDataTitle", tableName: filename, bundle: Bundle.main, value: "Not enough noise data yet", comment: "title when the sensor noise chart has no measurements")
    }()

    static let sensorNoiseHistoryNoDataMessage:String = {
        return NSLocalizedString("sensorNoiseHistoryNoDataMessage", tableName: filename, bundle: Bundle.main, value: "The chart will appear after enough sensor readings have been collected.", comment: "explanation when the sensor noise chart has no measurements")
    }()

    static let sensorNoiseHistoryFooter:String = {
        return NSLocalizedString(
            "sensorNoiseHistoryFooter",
            tableName: filename,
            bundle: Bundle.main,
            value: "The chart shows 30-minute jitter, the rolling 4-hour value and the 12-hour median "
                + "used for persistent-noise warnings. Lower values are smoother. It does not measure glucose accuracy.",
            comment: "explanation below the sensor noise history chart"
        )
    }()

    static let sensorNoiseHistoryChartAccessibility:String = {
        return NSLocalizedString("sensorNoiseHistoryChartAccessibility", tableName: filename, bundle: Bundle.main, value: "Sensor noise history chart", comment: "accessibility label for the sensor noise history chart")
    }()

    static let sensorNoiseWarningExtremeTitle:String = {
        return NSLocalizedString("sensorNoiseWarningExtremeTitle", tableName: filename, bundle: Bundle.main, value: "Extreme Sensor Noise", comment: "home screen warning title for extreme short-term sensor noise")
    }()

    static let sensorNoiseWarningPersistentTitle:String = {
        return NSLocalizedString("sensorNoiseWarningPersistentTitle", tableName: filename, bundle: Bundle.main, value: "Persistent Sensor Noise", comment: "home screen warning title for high long-term sensor noise")
    }()

    static let sensorNoiseWarningFlatlineTitle:String = {
        return NSLocalizedString("sensorNoiseWarningFlatlineTitle", tableName: filename, bundle: Bundle.main, value: "Sensor Signal Is Flat", comment: "home screen warning title for repeated identical sensor values")
    }()

    static let sensorHealthPersistentNoiseTitle: String = {
        return NSLocalizedString(
            "sensorHealthPersistentNoiseTitle",
            tableName: filename,
            bundle: Bundle.main,
            value: "Very High Sensor Noise",
            comment: "sensor health banner title after twelve hours of sustained very high noise"
        )
    }()

    static let sensorHealthPersistentNoiseGuidance: String = {
        return NSLocalizedString(
            "sensorHealthPersistentNoiseGuidance",
            tableName: filename,
            bundle: Bundle.main,
            value: "Very high noise for 12 hours. Consider replacing the sensor if it continues.",
            comment: "compact sensor health guidance for sustained calculated sensor noise"
        )
    }()

    static let sensorHealthFlatlineTitle: String = {
        return NSLocalizedString(
            "sensorHealthFlatlineTitle",
            tableName: filename,
            bundle: Bundle.main,
            value: "Sensor Signal Is Flat",
            comment: "sensor health banner title for repeated identical sensor values"
        )
    }()

    static let sensorHealthFlatlineGuidance: String = {
        return NSLocalizedString(
            "sensorHealthFlatlineGuidance",
            tableName: filename,
            bundle: Bundle.main,
            value: "Readings unchanged for 30 minutes. This usually indicates that the sensor has failed/expired.",
            comment: "compact sensor health guidance for suspected flatline readings"
        )
    }()

    static let sensorHealthTemporaryIssueTitle: String = {
        return NSLocalizedString(
            "sensorHealthTemporaryIssueTitle",
            tableName: filename,
            bundle: Bundle.main,
            value: "Temporary Sensor Issue",
            comment: "sensor health banner title for a transmitter temporary issue lasting three hours"
        )
    }()

    static let sensorHealthTemporaryIssueGuidance: String = {
        return NSLocalizedString(
            "sensorHealthTemporaryIssueGuidance",
            tableName: filename,
            bundle: Bundle.main,
            value: "Temporary sensor issue for 3 hours. Check with a meter and follow manufacturer guidance.",
            comment: "compact sensor health guidance for a temporary transmitter status"
        )
    }()

    static let sensorHealthSensorFailedTitle: String = {
        return NSLocalizedString(
            "sensorHealthSensorFailedTitle",
            tableName: filename,
            bundle: Bundle.main,
            value: "Sensor Failed",
            comment: "sensor health banner title for a transmitter-confirmed sensor failure"
        )
    }()

    static let sensorHealthSensorFailedGuidance: String = {
        return NSLocalizedString(
            "sensorHealthSensorFailedGuidance",
            tableName: filename,
            bundle: Bundle.main,
            value: "Sensor failure reported. Replace the sensor.",
            comment: "compact sensor health guidance for a transmitter-confirmed sensor failure"
        )
    }()

    static let sensorHealthTransmitterFailedTitle: String = {
        return NSLocalizedString(
            "sensorHealthTransmitterFailedTitle",
            tableName: filename,
            bundle: Bundle.main,
            value: "Transmitter Failure",
            comment: "sensor health banner title for a terminal transmitter failure"
        )
    }()

    static let sensorHealthTransmitterFailedGuidance: String = {
        return NSLocalizedString(
            "sensorHealthTransmitterFailedGuidance",
            tableName: filename,
            bundle: Bundle.main,
            value: "Transmitter failure reported. Check or replace it.",
            comment: "compact sensor health guidance for a terminal transmitter failure"
        )
    }()

    static let sensorHealthTestPersistentNoise: String = {
        return NSLocalizedString(
            "sensorHealthTestPersistentNoise",
            tableName: filename,
            bundle: Bundle.main,
            value: "Test Persistent Noise in 5 Seconds",
            comment: "hidden Home context-menu action that queues a persistent sensor noise test warning"
        )
    }()

    static let sensorHealthTestFlatline: String = {
        return NSLocalizedString(
            "sensorHealthTestFlatline",
            tableName: filename,
            bundle: Bundle.main,
            value: "Test Flat Signal in 5 Seconds",
            comment: "hidden Home context-menu action that queues a flat sensor signal test warning"
        )
    }()

    static let sensorHealthTestTemporaryIssue: String = {
        return NSLocalizedString(
            "sensorHealthTestTemporaryIssue",
            tableName: filename,
            bundle: Bundle.main,
            value: "Test Temporary Issue in 5 Seconds",
            comment: "hidden Home context-menu action that queues a temporary sensor issue warning"
        )
    }()

    static let sensorHealthTestSensorFailure: String = {
        return NSLocalizedString(
            "sensorHealthTestSensorFailure",
            tableName: filename,
            bundle: Bundle.main,
            value: "Test Sensor Failure in 5 Seconds",
            comment: "hidden Home context-menu action that queues a sensor failure alarm"
        )
    }()

    static let sensorHealthTestTransmitterFailure: String = {
        return NSLocalizedString(
            "sensorHealthTestTransmitterFailure",
            tableName: filename,
            bundle: Bundle.main,
            value: "Test Transmitter Failure in 5 Seconds",
            comment: "hidden Home context-menu action that queues a transmitter failure alarm"
        )
    }()

    static let sensorManagementActionsTitle:String = {
        return NSLocalizedString("sensorManagementActionsTitle", tableName: filename, bundle: Bundle.main, value: "Sensor Actions", comment: "section title for sensor management actions")
    }()

    static let sensorManagementCalibrationTitle:String = {
        return NSLocalizedString("sensorManagementCalibrationTitle", tableName: filename, bundle: Bundle.main, value: "Calibration", comment: "section title for sensor calibration information")
    }()

    static let sensorManagementHistoryTitle:String = {
        return NSLocalizedString("sensorManagementHistoryTitle", tableName: filename, bundle: Bundle.main, value: "Calibration History", comment: "section title for calibration history")
    }()

    static let sensorManagementNotAvailableInFollower:String = {
        return NSLocalizedString("sensorManagementNotAvailableInFollower", tableName: filename, bundle: Bundle.main, value: "Sensor management is unavailable in follower mode.", comment: "message shown when sensor management is not available in follower mode")
    }()

    static let sensorManagementAutomaticSessionNote:String = {
        return NSLocalizedString("sensorManagementAutomaticSessionNote", tableName: filename, bundle: Bundle.main, value: "This sensor manages its session automatically, so manual start and stop are unavailable.", comment: "message shown when a sensor manages its own session")
    }()

    static let sensorManagementNoTransmitterNote:String = {
        return NSLocalizedString("sensorManagementNoTransmitterNote", tableName: filename, bundle: Bundle.main, value: "Connect a CGM transmitter to manage the sensor session.", comment: "message shown when no transmitter is available for sensor management")
    }()

    static let sensorManagementCalibrationUnavailable:String = {
        return NSLocalizedString("sensorManagementCalibrationUnavailable", tableName: filename, bundle: Bundle.main, value: "Calibration is temporarily unavailable.", comment: "generic error shown when calibration cannot be performed")
    }()

    static let sensorManagementStatusActive:String = {
        return NSLocalizedString("sensorManagementStatusActive", tableName: filename, bundle: Bundle.main, value: "Sensor Active", comment: "sensor management status label")
    }()

    static let sensorManagementStatusWarmingUp:String = {
        return NSLocalizedString("sensorManagementStatusWarmingUp", tableName: filename, bundle: Bundle.main, value: "Warming Up", comment: "sensor management status label")
    }()

    static let sensorManagementStatusExpired:String = {
        return NSLocalizedString("sensorManagementStatusExpired", tableName: filename, bundle: Bundle.main, value: "Expired", comment: "sensor management status label")
    }()

    static let sensorManagementStatusNotStarted:String = {
        return NSLocalizedString("sensorManagementStatusNotStarted", tableName: filename, bundle: Bundle.main, value: "Not Started", comment: "sensor management status label")
    }()

    static let sensorManagementNoSensor:String = {
        return NSLocalizedString("sensorManagementNoSensor", tableName: filename, bundle: Bundle.main, value: "No Sensor", comment: "banner title when no sensor session is active")
    }()

    static let sensorManagementCGMType: String = {
        return NSLocalizedString("sensorManagementCGMType", tableName: filename, bundle: Bundle.main, value: "CGM Type", comment: "sensor management row title for CGM type")
    }()

    static let sensorManagementElapsed:String = {
        return NSLocalizedString("sensorManagementElapsed", tableName: filename, bundle: Bundle.main, value: "Elapsed", comment: "sensor management row title")
    }()

    static let sensorManagementRemaining:String = {
        return NSLocalizedString("sensorManagementRemaining", tableName: filename, bundle: Bundle.main, value: "Remaining", comment: "sensor management row title")
    }()

    static let sensorManagementSessionLifetime: String = {
        return NSLocalizedString("sensorManagementSessionLifetime", tableName: filename, bundle: Bundle.main, value: "Elapsed / Remaining", comment: "sensor management row title for compact elapsed and remaining lifetime")
    }()

    static let sensorManagementSessionDetails: String = {
        return NSLocalizedString("sensorManagementSessionDetails", tableName: filename, bundle: Bundle.main, value: "Session Details", comment: "sensor management button and alert title for full sensor session dates")
    }()

    static let sensorManagementStarted: String = {
        return NSLocalizedString("sensorManagementStarted", tableName: filename, bundle: Bundle.main, value: "Started", comment: "sensor management session details label for sensor start date")
    }()

    static let sensorManagementEnds: String = {
        return NSLocalizedString("sensorManagementEnds", tableName: filename, bundle: Bundle.main, value: "Ends", comment: "sensor management session details label for sensor end date")
    }()

    static let sensorManagementCalibrationOpenTitle: String = {
        return NSLocalizedString("sensorManagementCalibrationOpenTitle", tableName: filename, bundle: Bundle.main, value: "Calibration Details", comment: "sensor management row title that opens calibration details")
    }()

    static let sensorManagementLastCalibration: String = {
        return NSLocalizedString("sensorManagementLastCalibration", tableName: filename, bundle: Bundle.main, value: "Last", comment: "sensor management row title for the latest calibration date")
    }()

    static let sensorManagementExpiryFooterFormat:String = {
        return NSLocalizedString("sensorManagementExpiryFooterFormat", tableName: filename, bundle: Bundle.main, value: "Sensor expires on %@", comment: "footer text shown in sensor session when an expiry date is known")
    }()

    static let sensorManagementCurrentCalibrationTitle:String = {
        return NSLocalizedString("sensorManagementCurrentCalibrationTitle", tableName: filename, bundle: Bundle.main, value: "Current Calibration", comment: "title for the current calibration subsection")
    }()

    static let sensorManagementHistoricCalibration:String = {
        return NSLocalizedString("sensorManagementHistoricCalibration", tableName: filename, bundle: Bundle.main, value: "Historic", comment: "label for a historic or unused calibration")
    }()

    static let pumpBattery: String = {
        return NSLocalizedString("pumpBattery", tableName: filename, bundle: Bundle.main, value: "Battery", comment: "pump status view, insulin pump battery level label")
    }()

    static let pumpReservoir: String = {
        return NSLocalizedString("pumpReservoir", tableName: filename, bundle: Bundle.main, value: "Reservoir", comment: "pump status view, insulin pump reservoir amount label")
    }()

    static let sensorManagementCalibrationSafetyFooter:String = {
        return NSLocalizedString("sensorManagementCalibrationSafetyFooter", tableName: filename, bundle: Bundle.main, value: "Only calibrate if you understand how to do it safely.", comment: "safety text shown in the calibration entry screen")
    }()

    static let sensorManagementCalibrationValue: String = {
        return NSLocalizedString("sensorManagementCalibrationValue", tableName: filename, bundle: Bundle.main, value: "Calibration Value", comment: "calibration readiness row title for the entered fingerstick value")
    }()

    static let sensorManagementCalibrationPending: String = {
        return NSLocalizedString("sensorManagementCalibrationPending", tableName: filename, bundle: Bundle.main, value: "Pending...", comment: "calibration readiness detail before a valid fingerstick value is entered")
    }()

    static let sensorManagementCalibrationStableTrend: String = {
        return NSLocalizedString("sensorManagementCalibrationStableTrend", tableName: filename, bundle: Bundle.main, value: "Stable trend", comment: "calibration readiness row checking whether glucose has been stable")
    }()

    static let sensorManagementCalibrationSlightlyLow: String = {
        return NSLocalizedString("sensorManagementCalibrationSlightlyLow", tableName: filename, bundle: Bundle.main, value: "Slightly Low", comment: "calibration readiness detail when glucose is slightly below the preferred calibration range")
    }()

    static let sensorManagementCalibrationSlightlyHigh: String = {
        return NSLocalizedString("sensorManagementCalibrationSlightlyHigh", tableName: filename, bundle: Bundle.main, value: "Slightly High", comment: "calibration readiness detail when glucose is slightly above the preferred calibration range")
    }()

    static let sensorManagementCalibrationNoReading: String = {
        return NSLocalizedString("sensorManagementCalibrationNoReading", tableName: filename, bundle: Bundle.main, value: "No Reading", comment: "calibration readiness detail when no current glucose reading is available")
    }()

    static let sensorManagementCalibrationGood: String = {
        return NSLocalizedString("sensorManagementCalibrationGood", tableName: filename, bundle: Bundle.main, value: "Good", comment: "calibration readiness detail when the glucose level is suitable")
    }()

    static let sensorManagementCalibrationNoTrend: String = {
        return NSLocalizedString("sensorManagementCalibrationNoTrend", tableName: filename, bundle: Bundle.main, value: "No Trend", comment: "calibration readiness detail when no glucose trend is available")
    }()

    static let sensorManagementCalibrationStale: String = {
        return NSLocalizedString("sensorManagementCalibrationStale", tableName: filename, bundle: Bundle.main, value: "Stale", comment: "calibration readiness detail when the latest glucose reading is too old")
    }()

    static let sensorManagementCalibrationStable: String = {
        return NSLocalizedString("sensorManagementCalibrationStable", tableName: filename, bundle: Bundle.main, value: "Stable", comment: "calibration readiness detail when glucose has been stable")
    }()

    static let sensorManagementCalibrationFallingFast: String = {
        return NSLocalizedString("sensorManagementCalibrationFallingFast", tableName: filename, bundle: Bundle.main, value: "Falling Fast", comment: "calibration readiness detail when glucose is falling quickly")
    }()

    static let sensorManagementCalibrationFalling: String = {
        return NSLocalizedString("sensorManagementCalibrationFalling", tableName: filename, bundle: Bundle.main, value: "Falling", comment: "calibration readiness detail when glucose is falling")
    }()

    static let sensorManagementCalibrationRisingFast: String = {
        return NSLocalizedString("sensorManagementCalibrationRisingFast", tableName: filename, bundle: Bundle.main, value: "Rising Fast", comment: "calibration readiness detail when glucose is rising quickly")
    }()

    static let sensorManagementCalibrationRising: String = {
        return NSLocalizedString("sensorManagementCalibrationRising", tableName: filename, bundle: Bundle.main, value: "Rising", comment: "calibration readiness detail when glucose is rising")
    }()

    static let sensorManagementCalibrationFlatline: String = {
        return NSLocalizedString("sensorManagementCalibrationFlatline", tableName: filename, bundle: Bundle.main, value: "Flatline", comment: "calibration readiness detail when identical sensor readings suggest a flatline")
    }()

    static let sensorManagementCalibrationBG: String = {
        return NSLocalizedString("sensorManagementCalibrationBG", tableName: filename, bundle: Bundle.main, value: "BG", comment: "calibration history row title for the calibrated blood glucose value")
    }()

    static let sensorManagementCalibrationRaw: String = {
        return NSLocalizedString("sensorManagementCalibrationRaw", tableName: filename, bundle: Bundle.main, value: "Raw", comment: "calibration history row title for the raw sensor value")
    }()

    static let sensorManagementCalibrationSlope: String = {
        return NSLocalizedString("sensorManagementCalibrationSlope", tableName: filename, bundle: Bundle.main, value: "Slope", comment: "calibration history row title for the calibration slope")
    }()

    static let sensorManagementCalibrationIntercept: String = {
        return NSLocalizedString("sensorManagementCalibrationIntercept", tableName: filename, bundle: Bundle.main, value: "Intercept", comment: "calibration history row title for the calibration intercept")
    }()

    static let sensorManagementCalibrationReadinessBad: String = {
        return NSLocalizedString("sensorManagementCalibrationReadinessBad", tableName: filename, bundle: Bundle.main, value: "Calibration is unlikely to be accurate at this time. Please wait.", comment: "calibration readiness footer when conditions are unsuitable")
    }()

    static let sensorManagementCalibrationReadinessCaution: String = {
        return NSLocalizedString("sensorManagementCalibrationReadinessCaution", tableName: filename, bundle: Bundle.main, value: "Calibration may be less reliable. Waiting may be better.", comment: "calibration readiness footer when conditions are not ideal")
    }()

    static let sensorManagementCalibrationReadinessGood: String = {
        return NSLocalizedString("sensorManagementCalibrationReadinessGood", tableName: filename, bundle: Bundle.main, value: "Now is a good time to calibrate.", comment: "calibration readiness footer when conditions are suitable")
    }()

    static let sensorManagementCalibrationHelp:String = {
        return NSLocalizedString("sensorManagementCalibrationHelp", tableName: filename, bundle: Bundle.main, value: "Calibration Help", comment: "button title to open the calibration help documentation")
    }()

    static let sensorManagementLargeCalibrationDifferenceWarningFormat:String = {
        return NSLocalizedString(
            "sensorManagementLargeCalibrationDifferenceWarningFormat",
            tableName: filename,
            bundle: Bundle.main,
            value: "It is possible that this calibration will not work. Try to limit each calibration change to maximum %@ at a time.",
            comment: "warning shown when the entered calibration differs too much from the current glucose value. Placeholder is a localized glucose amount with unit"
        )
    }()
    
    static let lockButton:String = {
        return NSLocalizedString("lock", tableName: filename, bundle: Bundle.main, value: "Lock", comment: "Text in button on home screen")
    }()
    
    static let unlockButton:String = {
        return NSLocalizedString("unlock", tableName: filename, bundle: Bundle.main, value: "Unlock", comment: "Text in button on home screen")
    }()
    
    static let screenLockTitle:String = {
        return NSLocalizedString("screenlocktitle", tableName: filename, bundle: Bundle.main, value: "Screen Lock Enabled", comment: "Screen Lock Title")
    }()
    
    static let screenLockInfo:String = {
        return NSLocalizedString("screenlockinfo", tableName: filename, bundle: Bundle.main, value: "This will keep the screen awake until you move to another app or click Unlock.\r\n\nIt is recommended that you keep the phone plugged into a charger to prevent battery drain.", comment: "Info message to explain screen lock function")
    }()
    
    static let statusActionTitle:String = {
        return NSLocalizedString("statusactiontitle", tableName: filename, bundle: Bundle.main, value: "Status", comment: "when user clicks transmitterButton, this is the first action, to show the status")
    }()
    
    static let scanBluetoothDeviceActionTitle:String = {
        return NSLocalizedString("scanbluetoothdeviceactiontitle", tableName: filename, bundle: Bundle.main, value: "Scan for Transmitter", comment: "when user clicks transmitterButton, this is the action to start scanning")
    }()
    
    static let forgetBluetoothDeviceActionTitle:String = {
        return NSLocalizedString("forgetbluetoothdeviceactiontitle", tableName: filename, bundle: Bundle.main, value: "Forget Transmitter", comment: "when user clicks transmitterButton, this is the action to forget the device, so that user can scan for a new device, in case user switches device")
    }()
    
    static let startSensorActionTitle:String = {
        return NSLocalizedString("startsensor", tableName: filename, bundle: Bundle.main, value: "Start Sensor", comment: "when user clicks transmitterButton, this is the action to start the sensor")
    }()
    
    static let stopSensorActionTitle:String = {
        return NSLocalizedString("stopsensor", tableName: filename, bundle: Bundle.main, value: "Stop Sensor", comment: "when user clicks transmitterButton, this is the action to stop the sensor")
    }()
    
    static let startSensorTimeInfo:String = {
        return NSLocalizedString("startsensortimeinfo", tableName: filename, bundle: Bundle.main, value: "In the next dialogs, you will need to set the date and time the sensor was inserted. It is important that you set the date and time as accurately as possible.", comment: "when user manually starts sensor, this is the message that explains that time should be correct")
    }()
    
    static let scanBluetoothDeviceOngoing:String = {
        return NSLocalizedString("scanbluetoothdeviceongoing", tableName: filename, bundle: Bundle.main, value: "Scanning for Transmitter...", comment: "when user manually starts scanning, this is the message that scanning is ongoing")
    }()
    
    static let bluetoothIsNotOn:String = {
        return NSLocalizedString("bluetoothisnoton", tableName: filename, bundle: Bundle.main, value: "Bluetooth is not on. Switch on bluetooth first and then try again.", comment: "when user starts scanning but bluetooth is not on")
    }()
    
    static let bluetoothIsNotAuthorized: String = {
        return String(format: NSLocalizedString("bluetoothIsNotAuthorized", tableName: filename, bundle: Bundle.main, value: "You did not give bluetooth permission for %@. Go to the settings, find the %@ app, and enable Bluetooth.", comment: "when user starts scanning for bluetooth device, but bluetooth is not authorized"), ConstantsHomeView.applicationName, ConstantsHomeView.applicationName)
    }()
    
    static let startScanningInfo: String = {
        return String(format: NSLocalizedString("startScanningInfo", tableName: filename, bundle: Bundle.main, value: "Scanning Started.\n\nKeep %@ open in the foreground until a connection is made.\n\n(There's no need to turn off Auto-Lock. Just don't press the home button and don't lock your iPhone)", comment: "After clicking scan button, this message will appear"), ConstantsHomeView.applicationName)
    }()
   
    static let sensorStart:String = {
        return NSLocalizedString("sensorstart", tableName: filename, bundle: Bundle.main, value: "Sensor Started", comment: "status info : literally 'Sensor Start'")
    }()
    
    static let sensorDuration:String = {
        return NSLocalizedString("sensorDuration", tableName: filename, bundle: Bundle.main, value: "Sensor Duration", comment: "status info : literally 'Sensor Duration'")
    }()

    static let sensorEnd:String = {
        return NSLocalizedString("sensorend", tableName: filename, bundle: Bundle.main, value: "Sensor End", comment: "status info : literally 'Sensor End'")
    }()
    
    static let sensorRemaining:String = {
        return NSLocalizedString("sensorRemaining", tableName: filename, bundle: Bundle.main, value: "Sensor Remaining", comment: "status info : literally 'Sensor Remaining'")
    }()
    
    static let notStarted:String = {
        return NSLocalizedString("notstarted", tableName: filename, bundle: Bundle.main, value: "Not Started", comment: "status info : literally 'not started', used if sensor is not started")
    }()
    
    static let notKnown:String = {
        return NSLocalizedString("notknown", tableName: filename, bundle: Bundle.main, value: "Not Known", comment: "status info : literally 'not known', used if transmitter name is not known")
    }()

    static let lastConnection:String = {
        return NSLocalizedString("lastconnection", tableName: filename, bundle: Bundle.main, value: "Last Connection", comment: "status info : literally 'Last connection', shows when the last connection to a transmitter occured")
    }()
    
    static let ago:String = {
        return NSLocalizedString("ago", tableName: filename, bundle: Bundle.main, value: "ago", comment: "for home view, where it say how old the reading is, 'x minutes ago', literaly translation of 'ago'")
    }()
    
    static let remaining: String = {
        return NSLocalizedString("remaining", tableName: filename, bundle: Bundle.main, value: "remaining", comment: "for home view, where it say how old much time is left, literaly translation of 'remaining'")
    }()

    // make sure any translations are short enough to display nicely in the Home view
    static func sensorLifetimeRemaining(_ duration: String) -> String {
        return String(format: NSLocalizedString("sensorLifetimeRemainingFormat", tableName: filename, bundle: Bundle.main, value: "%@ remaining", comment: "for home view, where it says how much sensor lifetime is left, %@ will be replaced by the remaining days and hours"), duration)
    }

    static let licenseInfo:String = {
        return String(format: NSLocalizedString("licenseinfo", tableName: filename, bundle: Bundle.main, value: "This program is free software distributed under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.\r\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY.\r\n\nSee http://www.gnu.org/licenses/gpl.txt for more details.\r\n\r\nInfo: ", comment: "for home view, license info"), ConstantsHomeView.applicationName, ConstantsHomeView.applicationName)
    }()

    static let info:String = {
        return NSLocalizedString("info", tableName: filename, bundle: Bundle.main, value: "Please Read", comment: "for home view, title of pop up that gives info about how to select the transmitter. Simply the word Info")
    }()
    
    static let transmitterInfo:String = {
        return NSLocalizedString("transmitterinfo", tableName: filename, bundle: Bundle.main, value: "First go to the Bluetooth screen where you can add and scan for your transmitter.\r\n\nThen come back to the Home screen and start your sensor.", comment: "for home view, Info how to start : set transmitter and id, then go back to home screen, start scanning")
    }()
    
    static let startSensorBeforeCalibration:String = {
        return NSLocalizedString("startsensorbeforecalibration", tableName: filename, bundle: Bundle.main, value: "You cannot calibrate unless you have started a sensor.", comment: "for home view, user clicks calibrate but there's no sensor started yet")
    }()
    
    static let theresNoCGMTransmitterActive:String = {
        return NSLocalizedString("theresNoCGMTransmitterActive", tableName: filename, bundle: Bundle.main, value: "You cannot calibrate unless you have a transmitter connected.", comment: "When user has no CGM transmitter created with 'Always connect', and tries to calibrate, then this message is shown")
    }()
    
    static let thereMustBeAreadingBeforeCalibration:String = {
        return NSLocalizedString("theremustbeareadingbeforecalibration", tableName: filename, bundle: Bundle.main, value: "There must be at least two readings before you can calibrate. You will be requested to calibrate as soon as there is another reading.", comment: "for home view, user clicks calibrate but there's no reading yet")
    }()
    
    static let sensorNotDetected:String = {
        return NSLocalizedString("sensornotdetected", tableName: filename, bundle: Bundle.main, value: "The sensor was not detected. Check if the Transmitter is correctly placed on the sensor.", comment: "for home view, miaomiao doesn't detect a sensor")
    }()
    
    static let transmitterNotPaired:String = {
        return NSLocalizedString("transmitternotpaired", tableName: filename, bundle: Bundle.main, value: "The Transmitter is not paired with this iPhone. Open the application.", comment: "If transmitter needs pairing, user needs to click the notification")
    }()
    
    static let transmitterPairingTooLate:String = {
        return NSLocalizedString("transmitterpairingtoolate", tableName: filename, bundle: Bundle.main, value: "Too late! The Transmitter has already been disconnected. You should get a new pairing request in a few minutes.", comment: "If transmitter needs pairing, a notification was fired, user clicked it more than 60 seconds later, which is too late")
    }()

    static let transmitterPairingSuccessful:String = {
        return NSLocalizedString("transmitterpairingsuccessful", tableName: filename, bundle: Bundle.main, value: "The Transmitter was successfully paired.", comment: "To give info to user that the transmitter is successfully paired")
    }()
    
    static let transmitterPairingAttemptTimeout:String = {
        return NSLocalizedString("transmitterpairingattempttimeout", tableName: filename, bundle: Bundle.main, value: "Transmitter did not reply to pairing request.", comment: "To give info to user that the transmitter pairing requeset timed out")
    }()
    
    static let success:String = {
        return NSLocalizedString("success", tableName: filename, bundle: Bundle.main, value: "Success", comment: "To give result about transitter result in notification body, successful")
    }()
    
    static let failed:String = {
        return NSLocalizedString("failed", tableName: filename, bundle: Bundle.main, value: "Failed", comment: "To give result about transitter result in notification body, failed")
    }()
    
    static let calibrationNotNecessary:String = {
        return NSLocalizedString("calibrationNotNecessary", tableName: filename, bundle: Bundle.main, value: "When using the native transmitter algorithm, manual calibration is not available.\n\nIf you want to calibrate, you can switch to the xDrip algorithm in the transmitter screen (if available).", comment: "if web oop enabled, and also if transmitter supports this, user clicks calibrate button, but calibration is not possible")
    }()
 
    static let dexcomBatteryTooLow: String = {
        return NSLocalizedString("dexcomBatteryTooLow", tableName: filename, bundle: Bundle.main, value: "The Transmitter battery is too low!", comment: "Error message in case Dexcom G5 (and G6?) battery is too low. This is deteced by wrong G5 values 2096896")
    }()
    
    static let enterSensorCode: String = {
        return NSLocalizedString("enterSensorCode", tableName: filename, bundle: Bundle.main, value: "If you don't know the sensor code, leave this empty to use 0000. Pressing OK without a code will use 0000 as the sensor code, or will just capture the current session if one is already started.", comment: "When user needs to enter sensor code, to start firefly sensor")
    }()

    static let scanWithCamera = NSLocalizedString("scanWithCamera", tableName: filename, bundle: .main, value: "Scan with Camera", comment: "button to scan a Dexcom G6 sensor label")
    static let chooseSensorLabelPhoto = NSLocalizedString("chooseSensorLabelPhoto", tableName: filename, bundle: .main, value: "Choose Photo", comment: "button to decode a Dexcom G6 sensor label from a photo")
    static let readingSensorLabel = NSLocalizedString("readingSensorLabel", tableName: filename, bundle: .main, value: "Reading sensor label...", comment: "progress text while decoding a sensor label photo")
    static let scanSensorLabel = NSLocalizedString("scanSensorLabel", tableName: filename, bundle: .main, value: "Scan Sensor Label", comment: "camera scanner title")
    static let sensorCodeScannerGuidance = NSLocalizedString("sensorCodeScannerGuidance", tableName: filename, bundle: .main, value: "Place the Data Matrix inside the frame.", comment: "camera scanner guidance")
    static let sensorCodeScannerTorch = NSLocalizedString("sensorCodeScannerTorch", tableName: filename, bundle: .main, value: "Torch", comment: "camera scanner torch button")
    static let cameraAccessRequired = NSLocalizedString("cameraAccessRequired", tableName: filename, bundle: .main, value: "Camera Access Required", comment: "camera permission alert title")
    static let cameraAccessRequiredMessage = NSLocalizedString("cameraAccessRequiredMessage", tableName: filename, bundle: .main, value: "Allow camera access in Settings, or enter the code manually or choose a photo.", comment: "camera permission alert message")
    static let openSettings = NSLocalizedString("openSettings", tableName: filename, bundle: .main, value: "Open Settings", comment: "button opening iOS Settings")
    static let cameraUnavailable = NSLocalizedString("cameraUnavailable", tableName: filename, bundle: .main, value: "Camera Unavailable", comment: "camera unavailable alert title")
    static let cameraUnavailableMessage = NSLocalizedString("cameraUnavailableMessage", tableName: filename, bundle: .main, value: "Enter the sensor code manually or choose a photo.", comment: "camera unavailable alert message")
    static let sensorInformationTitle = NSLocalizedString("sensorInformationTitle", tableName: filename, bundle: .main, value: "Sensor Information", comment: "section title for stored sensor-label information")
    static let sensorLotNumber = NSLocalizedString("sensorLotNumber", tableName: filename, bundle: .main, value: "Lot Number", comment: "Dexcom sensor lot number label")
    static let sensorSerialNumber = NSLocalizedString("sensorSerialNumberMetadata", tableName: filename, bundle: .main, value: "Sensor Serial Number", comment: "Dexcom sensor serial number label")
    static let sensorLabelReviewFooter = NSLocalizedString("sensorLabelReviewFooter", tableName: filename, bundle: .main, value: "Check the decoded information before starting the sensor.", comment: "footer below decoded sensor-label information")
    static let sensorLabelScanFailed = NSLocalizedString("sensorLabelScanFailed", tableName: filename, bundle: .main, value: "Sensor Label Not Read", comment: "sensor-label decoding alert title")
    static let multipleSensorLabelsFound = NSLocalizedString("multipleSensorLabelsFound", tableName: filename, bundle: .main, value: "The photo contains more than one sensor label. Choose a photo containing one label.", comment: "multiple sensor labels error")
    static let noSensorLabelFound = NSLocalizedString("noSensorLabelFound", tableName: filename, bundle: .main, value: "No valid Dexcom G6 sensor label was found in the photo.", comment: "no sensor label error")
    static let invalidSensorLabelFound = NSLocalizedString("invalidSensorLabelFound", tableName: filename, bundle: .main, value: "A Data Matrix was found, but it was not a valid Dexcom G6 sensor label.", comment: "invalid sensor label error")
    static let sensorLabelPhotoUnreadable = NSLocalizedString("sensorLabelPhotoUnreadable", tableName: filename, bundle: .main, value: "The selected photo could not be read.", comment: "unreadable sensor-label photo error")
    static let sensorCode = NSLocalizedString("sensorCodeMetadata", tableName: filename, bundle: .main, value: "Sensor Code", comment: "active Dexcom sensor code label")
    static let scannedSensorLabelCode = NSLocalizedString("scannedSensorLabelCode", tableName: filename, bundle: .main, value: "Scanned Label Code", comment: "sensor code decoded from a physical label")
    static let noCodeSensorSessionValue = NSLocalizedString("noCodeSensorSessionValue", tableName: filename, bundle: .main, value: "0000 (No-code session)", comment: "confirmed no-code Dexcom session value")
    static let sensorCodeUnknown = NSLocalizedString("sensorCodeUnknown", tableName: filename, bundle: .main, value: "Unknown", comment: "unknown active sensor code value")
    static let sensorSessionOrigin = NSLocalizedString("sensorSessionOrigin", tableName: filename, bundle: .main, value: "Session Origin", comment: "sensor session origin label")
    static let sensorSessionOriginUnknown = NSLocalizedString("sensorSessionOriginUnknown", tableName: filename, bundle: .main, value: "Unknown", comment: "unknown sensor session origin")
    static let sensorSessionOriginAwaitingTransmitter = NSLocalizedString("sensorSessionOriginAwaitingTransmitter", tableName: filename, bundle: .main, value: "Awaiting transmitter", comment: "pending sensor-start request origin")
    static let sensorSessionOriginStartedByApp = NSLocalizedString("sensorSessionOriginStartedByApp", tableName: filename, bundle: .main, value: "Started by xDrip4iOS", comment: "sensor session started by this app")
    static let sensorSessionOriginExistingAdopted = NSLocalizedString("sensorSessionOriginExistingAdopted", tableName: filename, bundle: .main, value: "Existing session adopted", comment: "existing transmitter session adopted by this app")
    static let sensorSessionOriginTransmitterDetected = NSLocalizedString("sensorSessionOriginTransmitterDetected", tableName: filename, bundle: .main, value: "Detected from transmitter", comment: "sensor session automatically detected from transmitter")
    static let sensorSessionOriginRejected = NSLocalizedString("sensorSessionOriginRejected", tableName: filename, bundle: .main, value: "Start request rejected", comment: "sensor-start request rejected by transmitter")

    static let noSensorCodeSelectedTitle: String = {
        return NSLocalizedString("noSensorCodeSelectedTitle", tableName: filename, bundle: Bundle.main, value: "No Sensor Code Selected", comment: "Alert title shown before starting a Dexcom G6 sensor with no code/0000")
    }()

    static let noSensorCodeSelectedMessage: String = {
        let message = "Starting a Dexcom G6 sensor with 0000 means no sensor code will be sent to the transmitter.\n\n"
            + "The Dexcom transmitter will require calibrations for this sensor session: two calibrations after warm-up, "
            + "another 12 hours later, another 12 hours after that, then once every 24 hours until the sensor ends.\n\n"
            + "These calibration requests come from the Dexcom transmitter/no-code workflow. They are not caused by the "
            + "%@ calibration reminder setting, and disabling that reminder will not stop required transmitter calibrations."
        let localizedMessage = NSLocalizedString(
            "noSensorCodeSelectedMessage",
            tableName: filename,
            bundle: Bundle.main,
            value: message,
            comment: "Alert message shown before starting a Dexcom G6 sensor with no code/0000. Placeholder is the app display name"
        )
        return String(format: localizedMessage, ConstantsHomeView.applicationName)
    }()

    static let startSensorAnyway: String = {
        return NSLocalizedString("startSensorAnyway", tableName: filename, bundle: Bundle.main, value: "Start Anyway", comment: "Confirmation button to start a sensor after a no-code calibration warning")
    }()
    
    static let stopSensorConfirmation: String = {
        return NSLocalizedString("stopSensorConfirmation", tableName: filename, bundle: Bundle.main, value: "Are you sure you want to stop the sensor?", comment: "When user clicks stop sensor, ask confirmation")
    }()
    
    static let noSensorData: String = {
        return NSLocalizedString("noSensorData", tableName: filename, bundle: Bundle.main, value: "No sensor data", comment: "no sensor data is available")
    }()
    
    static let noDataSourceConnected: String = {
        return NSLocalizedString("noDataSourceConnected", tableName: filename, bundle: Bundle.main, value: "No CGM data source connected", comment: "no data source is enabled or connected")
    }()
    
    // the same as noDataSourceConnected but shorter to display nicely in the Watch app
    static let noDataSourceConnectedWatch: String = {
        return NSLocalizedString("noDataSourceConnectedWatch", tableName: filename, bundle: Bundle.main, value: "No data source", comment: "no data source is enabled or connected")
    }()
    
    static let reconnectLibreDataSource: String = {
        return NSLocalizedString("reconnectLibreDataSource", tableName: filename, bundle: Bundle.main, value: "Disconnect and reconnect Libre sensor", comment: "ask the user to disconnect and reconnect the sensor")
    }()

    // used when a CGM Transmitter is selected and waiting for its Bluetooth connection
    static let waitingForCGMConnection: String = {
        return NSLocalizedString("waitingForCGMConnection", tableName: filename, bundle: Bundle.main, value: "Waiting for CGM connection...", comment: "waiting for the selected CGM transmitter to connect")
    }()

    static let connectingToCGM: String = {
        return NSLocalizedString("connectingToCGM", tableName: filename, bundle: Bundle.main, value: "Connecting to CGM...", comment: "first Bluetooth connection to the selected CGM after the user activates it")
    }()

    static let reconnectingToCGM: String = {
        return NSLocalizedString("reconnectingToCGM", tableName: filename, bundle: Bundle.main, value: "Reconnecting to CGM...", comment: "an enabled continuously connected CGM unexpectedly lost its Bluetooth connection")
    }()
    
    // used when a CGM Transmitter is connected, but there is no active sensor data yet
    static let waitingForDataSource: String = {
        return NSLocalizedString("waitingForDataSource", tableName: filename, bundle: Bundle.main, value: "CGM connected. Waiting for data...", comment: "waiting for data to arrive")
    }()
    
    // make sure any translations are less than 20-22 characters long (including the "%@")
    static let hidingUrlForXSeconds:String = {
        return String(format: NSLocalizedString("hidingUrlForXSeconds", tableName: filename, bundle: Bundle.main, value: "Hiding URL for %@s...", comment: "After clicking scan button, this message will appear"), String(ConstantsHomeView.hideUrlDuringTimeInSeconds))
    }()
    
    static let nightscoutNotEnabled: String = {
        return NSLocalizedString("nightscoutNotEnabled", tableName: filename, bundle: Bundle.main, value: "Nightscout is disabled", comment: "nightscout is not enabled")
    }()
    
    static let nightscoutURLMissing: String = {
        return NSLocalizedString("nightscoutURLMissing", tableName: filename, bundle: Bundle.main, value: "URL missing", comment: "nightscout is not enabled")
    }()
    
    static let followerAccountCredentialsMissing: String = {
        return NSLocalizedString("followerAccountCredentialsMissing", tableName: filename, bundle: Bundle.main, value: "Username/password missing", comment: "username and/or password is missing")
    }()
    
    static let followerAccountCredentialsInvalid: String = {
        return NSLocalizedString("followerAccountCredentialsInvalid", tableName: filename, bundle: Bundle.main, value: "Invalid Account", comment: "username and/or password is invalid")
    }()
    
    static let showHideItemsTitle: String = {
        return NSLocalizedString("showHideItemsTitle", tableName: filename, bundle: Bundle.main, value: "Quick Show/Hide", comment: "show or hide various interface items")
    }()

    static let showHideHomeScreenTitle: String = {
        return NSLocalizedString("showHideHomeScreenTitle", tableName: filename, bundle: Bundle.main, value: "Home Screen", comment: "quick show hide section title for home screen items")
    }()

    static let showHideHomeScreenFooter: String = {
        return NSLocalizedString("showHideHomeScreenFooter", tableName: filename, bundle: Bundle.main, value: "Show or hide main home screen elements, useful when using smaller iPhone screen sizes", comment: "quick show hide footer for home screen items")
    }()

    static let showHideGlucoseChartTitle: String = {
        return NSLocalizedString("showHideGlucoseChartTitle", tableName: filename, bundle: Bundle.main, value: "Glucose Chart", comment: "quick show hide section title for chart items")
    }()

    static let showHideStandByModeTitle: String = {
        return NSLocalizedString("showHideStandByModeTitle", tableName: filename, bundle: Bundle.main, value: "StandBy Mode", comment: "quick show hide section title for standby settings")
    }()

    static let showHideStandByModeFooter: String = {
        return NSLocalizedString("showHideStandByModeFooter", tableName: filename, bundle: Bundle.main, value: "Changes how the StandBy mode will be displayed if activated in the iPhone settings", comment: "quick show hide footer for standby settings")
    }()

    static let showHideAdditionalItemsTitle: String = {
        return NSLocalizedString("showHideAdditionalItemsTitle", tableName: filename, bundle: Bundle.main, value: "Additional Items", comment: "quick show hide section title for additional items")
    }()
    
    static let postProcessingTitle: String = {
        return NSLocalizedString("postProcessingTitle", tableName: filename, bundle: Bundle.main, value: "Glucose Adjustments", comment: "title for the blood glucose post processing view")
    }()

    static let postProcessingPreviewHours: String = {
        return NSLocalizedString("postProcessingPreviewHours", tableName: filename, bundle: Bundle.main, value: "Preview Hours", comment: "post processing preview chart hours selector label")
    }()

    static let postProcessingAdjustment: String = {
        return NSLocalizedString("postProcessingAdjustment", tableName: filename, bundle: Bundle.main, value: "Adjustment", comment: "post processing section title for adjustment")
    }()

    static let postProcessingEnable: String = {
        return NSLocalizedString("postProcessingEnable", tableName: filename, bundle: Bundle.main, value: "Enable", comment: "post processing enable toggle title")
    }()

    static let postProcessingOffset: String = {
        return NSLocalizedString("postProcessingOffset", tableName: filename, bundle: Bundle.main, value: "Offset", comment: "post processing offset label")
    }()

    static let postProcessingScale: String = {
        return NSLocalizedString("postProcessingScale", tableName: filename, bundle: Bundle.main, value: "Scale", comment: "post processing scale label")
    }()

    static let postProcessingShape: String = {
        return NSLocalizedString("postProcessingShape", tableName: filename, bundle: Bundle.main, value: "Emphasis", comment: "post processing emphasis picker title")
    }()

    static let postProcessingShapeExplanation: String = {
        return NSLocalizedString("postProcessingShapeExplanation", tableName: filename, bundle: Bundle.main, value: "Emphasis changes where Scale has the most effect on the curve. This can help if a sensor seems to exaggerate higher or lower glucose values more than the rest of the range.", comment: "post processing explanation for emphasis selection")
    }()

    static let postProcessingSofterHighs: String = {
        return NSLocalizedString("postProcessingSofterHighs", tableName: filename, bundle: Bundle.main, value: "Highs", comment: "post processing emphasis option for highs")
    }()

    static let postProcessingSofterHighsDescription: String = {
        return NSLocalizedString("postProcessingSofterHighsDescription", tableName: filename, bundle: Bundle.main, value: "Applies more of the scale effect at higher glucose values and less at lower values.", comment: "post processing explanation for highs emphasis option")
    }()

    static let postProcessingNeutral: String = {
        return NSLocalizedString("postProcessingNeutral", tableName: filename, bundle: Bundle.main, value: "Normal", comment: "post processing shape option normal")
    }()

    static let postProcessingNeutralDescription: String = {
        return NSLocalizedString("postProcessingNeutralDescription", tableName: filename, bundle: Bundle.main, value: "Applies the scale effect evenly through the glucose range.", comment: "post processing explanation for neutral emphasis option")
    }()

    static let postProcessingSofterLows: String = {
        return NSLocalizedString("postProcessingSofterLows", tableName: filename, bundle: Bundle.main, value: "Lows", comment: "post processing emphasis option for lows")
    }()

    static let postProcessingSofterLowsDescription: String = {
        return NSLocalizedString("postProcessingSofterLowsDescription", tableName: filename, bundle: Bundle.main, value: "Applies more of the scale effect at lower glucose values and less at higher values.", comment: "post processing explanation for lows emphasis option")
    }()

    static let postProcessingSmoothing: String = {
        return NSLocalizedString("postProcessingSmoothing", tableName: filename, bundle: Bundle.main, value: "Smoothing", comment: "post processing section title for smoothing")
    }()

    static let postProcessingStrength: String = {
        return NSLocalizedString("postProcessingStrength", tableName: filename, bundle: Bundle.main, value: "Strength", comment: "post processing smoothing strength picker title")
    }()

    static let postProcessingAlgorithm: String = {
        return NSLocalizedString("postProcessingAlgorithm", tableName: filename, bundle: Bundle.main, value: "Algorithm", comment: "post processing smoothing algorithm picker title")
    }()

    static let postProcessingAlgorithmSavitzkyGolay: String = {
        return NSLocalizedString("postProcessingAlgorithmSavitzkyGolay", tableName: filename, bundle: Bundle.main, value: "Savitzky-Golay", comment: "post processing Savitzky-Golay smoothing algorithm")
    }()

    static let postProcessingAlgorithmSavitzkyGolayDescription: String = {
        return NSLocalizedString("postProcessingAlgorithmSavitzkyGolayDescription", tableName: filename, bundle: Bundle.main, value: "Savitzky-Golay smooths the glucose curve by fitting short local windows while preserving the general shape of peaks and troughs.", comment: "post processing footer text explaining the selected Savitzky-Golay smoothing algorithm")
    }()

    static let postProcessingAlgorithmExponential: String = {
        return NSLocalizedString("postProcessingAlgorithmExponential", tableName: filename, bundle: Bundle.main, value: "Exponential", comment: "post processing exponential smoothing algorithm")
    }()

    static let postProcessingAlgorithmExponentialDescription: String = {
        return NSLocalizedString("postProcessingAlgorithmExponentialDescription", tableName: filename, bundle: Bundle.main, value: "Exponential smoothing uses low-lag forward and backward weighted passes, making recent glucose moves look calmer without flattening them as aggressively.", comment: "post processing footer text explaining the selected exponential smoothing algorithm")
    }()

    static let postProcessingAlgorithmKalman: String = {
        return NSLocalizedString("postProcessingAlgorithmKalman", tableName: filename, bundle: Bundle.main, value: "Kalman", comment: "post processing Kalman smoothing algorithm")
    }()

    static let postProcessingAlgorithmKalmanDescription: String = {
        return NSLocalizedString("postProcessingAlgorithmKalmanDescription", tableName: filename, bundle: Bundle.main, value: "Kalman smoothing models glucose as a noisy live signal and updates a running estimate, usually producing a steadier curve with more obvious filtering than the default shape-preserving smoother.", comment: "post processing footer text explaining the selected Kalman smoothing algorithm")
    }()

    static let postProcessingAlgorithmLoess: String = {
        return NSLocalizedString("postProcessingAlgorithmLoess", tableName: filename, bundle: Bundle.main, value: "LOESS", comment: "post processing LOESS smoothing algorithm")
    }()

    static let postProcessingAlgorithmLoessDescription: String = {
        return NSLocalizedString("postProcessingAlgorithmLoessDescription", tableName: filename, bundle: Bundle.main, value: "LOESS fits a small weighted regression around each reading, usually preserving ramps and bends while looking smoother and less rigid than a simple filter pass.", comment: "post processing footer text explaining the selected LOESS smoothing algorithm")
    }()

    static let postProcessingAlgorithmHampelSavitzkyGolay: String = {
        return NSLocalizedString("postProcessingAlgorithmHampelSavitzkyGolay", tableName: filename, bundle: Bundle.main, value: "Hampel + Savitzky-Golay", comment: "post processing Hampel plus Savitzky-Golay smoothing algorithm")
    }()

    static let postProcessingAlgorithmHampelSavitzkyGolayDescription: String = {
        return NSLocalizedString("postProcessingAlgorithmHampelSavitzkyGolayDescription", tableName: filename, bundle: Bundle.main, value: "This hybrid first suppresses isolated spike-like outliers with a Hampel pass, then applies Savitzky-Golay smoothing to keep the broader glucose curve natural.", comment: "post processing footer text explaining the selected Hampel plus Savitzky-Golay smoothing algorithm")
    }()

    static let postProcessingLight: String = {
        return NSLocalizedString("postProcessingLight", tableName: filename, bundle: Bundle.main, value: "Light", comment: "post processing smoothing light option")
    }()

    static let postProcessingMedium: String = {
        return NSLocalizedString("postProcessingMedium", tableName: filename, bundle: Bundle.main, value: "Medium", comment: "post processing smoothing medium option")
    }()

    static let postProcessingStrong: String = {
        return NSLocalizedString("postProcessingStrong", tableName: filename, bundle: Bundle.main, value: "Strong", comment: "post processing smoothing strong option")
    }()

    static let postProcessingFiveMinuteReadings: String = {
        return NSLocalizedString("postProcessingFiveMinuteReadings", tableName: filename, bundle: Bundle.main, value: "5-minute readings", comment: "post processing option to reduce faster CGM streams to visible 5 minute readings")
    }()

    static let postProcessingReadingFrequency: String = {
        return NSLocalizedString("postProcessingReadingFrequency", tableName: filename, bundle: Bundle.main, value: "Reading Frequency", comment: "post processing section title for output cadence controls such as reducing faster streams to 5 minute readings")
    }()

    static let postProcessingApplyFrom: String = {
        return NSLocalizedString("postProcessingApplyFrom", tableName: filename, bundle: Bundle.main, value: "Apply From", comment: "post processing section title and picker title for apply from")
    }()

    static let postProcessingNow: String = {
        return NSLocalizedString("postProcessingNow", tableName: filename, bundle: Bundle.main, value: "Now", comment: "post processing apply from now option")
    }()

    static let postProcessingApply: String = {
        return NSLocalizedString("postProcessingApply", tableName: filename, bundle: Bundle.main, value: "Apply", comment: "post processing apply button")
    }()

    static let postProcessingDexcomShareDataNotUpdated: String = {
        return NSLocalizedString("postProcessingDexcomShareDataNotUpdated", tableName: filename, bundle: Bundle.main, value: "Dexcom Share data will not be updated", comment: "post processing helper text when following Dexcom Share and Dexcom Share writes are disabled")
    }()

    static let postProcessingOriginal: String = {
        return NSLocalizedString("postProcessingOriginal", tableName: filename, bundle: Bundle.main, value: "Original", comment: "post processing chart context original value title")
    }()

    static let postProcessingAdjusted: String = {
        return NSLocalizedString("postProcessingAdjusted", tableName: filename, bundle: Bundle.main, value: "Adjusted", comment: "post processing chart context adjusted value title")
    }()

    static let postProcessingSmoothed: String = {
        return NSLocalizedString("postProcessingSmoothed", tableName: filename, bundle: Bundle.main, value: "Smoothed", comment: "post processing chart context smoothed value title")
    }()

    static let postProcessingUpdateAllReadingsLastPeriod: String = {
        return NSLocalizedString("postProcessingUpdateAllReadingsLastPeriod", tableName: filename, bundle: Bundle.main, value: "Overwrite all values in the last %@", comment: "post processing helper text for historical apply window using a dynamic time period such as 1h36m")
    }()

    static let postProcessingNightscoutDataNotUpdated: String = {
        return NSLocalizedString("postProcessingNightscoutDataNotUpdated", tableName: filename, bundle: Bundle.main, value: "Nightscout data will not be updated", comment: "post processing helper text when following Nightscout and Nightscout writes are disabled")
    }()

    static let postProcessingMasterNightscoutUploadDisabled: String = {
        return NSLocalizedString("postProcessingMasterNightscoutUploadDisabled", tableName: filename, bundle: Bundle.main, value: "Upload to Nightscout is disabled", comment: "post processing helper text when master Nightscout BG upload is disabled")
    }()

    static let postProcessingOriginalGlucose: String = {
        return NSLocalizedString("postProcessingOriginalGlucose", tableName: filename, bundle: Bundle.main, value: "Original Glucose", comment: "post processing input row title for original glucose")
    }()

    static let postProcessingCurrentValue: String = {
        return NSLocalizedString("postProcessingCurrentValue", tableName: filename, bundle: Bundle.main, value: "Current Value", comment: "shared row title for the current glucose value")
    }()

    static let postProcessingAdjustedGlucose: String = {
        return NSLocalizedString("postProcessingAdjustedGlucose", tableName: filename, bundle: Bundle.main, value: "Adjusted glucose", comment: "post processing input row title for adjusted glucose")
    }()

    static let postProcessingEnterValue: String = {
        return NSLocalizedString("postProcessingEnterValue", tableName: filename, bundle: Bundle.main, value: "Enter value", comment: "post processing placeholder to enter a glucose value")
    }()

    static let postProcessingEnterGlucose: String = {
        return NSLocalizedString("postProcessingEnterGlucose", tableName: filename, bundle: Bundle.main, value: "Enter Glucose", comment: "post processing input screen title")
    }()

    static let postProcessingNoCurrentValues: String = {
        return NSLocalizedString("postProcessingNoCurrentValues", tableName: filename, bundle: Bundle.main, value: "No current values", comment: "post processing placeholder shown above the preview chart when there are no glucose values to display")
    }()
    
    static let postProcessingValidGlucoseRange: String = {
        return NSLocalizedString("postProcessingValidGlucoseRange", tableName: filename, bundle: Bundle.main, value: "Enter a value between %@ and %@", comment: "post processing helper text describing the valid glucose input range")
    }()
    
    static let postProcessingOffsetBgCheckHint: String = {
        return NSLocalizedString("postProcessingOffsetBgCheckHint", tableName: filename, bundle: Bundle.main, value: "At least one recent BG check recommended", comment: "post processing hint shown when no BG check is visible in the preview while adjusting offset")
    }()
    
    static let postProcessingScaleBgCheckHint: String = {
        return NSLocalizedString("postProcessingScaleBgCheckHint", tableName: filename, bundle: Bundle.main, value: "At least two recent BG checks recommended", comment: "post processing hint shown when fewer than two BG checks are visible in the preview while adjusting scale or emphasis")
    }()
    
    static let postProcessingAdjustmentDisabledBecauseSensorIsCalibrated: String = {
        return NSLocalizedString("postProcessingAdjustmentDisabledBecauseSensorIsCalibrated", tableName: filename, bundle: Bundle.main, value: "Adjustment is disabled because this sensor already uses its own calibration.", comment: "post processing footer text when glucose adjustment is disabled because the active sensor already uses calibration")
    }()
    
    static let postProcessingAdjustmentDisabledUseNativeAlgorithm: String = {
        return NSLocalizedString("postProcessingAdjustmentDisabledUseNativeAlgorithm", tableName: filename, bundle: Bundle.main, value: "Adjustment is disabled because this sensor already uses its own calibration. Change to the native algorithm to allow glucose adjustments.", comment: "post processing footer text when glucose adjustment is disabled for a Libre sensor using xDrip calibration")
    }()
    
    static let showTreatments: String = {
        return NSLocalizedString("showTreatments", tableName: filename, bundle: Bundle.main, value: "Show Treatments", comment: "show the treatments on the chart")
    }()
    
}
