import Foundation
import UIKit

class M5StickCBluetoothPeripheralViewModel : M5StackBluetoothPeripheralViewModel {
    
    override func m5StackcreenTitle() -> String {
        return Texts_M5StackView.m5StickCViewscreenTitle
    }
    
    override func updateM5Stack(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        super.updateM5Stack(cell: cell, forRow: rawValue, forSection: section, for: bluetoothPeripheral)
        
        // verify that rawValue is within range of setting
        guard let setting = CommonM5Setting(rawValue: rawValue) else { fatalError("M5StackBluetoothPeripheralViewModel update, Unexpected setting")
        }
        
        switch setting {
            
        case .m5StackHelpText:
            // specific text for M5StickC in the cell
            cell.textLabel?.text = Texts_M5StackView.m5StickCSoftWhereHelpCellText
            
        case .blePassword, .textColor, .backGroundColor, .rotation, .connectToWiFi:
            break
            
        }
        
    }
    
    override func userDidSelectM5StackRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        
        // M5Stick C doesn't suppor the M5Stack specific settings, so if section > number of sections - 1 then return (should normally never arrive here with such value)
        guard section < super.numberOfM5Sections() else {return .nothing}
        
        // verify that rawValue is within range of setting
        guard let setting = CommonM5Setting(rawValue: rawValue) else {
            fatalError("M5StackBluetoothPeripheralViewModel update, Unexpected setting")
        }
        
        switch setting {
            
        case .m5StackHelpText:
            
            return .showInfoText(title: Texts_HomeView.info, message: Texts_M5StackView.m5StackSoftWareHelpText + " " + ConstantsM5Stack.githubURLM5StickC)

        case .blePassword, .textColor, .backGroundColor, .rotation, .connectToWiFi :
            
            return super.userDidSelectM5StackRow(withSettingRawValue: rawValue, forSection: section, for: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager)

        }
        
    }
    
    /// - this function is defined to allow override by M5StickC specific model class, because the number of sections is different for M5StickC
    override public func numberOfM5Sections() -> Int {
        return super.numberOfM5Sections() - 1
    }

}
