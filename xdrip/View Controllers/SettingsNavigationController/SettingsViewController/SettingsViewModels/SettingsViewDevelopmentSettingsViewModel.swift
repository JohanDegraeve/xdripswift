import UIKit

fileprivate enum Setting:Int, CaseIterable {

    /// to enable NSLog
    case NSLogEnabled = 0
    
    /// to enable OSLog
    case OSLogEnabled = 1
    
    /// case smooth libre values
    case smoothLibreValues = 2
    
    /// for Libre 2 only, to suppress that app sends unlock payload to Libre 2, in which case xDrip4iOS can run in parallel with other app(s)
    case suppressUnLockPayLoad = 3

    /// if true, then readings will not be written to shared user defaults (for loop)
    case suppressLoopShare = 4
    
    /// to create artificial delay in readings stored in sharedUserDefaults for loop. Minutes - so that Loop receives more smoothed values.
    ///
    /// Default value 0, if used then recommended value is multiple of 5 (eg 5 ot 10)
    case loopDelay = 5
    
}

struct SettingsViewDevelopmentSettingsViewModel:SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }

    func sectionTitle() -> String? {
        return Texts_SettingsView.developerSettings
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled:
            return Texts_SettingsView.nsLog
            
        case .OSLogEnabled:
            return Texts_SettingsView.osLog
            
        case .smoothLibreValues:
            return Texts_SettingsView.smoothLibreValues
            
        case .suppressUnLockPayLoad:
            return Texts_SettingsView.suppressUnLockPayLoad
            
        case .suppressLoopShare:
            return Texts_SettingsView.suppressLoopShare
            
        case .loopDelay:
            return "Loop Delay"
            
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled, .OSLogEnabled, .smoothLibreValues, .suppressUnLockPayLoad, .suppressLoopShare:
            return UITableViewCell.AccessoryType.none
            
        case .loopDelay:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled:
            return nil
            
        case .OSLogEnabled:
            return nil
            
        case .smoothLibreValues:
            return nil
            
        case .suppressUnLockPayLoad:
            return nil
            
        case .suppressLoopShare:
            return nil
            
        case .loopDelay:
            return UserDefaults.standard.loopDelay.description
            
        }
        
    }
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled:
            return UISwitch(isOn: UserDefaults.standard.NSLogEnabled, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.NSLogEnabled = isOn
                
            })
            
        case .OSLogEnabled:
            return UISwitch(isOn: UserDefaults.standard.OSLogEnabled, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.OSLogEnabled = isOn
                
            })
                                        
        case .smoothLibreValues:
            return UISwitch(isOn: UserDefaults.standard.smoothLibreValues, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.smoothLibreValues = isOn
                
            })

        case .suppressUnLockPayLoad:
            return UISwitch(isOn: UserDefaults.standard.suppressUnLockPayLoad, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.suppressUnLockPayLoad = isOn
                
            })
            
        case .suppressLoopShare:
            return UISwitch(isOn: UserDefaults.standard.suppressLoopShare, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.suppressLoopShare = isOn
                
            })
            
        case .loopDelay:
            return nil
            
        }
        
    }

    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled, .OSLogEnabled, .smoothLibreValues, .suppressUnLockPayLoad, .suppressLoopShare:
            return .nothing
            
        case .loopDelay:
            return SettingsSelectedRowAction.askText(title: "Loop Delay", message: "Artificial delay in readings when sending to Loop (minutes) - 0 means no delay. Use maximum 10 minutes.", keyboardType: .numberPad, text: UserDefaults.standard.loopDelay.description, placeHolder: "0", actionTitle: nil, cancelTitle: nil, actionHandler: {(interval:String) in if let interval = Int(interval) {UserDefaults.standard.loopDelay = Int(interval)}}, cancelHandler: nil, inputValidator: nil)
            

        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
}
