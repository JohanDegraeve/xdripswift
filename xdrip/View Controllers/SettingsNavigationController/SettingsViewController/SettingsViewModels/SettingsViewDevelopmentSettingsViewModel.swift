import UIKit

fileprivate enum Setting:Int, CaseIterable {

    /// to enable developer settings
    case showDeveloperSettings = 0
    
    /// to enable NSLog
    case NSLogEnabled = 1
    
    /// to enable OSLog
    case OSLogEnabled = 2
    
    /// for Libre 2 only, to suppress that app sends unlock payload to Libre 2, in which case xDrip4iOS can run in parallel with other app(s)
    case suppressUnLockPayLoad = 3

    /// should the BG values be written to a shared app group?
    case loopShareType = 4
    
    /// if true, then readings will only be written to shared user defaults (for loop) every 5 minutes (>4.5 mins to be exact)
    case shareToLoopOnceEvery5Minutes = 5
    
    /// to create artificial delay in readings stored in sharedUserDefaults for loop. Minutes - so that Loop receives more smoothed values.
    ///
    /// Default value 0, if used then recommended value is multiple of 5 (eg 5 ot 10)
    case loopDelay = 6
    
    /// LibreLinkUp version number that will be used for the LLU follower mode http request headers
    case libreLinkUpVersion = 7
    
    /// number of remaining forced complication updates available today
    case remainingComplicationUserInfoTransfers = 8
    
    /// allow StandBy mode to show a high contrast version of the widget at night
    case allowStandByHighContrast = 9
    
}

class SettingsViewDevelopmentSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    var sectionReloadClosure: (() -> Void)?
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }

    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.developerSettingsIcon + " " + Texts_SettingsView.developerSettings
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDeveloperSettings:
            return Texts_SettingsView.showDeveloperSettings
            
        case .NSLogEnabled:
            return Texts_SettingsView.nsLog
            
        case .OSLogEnabled:
            return Texts_SettingsView.osLog
            
        case .suppressUnLockPayLoad:
            return Texts_SettingsView.suppressUnLockPayLoad
            
        case .loopShareType:
            return Texts_SettingsView.loopShare
            
        case .shareToLoopOnceEvery5Minutes:
            return Texts_SettingsView.shareToLoopOnceEvery5Minutes
            
        case .loopDelay:
            return Texts_SettingsView.loopDelaysScreenTitle
            
        case .libreLinkUpVersion:
            return Texts_SettingsView.libreLinkUpVersion
            
        case .remainingComplicationUserInfoTransfers:
            return Texts_SettingsView.appleWatchRemainingComplicationUserInfoTransfers
            
        case .allowStandByHighContrast:
            return Texts_SettingsView.allowStandByHighContrast
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDeveloperSettings, .NSLogEnabled, .OSLogEnabled, .suppressUnLockPayLoad, .shareToLoopOnceEvery5Minutes, .allowStandByHighContrast:
            return .none
            
        case .loopShareType, .loopDelay, .libreLinkUpVersion, .remainingComplicationUserInfoTransfers:
            return .disclosureIndicator
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDeveloperSettings, .NSLogEnabled, .OSLogEnabled, .suppressUnLockPayLoad, .shareToLoopOnceEvery5Minutes, .loopDelay, .allowStandByHighContrast:
            return nil
            
        case .loopShareType:
            return UserDefaults.standard.loopShareType.description
            
        case .libreLinkUpVersion:
            return UserDefaults.standard.libreLinkUpVersion
            
        case .remainingComplicationUserInfoTransfers:
            if let remainingComplicationUserInfoTrans = UserDefaults.standard.remainingComplicationUserInfoTransfers {
                return remainingComplicationUserInfoTrans.description + " / 50"
            } else {
                return "-"
            }
            
        }
        
    }
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDeveloperSettings:
            return UISwitch(isOn: UserDefaults.standard.showDeveloperSettings, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.showDeveloperSettings = isOn
                
                // this is a bit messy, but seems to be the best way to reset the setting to false
                // this will usually happen when the view is not on screen anyway
                if isOn {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
                        UserDefaults.standard.showDeveloperSettings = false
                        self.sectionReloadClosure?()
                    }
                }
                
            })
            
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

        case .suppressUnLockPayLoad:
            return UISwitch(isOn: UserDefaults.standard.suppressUnLockPayLoad, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.suppressUnLockPayLoad = isOn
                
            })
            
        case .shareToLoopOnceEvery5Minutes:
            return UISwitch(isOn: UserDefaults.standard.shareToLoopOnceEvery5Minutes, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.shareToLoopOnceEvery5Minutes = isOn
                
            })
            
        case .allowStandByHighContrast:
            return UISwitch(isOn: UserDefaults.standard.allowStandByHighContrast, action: {
                (isOn:Bool) in
                
                UserDefaults.standard.allowStandByHighContrast = isOn
                
            })
            
        case .loopShareType, .loopDelay, .remainingComplicationUserInfoTransfers, .libreLinkUpVersion:
            return nil
            
        }
        
    }

    func numberOfRows() -> Int {
        return  UserDefaults.standard.showDeveloperSettings ? Setting.allCases.count : 1
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDeveloperSettings, .NSLogEnabled, .OSLogEnabled, .suppressUnLockPayLoad, .shareToLoopOnceEvery5Minutes, .allowStandByHighContrast:
            return .nothing
            
        case .loopShareType:
            
            // data to be displayed in list from which user needs to pick a loop share type
            var data = [String]()
            
            var selectedRow: Int?
            
            var index = 0
            
            let currentLoopShareType = UserDefaults.standard.loopShareType
            
            // get all loop share types and add the description to data. Search for the type that matches the LoopShareType that is currently stored in userdefaults.
            for loopShareType in LoopShareType.allCases {
                
                data.append(loopShareType.description)
                
                if loopShareType == currentLoopShareType {
                    selectedRow = index
                }
                
                index += 1
                
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.loopShare, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                
                if index != selectedRow {
                    
                    UserDefaults.standard.loopShareType = LoopShareType(rawValue: index) ?? .disabled
                    
                }
                
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .loopDelay:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToLoopDelaySchedule.rawValue, sender: self)
            
        case .libreLinkUpVersion:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.libreLinkUpVersion, message:  Texts_SettingsView.libreLinkUpVersionMessage, keyboardType: .default, text: UserDefaults.standard.libreLinkUpVersion, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(libreLinkUpVersion: String) in
                
                // check if the entered version is in the correct format before allowing it to help avoid problems with the server requests
                if let versionNumber = libreLinkUpVersion.toNilIfLength0(), self.checkLibreLinkUpVersionFormat(for: libreLinkUpVersion) {
                    
                    UserDefaults.standard.libreLinkUpVersion = versionNumber.toNilIfLength0()
                    
                }
                
            }, cancelHandler: nil, inputValidator: nil)
            
        case .remainingComplicationUserInfoTransfers:
            return .askConfirmation(title: Texts_SettingsView.appleWatchForceManualComplicationUpdate, message: Texts_SettingsView.appleWatchForceManualComplicationUpdateMessage, actionHandler: {
                UserDefaults.standard.forceComplicationUpdate = true
            }, cancelHandler: nil)
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
    
    
    // MARK: - observe functions
    
    private func addObservers() {
        
        // Listen for changes in the remaining complication transfers to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.remainingComplicationUserInfoTransfers.rawValue, options: .new, context: nil)
        
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else { return }
        
        switch keyPathEnum {
        case UserDefaults.Key.remainingComplicationUserInfoTransfers:
            
            // we have to run this in the main thread to avoid access errors
            DispatchQueue.main.async {
                self.sectionReloadClosure?()
            }
            
        default:
            break
        }
    }
    
}
