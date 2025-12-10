import UIKit

// MARK: - Setting

/// a case per type of attribute that can be set in an AlerSettingsView
private enum Setting: Int, CaseIterable {
    // case value must be second-to-last in the series !! because it is not shown if the alertkind doesn't need it
    // case triggerValue must be the last in the series because some alerts have value but not triggerValue
    
    /// is alert disabled?
    case isDisabled = 0
    /// as of when is the alert applicable
    case start = 1
    /// alertType
    case alertType = 2
    /// value
    case value = 3
    /// optional trigger value (optional depending on alert
    case triggerValue = 4
}

// MARK: - AlertSettingsViewControllerData

/// AlertSettingsViewController and NewAlertSettingsViewController have similar functionality, ie the first is about updating an existing alertEntry, the other is about creating a new one. The class AlertSettingsViewControllerData has the common code
///
/// AlertSettingsViewController is doing a performsegue towards NewAlertSettingsViewController. That only works with different UIViewControllers (that's why it's two), but the functionality in it is 90% the same.
///
/// to avoid code duplication, all relevant code is written in the class AlertSettingsViewControllerData, which conforms to the protocols UITableViewDataSource, UITableViewDelegate
///
/// the classes AlertSettingsViewController and NewAlertSettingsViewController have a property of type AlertSettingsViewControllerData, and the tableView in each of them uses that property as delegate and datasource
class AlertSettingsViewControllerData: NSObject, UITableViewDataSource, UITableViewDelegate {
    // MARK: - Public properties
    
    /// isDisabled of alertEntry being modified
    public var isDisabled: Bool
    /// start of alertEntry being modified
    public var start: Int16
    /// value of alertEntry being modified
    public var value: Int16
    /// triggerValue of alertEntry being modified
    public var triggerValue: Int16
    /// alertKind of alertEntry being modified
    public var alertKind: Int16
    /// alertType of alertEntry being modified, default nil because it can't be initialized
    public var alertType: AlertType
    /// when modifying the start value, this is the minimum value
    public var minimumStart: Int16
    
    /// a reference to the UIViewController
    public var uIViewController: UIViewController
    
    /// coredatamanager
    public var coreDataManager: CoreDataManager
    
    // MARK: - Private properties
    
    /// will be used to compare original isDisabled to changed isDisabled, to detect changes on the screen
    private let tempIsDisabled: Bool
    /// will be used to compare original value to changed value, to detect changes on the screen
    private let tempStart: Int16
    /// will be used to compare original value to changed value, to detect changes on the screen
    private let tempValue: Int16
    /// will be used to compare original triggerValue to changed triggerValue, to detect changes on the screen
    private let tempTriggerValue: Int16
    /// will be used to compare original value to changed value, to detect changes on the screen
    private let tempAlertKind: Int16
    /// will be used to compare original value to changed value, to detect changes on the screen
    private let tempAlertType: AlertType
    /// when modifying the start value , this is the maximum value
    public var maximumStart: Int16 = (24 * 60) - 1 // default one minute before midnight
    
    /// when user changes properties, before pressing save button, this function will be called, can be set by AlertSettingsViewController which can assign to closure that disables "Add" button
    private var toCallWhenUserChangesProperties: (() -> ())?
    
    /// user may have changed some properties, but changes them back to original value, AlertSettingsViewController can re-enable the add button and even disable the save button
    private var toCallWhenUserResetsProperties: (() -> ())?

    // MARK: - initializer
    
    /// initializer
    init(isDisabled: Bool, start: Int16, value: Int16, triggerValue: Int16, alertKind: Int16, alertType: AlertType, minimumStart: Int16, maximumStart: Int16, uIViewController: UIViewController, toCallWhenUserResetsProperties: (() -> ())?, toCallWhenUserChangesProperties: (() -> ())?, coreDataManager: CoreDataManager) {
        // initialze all parameters
        self.isDisabled = isDisabled
        self.start = start
        self.value = value
        self.triggerValue = triggerValue
        self.alertKind = alertKind
        self.alertType = alertType
        
        // initialze all temp variables
        self.tempIsDisabled = isDisabled
        self.tempStart = start
        self.tempValue = value
        self.tempTriggerValue = triggerValue
        self.tempAlertKind = alertKind
        self.tempAlertType = alertType
        
        // intialize toCallWhenUserChangesProperties and toCallWhenUserResetsProperties
        self.toCallWhenUserChangesProperties = toCallWhenUserChangesProperties
        self.toCallWhenUserResetsProperties = toCallWhenUserResetsProperties
        
        self.minimumStart = minimumStart
        self.maximumStart = maximumStart
        self.uIViewController = uIViewController
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - private helper functions
    
    // will check if properties have changed, if yes calls toCallWhenUserChangesProperties, if not calls toCallWhenUserResetsProperties
    private func checkIfPropertiesChanged() {
        if isDisabled == tempIsDisabled && start == tempStart && value == tempValue && triggerValue == tempTriggerValue && alertKind == tempAlertKind && alertType.name == tempAlertType.name {
            if let toCallWhenUserResetsProperties = toCallWhenUserResetsProperties {
                toCallWhenUserResetsProperties()
            }
        } else {
            if let toCallWhenUserChangesProperties = toCallWhenUserChangesProperties {
                toCallWhenUserChangesProperties()
            }
        }
    }
}

// UITableViewDataSource and UITableViewDelegate protocol Methods
extension AlertSettingsViewControllerData {
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.textLabel?.textColor = ConstantsUI.tableViewHeaderTextColor
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // if the alert is not enabled, then just show the first row and hide the rest
        if isDisabled {
            return 1
        }
        
        // if no need to show alertvalue, then return count - 2
        // if need to show alertValue, but not alertTriggerValue, then return count - 1, trigger value is the last row, it won't be shown
        if AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).needsAlertValue() || alertType.enabled {
            if AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).needsAlertTriggerValue() {
                return Setting.allCases.count
            } else {
                return Setting.allCases.count - 1
            }
        } else {
            return Setting.allCases.count - 2
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("AlertSettingsViewControllerData cellforrowat, Unexpected Table View Cell ") }
        
        guard let setting = Setting(rawValue: indexPath.row) else { fatalError("AlertSettingsViewControllerData cellForRowAt, Unexpected setting") }
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // it's needed here at least two times, so get alertKind as AlertKind instance
        let alertKindAsAlertKind = AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind)
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // configure the cell depending on setting
        switch setting {
        case .isDisabled:
            cell.textLabel?.text = Texts_Common.enabled
            cell.detailTextLabel?.text = isDisabled ? "\u{26A0}" : nil
            cell.accessoryType = .none
            cell.accessoryView = UISwitch(isOn: !isDisabled, action: { (isOn: Bool) in
                self.isDisabled = !isOn
                tableView.reloadSections(IndexSet(integer: 0), with: .none)
                // checkIfPropertiesChanged - this must be handled here and not at the usual didSelectRowAt call
                self.checkIfPropertiesChanged()
            })
            
        case .start:
            cell.textLabel?.text = Texts_Alerts.alertStart
            cell.detailTextLabel?.text = Int(start).convertMinutesToTimeAsString()
            if start == 0 { // alertEntry with start time 0, time can't be changed
                cell.accessoryType = .none
            } else {
                cell.accessoryType = .disclosureIndicator
                // set color of disclosureIndicator to ConstantsUI.disclosureIndicatorColor
                cell.accessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
            }

        case .value:
            // note that value will not be shown if alerttype not enabled or alertkind doesn't need a value, means if that's the case, setting will never be .value
            cell.textLabel?.text = Texts_Alerts.alertValue
            if alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) != "" {
                if alertKindAsAlertKind.valueIsABgValue() {
                    cell.detailTextLabel?.text = Double(value).mgDlToMmolAndToString(mgDl: isMgDl) + (alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) != "" ? (" " + alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType)) : "")
                } else {
                    cell.detailTextLabel?.text = value.description + (alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) != "" ? (" " + alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType)) : "")
                }
            } else {
                cell.detailTextLabel?.text = value.description
            }
            
            cell.accessoryType = .disclosureIndicator
            // set color of disclosureIndicator to ConstantsUI.disclosureIndicatorColor
            cell.accessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
            
        case .triggerValue:
            // note that trigger value will not be shown if alertkind doesn't need a trigger value
            var triggerValueText = ""
            switch alertKindAsAlertKind { // it's overkill using a switch for this as there are only two possible conditions at the moment
            case .fastdrop:
                triggerValueText = Texts_Alerts.alertWhenBelowValue
            case .fastrise:
                triggerValueText = Texts_Alerts.alertWhenAboveValue
            default:
                break
            }
            
            cell.textLabel?.text = triggerValueText
            if alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) != "" {
                if alertKindAsAlertKind.valueIsABgValue() {
                    cell.detailTextLabel?.text = Double(triggerValue).mgDlToMmolAndToString(mgDl: isMgDl) + (alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) != "" ? (" " + alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType)) : "")
                } else {
                    cell.detailTextLabel?.text = triggerValue.description + (alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) != "" ? (" " + alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType)) : "")
                }
            } else {
                cell.detailTextLabel?.text = value.description
            }
            
            cell.accessoryType = .disclosureIndicator
            // set color of disclosureIndicator to ConstantsUI.disclosureIndicatorColor
            cell.accessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
            
        case .alertType:
            cell.textLabel?.text = Texts_Alerts.alerttype
            cell.detailTextLabel?.text = AlertSettingsViewControllerData.getAlertType(alertType: alertType).name
            cell.accessoryType = .disclosureIndicator
            // set color of disclosureIndicator to ConstantsUI.disclosureIndicatorColor
            cell.accessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
        }
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // only 1 section, namely the list of settings for an alertentry
        return 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let setting = Setting(rawValue: indexPath.row) else { fatalError("AlertSettingsViewControllerData didSelectRowAt, Unexpected setting") }
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // it's needed here at least two times, so get alertKind as AlertKind instance
        let alertKindAsAlertKind = AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind)

        // configure the cell depending on setting
        switch setting {
        case .isDisabled:
            break // status is changed only when clicking the switch, not the row
            
        case .start:
            if start == 0 { // alertEntry with start time 0, time can't be changed
                return
            }
            
            // create Date that represents now, locally, at 00:00
            let nowAt000 = Date().toMidnight()
            
            // the actual date of start is nowAt000 + the number of minutes in the entry
            let startAsDate = Date(timeInterval: TimeInterval(Double(start) * 60.0), since: nowAt000)
            
            // create date pickerviewdata
            let datePickerViewData = DatePickerViewData(withMainTitle: alertKindAsAlertKind.alertTitle(), withSubTitle: Texts_Alerts.alertStart, datePickerMode: .time, date: startAsDate, minimumDate: Date(timeInterval: TimeInterval(Double(minimumStart) * 60.0), since: nowAt000), maximumDate: Date(timeInterval: TimeInterval(Double(maximumStart) * 60.0), since: nowAt000), okButtonText: nil, cancelButtonText: nil, onOkClick: { date in
                
                // set new start value
                self.start = Int16(date.minutesSinceMidNightLocalTime())
                
                // table may need reload to show new value
                tableView.reloadRows(at: [IndexPath(row: Setting.start.rawValue, section: 0)], with: .none)
                
                // checkIfPropertiesChanged
                self.checkIfPropertiesChanged()
                
            }, onCancelClick: nil)
            
            // present datepickerview
            DatePickerViewControllerModal.displayDatePickerViewController(datePickerViewData: datePickerViewData, parentController: uIViewController)
            
        case .value:
            // for keyboard type : normally keyboard type is numeric only, except if value is bg value, and userdefaults is mmol
            var keyboardType = UIKeyboardType.numberPad
            if AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).valueIsABgValue(), !UserDefaults.standard.bloodGlucoseUnitIsMgDl {
                keyboardType = .decimalPad
            }
            let alert = UIAlertController(title: AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).alertTitle(), message: Texts_Alerts.changeAlertValue + " (" + alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) + ")", keyboardType: keyboardType, text: Double(value).mgDlToMmolAndToString(mgDl: isMgDl || !AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).valueIsABgValue()), placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (text: String) in
                
                if var newValue = text.toDouble() {
                    var newValueIsValid = true
                    if AlertSettingsViewControllerData.getAlertKind(alertKind: self.alertKind).valueIsABgValue() {
                        // now we've validated the BG value, convert it to mmol if required
                        newValue = newValue.mmolToMgdl(mgDl: isMgDl)
                        // first check that the value, as it is a BG value and now in mg/dL, is above 0 and below the maximum BG value limits (this value could be a small amount for fast rise/drop
                        newValueIsValid = newValue > 0.0 && newValue < ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue
                    }
                    
                    if newValue < 32767.0, newValueIsValid {
                        self.value = Int16(newValue)
                        tableView.reloadRows(at: [IndexPath(row: Setting.value.rawValue, section: 0)], with: .none)
                        // checkIfPropertiesChanged
                        self.checkIfPropertiesChanged()
                    }
                }
                
            }, cancelHandler: nil)
            
            // present the alert
            uIViewController.present(alert, animated: true, completion: nil)
            
        case .triggerValue:
            // for keyboard type : normally keyboard type is numeric only, except if value is bg value, and userdefaults is mmol
            var keyboardType = UIKeyboardType.numberPad
            if AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).valueIsABgValue(), !UserDefaults.standard.bloodGlucoseUnitIsMgDl {
                keyboardType = .decimalPad
            }
            
            // note that trigger value will not be shown if alertkind doesn't need a trigger value
            var triggerValueText = ""
            switch alertKindAsAlertKind { // it's overkill using a switch for this as there are only two possible conditions at the moment
            case .fastdrop:
                triggerValueText = Texts_Alerts.alertWhenBelowValue
            case .fastrise:
                triggerValueText = Texts_Alerts.alertWhenAboveValue
            default:
                break
            }
            
            let alert = UIAlertController(title: AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).alertTitle(), message: triggerValueText + " (" + alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) + ")", keyboardType: keyboardType, text: Double(triggerValue).mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl || !AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).valueIsABgValue()), placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (text: String) in
                
                if var newValue = text.toDouble() {
                    var newValueIsValid = true
                    if AlertSettingsViewControllerData.getAlertKind(alertKind: self.alertKind).valueIsABgValue() {
                        // now we've validated the BG value, convert it to mmol if required
                        newValue = newValue.mmolToMgdl(mgDl: isMgDl)
                        // first check that the value, as it is a BG value and now in mg/dL, is within BG value limits
                        newValueIsValid = newValue > ConstantsCalibrationAlgorithms.minimumBgReadingCalculatedValue && newValue < ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue
                    }
                    
                    if newValue < 32767.0, newValueIsValid {
                        self.triggerValue = Int16(newValue)
                        tableView.reloadRows(at: [IndexPath(row: Setting.triggerValue.rawValue, section: 0)], with: .none)
                        // checkIfPropertiesChanged
                        self.checkIfPropertiesChanged()
                    }
                }
                
            }, cancelHandler: nil)
            
            // present the alert
            uIViewController.present(alert, animated: true, completion: nil)
            
        case .alertType:
            
            // will open a pickerview with names of all available alerttypes and let user select an alerttype
            
            // first get all alerttypes, and store name in seperate array
            let allAlertTypes = AlertTypesAccessor(coreDataManager: coreDataManager).getAllAlertTypes()
            var allAlertTypeNames = [String]()
            for alertType in allAlertTypes {
                allAlertTypeNames.append(alertType.name)
            }
            
            // select index of current alerttype
            var selectedRow = 0
            for (index, alertTypeName) in allAlertTypeNames.enumerated() {
                if alertTypeName == alertType.name {
                    selectedRow = index
                }
            }
            
            // configure pickerViewData
            let pickerViewData = PickerViewData(withMainTitle: Texts_Alerts.alerttype, withSubTitle: nil, withData: allAlertTypeNames, selectedRow: selectedRow, withPriority: nil, actionButtonText: nil, cancelButtonText: nil, onActionClick: { (_ index: Int) in
                
                self.alertType = allAlertTypes[index]
                tableView.reloadRows(at: [IndexPath(row: Setting.alertType.rawValue, section: 0)], with: .none)
                // checkIfPropertiesChanged
                self.checkIfPropertiesChanged()
                
            }, onCancelClick: {}, didSelectRowHandler: nil)
            
            // create and present pickerviewcontroller
            PickerViewControllerModal.displayPickerViewController(pickerViewData: pickerViewData, parentController: uIViewController)
        }
    }
}

// helper functions
extension AlertSettingsViewControllerData {
    /// helper function to get AlertKind from int16, if not possible then fatal error is thrown
    public class func getAlertKind(alertKind: Int16) -> AlertKind {
        if let alertKind = AlertKind(rawValue: Int(alertKind)) { return alertKind }
        else { fatalError("in AlertSettingsViewControllerData, getAlertKind, could not create AlertKind from Int16 value") }
    }
    
    /// helper to check if alertType exists and if yes return it unwrapped, else fatalerror
    public class func getAlertType(alertType: AlertType?) -> AlertType {
        if let alertType = alertType { return alertType }
        else { fatalError("in AlertSettingsViewControllerData, getAlertType, alertType is nil") }
    }
}
