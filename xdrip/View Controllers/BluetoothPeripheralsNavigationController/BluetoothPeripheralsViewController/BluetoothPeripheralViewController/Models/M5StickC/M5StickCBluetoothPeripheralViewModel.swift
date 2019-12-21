import Foundation
import UIKit

class M5StickCBluetoothPeripheralViewModel : M5StackBluetoothPeripheralViewModel {
    
    override func m5StackcreenTitle() -> String {
        return Texts_M5StackView.m5StickCViewscreenTitle
    }
    
    override func updateM5Stack(cell: UITableViewCell, withSettingRawValue rawValue: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that rawValue is within range of setting
        guard let setting = Setting(rawValue: rawValue) else { fatalError("M5StackBluetoothPeripheralViewModel update, Unexpected setting")
        }
        
        super.updateM5Stack(cell: cell, withSettingRawValue: rawValue, for: bluetoothPeripheral)
        
        if setting == .brightness {
            
            // M5StickC doesn't support brightness
            cell.accessoryType = .none
            
        } else if setting == .m5StackHelpText {
            
            // specific text for M5StickC in the cell
            cell.textLabel?.text = Texts_M5StackView.m5StickCSoftWhereHelpCellText
            
        }
        
    }
    
    override func userDidSelectM5StackRow(withSettingRawValue rawValue: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging, doneButtonOutlet: UIBarButtonItem) {
        
        // verify that rawValue is within range of setting
        guard let setting = Setting(rawValue: rawValue) else { fatalError("M5StackBluetoothPeripheralViewModel update, Unexpected setting")
        }
        
        if setting == .brightness {
            
            // On M5StickC, user can't change the brightness, so do nothing
            return
            
        }  else if setting == .m5StackHelpText {
            
            let alert = UIAlertController(title: Texts_HomeView.info, message: Texts_M5StackView.m5StackSoftWareHelpText + " " + ConstantsM5Stack.githubURLM5StickC, actionHandler: nil)
            
            bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
            
        } else {
            
            super.userDidSelectM5StackRow(withSettingRawValue: rawValue, for: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, doneButtonOutlet: doneButtonOutlet)
            
        }
        
    }
}
