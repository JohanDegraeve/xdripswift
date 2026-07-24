import Foundation

fileprivate enum Setting:Int, CaseIterable {
    
    //blood glucose  unit
    case textColor
    
}

struct SettingsViewM5StackGeneralSettingsViewModel: SettingsViewModelProtocol {
    
    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        [
            nativeSettingsRow(id: "m5stackGeneral.textColor", index: Setting.textColor.rawValue, sectionID: sectionID)
        ]
    }

    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    

    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func sectionTitle() -> String? {
        return Texts_BgReadings.generalSectionHeader
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .textColor:
            return Texts_SettingsView.m5StackTextColor
        }

    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .textColor:
            return SettingsAccessory.disclosure
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .textColor:
            var textColor = UserDefaults.standard.m5StackTextColor
            if textColor == nil {
                textColor = ConstantsM5Stack.defaultTextColor
            }
            return textColor?.description
        }
    }
    
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .textColor:
            var texts = [String]()
            var colors = [M5StackColor]()
            for textColor in M5StackColor.allCases {
                texts.append(textColor.description)
                colors.append(textColor)
            }
            
            //find index for text color currently stored in userdefaults
            var selectedRow:Int?
            if let textColor = UserDefaults.standard.m5StackTextColor?.description {
                selectedRow = texts.firstIndex(of:textColor)
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.m5StackTextColor, data: texts, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                if index != selectedRow {
                    UserDefaults.standard.m5StackTextColor = colors[index]
                }
            }, cancelHandler: nil, didSelectRowHandler: nil)

        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
}
