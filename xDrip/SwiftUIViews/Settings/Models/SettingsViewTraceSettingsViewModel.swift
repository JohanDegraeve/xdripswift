//
//  SettingsViewTraceSettingsViewModel.swift
//  xdrip
//
//  Created by Johan Degraeve on 2/5/20.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation

fileprivate enum Setting:Int, CaseIterable {
    
    /// to send trace file
    case sendTraceFile = 0
    
    /// should debug level logs be stored in trace file yes or no
    case debugLevel = 1
    
}

class SettingsViewTraceSettingsViewModel: NSObject {
    
    private let sectionTitleOverride: String?
    
    init(sectionTitleOverride: String? = nil) {
        self.sectionTitleOverride = sectionTitleOverride

        super.init()
    }

}

extension SettingsViewTraceSettingsViewModel: SettingsViewModelProtocol {
    
    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        [
            SettingsRow(
                id: "trace.sendTraceFile",
                title: Texts_SettingsView.sendTraceFile,
                accessory: .disclosure,
                action: .sendTraceEmail
            ),
            nativeSettingsRow(id: "trace.debugLevel", index: Setting.debugLevel.rawValue, sectionID: sectionID)
        ]
    }

    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
    

    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {}
    
    func sectionTitle() -> String? {
        if let sectionTitleOverride {
            return sectionTitleOverride
        }

        return Texts_SettingsView.sectionTitleTrace
    }

    func settingsSectionFooter() -> String? {
        Texts_SettingsView.issueReportSectionFooter
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .sendTraceFile:
            return Texts_SettingsView.sendTraceFile
            
        case .debugLevel:
            return Texts_SettingsView.debugLevel
            
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .sendTraceFile:
            return .disclosure
            
        case .debugLevel:
            return .none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .sendTraceFile:
            return nil
            
        case .debugLevel:
            return nil
            
        }
        
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .debugLevel:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog },
                setIsOn: { UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog = $0 }
            )
        case .sendTraceFile:
            return nil
        }
    }
    
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .sendTraceFile:
            return .nothing
            
        case .debugLevel:
            return .nothing
            
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        return false
        
    }
    
}
