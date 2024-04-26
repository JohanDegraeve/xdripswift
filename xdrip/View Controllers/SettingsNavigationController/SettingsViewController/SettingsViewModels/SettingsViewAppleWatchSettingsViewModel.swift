//
//  SettingsViewAppleWatchSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 21/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import OSLog

fileprivate enum Setting: Int, CaseIterable {
    // allow the homescreen to be show a landscape chart when rotated?
    case showDataInWatchComplications = 0
    
    // show a clock at the bottom of the home screen when the screen lock is activated?
    case watchComplicationUserAgreementDate = 1
    
    // show a clock at the bottom of the home screen when the screen lock is activated?
//    case forceComplicationUpdateInMinutes = 2
    
    // type of semi-transparent dark overlay to cover the app when the screen is locked
    case remainingComplicationUserInfoTransfers = 2
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewAppleWatchSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewCalendarEventsSettingsViewModel)
    
    /// the viewcontroller sets it by calling storeMessageHandler
    private var messageHandler: ((String, String) -> Void)?
    
    var sectionReloadClosure: (() -> Void)?
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    private func callMessageHandlerInMainThread(title: String, message: String) {
        
        // unwrap messageHandler
        guard let messageHandler = messageHandler else {return}
        
        DispatchQueue.main.async {
            messageHandler(title, message)
        }
        
    }
    
    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {
        self.messageHandler = messageHandler
    }
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showDataInWatchComplications, .watchComplicationUserAgreementDate, .remainingComplicationUserInfoTransfers:
            return nil
        }
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showDataInWatchComplications:
                return .askConfirmation(title: Texts_SettingsView.appleWatchShowDataInComplications, message: Texts_SettingsView.appleWatchShowDataInComplicationsMessage, actionHandler: {
                    UserDefaults.standard.showDataInWatchComplications = true
                    UserDefaults.standard.watchComplicationUserAgreementDate = .now
                }, cancelHandler: {
                    UserDefaults.standard.showDataInWatchComplications = false
                    UserDefaults.standard.watchComplicationUserAgreementDate = nil
                    // we have to run this in the main thread to avoid access errors
                    DispatchQueue.main.async {
                        self.sectionReloadClosure?()
                    }
                })
        
        case .remainingComplicationUserInfoTransfers:
            UserDefaults.standard.forceComplicationUpdate = true
            return .nothing
            
        case .watchComplicationUserAgreementDate:
            return .nothing
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.appleWatchSectionTitle
    }
    
    func numberOfRows() -> Int {
        // if the user doesn't enable the complications, then hide the rest of the settings
        return Setting.allCases.count - (UserDefaults.standard.showDataInWatchComplications ? 0 : 2)
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showDataInWatchComplications:
            return Texts_SettingsView.appleWatchShowDataInComplications
            
        case .watchComplicationUserAgreementDate:
            return Texts_SettingsView.appleWatchComplicationUserAgreementDate
            
        case .remainingComplicationUserInfoTransfers:
            return Texts_SettingsView.appleWatchRemainingComplicationUserInfoTransfers
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showDataInWatchComplications:
            return .disclosureIndicator
        case .watchComplicationUserAgreementDate, .remainingComplicationUserInfoTransfers:
            return .none
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .showDataInWatchComplications:
            return UserDefaults.standard.showDataInWatchComplications ? Texts_Common.enabled : Texts_Common.disabled
            
        case .watchComplicationUserAgreementDate:
            return UserDefaults.standard.watchComplicationUserAgreementDate?.formatted(date: .abbreviated, time: .shortened) ?? "-"
            
        case .remainingComplicationUserInfoTransfers:
            if let remainingComplicationUserInfoTrans = UserDefaults.standard.remainingComplicationUserInfoTransfers {
                return remainingComplicationUserInfoTrans.description + " / 50"
            } else {
                return "-"
            }
        }
    }
    
    // MARK: - observe functions
    
    private func addObservers() {
        
        // Listen for changes in the remaining complication transfers to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.remainingComplicationUserInfoTransfers.rawValue, options: .new, context: nil)
        
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else { return }
        
        switch keyPathEnum {
        case UserDefaults.Key.remainingComplicationUserInfoTransfers:
            
            // we have to run this in the main thread to avoid access errors
            DispatchQueue.main.async {
                self.sectionReloadClosure?()
            }
            
        default:
            break
        }
    }
    
}
