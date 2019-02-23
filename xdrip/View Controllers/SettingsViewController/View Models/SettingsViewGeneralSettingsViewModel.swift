import UIKit

fileprivate enum Setting:Int, CaseIterable {
    //blood glucose  unit
    case bloodGlucoseUnit = 0
    //low value
    case lowMarkValue = 1
    //high value
    case highMarkValue = 2
    // transmitter type
}

struct SettingsViewGeneralSettingsViewModel:SettingsViewModelProtocol {
    func onRowSelect(index: Int) -> SelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .bloodGlucoseUnit:
            return SelectedRowAction.callFunction(function: {UserDefaults.standard.bloodGlucoseUnitIsMgDl ? (UserDefaults.standard.bloodGlucoseUnitIsMgDl) = false : (UserDefaults.standard.bloodGlucoseUnitIsMgDl = true)})
        case .lowMarkValue:
            return SelectedRowAction.askText(title: Texts_SettingsViews.lowValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, placeHolder: UserDefaults.standard.lowMarkValueInUserChosenUnitRounded, actionTitle: nil, cancelTitle: nil, actionHandler: {(lowMarkValue:String) in UserDefaults.standard.lowMarkValueInUserChosenUnitRounded = lowMarkValue}, cancelHandler: nil)

        case .highMarkValue:
            return SelectedRowAction.askText(title: Texts_SettingsViews.highValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, placeHolder: UserDefaults.standard.highMarkValueInUserChosenUnitRounded, actionTitle: nil, cancelTitle: nil, actionHandler: {(highMarkValue:String) in UserDefaults.standard.highMarkValueInUserChosenUnitRounded = highMarkValue}, cancelHandler: nil)
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsViews.sectionTitleGeneral
    }

    func numberOfRows() -> Int {
        return Setting.allCases.count
    }

    func text(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .bloodGlucoseUnit:
            return Texts_Common.bloodGLucoseUnit
        case .lowMarkValue:
            return Texts_SettingsViews.lowValue
        case .highMarkValue:
            return Texts_SettingsViews.highValue
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .bloodGlucoseUnit:
            return UITableViewCell.AccessoryType.none
        case .lowMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .highMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .bloodGlucoseUnit:
            if UserDefaults.standard.bloodGlucoseUnitIsMgDl {
                return Texts_Common.mgdl
            } else {
                return Texts_Common.mmol
            }
        case .lowMarkValue:
            return UserDefaults.standard.lowMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        case .highMarkValue:
            return UserDefaults.standard.highMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        }
    }
    
    func uiView(index: Int) -> (view: UIView?, reloadSection: Bool) {
        return (nil, false)
    }
    
}
