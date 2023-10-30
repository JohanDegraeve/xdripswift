//
//  SettingsViewDataSourceSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 25/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import UIKit
import SwiftUI

fileprivate enum Setting: Int, CaseIterable {
    
    /// choose between master and follower
    case masterFollower = 0
    
    /// if follower, what should be the data source
    case followerDataSourceType = 1
    
    /// if follower data source is not Nightscout, should we upload the BG values to Nightscout?
    case uploadFollowerDataToNightscout = 2
    
    /// web follower username
    case followerUserName = 3
    
    /// web follower username
    case followerPassword = 4
    
    /// web follower sensor serial number (will not always be available)
    case followerSensorSerialNumber = 5
    
    /// web follower sensor start date (will not always be available)
    case followerSensorStartDate = 6
    
    /// web follower server region
    case followerRegion = 7
    
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewDataSourceSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    private var coreDataManager: CoreDataManager?
    
    init(coreDataManager: CoreDataManager?) {
        
        self.coreDataManager = coreDataManager
        
        super.init()
        
        addObservers()
        
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
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        // changing follower to master or master to follower requires changing ui for nightscout settings and transmitter type settings
        if (index == Setting.masterFollower.rawValue || index == Setting.followerDataSourceType.rawValue) {return true}
        
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {

        case .masterFollower:
            
            // switching from master to follower will set cgm transmitter to nil and stop the sensor. If there's a sensor active then it's better to ask for a confirmation, if not then do the change without asking confirmation

            if UserDefaults.standard.isMaster {
                
                if let coreDataManager = coreDataManager {
                    
                    if SensorsAccessor(coreDataManager: coreDataManager).fetchActiveSensor() != nil {

                        return .askConfirmation(title: Texts_Common.warning, message: Texts_SettingsView.warningChangeFromMasterToFollower, actionHandler: {
                            
                            UserDefaults.standard.isMaster = false
                            
                        }, cancelHandler: nil)

                    } else {
                        
                        // no sensor active
                        // set to follower
                        return SettingsSelectedRowAction.callFunction(function: {
                            UserDefaults.standard.isMaster = false
                        })
                        
                    }
                    
                } else {
                    
                    // coredata manager is nil, should normally not be the case
                    return SettingsSelectedRowAction.callFunction(function: {
                        UserDefaults.standard.isMaster = false
                    })

                }
                
                
            } else {
                
                // switching from follower to master
                return SettingsSelectedRowAction.callFunction(function: {
                    UserDefaults.standard.isMaster = true
                })

            }
            
        case .followerDataSourceType:
            
            // data to be displayed in list from which user needs to pick a follower data source
            var data = [String]()

            var selectedRow: Int?

            var index = 0
            
            let currentFollowerDataSourceType = UserDefaults.standard.followerDataSourceType
            
            // get all data source types and add the description to data. Search for the type that matches the FollowerDataSourceType that is currently stored in userdefaults.
            for dataSourceType in FollowerDataSourceType.allCases {
                
                data.append(dataSourceType.description)
                
                if dataSourceType == currentFollowerDataSourceType {
                    selectedRow = index
                }
                
                index += 1
                
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.labelFollowerDataSourceType, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                
                // we'll set this here so that we can use it in the else statement for logging
                let oldFollowerDataSourceType = UserDefaults.standard.followerDataSourceType
                
                if index != selectedRow {
                    
                    UserDefaults.standard.followerDataSourceType = FollowerDataSourceType(rawValue: index) ?? .nightscout
                    
                    let newFollowerDataSourceType = UserDefaults.standard.followerDataSourceType
                    
                    print("Follower source data type was changed from '" + oldFollowerDataSourceType.description + "' to '" + newFollowerDataSourceType.description + "'")
                    
                    if UserDefaults.standard.followerDataSourceType.needsUserNameAndPassword() && ( UserDefaults.standard.libreLinkUpEmail == nil || UserDefaults.standard.libreLinkUpPassword == nil) {
                        
                        _ = SettingsSelectedRowAction.showInfoText(title: "Account details needed", message: "In order to use LibreLinkUp follower mode, you need to add the e-mail address and password of the LibreLinkUpUp account that was invited to view BG values")
                        
                    }
                    
                } else {
                    print("Follower source data type was kept as '" + oldFollowerDataSourceType.description + "'")
                }
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .uploadFollowerDataToNightscout:
            
            return UserDefaults.standard.nightScoutEnabled ? .nothing : SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.nightscoutNotEnabled)
            
        case .followerUserName:
            
                switch UserDefaults.standard.followerDataSourceType {
                    
                case .libreLinkUp:
                    return SettingsSelectedRowAction.askText(title: UserDefaults.standard.followerDataSourceType.description, message:  Texts_SettingsView.enterUsername, keyboardType: .default, text: UserDefaults.standard.libreLinkUpEmail, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(libreLinkUpEmail: String) in
                        
                        UserDefaults.standard.libreLinkUpEmail = libreLinkUpEmail.toNilIfLength0()
                        
                        // if the user has changed their account name, then let's also nillify the password for them so that we don't try and login with bad credentials
                        UserDefaults.standard.libreLinkUpPassword = nil
                        
                        // reset all data used in the UI
                        self.resetLibreLinkUpUpData()
                        
                    }, cancelHandler: nil, inputValidator: nil)
                    
                default:
                    return .nothing
                    
                }
            
            
        case .followerPassword:
            
                switch UserDefaults.standard.followerDataSourceType {
                    
                case .libreLinkUp:
                    return SettingsSelectedRowAction.askText(title: UserDefaults.standard.followerDataSourceType.description, message:  Texts_SettingsView.enterPassword, keyboardType: .default, text: UserDefaults.standard.libreLinkUpPassword, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(libreLinkUpPassword: String) in
    
                        UserDefaults.standard.libreLinkUpPassword = libreLinkUpPassword.toNilIfLength0()
                        
                        // reset all data used in the UI
                        self.resetLibreLinkUpUpData()
                        
                    }, cancelHandler: nil, inputValidator: nil)
                    
                default:
                    return .nothing
                    
                }
            
        case .followerSensorSerialNumber:
            return .nothing
            
        case .followerSensorStartDate:
                
            if let startDate = UserDefaults.standard.activeSensorStartDate {
                
                var startDateString = startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                
                startDateString += "\n\n" + startDate.daysAndHoursAgo() + " " + Texts_HomeView.ago
                
                return .showInfoText(title: Texts_BluetoothPeripheralView.sensorStartDate, message: "\n" + startDateString)
                
            } else {
                return .nothing
            }
            
        case .followerRegion:
            
            switch UserDefaults.standard.followerDataSourceType {
                
            case .libreLinkUp:
                return .nothing
                
            default:
                return .nothing
                
            }
            
        }
        
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleDataSource
    }

    func numberOfRows() -> Int {
        
        // if master is selected then just show this row and hide the rest
        if UserDefaults.standard.isMaster {
            
            return 1
            
        } else {
            
            let count = Setting.allCases.count
            
            switch UserDefaults.standard.followerDataSourceType {
            
            case .nightscout:
                // no need to show any extra rows/settings as all Nightscout required parameters are set in the Nightscout section
                return 2
            
            case .libreLinkUp:
                // show all sections
                return count
                
            }
            
        }
        
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .masterFollower:
            return Texts_SettingsView.labelMasterOrFollower
            
        case .followerDataSourceType:
            return Texts_SettingsView.labelFollowerDataSourceType
            
        case .uploadFollowerDataToNightscout:
            return Texts_SettingsView.labelUploadFollowerDataToNightscout
            
        case .followerUserName:
            return Texts_Common.username
            
        case .followerPassword:
            return Texts_Common.password
            
        case .followerSensorSerialNumber:
            return Texts_HomeView.sensor
            
        case .followerSensorStartDate:
            return Texts_BluetoothPeripheralView.sensorStartDate
            
        case .followerRegion:
            return Texts_SettingsView.labelFollowerDataSourceRegion
            
        }
        
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
    
        case .masterFollower, .uploadFollowerDataToNightscout, .followerSensorSerialNumber, .followerRegion:
            return UITableViewCell.AccessoryType.none
            
        case .followerDataSourceType, .followerUserName, .followerPassword:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .followerSensorStartDate:
            
            if UserDefaults.standard.activeSensorStartDate != nil {
                
                return UITableViewCell.AccessoryType.disclosureIndicator
                
            } else {
                
                return UITableViewCell.AccessoryType.none
                
            }
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .masterFollower:
            return UserDefaults.standard.isMaster ? Texts_SettingsView.master : Texts_SettingsView.follower
            
        case .followerDataSourceType:
            return UserDefaults.standard.followerDataSourceType.description
            
        case .uploadFollowerDataToNightscout:
            return UserDefaults.standard.nightScoutEnabled ? nil : Texts_SettingsView.nightscoutNotEnabledRowText
            
        case .followerUserName:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp:
                return UserDefaults.standard.libreLinkUpEmail?.obscured() ?? ""
            default:
                return ""
            }
            
        case .followerPassword:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp:
                return UserDefaults.standard.libreLinkUpPassword?.obscured() ?? ""
            default:
                return ""
            }
            
        case .followerSensorSerialNumber:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp:
                
                // we will use this row to also show important information regarding any login errors
                if UserDefaults.standard.libreLinkUpReAcceptNeeded {
                    return Texts_SettingsView.libreLinkUpReAcceptNeeded
                } else {
                    
                    if UserDefaults.standard.activeSensorSerialNumber != nil {
                        // nicely format the (incomplete) serial numbers from LibreLinkUp
                        return processLibreLinkUpSensorInfo(sn: UserDefaults.standard.activeSensorSerialNumber)
                    } else if UserDefaults.standard.libreLinkUpPreventLogin {
                        return "Invalid User/Password"
                    } else {
                        return Texts_SettingsView.libreLinkUpNoActiveSensor
                    }
                }
                
            default:
                return ""
            }
            
        case .followerSensorStartDate:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp:
                if let startDate = UserDefaults.standard.activeSensorStartDate {
                    
                    var startDateString = startDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short)
                    
                    startDateString += " (" + startDate.daysAndHoursAgo() + ")"
                    
                    return startDateString
                    
                } else {
                    return ""
                }
            default:
                return ""
            }
            
        case .followerRegion:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp:
                
                if UserDefaults.standard.activeSensorSerialNumber != nil {
                    
                    var returnString = UserDefaults.standard.libreLinkUpRegion?.description ?? ""
                    
                    if let country = UserDefaults.standard.libreLinkUpCountry {
                        returnString += " (" + country + ")"
                    }
                    
                    return returnString
                    
                } else {
                    return ""
                }
                
            default:
                return ""
            }
            
        }
    }
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

        case .masterFollower, .followerDataSourceType, .followerUserName, .followerPassword, .followerSensorSerialNumber, .followerSensorStartDate, .followerRegion:
            return nil
            
        case .uploadFollowerDataToNightscout:
            
            return UserDefaults.standard.nightScoutEnabled ? UISwitch(isOn: UserDefaults.standard.uploadFollowerDataToNightscout, action: {(isOn:Bool) in UserDefaults.standard.uploadFollowerDataToNightscout = isOn}) : nil
            
        }

    }
    
    func resetLibreLinkUpUpData() {
        
        UserDefaults.standard.libreLinkUpRegion = nil
        UserDefaults.standard.activeSensorStartDate = nil
        UserDefaults.standard.activeSensorSerialNumber = nil
        UserDefaults.standard.libreLinkUpCountry = nil
        UserDefaults.standard.libreLinkUpPreventLogin = false
        
    }
    
    func processLibreLinkUpSensorInfo(sn: String?) -> String {
        
        var returnString: String = "Not recognised"
        
        if let sn = sn {
            
            returnString = sn
            
            if sn.range(of: #"^MH"#, options: .regularExpression) != nil {
                
                // MHxxxxxxxx
                // must be a L2 sensor
                returnString = "Libre 2 (3" + sn + ")"
                
            } else if sn.range(of: #"^0D"#, options: .regularExpression) != nil || sn.range(of: #"^0E"#, options: .regularExpression) != nil || sn.range(of: #"^0F"#, options: .regularExpression) != nil{
                
                // must be a Libre 3 sensor
                let newString = "Libre 3 (" + String(sn.dropLast()) + ")"
                
                returnString = newString
                
            }
            
        }
        
        return returnString
        
    }
    
    // MARK: - observe functions
    
    private func addObservers() {
        
        // Listen for changes in the active sensor value to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.activeSensorSerialNumber.rawValue, options: .new, context: nil)
        
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else { return }
        
        switch keyPathEnum {
        case UserDefaults.Key.activeSensorSerialNumber:
            
            // we have to run this in the main thread to avoid access errors
            DispatchQueue.main.async {
                self.sectionReloadClosure?()
            }
            
        default:
            break
            
        }
    }
}
