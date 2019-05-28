import UIKit

fileprivate enum Setting:Int, CaseIterable {
    //transmittertype
    case transmitterType = 0
    //transmitterid
    case transmitterId = 1
}

/// conforms to SettingsViewModelProtocol for all transmitter settings in the first sections screen
struct SettingsViewTransmitterSettingsViewModel:SettingsViewModelProtocol {
    
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
                        UserDefaults.standard.transmitterId = transmitterIdUpper
                    }
                } else {
                    UserDefaults.standard.transmitterId = transmitterIdUpper
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
            }, cancelHandler: nil)
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
    
    func uiView(index: Int) ->(view: UIView?, reloadSection: Bool) {
        return (nil, false)
    }
}
