import UIKit
import os
import Foundation
import SafariServices

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

class SettingsViewNightscoutSettingsViewModel {
    
    // MARK: - properties
    
    /// in case info message or errors occur like credential check error, then this closure will be called with title and message
    /// - parameters:
    ///     - first parameter is title
    ///     - second parameter is the message
    ///
    /// the viewcontroller sets it by calling storeMessageHandler
    private var messageHandler: ((String, String) -> Void)?
    
    /// path to test API Secret
    private let nightscoutAuthTestPath = "/api/v1/experiments/test"
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMG5)
    
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
    
}

/// conforms to SettingsViewModelProtocol for all nightscout settings in the first sections screen
extension SettingsViewNightscoutSettingsViewModel: SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}

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
                
            }, cancelHandler: nil, inputValidator: nil)

        case .nightscoutAPIKey:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightscoutAPIKey, message:  Texts_SettingsView.giveNightscoutAPIKey, keyboardType: .default, text: UserDefaults.standard.nightscoutAPIKey, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(apiKey: String) in
                UserDefaults.standard.nightscoutAPIKey = apiKey.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)

        case .port:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.nightscoutPort, message: nil, keyboardType: .numberPad, text: UserDefaults.standard.nightscoutPort != 0 ? UserDefaults.standard.nightscoutPort.description : nil, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(port: String) in if let port = port.toNilIfLength0() { UserDefaults.standard.nightscoutPort = Int(port) ?? 0 } else {UserDefaults.standard.nightscoutPort = 0}}, cancelHandler: nil, inputValidator: nil)
        
        case .token:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.nightscoutToken, message:  nil, keyboardType: .default, text: UserDefaults.standard.nightscoutToken, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(token: String) in
                UserDefaults.standard.nightscoutToken = token.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .testUrlAndAPIKey:

                // show info that test is started, through the messageHandler
                if let messageHandler = messageHandler {
                    messageHandler(TextsNightscout.nightscoutAPIKeyAndURLStartedTitle, TextsNightscout.nightscoutAPIKeyAndURLStartedBody)
                }
                
                self.testNightscoutCredentials()
                
                return .nothing
            
        case .openNightscout:
            if let url = URL(string: UserDefaults.standard.nightscoutUrl ?? "") {
                openWeb(url)
            }
            
            return .nothing

        case .useSchedule:
            return .nothing
            
        case .schedule:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToSchedule.rawValue, sender: self)
            
        case .uploadSensorStartTime:
            return SettingsSelectedRowAction.nothing
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.nightscoutSettingsIcon + " " + Texts_SettingsView.sectionTitleNightscout
    }

    func numberOfRows() -> Int {
        
        // if nightscout upload not enabled then only first row is shown
        if UserDefaults.standard.nightscoutEnabled {
            
            // in follower mode, only 6 first rows to be shown : nightscout enabled button, follow type, url, port number, token, api key, option to test and open Nightscout
            if !UserDefaults.standard.isMaster {
                return 8
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
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightscoutFollowType, .nightscoutUrl, .nightscoutAPIKey, .port, .token, .schedule:
            return .disclosureIndicator
        case .openNightscout:
            return UserDefaults.standard.nightscoutUrl == nil ? .none : .disclosureIndicator
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
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightscoutEnabled:
            return UISwitch(isOn: UserDefaults.standard.nightscoutEnabled, action: {(isOn: Bool) in UserDefaults.standard.nightscoutEnabled = isOn})
        case .useSchedule:
            return UISwitch(isOn: UserDefaults.standard.nightscoutUseSchedule, action: {(isOn: Bool) in UserDefaults.standard.nightscoutUseSchedule = isOn})
        case .uploadSensorStartTime:
            return UISwitch(isOn: UserDefaults.standard.uploadSensorStartTimeToNS, action: {(isOn: Bool) in UserDefaults.standard.uploadSensorStartTimeToNS = isOn})
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


