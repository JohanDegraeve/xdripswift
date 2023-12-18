//
//  SettingsViewStatisticsSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 25/04/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation

import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    //show the statistics on the home screen?
    case showStatistics = 0
    
    //should we use the standard range for TIR, or the newer Time in Tighter Range values?
    case useTITRStatisticsRange = 1
    
    //urgent low value
    case useIFCCA1C = 2
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
struct SettingsViewStatisticsSettingsViewModel:SettingsViewModelProtocol {
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

        case .showStatistics:
            return UISwitch(isOn: UserDefaults.standard.showStatistics, action: {(isOn:Bool) in UserDefaults.standard.showStatistics = isOn})
                        
        case .useTITRStatisticsRange :
            return UISwitch(isOn: UserDefaults.standard.useTITRStatisticsRange, action: {(isOn:Bool) in UserDefaults.standard.useTITRStatisticsRange = isOn})
            
        case .useIFCCA1C :
            return UISwitch(isOn: UserDefaults.standard.useIFCCA1C, action: {(isOn:Bool) in UserDefaults.standard.useIFCCA1C = isOn})
            
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
                
            case .showStatistics:
                return SettingsSelectedRowAction.callFunction(function: {
                    if UserDefaults.standard.showStatistics {
                        UserDefaults.standard.showStatistics = false
                    } else {
                        UserDefaults.standard.showStatistics = true
                    }
                })
                    
            case .useTITRStatisticsRange:
                return SettingsSelectedRowAction.callFunction(function: {
                    if UserDefaults.standard.useTITRStatisticsRange {
                        UserDefaults.standard.useTITRStatisticsRange = false
                    } else {
                        UserDefaults.standard.useTITRStatisticsRange = true
                    }
                })
                
            case .useIFCCA1C:
                return SettingsSelectedRowAction.callFunction(function: {
                    if UserDefaults.standard.useIFCCA1C {
                        UserDefaults.standard.useIFCCA1C = false
                    } else {
                        UserDefaults.standard.useIFCCA1C = true
                    }
                })
                
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleStatistics
    }
    
    func numberOfRows() -> Int {
        
        // if the user doesn't want to see the objectives on the graph, then hide the options, the same applies to the Show Target option
        if UserDefaults.standard.showStatistics {
            return Setting.allCases.count
        } else {
            return Setting.allCases.count - 2
        }
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
                
            case .showStatistics:
                return Texts_SettingsView.labelShowStatistics
                    
            case .useTITRStatisticsRange:
                return Texts_SettingsView.labelUseTITRStatisticsRange
                    
            case .useIFCCA1C:
                return Texts_SettingsView.labelUseIFFCA1C
                
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showStatistics, .useTITRStatisticsRange, .useIFCCA1C:
            return UITableViewCell.AccessoryType.none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .showStatistics, .useTITRStatisticsRange, .useIFCCA1C:
            return nil
            
        }
    }
    
}
