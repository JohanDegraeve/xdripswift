import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    // for G6 testing, factor 1
    case G6v2ScalingFactor1 = 0
    
    // for G6 testing, factor 2
    case G6v2ScalingFactor2 = 1
    
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

        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .G6v2ScalingFactor1:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .G6v2ScalingFactor2:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
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
        }
        
    }
    
    func uiView(index: Int) -> UIView? {
        
        return nil
        
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
                
            }, cancelHandler: nil)

        case .G6v2ScalingFactor2:
            
            return SettingsSelectedRowAction.askText(title: "G6 scaling", message: "Give G6 v2 scaling factor 2", keyboardType: UIKeyboardType.decimalPad, text: UserDefaults.standard.G6v2ScalingFactor2, placeHolder: CGMG6Transmitter.G6v2DefaultScalingFactor2.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(factor:String) in
                
                // convert to uppercase
                if let factorAsDouble = factor.toDouble() {
                    UserDefaults.standard.G6v2ScalingFactor2 = factorAsDouble.description
                }
                

            }, cancelHandler: nil)

        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
}
