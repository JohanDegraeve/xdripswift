import Foundation

/// all texts related to treatmentss (2 views)
enum Texts_TreatmentsView {
	static private let filename = "Treatments"

	static let treatmentsTitle:String = {
		return NSLocalizedString("treatments_title", tableName: filename, bundle: Bundle.main, value: "Treatments", comment: "Title of treatments view.")
	}()
	
	static let newButton:String = {
		return NSLocalizedString("treatments_new_button", tableName: filename, bundle: Bundle.main, value: "New", comment: "New button text.")
	}()
	
	static let newEntryTitle:String = {
		return NSLocalizedString("treatments_new_entry", tableName: filename, bundle: Bundle.main, value: "New Entry", comment: "New entry view title.")
	}()
	
	static let carbsWithUnit:String = {
		return NSLocalizedString("treatments_carbs_with_unit", tableName: filename, bundle: Bundle.main, value: "Carbs (g):", comment: "Carbs with unit.")
	}()
	
	static let insulinWithUnit:String = {
		return NSLocalizedString("treatments_insulin_with_unit", tableName: filename, bundle: Bundle.main, value: "Insulin (U):", comment: "Insulin with unit.")
	}()
	
	static let exerciseWithUnit:String = {
		return NSLocalizedString("treatments_exercise_with_unit", tableName: filename, bundle: Bundle.main, value: "Exercise (min):", comment: "Exercise with unit.")
	}()

	static let success:String = {
		return NSLocalizedString("treatments_success", tableName: filename, bundle: Bundle.main, value: "Success", comment: "Success.")
	}()

	static let uploadCompleted:String = {
		return NSLocalizedString("treatments_upload_complete", tableName: filename, bundle: Bundle.main, value: "Upload completed.", comment: "Upload completed.")
	}()
	
}
