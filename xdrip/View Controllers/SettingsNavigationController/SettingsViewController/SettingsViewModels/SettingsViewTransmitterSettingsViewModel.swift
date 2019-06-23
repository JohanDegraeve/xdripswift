import UIKit

fileprivate enum Setting:Int, CaseIterable {
    //transmittertype
    case transmitterType = 0
    //transmitterid
    case transmitterId = 1
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
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Setting in SettingsViewTransmitterSettingsViewModel onRowSelect") }
        
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
                
            }, cancelHandler: nil)
            
        case .transmitterType:
            var data = [String]()
            for transmitterType in CGMTransmitterType.allCases {
                data.append(transmitterType.rawValue)
            }
            
            //find index for transmitter type currently stored in userdefaults
            var selectedRow:Int?
            if let transmitterType = UserDefaults.standard.transmitterType?.rawValue {
                selectedRow = data.index(of:transmitterType)
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.labelTransmitterId, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                if index != selectedRow {
                    UserDefaults.standard.transmitterTypeAsString = data[index]
                }
            }, cancelHandler: nil, didSelectRowHandler: nil)
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleTransmitter
    }

    func numberOfRows() -> Int {
        if let transmitterType = UserDefaults.standard.transmitterType {
            // if transmitter doesn't need transmitterid (like MiaoMiao) then the settings row that asks for transmitterid doesn't need to be shown. That rows is the second row.
            return transmitterType.needsTransmitterId() ? 2:1
        } else {
            // transmitterType nil, means this is initial setup, no need to show transmitter id field
            return 1
        }
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch (setting) {
        case .transmitterId:
            return Texts_SettingsView.labelTransmitterId
        case .transmitterType:
            return Texts_SettingsView.labelTransmitterType
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        return UITableViewCell.AccessoryType.disclosureIndicator
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch (setting) {
        case .transmitterId:
            return UserDefaults.standard.transmitterId
        case .transmitterType:
            return UserDefaults.standard.transmitterType?.rawValue
        }
    }
    
    func uiView(index: Int) -> UIView? {
        return nil
    }
    
    /// sets UserDefaults.standard.transmitterId with valud of id
    ///
    /// if transmitterType is G5 (or maybe later G6), then sets UserDefaults.standard.dexcomShareSerialNumber = UserDefaults.standard.transmitterId - otherwise dexcomShareSerialNumber is not changed
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
                
            case .dexcomG4, .miaomiao, .GNSentry:
                break
            case .dexcomG5:
                UserDefaults.standard.dexcomShareSerialNumber = UserDefaults.standard.transmitterId
                
            }
        }
    }
    
}
