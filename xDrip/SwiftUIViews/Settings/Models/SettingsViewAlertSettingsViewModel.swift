import Foundation
import AVFoundation

fileprivate enum Setting:Int, CaseIterable {
    
    /// alert types
    case alertTypes = 0
    
    /// alerts
    case alerts = 1
    
    /// volume test for sound played by soundPlayer
    case volumeTestSoundPlayer = 2
    
    /// volume test for sound play in iOS notification
    case volumeTestiOSSound = 3
    
}

enum AlertSettingsRowGroup {
    case alertTypes
    case alerts
    case volumeTests
}

/// conforms to SettingsViewModelProtocol for all alert settings in the first sections screen
struct SettingsViewAlertSettingsViewModel:SettingsViewModelProtocol {

    private let rowGroup: AlertSettingsRowGroup

    init(rowGroup: AlertSettingsRowGroup = .alertTypes) {
        self.rowGroup = rowGroup
    }
    
    // MARK: - Native SwiftUI rows

    func settingsSectionTitle() -> String? {
        switch rowGroup {
        case .alertTypes, .alerts:
            return nil
        case .volumeTests:
            return Texts_SettingsView.volumeTestsSectionTitle
        }
    }

    func settingsSectionFooter() -> String? {
        switch rowGroup {
        case .alertTypes:
            return Texts_SettingsView.alertTypesSectionFooter
        case .alerts:
            return Texts_SettingsView.alertsSectionFooter
        case .volumeTests:
            return nil
        }
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        switch rowGroup {
        case .alertTypes:
            return [
                nativeSettingsRow(id: "alerts.alertTypes", index: Setting.alertTypes.rawValue, sectionID: sectionID)
            ]
        case .alerts:
            return [
                nativeSettingsRow(id: "alerts.alerts", index: Setting.alerts.rawValue, sectionID: sectionID)
            ]
        case .volumeTests:
            return [
                volumeTestRow(id: "alerts.volumeTestiOSSound", index: Setting.volumeTestiOSSound.rawValue, sectionID: sectionID, symbolName: "bell"),
                volumeTestRow(id: "alerts.volumeTestSoundPlayer", index: Setting.volumeTestSoundPlayer.rawValue, sectionID: sectionID, symbolName: "bell.slash")
            ]
        }
    }

    /// Builds the volume-test rows as visible action rows while keeping the original
    /// selection logic below. These rows play a sound immediately, so they should
    /// look tappable instead of reading like passive settings values.
    private func volumeTestRow(id: String, index: Int, sectionID: Int, symbolName: String) -> SettingsRow {
        var row = nativeSettingsRow(id: id, index: index, sectionID: sectionID)
        row.icon = SettingsIcon(symbolName: symbolName, color: .accentColor)
        row.titleColor = .accentColor
        return row
    }


    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
        
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Setting in SettingsViewAlertSettingsViewModel onRowSelect") }

        switch setting {
        case .alertTypes:
            return .performSegue(withIdentifier: SettingsSegueIdentifier.settingsToAlertTypeSettings.rawValue, sender: nil)
        case .alerts:
            return .performSegue(withIdentifier: SettingsSegueIdentifier.settingsToAlertSettings.rawValue, sender: nil)
            
        case .volumeTestSoundPlayer:
            
            // here the volume of the soundplayer will be tested.
            // soundplayer is used for alerts with override mute = on, except for missed reading alerts or any other delayed alert
            
            // create a soundplayer
            let soundPlayer = SoundPlayer()
            
            // start playing the xdripalert.aif
            soundPlayer.playSound(soundFileName: "xdripalert.aif")
            
            return SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.volumeTestSoundPlayerExplanation, actionHandler: {
                
                // user clicked ok, which will close the pop up and also player should stop playing
                soundPlayer.stopPlaying()
                
            })
            
        case .volumeTestiOSSound:

            // here the iOS sound volume will be tested.
            // this volume is used for alerts with override mute = off, and for missed reading alerts
            // we use a notification for that with sound = xdripalert.aif
            // The app is in the foreground  now (otherwise user wouldn't be able to select this option)
            //    the RootViewController is conforming to UNUserNotificationCenterDelegate. As soon as notification content is added to uNUserNotificationCenter, the function userNotificationCenter willPresent will be called. There the completionHandler with .sound is called, which will cause the sound to be played
            
            // define and set the content
            let content = UNMutableNotificationContent()
            // body and title will not be shown, because app is in the foreground
            content.body = "will not be shown"
            content.title = "will not be shown"
            // sound
            content.sound = UNNotificationSound.init(named: UNNotificationSoundName.init("xdripalert.aif"))
            // notification request
            let notificationRequest = UNNotificationRequest(identifier: ConstantsNotifications.notificationIdentifierForVolumeTest, content: content, trigger: nil)
            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest)
            
            return SettingsSelectedRowAction.showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.volumeTestiOSSoundExplanation, actionHandler: nil)
            
        }
    }
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleAlerting
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }

    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Setting in SettingsViewAlertSettingsViewModel onRowSelect") }
        
        switch setting {
            
        case .alertTypes:
            return Texts_SettingsView.labelAlertTypes
        case .alerts:
            return Texts_SettingsView.labelAlerts
            
        case .volumeTestSoundPlayer:
            return Texts_SettingsView.volumeTestSoundPlayer
            
        case .volumeTestiOSSound:
            return Texts_SettingsView.volumeTestiOSSound
            
        }
    }
    
    func accessoryType(index: Int) -> SettingsAccessory {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

        case .alertTypes, .alerts:
            
            return .disclosure
            
        case .volumeTestSoundPlayer, .volumeTestiOSSound:
            
            return .none
            
        }
        
    }
    
    func detailedText(index: Int) -> String? {
        return nil
    }
    
}
