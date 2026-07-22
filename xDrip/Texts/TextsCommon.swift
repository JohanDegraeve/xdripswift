import Foundation

// all common texts 
class Texts_Common {
    static private let filename = "Common"
    
    static let Ok = {
        return NSLocalizedString("common_Ok", tableName: filename, bundle: Bundle.main, value: "OK", comment: "literally 'OK'")
    }()
    
    //common_cancel
    static let Cancel = {
        return NSLocalizedString("common_cancel", tableName: filename, bundle: Bundle.main, value: "Cancel", comment: "literally 'Cancel'")
    }()
    
    static let mgdl: String = {
        return NSLocalizedString("common_mgdl", tableName: filename, bundle: Bundle.main, value: "mg/dL", comment: "mg/dL")
    }()

    static let mmol: String = {
        return NSLocalizedString("common_mmol", tableName: filename, bundle: Bundle.main, value: "mmol/L", comment: "mmol/L")
    }()

    static let bloodGlucoseUnit: String = {
        return NSLocalizedString("common_bloodglucoseunit", tableName: filename, bundle: Bundle.main, value: "Blood Glucose Unit", comment: "can be used in several screens, just the words Bloodglucose unit")
    }()
    
    static let bloodGlucoseUnitShort:String = {
        return NSLocalizedString("common_bloodglucoseunit_short", tableName: filename, bundle: Bundle.main, value: "BG Unit", comment: "blood glucose unit in short, for text field title")
    }()
    
    static let password = {
        return NSLocalizedString("common_password", tableName: filename, bundle: Bundle.main, value: "Password", comment: "literally password")
    }()
    
    static let username = {
        return NSLocalizedString("common_username", tableName: filename, bundle: Bundle.main, value: "Username", comment: "literally username")
    }()
    
    static let default0 = {
        return NSLocalizedString("common_default", tableName: filename, bundle: Bundle.main, value: "Default", comment: "literally default, will be the name of default alerttypes that will be created during initial app launch")
    }()

    static let HIGH = {
        return NSLocalizedString("common_high", tableName: filename, bundle: Bundle.main, value: "HIGH", comment: "the word HIGH, in capitals")
    }()
    
    static let LOW = {
        return NSLocalizedString("common_low", tableName: filename, bundle: Bundle.main, value: "LOW", comment: "the word LOW, in capitals")
    }()
    
    static let hourshort = {
        return NSLocalizedString("common_hourshort", tableName: filename, bundle: Bundle.main, value: "h", comment: "literal translation needed")
    }()
    
    static let hour = {
        return NSLocalizedString("common_hour", tableName: filename, bundle: Bundle.main, value: "hour", comment: "literal translation needed")
    }()
    
    static let hours = {
        return NSLocalizedString("common_hours", tableName: filename, bundle: Bundle.main, value: "hours", comment: "literal translation needed")
    }()
    
    static let minuteshort = {
        return NSLocalizedString("common_minuteshort", tableName: filename, bundle: Bundle.main, value: "m", comment: "literal translation needed")
    }()
    
    static let minutes = {
        return NSLocalizedString("common_minutes", tableName: filename, bundle: Bundle.main, value: "mins", comment: "literal translation needed")
    }()
    
    static let minute = {
        return NSLocalizedString("common_minute", tableName: filename, bundle: Bundle.main, value: "min", comment: "literal translation needed")
    }()
    
    static let dayshort = {
        return NSLocalizedString("common_dayshort", tableName: filename, bundle: Bundle.main, value: "d", comment: "literal translation needed")
    }()
    
    static let day = {
        return NSLocalizedString("common_day", tableName: filename, bundle: Bundle.main, value: "day", comment: "literal translation needed")
    }()
    
    static let days = {
        return NSLocalizedString("common_days", tableName: filename, bundle: Bundle.main, value: "days", comment: "literal translation needed")
    }()
    
    static let today = {
        return NSLocalizedString("common_today", tableName: filename, bundle: Bundle.main, value: "Today", comment: "the word today")
    }()
    
    static let todayshort = {
        return NSLocalizedString("common_todayshort", tableName: filename, bundle: Bundle.main, value: "Today", comment: "the word today")
    }()
    
    static let week = {
        return NSLocalizedString("common_week", tableName: filename, bundle: Bundle.main, value: "week", comment: "literal translation needed")
    }()
    
    static let warning = {
        return NSLocalizedString("warning", tableName: filename, bundle: Bundle.main, value: "Warning!", comment: "literally warning")
    }()
 
    static let update = {
        return NSLocalizedString("update", tableName: filename, bundle: Bundle.main, value: "Edit", comment: "literally update")
    }()

    static let add = {
        return NSLocalizedString("add", tableName: filename, bundle: Bundle.main, value: "Add", comment: "literally add")
    }()
    
    static let yes = {
        return NSLocalizedString("yes", tableName: filename, bundle: Bundle.main, value: "Yes", comment: "literally yes, without capital")
    }()
    
    static let no = {
        return NSLocalizedString("no", tableName: filename, bundle: Bundle.main, value: "No", comment: "literally no, without capital")
    }()
    
    static let red = {
        return NSLocalizedString("red", tableName: filename, bundle: Bundle.main, value: "red", comment: "red")
    }()
    
    static let green = {
        return NSLocalizedString("green", tableName: filename, bundle: Bundle.main, value: "green", comment: "green")
    }()
    
    static let white = {
        return NSLocalizedString("white", tableName: filename, bundle: Bundle.main, value: "white", comment: "white")
    }()
    
    static let yellow = {
        return NSLocalizedString("yellow", tableName: filename, bundle: Bundle.main, value: "yellow", comment: "yellow")
    }()
    
    static let black = {
        return NSLocalizedString("black", tableName: filename, bundle: Bundle.main, value: "black", comment: "black")
    }()
    
    static let name = {
        return NSLocalizedString("name", tableName: filename, bundle: Bundle.main, value: "Name:", comment: "name")
    }()

    static let value = {
        return NSLocalizedString("common_value", tableName: filename, bundle: Bundle.main, value: "Value", comment: "generic value label")
    }()

    static let enterValue = {
        return NSLocalizedString("common_enterValue", tableName: filename, bundle: Bundle.main, value: "Enter Value", comment: "generic label for a row where the user enters a value")
    }()
    
    static let WiFi = {
        return NSLocalizedString("WiFi", tableName: filename, bundle: Bundle.main, value: "WiFi", comment: "WiFi")
    }()
    
    static let on = {
        return NSLocalizedString("on", tableName: filename, bundle: Bundle.main, value: "On", comment: "on")
    }()

    static let off = {
        return NSLocalizedString("Off", tableName: filename, bundle: Bundle.main, value: "off", comment: "off")
    }()

    static let delete = {
        return NSLocalizedString("Delete", tableName: filename, bundle: Bundle.main, value: "Delete", comment: "Delete")
    }()
    
    static let invalidValue = {
        return NSLocalizedString("invalidValue", tableName: filename, bundle: Bundle.main, value: "Invalid Value", comment: "whenever invalid value is given by user somewhere in a field")
    }()
    
    static let firmware = {
        return NSLocalizedString("firmware", tableName: filename, bundle: Bundle.main, value: "Firmware", comment: "for settings row, literally firmware")
    }()
    
    static let hardware = {
        return NSLocalizedString("hardware", tableName: filename, bundle: Bundle.main, value: "Hardware", comment: "for settings row, literally hardware")
    }()
    
    static let unknown = {
        return NSLocalizedString("unknown", tableName: filename, bundle: Bundle.main, value: "Unknown", comment: "general usage")
    }()
    
    static let sensorStatus = {
        return NSLocalizedString("sensorStatus", tableName: filename, bundle: Bundle.main, value: "Sensor Status", comment: "to show the sensor status")
    }()
    
    static let invalidAccountOrPassword = {
        return NSLocalizedString("invalidAccountOrPassword", tableName: filename, bundle: Bundle.main, value: "Invalid account or password", comment: "Where credentials need to be given, if either account or password is invalid (for the moment only applicable to Dexcom Share")
    }()
    

    static let lowStatistics = {
        return NSLocalizedString("common_statistics_low", tableName: filename, bundle: Bundle.main, value: "Low", comment: "the word low")
    }()
    
    static let inRangeStatistics = {
        return NSLocalizedString("common_statistics_inRange", tableName: filename, bundle: Bundle.main, value: "In Range", comment: "the words in range")
    }()
    
    static let inTightRangeStatistics = {
        return NSLocalizedString("common_statistics_inTightRange", tableName: filename, bundle: Bundle.main, value: "Tight Range", comment: "the words in tight range")
    }()
    
    static let userRangeStatistics = {
        return NSLocalizedString("common_statistics_userRange", tableName: filename, bundle: Bundle.main, value: "User Range", comment: "the words in user range")
    }()
    
    static let highStatistics = {
        return NSLocalizedString("common_statistics_high", tableName: filename, bundle: Bundle.main, value: "High", comment: "the word high")
    }()
    
    static let averageStatistics = {
        return NSLocalizedString("common_statistics_average", tableName: filename, bundle: Bundle.main, value: "Average", comment: "the word average")
    }()
    
    static let a1cStatistics = {
        return NSLocalizedString("common_statistics_a1c", tableName: filename, bundle: Bundle.main, value: "HbA1c", comment: "phrase HbA1c")
    }()
    
    static let cvStatistics = {
        return NSLocalizedString("common_statistics_cv", tableName: filename, bundle: Bundle.main, value: "CV", comment: "coefficient of variation")
    }()

    static let statisticsTitle = {
        return NSLocalizedString("common_statistics_title", tableName: filename, bundle: Bundle.main, value: "Statistics", comment: "statistics tab title")
    }()

    static let statisticsPeriod = {
        return NSLocalizedString("common_statistics_period", tableName: filename, bundle: Bundle.main, value: "Period", comment: "statistics period picker title")
    }()

    static let statisticsSummary = {
        return NSLocalizedString("common_statistics_summary", tableName: filename, bundle: Bundle.main, value: "Summary", comment: "statistics summary section tab")
    }()

    static let statisticsTrends = {
        return NSLocalizedString("common_statistics_trends", tableName: filename, bundle: Bundle.main, value: "Trends", comment: "statistics trends section tab")
    }()

    static let statisticsDaily = {
        return NSLocalizedString("common_statistics_daily", tableName: filename, bundle: Bundle.main, value: "Daily", comment: "statistics daily section tab")
    }()

    static let statisticsReport = {
        return NSLocalizedString("common_statistics_report", tableName: filename, bundle: Bundle.main, value: "Report", comment: "statistics report section tab")
    }()

    static let statisticsTimeInRange = {
        return NSLocalizedString("common_statistics_timeInRange", tableName: filename, bundle: Bundle.main, value: "Time in Range", comment: "statistics time in range title")
    }()

    static let statisticsTimeInTightRange = {
        return NSLocalizedString("common_statistics_timeInTightRange", tableName: filename, bundle: Bundle.main, value: "Time in Tight Range", comment: "statistics time in tight range title")
    }()

    static let statisticsMeanGlucose = {
        return NSLocalizedString("common_statistics_meanGlucose", tableName: filename, bundle: Bundle.main, value: "Mean glucose", comment: "statistics average glucose detail")
    }()

    static let statisticsGMI = {
        return NSLocalizedString("common_statistics_gmi", tableName: filename, bundle: Bundle.main, value: "GMI", comment: "glucose management indicator abbreviation")
    }()

    static let statisticsCGMEstimate = {
        return NSLocalizedString("common_statistics_cgmEstimate", tableName: filename, bundle: Bundle.main, value: "CGM estimate", comment: "statistics GMI detail")
    }()

    static let statisticsDataCapture = {
        return NSLocalizedString("common_statistics_dataCapture", tableName: filename, bundle: Bundle.main, value: "Data Capture", comment: "statistics data capture title")
    }()

    static let statisticsTargetLessThanOrEqual = {
        return NSLocalizedString("common_statistics_targetLessThanOrEqual", tableName: filename, bundle: Bundle.main, value: "Target <=%@", comment: "statistics target less than or equal to value")
    }()

    static let statisticsTargetGreaterThanOrEqual = {
        return NSLocalizedString("common_statistics_targetGreaterThanOrEqual", tableName: filename, bundle: Bundle.main, value: "Target >=%@", comment: "statistics target greater than or equal to value")
    }()

    static let statisticsAmbulatoryGlucoseProfile = {
        return NSLocalizedString("common_statistics_ambulatoryGlucoseProfile", tableName: filename, bundle: Bundle.main, value: "Ambulatory Glucose Profile", comment: "statistics AGP chart title")
    }()

    static let statisticsInsufficientAGPData = {
        return NSLocalizedString("common_statistics_insufficientAGPData", tableName: filename, bundle: Bundle.main, value: "Insufficient data for AGP percentile chart", comment: "statistics AGP empty chart message")
    }()

    static let statisticsInsufficientData = {
        return NSLocalizedString("common_statistics_insufficientData", tableName: filename, bundle: Bundle.main, value: "Insufficient data", comment: "statistics chart empty message")
    }()

    static let statisticsEstimatedA1cTrend = {
        return NSLocalizedString("common_statistics_estimatedA1cTrend", tableName: filename, bundle: Bundle.main, value: "Estimated HbA1c trend", comment: "statistics estimated HbA1c trend chart title")
    }()

    static let statisticsCVTrend = {
        return NSLocalizedString("common_statistics_cvTrend", tableName: filename, bundle: Bundle.main, value: "CV trend", comment: "statistics coefficient of variation trend chart title")
    }()

    static let statisticsDailyPattern = {
        return NSLocalizedString("common_statistics_dailyPattern", tableName: filename, bundle: Bundle.main, value: "Daily Pattern", comment: "statistics daily pattern chart title")
    }()

    static let statisticsAverageFormat = {
        return NSLocalizedString("common_statistics_averageFormat", tableName: filename, bundle: Bundle.main, value: "Average %@", comment: "statistics average value format")
    }()

    static let statisticsDailyPatternFooter = {
        return NSLocalizedString("common_statistics_dailyPatternFooter", tableName: filename, bundle: Bundle.main, value: "Bars show daily percentage in 70-180 mg/dL range. The dashed line marks the 70% clinical target.", comment: "statistics daily pattern chart footer")
    }()

    static let statisticsDailySummary = {
        return NSLocalizedString("common_statistics_dailySummary", tableName: filename, bundle: Bundle.main, value: "Daily Summary", comment: "statistics daily summary section title")
    }()

    static let statisticsBestDay = {
        return NSLocalizedString("common_statistics_bestDay", tableName: filename, bundle: Bundle.main, value: "Best Day", comment: "statistics best day tile title")
    }()

    static let statisticsMostLow = {
        return NSLocalizedString("common_statistics_mostLow", tableName: filename, bundle: Bundle.main, value: "Most Low", comment: "statistics most low day tile title")
    }()

    static let statisticsMostHigh = {
        return NSLocalizedString("common_statistics_mostHigh", tableName: filename, bundle: Bundle.main, value: "Most High", comment: "statistics most high day tile title")
    }()

    static let statisticsNoDataTitle = {
        return NSLocalizedString("common_statistics_noDataTitle", tableName: filename, bundle: Bundle.main, value: "No Statistics Available", comment: "statistics empty state title")
    }()

    static let statisticsNoDataMessage = {
        return NSLocalizedString("common_statistics_noDataMessage", tableName: filename, bundle: Bundle.main, value: "There is not enough stored CGM data for this period.", comment: "statistics empty state message")
    }()

    static let reportGenerateTitle = {
        return NSLocalizedString("common_report_generateTitle", tableName: filename, bundle: Bundle.main, value: "Generate Report", comment: "generate report screen title and button")
    }()

    static let reportGeneratingStatus = {
        return NSLocalizedString("common_report_generatingStatus", tableName: filename, bundle: Bundle.main, value: "Generating clinical report...", comment: "generate report progress message")
    }()

    static let reportGenerationFailedTitle = {
        return NSLocalizedString("common_report_generationFailedTitle", tableName: filename, bundle: Bundle.main, value: "Report generation failed", comment: "generate report failure alert title")
    }()

    static let reportPatientName = {
        return NSLocalizedString("common_report_patientName", tableName: filename, bundle: Bundle.main, value: "Patient Name", comment: "generate report patient name row")
    }()

    static let reportPatientNamePlaceholder = {
        return NSLocalizedString("common_report_patientNamePlaceholder", tableName: filename, bundle: Bundle.main, value: "Patient name", comment: "generate report patient name placeholder")
    }()

    static let reportPatientID = {
        return NSLocalizedString("common_report_patientID", tableName: filename, bundle: Bundle.main, value: "Patient ID", comment: "generate report patient id row")
    }()

    static let reportPatientIDPlaceholder = {
        return NSLocalizedString("common_report_patientIDPlaceholder", tableName: filename, bundle: Bundle.main, value: "Medical record / patient ID", comment: "generate report patient id placeholder")
    }()

    static let reportNotSet = {
        return NSLocalizedString("common_report_notSet", tableName: filename, bundle: Bundle.main, value: "Not Set", comment: "generate report unset row placeholder")
    }()

    static let reportPatientSection = {
        return NSLocalizedString("common_report_patientSection", tableName: filename, bundle: Bundle.main, value: "Patient", comment: "generate report patient section title")
    }()

    static let reportPatientFooter = {
        return NSLocalizedString("common_report_patientFooter", tableName: filename, bundle: Bundle.main, value: "Patient details are stored locally on this device and printed in the report header.", comment: "generate report patient section footer")
    }()

    static let reportPeriod = {
        return NSLocalizedString("common_report_period", tableName: filename, bundle: Bundle.main, value: "Report Period", comment: "generate report period row and screen title")
    }()

    static let reportPaperSize = {
        return NSLocalizedString("common_report_paperSize", tableName: filename, bundle: Bundle.main, value: "Paper Size", comment: "generate report paper size row and screen title")
    }()

    static let reportLanguage = {
        return NSLocalizedString("common_report_language", tableName: filename, bundle: Bundle.main, value: "Language", comment: "generate report language row and screen title")
    }()

    static let reportPasswordToOpen = {
        return NSLocalizedString("common_report_passwordToOpen", tableName: filename, bundle: Bundle.main, value: "Password to Open", comment: "generate report password row and screen title")
    }()

    static let reportNone = {
        return NSLocalizedString("common_report_none", tableName: filename, bundle: Bundle.main, value: "None", comment: "generate report none placeholder")
    }()

    static let reportOptions = {
        return NSLocalizedString("common_report_options", tableName: filename, bundle: Bundle.main, value: "Report Options", comment: "generate report options section title")
    }()

    static let reportWillBePasswordProtected = {
        return NSLocalizedString("common_report_willBePasswordProtected", tableName: filename, bundle: Bundle.main, value: "Report will be password protected", comment: "generate report password enabled status")
    }()

    static let reportWillNotBePasswordProtected = {
        return NSLocalizedString("common_report_willNotBePasswordProtected", tableName: filename, bundle: Bundle.main, value: "Report will not be password protected", comment: "generate report password disabled status")
    }()

    static let reportPasswordFieldPlaceholder = {
        return NSLocalizedString("common_report_passwordFieldPlaceholder", tableName: filename, bundle: Bundle.main, value: "Password to open PDF", comment: "generate report password field placeholder")
    }()

    static let reportPasswordConfirmationPlaceholder = {
        return NSLocalizedString("common_report_passwordConfirmationPlaceholder", tableName: filename, bundle: Bundle.main, value: "Enter password again", comment: "generate report confirm password field placeholder")
    }()

    static let reportPasswordFooter = {
        return NSLocalizedString("common_report_passwordFooter", tableName: filename, bundle: Bundle.main, value: "This password is only used for the next generated PDF and is not stored.", comment: "generate report password editor footer")
    }()

    static let reportNotEnoughData = {
        return NSLocalizedString("common_report_notEnoughData", tableName: filename, bundle: Bundle.main, value: "Not enough data", comment: "generate report unavailable period message")
    }()

    static let reportUnableToPrepareTitle = {
        return NSLocalizedString("common_report_unableToPrepareTitle", tableName: filename, bundle: Bundle.main, value: "Unable to prepare report", comment: "report preview share preparation failure title")
    }()

    static let reportShareAccessibility = {
        return NSLocalizedString("common_report_shareAccessibility", tableName: filename, bundle: Bundle.main, value: "Share Report", comment: "report preview share button accessibility label")
    }()

    static let reportPeriodTitleFormat = {
        return NSLocalizedString("common_report_periodTitleFormat", tableName: filename, bundle: Bundle.main, value: "%d day Report", comment: "report preview title without patient, parameter is report period days")
    }()

    static let reportPatientPeriodTitleFormat = {
        return NSLocalizedString("common_report_patientPeriodTitleFormat", tableName: filename, bundle: Bundle.main, value: "%@'s %@", comment: "report preview title with patient and period title")
    }()

    static let reportPasswordProtectionOpenError = {
        return NSLocalizedString("common_report_passwordProtectionOpenError", tableName: filename, bundle: Bundle.main, value: "The report PDF could not be opened for password protection.", comment: "report preview password protection source PDF open error")
    }()

    static let reportPasswordProtectionWriteError = {
        return NSLocalizedString("common_report_passwordProtectionWriteError", tableName: filename, bundle: Bundle.main, value: "The password-protected report PDF could not be created.", comment: "report preview password protection write error")
    }()
    
    static let dontShowAgain = {
        return NSLocalizedString("common_dontshowagain", tableName: filename, bundle: Bundle.main, value: "Don't Show Again", comment: "don't show again")
    }()
    
    static let enabled = {
        return NSLocalizedString("common_enabled", tableName: filename, bundle: Bundle.main, value: "Enabled", comment: "enabled")
    }()
    
    static let disabled = {
        return NSLocalizedString("common_disabled", tableName: filename, bundle: Bundle.main, value: "Disabled", comment: "disabled")
    }()
    
    static let notRequired = {
        return NSLocalizedString("common_notRequired", tableName: filename, bundle: Bundle.main, value: "Not required", comment: "not required")
    }()
    
    static let next = {
        return NSLocalizedString("common_next", tableName: filename, bundle: Bundle.main, value: "Next", comment: "next")
    }()
    
    static let checking = {
        return NSLocalizedString("common_checking", tableName: filename, bundle: Bundle.main, value: "Checking...", comment: "checking")
    }()
    
    static let notAvailable = {
        return NSLocalizedString("common_notAvailable", tableName: filename, bundle: Bundle.main, value: "Not Available", comment: "not available")
    }()
}
