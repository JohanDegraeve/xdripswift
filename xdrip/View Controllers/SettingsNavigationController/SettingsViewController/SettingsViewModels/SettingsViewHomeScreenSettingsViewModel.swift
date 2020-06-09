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
    
    //target value
    case targetMarkValue = 2
    
    //low value
    case lowMarkValue = 3
    
    //urgent low value
    case urgentLowMarkValue = 4
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
struct SettingsViewHomeScreenSettingsViewModel:SettingsViewModelProtocol {
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

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

        case .targetMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelTargetValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.targetMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultTargetMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(targetMarkValue:String) in UserDefaults.standard.targetMarkValueInUserChosenUnitRounded = targetMarkValue}, cancelHandler: nil, inputValidator: nil)
        
        case .lowMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelLowValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.lowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultLowMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(lowMarkValue:String) in UserDefaults.standard.lowMarkValueInUserChosenUnitRounded = lowMarkValue}, cancelHandler: nil, inputValidator: nil)

        case .urgentLowMarkValue:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelUrgentLowValue, message: nil, keyboardType: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .numberPad:.decimalPad, text: UserDefaults.standard.urgentLowMarkValueInUserChosenUnitRounded, placeHolder: ConstantsBGGraphBuilder.defaultUrgentLowMarkInMgdl.description, actionTitle: nil, cancelTitle: nil, actionHandler: {(urgentLowMarkValue:String) in UserDefaults.standard.urgentLowMarkValueInUserChosenUnitRounded = urgentLowMarkValue}, cancelHandler: nil, inputValidator: nil)
            
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleHomeScreen
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .urgentHighMarkValue:
            return Texts_SettingsView.labelUrgentHighValue

        case .highMarkValue:
            return Texts_SettingsView.labelHighValue

        case .targetMarkValue:
            return Texts_SettingsView.labelTargetValue
            
        case .lowMarkValue:
            return Texts_SettingsView.labelLowValue
            
        case .urgentLowMarkValue:
            return Texts_SettingsView.labelUrgentLowValue
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .urgentHighMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .highMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .targetMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
        
        case .lowMarkValue:
            return UITableViewCell.AccessoryType.disclosureIndicator
        
        case .urgentLowMarkValue:
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
            
        case .targetMarkValue:
            return UserDefaults.standard.targetMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

        case .lowMarkValue:
            return UserDefaults.standard.lowMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

        case .urgentLowMarkValue:
            return UserDefaults.standard.urgentLowMarkValueInUserChosenUnit.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        }
    }
    
}
