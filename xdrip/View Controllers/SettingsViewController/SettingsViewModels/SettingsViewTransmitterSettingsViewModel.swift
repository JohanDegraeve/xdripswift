import UIKit

fileprivate enum Setting:Int, CaseIterable {
    //transmittertype
    case transmitterType = 0
    //transmitterid
    case transmitterId = 1
}

struct SettingsViewTransmitterSettingsViewModel:SettingsViewModelProtocol {
    
    func onRowSelect(index: Int) -> SelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .transmitterId:
            return SelectedRowAction.askText(title: Texts_SettingsViews.transmitterId, message: Texts_SettingsViews.giveTransmitterId, keyboardType: UIKeyboardType.alphabet, text: UserDefaults.standard.transmitterId, placeHolder: "00000", actionTitle: nil, cancelTitle: nil, actionHandler: {(serialNumber:String) in UserDefaults.standard.transmitterId = serialNumber}, cancelHandler: nil)
            
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
            
            return SelectedRowAction.selectFromList(title: Texts_SettingsViews.transmitterId, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in UserDefaults.standard.transmitterTypeAsString = data[index]}, cancelHandler: nil)
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsViews.sectionTitleTransmitter
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

    func text(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch (setting) {
        case .transmitterId:
            return Texts_SettingsViews.transmitterId
        case .transmitterType:
            return Texts_SettingsViews.transmitterType
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
