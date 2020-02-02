import UIKit

fileprivate enum Setting:Int, CaseIterable {
    /// transmittertype
    case transmitterType = 0
    /// transmitterid
    case transmitterId = 1
    /// is transmitter reset required or not (only applicable to Dexcom G5 and later also G6)
    case resetRequired = 2
    /// is webOOP enabled or not
    case webOOP = 3
    /// if webOOP enabled, what site to use
    case webOOPsite = 4
    /// if webOOP enabled, value of the token
    case webOOPtoken = 5
}

/// conforms to SettingsViewModelProtocol for all transmitter settings in the first sections screen
struct SettingsViewTransmitterSettingsViewModel:SettingsViewModelProtocol {
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        // in follower mode, all transmitter settings can be disabled
        if UserDefaults.standard.isMaster {
            return true
        } else {
            return false
        }
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: fixWebOOPIndex(index)) else { fatalError("Unexpected Setting in SettingsViewTransmitterSettingsViewModel onRowSelect") }
        
        switch setting {
            
        case .transmitterId:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelTransmitterId, message: Texts_SettingsView.labelGiveTransmitterId, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.transmitterId, placeHolder: "00000", actionTitle: nil, cancelTitle: nil, actionHandler: {(transmitterId:String) in
                
                // convert to uppercase
                let transmitterIdUpper = transmitterId.uppercased()
                
                // if changed then store new value
                if let currentTransmitterId = UserDefaults.standard.transmitterId {
                    if currentTransmitterId != transmitterIdUpper {
                        self.setTransmitterIdAndDexcomShareSerialNumber(id: transmitterIdUpper)
                    }
                } else {
                    self.setTransmitterIdAndDexcomShareSerialNumber(id: transmitterIdUpper)
                }
                
            }, cancelHandler: nil, inputValidator: { (transmitterId) in
                
                if transmitterId.count >= 2 {
                    // convert to upper
                    let transmitterIdUpper = transmitterId.uppercased()
                    
                    if transmitterIdUpper.compare("8G") == .orderedAscending {
                        return nil
                    } else {
                        return Texts_SettingsView.transmitterId8OrHigherNotSupported
                    }
                }
                
                // more checks can be added later , like length of transmitter id
                return nil
                
            })
            
        case .transmitterType:
            var data = [String]()
            for transmitterType in CGMTransmitterType.allCases {
                data.append(transmitterType.rawValue)
            }
            
            //find index for transmitter type currently stored in userdefaults
            var selectedRow:Int?
            if let transmitterType = UserDefaults.standard.transmitterType?.rawValue {
                selectedRow = data.firstIndex(of:transmitterType)
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.labelTransmitterId, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                if index != selectedRow {
                    UserDefaults.standard.transmitterTypeAsString = data[index]
                }
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .resetRequired:
            return SettingsSelectedRowAction.callFunction(function: {UserDefaults.standard.transmitterResetRequired ? (UserDefaults.standard.transmitterResetRequired) = false : (UserDefaults.standard.transmitterResetRequired = true)})

        case .webOOP:
            return SettingsSelectedRowAction.nothing

        case .webOOPsite:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelWebOOP, message: Texts_SettingsView.labelWebOOPSiteExplainingText, keyboardType: .URL, text: UserDefaults.standard.webOOPSite, placeHolder: Texts_Common.default0, actionTitle: nil, cancelTitle: nil, actionHandler: {(oopwebsiteurl:String) in UserDefaults.standard.webOOPSite = oopwebsiteurl.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .webOOPtoken:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelWebOOP, message: Texts_SettingsView.labelWebOOPtokenExplainingText, keyboardType: .default, text: UserDefaults.standard.webOOPtoken, placeHolder: Texts_Common.default0, actionTitle: nil, cancelTitle: nil, actionHandler: {(oopwebtoken:String) in UserDefaults.standard.webOOPtoken = oopwebtoken.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)

        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleTransmitter
    }

    func numberOfRows() -> Int {
        
        if !UserDefaults.standard.isMaster {
            // follower mode, no need to show all settings
            return 1
        }
        
        if let transmitterType = UserDefaults.standard.transmitterType {
            // if transmitter doesn't need transmitterid (like MiaoMiao) then the settings row that asks for transmitterid doesn't need to be shown. That row is the second row - also reset transmitter not necessary in that case
            // if ever there would be a transmitter that doesn't need a transmitter id but that supports reset transmitter, then some recoding will be necessary here
            var count = 0
            if transmitterType.needsTransmitterId()  {
                if transmitterType.resetPossible() {
                    count = 3
                } else {
                    count = 2
                }
            } else {
                count = 1
            }
            
            // for now WebOOP is only for transmitters that don't need transmitterId and no reset possible.
            // So for those transmitters, if canWebOOP and if enabled, then amount of rows = 4 (enable weboop, weboop site and weboop token. If webOOP not enabled, then only show setting to enabled weboop
            // Needs adaptation in case we would enable webOOP for transmitters with transmitterId, like Blucon
            if transmitterType.canWebOOP() {
                if UserDefaults.standard.webOOPEnabled {
                    count = 4
                } else {
                    count = 2
                }
            }
            
            return count
        } else {
            // transmitterType nil, means this is initial setup, no need to show transmitter id field
            return 1
        }
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: fixWebOOPIndex(index)) else { fatalError("Unexpected Section") }

        switch (setting) {
            
        case .transmitterId:
            return Texts_SettingsView.labelTransmitterId
            
        case .transmitterType:
            return Texts_SettingsView.labelTransmitterType
            
        case .resetRequired:
            return Texts_SettingsView.labelResetTransmitter
            
        case .webOOP:
            return Texts_SettingsView.labelWebOOPTransmitter
            
        case .webOOPsite:
            return Texts_SettingsView.labelWebOOPSite
            
        case .webOOPtoken:
            return Texts_SettingsView.labelWebOOPtoken
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: fixWebOOPIndex(index)) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .transmitterType:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .transmitterId:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .resetRequired:
            return UITableViewCell.AccessoryType.none
        case .webOOP:
            return UITableViewCell.AccessoryType.none
        case .webOOPsite:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .webOOPtoken:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }

    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: fixWebOOPIndex(index)) else { fatalError("Unexpected Section") }
        
        switch (setting) {
            
        case .transmitterId:
            return UserDefaults.standard.transmitterId
        case .transmitterType:
            return UserDefaults.standard.transmitterType?.rawValue
        case .resetRequired:
            return UserDefaults.standard.transmitterResetRequired ? Texts_Common.yes:Texts_Common.no
        case .webOOP:
            return nil
        case .webOOPsite:
            if let site = UserDefaults.standard.webOOPSite {
                return site
            } else {
                return Texts_Common.default0
            }
        case .webOOPtoken:
            if let token = UserDefaults.standard.webOOPtoken {
                return token
            } else {
                return Texts_Common.default0
            }

        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: fixWebOOPIndex(index)) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .webOOP:
            return UISwitch(isOn: UserDefaults.standard.webOOPEnabled, action: {(isOn:Bool) in UserDefaults.standard.webOOPEnabled = isOn})
        default:
            return nil
        }
    }
    
    // MARK: - private helper functions
    
    /// if it's a transmitterType that canWebOOP, then when user clicks second row or highter (ie index >= 1), then fix to index + 2 is done
    private func fixWebOOPIndex(_ index: Int) -> Int {
        
        var index = index
        
        if let transmitterType = UserDefaults.standard.transmitterType {
            if transmitterType.canWebOOP() && index >= 1 {
                index = index + 2
            }
        }
        
        return index
    }
    
    /// sets UserDefaults.standard.transmitterId with valud of id
    ///
    /// if transmitterType is G5 or G6, then sets UserDefaults.standard.dexcomShareSerialNumber = UserDefaults.standard.transmitterId - otherwise dexcomShareSerialNumber is not changed
    ///
    /// - parameters:
    ///     - id : new value for transmitterId and possibly also dexcomShareSerialNumber. If length is 0, then transmitterId gets value nil (and possibly also dexcomShareSerialNumber)
    private func setTransmitterIdAndDexcomShareSerialNumber(id:String) {
        
        // if length of id 0 , then set transmitterId to nil
        if id.count == 0 {
            UserDefaults.standard.transmitterId = nil
        } else {
            UserDefaults.standard.transmitterId = id
        }
        
        if let transmitterType = UserDefaults.standard.transmitterType {
            
            switch transmitterType {
                
            case .dexcomG5, .dexcomG6:
                UserDefaults.standard.dexcomShareSerialNumber = UserDefaults.standard.transmitterId

            default:
                break
                
            }
        }
    }
    
}
