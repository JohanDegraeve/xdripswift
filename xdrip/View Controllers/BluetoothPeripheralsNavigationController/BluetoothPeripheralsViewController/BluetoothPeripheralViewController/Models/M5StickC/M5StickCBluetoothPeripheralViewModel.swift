import Foundation
import UIKit

class M5StickCBluetoothPeripheralViewModel : M5StackBluetoothPeripheralViewModel {
    
    override func m5StackcreenTitle() -> String {
        return Texts_M5StackView.m5StickCViewscreenTitle
    }
    
    override func updateM5Stack(cell: UITableViewCell, withSettingRawValue rawValue: Int, for bluetoothPeripheral: BluetoothPeripheral, doneButtonOutlet: UIBarButtonItem) {
        
        // verify that rawValue is within range of setting
        guard let setting = Setting(rawValue: rawValue) else { fatalError("M5StackBluetoothPeripheralViewModel update, Unexpected setting")
        }
        
        super.updateM5Stack(cell: cell, withSettingRawValue: rawValue, for: bluetoothPeripheral, doneButtonOutlet: doneButtonOutlet)
        
        switch setting {
            
        case .m5StackHelpText:
            // specific text for M5StickC in the cell
            cell.textLabel?.text = Texts_M5StackView.m5StickCSoftWhereHelpCellText
            
        case .batteryLevel:
            
            // No battery level available on M5StickC
            cell.accessoryType = .none
            cell.detailTextLabel?.text = nil
            
            // inactive setting, set color
            cell.textLabel?.textColor = ConstantsUI.colorInActiveSetting

        case .brightness:
            
            // M5StickC doesn't support brightness
            cell.accessoryType = .none
            cell.detailTextLabel?.text = nil
            
            // inactive setting, set color
            cell.textLabel?.textColor = ConstantsUI.colorInActiveSetting
            
        case .powerOff:
            
            // No power off functionality on M5StickC
            cell.accessoryType = .none
            cell.detailTextLabel?.text = nil
            
            // inactive setting, set color
            cell.textLabel?.textColor = ConstantsUI.colorInActiveSetting

        case .blePassword, .textColor, .backGroundColor, .rotation, .connectToWiFi:
            cell.textLabel?.textColor = ConstantsUI.colorActiveSetting
            
        }
        
    }
    
    override func userDidSelectM5StackRow(withSettingRawValue rawValue: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging, doneButtonOutlet: UIBarButtonItem) {
        
        // verify that rawValue is within range of setting
        guard let setting = Setting(rawValue: rawValue) else {
            fatalError("M5StackBluetoothPeripheralViewModel update, Unexpected setting")
        }
        
        switch setting {
            
        case .m5StackHelpText:
            
            let alert = UIAlertController(title: Texts_HomeView.info, message: Texts_M5StackView.m5StackSoftWareHelpText + " " + ConstantsM5Stack.githubURLM5StickC, actionHandler: nil)
            
            bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)

        case .batteryLevel:
            // No battery level available on M5StickC
            break
            
        case .brightness:
            // On M5StickC, user can't change the brightness, so do nothing
            break
            
        case .powerOff:
            // No power off functionality on M5StickC
            break

        case .blePassword, .textColor, .backGroundColor, .rotation:
            
            super.userDidSelectM5StackRow(withSettingRawValue: rawValue, for: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, doneButtonOutlet: doneButtonOutlet)

        case .connectToWiFi:
            break
            
        }
        
    }
}
