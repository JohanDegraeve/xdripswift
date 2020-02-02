import UIKit

fileprivate enum Setting:Int, CaseIterable {

    /// to enable NSLog
    case NSLogEnabled = 0
    
    /// to enable OSLog
    case OSLogEnabled = 1
    
    /// for G6 testing, factor 1
    case G6v2ScalingFactor1 = 2
    
    /// for G6 testing, factor 2
    case G6v2ScalingFactor2 = 3
    
}

struct SettingsViewDevelopmentSettingsViewModel:SettingsViewModelProtocol {
    
    func sectionTitle() -> String? {
        return "Developer Settings"
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .G6v2ScalingFactor1:
            return "G6 v2 scaling factor 1"
        case .G6v2ScalingFactor2:
            return "G6 v2 scaling factor 2"

        case .NSLogEnabled:
            return "NSLog"
            
        case .OSLogEnabled:
            return "OSLog"
            
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .G6v2ScalingFactor1:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .G6v2ScalingFactor2:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .NSLogEnabled, .OSLogEnabled:
            return UITableViewCell.AccessoryType.none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .G6v2ScalingFactor1:
            if let factor = UserDefaults.standard.G6v2ScalingFactor1 {
                return factor
            } else {
                return CGMG6Transmitter.G6v2DefaultScalingFactor1.description
            }
            
        case .G6v2ScalingFactor2:
            if let factor = UserDefaults.standard.G6v2ScalingFactor2 {
                return factor
            } else {
                return CGMG6Transmitter.G6v2DefaultScalingFactor2.description
            }
            
        case .NSLogEnabled:
            return "NSLog"
            
        case .OSLogEnabled:
            return "OSLog"
            
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
            
        case .G6v2ScalingFactor1, .G6v2ScalingFactor2:
            return nil
            
        }
        
    }

    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .G6v2ScalingFactor1:
            
            return SettingsSelectedRowAction.askText(title: "G6 scaling", message: "Give G6 v2 scaling factor 1", keyboardType: UIKeyboardType.decimalPad, text: UserDefaults.standard.G6v2ScalingFactor1, placeHolder: CGMG6Transmitter.G6v2DefaultScalingFactor1.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(factor:String) in
                
                // convert to uppercase
                if let factorAsDouble = factor.toDouble() {
                    UserDefaults.standard.G6v2ScalingFactor1 = factorAsDouble.description
                }
                
            }, cancelHandler: nil, inputValidator: nil)

        case .G6v2ScalingFactor2:
            
            return SettingsSelectedRowAction.askText(title: "G6 scaling", message: "Give G6 v2 scaling factor 2", keyboardType: UIKeyboardType.decimalPad, text: UserDefaults.standard.G6v2ScalingFactor2, placeHolder: CGMG6Transmitter.G6v2DefaultScalingFactor2.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(factor:String) in
                
                // convert to uppercase
                if let factorAsDouble = factor.toDouble() {
                    UserDefaults.standard.G6v2ScalingFactor2 = factorAsDouble.description
                }
                

            }, cancelHandler: nil, inputValidator: nil)

        case .NSLogEnabled, .OSLogEnabled:
            return .nothing
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
}
