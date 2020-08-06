//
//  SettingsViewHomeScreenSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 09/06/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    //urgent high value
    case urgentHighMarkValue = 0
    
    //high value
    case highMarkValue = 1
    
    //low value
    case lowMarkValue = 2
    
    //urgent low value
    case urgentLowMarkValue = 3
    
    //use objectives in graph?
    case useObjectives = 4
    
    //show colored objective lines?
    case showColoredObjectives = 5
    
    //show target line?
    case showTarget = 6
    
    //target value
    case targetMarkValue = 7
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
struct SettingsViewHomeScreenSettingsViewModel:SettingsViewModelProtocol {
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

        case .useObjectives:
            return UISwitch(isOn: UserDefaults.standard.useObjectives, action: {(isOn:Bool) in UserDefaults.standard.useObjectives = isOn})
            
        case .showColoredObjectives:
            return UISwitch(isOn: UserDefaults.standard.showColoredObjectives, action: {(isOn:Bool) in UserDefaults.standard.showColoredObjectives = isOn})
            
        case .showTarget :
            return UISwitch(isOn: UserDefaults.standard.showTarget, action: {(isOn:Bool) in UserDefaults.standard.showTarget = isOn})
            
        case  .urgentHighMarkValue, .highMarkValue, .targetMarkValue, .lowMarkValue, .urgentLowMarkValue:
            return nil
            
        }
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}

    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
                
            case .urgentHighMarkValue:
                return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelUrgentHighValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.urgentHighMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultUrgentHighMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(urgentHighMarkValue:String) in UserDefaults.standard.urgentHighMarkValueInUserChosenUnitRounded = urgentHighMarkValue}, cancelHandler: nil, inputValidator: nil)

            case .highMarkValue:
                return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelHighValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.highMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultHighMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(highMarkValue:String) in UserDefaults.standard.highMarkValueInUserChosenUnitRounded = highMarkValue}, cancelHandler: nil, inputValidator: nil)
            
            case .lowMarkValue:
                return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelLowValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.lowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultLowMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(lowMarkValue:String) in UserDefaults.standard.lowMarkValueInUserChosenUnitRounded = lowMarkValue}, cancelHandler: nil, inputValidator: nil)

            case .urgentLowMarkValue:
                return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelUrgentLowValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.urgentLowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultUrgentLowMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(urgentLowMarkValue:String) in UserDefaults.standard.urgentLowMarkValueInUserChosenUnitRounded = urgentLowMarkValue}, cancelHandler: nil, inputValidator: nil)

            case .useObjectives:
                return SettingsSelectedRowAction.callFunction(function: {
                    if UserDefaults.standard.useObjectives {
                        UserDefaults.standard.useObjectives = false
                    } else {
                        UserDefaults.standard.useObjectives = true
                    }
                })

            case .showColoredObjectives:
                return SettingsSelectedRowAction.callFunction(function: {
                    if UserDefaults.standard.showColoredObjectives {
                        UserDefaults.standard.showColoredObjectives = false
                    } else {
                        UserDefaults.standard.showColoredObjectives = true
                    }
                })
            
            case .showTarget:
                return SettingsSelectedRowAction.callFunction(function: {
                    if UserDefaults.standard.showTarget {
                        UserDefaults.standard.showTarget = false
                    } else {
                        UserDefaults.standard.showTarget = true
                    }
                })
            
            case .targetMarkValue:
                return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelTargetValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.targetMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultTargetMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(targetMarkValue:String) in UserDefaults.standard.targetMarkValueInUserChosenUnitRounded = targetMarkValue}, cancelHandler: nil, inputValidator: nil)
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleHomeScreen
    }
    
    func numberOfRows() -> Int {
        
        // if the user doesn't want to see the objectives on the graph, then hide the options, the same applies to the Show Target option
        if UserDefaults.standard.useObjectives && UserDefaults.standard.showTarget {
            return Setting.allCases.count
        } else if UserDefaults.standard.useObjectives && !UserDefaults.standard.showTarget {
            return Setting.allCases.count - 1
        } else {
            return Setting.allCases.count - 3
        }
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
                
            case .urgentHighMarkValue:
                return Texts_SettingsView.labelUrgentHighValue

            case .highMarkValue:
                return Texts_SettingsView.labelHighValue
                
            case .lowMarkValue:
                return Texts_SettingsView.labelLowValue
                
            case .urgentLowMarkValue:
                return Texts_SettingsView.labelUrgentLowValue
                
            case .useObjectives:
                return Texts_SettingsView.labelUseObjectives
            
            case .showColoredObjectives:
                return Texts_SettingsView.labelShowColoredObjectives
            
            case .showTarget:
                return Texts_SettingsView.labelShowTarget

            case .targetMarkValue:
                return Texts_SettingsView.labelTargetValue
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .urgentHighMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .highMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
        
        case .lowMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
        
        case .urgentLowMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator

        case .useObjectives:
            return UITableViewCell.AccessoryType.disclosureIndicator

        case .showColoredObjectives:
            return UITableViewCell.AccessoryType.disclosureIndicator

        case .showTarget:
            return UITableViewCell.AccessoryType.disclosureIndicator
                
        case .targetMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .urgentHighMarkValue:
            return UserDefaults.standard.urgentHighMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                
        case .highMarkValue:
            return UserDefaults.standard.highMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

        case .lowMarkValue:
            return UserDefaults.standard.lowMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

        case .urgentLowMarkValue:
            return UserDefaults.standard.urgentLowMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

        case .targetMarkValue:
            return UserDefaults.standard.targetMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        case .useObjectives, .showColoredObjectives, .showTarget:
            return nil
            
        }
    }
    
}
