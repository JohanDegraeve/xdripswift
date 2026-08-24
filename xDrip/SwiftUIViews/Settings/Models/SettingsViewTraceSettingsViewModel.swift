//
//  SettingsViewTraceSettingsViewModel.swift
//  xdrip
//
//  Created by Johan Degraeve on 2/5/20.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation

/// Stable row indexes retained for the legacy `SettingsViewModelProtocol` bridge.
fileprivate enum Setting:Int, CaseIterable {

    /// Opens the short, consumer-safe activity history.
    case troubleshootingLog = 0
    
    /// Opens the existing e-mail workflow with private developer trace attachments.
    case sendTraceFile = 1
    
    /// Controls whether debug-level developer messages enter the trace files.
    case debugLevel = 2
    
}

/// Supplies either the visible consumer Activity Log row or the developer-report child screen.
/// The separation is intentional: the activity log must never become an e-mail attachment, and the
/// developer trace must never be loaded by the shareable log viewer. The developer group is opened
/// only from the Issue Report row revealed by Show Advanced.
enum SettingsViewTraceSettingsRowGroup {
    case troubleshooting
    case developerReport
}

/// Supplies consumer troubleshooting at the root or developer reporting inside its child screen.
class SettingsViewTraceSettingsViewModel: NSObject {
    private let rowGroup: SettingsViewTraceSettingsRowGroup
    
    init(rowGroup: SettingsViewTraceSettingsRowGroup = .developerReport) {
        self.rowGroup = rowGroup

        super.init()
    }

}

extension SettingsViewTraceSettingsViewModel: SettingsViewModelProtocol {
    
    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        switch rowGroup {
        case .troubleshooting:
            return [
                SettingsRow(
                    id: "trace.troubleshootingLog",
                    title: Texts_SettingsView.viewActivityLog,
                    accessory: .disclosure,
                    action: .troubleshootingLog
                )
            ]

        case .developerReport:
            return [
                // Debug detail changes what the report contains, so present that choice before the
                // action that creates the e-mail. This makes the section read in workflow order.
                nativeSettingsRow(id: "trace.debugLevel", index: Setting.debugLevel.rawValue, sectionID: sectionID),
                SettingsRow(
                    id: "trace.sendTraceFile",
                    title: Texts_SettingsView.sendTraceFile,
                    accessory: .disclosure,
                    action: .sendTraceEmail
                )
            ]
        }
    }

    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
    

    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {}
    
    func sectionTitle() -> String? {
        switch rowGroup {
        case .troubleshooting:
            return Texts_SettingsView.troubleshootingTitle
        case .developerReport:
            // The child navigation title already says Issue Report, so another section title would
            // add repetition without clarifying the two controls.
            return nil
        }
    }

    func settingsSectionFooter() -> String? {
        switch rowGroup {
        case .troubleshooting:
            // The row label and Troubleshooting heading already explain the destination. The former
            // explanatory footer made this compact root section unnecessarily visually dominant.
            return nil
        case .developerReport:
            return Texts_SettingsView.issueReportSectionFooter
        }
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

        case .troubleshootingLog:
            return Texts_SettingsView.viewActivityLog
            
        case .sendTraceFile:
            return Texts_SettingsView.sendTraceFile
            
        case .debugLevel:
            return Texts_SettingsView.debugLevel
            
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

        case .troubleshootingLog:
            return .disclosure
            
        case .sendTraceFile:
            return .disclosure
            
        case .debugLevel:
            return .none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

        case .troubleshootingLog:
            return nil
            
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
        case .troubleshootingLog, .sendTraceFile:
            return nil
        }
    }
    
    
    func numberOfRows() -> Int {
        switch rowGroup {
        case .troubleshooting:
            return 1
        case .developerReport:
            return 2
        }
    }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

        case .troubleshootingLog:
            return .nothing
            
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
