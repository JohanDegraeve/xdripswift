import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    /// blood glucose  unit
    case bloodGlucoseUnit = 0
    
    /// choose between master and follower
    case masterFollower = 1
    
    /// show a clock at the bottom of the home screen when the screen lock is activated?
    case showClockWhenScreenIsLocked = 2
    
    /// show a countdown graphic for the sensor days if available?
    case showSensorCountdown = 3
    
    /// should reading be shown in notification
    case showReadingInNotification = 4
    
    /// - minimum time between two readings, for which notification should be created (in minutes)
    /// - except if there's been a disconnect, in that case this value is not taken into account
    case notificationInterval = 5
    
    /// show reading in app badge
    case showReadingInAppBadge = 6
    
    /// if reading is shown in app badge, should value be multiplied with 10 yes or no
    case multipleAppBadgeValueWith10 = 7
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewGeneralSettingsViewModel: SettingsViewModelProtocol {
    
    private var coreDataManager: CoreDataManager?
    
    init(coreDataManager: CoreDataManager?) {
        
        self.coreDataManager = coreDataManager
        
    }
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}

    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        // changing follower to master or master to follower requires changing ui for nightscout settings and transmitter type settings
        // the same applies when changing bloodGlucoseUnit, because off the seperate section with bgObjectives
        if (index == Setting.masterFollower.rawValue || index == Setting.bloodGlucoseUnit.rawValue) {return true}
        
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .bloodGlucoseUnit:
            return SettingsSelectedRowAction.callFunction(function: {
                
                UserDefaults.standard.bloodGlucoseUnitIsMgDl ? (UserDefaults.standard.bloodGlucoseUnitIsMgDl = false) : (UserDefaults.standard.bloodGlucoseUnitIsMgDl = true)
                
            })

        case .masterFollower:
            
            // switching from master to follower will set cgm transmitter to nil and stop the sensor. If there's a sensor active then it's better to ask for a confirmation, if not then do the change without asking confirmation

            if UserDefaults.standard.isMaster {
                
                if let coreDataManager = coreDataManager {
                    
                    if SensorsAccessor(coreDataManager: coreDataManager).fetchActiveSensor() != nil {

                        return .askConfirmation(title: Texts_Common.warning, message: Texts_SettingsView.warningChangeFromMasterToFollower, actionHandler: {
                            
                            UserDefaults.standard.isMaster = false
                            
                        }, cancelHandler: nil)

                    } else {
                        
                        // no sensor active
                        // set to follower
                        return SettingsSelectedRowAction.callFunction(function: {
                            UserDefaults.standard.isMaster = false
                        })
                        
                    }
                    
                } else {
                    
                    // coredata manager is nil, should normally not be the case
                    return SettingsSelectedRowAction.callFunction(function: {
                        UserDefaults.standard.isMaster = false
                    })

                }
                
                
            } else {
                
                // switching from follower to master
                return SettingsSelectedRowAction.callFunction(function: {
                    UserDefaults.standard.isMaster = true
                })

            }
            
        case .showReadingInNotification, .showReadingInAppBadge, .multipleAppBadgeValueWith10, .showClockWhenScreenIsLocked, .showSensorCountdown:
            return SettingsSelectedRowAction.nothing
            
        case .notificationInterval:
            
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.settingsviews_IntervalTitle, message: Texts_SettingsView.settingsviews_IntervalMessage, keyboardType: .numberPad, text: UserDefaults.standard.notificationInterval.description, placeHolder: "0", actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.notificationInterval = Int(interval)}}, cancelHandler: nil, inputValidator: nil)
            
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleGeneral
    }

    func numberOfRows() -> Int {
        
        // if unit is mmol and if show value in app badge is on and if showReadingInNotification is not on, then show also if to be multiplied by 10 yes or no
        // (if showReadingInNotification is on, then badge counter will be set via notification, in this case we can use NSNumber so we don't need to multiply by 10)
        if !UserDefaults.standard.bloodGlucoseUnitIsMgDl && UserDefaults.standard.showReadingInAppBadge && !UserDefaults.standard.showReadingInNotification {
            return Setting.allCases.count
        } else {
            return Setting.allCases.count - 1
        }
        
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .bloodGlucoseUnit:
            return Texts_SettingsView.labelSelectBgUnit
            
        case .masterFollower:
            return Texts_SettingsView.labelMasterOrFollower
            
        case .showClockWhenScreenIsLocked:
            return Texts_SettingsView.showClockWhenScreenIsLocked
            
        case .showSensorCountdown:
            return Texts_SettingsView.showSensorCountdown
            
        case .showReadingInNotification:
            return Texts_SettingsView.showReadingInNotification
            
        case .notificationInterval:
            return Texts_SettingsView.settingsviews_IntervalTitle
            
        case .showReadingInAppBadge:
            return Texts_SettingsView.labelShowReadingInAppBadge
            
        case .multipleAppBadgeValueWith10:
            return Texts_SettingsView.multipleAppBadgeValueWith10
            
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .bloodGlucoseUnit:
            return UITableViewCell.AccessoryType.none
    
        case .masterFollower:
            return UITableViewCell.AccessoryType.none
            
        case .showReadingInNotification, .showReadingInAppBadge, .multipleAppBadgeValueWith10, .showClockWhenScreenIsLocked, .showSensorCountdown:
            return UITableViewCell.AccessoryType.none
            
        case .notificationInterval:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .bloodGlucoseUnit:
            return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl:Texts_Common.mmol
            
        case .masterFollower:
            return UserDefaults.standard.isMaster ? Texts_SettingsView.master:Texts_SettingsView.follower
            
        case .showReadingInNotification, .showReadingInAppBadge, .multipleAppBadgeValueWith10, .showClockWhenScreenIsLocked, .showSensorCountdown:
            return nil
            
        case .notificationInterval:
            return UserDefaults.standard.notificationInterval.description
        }
    }
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showReadingInNotification:
            
            return UISwitch(isOn: UserDefaults.standard.showReadingInNotification, action: {(isOn:Bool) in UserDefaults.standard.showReadingInNotification = isOn})
            
        case .showReadingInAppBadge:

            return UISwitch(isOn: UserDefaults.standard.showReadingInAppBadge, action: {(isOn:Bool) in UserDefaults.standard.showReadingInAppBadge = isOn})

        case .multipleAppBadgeValueWith10:

            return UISwitch(isOn: UserDefaults.standard.multipleAppBadgeValueWith10, action: {(isOn:Bool) in UserDefaults.standard.multipleAppBadgeValueWith10 = isOn})
            
        case .showClockWhenScreenIsLocked:

            return UISwitch(isOn: UserDefaults.standard.showClockWhenScreenIsLocked, action: {(isOn:Bool) in UserDefaults.standard.showClockWhenScreenIsLocked = isOn})
            
        case .showSensorCountdown:

            return UISwitch(isOn: UserDefaults.standard.showSensorCountdown, action: {(isOn:Bool) in UserDefaults.standard.showSensorCountdown = isOn})

        case .bloodGlucoseUnit, .masterFollower:
            return nil
            
        case .notificationInterval:
            return nil
            
        }

    }
    
}
