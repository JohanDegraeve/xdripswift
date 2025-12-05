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
    // does the user agree to show data in the complications knowing that it will not always be up-to-date?
    case showDataInWatchComplications = 0
    
    /// the date that the user agreed
    case watchComplicationUserAgreementDate = 1
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
        case .showDataInWatchComplications, .watchComplicationUserAgreementDate:
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
                    trace("showDataInWatchComplications agreed OK by user", log: self.log, category: ConstantsLog.categorySettingsViewAppleWatchSettingsViewModel, type: .info)
                    UserDefaults.standard.showDataInWatchComplications = true
                    UserDefaults.standard.watchComplicationUserAgreementDate = .now
                }, cancelHandler: {
                    trace("showDataInWatchComplications cancelled by user", log: self.log, category: ConstantsLog.categorySettingsViewAppleWatchSettingsViewModel, type: .info)
                    UserDefaults.standard.showDataInWatchComplications = false
                    UserDefaults.standard.watchComplicationUserAgreementDate = nil
                    // we have to run this in the main thread to avoid access errors
                    DispatchQueue.main.async {
                        self.sectionReloadClosure?()
                    }
                })
            
        case .watchComplicationUserAgreementDate:
            return .nothing
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.appleWatchSettingsIcon + " " + Texts_SettingsView.appleWatchSectionTitle
    }
    
    func numberOfRows() -> Int {
        // if the user doesn't enable the complications, then hide the rest of the settings
        return Setting.allCases.count - (UserDefaults.standard.showDataInWatchComplications ? 0 : 1)
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showDataInWatchComplications:
            return Texts_SettingsView.appleWatchShowDataInComplications
            
        case .watchComplicationUserAgreementDate:
            return Texts_SettingsView.appleWatchComplicationUserAgreementDate
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showDataInWatchComplications:
            return .disclosureIndicator
        case .watchComplicationUserAgreementDate:
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
        }
    }
}
