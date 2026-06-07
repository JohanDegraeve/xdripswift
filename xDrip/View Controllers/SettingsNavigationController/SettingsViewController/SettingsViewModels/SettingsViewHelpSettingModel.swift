//
//  SettingsViewHelpSettingModel.swift
//  xdrip
//
//  Created by Paul Plant on 8/10/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import UIKit
import AVFoundation

fileprivate enum Setting:Int, CaseIterable {
    
    /// open the online help URL
    case showOnlineHelp = 0
    
    /// should the online help be  automatically translated?
    case translateOnlineHelp = 1
    
}

/// conforms to SettingsViewModelProtocol for all alert settings in the first sections screen
struct SettingsViewHelpSettingsViewModel:SettingsViewModelProtocol {
    
    func storeUIViewController(uIViewController: UIViewController) {}

    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
        
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Setting in SettingsViewHelpSettingsViewModel onRowSelect") }

        switch setting {
            
        case .showOnlineHelp:
            
            // get the 2 character language code for the App Locale (i.e. "en", "es", "nl", "fr")
            // if the user has the app in a language other than English and they have the "auto translate" option selected, then load the help pages through Google Translate
            // important to check the the URLs actually exist in ConstansHomeView before trying to open them
            if let languageCode = NSLocale.current.language.languageCode?.identifier, languageCode != ConstantsHomeView.onlineHelpBaseLocale && UserDefaults.standard.translateOnlineHelp {
                
                guard let url = URL(string: ConstantsHomeView.onlineHelpURLTranslated1 + languageCode + ConstantsHomeView.onlineHelpURLTranslated2) else { return .nothing }
                
                UIApplication.shared.open(url)
                
            } else {
                
                // so the user is running the app in English or they don't want to translate so let's just load it directly
                guard let url = URL(string: ConstantsHomeView.onlineHelpURL) else { return .nothing}
                
                UIApplication.shared.open(url)
                
            }
            
            return .nothing
            
        case .translateOnlineHelp:
            
            return .nothing
            
        }
    }
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.helpSettingsIcon + " " + Texts_SettingsView.sectionTitleHelp
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showOnlineHelp:
            return nil
        case .translateOnlineHelp:
            return UISwitch(isOn: UserDefaults.standard.translateOnlineHelp, action: {(isOn:Bool) in UserDefaults.standard.translateOnlineHelp = isOn})
        }
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Setting in SettingsHelpSettingsViewModel settingsRowText") }
        
        switch setting {
        case .showOnlineHelp:
            return Texts_SettingsView.showOnlineHelp
        case .translateOnlineHelp:
            return Texts_SettingsView.translateOnlineHelp
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showOnlineHelp:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .translateOnlineHelp:
            return UITableViewCell.AccessoryType.none
            
        }
        
    }
    
    func detailedText(index: Int) -> String? {
        //return nil
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showOnlineHelp, .translateOnlineHelp:
            return nil
        }
    }
    
    
}

