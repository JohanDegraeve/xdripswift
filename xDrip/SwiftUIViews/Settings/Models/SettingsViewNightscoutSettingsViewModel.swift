import Foundation
import os
import SwiftUI

fileprivate enum Setting:Int, CaseIterable {
    
    /// should readings be uploaded or not
    case nightscoutEnabled = 0
    
    /// open web view with Nightscout URL
    case openNightscout = 1
    
    /// nightscout follower type
    case nightscoutFollowType = 2
    
    /// nightscout url
    case nightscoutUrl = 3
    
    /// nightscout api key
    case nightscoutAPIKey = 4
    
    /// nightscout api key
    case token = 5
    
    /// port
    case port = 6
    
    /// to allow testing explicitly
    case testUrlAndAPIKey = 7
    
    /// should sensor start time be uploaded to NS yes or no
    case uploadSensorStartTime = 8
    
    /// use nightscout schedule or not
    case useSchedule = 9
    
    /// open uiviewcontroller to edit schedule
    case schedule = 10
    
}

enum NightscoutSettingsRowGroup {
    case nightscout
    case connectionSettings
    case actions
    case uploadSchedule
}

class SettingsViewNightscoutSettingsViewModel {
    
    // MARK: - properties

    private let rowGroup: NightscoutSettingsRowGroup
    
    /// in case info message or errors occur like credential check error, then this closure will be called with title and message
    /// - parameters:
    ///     - first parameter is title
    ///     - second parameter is the message
    ///
    /// the viewcontroller sets it by calling storeMessageHandler
    private var messageHandler: ((String, String) -> Void)?

    /// used to refresh the action rows when the Nightscout connection timestamp changes
    private var sectionReloadClosure: (() -> Void)?

    /// refreshes the relative connection timestamp while the Nightscout actions section is visible
    private var connectionTimestampRefreshTimer: Timer?
    
    /// path to test API Secret
    private let nightscoutAuthTestPath = "/api/v1/experiments/test"
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMG5)

    init(rowGroup: NightscoutSettingsRowGroup = .nightscout) {
        self.rowGroup = rowGroup
    }

    deinit {
        connectionTimestampRefreshTimer?.invalidate()
    }
    
    // MARK: - Native SwiftUI rows

    func settingsSectionTitle() -> String? {
        switch rowGroup {
        case .nightscout:
            return Texts_SettingsView.sectionTitleNightscout
        case .connectionSettings:
            return Texts_SettingsView.screenTitle
        case .actions:
            return nil
        case .uploadSchedule:
            return Texts_SettingsView.nightscoutUploadOptionsSectionTitle
        }
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        let nightscoutEnabled = UserDefaults.standard.nightscoutEnabled
        let masterModeRowsVisible = nightscoutEnabled && UserDefaults.standard.isMaster
        let sensorStartTimeRowVisible = masterModeRowsVisible || (nightscoutEnabled && isLibreLinkUpFollower)

        switch rowGroup {
        case .nightscout:
            return [
                nativeSettingsRow(id: "nightscout.enabled", index: Setting.nightscoutEnabled.rawValue, sectionID: sectionID),
                nativeSettingsRow(id: "nightscout.followType", index: Setting.nightscoutFollowType.rawValue, sectionID: sectionID, isVisible: nightscoutEnabled)
            ]
        case .connectionSettings:
            return [
                nativeSettingsRow(id: "nightscout.url", index: Setting.nightscoutUrl.rawValue, sectionID: sectionID, isVisible: nightscoutEnabled),
                nativeSettingsRow(id: "nightscout.apiKey", index: Setting.nightscoutAPIKey.rawValue, sectionID: sectionID, isVisible: nightscoutEnabled),
                nativeSettingsRow(id: "nightscout.token", index: Setting.token.rawValue, sectionID: sectionID, isVisible: nightscoutEnabled),
                nativeSettingsRow(id: "nightscout.port", index: Setting.port.rawValue, sectionID: sectionID, isVisible: nightscoutEnabled)
            ]
        case .actions:
            return [
                actionRow(
                    id: "nightscout.openNightscout",
                    index: Setting.openNightscout.rawValue,
                    sectionID: sectionID,
                    symbolName: "safari",
                    isVisible: nightscoutEnabled,
                    isAvailable: UserDefaults.standard.nightscoutUrl != nil
                ),
                // The Test Connection row also shows the last known good Nightscout
                // connection. This is deliberately based on the stored timestamp,
                // not the latest failed check, so the user can see when the last
                // working connection happened and when it has become stale.
                actionRow(
                    id: "nightscout.testUrlAndAPIKey",
                    index: Setting.testUrlAndAPIKey.rawValue,
                    sectionID: sectionID,
                    symbolName: "link.icloud",
                    isVisible: nightscoutEnabled,
                    detail: nightscoutLastConnectionText,
                    detailIndicator: nightscoutLastConnectionIndicator
                )
            ]
        case .uploadSchedule:
            return [
                nativeSettingsRow(id: "nightscout.uploadSensorStartTime", index: Setting.uploadSensorStartTime.rawValue, sectionID: sectionID, isVisible: sensorStartTimeRowVisible),
                nativeSettingsRow(id: "nightscout.useSchedule", index: Setting.useSchedule.rawValue, sectionID: sectionID, isVisible: masterModeRowsVisible),
                nativeSettingsRow(
                    id: "nightscout.schedule",
                    index: Setting.schedule.rawValue,
                    sectionID: sectionID,
                    isVisible: masterModeRowsVisible && UserDefaults.standard.nightscoutUseSchedule
                )
            ]
        }
    }

    /// Builds the Nightscout utility rows as link-style actions while still using
    /// the original selection logic below for the actual work.
    private func actionRow(
        id: String,
        index: Int,
        sectionID: Int,
        symbolName: String,
        isVisible: Bool,
        isAvailable: Bool = true,
        detail: String? = nil,
        detailIndicator: SettingsIndicator? = nil
    ) -> SettingsRow {
        var row = nativeSettingsRow(id: id, index: index, sectionID: sectionID, isVisible: isVisible)
        row.detail = detail ?? row.detail
        row.detailIndicator = detailIndicator
        row.icon = SettingsIcon(symbolName: symbolName, color: isAvailable ? .accentColor : Color(.colorTertiary))
        row.titleColor = isAvailable ? .accentColor : nil
        row.accessory = .none
        row.isEnabled = isAvailable
        return row
    }

    /// Shows how long ago Nightscout last had a known good connection. This uses
    /// the same timestamp as the root-view follower connection indicator. The
    /// current formatter is minute-based, so very recent checks appear as 0m ago.
    private var nightscoutLastConnectionText: String? {
        guard let lastConnection = UserDefaults.standard.timeStampOfLastFollowerConnection else {
            return nil
        }

        guard lastConnection > .distantPast else {
            return ""
        }

        return lastConnection.daysAndHoursAgo(appendAgo: true)
    }

    /// Matches the root-view connection logic: green while the last Nightscout
    /// connection is recent, red once it is older than the warning interval.
    private var nightscoutLastConnectionIndicator: SettingsIndicator? {
        guard let lastConnection = UserDefaults.standard.timeStampOfLastFollowerConnection else {
            return nil
        }

        guard lastConnection > .distantPast else {
            return SettingsIndicator(color: ConstantsAppColors.urgent)
        }

        let connectionIsRecent = lastConnection > Date().addingTimeInterval(-Double(ConstantsFollower.secondsUntilFollowerDisconnectWarningNightscout))
        return SettingsIndicator(color: connectionIsRecent ? ConstantsAppColors.normal : ConstantsAppColors.urgent)
    }

    // MARK: - private functions
    
    /// test the nightscout url and api key and send result to messageHandler
    private func testNightscoutCredentials() {
        
        // unwrap siteUrl and apiKey
        guard var siteUrl = UserDefaults.standard.nightscoutUrl else {return}
        
        // add port number if it exists
        if UserDefaults.standard.nightscoutPort != 0 {
            siteUrl += ":" + UserDefaults.standard.nightscoutPort.description
        }
                
        if let url = URL(string: siteUrl) {
            
            let testURL = url.appendingPathComponent(nightscoutAuthTestPath)
            
            var request = URLRequest(url: testURL)
            request.setValue("application/json", forHTTPHeaderField:"Content-Type")
            request.setValue("application/json", forHTTPHeaderField:"Accept")
            
            // if the API_SECRET is present, then hash it and pass it via http header. If it's missing but there is a token, then send this as plain text to allow the authentication check.
            if let apiKey = UserDefaults.standard.nightscoutAPIKey {
                
                request.setValue(apiKey.sha1(), forHTTPHeaderField:"api-secret")
                
            } else if let token = UserDefaults.standard.nightscoutToken {
                
                request.setValue(token, forHTTPHeaderField:"api-secret")
                
            }
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                
                trace("in testNightscoutCredentials, finished task", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info)
                
                if let error = error {
                    
                    if error.localizedDescription.hasPrefix("A server with the specified hostname could not be found") {
                    
                        print("in testNightscoutCredentials, error = URL/Hostname not found!")
                        
                        trace("in testNightscoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info, error.localizedDescription)
                        
                        self.callMessageHandlerInMainThread(title: "URL/Hostname not found!", message: error.localizedDescription)
                        
                        return
                        
                    } else {
                        
                        trace("in testNightscoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info, error.localizedDescription)
                        
                        self.callMessageHandlerInMainThread(title: TextsNightscout.verificationErrorAlertTitle, message: error.localizedDescription)
                        
                        return
                        
                    }
                }
                
                if let httpResponse = response as? HTTPURLResponse, let data = data {
                    
                    let errorMessage = String(data: data, encoding: String.Encoding.utf8)!
                    
                    switch httpResponse.statusCode {
                        
                    case (200...299):
                        
                        trace("in testNightscoutCredentials, successful", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info)

                        // A successful manual check proves that the current
                        // Nightscout URL/authentication settings are valid, so
                        // we can use the shared follower connection timestamp as
                        // the row's last-known-good connection value.
                        UserDefaults.standard.timeStampOfLastFollowerConnection = Date()
                        self.callSectionReloadClosureInMainThread()
                        
                        self.callMessageHandlerInMainThread(title: TextsNightscout.verificationSuccessfulAlertTitle, message: TextsNightscout.verificationSuccessfulAlertBody)
                        
                    case (400):
                        
                        trace("in testNightscoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info, errorMessage)
                        
                        self.callMessageHandlerInMainThread(title: "400: Bad Request", message: errorMessage)
                        
                    case (401):
                        
                        if UserDefaults.standard.nightscoutAPIKey != nil {
                            
                            trace("in testNightscoutCredentials, API_SECRET is not valid, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info, errorMessage)
                            
                            self.callMessageHandlerInMainThread(title: "API_SECRET is not valid", message: errorMessage)
                            
                        } else if UserDefaults.standard.nightscoutAPIKey == nil && UserDefaults.standard.nightscoutToken != nil {
                            
                            trace("in testNightscoutCredentials, Token is not valid, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info, errorMessage)
                            
                            self.callMessageHandlerInMainThread(title: "Token is not valid", message: errorMessage)
                            
                        } else {
                            
                            trace("in testNightscoutCredentials, URL responds OK but authentication method is missing and cannot be checked", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info)
                            
                            self.callMessageHandlerInMainThread(title: TextsNightscout.verificationSuccessfulAlertTitle, message: "URL responds OK but authentication method is missing and cannot be checked!")
                            
                        }
                    
                    case (403):
                        
                        trace("in testNightscoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info, errorMessage)
                        
                        self.callMessageHandlerInMainThread(title: "403: Forbidden Request", message: errorMessage)
                        
                    case (404):
                        
                        trace("in testNightscoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info, errorMessage)
                        
                        self.callMessageHandlerInMainThread(title: "404: Page Not Found", message: errorMessage)
                        
                    default:
                        
                        trace("in testNightscoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info, errorMessage)
                        
                        self.callMessageHandlerInMainThread(title: TextsNightscout.verificationErrorAlertTitle, message: errorMessage)
                        
                    }
                    
                }
                
            })
            
            trace("in testNightscoutCredentials, calling task.resume", log: log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info)
            task.resume()
        }
    }
    
    private func callMessageHandlerInMainThread(title: String, message: String) {
        
        // unwrap messageHandler
        guard let messageHandler = messageHandler else {return}
        
        DispatchQueue.main.async {
            messageHandler(title, message)
        }
        
    }

    private func callSectionReloadClosureInMainThread() {
        guard let sectionReloadClosure = sectionReloadClosure else { return }

        // Settings callbacks can be triggered from URLSession or timer work, so
        // keep the SwiftUI refresh safely on the main thread.
        DispatchQueue.main.async {
            sectionReloadClosure()
        }
    }

    /// Starts a small UI-only refresh timer so the connection age and status dot
    /// keep ageing while the Nightscout settings screen remains open.
    private func startConnectionTimestampRefreshTimer() {
        guard rowGroup == .actions else { return }

        connectionTimestampRefreshTimer?.invalidate()
        connectionTimestampRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sectionReloadClosure?()
        }
    }

    /// Clears the last known good connection when the Nightscout connection
    /// settings change, because the previous success no longer proves that the
    /// new URL, secret, token, port or enabled state can connect.
    private func resetLastConnectionTimestamp() {
        UserDefaults.standard.timeStampOfLastFollowerConnection = .distantPast
        callSectionReloadClosureInMainThread()
    }
    
}

/// conforms to SettingsViewModelProtocol for all nightscout settings in the first sections screen
extension SettingsViewNightscoutSettingsViewModel: SettingsViewModelProtocol {

    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}

    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
        startConnectionTimestampRefreshTimer()
    }
    

    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {
        self.messageHandler = messageHandler
    }
    
   func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .nightscoutEnabled:
            return SettingsSelectedRowAction.nothing
            
        case .nightscoutFollowType:
                // data to be displayed in list from which user needs to pick a live activity type
                var data = [String]()
                var selectedRow: Int?
                var index = 0
                
            let currentNightscoutFollowType = UserDefaults.standard.nightscoutFollowType
                
                // get all Nightscout follower types and add the description to data. Search for the type that matches the FightscoutFollowerType that is currently stored in userdefaults.
                for nightscoutFollowType in NightscoutFollowType.allCasesForList {
                    
                    data.append(nightscoutFollowType.descriptionExpanded)
                    
                    if nightscoutFollowType == currentNightscoutFollowType {
                        selectedRow = index
                    }
                    index += 1
                }
                
                return SettingsSelectedRowAction.selectFromList(title: Texts_SettingsView.labelNightscoutFollowType, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                    
                    // we'll set this here so that we can use it in the else statement for logging
                    let oldNightscoutFollowType = UserDefaults.standard.nightscoutFollowType
                    
                    if index != selectedRow {
                        
                        UserDefaults.standard.nightscoutFollowType = NightscoutFollowType(forRowAt: index) ?? .none
                        
                        let newNightscoutFollowType = UserDefaults.standard.nightscoutFollowType
                        
                        trace("Nightscout follower type was changed from '%{public}@' to '%{public}@'", log: self.log, category: ConstantsLog.categoryNightscoutSettingsViewModel, type: .info, oldNightscoutFollowType.description, newNightscoutFollowType.description)
                    }
                }, cancelHandler: nil, didSelectRowHandler: nil)
            
        case .nightscoutUrl:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightscoutUrl, message: Texts_SettingsView.giveNightscoutUrl, keyboardType: .URL, text: UserDefaults.standard.nightscoutUrl != nil ? UserDefaults.standard.nightscoutUrl : ConstantsNightscout.defaultNightscoutUrl, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(nightscouturl: String) in
                
                // if user gave empty string then set to nil
                // if not nil, and if not starting with http or https, add https, and remove ending /
                var enteredURL = nightscouturl.toNilIfLength0()
                
                // assuming that the enteredURL isn't nil, isn't the default value and hasn't been entered without a valid scheme
                if enteredURL != nil && enteredURL != ConstantsNightscout.defaultNightscoutUrl  && !enteredURL!.startsWith("https://http") {
                    
                    // if self doesn't start with http or https, then add https. This might not make sense, but it will guard against throwing fatal errors when trying to get the scheme of the Endpoint
                    if !enteredURL!.startsWith("http://") && !enteredURL!.startsWith("https://") {
                        enteredURL = "https://" + enteredURL!
                    }
                    
                    // if url ends with /, remove it
                    if enteredURL!.last == "/" {
                        enteredURL!.removeLast()
                    }
                    
                    // remove the api path if it exists - useful for people pasting in xDrip+ Base URLs
                    enteredURL = enteredURL!.replacingOccurrences(of: "/api/v1", with: "")
                    
                    // if we've got a valid URL, then let's break it down
                    if let enteredURLComponents = URLComponents(string: enteredURL!) {
                        
                        // pull the port info if it exists and set the port
                        if let port = enteredURLComponents.port {
                            UserDefaults.standard.nightscoutPort = port
                        }
                        
                        // pull the "user" info if it exists and use it to set the API_SECRET
                        if let user = enteredURLComponents.user {
                            UserDefaults.standard.nightscoutAPIKey = user.toNilIfLength0()
                        }
                        
                        // if the user has pasted in a URL with a token, then let's parse it out and use it
                        if let token = enteredURLComponents.queryItems?.first(where: { $0.name == "token" })?.value {
                            UserDefaults.standard.nightscoutToken = token.toNilIfLength0()
                        }
                        
                        // finally, let's make a clean URL with just the scheme and host. We don't need to add anything else as this is basically the only thing we were asking for in the first place.
                        var nighscoutURLComponents = URLComponents()
                        nighscoutURLComponents.scheme = "https"
                        nighscoutURLComponents.host = enteredURLComponents.host?.lowercased()
                        
                        UserDefaults.standard.nightscoutUrl = nighscoutURLComponents.string!
                        
                    }
                    
                } else {
                    
                    // there must be something wrong with the URL the user is trying to add, so let's just ignore it
                    UserDefaults.standard.nightscoutUrl = nil
                    
                }

                self.resetLastConnectionTimestamp()
                
            }, cancelHandler: nil, inputValidator: nil)

        case .nightscoutAPIKey:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightscoutAPIKey, message:  Texts_SettingsView.giveNightscoutAPIKey, keyboardType: .default, text: UserDefaults.standard.nightscoutAPIKey, placeHolder: "MyAPISecret123", actionTitle: nil, cancelTitle: nil, actionHandler: {(apiKey: String) in
                UserDefaults.standard.nightscoutAPIKey = apiKey.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                self.resetLastConnectionTimestamp()
            }, cancelHandler: nil, inputValidator: nil)

        case .port:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.nightscoutPort, message: nil, keyboardType: .numberPad, text: UserDefaults.standard.nightscoutPort != 0 ? UserDefaults.standard.nightscoutPort.description : nil, placeHolder: "1337", fieldTitle: Texts_SettingsView.enterNightscoutPortNumber, actionTitle: nil, cancelTitle: nil, actionHandler: {(port: String) in
                if let port = port.trimmingCharacters(in: .whitespaces).toNilIfLength0() {
                    UserDefaults.standard.nightscoutPort = Int(port) ?? 0
                } else {
                    UserDefaults.standard.nightscoutPort = 0
                }
                self.resetLastConnectionTimestamp()
            }, cancelHandler: nil, inputValidator: nil)
        
        case .token:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.nightscoutToken, message: Texts_SettingsView.giveNightscoutToken, keyboardType: .default, text: UserDefaults.standard.nightscoutToken, placeHolder: "readable-3f033c4515e623c2", actionTitle: nil, cancelTitle: nil, actionHandler: {(token: String) in
                UserDefaults.standard.nightscoutToken = token.trimmingCharacters(in: .whitespaces).toNilIfLength0()
                self.resetLastConnectionTimestamp()
            }, cancelHandler: nil, inputValidator: nil)
            
        case .testUrlAndAPIKey:
            return .callFunction { [weak self] in
                guard let self else { return }

                // show info that test is started, through the messageHandler
                if let messageHandler = self.messageHandler {
                    messageHandler(TextsNightscout.nightscoutAPIKeyAndURLStartedTitle, TextsNightscout.nightscoutAPIKeyAndURLStartedBody)
                }

                self.testNightscoutCredentials()
            }
            
        case .openNightscout:
            guard let nightscoutURL = UserDefaults.standard.nightscoutUrl,
                  let url = URL(string: nightscoutURL),
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return .nothing
            }

            if UserDefaults.standard.nightscoutPort != 0 {
                components.port = UserDefaults.standard.nightscoutPort
            }

            if let token = UserDefaults.standard.nightscoutToken {
                components.queryItems = [URLQueryItem(name: "token", value: token)]
            }

            guard let url = components.url else { return .nothing }

            return .openURL(url)

        case .useSchedule:
            return .nothing
            
        case .schedule:
            return .performSegue(withIdentifier: SettingsSegueIdentifier.settingsToSchedule.rawValue, sender: self)
            
        case .uploadSensorStartTime:
            return SettingsSelectedRowAction.nothing
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleNightscout
    }

    func numberOfRows() -> Int {
        
        // if nightscout upload not enabled then only first row is shown
        if UserDefaults.standard.nightscoutEnabled {
            
            // Follower mode normally shows only the connection and action rows.
            // LibreLinkUp also exposes the sensor-start option because it supplies the timestamp.
            if !UserDefaults.standard.isMaster {
                return isLibreLinkUpFollower ? 9 : 8
            }
            
            // if schedule not enabled then show all rows except the last which is to edit the schedule
            if !UserDefaults.standard.nightscoutUseSchedule {
                return Setting.allCases.count - 1
            }
            
            return Setting.allCases.count
            
        } else {
            return 1
        }
    }

    /// LibreLinkUp is currently the only follower service that supplies an authoritative
    /// sensor start timestamp, so the Nightscout option must remain hidden for other sources.
    private var isLibreLinkUpFollower: Bool {
        guard !UserDefaults.standard.isMaster else { return false }

        return UserDefaults.standard.followerDataSourceType == .libreLinkUp || UserDefaults.standard.followerDataSourceType == .libreLinkUpRussia
    }

    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightscoutEnabled:
            return Texts_SettingsView.labelNightscoutEnabled
        case .nightscoutFollowType:
            return Texts_SettingsView.labelNightscoutFollowType
        case .nightscoutUrl:
            return Texts_SettingsView.labelNightscoutUrl
        case .nightscoutAPIKey:
            return Texts_SettingsView.labelNightscoutAPIKey
        case .port:
            return Texts_SettingsView.nightscoutPort
        case .token:
            return Texts_SettingsView.nightscoutToken
        case .useSchedule:
            return Texts_SettingsView.useSchedule
        case .schedule:
            return Texts_SettingsView.schedule
        case .uploadSensorStartTime:
            return Texts_SettingsView.uploadSensorStartTime
        case .testUrlAndAPIKey:
            return Texts_SettingsView.testUrlAndAPIKey
        case .openNightscout:
            return Texts_SettingsView.openNightscout
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightscoutFollowType, .nightscoutUrl, .nightscoutAPIKey, .port, .token, .schedule:
            return .disclosure
        case .openNightscout:
            return UserDefaults.standard.nightscoutUrl == nil ? .none : .disclosure
        default:
            return .none
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightscoutFollowType:
            return UserDefaults.standard.nightscoutFollowType.description
        case .nightscoutUrl:
            return UserDefaults.standard.nightscoutUrl ?? Texts_SettingsView.valueIsRequired
        case .nightscoutAPIKey:
            return UserDefaults.standard.nightscoutAPIKey?.obscured() ?? nil
        case .port:
            return UserDefaults.standard.nightscoutPort != 0 ? UserDefaults.standard.nightscoutPort.description : nil
        case .token:
            return UserDefaults.standard.nightscoutToken?.obscured() ?? ""
        case .openNightscout:
            return UserDefaults.standard.nightscoutUrl == nil ? Texts_HomeView.nightscoutURLMissing : nil
        default:
            return nil
        }
    }

    func settingsToggle(index: Int) -> SettingsToggleControl? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
        case .nightscoutEnabled:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.nightscoutEnabled },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("nightscoutEnabled changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewNightscoutSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.nightscoutEnabled = isOn
                    self.resetLastConnectionTimestamp()
                }
            )
        case .useSchedule:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.nightscoutUseSchedule },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("useSchedule changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewNightscoutSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.nightscoutUseSchedule = isOn
                }
            )
        case .uploadSensorStartTime:
            return SettingsToggleControl(
                isOn: { UserDefaults.standard.uploadSensorStartTimeToNS },
                setIsOn: { [weak self] isOn in
                    guard let self else { return }
                    trace("uploadSensorStartTime changed by user to %{public}@", log: self.log, category: ConstantsLog.categorySettingsViewNightscoutSettingsViewModel, type: .info, isOn.description)
                    UserDefaults.standard.uploadSensorStartTimeToNS = isOn
                }
            )
        default:
            return nil
        }
    }
    
    
}

extension SettingsViewNightscoutSettingsViewModel: TimeSchedule {
    
    func serviceName() -> String {
        return "Nightscout"
    }
    
    func getSchedule() -> [Int] {

        var schedule = [Int]()
        
        if let scheduleInSettings = UserDefaults.standard.nightscoutSchedule {
            
            schedule = scheduleInSettings.split(separator: "-").map({Int($0) ?? 0})
            
        }

        return schedule
        
    }
    
    func storeSchedule(schedule: [Int]) {
        
        var scheduleToStore: String?
        
        for entry in schedule {
            
            if scheduleToStore == nil {
                
                scheduleToStore = entry.description
                
            } else {
                
                scheduleToStore = scheduleToStore! + "-" + entry.description
                
            }
            
        }
        
        UserDefaults.standard.nightscoutSchedule = scheduleToStore
        
    }
    
    
}
