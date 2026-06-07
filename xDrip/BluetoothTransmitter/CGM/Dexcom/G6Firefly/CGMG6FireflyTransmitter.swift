import Foundation
import CoreBluetooth
import OSLog

class CGMG6FireflyTransmitter:BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - public properties
    
    /// CGMG5TransmitterDelegate
    public weak var cGMG6FireflyTransmitterDelegate: CGMG6FireflyTransmitterDelegate?

    // MARK: UUID's
    
    // advertisement
    let CBUUID_Advertisement_G6 = "0000FEBC-0000-1000-8000-00805F9B34FB"
    
    // service
    let CBUUID_Service_G6 = "F8083532-849E-531C-C594-30F1F86A4EA5"
    
    // characteristic uuids (created them in an enum as there's a lot of them, it's easy to switch through the list)
    private enum CBUUID_Characteristic_UUID:String, CustomStringConvertible  {
        
        // Read/Notify characteristic
        case CBUUID_Communication = "F8083533-849E-531C-C594-30F1F86A4EA5"
        
        // Write/Indicate - write characteristic
        case CBUUID_Write_Control = "F8083534-849E-531C-C594-30F1F86A4EA5"
        
        // Read/Write/Indicate - Read Characteristic
        case CBUUID_Receive_Authentication = "F8083535-849E-531C-C594-30F1F86A4EA5"
        
        // Read/Write/Notify
        case CBUUID_Backfill = "F8083536-849E-531C-C594-30F1F86A4EA5"
        
        /// for logging, returns a readable name for the characteristic
        var description: String {
            switch self {
                
            case .CBUUID_Communication:
                return "Communication"
            case .CBUUID_Write_Control:
                return "Write_Control"
            case .CBUUID_Receive_Authentication:
                return "Receive_Authentication"
            case .CBUUID_Backfill:
                return "Backfill"
            }
        }
    }
    
    // MARK: other
    
    //timestamp of last reading
    private var timeStampOfLastG6FireflyReading: Date
    
    //timestamp of transmitterReset
    private var timeStampTransmitterReset:Date
    
    /// transmitterId
    private let transmitterId:String

    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMG6Firefly)
    
    /// is G6 reset necessary or not
    private var G6FireflyResetRequested:Bool

    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?

    /// G6 firefly transmitter firmware version - only used internally, if nil then it was  never received
    ///
    /// created public because inheriting classes need it
    private var firmware:String?
    
    // MARK: - functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID, 6 characters
    ///     - bluetoothTransmitterDelegate : a NluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMG6FireflyTransmitterDelegate : a cGMG6FireflyTransmitterDelegate
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMG6FireflyTransmitterDelegate: CGMG6FireflyTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "DEXCOM" + transmitterID[transmitterID.index(transmitterID.startIndex, offsetBy: 4)..<transmitterID.endIndex])
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // set timeStampOfLastG6FireflyReading to 0
        self.timeStampOfLastG6FireflyReading = Date(timeIntervalSince1970: 0)
        
        //set timeStampTransmitterReset to 0
        self.timeStampTransmitterReset = Date(timeIntervalSince1970: 0)
        
        //assign transmitterId
        self.transmitterId = transmitterID
        
        // initialize G6FireflyResetRequested
        self.G6FireflyResetRequested = false
        
        // initialize - CBUUID_Receive_Authentication.rawValue and CBUUID_Write_Control.rawValue will probably not be used in the superclass
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_G6, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_G6)], CBUUID_ReceiveCharacteristic: CBUUID_Characteristic_UUID.CBUUID_Receive_Authentication.rawValue, CBUUID_WriteCharacteristic: CBUUID_Characteristic_UUID.CBUUID_Write_Control.rawValue, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
        //assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMG6FireflyTransmitterDelegate
        self.cGMG6FireflyTransmitterDelegate = cGMG6FireflyTransmitterDelegate
        
    }
    
    // MARK: - BluetoothTransmitter overriden functions
    
    override func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if Date() < Date(timeInterval: 60, since: timeStampOfLastG6FireflyReading) {
            // will probably never come here because reconnect doesn't happen with scanning, hence diddiscover will never be called excep the very first time that an app tries to connect to a G5
            trace("diddiscover peripheral, but last reading was less than 1 minute ago, will ignore", log: log, category: ConstantsLog.categoryCGMG5, type: .info)
        } else {
            super.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
        }
        
    }
    

    
}
