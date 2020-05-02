import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    //blood glucose  unit
    case bloodGlucoseUnit = 0
    
    //low value
    case lowMarkValue = 1
    
    //high value
    case highMarkValue = 2
    
    // choose between master and follower
    case masterFollower = 3
    
    // should reading be shown in notification
    case showReadingInNotification = 4
    
    // show reading in app badge
    case showReadingInAppBadge = 5
    
    // if reading is shown in app badge, should value be multiplied with 10 yes or no
    case multipleAppBadgeValueWith10 = 6
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
struct SettingsViewGeneralSettingsViewModel:SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}

    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        // changing follower to master or master to follower requires changing ui for nightscout settings and transmitter type settings
        if index == Setting.masterFollower.rawValue {return true}
        
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .bloodGlucoseUnit:
            return SettingsSelectedRowAction.callFunction(function: {UserDefaults.standard.bloodGlucoseUnitIsMgDl ? (UserDefaults.standard.bloodGlucoseUnitIsMgDl) = false : (UserDefaults.standard.bloodGlucoseUnitIsMgDl = true)})
            
        case .lowMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelLowValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.lowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultLowMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(lowMarkValue:String) in UserDefaults.standard.lowMarkValueInUserChosenUnitRounded = lowMarkValue}, cancelHandler: nil, inputValidator: nil)

        case .highMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelHighValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.highMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultHighMmarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(highMarkValue:String) in UserDefaults.standard.highMarkValueInUserChosenUnitRounded = highMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        case .masterFollower:
            
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.isMaster {
                    UserDefaults.standard.isMaster = false
                } else {
                    UserDefaults.standard.isMaster = true
                }

            })
                
        case .showReadingInNotification, .showReadingInAppBadge, .multipleAppBadgeValueWith10:
            return SettingsSelectedRowAction.nothing
            
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
            
        case .lowMarkValue:
            return Texts_SettingsView.labelLowValue
            
        case .highMarkValue:
            return Texts_SettingsView.labelHighValue
            
        case .masterFollower:
            return Texts_SettingsView.labelMasterOrFollower
            
        case .showReadingInNotification:
            return Texts_SettingsView.labelShowReadingInNotification
            
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
            
        case .lowMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .highMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .masterFollower:
            return UITableViewCell.AccessoryType.none
            
        case .showReadingInNotification, .showReadingInAppBadge, .multipleAppBadgeValueWith10:
            return UITableViewCell.AccessoryType.none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .bloodGlucoseUnit:
            return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl:Texts_Common.mmol
            
        case .lowMarkValue:
            return UserDefaults.standard.lowMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .highMarkValue:
            return UserDefaults.standard.highMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .masterFollower:
            return UserDefaults.standard.isMaster ? Texts_SettingsView.master:Texts_SettingsView.follower
            
        case .showReadingInNotification, .showReadingInAppBadge, .multipleAppBadgeValueWith10:
            return nil
            
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

        case .bloodGlucoseUnit, .highMarkValue, .lowMarkValue, .masterFollower:
            return nil
            
        }

    }
    
}
