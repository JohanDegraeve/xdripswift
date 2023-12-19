import UIKit
import os
import Foundation

fileprivate enum Setting:Int, CaseIterable {
    
    ///should readings be uploaded or not
    case nightScoutEnabled = 0
    
    ///nightscout url
    case nightScoutUrl = 1
    
    /// nightscout api key
    case nightScoutAPIKey = 2
    
    /// nightscout api key
    case token = 3
    
    /// port
    case port = 4
    
    /// to allow testing explicitly
    case testUrlAndAPIKey = 5
    
    /// should sensor start time be uploaded to NS yes or no
    case uploadSensorStartTime = 6
    
    /// use nightscout schedule or not
    case useSchedule = 7
    
    /// open uiviewcontroller to edit schedule
    case schedule = 8
    
}

class SettingsViewNightScoutSettingsViewModel {
    
    // MARK: - properties
    
    /// in case info message or errors occur like credential check error, then this closure will be called with title and message
    /// - parameters:
    ///     - first parameter is title
    ///     - second parameter is the message
    ///
    /// the viewcontroller sets it by calling storeMessageHandler
    private var messageHandler: ((String, String) -> Void)?
    
    /// path to test API Secret
    private let nightScoutAuthTestPath = "/api/v1/experiments/test"
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMG5)
    
    // MARK: - private functions
    
    /// test the nightscout url and api key and send result to messageHandler
    private func testNightScoutCredentials() {
        
        // unwrap siteUrl and apiKey
        guard var siteUrl = UserDefaults.standard.nightScoutUrl else {return}
        
        // add port number if it exists
        if UserDefaults.standard.nightScoutPort != 0 {
            siteUrl += ":" + UserDefaults.standard.nightScoutPort.description
        }
                
        if let url = URL(string: siteUrl) {
            
            let testURL = url.appendingPathComponent(nightScoutAuthTestPath)
            
            var request = URLRequest(url: testURL)
            request.setValue("application/json", forHTTPHeaderField:"Content-Type")
            request.setValue("application/json", forHTTPHeaderField:"Accept")
            
            // if the API_SECRET is present, then hash it and pass it via http header. If it's missing but there is a token, then send this as plain text to allow the authentication check.
            if let apiKey = UserDefaults.standard.nightScoutAPIKey {
                
                request.setValue(apiKey.sha1(), forHTTPHeaderField:"api-secret")
                
            } else if let token = UserDefaults.standard.nightscoutToken {
                
                request.setValue(token, forHTTPHeaderField:"api-secret")
                
            }
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                
                trace("in testNightScoutCredentials, finished task", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info)
                
                if let error = error {
                    
                    if error.localizedDescription.hasPrefix("A server with the specified hostname could not be found") {
                    
                        print("in testNightScoutCredentials, error = URL/Hostname not found!")
                        
                        trace("in testNightScoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info, error.localizedDescription)
                        
                        self.callMessageHandlerInMainThread(title: "URL/Hostname not found!", message: error.localizedDescription)
                        
                        return
                        
                    } else {
                        
                        trace("in testNightScoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info, error.localizedDescription)
                        
                        self.callMessageHandlerInMainThread(title: TextsNightScout.verificationErrorAlertTitle, message: error.localizedDescription)
                        
                        return
                        
                    }
                }
                
                if let httpResponse = response as? HTTPURLResponse, let data = data {
                    
                    let errorMessage = String(data: data, encoding: String.Encoding.utf8)!
                    
                    switch httpResponse.statusCode {
                        
                    case (200...299):
                        
                        trace("in testNightScoutCredentials, successful", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info)
                        
                        self.callMessageHandlerInMainThread(title: TextsNightScout.verificationSuccessfulAlertTitle, message: TextsNightScout.verificationSuccessfulAlertBody)
                        
                        
                        
                    case (400):
                        
                        trace("in testNightScoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info, errorMessage)
                        
                        self.callMessageHandlerInMainThread(title: "400: Bad Request", message: errorMessage)
                        
                    case (401):
                        
                        if UserDefaults.standard.nightScoutAPIKey != nil {
                            
                            trace("in testNightScoutCredentials, API_SECRET is not valid, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info, errorMessage)
                            
                            self.callMessageHandlerInMainThread(title: "API_SECRET is not valid", message: errorMessage)
                            
                        } else if UserDefaults.standard.nightScoutAPIKey == nil && UserDefaults.standard.nightscoutToken != nil {
                            
                            trace("in testNightScoutCredentials, Token is not valid, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info, errorMessage)
                            
                            self.callMessageHandlerInMainThread(title: "Token is not valid", message: errorMessage)
                            
                        } else {
                            
                            trace("in testNightScoutCredentials, URL responds OK but authentication method is missing and cannot be checked", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info)
                            
                            self.callMessageHandlerInMainThread(title: TextsNightScout.verificationSuccessfulAlertTitle, message: "URL responds OK but authentication method is missing and cannot be checked!")
                            
                        }
                    
                    case (403):
                        
                        trace("in testNightScoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info, errorMessage)
                        
                        self.callMessageHandlerInMainThread(title: "403: Forbidden Request", message: errorMessage)
                        
                    case (404):
                        
                        trace("in testNightScoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info, errorMessage)
                        
                        self.callMessageHandlerInMainThread(title: "404: Page Not Found", message: errorMessage)
                        
                    default:
                        
                        trace("in testNightScoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info, errorMessage)
                        
                        self.callMessageHandlerInMainThread(title: TextsNightScout.verificationErrorAlertTitle, message: errorMessage)
                        
                    }
                    
                }
                
            })
            
            trace("in testNightScoutCredentials, calling task.resume", log: log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info)
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
    
}

/// conforms to SettingsViewModelProtocol for all nightscout settings in the first sections screen
extension SettingsViewNightScoutSettingsViewModel: SettingsViewModelProtocol {
    
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
            
        case .nightScoutEnabled:
            return SettingsSelectedRowAction.nothing
            
        case .nightScoutUrl:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightScoutUrl, message: Texts_SettingsView.giveNightScoutUrl, keyboardType: .URL, text: UserDefaults.standard.nightScoutUrl != nil ? UserDefaults.standard.nightScoutUrl : ConstantsNightScout.defaultNightScoutUrl, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(nightscouturl:String) in
                
                // if user gave empty string then set to nil
                // if not nil, and if not starting with http or https, add https, and remove ending /
                var enteredURL = nightscouturl.toNilIfLength0()
                
                // assuming that the enteredURL isn't nil, isn't the default value and hasn't been entered without a valid scheme
                if enteredURL != nil && enteredURL != ConstantsNightScout.defaultNightScoutUrl  && !enteredURL!.startsWith("https://http") {
                    
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
                            UserDefaults.standard.nightScoutPort = port
                        }
                        
                        // pull the "user" info if it exists and use it to set the API_SECRET
                        if let user = enteredURLComponents.user {
                            UserDefaults.standard.nightScoutAPIKey = user.toNilIfLength0()
                        }
                        
                        // if the user has pasted in a URL with a token, then let's parse it out and use it
                        if let token = enteredURLComponents.queryItems?.first(where: { $0.name == "token" })?.value {
                            UserDefaults.standard.nightscoutToken = token.toNilIfLength0()
                        }
                        
                        // finally, let's make a clean URL with just the scheme and host. We don't need to add anything else as this is basically the only thing we were asking for in the first place.
                        var nighscoutURLComponents = URLComponents()
                        nighscoutURLComponents.scheme = "https"
                        nighscoutURLComponents.host = enteredURLComponents.host?.lowercased()
                        
                        UserDefaults.standard.nightScoutUrl = nighscoutURLComponents.string!
                        
                    }
                    
                } else {
                    
                    // there must be something wrong with the URL the user is trying to add, so let's just ignore it
                    UserDefaults.standard.nightScoutUrl = nil
                    
                }
                
            }, cancelHandler: nil, inputValidator: nil)

        case .nightScoutAPIKey:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightScoutAPIKey, message:  Texts_SettingsView.giveNightScoutAPIKey, keyboardType: .default, text: UserDefaults.standard.nightScoutAPIKey, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(apiKey:String) in
                UserDefaults.standard.nightScoutAPIKey = apiKey.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)

        case .port:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.nightScoutPort, message: nil, keyboardType: .numberPad, text: UserDefaults.standard.nightScoutPort != 0 ? UserDefaults.standard.nightScoutPort.description : nil, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(port:String) in if let port = port.toNilIfLength0() { UserDefaults.standard.nightScoutPort = Int(port) ?? 0 } else {UserDefaults.standard.nightScoutPort = 0}}, cancelHandler: nil, inputValidator: nil)
        
        case .token:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.nightscoutToken, message:  nil, keyboardType: .default, text: UserDefaults.standard.nightscoutToken, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(token:String) in
                UserDefaults.standard.nightscoutToken = token.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
            
        case .testUrlAndAPIKey:

                // show info that test is started, through the messageHandler
                if let messageHandler = messageHandler {
                    messageHandler(TextsNightScout.nightScoutAPIKeyAndURLStartedTitle, TextsNightScout.nightScoutAPIKeyAndURLStartedBody)
                }
                
                self.testNightScoutCredentials()
                
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
        return Texts_SettingsView.sectionTitleNightScout
    }

    func numberOfRows() -> Int {
        
        // if nightscout upload not enabled then only first row is shown
        if UserDefaults.standard.nightScoutEnabled {
            
            // in follower mode, only 6 first rows to be shown : nightscout enabled button, url, port number, token, api key, option to test
            if !UserDefaults.standard.isMaster {
                return 6
            }
            
            // if schedule not enabled then show all rows except the last which is to edit the schedule
            if !UserDefaults.standard.nightScoutUseSchedule {
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
            
        case .nightScoutEnabled:
            return Texts_SettingsView.labelNightScoutEnabled
        case .nightScoutUrl:
            return Texts_SettingsView.labelNightScoutUrl
        case .nightScoutAPIKey:
            return Texts_SettingsView.labelNightScoutAPIKey
        case .port:
            return Texts_SettingsView.nightScoutPort
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
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightScoutEnabled:
            return UITableViewCell.AccessoryType.none
        case .nightScoutUrl:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .nightScoutAPIKey:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .port:
            return .disclosureIndicator
        case .token:
            return .disclosureIndicator
        case .useSchedule:
            return UITableViewCell.AccessoryType.none
        case .schedule:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .uploadSensorStartTime:
            return UITableViewCell.AccessoryType.none
        case .testUrlAndAPIKey:
            return .none
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightScoutEnabled:
            return nil
        case .nightScoutUrl:
            return UserDefaults.standard.nightScoutUrl ?? Texts_SettingsView.valueIsRequired
        case .nightScoutAPIKey:
            return UserDefaults.standard.nightScoutAPIKey?.obscured() ?? nil
        case .port:
            return UserDefaults.standard.nightScoutPort != 0 ? UserDefaults.standard.nightScoutPort.description : nil
        case .token:
            return UserDefaults.standard.nightscoutToken?.obscured() ?? nil
        case .useSchedule:
            return nil
        case .schedule:
            return nil
        case .uploadSensorStartTime:
            return nil
        case .testUrlAndAPIKey:
            return nil
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .nightScoutEnabled:
            return UISwitch(isOn: UserDefaults.standard.nightScoutEnabled, action: {(isOn:Bool) in UserDefaults.standard.nightScoutEnabled = isOn})
        
        case .nightScoutUrl:
            return nil
            
        case .nightScoutAPIKey:
            return nil
            
        case .port:
            return nil
            
        case .token:
            return nil
            
        case .useSchedule:
            return UISwitch(isOn: UserDefaults.standard.nightScoutUseSchedule, action: {(isOn:Bool) in UserDefaults.standard.nightScoutUseSchedule = isOn})
            
        case .schedule:
            return nil
            
        case .uploadSensorStartTime:
            return UISwitch(isOn: UserDefaults.standard.uploadSensorStartTimeToNS, action: {(isOn:Bool) in UserDefaults.standard.uploadSensorStartTimeToNS = isOn})
            
        case .testUrlAndAPIKey:
            return nil
            
        }
    }
    
}

extension SettingsViewNightScoutSettingsViewModel: TimeSchedule {
    
    func serviceName() -> String {
        return "NightScout"
    }
    
    func getSchedule() -> [Int] {

        var schedule = [Int]()
        
        if let scheduleInSettings = UserDefaults.standard.nightScoutSchedule {
            
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
        
        UserDefaults.standard.nightScoutSchedule = scheduleToStore
        
    }
    
    
}


