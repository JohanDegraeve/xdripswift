//
//  SettingsViewSensorCountdownSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 30/8/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation

import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    //show the statistics on the home screen?
    case showSensorCountdown = 0
    
    //should we use the user values for High + Low, or use the standard range?
    case showSensorCountdownAlternativeGraphics = 1
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
struct SettingsViewSensorCountdownSettingsViewModel:SettingsViewModelProtocol {
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        
            case .showSensorCountdown :
                return UISwitch(isOn: UserDefaults.standard.showSensorCountdown, action: {(isOn:Bool) in UserDefaults.standard.showSensorCountdown = isOn})
                
            case .showSensorCountdownAlternativeGraphics :
                return UISwitch(isOn: UserDefaults.standard.showSensorCountdownAlternativeGraphics, action: {(isOn:Bool) in UserDefaults.standard.showSensorCountdownAlternativeGraphics = isOn})
            
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
                
        case  .showSensorCountdown:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showSensorCountdown {
                    UserDefaults.standard.showSensorCountdown = false
                } else {
                    UserDefaults.standard.showSensorCountdown = true
                }
            })
            
        case  .showSensorCountdownAlternativeGraphics:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showSensorCountdownAlternativeGraphics {
                    UserDefaults.standard.showSensorCountdownAlternativeGraphics = false
                } else {
                    UserDefaults.standard.showSensorCountdownAlternativeGraphics = true
                }
            })
                
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleSensorCountdown
    }
    
    func numberOfRows() -> Int {
        
        // if the user doesn't want to see the objectives on the graph, then hide the options, the same applies to the Show Target option
        if UserDefaults.standard.showSensorCountdown {
            return Setting.allCases.count
        } else {
            return Setting.allCases.count - 1
        }
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
                
            case .showSensorCountdown:
                return Texts_SettingsView.labelShowSensorCountdown
                
            case .showSensorCountdownAlternativeGraphics:
                return Texts_SettingsView.labelShowSensorCountdownAlternativeGraphics
                
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showSensorCountdown, .showSensorCountdownAlternativeGraphics:
            return UITableViewCell.AccessoryType.none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .showSensorCountdown, .showSensorCountdownAlternativeGraphics:
            return nil
            
        }
    }
    
}

