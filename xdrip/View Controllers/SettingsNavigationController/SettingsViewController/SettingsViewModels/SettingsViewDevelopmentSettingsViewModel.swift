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
    
    /// if true, then readings will only be written to shared user defaults (for loop) every 5 minutes (>4.5 mins to be exact)
    case shareToLoopOnceEvery5Minutes = 5
    
    /// to create artificial delay in readings stored in sharedUserDefaults for loop. Minutes - so that Loop receives more smoothed values.
    ///
    /// Default value 0, if used then recommended value is multiple of 5 (eg 5 ot 10)
    case loopDelay = 6
    
    /// LibreLinkUp version number that will be used for the LLU follower mode http request headers
    case libreLinkUpVersion = 7
    
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
            
        case .shareToLoopOnceEvery5Minutes:
            return Texts_SettingsView.shareToLoopOnceEvery5Minutes
            
        case .loopDelay:
            return Texts_SettingsView.loopDelaysScreenTitle
            
        case .libreLinkUpVersion:
            return Texts_SettingsView.libreLinkUpVersion
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled, .OSLogEnabled, .smoothLibreValues, .suppressUnLockPayLoad, .shareToLoopOnceEvery5Minutes, .suppressLoopShare:
            return UITableViewCell.AccessoryType.none
            
        case .loopDelay, .libreLinkUpVersion:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled, .OSLogEnabled, .smoothLibreValues, .suppressUnLockPayLoad, .suppressLoopShare, .shareToLoopOnceEvery5Minutes, .loopDelay:
            return nil
            
        case .libreLinkUpVersion:
            return UserDefaults.standard.libreLinkUpVersion
            
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
            
        case .shareToLoopOnceEvery5Minutes:
            return UISwitch(isOn: UserDefaults.standard.shareToLoopOnceEvery5Minutes, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.shareToLoopOnceEvery5Minutes = isOn
                
            })
            
        case .loopDelay, .libreLinkUpVersion:
            return nil
            
        }
        
    }

    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .NSLogEnabled, .OSLogEnabled, .smoothLibreValues, .suppressUnLockPayLoad, .shareToLoopOnceEvery5Minutes, .suppressLoopShare:
            return .nothing
            
        case .loopDelay:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToLoopDelaySchedule.rawValue, sender: self)
            
        case .libreLinkUpVersion:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.libreLinkUpVersion, message:  Texts_SettingsView.libreLinkUpVersionMessage, keyboardType: .default, text: UserDefaults.standard.libreLinkUpVersion, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(libreLinkUpVersion: String) in
                
                // check if the entered version is in the correct format before allowing it to help avoid problems with the server requests
                if let versionNumber = libreLinkUpVersion.toNilIfLength0(), checkLibreLinkUpVersionFormat(for: libreLinkUpVersion) {
                    
                    UserDefaults.standard.libreLinkUpVersion = versionNumber.toNilIfLength0()
                    
                }
                
            }, cancelHandler: nil, inputValidator: nil)
            
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    // regex tested here: https://regex101.com/r/MI9vTy/2
    /// check the LibreLinkUp version number entered to make sure it follows the required format like "4.x.x"
    func checkLibreLinkUpVersionFormat(for text: String) -> Bool {
        
        let regex = try! NSRegularExpression(pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$", options: [.caseInsensitive])
        
        let range = NSRange(location: 0, length: text.count)
        
        let matches = regex.matches(in: text, options: [], range: range)
        
        return matches.first != nil
        
    }
    
}
