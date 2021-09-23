import Foundation
import UIKit

fileprivate enum Setting:Int, CaseIterable {
    
    /// Export
    case exportBtn = 0
    
}

struct SettingsExportSettingsViewModel:SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // this ViewModel does need to send back messages to the viewcontroller asynchronously
    }
    
    func sectionTitle() -> String? {
        return Texts_ExportView.screenTitle
    }
    
    func settingsRowText(index: Int) -> String {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .exportBtn:
            return Texts_ExportView.exportBtn
            
        }
        
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }

        switch setting {
            
        case .exportBtn:
            return .disclosureIndicator
        }
        
    }
    
    func detailedText(index: Int) -> String? {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .exportBtn:
            return nil
        }
        
    }
    
    func uiView(index: Int) -> UIView? {
        return nil
    }
    
    func numberOfRows() -> Int {
        return Setting.allCases.count
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .exportBtn:
            guard let dataURL = exportAllBgReadings() else { return .nothing }
            let activityVC = UIActivityViewController(activityItems: [dataURL], applicationActivities: nil)
            UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
            return .nothing
            
        }
    }
    
    func isEnabled(index: Int) -> Bool {
        
        return true
        
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        
        return false
        
    }

    func exportAllBgReadings () -> URL? {
        let viewController = UIApplication.shared.keyWindow?.rootViewController as! UITabBarController
        let rootViewController = viewController.viewControllers?.first as! RootViewController
        return rootViewController.exportAllReadings()
    }
}

