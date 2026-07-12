import Foundation

fileprivate enum Setting:Int, CaseIterable {
    
    /// version Number
    case versionNumber = 0
    
    /// app install date
    case installDate = 1
    
    /// licenseInfo
    case licenseInfo = 2
    
    /// link to open the project GitHub page
    case showGitHub = 3
    
}

struct SettingsViewInfoViewModel:SettingsViewModelProtocol {
    
    // MARK: - Native SwiftUI rows

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        [
            nativeSettingsRow(id: "info.versionNumber", index: Setting.versionNumber.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "info.installDate", index: Setting.installDate.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "info.licenseInfo", index: Setting.licenseInfo.rawValue, sectionID: sectionID),
            nativeSettingsRow(id: "info.showGitHub", index: Setting.showGitHub.rawValue, sectionID: sectionID)
        ]
    }

    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
    
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleAbout
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .versionNumber:
            
            return Texts_SettingsView.version
            
        case .installDate:
            return Texts_SettingsView.installedSince

        case .licenseInfo:
            return Texts_SettingsView.license
            
        case .showGitHub:
            return Texts_SettingsView.showGitHub

        }
        
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .installDate:
            return .none

        case .versionNumber:
            return .disclosure

        case .licenseInfo:
            return .disclosure
            
        case .showGitHub:
            return .disclosure
            
        }
        
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .versionNumber:
            
            guard let dictionary = Bundle.main.infoDictionary else {return "unknown"}
            
            guard let version = dictionary["CFBundleShortVersionString"] as? String else {return "unknown"}
            
            guard let build = dictionary["CFBundleVersion"] as? String else {return "unknown"}

            return version + " (" + build + ")"

        case .installDate:

            return installDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short) + " (" + installDate.daysAndHoursAgo(showOnlyDays: true) + ")"
            
        case .licenseInfo:

            return ConstantsHomeView.licenseType

        case .showGitHub:
            
            return ConstantsHomeView.gitHubRepositoryName

        }
        
    }
    
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .versionNumber:
            guard let version = appVersion,
                  let url = SettingsAppInfo.releaseNotesURL(version: version) else { return .nothing }

            return .openURL(url)

        case .installDate:
            return .nothing
            
        case .licenseInfo:
            return SettingsSelectedRowAction.showInfoText(title: ConstantsHomeView.applicationName, message: Texts_HomeView.licenseInfo + ConstantsHomeView.infoEmailAddress)

        case .showGitHub:
            guard let url = URL(string: ConstantsHomeView.gitHubURL) else { return .nothing}
            
            return .openURL(url)
            
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        
        return true
        
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        return false
        
    }

    private var installDate: Date {
        // this intentionally matches the install date used in the appinfo trace file
        // it uses the Documents folder creation date as a reliable local install timestamp
        if let documentsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            if let installDate = try? FileManager.default.attributesOfItem(atPath: documentsFolder.path)[.creationDate] as? Date {
                return installDate
            }
        }

        return Date()
    }

    private var appVersion: String? {
        guard let dictionary = Bundle.main.infoDictionary else {return nil}

        return dictionary["CFBundleShortVersionString"] as? String
    }
    
    
}
