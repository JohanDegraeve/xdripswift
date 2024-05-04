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
    
    //which TIR type should be used?
    case timeInRangeType = 1
    
    //urgent low value
    case useIFCCA1C = 2
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewStatisticsSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    override init() {
        
        super.init()
        
        addObservers()
        
    }
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

        case .showStatistics:
            return UISwitch(isOn: UserDefaults.standard.showStatistics, action: {(isOn:Bool) in UserDefaults.standard.showStatistics = isOn})
                        
        case .timeInRangeType:
            return nil
            
        case .useIFCCA1C :
            return UISwitch(isOn: UserDefaults.standard.useIFCCA1C, action: {(isOn:Bool) in UserDefaults.standard.useIFCCA1C = isOn})
            
        }
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        // changing follower to master or master to follower requires changing ui for nightscout settings and transmitter type settings
        if (index == Setting.timeInRangeType.rawValue) {return true}
        
        return false
    }
    
    var sectionReloadClosure: (() -> Void)?
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
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
            
        case .timeInRangeType:
            
            // data to be displayed in list from which user needs to pick a screen dimming type
            var data = [String]()
            
            var selectedRow: Int?
            
            var index = 0
            
            let currentTimeInRangeType = UserDefaults.standard.timeInRangeType
            
            // get all data source types and add the description to data. Search for the type that matches the ScreenLockDimmingType that is currently stored in userdefaults.
            for timeInRangeType in TimeInRangeType.allCases {
                
                data.append(timeInRangeType.description + timeInRangeType.rangeString())
                
                if timeInRangeType == currentTimeInRangeType {
                    selectedRow = index
                }
                
                index += 1
                
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.labelTimeInRangeType, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                
                if index != selectedRow {
                    
                    UserDefaults.standard.timeInRangeType = TimeInRangeType(rawValue: index) ?? .standardRange
                    
                }
                
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
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
        return ConstantsSettingsIcons.statisticsSettingsIcon + " " + Texts_SettingsView.sectionTitleStatistics
    }
    
    func numberOfRows() -> Int {
        
        // if the user doesn't want to see the statistics, then hide the options
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
                    
            case .timeInRangeType:
                return Texts_SettingsView.labelTimeInRangeType
                    
            case .useIFCCA1C:
                return Texts_SettingsView.labelUseIFFCA1C
                
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showStatistics, .useIFCCA1C:
            return UITableViewCell.AccessoryType.none
            
        case .timeInRangeType:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .showStatistics, .useIFCCA1C:
            return nil
            
        case .timeInRangeType:
            return UserDefaults.standard.timeInRangeType.description
            
        }
    }
    
    
    // MARK: - observe functions
    
    private func addObservers() {
        
        // Listen for changes in the timeInRangeType to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.timeInRangeType.rawValue, options: .new, context: nil)
        
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else { return }
        
        switch keyPathEnum {
        case UserDefaults.Key.timeInRangeType:
            
            // we have to run this in the main thread to avoid access errors
            DispatchQueue.main.async {
                self.sectionReloadClosure?()
            }
            
        default:
            break
            
        }
    }
    
}
