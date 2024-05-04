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
    
    //should we use the user values for High + Low, or use the standard range?
    case smallBolusTreatmentThreshold = 1
    
    //should we show the micro-boluses on the main chart?
    case showSmallBolusTreatmentsOnChart = 2
    
    //should we offset the carbs on the main chart?
    case offsetCarbTreatmentsOnChart = 3
    
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
struct SettingsViewTreatmentsSettingsViewModel:SettingsViewModelProtocol {
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showTreatmentsOnChart:
            return UISwitch(isOn: UserDefaults.standard.showTreatmentsOnChart, action: {(isOn:Bool) in UserDefaults.standard.showTreatmentsOnChart = isOn})
            
        case .smallBolusTreatmentThreshold:
            return nil
            
        case .showSmallBolusTreatmentsOnChart:
            return UISwitch(isOn: UserDefaults.standard.showSmallBolusTreatmentsOnChart, action: {(isOn:Bool) in UserDefaults.standard.showSmallBolusTreatmentsOnChart = isOn})
            
        case .offsetCarbTreatmentsOnChart:
            return UISwitch(isOn: UserDefaults.standard.offsetCarbTreatmentsOnChart, action: {(isOn:Bool) in UserDefaults.standard.offsetCarbTreatmentsOnChart = isOn})
            
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
            
        case .smallBolusTreatmentThreshold:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.settingsviews_smallBolusTreatmentThreshold, message: Texts_SettingsView.settingsviews_smallBolusTreatmentThresholdMessage, keyboardType: .decimalPad, text: UserDefaults.standard.smallBolusTreatmentThreshold.description, placeHolder: "0.0", actionTitle: nil, cancelTitle: nil, actionHandler: {(threshold:String) in if let threshold = Double(threshold) {UserDefaults.standard.smallBolusTreatmentThreshold = Double(threshold)}}, cancelHandler: nil, inputValidator: nil)
            
        case .showSmallBolusTreatmentsOnChart:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.showSmallBolusTreatmentsOnChart {
                    UserDefaults.standard.showSmallBolusTreatmentsOnChart = false
                } else {
                    UserDefaults.standard.showSmallBolusTreatmentsOnChart = true
                }
            })
            
        case .offsetCarbTreatmentsOnChart:
            return SettingsSelectedRowAction.callFunction(function: {
                if UserDefaults.standard.offsetCarbTreatmentsOnChart {
                    UserDefaults.standard.offsetCarbTreatmentsOnChart = false
                } else {
                    UserDefaults.standard.offsetCarbTreatmentsOnChart = true
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
            
        case .smallBolusTreatmentThreshold:
            return Texts_SettingsView.settingsviews_smallBolusTreatmentThreshold
            
        case .showSmallBolusTreatmentsOnChart:
            return Texts_SettingsView.settingsviews_showSmallBolusTreatmentsOnChart
            
        case .offsetCarbTreatmentsOnChart:
            return Texts_SettingsView.settingsviews_offsetCarbTreatmentsOnChart
            
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showTreatmentsOnChart, .showSmallBolusTreatmentsOnChart, .offsetCarbTreatmentsOnChart:
            return UITableViewCell.AccessoryType.none
            
        case .smallBolusTreatmentThreshold:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showTreatmentsOnChart, .showSmallBolusTreatmentsOnChart, .offsetCarbTreatmentsOnChart:
            return nil
            
        case .smallBolusTreatmentThreshold:
            return UserDefaults.standard.smallBolusTreatmentThreshold.description
            
        }
    }
    
}
