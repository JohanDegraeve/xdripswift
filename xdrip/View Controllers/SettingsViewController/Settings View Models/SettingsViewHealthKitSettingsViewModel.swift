import UIKit

class SettingsViewHealthKitSettingsViewModel:SettingsViewModelProtocol {
    
    func onRowSelect(index: Int) -> SelectedRowAction {
        return SelectedRowAction.nothing
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsViews.sectionTitleHealthKit
    }

    func numberOfRows() -> Int {
        return 1
    }

    func text(index: Int) -> String {
        return Texts_SettingsViews.healthKit
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        return UITableViewCell.AccessoryType.none
    }
    
    func detailedText(index: Int) -> String? {
        return nil
    }
    
    func uiView(index:Int) -> (view: UIView?, reloadSection: Bool) {
        let uiSwitch:UISwitch = UISwitch(frame: CGRect.zero)
        uiSwitch.setOn(UserDefaults.standard.storeReadingsInHealthkit, animated: true)
        uiSwitch.addTarget(self, action: {(theSwitch:UISwitch) in UserDefaults.standard.storeReadingsInHealthkit = theSwitch.isOn}, for: UIControl.Event.valueChanged)
        return (uiSwitch, false)
    }
}


