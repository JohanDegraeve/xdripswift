import UIKit
import os

fileprivate enum Setting:Int, CaseIterable {
    
    ///should readings be uploaded or not
    case nightScoutEnabled = 0
    
    ///nightscout url
    case nightScoutUrl = 1
    
    /// port
    case port = 2
    
    /// nightscout api key
    case nightScoutAPIKey = 3
    
    /// to allow testing explicitly
    case testUrlAndAPIKey = 4
    
    /// should sensor start time be uploaded to NS yes or no
    case uploadSensorStartTime = 5
    
    /// use nightscout schedule or not
    case useSchedule = 6
    
    /// open uiviewcontroller to edit schedule
    case schedule = 7
    
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
        guard let siteUrl = UserDefaults.standard.nightScoutUrl, let apiKey = UserDefaults.standard.nightScoutAPIKey else {return}
        
        if let url = URL(string: siteUrl) {
            let testURL = url.appendingPathComponent(nightScoutAuthTestPath)
            
            var request = URLRequest(url: testURL)
            request.setValue("application/json", forHTTPHeaderField:"Content-Type")
            request.setValue("application/json", forHTTPHeaderField:"Accept")
            request.setValue(apiKey.sha1(), forHTTPHeaderField:"api-secret")
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                
                trace("in testNightScoutCredentials, finished task", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info)
                
                if let error = error {
                    
                    trace("in testNightScoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info, error.localizedDescription)
                    
                    self.callMessageHandlerInMainThread(title: Texts_NightScoutTestResult.verificationErrorAlertTitle, message: error.localizedDescription)
                    
                    return
                    
                }
                
                if let httpResponse = response as? HTTPURLResponse ,
                    httpResponse.statusCode != 200, let data = data {
                    
                    let errorMessage = String(data: data, encoding: String.Encoding.utf8)!
                    
                    trace("in testNightScoutCredentials, error = %{public}@", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info, errorMessage)
                    
                   self.callMessageHandlerInMainThread(title: Texts_NightScoutTestResult.verificationErrorAlertTitle, message: errorMessage)
                    
                } else {
                    
                    trace("in testNightScoutCredentials, successful", log: self.log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info)
                    
                    self.callMessageHandlerInMainThread(title: Texts_NightScoutTestResult.verificationSuccessFulAlertTitle, message: Texts_NightScoutTestResult.verificationSuccessFulAlertBody)
                    
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
                // if not nil, and if not starting with http, add https, and remove ending /
                UserDefaults.standard.nightScoutUrl = nightscouturl.toNilIfLength0().addHttpsIfNeeded()
                
            }, cancelHandler: nil, inputValidator: nil)

        case .nightScoutAPIKey:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightScoutAPIKey, message:  Texts_SettingsView.giveNightScoutAPIKey, keyboardType: .default, text: UserDefaults.standard.nightScoutAPIKey, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(apiKey:String) in
                UserDefaults.standard.nightScoutAPIKey = apiKey.toNilIfLength0()}, cancelHandler: nil, inputValidator: nil)
           
        case .testUrlAndAPIKey:

            if UserDefaults.standard.nightScoutAPIKey != nil && UserDefaults.standard.nightScoutUrl != nil {

                // show info that test is started, through the messageHandler
                if let messageHandler = messageHandler {
                    messageHandler(Texts_HomeView.info, Texts_NightScoutTestResult.nightScoutAPIKeyAndURLStarted)
                }
                
                self.testNightScoutCredentials()
                
                return .nothing

            } else {
                
                return .showInfoText(title: Texts_Common.warning, message: Texts_NightScoutTestResult.warningAPIKeyOrURLIsnil)
                
            }

        case .useSchedule:
            return .nothing
            
        case .schedule:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToSchedule.rawValue, sender: self)
            
        case .uploadSensorStartTime:
            return SettingsSelectedRowAction.nothing
            
        case .port:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.nightScoutPort, message: nil, keyboardType: .numberPad, text: UserDefaults.standard.nightScoutPort != 0 ? UserDefaults.standard.nightScoutPort.description : nil, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(port:String) in if let port = port.toNilIfLength0() { UserDefaults.standard.nightScoutPort = Int(port) ?? 0 } else {UserDefaults.standard.nightScoutPort = 0}}, cancelHandler: nil, inputValidator: nil)}
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleNightScout
    }

    func numberOfRows() -> Int {
        
        // if nightscout upload not enabled then only first row is shown
        if UserDefaults.standard.nightScoutEnabled {
            
            // in follower mode, only two first rows to be shown : nightscout enabled button and url
            if !UserDefaults.standard.isMaster {
                return 2
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
            
        case .nightScoutAPIKey:
            return Texts_SettingsView.labelNightScoutAPIKey
        case .nightScoutUrl:
            return Texts_SettingsView.labelNightScoutUrl
        case .nightScoutEnabled:
            return Texts_SettingsView.labelNightScoutEnabled
        case .useSchedule:
            return Texts_SettingsView.useSchedule
        case .schedule:
            return Texts_SettingsView.schedule
        case .uploadSensorStartTime:
            return Texts_SettingsView.uploadSensorStartTime
        case .testUrlAndAPIKey:
            return Texts_SettingsView.testUrlAndAPIKey
        case .port:
            return Texts_SettingsView.nightScoutPort
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
        case .useSchedule:
            return UITableViewCell.AccessoryType.none
        case .schedule:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .uploadSensorStartTime:
            return UITableViewCell.AccessoryType.none
        case .testUrlAndAPIKey:
            return .none
        case .port:
            return .disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .nightScoutEnabled:
            return nil
        case .nightScoutAPIKey:
            return UserDefaults.standard.nightScoutAPIKey
        case .nightScoutUrl:
            return UserDefaults.standard.nightScoutUrl
        case .useSchedule:
            return nil
        case .schedule:
            return nil
        case .uploadSensorStartTime:
            return nil
        case .testUrlAndAPIKey:
            return nil
        case .port:
            return UserDefaults.standard.nightScoutPort != 0 ? UserDefaults.standard.nightScoutPort.description : nil
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
            
        case .useSchedule:
            return UISwitch(isOn: UserDefaults.standard.nightScoutUseSchedule, action: {(isOn:Bool) in UserDefaults.standard.nightScoutUseSchedule = isOn})
            
        case .schedule:
            return nil
            
        case .uploadSensorStartTime:
            return UISwitch(isOn: UserDefaults.standard.uploadSensorStartTimeToNS, action: {(isOn:Bool) in UserDefaults.standard.uploadSensorStartTimeToNS = isOn})
            
        case .testUrlAndAPIKey:
            return nil
            
        case .port:
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


