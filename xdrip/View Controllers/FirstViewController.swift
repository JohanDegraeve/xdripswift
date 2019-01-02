import UIKit
import CoreData
import os
import CoreBluetooth

class FirstViewController: UIViewController, CGMTransmitterDelegate {
    
    // MARK: - Properties
    var test:CGMGMiaoMiaoTransmitter?
    
    var address:String?
    var name:String?
    
    var log:OSLog?

    // TODO : move to other location ?
    private var coreDataManager = CoreDataManager(modelName: "xdrip")

    override func viewDidLoad() {
        super.viewDidLoad()
        //let test:CGMG4xDripTransmitter = CGMG4xDripTransmitter(addressAndName: CGMG4xDripTransmitter.G4DeviceAddressAndName.notYetConnected)
        test = CGMGMiaoMiaoTransmitter(addressAndName: CGMGMiaoMiaoTransmitter.MiaoMiaoDeviceAddressAndName.notYetConnected, delegate:self)
        log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryBlueTooth)
        os_log("firstview", log: log!, type: .info)
    }
    
    func bluetooth(didUpdateState state: CBManagerState) {
        if address == nil {
            _ = test?.startScanning()
        }
    }

    func cgmTransmitterdidConnect() {
        address = test?.address
        name = test?.name
    }
    
    func newSensorDetected() {
        os_log("new sensor detected", log: log!, type: .info)
    }
    
    func sensorNotDetected() {
        os_log("sensor not detected", log: log!, type: .info)
    }
    
    /// readings, first entry is the most recent
    func newReadingsReceived(glucoseData: inout [RawGlucoseData], sensorState: LibreSensorState, firmware: String, hardware: String, batteryPercentage: Int, sensorTimeInMinutes: Int) {
        os_log("sensorstate %@", log: log!, type: .debug, sensorState.description)
        os_log("firmware %@", log: log!, type: .debug, firmware)
        os_log("hardware %@", log: log!, type: .debug, hardware)
        os_log("battery percentage  %d", log: log!, type: .debug, batteryPercentage)
        os_log("sensor time in minutes  %d", log: log!, type: .debug, sensorTimeInMinutes)
        for (index, reading) in glucoseData.enumerated() {
            os_log("Reading %{public}d, raw level = %{public}d,realDate = %{public}s", log: log!, type: .debug, index, reading.glucoseLevelRaw, reading.timeStamp.description)
        }
    }
}


