//
//  SettingsViewDataSourceSettingsViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 25/7/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import os
import UIKit
import SafariServices

fileprivate enum Setting: Int, CaseIterable {
    /// blood glucose  unit
    case bloodGlucoseUnit = 0
    
    /// choose between master and follower
    case masterFollower = 1
    
    /// - Master: Upload CGM values to Nightscout?
    /// - Follower: patient name
    case followerExtraRow2 = 2
    
    /// - Follower: keep-alive method
    case followerExtraRow3 = 3
    
    /// - Follower: what should be the data source
    case followerExtraRow4 = 4
    
    /// - Follower
    ///  - LibreLinkUp: service status
    ///  - Dexcom Share: service status
    case followerExtraRow5 = 5
    
    /// - Follower: if follower data source is not Nightscout, should we upload the BG values to Nightscout?
    case followerExtraRow6 = 6
    
    /// - Follower: web follower username
    case followerExtraRow7 = 7
    
    /// - Follower: web follower password
    case followerExtraRow8 = 8
    
    /// - Follower
    ///  - LibreLinkUp: followerSensorSerialNumber (web follower sensor serial number - will not always be available)
    ///  - Dexcom Share: Dexcom Share Region as detected (or error message)
    ///  - Medtrum EasyView: Picker list for patient selection or just patient name if already selected (or if no selection was needed)
    case followerExtraRow9 = 9
    
    /// - Follower
    ///  - LibreLinkUp:  followerSensorStartDate (web follower sensor start date - will not always be available)
    case followerExtraRow10 = 10
    
    /// - Follower
    ///  - LibreLinkUp:  followerRegion (web follower server region)
    case followerExtraRow11 = 11
    
    /// - Follower
    ///  - LibreLinkUp:  followerIs15DaySensor (should be set by the user to true if using a "Plus" sensor with a 15 day lifetime instead of 14 days)
    case followerExtraRow12 = 12
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewDataSourceSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    // MARK: - Private variables
    
    private var coreDataManager: CoreDataManager?
    
    /// the viewcontroller sets it by calling storeMessageHandler
    private var messageHandler: ((String, String) -> Void)?
    
    /// holds the result of the service status if needed
    private var followerServiceStatusResult = FollowerServiceStatusResult()
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel)
    
    /// timer instance for the timer that will run and periodically update the follower service status if required
    private var serviceStatusTimer: Timer?
    
    /// warning symbol to be prefixed to a user-facing string where there is an error or further action needed
    private let warningPrefix = "⚠️ "
    
    // MARK: - Initialization / Deinitialization

    init(coreDataManager: CoreDataManager?) {
        self.coreDataManager = coreDataManager
        
        super.init()
        
        addObservers()
        
        startCheckFollowerServiceStatusTimer()
    }

    deinit {
        serviceStatusTimer?.invalidate()
    }
    
    // MARK: - Private functions
    
    private func callMessageHandlerInMainThread(title: String, message: String) {
        // unwrap messageHandler
        guard let messageHandler = messageHandler else { return }
        
        DispatchQueue.main.async {
            messageHandler(title, message)
        }
    }
    
    // open a Safari web view with the provided URL
    private func openWeb(_ url: URL) {
        let vc = SFSafariViewController(url: url)
        vc.modalPresentationStyle = .pageSheet
        DispatchQueue.main.async {
            self.topViewController()?.present(vc, animated: true)
        }
    }
    
    // returns the view controller on the top of the navigation stack
    private func topViewController(_ base: UIViewController? = {
        UIApplication.shared.connectedScenes
            .compactMap {
                $0 as? UIWindowScene
            }
            .flatMap {
                $0.windows
            }
            .first {
                $0.isKeyWindow
            }?.rootViewController
    }()) -> UIViewController? {
        if let nav = base as? UINavigationController { return topViewController(nav.visibleViewController) }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController { return topViewController(selected) }
        if let presented = base?.presentedViewController { return topViewController(presented) }
        return base
    }
    
    private func resetLibreLinkUpData() {
        UserDefaults.standard.libreLinkUpRegion = nil
        UserDefaults.standard.activeSensorStartDate = nil
        UserDefaults.standard.activeSensorSerialNumber = nil
        UserDefaults.standard.libreLinkUpCountry = nil
        UserDefaults.standard.libreLinkUpPreventLogin = false
    }

    private func resetMedtrumEasyViewData() {
        UserDefaults.standard.medtrumEasyViewPreventLogin = false
    }

    private func processLibreLinkUpSensorInfo(sn: String?) -> String {
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
    
    // starts a timer instance and fetches the latest service status via the helper function checkFollowerServiceStatus()
    private func startCheckFollowerServiceStatusTimer() {
        serviceStatusTimer?.invalidate()
        
        checkFollowerServiceStatus()
        
        serviceStatusTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkFollowerServiceStatus()
        }
    }
    
    // MARK: - General View Model declarations/functions
    
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
            return .callFunction(function: {
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
                                self.checkFollowerServiceStatus()
                            }, cancelHandler: nil)
                        } else {
                            // normal flow for all other follower modes
                            return .askConfirmation(title: Texts_Common.warning, message: Texts_SettingsView.warningChangeFromMasterToFollower, actionHandler: {
                                UserDefaults.standard.isMaster = false
                                self.checkFollowerServiceStatus()
                            }, cancelHandler: nil)
                        }
                    } else {
                        if UserDefaults.standard.followerDataSourceType == .dexcomShare && UserDefaults.standard.uploadReadingstoDexcomShare {
                            // as Dexcom Share was the previously selected follower mode and the user had upload to dexcom share enabled,
                            // inform then that we'll disable the upload
                            return .askConfirmation(title: Texts_Common.warning, message: Texts_SettingsView.warningChangeFromMasterToFollowerDexcomShare, actionHandler: {
                                UserDefaults.standard.uploadReadingstoDexcomShare = false
                                UserDefaults.standard.isMaster = false
                                self.checkFollowerServiceStatus()
                            }, cancelHandler: nil)
                        } else {
                            // no sensor active - set to follower
                            return .callFunction(function: {
                                UserDefaults.standard.isMaster = false
                                self.checkFollowerServiceStatus()
                            })
                        }
                    }
                } else {
                    // coredata manager is nil, should normally not be the case
                    return .callFunction(function: {
                        UserDefaults.standard.isMaster = false
                        self.checkFollowerServiceStatus()
                    })
                }
                
            } else {
                // switching from follower to master
                return .callFunction(function: {
                    UserDefaults.standard.isMaster = true
                })
            }
            
        case .followerExtraRow2:
            // if Master mode, upload CGM data to Nightscout?
            if UserDefaults.standard.isMaster {
                return UserDefaults.standard.nightscoutEnabled ? .nothing : .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.nightscoutNotEnabled)
            } else {
                return .askText(title: Texts_SettingsView.followerPatientName, message: Texts_SettingsView.followerPatientNameMessage, keyboardType: .default, text: UserDefaults.standard.followerPatientName, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (followerPatientName: String) in
                    
                    UserDefaults.standard.followerPatientName = followerPatientName.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                    
                }, cancelHandler: nil, inputValidator: nil)
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
            
            return .selectFromList(title: Texts_SettingsView.labelfollowerKeepAliveType, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: { (index: Int) in
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
            // Build list from the enabled cases only. This allows for ignored follower types
            let enabled = FollowerDataSourceType.allEnabledCases
            let data = enabled.map { $0.description }
            let currentFollowerDataSourceType = UserDefaults.standard.followerDataSourceType
            let selectedRow = enabled.firstIndex(of: currentFollowerDataSourceType)
            
            return .selectFromList(title: Texts_SettingsView.labelFollowerDataSourceType, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: { (index: Int) in
                let enabled = FollowerDataSourceType.allEnabledCases
                // Safety: ensure index is valid
                guard index >= 0, index < enabled.count else { return }
                
                let oldFollowerDataSourceType = UserDefaults.standard.followerDataSourceType
                let newFollowerDataSourceType = enabled[index]
                
                if newFollowerDataSourceType != oldFollowerDataSourceType {
                    UserDefaults.standard.followerDataSourceType = newFollowerDataSourceType
                    self.checkFollowerServiceStatus()
                    
                    trace("follower source data type was changed from '%{public}@' to '%{public}@'", log: self.log, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel, type: .info, oldFollowerDataSourceType.description, newFollowerDataSourceType.description)
                    
                    // make sure we disable dexcom share upload if we are using the share follow option
                    if newFollowerDataSourceType == .dexcomShare && UserDefaults.standard.uploadReadingstoDexcomShare {
                        self.callMessageHandlerInMainThread(title: FollowerDataSourceType.dexcomShare.fullDescription, message: Texts_SettingsView.warningChangeToFollowerDexcomShare)
                        UserDefaults.standard.uploadReadingstoDexcomShare = false
                    }
                }
            }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .followerExtraRow5:
            if let url = URL(string: UserDefaults.standard.followerDataSourceType.serviceStatusBaseUrlString(nightscoutUrl: UserDefaults.standard.nightscoutUrl)), (UserDefaults.standard.followerDataSourceType.hasServiceStatus() && followerServiceStatusResult.status != .notAvailable) {
                openWeb(url)
            }
            return .nothing
            
        case .followerExtraRow6:
            return UserDefaults.standard.nightscoutEnabled ? .nothing : .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.nightscoutNotEnabled)
            
        case .followerExtraRow7:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp, .libreLinkUpRussia:
                return .askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterUsername, keyboardType: .default, text: UserDefaults.standard.libreLinkUpEmail, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (libreLinkUpEmail: String) in
                        
                    UserDefaults.standard.libreLinkUpEmail = libreLinkUpEmail.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                        
                    // if the user has changed their account name, then let's also nillify the password for them so that we don't try and login with bad credentials
                    UserDefaults.standard.libreLinkUpPassword = nil
                        
                    // reset all data used in the UI
                    self.resetLibreLinkUpData()
                }, cancelHandler: nil, inputValidator: nil)
                
            case .dexcomShare:
                return .askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterUsername, keyboardType: .default, text: UserDefaults.standard.dexcomShareAccountName, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (dexcomShareAccountName: String) in
                        
                    UserDefaults.standard.dexcomShareAccountName = dexcomShareAccountName.trimmingCharacters(in: .whitespaces).toNilIfLength0()

                    // if the user has changed their account name, then let's also nillify the password for them so that we don't try and login with bad credentials
                    UserDefaults.standard.dexcomSharePassword = nil
                }, cancelHandler: nil, inputValidator: nil)

            case .medtrumEasyView:
                return SettingsSelectedRowAction.askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterUsername, keyboardType: .default, text: UserDefaults.standard.medtrumEasyViewEmail, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (medtrumEasyViewEmail: String) in

                    UserDefaults.standard.medtrumEasyViewEmail = medtrumEasyViewEmail.trimmingCharacters(in: .whitespaces).toNilIfLength0()

                    // if the user has changed their account name, then let's also nillify the password for them so that we don't try and login with bad credentials
                    UserDefaults.standard.medtrumEasyViewPassword = nil

                    // reset all data used in the UI
                    self.resetMedtrumEasyViewData()

                }, cancelHandler: nil, inputValidator: nil)

            default:
                return .nothing
            }
            
        case .followerExtraRow8:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp, .libreLinkUpRussia:
                return .askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterPassword, keyboardType: .default, text: UserDefaults.standard.libreLinkUpPassword, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (libreLinkUpPassword: String) in
    
                    UserDefaults.standard.libreLinkUpPassword = libreLinkUpPassword.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                        
                    // reset all data used in the UI
                    self.resetLibreLinkUpData()
                }, cancelHandler: nil, inputValidator: nil)
                
            case .dexcomShare:
                return .askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterPassword, keyboardType: .default, text: UserDefaults.standard.dexcomSharePassword, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (dexcomSharePassword: String) in

                    UserDefaults.standard.dexcomSharePassword = dexcomSharePassword.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                }, cancelHandler: nil, inputValidator: nil)

            case .medtrumEasyView:
                return .askText(title: UserDefaults.standard.followerDataSourceType.description, message: Texts_SettingsView.enterPassword, keyboardType: .default, text: UserDefaults.standard.medtrumEasyViewPassword, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (medtrumEasyViewPassword: String) in

                    UserDefaults.standard.medtrumEasyViewPassword = medtrumEasyViewPassword.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                    
                    // reset all data used in the UI
                    self.resetMedtrumEasyViewData()
                    
                }, cancelHandler: nil, inputValidator: nil)

            default:
                return .nothing
            }
            
        case .followerExtraRow9:
            switch UserDefaults.standard.followerDataSourceType {
            case .dexcomShare:
                if UserDefaults.standard.dexcomShareRegion != .none {
                    return .showInfoText(title: "Dexcom Server " + UserDefaults.standard.dexcomShareRegion.regionServerNumber, message: "\n" + UserDefaults.standard.dexcomShareRegion.regionCountriesDescription)
                }

                return .nothing

            case .medtrumEasyView:
                // Only show dropdown if caregiver account
                guard UserDefaults.standard.medtrumEasyViewUserType == "M" else {
                    return .nothing
                }
                
                // if caregiver account, but patient was previously selected then do nothing
                guard UserDefaults.standard.medtrumEasyViewSelectedPatientUid == 0 else {
                    return .nothing
                }

                // Try to decode cached connections
                var connections: [MedtrumEasyViewPatientConnection] = []
                if let cachedData = UserDefaults.standard.medtrumEasyViewCachedConnections {
                    connections = (try? JSONDecoder().decode([MedtrumEasyViewPatientConnection].self, from: cachedData)) ?? []
                }

                // Build dropdown data: placeholder + patient list
                // add 👇 before the text - it's ugly but clearly indicates that it isn't
                // a valid patient name and they should chose from the options below
                var data = ["👇 " + Texts_SettingsView.medtrumSelectPatient + "..."]
                data.append(contentsOf: connections.map { $0.displayName })

                // Determine selected row
                let selectedPatientUid = UserDefaults.standard.medtrumEasyViewSelectedPatientUid
                var selectedRow = 0  // Default to placeholder
                if selectedPatientUid != 0 {
                    // Find index of selected patient (add 1 for placeholder offset)
                    if let index = connections.firstIndex(where: { $0.uid == selectedPatientUid }) {
                        selectedRow = index + 1
                    }
                }

                return SettingsSelectedRowAction.selectFromList(
                    title: Texts_SettingsView.medtrumSelectPatientFromList,
                    data: data,
                    selectedRow: selectedRow,
                    actionTitle: nil,
                    cancelTitle: nil,
                    actionHandler: { (index: Int) in
                        if index == 0 {
                            // Placeholder selected - no patient
                            UserDefaults.standard.medtrumEasyViewSelectedPatientUid = 0
                            trace("Medtrum EasyView: No patient selected (placeholder)", log: self.log, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel, type: .info)
                        } else if index > 0 && index <= connections.count {
                            // Patient selected
                            let patient = connections[index - 1]
                            UserDefaults.standard.medtrumEasyViewSelectedPatientUid = patient.uid
                            trace("Medtrum EasyView: Selected patient '%{public}@' (UID: %{public}@)", log: self.log, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel, type: .info, patient.displayName, patient.uid.description)
                            // set the Follower Patient Name in the app
                            UserDefaults.standard.followerPatientName = patient.displayName
                        }

                        // Reset Medtrum data to trigger refetch with new patient
                        self.resetMedtrumEasyViewData()
                    },
                    cancelHandler: nil,
                    didSelectRowHandler: nil
                )

            default:
                return .nothing
            }
            
        case .followerExtraRow10:
            if let startDate = UserDefaults.standard.activeSensorStartDate {
                var startDateString = startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                
                startDateString += "\n\n" + startDate.daysAndHoursAgo() + " " + Texts_HomeView.ago
                
                return .showInfoText(title: Texts_BluetoothPeripheralView.sensorStartDate, message: "\n" + startDateString)
            }
            return .nothing

        case .followerExtraRow11, .followerExtraRow12:
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
                return 6
                
            case .libreLinkUp, .libreLinkUpRussia:
                // show all sections if needed. If there is no active sensor data then just hide some of the rows
                return UserDefaults.standard.activeSensorSerialNumber != nil ? count : count - (UserDefaults.standard.libreLinkUpPassword == nil || UserDefaults.standard.libreLinkUpEmail == nil ? 4 : 3)
                
            case .dexcomShare:
                // show patient name, upload to nightscout and also account username/password, together with "use US servers"
                return 10

            case .medtrumEasyView:
                // Show patient selector dropdown if caregiver account
                // Patient account rows (0-8): BG unit, master/follower, patient name, keep-alive, data source, service status, upload to NS, username, password
                // Caregiver account adds row 9: patient selection
                let isCaregiverAccount = UserDefaults.standard.medtrumEasyViewUserType == "M"
                return isCaregiverAccount ? 10 : 9
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
            return UserDefaults.standard.isMaster ? Texts_SettingsView.labelUploadDataToNightscout : Texts_SettingsView.followerPatientName
            
        case .followerExtraRow3:
            return Texts_SettingsView.labelfollowerKeepAliveType
            
        case .followerExtraRow4:
            return Texts_SettingsView.labelFollowerDataSourceType
            
        case .followerExtraRow5:
            return Texts_SettingsView.followerServiceStatus
            
        case .followerExtraRow6:
            return Texts_SettingsView.labelUploadDataToNightscout
            
        case .followerExtraRow7:
            return Texts_Common.username
            
        case .followerExtraRow8:
            return Texts_Common.password
            
        case .followerExtraRow9:
            switch UserDefaults.standard.followerDataSourceType {
            case .dexcomShare:
                return Texts_SettingsView.labelFollowerDataSourceRegion
            case .medtrumEasyView:
                return Texts_SettingsView.medtrumSelectedPatient
            default:
                return Texts_HomeView.sensor
            }
            
        case .followerExtraRow10:
            return Texts_BluetoothPeripheralView.sensorStartDate
            
        case .followerExtraRow11:
            return Texts_SettingsView.labelFollowerDataSourceRegion
            
        case .followerExtraRow12:
            if processLibreLinkUpSensorInfo(sn: UserDefaults.standard.activeSensorSerialNumber).prefix(5) == "Libre" {
                return processLibreLinkUpSensorInfo(sn: UserDefaults.standard.activeSensorSerialNumber).prefix(7) + " Plus (15 " + Texts_Common.days + ")?"
            }
            return Texts_SettingsView.labelFollowerIs15DaySensor
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .bloodGlucoseUnit, .masterFollower, .followerExtraRow6, .followerExtraRow11, .followerExtraRow12:
            return .none

        case .followerExtraRow2:
            return UserDefaults.standard.isMaster ? .none : .disclosureIndicator
            
        case .followerExtraRow5:
            return (UserDefaults.standard.followerDataSourceType.hasServiceStatus() && followerServiceStatusResult.status != .notAvailable) ? .disclosureIndicator : .none

        case .followerExtraRow9:
            // Show disclosure indicator for Dexcom region selection or Medtrum patient selection
            if UserDefaults.standard.followerDataSourceType == .dexcomShare && UserDefaults.standard.dexcomShareRegion != .none {
                return .disclosureIndicator
            } else if UserDefaults.standard.followerDataSourceType == .medtrumEasyView && UserDefaults.standard.medtrumEasyViewUserType == "M" && UserDefaults.standard.medtrumEasyViewSelectedPatientUid == 0 {
                return .disclosureIndicator
            } else {
                return .none
            }

        case .followerExtraRow10:
            return UserDefaults.standard.activeSensorStartDate != nil ? .disclosureIndicator : .none
            
        case .followerExtraRow3, .followerExtraRow4, .followerExtraRow7, .followerExtraRow8:
            return .disclosureIndicator
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
            return UserDefaults.standard.isMaster ? (UserDefaults.standard.nightscoutEnabled ? nil : Texts_SettingsView.nightscoutNotEnabledRowText) : UserDefaults.standard.followerPatientName ?? nil
            
        case .followerExtraRow3:
            return UserDefaults.standard.followerBackgroundKeepAliveType.description
            
        case .followerExtraRow4:
            return UserDefaults.standard.followerDataSourceType.description
            
        case .followerExtraRow5:
            return followerServiceStatusResult.status.icon + " " + followerServiceStatusResult.description
            
        case .followerExtraRow6:
            return UserDefaults.standard.nightscoutEnabled ? nil : Texts_SettingsView.nightscoutNotEnabledRowText
            
        case .followerExtraRow7:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp, .libreLinkUpRussia:
                if let libreLinkUpEmail = UserDefaults.standard.libreLinkUpEmail {
                    return ((UserDefaults.standard.libreLinkUpPreventLogin && UserDefaults.standard.libreLinkUpPassword != nil) ? warningPrefix : "") + libreLinkUpEmail.obscured()
                } else {
                    return Texts_SettingsView.valueIsRequired
                }
            case .dexcomShare:
                return UserDefaults.standard.dexcomShareAccountName?.obscured() ?? Texts_SettingsView.valueIsRequired
            case .medtrumEasyView:
                if let medtrumEasyViewEmail = UserDefaults.standard.medtrumEasyViewEmail {
                    return ((UserDefaults.standard.medtrumEasyViewPreventLogin && UserDefaults.standard.medtrumEasyViewPassword != nil) ? warningPrefix : "") + medtrumEasyViewEmail.obscured()
                } else {
                    return Texts_SettingsView.valueIsRequired
                }
            default:
                return nil
            }
            
        case .followerExtraRow8:
            switch UserDefaults.standard.followerDataSourceType {
            case .libreLinkUp, .libreLinkUpRussia:
                if let libreLinkUpPassword = UserDefaults.standard.libreLinkUpPassword {
                    return (UserDefaults.standard.libreLinkUpPreventLogin ? warningPrefix : "") + libreLinkUpPassword.obscured()
                } else {
                    return Texts_SettingsView.valueIsRequired
                }
            case .dexcomShare:
                return UserDefaults.standard.dexcomSharePassword?.obscured() ?? Texts_SettingsView.valueIsRequired
            case .medtrumEasyView:
                if let medtrumEasyViewPassword = UserDefaults.standard.medtrumEasyViewPassword {
                    return (UserDefaults.standard.medtrumEasyViewPreventLogin ? warningPrefix : "") + medtrumEasyViewPassword.obscured()
                } else {
                    return Texts_SettingsView.valueIsRequired
                }
            default:
                return nil
            }
            
        case .followerExtraRow9:
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
                        return warningPrefix + Texts_HomeView.followerAccountCredentialsInvalid
                    } else {
                        return warningPrefix + Texts_SettingsView.libreLinkUpNoActiveSensor
                    }
                }
                
            case .dexcomShare:
                if UserDefaults.standard.dexcomShareAccountName == nil || UserDefaults.standard.dexcomSharePassword == nil {
                    return "-"
                } else if UserDefaults.standard.dexcomShareRegion == .none && UserDefaults.standard.dexcomShareLoginFailedTimestamp != nil {
                    return warningPrefix + Texts_HomeView.followerAccountCredentialsInvalid
                } else if UserDefaults.standard.dexcomShareRegion == .none {
                    return Texts_Common.checking
                } else {
                    return UserDefaults.standard.dexcomShareRegion.description
                }

            case .medtrumEasyView:
                // Only show for caregiver accounts
                guard UserDefaults.standard.medtrumEasyViewUserType == "M" else {
                    return nil
                }

                // Show error if connections fetch failed
                if UserDefaults.standard.medtrumEasyViewConnectionsFetchFailed {
                    return warningPrefix + "Failed to fetch patients (using cached list)"
                }

                // Show selected patient or placeholder
                let selectedPatientUid = UserDefaults.standard.medtrumEasyViewSelectedPatientUid
                if selectedPatientUid == 0 {
                    return warningPrefix + Texts_SettingsView.medtrumSelectPatient
                } else {
                    // Try to find patient name from cached connections
                    if let cachedData = UserDefaults.standard.medtrumEasyViewCachedConnections,
                       let connections = try? JSONDecoder().decode([MedtrumEasyViewPatientConnection].self, from: cachedData),
                       let patient = connections.first(where: { $0.uid == selectedPatientUid }) {
                        return patient.displayName
                    }
                    return "Patient ID: \(selectedPatientUid)"
                }

            default:
                return nil
            }
            
        case .followerExtraRow10:
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
            
        case .followerExtraRow11:
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
            
        case .followerExtraRow12:
            return nil
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .followerExtraRow2:
            if UserDefaults.standard.isMaster {
                return UserDefaults.standard.nightscoutEnabled ? UISwitch(isOn: UserDefaults.standard.masterUploadDataToNightscout, action: { (isOn: Bool) in
                    trace("isMaster changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.masterUploadDataToNightscout = isOn } ) : nil
            } else {
                return nil
            }
            
        case .followerExtraRow6:
            return UserDefaults.standard.nightscoutEnabled ? UISwitch(isOn: UserDefaults.standard.followerUploadDataToNightscout, action: { (isOn: Bool) in
                trace("followerUploadDataToNightscout changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel, type: .info, isOn.description)
                UserDefaults.standard.followerUploadDataToNightscout = isOn } ) : nil
            
        case .followerExtraRow12:
            return UISwitch(isOn: UserDefaults.standard.libreLinkUpIs15DaySensor, action: { (isOn: Bool) in
                trace("libreLinkUpIs15DaySensor changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel, type: .info, isOn.description)
                UserDefaults.standard.libreLinkUpIs15DaySensor = isOn
                UserDefaults.standard.activeSensorMaxSensorAgeInDays = UserDefaults.standard.libreLinkUpIs15DaySensor ? ConstantsLibreLinkUp.libreLinkUpMaxSensorAgeInDaysLibrePlus : ConstantsLibreLinkUp.libreLinkUpMaxSensorAgeInDays
            })

        case .bloodGlucoseUnit, .masterFollower, .followerExtraRow3, .followerExtraRow4, .followerExtraRow5, .followerExtraRow7, .followerExtraRow8, .followerExtraRow9, .followerExtraRow10, .followerExtraRow11:
            return nil
        }
    }
    
    // MARK: - observe functions
    
    private func addObservers() {
        // Listen for changes in the follower patient name to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.followerPatientName.rawValue, options: .new, context: nil)
        
        // Listen for changes in the active sensor value to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.activeSensorSerialNumber.rawValue, options: .new, context: nil)

        // Listen for changes in the detected dexcom server region to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomShareRegion.rawValue, options: .new, context: nil)

        // Listen for changes in the login status to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.dexcomShareLoginFailedTimestamp.rawValue, options: .new, context: nil)

        // Listen for changes in Medtrum EasyView user type (patient vs caregiver)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewUserType.rawValue, options: .new, context: nil)

        // Listen for changes in Medtrum EasyView selected patient
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewSelectedPatientUid.rawValue, options: .new, context: nil)
        
        // Listen for changes in follower login status (i.e. if prevented due to wrong credentials)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.libreLinkUpPreventLogin.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.medtrumEasyViewPreventLogin.rawValue, options: .new, context: nil)
        
        // Listen for changes in the Nightscout status to trigger the UI to be updated
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutUrl.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutAPIKey.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutToken.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutPort.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightscoutEnabled.rawValue, options: .new, context: nil)
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else { return }
        
        switch keyPathEnum {

        case UserDefaults.Key.followerPatientName, UserDefaults.Key.activeSensorSerialNumber, UserDefaults.Key.dexcomShareRegion, UserDefaults.Key.dexcomShareLoginFailedTimestamp, UserDefaults.Key.medtrumEasyViewUserType, UserDefaults.Key.medtrumEasyViewSelectedPatientUid:
            // run this in the main thread to avoid access errors
            DispatchQueue.main.async {
                self.sectionReloadClosure?()
            }
        case UserDefaults.Key.medtrumEasyViewPreventLogin:
            // if there is a problem with the medtrum login, then clear the last connection date and follower patient name
            if UserDefaults.standard.medtrumEasyViewPreventLogin {
                UserDefaults.standard.timeStampOfLastFollowerConnection = .distantPast
                UserDefaults.standard.followerPatientName = nil
            }
            // run this in the main thread to avoid access errors
            DispatchQueue.main.async {
                self.sectionReloadClosure?()
            }
        case UserDefaults.Key.libreLinkUpPreventLogin:
            // if there is a problem with the LLU login, then clear the last connection date
            if UserDefaults.standard.libreLinkUpPreventLogin {
                UserDefaults.standard.timeStampOfLastFollowerConnection = .distantPast
            }
        case UserDefaults.Key.nightscoutUrl, UserDefaults.Key.nightscoutAPIKey, UserDefaults.Key.nightscoutToken, UserDefaults.Key.nightscoutPort, UserDefaults.Key.nightscoutEnabled:
            checkFollowerServiceStatus()
            
        default:
            break
        }
    }
}

// MARK: - Extension with Follower Service Status components

extension SettingsViewDataSourceSettingsViewModel {
    
    /// defines the service status based upon the status.indicator attribute of the summary response
    ///
    /// "status": {
    ///     "indicator": "none",
    ///     "description": "All Systems Operational"
    /// }
    ///
    /// https://status.atlassian.com/api#summary
    ///
    enum FollowerServiceStatus {
        case notAvailable, ok, degraded, outage, unknown, error

        init(indicator: String = "") {
            switch indicator { // need to add more Nightscout status cases here
            case "":
                self = .notAvailable
            case "none", "ok":
                self = .ok
            case "minor":
                self = .degraded
            case "major", "critical":
                self = .outage
            default:
                self = .unknown
            }
        }
        
        var icon: String {
            switch self {
            case .ok:
                return "🟢 "
            case .degraded:
                return "🟡 "
            case .outage:
                return "🔴 "
            case .error:
                return "⚠️ "
            default:
                return ""
            }
        }
        
        var description: String {
            switch self {
            case .notAvailable:
                return Texts_Common.notAvailable
            case .ok:
                return "Operational"
            case .degraded:
                return "Degraded"
            case .outage:
                return "Outage"
            case .error:
                return "Error"
            case .unknown:
                return Texts_Common.checking
            }
        }
    }

    struct FollowerServiceStatusResult {
        let status: FollowerServiceStatus
        let description: String
        
        // set the default initialization values to unknown and "checking...", this is useful for the UI
        init(status: FollowerServiceStatus = .unknown, description: String? = nil) {
            // make a quick check to set Nightscout follower service status to not available if Nightscout isn't enabled or if a valid URL doesn't exist
            if UserDefaults.standard.followerDataSourceType == .nightscout && (!UserDefaults.standard.nightscoutEnabled || UserDefaults.standard.nightscoutUrl == "") {
                self.status = .notAvailable
            } else {
                self.status = status
            }
                
            self.description = description ?? self.status.description
        }
    }

    struct StatusPageSummaryModel: Decodable {
        struct Status: Decodable {
            let indicator: String
            let description: String
        }
        
        let status: Status
    }
    
    struct NightscoutStatusModel: Decodable {
        let status: String
    }
    
    // MARK: - Private functions
    
    /// checks if we should fetch the service status and then calls  the fetch whilst handling the UI updates
    /// this is the only function called by the main class - it uses the below helper functions to work.
    private func checkFollowerServiceStatus() {
        guard !UserDefaults.standard.isMaster else { return }
        
        followerServiceStatusResult = FollowerServiceStatusResult()
        
        // resets the stored results to default, updates the UI before fetching the current results and updates again
        // we do it like this to give a visual indication to the user that we are performing a fresh check every now and again
        DispatchQueue.main.async {
            self.sectionReloadClosure?()
        }
        
        // Use async/await for the network call
        Task { [weak self] in
            guard let self = self else { return }
            let result = await self.fetchFollowerServiceStatus(followerDataSourceType: UserDefaults.standard.followerDataSourceType)
            if let followerServiceStatusResult = result {
                // we will call the UI update in a separate MainActor function to avoid inferring the closure as @Sendable
                await self.delayedUIUpdate(followerServiceStatusResult)
            }
        }
    }
    
    /// Fetches the status for the given follower service (Dexcom Share or LibreLinkUp) asynchronously
    /// - Parameter followerDataSourceType: The data source type to check
    /// - Returns: FollowerServiceStatusResult with status and description, or nil if URL is invalid
    private func fetchFollowerServiceStatus(followerDataSourceType: FollowerDataSourceType) async -> FollowerServiceStatusResult? {
        guard UserDefaults.standard.followerDataSourceType.hasServiceStatus() else {
            return FollowerServiceStatusResult(status: .notAvailable)
        }
        
        guard !(UserDefaults.standard.followerDataSourceType == .nightscout && (!UserDefaults.standard.nightscoutEnabled || UserDefaults.standard.nightscoutUrl == "")) else {
            return FollowerServiceStatusResult(status: .notAvailable)
        }
        
        guard let url = URL(string: followerDataSourceType.serviceStatusBaseUrlString(nightscoutUrl: UserDefaults.standard.nightscoutUrl).appending(followerDataSourceType.serviceStatusApiPathString())) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            var status = FollowerServiceStatus()
            var description = ""
            
            switch followerDataSourceType {
            case .nightscout:
                let nightscoutStatus = try JSONDecoder().decode(NightscoutStatusModel.self, from: data)
                status = FollowerServiceStatus(indicator: nightscoutStatus.status)
                description = status.description
            case .dexcomShare, .libreLinkUp, .libreLinkUpRussia:
                let summary = try JSONDecoder().decode(StatusPageSummaryModel.self, from: data)
                status = FollowerServiceStatus(indicator: summary.status.indicator)
                description = summary.status.description
            case .medtrumEasyView:
                // Medtrum doesn't have a service status, this case should never be reached
                break
            }
            if status != .ok && status != .unknown {
                trace("in fetchFollowerServiceStatus, %{public}@ service status issue = '%{public}@'", log: self.log, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel, type: .info, followerDataSourceType.description, description)
            }
            return FollowerServiceStatusResult(status: status, description: description)
        } catch {
            trace("in fetchFollowerServiceStatus, network or decoding error: %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel, type: .info, error.localizedDescription)
            return FollowerServiceStatusResult(status: .error, description: "Fetch Error")
        }
    }
    
    @MainActor
    // run the UI update on the main thread after a small delay so that the user actually notices that we are checking the service status
    // if we don't do this, it will likely change so fast that it will just look like we haven't checked
    private func delayedUIUpdate(_ result: FollowerServiceStatusResult) {
        // we won't apply any delay if the follower mode doesn't have a service status as it makes no sense and will
        // confuse even further - in this case, we'll immediately show that it's not available
        let delayToUse = (result.status == .notAvailable ? 0.0 : 0.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delayToUse) { [weak self] in
            guard let self = self else { return }
            self.followerServiceStatusResult = result
            self.sectionReloadClosure?()
        }
    }
}
