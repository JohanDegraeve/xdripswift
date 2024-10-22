//
//  SettingsViewTreatmentsSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 31/3/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation

import UIKit

fileprivate enum Setting:Int, CaseIterable {
    //show the statistics on the home screen?
    case showTreatmentsOnChart = 0
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
struct SettingsViewTreatmentsSettingsViewModel:SettingsViewModelProtocol {
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showTreatmentsOnChart:
            return UISwitch(isOn: UserDefaults.standard.showTreatmentsOnChart, action: {(isOn:Bool) in UserDefaults.standard.showTreatmentsOnChart = isOn})
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
        case .showTreatmentsOnChart:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showTreatmentsOnChart {
                    UserDefaults.standard.showTreatmentsOnChart = false
                } else {
                    UserDefaults.standard.showTreatmentsOnChart = true
                }
            })
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.treatmentsSettingsIcon + " " + Texts_SettingsView.sectionTitleTreatments
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showTreatmentsOnChart:
            return Texts_SettingsView.settingsviews_showTreatmentsOnChart
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showTreatmentsOnChart:
            return UITableViewCell.AccessoryType.none
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showTreatmentsOnChart:
            return nil
        }
    }
}
