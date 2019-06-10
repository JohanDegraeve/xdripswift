import UIKit
import HealthKit
import os

/// conforms to SettingsViewModelProtocol for all healthkit settings in the first sections screen
class SettingsViewHealthKitSettingsViewModel:SettingsViewModelProtocol {
    
    // MARK: - private properties
    
    /// for logging
    private var log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryHealthKitManager)

    // MARK: - functions in protocol SettingsViewModelProtocol
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        // if healthkit not available (iPad) then don't enable
        return HKHealthStore.isHealthDataAvailable()
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        return SettingsSelectedRowAction.nothing
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleHealthKit
    }

    func numberOfRows() -> Int {
        return 1
    }

    func settingsRowText(index: Int) -> String {
        return Texts_SettingsView.labelHealthKit
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        return UITableViewCell.AccessoryType.none
    }
    
    func detailedText(index: Int) -> String? {
        return nil
    }
    
    func uiView(index:Int) -> UIView? {
        return UISwitch(isOn: UserDefaults.standard.storeReadingsInHealthkit, action: {
            (isOn:Bool) in
            
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
                        healthStore.requestAuthorization(toShare: shareTypes, read: nil, completion: { (success:Bool, error:Error?) in
                            
                            UserDefaults.standard.storeReadingsInHealthkitAuthorized = success
                            
                            if let error = error {
                                os_log("user did not authorize to store bg readings in  healthkit, error = %{public}@", log: self.log, type: .error, error.localizedDescription)
                            }
                        })
                    case .sharingDenied:
                        UserDefaults.standard.storeReadingsInHealthkitAuthorized = false
                        // user must have removed the authorization in the healt app - when user tries to enable healthkit , user will not be informed that he should first go back to the healt app and allow upload bgreadings - let's do such info in a later phase, eg with an info button next to the setting
                        os_log("user removed authorization to store bgreadings in healthkit", log: self.log, type: .error)
                    case .sharingAuthorized:
                        break
                    }
                } else {
                    os_log("User enabled HealthKit however failed to create bloodGlucoseType", log: self.log, type: .error)
                    return
                }
                
            }

            // set UserDefaults.standard.storeReadingsInHealthkit to isOn
            UserDefaults.standard.storeReadingsInHealthkit = isOn

        })
    }
}


