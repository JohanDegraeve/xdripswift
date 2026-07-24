import Foundation

/// all texts related to treatments (2 views)
enum Texts_TreatmentsView {
	static private let filename = "Treatments"

	static let treatmentsTitle:String = {
		return NSLocalizedString("treatments_title", tableName: filename, bundle: Bundle.main, value: "Treatments", comment: "Title of treatments view.")
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

    static let note:String = {
        return NSLocalizedString("treatments_note", tableName: filename, bundle: Bundle.main, value: "Note", comment: "Free-form note treatment")
    }()

	static let questionMark:String = {
		return NSLocalizedString("treatments_question_mark", tableName: filename, bundle: Bundle.main, value: "?", comment: "Literally a question mark, used as unknown abbreviation.")
	}()

    static let cannotStoreFutureBGCheck:String = {
        return NSLocalizedString("treatments_cannotStoreFutureBGCheck", tableName: filename, bundle: Bundle.main, value: "You cannot store a BG Check in the future.\n\nIt will be stored at the actual time.", comment: "warn about trying to set a future bg value")
    }()

    static let enteredBy:String = {
        return NSLocalizedString("treatments_enteredBy", tableName: filename, bundle: Bundle.main, value: "Entered By", comment: "the name of the uploader device or app")
    }()

    static let addTreatmentTitle:String = {
        return NSLocalizedString("treatments_add_title", tableName: filename, bundle: Bundle.main, value: "Add Treatment", comment: "Title of add treatment view.")
    }()

    static let editTreatmentTitle:String = {
        return NSLocalizedString("treatments_edit_title", tableName: filename, bundle: Bundle.main, value: "Edit Treatment", comment: "Title of edit treatment view.")
    }()

    static let filterTreatmentsLabel:String = {
        return NSLocalizedString("treatments_filterTreatmentsLabel", tableName: filename, bundle: Bundle.main, value: "Filter", comment: "Section header above the treatment type filter chips.")
    }()

    static let noTreatmentsToShow:String = {
        return NSLocalizedString("treatments_noTreatmentsToShow", tableName: filename, bundle: Bundle.main, value: "No treatments to show for this date.", comment: "Shown when no treatments match the current date and filters.")
    }()

    static let type:String = {
        return NSLocalizedString("treatments_type", tableName: filename, bundle: Bundle.main, value: "Type", comment: "Treatment type label.")
    }()

    static let value:String = {
        return NSLocalizedString("treatments_value", tableName: filename, bundle: Bundle.main, value: "Value", comment: "Treatment value label.")
    }()

    static let notes:String = {
        return NSLocalizedString("treatments_notes", tableName: filename, bundle: Bundle.main, value: "Notes", comment: "Treatment note text label.")
    }()

    static let notePlaceholder:String = {
        return NSLocalizedString("treatments_notePlaceholder", tableName: filename, bundle: Bundle.main, value: "Enter note", comment: "Placeholder for a treatment note")
    }()

    static let deleteTreatment:String = {
        return NSLocalizedString("treatments_deleteTreatment", tableName: filename, bundle: Bundle.main, value: "Delete Treatment", comment: "Delete treatment button title.")
    }()

    static let invalidValueMessage:String = {
        return NSLocalizedString("treatments_invalidValueMessage", tableName: filename, bundle: Bundle.main, value: "Please enter a valid value greater than zero.", comment: "Shown when a treatment value is invalid.")
    }()

    static let invalidNoteMessage:String = {
        return NSLocalizedString("treatments_invalidNoteMessage", tableName: filename, bundle: Bundle.main, value: "Please enter a note.", comment: "Shown when a note treatment is missing text.")
    }()

    static let saveTreatment:String = {
        return NSLocalizedString("treatments_saveTreatment", tableName: filename, bundle: Bundle.main, value: "Save", comment: "Save treatment button title.")
    }()

}
