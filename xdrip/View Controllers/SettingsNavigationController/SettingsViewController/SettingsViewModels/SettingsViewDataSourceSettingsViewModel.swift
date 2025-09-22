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
    
    /// - Master: Upload CGM values to Nightscout?
    /// - Follower: what should be the data source
    case followerExtraRow2 = 2
    
    /// - Follower: should we try and keep the app alive in the background
    case followerExtraRow3 = 3
    
    /// - Follower: patient name/alias (optional) - useful for users who follow various people or just want to have the name visible
    case followerExtraRow4 = 4
    
    /// - Follower: if follower data source is not Nightscout, should we upload the BG values to Nightscout?
    case followerExtraRow5 = 5
    
    /// - Follower: web follower username
    case followerExtraRow6 = 6
    
    /// - Follower: web follower username
    case followerExtraRow7 = 7
    
    /// - Follower
    ///  - LibreLinkUp: followerSensorSerialNumber (web follower sensor serial number - will not always be available)
    ///  - Follower Dexcom Share: Use US servers
    case followerExtraRow8 = 8
    
    /// - Follower
    ///  - LibreLinkUp:  followerSensorStartDate (web follower sensor start date - will not always be available)
    case followerExtraRow9 = 9
    
    /// - Follower
    ///  - LibreLinkUp:  followerRegion (web follower server region)
    case followerExtraRow10 = 10
    
    /// - Follower
    ///  - LibreLinkUp:  followerIs15DaySensor (should be set by the user to true if using a "Plus" sensor with a 15 day lifetime instead of 14 days)
    case followerExtraRow11 = 11
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
        if index == Setting.bloodGlucoseUnit.rawValue || index == Setting.masterFollower.rawValue || index == Setting.followerExtraRow2.rawValue { return true }
        
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
                        if UserDefaults.standard.followerDataSourceType == .dexcomShare && UserDefaults.standard.uploadReadingstoDexcomShare {
                            // as Dexcom Share was the previously selected follower mode and the user had upload to dexcom share enabled,
                            // inform then that we'll disable the upload
                            return .askConfirmation(title: Texts_Common.warning, message: Texts_SettingsView.warningChangeFromMasterToFollowerDexcomShare, actionHandler: {
                                UserDefaults.standard.uploadReadingstoDexcomShare = false
                                UserDefaults.standard.isMaster = false
                            }, cancelHandler: nil)
                        } else {
                            // normal flow for all other follower modes
                            return .askConfirmation(title: Texts_Common.warning, message: Texts_SettingsView.warningChangeFromMasterToFollower, actionHandler: {
                                UserDefaults.standard.isMaster = false
                            }, cancelHandler: nil)
                        }
                    } else {
                        if UserDefaults.standard.followerDataSourceType == .dexcomShare && UserDefaults.standard.uploadReadingstoDexcomShare {
                            // as Dexcom Share was the previously selected follower mode and the user had upload to dexcom share enabled,
                            // inform then that we'll disable the upload
                            return .askConfirmation(title: Texts_Common.warning, message: Texts_SettingsView.warningChangeFromMasterToFollowerDexcomShare, actionHandler: {
                                UserDefaults.standard.uploadReadingstoDexcomShare = false
                                UserDefaults.standard.isMaster = false
                            }, cancelHandler: nil)
                        } else {
                            // no sensor active - set to follower
                            return SettingsSelectedRowAction.callFunction(function: {
                                UserDefaults.standard.isMaster = false
                            })
                        }
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
            
        case .followerExtraRow2:
            // if Master mode, upload CGM data to Nightscout?
            if UserDefaults.standard.isMaster {
                return UserDefaults.standard.nightscoutEnabled ? .nothing : SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.nightscoutNotEnabled)
            } else {
                // in Follower mode, data to be displayed in list from which user needs to pick a follower data source
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
                        
                        if newFollowerDataSourceType == .dexcomShare {
                            // make sure we disable dexcom share upload if we are using the share follow option
                            if UserDefaults.standard.uploadReadingstoDexcomShare {
                                self.callMessageHandlerInMainThread(title: FollowerDataSourceType.dexcomShare.fullDescription, message: Texts_SettingsView.warningChangeToFollowerDexcomShare)
                                UserDefaults.standard.uploadReadingstoDexcomShare = false
                            }
                        }
                    }
                    
                }, cancelHandler: nil, didSelectRowHandler: nil)
            }
        case .followerExtraRow3:
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
            
        case .followerExtraRow4:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.followerPatientName, message: Texts_SettingsView.followerPatientNameMessage, keyboardType: .default, text: UserDefaults.standard.followerPatientName, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (followerPatientName: String) in
                
                UserDefaults.standard.followerPatientName = followerPatientName.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                
            }, cancelHandler: nil, inputValidator: nil)
            
        case .followerExtraRow5:
            return UserDefaults.standard.nightscoutEnabled ? .nothing : SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.nightscoutNotEnabled)
            
        case .followerExtraRow6:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp, .libreLinkUpRussia:
                return SettingsSelectedRowAction.askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterUsername, keyboardType: .default, text: UserDefaults.standard.libreLinkUpEmail, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (libreLinkUpEmail: String) in
                        
                    UserDefaults.standard.libreLinkUpEmail = libreLinkUpEmail.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                        
                    // if the user has changed their account name, then let's also nillify the password for them so that we don't try and login with bad credentials
                    UserDefaults.standard.libreLinkUpPassword = nil
                        
                    // reset all data used in the UI
                    self.resetLibreLinkUpData()
                        
                }, cancelHandler: nil, inputValidator: nil)
                
            case .dexcomShare:
                return SettingsSelectedRowAction.askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterUsername, keyboardType: .default, text: UserDefaults.standard.dexcomShareAccountName, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (dexcomShareAccountName: String) in
                        
                    UserDefaults.standard.dexcomShareAccountName = dexcomShareAccountName.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                        
                    // if the user has changed their account name, then let's also nillify the password for them so that we don't try and login with bad credentials
                    UserDefaults.standard.dexcomSharePassword = nil
                        
                }, cancelHandler: nil, inputValidator: nil)
                    
            default:
                return .nothing
            }
            
        case .followerExtraRow7:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp, .libreLinkUpRussia:
                return SettingsSelectedRowAction.askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterPassword, keyboardType: .default, text: UserDefaults.standard.libreLinkUpPassword, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (libreLinkUpPassword: String) in
    
                    UserDefaults.standard.libreLinkUpPassword = libreLinkUpPassword.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                        
                    // reset all data used in the UI
                    self.resetLibreLinkUpData()
                        
                }, cancelHandler: nil, inputValidator: nil)
                
            case .dexcomShare:
                return SettingsSelectedRowAction.askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterPassword, keyboardType: .default, text: UserDefaults.standard.dexcomSharePassword, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (dexcomSharePassword: String) in
    
                    UserDefaults.standard.dexcomSharePassword = dexcomSharePassword.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                        
                    // reset all data used in the UI
                    //self.resetLibreLinkUpData()
                        
                }, cancelHandler: nil, inputValidator: nil)
                    
            default:
                return .nothing
            }
            
        case .followerExtraRow9:
            if let startDate = UserDefaults.standard.activeSensorStartDate {
                var startDateString = startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                
                startDateString += "\n\n" + startDate.daysAndHoursAgo() + " " + Texts_HomeView.ago
                
                return .showInfoText(title: Texts_BluetoothPeripheralView.sensorStartDate, message: "\n" + startDateString)
                
            } else {
                return .nothing
            }
            
        case .followerExtraRow8, .followerExtraRow10, .followerExtraRow11:
            return .nothing
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.dataSourceSettingsIcon + " " + Texts_SettingsView.sectionTitleDataSource
    }

    func numberOfRows() -> Int {
        // if master is selected then just show this row and hide the rest
        if UserDefaults.standard.isMaster {
            return 3
            
        } else {
            let count = Setting.allCases.count
            
            switch UserDefaults.standard.followerDataSourceType {
            case .nightscout:
                // no need to show any extra rows/settings (beyond patient name) as all Nightscout required parameters are set in the Nightscout section
                return 5
            
            case .libreLinkUp, .libreLinkUpRussia:
                // show all sections if needed. If there is no active sensor data then just hide some of the rows
                return UserDefaults.standard.activeSensorSerialNumber != nil ? count : count - (UserDefaults.standard.libreLinkUpPassword == nil || UserDefaults.standard.libreLinkUpEmail == nil ? 4 : 3)
                
            case .dexcomShare:
                // show patient name, upload to nightscout and also account username/password, together with "use US servers"
                return 9
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
            
        case .followerExtraRow2:
            return UserDefaults.standard.isMaster ? Texts_SettingsView.labelUploadDataToNightscout : Texts_SettingsView.labelFollowerDataSourceType
            
        case .followerExtraRow3:
            return Texts_SettingsView.labelfollowerKeepAliveType
            
        case .followerExtraRow4:
            return Texts_SettingsView.followerPatientName
            
        case .followerExtraRow5:
            return Texts_SettingsView.labelUploadDataToNightscout
            
        case .followerExtraRow6:
            return Texts_Common.username
            
        case .followerExtraRow7:
            return Texts_Common.password
            
        case .followerExtraRow8:
            switch UserDefaults.standard.followerDataSourceType {
            case .dexcomShare:
                return Texts_SettingsView.labelUseUSDexcomShareurl
            default:
                return Texts_HomeView.sensor
            }
            
        case .followerExtraRow9:
            return Texts_BluetoothPeripheralView.sensorStartDate
            
        case .followerExtraRow10:
            return Texts_SettingsView.labelFollowerDataSourceRegion
            
        case .followerExtraRow11:
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
        case .bloodGlucoseUnit, .masterFollower, .followerExtraRow5, .followerExtraRow8, .followerExtraRow10, .followerExtraRow11:
            return .none
            
        case .followerExtraRow2:
            return UserDefaults.standard.isMaster ? .none : .disclosureIndicator
            
        case .followerExtraRow3, .followerExtraRow4, .followerExtraRow6, .followerExtraRow7:
            return .disclosureIndicator
            
        case .followerExtraRow9:
            return UserDefaults.standard.activeSensorStartDate != nil ? .disclosureIndicator : .none
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .bloodGlucoseUnit:
            return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
            
        case .masterFollower:
            return UserDefaults.standard.isMaster ? Texts_SettingsView.master : Texts_SettingsView.follower
            
        case .followerExtraRow2:
            return UserDefaults.standard.isMaster ? (UserDefaults.standard.nightscoutEnabled ? nil : Texts_SettingsView.nightscoutNotEnabledRowText) : UserDefaults.standard.followerDataSourceType.description
            
        case .followerExtraRow3:
            return UserDefaults.standard.followerBackgroundKeepAliveType.description
            
        case .followerExtraRow4:
            return UserDefaults.standard.followerPatientName ?? nil
            
        case .followerExtraRow5:
            return UserDefaults.standard.nightscoutEnabled ? nil : Texts_SettingsView.nightscoutNotEnabledRowText
            
        case .followerExtraRow6:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp, .libreLinkUpRussia:
                return UserDefaults.standard.libreLinkUpEmail?.obscured() ?? Texts_SettingsView.valueIsRequired
            case .dexcomShare:
                return UserDefaults.standard.dexcomShareAccountName?.obscured() ?? Texts_SettingsView.valueIsRequired
            default:
                return nil
            }
            
        case .followerExtraRow7:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp, .libreLinkUpRussia:
                return UserDefaults.standard.libreLinkUpPassword?.obscured() ?? Texts_SettingsView.valueIsRequired
            case .dexcomShare:
                return UserDefaults.standard.dexcomSharePassword?.obscured() ?? Texts_SettingsView.valueIsRequired
            default:
                return nil
            }
            
        case .followerExtraRow8:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp, .libreLinkUpRussia:
                // we will use this row to also show important information regarding any login errors
                if UserDefaults.standard.libreLinkUpReAcceptNeeded {
                    return Texts_SettingsView.libreLinkUpReAcceptNeeded
                } else {
                    if UserDefaults.standard.activeSensorSerialNumber != nil {
                        // nicely format the (incomplete) serial numbers from LibreLinkUp
                        return processLibreLinkUpSensorInfo(sn: UserDefaults.standard.activeSensorSerialNumber)
                    } else if UserDefaults.standard.libreLinkUpPreventLogin {
                        return "⚠️ " + Texts_HomeView.followerAccountCredentialsInvalid
                    } else {
                        return "⚠️ " + Texts_SettingsView.libreLinkUpNoActiveSensor
                    }
                }
                
            default:
                return nil
            }
            
        case .followerExtraRow9:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp, .libreLinkUpRussia:
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
            
        case .followerExtraRow10:
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
                
            case .libreLinkUpRussia:
                if UserDefaults.standard.activeSensorSerialNumber != nil {
                    return "Russia"
                } else {
                    return "-"
                }
                
            default:
                return nil
            }
            
        case .followerExtraRow11:
            return nil
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .followerExtraRow2:
            if UserDefaults.standard.isMaster {
                return UserDefaults.standard.nightscoutEnabled ? UISwitch(isOn: UserDefaults.standard.masterUploadDataToNightscout, action: { (isOn: Bool) in UserDefaults.standard.masterUploadDataToNightscout = isOn } ) : nil
            } else {
                return nil
            }
            
        case .followerExtraRow5:
            return UserDefaults.standard.nightscoutEnabled ? UISwitch(isOn: UserDefaults.standard.followerUploadDataToNightscout, action: { (isOn: Bool) in UserDefaults.standard.followerUploadDataToNightscout = isOn } ) : nil
            
        case .followerExtraRow8:
            switch UserDefaults.standard.followerDataSourceType {
            case .dexcomShare:
                return UISwitch(isOn: UserDefaults.standard.useUSDexcomShareurl, action: { (isOn: Bool) in
                    UserDefaults.standard.useUSDexcomShareurl = isOn } )
            default:
                return nil
            }
            
        case .followerExtraRow11:
            return UISwitch(isOn: UserDefaults.standard.libreLinkUpIs15DaySensor, action: { (isOn: Bool) in
                UserDefaults.standard.libreLinkUpIs15DaySensor = isOn
                UserDefaults.standard.activeSensorMaxSensorAgeInDays = UserDefaults.standard.libreLinkUpIs15DaySensor ? ConstantsLibreLinkUp.libreLinkUpMaxSensorAgeInDaysLibrePlus : ConstantsLibreLinkUp.libreLinkUpMaxSensorAgeInDays
            })

        case .bloodGlucoseUnit, .masterFollower, .followerExtraRow3, .followerExtraRow4, .followerExtraRow6, .followerExtraRow7, .followerExtraRow9, .followerExtraRow10:
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
