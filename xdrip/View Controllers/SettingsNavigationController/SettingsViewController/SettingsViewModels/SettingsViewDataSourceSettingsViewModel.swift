//
//  SettingsViewDataSourceSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 25/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import os
import UIKit

fileprivate enum Setting: Int, CaseIterable {
    /// blood glucose  unit
    case bloodGlucoseUnit = 0
    
    /// choose between master and follower
    case masterFollower = 1
    
    /// if follower, what should be the data source
    case followerDataSourceType = 2
    
    /// if follower, should we try and keep the app alive in the background
    case followerKeepAliveType = 3
    
    /// patient name/alias (optional) - useful for users who follow various people
    case followerPatientName = 4
    
    /// if follower data source is not Nightscout, should we upload the BG values to Nightscout?
    case followerUploadDataToNightscout = 5
    
    /// web follower username
    case followerUserName = 6
    
    /// web follower username
    case followerPassword = 7
    
    /// web follower sensor serial number (will not always be available)
    case followerSensorSerialNumber = 8
    
    /// web follower sensor start date (will not always be available)
    case followerSensorStartDate = 9
    
    /// web follower server region
    case followerRegion = 10
    
    /// should be set by the user to true if using a "Plus" sensor with a 15 day lifetime instead of 14 days
    case followerIs15DaySensor = 11
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewDataSourceSettingsViewModel: NSObject, SettingsViewModelProtocol {
    private var coreDataManager: CoreDataManager?
    
    /// the viewcontroller sets it by calling storeMessageHandler
    private var messageHandler: ((String, String) -> Void)?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel)
    
    init(coreDataManager: CoreDataManager?) {
        self.coreDataManager = coreDataManager
        
        super.init()
        
        addObservers()
    }
    
    private func callMessageHandlerInMainThread(title: String, message: String) {
        // unwrap messageHandler
        guard let messageHandler = messageHandler else { return }
        
        DispatchQueue.main.async {
            messageHandler(title, message)
        }
    }
    
    var sectionReloadClosure: (() -> Void)?
    
    func storeRowReloadClosure(rowReloadClosure: (Int) -> Void) {}
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {
        self.messageHandler = messageHandler
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        // changing follower to master or master to follower requires changing ui for nightscout settings and transmitter type settings
        // the same applies when changing bloodGlucoseUnit, because off the seperate section with bgObjectives
        if index == Setting.bloodGlucoseUnit.rawValue || index == Setting.masterFollower.rawValue || index == Setting.followerDataSourceType.rawValue { return true }
        
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .bloodGlucoseUnit:
            return SettingsSelectedRowAction.callFunction(function: {
                UserDefaults.standard.bloodGlucoseUnitIsMgDl ? (UserDefaults.standard.bloodGlucoseUnitIsMgDl = false) : (UserDefaults.standard.bloodGlucoseUnitIsMgDl = true)
                
            })

        case .masterFollower:
            // switching from master to follower will set cgm transmitter to nil and stop the sensor
            // if there's a sensor active then it's better to ask for a confirmation, if not then do the change without asking confirmation
            if UserDefaults.standard.isMaster {
                if let coreDataManager = coreDataManager {
                    if SensorsAccessor(coreDataManager: coreDataManager).fetchActiveSensor() != nil {
                        return .askConfirmation(title: Texts_Common.warning, message: Texts_SettingsView.warningChangeFromMasterToFollower, actionHandler: {
                            UserDefaults.standard.isMaster = false
                            
                        }, cancelHandler: nil)

                    } else {
                        // no sensor active - set to follower
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
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.labelFollowerDataSourceType, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: { (index: Int) in
                
                // we'll set this here so that we can use it in the else statement for logging
                let oldFollowerDataSourceType = UserDefaults.standard.followerDataSourceType
                
                if index != selectedRow {
                    UserDefaults.standard.followerDataSourceType = FollowerDataSourceType(rawValue: index) ?? .nightscout
                    
                    let newFollowerDataSourceType = UserDefaults.standard.followerDataSourceType
                    
                    trace("follower source data type was changed from '%{public}@' to '%{public}@'", log: self.log, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel, type: .info, oldFollowerDataSourceType.description, newFollowerDataSourceType.description)
                }
                
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .followerKeepAliveType:
            // data to be displayed in list from which user needs to pick a follower keep-alive type
            var data = [String]()
            var selectedRow: Int?
            var index = 0
            let currentKeepAliveType = UserDefaults.standard.followerBackgroundKeepAliveType
            
            // get all data source types and add the description to data. Search for the type that matches the FollowerDataSourceType that is currently stored in userdefaults.
            for keepAliveType in FollowerBackgroundKeepAliveType.allCases {
                data.append(keepAliveType.description)
                
                if keepAliveType == currentKeepAliveType {
                    selectedRow = index
                }
                
                index += 1
            }
            
            return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.labelfollowerKeepAliveType, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: { (index: Int) in
                // we'll set this here so that we can use it for logging
                let oldFollowerBackgroundKeepAliveType = UserDefaults.standard.followerBackgroundKeepAliveType
                
                if index != selectedRow {
                    UserDefaults.standard.followerBackgroundKeepAliveType = FollowerBackgroundKeepAliveType(rawValue: index) ?? .normal
                    
                    let newFollowerBackgroundKeepAliveType = UserDefaults.standard.followerBackgroundKeepAliveType
                    
                    trace("follower background keep-alive type was changed from '%{public}@' to '%{public}@'", log: self.log, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel, type: .info, oldFollowerBackgroundKeepAliveType.description, newFollowerBackgroundKeepAliveType.description)
                    
                    var message = "\n"
                    
                    switch newFollowerBackgroundKeepAliveType {
                    case .disabled:
                        message += Texts_SettingsView.followerKeepAliveTypeDisabledMessage
                    case .normal:
                        message += Texts_SettingsView.followerKeepAliveTypeNormalMessage
                    case .aggressive:
                        message += Texts_SettingsView.followerKeepAliveTypeAggressiveMessage
                    case .heartbeat:
                        message += Texts_SettingsView.followerKeepAliveTypeHeartbeatMessage
                    }
                    
                    self.callMessageHandlerInMainThread(title: Texts_SettingsView.labelfollowerKeepAliveType, message: message)
                }
                
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .followerPatientName:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.followerPatientName, message: Texts_SettingsView.followerPatientNameMessage, keyboardType: .default, text: UserDefaults.standard.followerPatientName, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (followerPatientName: String) in
                
                UserDefaults.standard.followerPatientName = followerPatientName.toNilIfLength0()
                
            }, cancelHandler: nil, inputValidator: nil)
            
        case .followerUploadDataToNightscout:
            return UserDefaults.standard.nightscoutEnabled ? .nothing : SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.nightscoutNotEnabled)
            
        case .followerUserName:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp:
                return SettingsSelectedRowAction.askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterUsername, keyboardType: .default, text: UserDefaults.standard.libreLinkUpEmail, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (libreLinkUpEmail: String) in
                        
                    UserDefaults.standard.libreLinkUpEmail = libreLinkUpEmail.toNilIfLength0()
                        
                    // if the user has changed their account name, then let's also nillify the password for them so that we don't try and login with bad credentials
                    UserDefaults.standard.libreLinkUpPassword = nil
                        
                    // reset all data used in the UI
                    self.resetLibreLinkUpData()
                        
                }, cancelHandler: nil, inputValidator: nil)
                    
            default:
                return .nothing
            }
            
        case .followerPassword:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp:
                return SettingsSelectedRowAction.askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterPassword, keyboardType: .default, text: UserDefaults.standard.libreLinkUpPassword, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (libreLinkUpPassword: String) in
    
                    UserDefaults.standard.libreLinkUpPassword = libreLinkUpPassword.toNilIfLength0()
                        
                    // reset all data used in the UI
                    self.resetLibreLinkUpData()
                        
                }, cancelHandler: nil, inputValidator: nil)
                    
            default:
                return .nothing
            }
            
        case .followerSensorStartDate:
            if let startDate = UserDefaults.standard.activeSensorStartDate {
                var startDateString = startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                
                startDateString += "\n\n" + startDate.daysAndHoursAgo() + " " + Texts_HomeView.ago
                
                return .showInfoText(title: Texts_BluetoothPeripheralView.sensorStartDate, message: "\n" + startDateString)
                
            } else {
                return .nothing
            }
            
        case .followerSensorSerialNumber, .followerRegion, .followerIs15DaySensor:
            return .nothing
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.dataSourceSettingsIcon + " " + Texts_SettingsView.sectionTitleDataSource
    }

    func numberOfRows() -> Int {
        // if master is selected then just show this row and hide the rest
        if UserDefaults.standard.isMaster {
            return 2
            
        } else {
            let count = Setting.allCases.count
            
            switch UserDefaults.standard.followerDataSourceType {
            case .nightscout:
                // no need to show any extra rows/settings (beyond patient name) as all Nightscout required parameters are set in the Nightscout section
                return 5
            
            case .libreLinkUp:
                // show all sections if needed. If there is no active sensor data then just hide some of the rows
                return UserDefaults.standard.activeSensorSerialNumber != nil ? count : count - (UserDefaults.standard.libreLinkUpPassword == nil || UserDefaults.standard.libreLinkUpEmail == nil ? 4 : 3)
            }
        }
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .bloodGlucoseUnit:
            return Texts_SettingsView.labelSelectBgUnit
            
        case .masterFollower:
            return Texts_SettingsView.labelMasterOrFollower
            
        case .followerDataSourceType:
            return Texts_SettingsView.labelFollowerDataSourceType
            
        case .followerKeepAliveType:
            return Texts_SettingsView.labelfollowerKeepAliveType
            
        case .followerPatientName:
            return Texts_SettingsView.followerPatientName
            
        case .followerUploadDataToNightscout:
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
            
        case .followerIs15DaySensor:
            if processLibreLinkUpSensorInfo(sn: UserDefaults.standard.activeSensorSerialNumber).prefix(5) == "Libre" {
                return processLibreLinkUpSensorInfo(sn: UserDefaults.standard.activeSensorSerialNumber).prefix(7) + " Plus (15 " + Texts_Common.days + ")?"
            } else {
                return Texts_SettingsView.labelFollowerIs15DaySensor
            }
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .bloodGlucoseUnit, .masterFollower, .followerUploadDataToNightscout, .followerSensorSerialNumber, .followerRegion, .followerIs15DaySensor:
            return UITableViewCell.AccessoryType.none
            
        case .followerDataSourceType, .followerKeepAliveType, .followerPatientName, .followerUserName, .followerPassword:
            return UITableViewCell.AccessoryType.disclosureIndicator
            
        case .followerSensorStartDate:
            return UserDefaults.standard.activeSensorStartDate != nil ? UITableViewCell.AccessoryType.disclosureIndicator : UITableViewCell.AccessoryType.none
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .bloodGlucoseUnit:
            return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
            
        case .masterFollower:
            return UserDefaults.standard.isMaster ? Texts_SettingsView.master : Texts_SettingsView.follower
            
        case .followerDataSourceType:
            return UserDefaults.standard.followerDataSourceType.description
            
        case .followerKeepAliveType:
            return UserDefaults.standard.followerBackgroundKeepAliveType.description
            
        case .followerPatientName:
            return UserDefaults.standard.followerPatientName ?? "(optional)"
            
        case .followerUploadDataToNightscout:
            return UserDefaults.standard.nightscoutEnabled ? nil : Texts_SettingsView.nightscoutNotEnabledRowText
            
        case .followerUserName:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp:
                return UserDefaults.standard.libreLinkUpEmail?.obscured() ?? Texts_SettingsView.valueIsRequired
            default:
                return nil
            }
            
        case .followerPassword:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp:
                return UserDefaults.standard.libreLinkUpPassword?.obscured() ?? Texts_SettingsView.valueIsRequired
            default:
                return nil
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
                        return "⚠️ " + Texts_SettingsView.libreLinkUpNoActiveSensor
                    }
                }
                
            default:
                return nil
            }
            
        case .followerSensorStartDate:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp:
                if let startDate = UserDefaults.standard.activeSensorStartDate {
                    let sensorTimeInMinutes = Int(Date().timeIntervalSince1970 - startDate.timeIntervalSince1970) / 60
                    
                    if sensorTimeInMinutes < Int(ConstantsLibreLinkUp.sensorWarmUpRequiredInMinutesForLibre) {
                        // the Libre sensor is still in warm-up time so let's make it clear to the user
                        let sensorReadyDateTime = startDate.addingTimeInterval(ConstantsLibreLinkUp.sensorWarmUpRequiredInMinutesForLibre * 60)
                        
                        let startDateString = Texts_BluetoothPeripheralView.warmingUpUntil + " " + sensorReadyDateTime.toStringInUserLocale(timeStyle: .short, dateStyle: .none)
                        
                        return startDateString
                    } else {
                        let startDateString = startDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short) + " (" + startDate.daysAndHoursAgo() + ")"
                        
                        return startDateString
                    }
                    
                } else {
                    return "-"
                }
            default:
                return nil
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
                    return "-"
                }
                
            default:
                return nil
            }
            
        case .followerIs15DaySensor:
            return nil
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .followerUploadDataToNightscout:
            return UserDefaults.standard.nightscoutEnabled ? UISwitch(isOn: UserDefaults.standard.followerUploadDataToNightscout, action: { (isOn: Bool) in UserDefaults.standard.followerUploadDataToNightscout = isOn }) : nil
            
        case .followerIs15DaySensor:
            return UISwitch(isOn: UserDefaults.standard.libreLinkUpIs15DaySensor, action: { (isOn: Bool) in
                UserDefaults.standard.libreLinkUpIs15DaySensor = isOn
                UserDefaults.standard.activeSensorMaxSensorAgeInDays = UserDefaults.standard.libreLinkUpIs15DaySensor ? ConstantsLibreLinkUp.libreLinkUpMaxSensorAgeInDaysLibrePlus : ConstantsLibreLinkUp.libreLinkUpMaxSensorAgeInDays
            })

        case .bloodGlucoseUnit, .masterFollower, .followerDataSourceType, .followerKeepAliveType, .followerPatientName, .followerUserName, .followerPassword, .followerSensorSerialNumber, .followerSensorStartDate, .followerRegion:
            return nil
        }
    }
    
    func resetLibreLinkUpData() {
        UserDefaults.standard.libreLinkUpRegion = nil
        UserDefaults.standard.activeSensorStartDate = nil
        UserDefaults.standard.activeSensorSerialNumber = nil
        UserDefaults.standard.libreLinkUpCountry = nil
        UserDefaults.standard.libreLinkUpPreventLogin = false
    }
    
    func processLibreLinkUpSensorInfo(sn: String?) -> String {
        var returnString = "Not recognised"
        
        if let sn = sn {
            returnString = sn
            
            if sn.range(of: #"^MH"#, options: .regularExpression) != nil {
                // MHxxxxxxxx
                // must be a L2 sensor
                returnString = "Libre 2 " + (UserDefaults.standard.libreLinkUpIs15DaySensor ? "Plus " : "") + "(3" + sn + ")"
                
            } else if sn.range(of: #"^0D"#, options: .regularExpression) != nil || sn.range(of: #"^0E"#, options: .regularExpression) != nil || sn.range(of: #"^0F"#, options: .regularExpression) != nil {
                // must be a Libre 3 sensor
                let newString = "Libre 3 " + (UserDefaults.standard.libreLinkUpIs15DaySensor ? "Plus " : "") + "(" + String(sn.dropLast()) + ")"
                
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
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
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
