import Foundation

/// all texts related to treatments (2 views)
enum Texts_TreatmentsView {
	static private let filename = "Treatments"

	static let treatmentsTitle:String = {
		return NSLocalizedString("treatments_title", tableName: filename, bundle: Bundle.main, value: "Treatments", comment: "Title of treatments view.")
	}()
	
	static let newButton:String = {
		return NSLocalizedString("treatments_new_button", tableName: filename, bundle: Bundle.main, value: "New", comment: "New button text.")
	}()
	
	static let newEntryTitle:String = {
		return NSLocalizedString("treatments_new_entry", tableName: filename, bundle: Bundle.main, value: "New Treatment", comment: "New entry view title.")
	}()

	static let carbsUnit:String = {
		return NSLocalizedString("treatments_carbs_unit", tableName: filename, bundle: Bundle.main, value: "g", comment: "Carbs unit.")
	}()
	
	static let insulinUnit:String = {
		return NSLocalizedString("treatments_insulin_unit", tableName: filename, bundle: Bundle.main, value: "U", comment: "Insulin unit.")
	}()
	
	static let exerciseUnit:String = {
		return NSLocalizedString("treatments_exercise_unit", tableName: filename, bundle: Bundle.main, value: "mins", comment: "Exercise unit.")
	}()
    
    static let basalRateUnit:String = {
        return NSLocalizedString("treatments_basal_rate_unit", tableName: filename, bundle: Bundle.main, value: "U/hr", comment: "Basal rate unit.")
    }()

	static let carbs:String = {
		return NSLocalizedString("treatments_carbs", tableName: filename, bundle: Bundle.main, value: "Carbs", comment: "Carbs.")
	}()
	
	static let insulin:String = {
		return NSLocalizedString("treatments_insulin", tableName: filename, bundle: Bundle.main, value: "Bolus", comment: "Bolus.")
	}()
	
	static let exercise:String = {
		return NSLocalizedString("treatments_exercise", tableName: filename, bundle: Bundle.main, value: "Exercise", comment: "Exercise.")
	}()
    
    static let bgCheck:String = {
        return NSLocalizedString("treatments_bgcheck", tableName: filename, bundle: Bundle.main, value: "BG Check", comment: "Blood Glucose Check")
    }()
    
    static let basalRate:String = {
        return NSLocalizedString("treatments_basalRate", tableName: filename, bundle: Bundle.main, value: "Temp Basal", comment: "Temp Basal")
    }()
    
    static let siteChange:String = {
        return NSLocalizedString("treatments_siteChange", tableName: filename, bundle: Bundle.main, value: "Site Change", comment: "Site Change")
    }()
    
    static let sensorStart:String = {
        return NSLocalizedString("treatments_sensorStart", tableName: filename, bundle: Bundle.main, value: "Sensor Start", comment: "Sensor Start")
    }()
    
    static let pumpBatteryChange:String = {
        return NSLocalizedString("treatments_pumpBatteryChange", tableName: filename, bundle: Bundle.main, value: "Pump Battery Change", comment: "Pump Battery Change")
    }()

	static let questionMark:String = {
		return NSLocalizedString("treatments_question_mark", tableName: filename, bundle: Bundle.main, value: "?", comment: "Literally a question mark, used as unknown abbreviation.")
	}()
    
    static let filterTreatmentsLabel:String = {
        return NSLocalizedString("treatments_filterTreatmentsLabel", tableName: filename, bundle: Bundle.main, value: "Filter:", comment: "filter the treatments by type")
    }()
    
    static let cannotStoreFutureBGCheck:String = {
        return NSLocalizedString("treatments_cannotStoreFutureBGCheck", tableName: filename, bundle: Bundle.main, value: "You cannot store a BG Check in the future.\n\nIt will be stored at the actual time.", comment: "warn about trying to set a future bg value")
    }()
    
    static let enteredBy:String = {
        return NSLocalizedString("treatments_enteredBy", tableName: filename, bundle: Bundle.main, value: "Entered By", comment: "the name of the uploader device or app")
    }()

}
