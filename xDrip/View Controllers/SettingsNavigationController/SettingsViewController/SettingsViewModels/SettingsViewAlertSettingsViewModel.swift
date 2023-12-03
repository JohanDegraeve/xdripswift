import UIKit
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
    
    /// show slope in alarms
    case showSlopeInAlarms = 4
    
}

/// conforms to SettingsViewModelProtocol for all alert settings in the first sections screen
struct SettingsViewAlertSettingsViewModel:SettingsViewModelProtocol {
    
    func storeUIViewController(uIViewController: UIViewController) {}

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
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToAlertTypeSettings.rawValue, sender: nil)
        case .alerts:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToAlertSettings.rawValue, sender: nil)
            
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
            
        case .showSlopeInAlarms:
            return .nothing

        }
        
    }
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.alertSettingsIcon + " " + Texts_SettingsView.sectionTitleAlerting
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .showSlopeInAlarms:
            return UISwitch(isOn: UserDefaults.standard.showSlopeInAlarms, action: {(isOn:Bool) in UserDefaults.standard.showSlopeInAlarms = isOn})
        default:
            return nil
        }
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
        
        case .showSlopeInAlarms:
            return Texts_SettingsView.showSlopeInAlarms
            
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {

        case .alertTypes, .alerts:
            
            return .disclosureIndicator
            
        case .volumeTestSoundPlayer, .volumeTestiOSSound, .showSlopeInAlarms:
            
            return .none
            
        }
        
    }
    
    func detailedText(index: Int) -> String? {
        return nil
    }
    
}
