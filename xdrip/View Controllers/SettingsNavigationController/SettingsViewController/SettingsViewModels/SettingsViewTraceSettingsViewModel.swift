import UIKit
import MessageUI
import os

fileprivate enum Setting:Int, CaseIterable {
    
    /// to send trace file
    case sendTraceFile = 0
    
    /// should debug level logs be stored in trace file yes or no
    case debugLevel = 1
    
}

class SettingsViewTraceSettingsViewModel: NSObject {
    
    /// need to present MFMailComposeViewController
    private var uIViewController: UIViewController?
    
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
    
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {
        self.uIViewController = uIViewController
    }

    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {
        self.messageHandler = messageHandler
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.traceSettingsIcon + " " + Texts_SettingsView.sectionTitleTrace
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .sendTraceFile:
            return Texts_SettingsView.sendTraceFile
            
        case .debugLevel:
            return Texts_SettingsView.debugLevel
            
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .sendTraceFile:
            return .disclosureIndicator
            
        case .debugLevel:
            return .none
            
        }
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .sendTraceFile:
            return nil
            
        case .debugLevel:
            return nil
            
        }
        
    }
    
    func uiView(index: Int) -> UIView? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .sendTraceFile:
            return nil
            
        case .debugLevel:
            return UISwitch(isOn: UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog, action: {(isOn:Bool) in UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog = isOn})
            
        }
        
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .sendTraceFile:

            guard let uIViewController = uIViewController else {fatalError("in SettingsViewTraceSettingsViewModel, onRowSelect, uIViewController is nil")}
            
                // check if iOS device can send email, this depends of an email account is configured
                if MFMailComposeViewController.canSendMail() {
                    
                    return .askConfirmation(title: Texts_HomeView.info, message: Texts_SettingsView.describeProblem, actionHandler: {
                        
                        let mail = MFMailComposeViewController()
                        mail.mailComposeDelegate = self
                        mail.setToRecipients([ConstantsTrace.traceFileDestinationAddress])
                        mail.setMessageBody(Texts_SettingsView.emailbodyText, isHTML: true)
                        
                        // add all trace files as attachment
                        let traceFilesInData = Trace.getTraceFilesInData()
                        for (index, traceFileInData) in traceFilesInData.0.enumerated() {
                            mail.addAttachmentData(traceFileInData as Data, mimeType: "text/txt", fileName: traceFilesInData.1[index])
                        }
                        
                        if let appInfoAsData = Trace.getAppInfoFileAsData().0 {
                            mail.addAttachmentData(appInfoAsData as Data, mimeType: "text/txt", fileName: Trace.getAppInfoFileAsData().1)
                        }
                        
                        uIViewController.present(mail, animated: true)
                        
                    }, cancelHandler: nil)
                    
                    
                } else {
                    
                    return .showInfoText(title: Texts_Common.warning, message: Texts_SettingsView.emailNotConfigured)
                    
                }
            
        case .debugLevel:
            return .nothing
            
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
            break
            
        case .failed:
            if let messageHandler = messageHandler {
                messageHandler(Texts_Common.warning, Texts_SettingsView.failedToSendEmail)
            }
            
        @unknown default:
            break
            
        }
        
    }
    
}
