//
//  SettingsViewHealthKitSettingsViewModel.swift
//  xdrip
//
//  Created by Johan Degraeve on 23/2/19.
//  Copyright © 2019 Johan Degraeve. All rights reserved.
//

import Foundation
import HealthKit
import os

fileprivate enum Setting: Int, CaseIterable {
    /// should we write data to Apple Health?
    case enabledHealthKit = 0
}

/// conforms to SettingsViewModelProtocol for all healthkit settings in the first sections screen
class SettingsViewHealthKitSettingsViewModel:SettingsViewModelProtocol {
    
    // MARK: - private properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryHealthKitManager)
    
    // MARK: - Native SwiftUI rows
    
    func settingsRows(sectionID: Int) -> [SettingsRow] {
        [
            nativeSettingsRow(id: "healthKit.enabledHealthKit", index: Setting.enabledHealthKit.rawValue, sectionID: sectionID)
        ]
    }

    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        // if healthkit not available (iPad) then don't enable
        return HKHealthStore.isHealthDataAvailable()
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .enabledHealthKit:
            return .nothing
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleHealthKit
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .enabledHealthKit:
            return Texts_SettingsView.labelHealthKit
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .enabledHealthKit:
            return .none
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .enabledHealthKit:
            return nil
        }
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .enabledHealthKit:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.storeReadingsInHealthkit },
                setIsOn: { [weak self] isOn in
                    self?.setStoreReadingsInHealthKit(isOn)
                }
            )
        }
    }
    

    private func setStoreReadingsInHealthKit(_ isOn: Bool) {
        trace("storeReadingsInHealthkit changed by user to %{public}@", log: log, category: ConstantsLog.categorySettingsViewHealthKitSettingsViewModel, type: .info, isOn.description)

        // if value change to on, then verify authorization status and if needed ask authorization
        if isOn {
            // if creation of bloodGlucoseType fails, then we result in an inconsistent situation
            if let bloodGlucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
                let healthStore = HKHealthStore()
                let authorizationStatus = healthStore.authorizationStatus(for: bloodGlucoseType)
                switch authorizationStatus {
                case .notDetermined:
                    var shareTypes = Set<HKSampleType>()
                    shareTypes.insert(bloodGlucoseType)
                    healthStore.requestAuthorization(toShare: shareTypes, read: nil, completion: { (success: Bool, error: Error?) in
                        UserDefaults.standard.storeReadingsInHealthkitAuthorized = success

                        if let error = error {
                            trace("user did not authorize to store bg readings in  healthkit, error = %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewHealthKitSettingsViewModel, type: .error, error.localizedDescription)
                        }
                    })
                case .sharingDenied:
                    UserDefaults.standard.storeReadingsInHealthkitAuthorized = false
                    // user must have removed the authorization in the healt app - when user tries to enable healthkit , user will not be informed that he should first go back to the healt app and allow upload bgreadings - let's do such info in a later phase, eg with an info button next to the setting
                    trace("user removed authorization to store bgreadings in healthkit", log: log, category: ConstantsLog.categorySettingsViewHealthKitSettingsViewModel, type: .error)
                case .sharingAuthorized:
                    break
                @unknown default:
                    trace("unknown authorizationstatus for healthkit - SettingsViewHealthKitSettingsViewModel", log: log, category: ConstantsLog.categorySettingsViewHealthKitSettingsViewModel, type: .error)
                }
            } else {
                trace("user enabled HealthKit however failed to create bloodGlucoseType", log: log, category: ConstantsLog.categorySettingsViewHealthKitSettingsViewModel, type: .error)
                return
            }
        }

        // set UserDefaults.standard.storeReadingsInHealthkit to isOn
        UserDefaults.standard.storeReadingsInHealthkit = isOn
    }
}
