import UIKit

/// a case per type of attribute that can be set in an AlerSettingsView
fileprivate enum Setting:Int, CaseIterable {
    // case value must be the last in the series !! because it is not shown if the alertkind
    
    /// as of when is the alert applicable
    case start = 0
    /// alerttype
    case alertType = 1
    /// value
    case value = 2
}

/// AlertSettingsViewController and NewAlertSettingsViewController have similar functionality, ie the first is about updating an existing alertEntry, the other is about creating a new one. The class AlertSettingsViewControllerData has the common code
///
/// AlertSettingsViewController is doing a performsegue towards NewAlertSettingsViewController. That only works with different UIViewControllers (that's why it's two), but the functionality in it is 90% the same.
///
/// to avoid code duplication, all relevant code is written in the class AlertSettingsViewControllerData, which conforms to the protocols UITableViewDataSource, UITableViewDelegate
///
/// the classes AlertSettingsViewController and NewAlertSettingsViewController have a property of type AlertSettingsViewControllerData, and the tableView in each of them uses that property as delegate and datasource
class AlertSettingsViewControllerData: NSObject, UITableViewDataSource, UITableViewDelegate  {
    
    // MARK:- properties
    
    // following properties are used to store alertEntry attributes which can be modified.
    /// start of alertEntry being modified
    public var start:Int16
    /// will be used to compare original value to changed value, to detect changes on the screen
    private let tempStart:Int16
    
    /// value of alertEntry being modified
    public var value:Int16
    
    /// will be used to compare original value to changed value, to detect changes on the screen
    private let tempValue:Int16
    
    /// alertKind of alertEntry being modified
    public var alertKind:Int16
    
    /// will be used to compare original value to changed value, to detect changes on the screen
    private let tempAlertKind:Int16
    
    /// alertType of alertEntry being modified, default nil because it can't be initialized
    public var alertType:AlertType
    
    /// will be used to compare original value to changed value, to detect changes on the screen
    private let tempAlertType:AlertType
    
    /// when modifying the start value, this is the minimum value
    public var minimumStart:Int16
    
    /// when modifying the start value , this is the maximum value
    public var maximumStart:Int16 = Int16(24 * 60 - 1) // default one minute before midnight
    
    /// a reference to the UIViewController
    public var uIViewController:UIViewController
    
    /// coredatamanager
    public var coreDataManager:CoreDataManager
    
    /// when user changes properties, before pressing save button, this function will be called, can be set by AlertSettingsViewController which can assign to closure that disables "Add" button
    private var toCallWhenUserChangesProperties:(() -> ())?
    
    /// user may have changed some properties, but changes them back to original value, AlertSettingsViewController can re-enable the add button and even disable the save button
    private var toCallWhenUserResetsProperties:(() -> ())?

    // MARK:- initializer
    
    /// initializer
    init(start:Int16, value:Int16, alertKind:Int16, alertType:AlertType, minimumStart:Int16, maximumStart:Int16, uIViewController:UIViewController, toCallWhenUserResetsProperties:(() -> ())?, toCallWhenUserChangesProperties:(() -> ())?, coreDataManager:CoreDataManager) {
        
        // initialze all parameters, and also temp variables
        self.start = start
        self.tempStart = start
        self.value = value
        self.tempValue = value
        self.alertKind = alertKind
        self.tempAlertKind = alertKind
        self.alertType = alertType
        self.tempAlertType = alertType
        
        // intialize toCallWhenUserChangesProperties and toCallWhenUserResetsProperties
        self.toCallWhenUserChangesProperties = toCallWhenUserChangesProperties
        self.toCallWhenUserResetsProperties = toCallWhenUserResetsProperties
        
        self.minimumStart = minimumStart
        self.maximumStart = maximumStart
        self.uIViewController = uIViewController
        self.coreDataManager = coreDataManager
    }
    
    // MARK:- private helper functions
    
    // will check if properties have changed, if yes calls toCallWhenUserChangesProperties, if not calls toCallWhenUserResetsProperties
    private func checkIfPropertiesChanged() {
        if (start == tempStart && value == tempValue && alertKind == tempAlertKind && alertType.name == tempAlertType.name) {
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
        
        // if no need to show alertvalue, then return count 1 less, value is the last row, it won't be shown
        if AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).needsAlertValue() || alertType.enabled {
            return Setting.allCases.count
        } else {
            return Setting.allCases.count - 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("AlertSettingsViewControllerData cellforrowat, Unexpected Table View Cell ") }
        
        guard let setting = Setting(rawValue: indexPath.row) else { fatalError("AlertSettingsViewControllerData cellForRowAt, Unexpected setting") }
        
        // it's needed here at least two times, so get alertKind as AlertKind instance
        let alertKindAsAlertKind = AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind)
        
        //let alertKind =
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // configure the cell depending on setting
        switch setting {
            
        case .start:
            cell.textLabel?.text = Texts_Alerts.alertStart
            cell.detailTextLabel?.text = Int(start).convertMinutesToTimeAsString()
            if start == 0 {// alertEntry with start time 0, time can't be changed
                cell.accessoryType = UITableViewCell.AccessoryType.none
            } else {
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                // set color of disclosureIndicator to ConstantsUI.disclosureIndicatorColor
                cell.accessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
            }
        case .value:
            // note that value will not be shown if alerttype not enabled or alertkind doesn't need a value, means if that's the case, setting will never be .value
            cell.textLabel?.text = Texts_Alerts.alertValue + (alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) != "" ? (" (" + alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) + ")"):"")
            if alertKindAsAlertKind.valueNeedsConversionToMmol() {
                cell.detailTextLabel?.text = Double(value).mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            } else {
                cell.detailTextLabel?.text = value.description
            }
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            // set color of disclosureIndicator to ConstantsUI.disclosureIndicatorColor
            cell.accessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
            
        case .alertType:
            cell.textLabel?.text = Texts_Alerts.alerttype
            cell.detailTextLabel?.text = AlertSettingsViewControllerData.getAlertType(alertType: alertType).name
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
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
        
        // it's needed here at least two times, so get alertKind as AlertKind instance
        let alertKindAsAlertKind = AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind)

        // configure the cell depending on setting
        switch setting {
        case .start:
            if start == 0 {// alertEntry with start time 0, time can't be changed
                return
            }
            
            // create Date that represents now, locally, at 00:00
            let nowAt000 = Date().toMidnight()
            
            // the actual date of start is nowAt000 + the number of minutes in the entry
            let startAsDate = Date(timeInterval: TimeInterval(Double(start) * 60.0), since: nowAt000)
            
            // create date pickerviewdata
            let datePickerViewData = DatePickerViewData(withMainTitle: alertKindAsAlertKind.alertTitle(), withSubTitle: Texts_Alerts.alertStart, datePickerMode: .time, date: startAsDate, minimumDate: Date(timeInterval: TimeInterval(Double(minimumStart) * 60.0), since: nowAt000), maximumDate: Date(timeInterval: TimeInterval(Double(maximumStart) * 60.0), since: nowAt000), okButtonText: nil, cancelButtonText: nil
                , onOkClick: {(date) in
                    
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
            if AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).valueNeedsConversionToMmol() && !UserDefaults.standard.bloodGlucoseUnitIsMgDl {
                keyboardType = .decimalPad
            }
            let alert = UIAlertController(title: AlertSettingsViewControllerData.getAlertKind(alertKind: alertKind).alertTitle(), message: Texts_Alerts.changeAlertValue + " (" + alertKindAsAlertKind.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType) + ")", keyboardType: keyboardType, text: Double(value).mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl || !AlertSettingsViewControllerData.getAlertKind(alertKind: self.alertKind).valueNeedsConversionToMmol()), placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (text:String) in
                
                if var asdouble = text.toDouble() {
                    
                    if !UserDefaults.standard.bloodGlucoseUnitIsMgDl && AlertSettingsViewControllerData.getAlertKind(alertKind: self.alertKind).valueNeedsConversionToMmol() {
                        asdouble = asdouble.mmolToMgdl()
                    }
                    
                    if asdouble < 32767.0 {
                        
                        self.value = Int16(asdouble)
                        tableView.reloadRows(at: [IndexPath(row: Setting.value.rawValue, section: 0)], with: .none)
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
            let pickerViewData = PickerViewData(withMainTitle: Texts_Alerts.alerttype, withSubTitle: nil, withData: allAlertTypeNames, selectedRow: selectedRow, withPriority: nil, actionButtonText: nil, cancelButtonText: nil, onActionClick: {(_ index: Int) in
                
                self.alertType = allAlertTypes[index]
                tableView.reloadRows(at: [IndexPath(row: Setting.alertType.rawValue, section: 0)], with: .none)
                // checkIfPropertiesChanged
                self.checkIfPropertiesChanged()
                
            }, onCancelClick: {}, didSelectRowHandler: nil)
            
            // TODO: crash here with modal
            // create and present pickerviewcontroller
            PickerViewControllerModal.displayPickerViewController(pickerViewData: pickerViewData, parentController: uIViewController)
            
        }
    }
}

// helper functions
extension AlertSettingsViewControllerData {
    /// helper function to get AlertKind from int16, if not possible then fatal error is thrown
    class public func getAlertKind(alertKind:Int16) -> AlertKind {
        if let alertKind = AlertKind(rawValue: Int(alertKind)) {return alertKind}
        else {fatalError("in AlertSettingsViewControllerData, getAlertKind, could not create AlertKind from Int16 value" )}
    }
    
    /// helper to check if alertType exists and if yes return it unwrapped, else fatalerror
    class public func getAlertType(alertType:AlertType?) -> AlertType {
        if let alertType = alertType {return alertType}
        else {fatalError("in AlertSettingsViewControllerData, getAlertType, alertType is nil" )}
    }
}
