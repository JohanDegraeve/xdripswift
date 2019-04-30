import UIKit

struct SettingsViewAlarmsSettingsViewModel:SettingsViewModelProtocol {
    func onRowSelect(index: Int) -> SelectedRowAction {
        return .nothing
    }
    
    func getUIViewController(index: Int) -> UIViewController? {
        return nil
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsViews.sectionTitleAlerts
    }
    
    func numberOfRows() -> Int {
        return 1
    }
    
    func uiView(index: Int) -> (view: UIView?, reloadSection: Bool) {
        return (nil, false)
    }
    
    func text(index: Int) -> String {
        return "under construction"
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        return UITableViewCell.AccessoryType.none
    }
    
    func detailedText(index: Int) -> String? {
        return nil
    }
}
