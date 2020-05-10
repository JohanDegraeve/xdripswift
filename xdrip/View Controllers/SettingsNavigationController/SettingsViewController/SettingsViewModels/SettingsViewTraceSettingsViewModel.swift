import UIKit
import MessageUI
import os

fileprivate enum Setting:Int, CaseIterable {
    
    /// write trace to file enabled or not
    case writeTraceToFile = 0
    
    /// to send trace file
    case sendTraceFile = 1
    
}

class SettingsViewTraceSettingsViewModel: NSObject {
    
    /// need to present MFMailComposeViewController
    private var uIViewController: UIViewController?
    
    /// to force a row reload
    private var rowReloadClosure: ((Int) -> Void)?
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryTraceSettingsViewModel)

    /// in case info message or errors occur like credential check error, then this closure will be called with title and message
    /// - parameters:
    ///     - first parameter is title
    ///     - second parameter is the message
    ///
    /// the viewcontroller sets it by calling storeMessageHandler
    private var messageHandler: ((String, String) -> Void)?

}

extension SettingsViewTraceSettingsViewModel: SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {
        self.rowReloadClosure = rowReloadClosure
    }
    
    func storeUIViewController(uIViewController: UIViewController) {
        self.uIViewController = uIViewController
    }

    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {
        self.messageHandler = messageHandler
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleTrace
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .writeTraceToFile:
            return Texts_SettingsView.writeTraceToFile
            
        case .sendTraceFile:
            return Texts_SettingsView.sendTraceFile
            
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .writeTraceToFile:
            return .none
            
        case .sendTraceFile:
            return .disclosureIndicator
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .writeTraceToFile:
            return nil
            
        case .sendTraceFile:
            return nil
            
        }
        
    }
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .writeTraceToFile:
            return UISwitch(isOn: UserDefaults.standard.writeTraceToFile, action: {
                
                (isOn:Bool) in
                
                if isOn {
                    
                    // set writeTraceToFile to true before logging in trace that it is enabled
                    UserDefaults.standard.writeTraceToFile = true
                    
                    trace("Trace to file enabled", log: self.log, category: ConstantsLog.categoryTraceSettingsViewModel, type: .info)
                    
                } else {
                    
                    trace("Trace to file disabled", log: self.log, category: ConstantsLog.categoryTraceSettingsViewModel, type: .info)

                    // set writeTraceToFile to false after logging in trace that it is enabled
                    UserDefaults.standard.writeTraceToFile = false
                    
                }
                
                
                
            })
            
        case .sendTraceFile:
            return nil
                
        }
        
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .writeTraceToFile:
            return .nothing
            
        case .sendTraceFile:
    
            if !UserDefaults.standard.writeTraceToFile {
                
                    return .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.warningWriteTraceToFile)

            } else {

                guard let uIViewController = uIViewController else {fatalError("in SettingsViewTraceSettingsViewModel, onRowSelect, uIViewController is nil")}
                
                do {
                    
                    // create traceFile info as data
                    let fileData = try Data(contentsOf: traceFileName)

                    // create app info as data
                    Trace.createAppInfoFile()
                    let appInfoData = try Data(contentsOf: appInfoFileName)

                    if MFMailComposeViewController.canSendMail() {
                        
                        return .askConfirmation(title: Texts_HomeView.info, message: Texts_SettingsView.describeProblem, actionHandler: {
                            
                            let mail = MFMailComposeViewController()
                            mail.mailComposeDelegate = self
                            mail.setToRecipients([ConstantsTrace.traceFileDestinationAddress])
                            mail.setMessageBody(Texts_SettingsView.emailbodyText, isHTML: true)
                            
                            mail.addAttachmentData(fileData as Data, mimeType: "text/txt", fileName: ConstantsTrace.traceFileName)
                            
                            mail.addAttachmentData(appInfoData as Data, mimeType: "text/txt", fileName: ConstantsTrace.appInfoFileName)
                            
                            uIViewController.present(mail, animated: true)
                            
                        }, cancelHandler: nil)
                        
                        
                    } else {

                        return .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.emailNotConfigured)
                        
                    }

                } catch {
                    // should never get here ?
                    return .showInfoText(title: Texts_Common.warning, message: "Failed to create attachment")
                    
                }
                
            }
            
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        return false
        
    }
    
}

extension SettingsViewTraceSettingsViewModel: MFMailComposeViewControllerDelegate {
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        
        controller.dismiss(animated: true, completion: nil)
        
        switch result {
            
        case .cancelled:
            break
            
        case .sent, .saved:

            // delete the file as it's been sent successfully
            deleteTraceFile()
            
            // disable tracing, to avoid user forgets turning it off
            UserDefaults.standard.writeTraceToFile = false
            
            // as setting writeTraceToFile has been changed to false, the row with that setting needs to be reloaded
            if let rowReloadClosure = rowReloadClosure {
                rowReloadClosure(Setting.writeTraceToFile.rawValue)
            }

        case .failed:
            if let messageHandler = messageHandler {
                messageHandler(Texts_Common.warning, Texts_SettingsView.failedToSendEmail)
            }
            
        @unknown default:
            break
            
        }
        
    }
    
}
