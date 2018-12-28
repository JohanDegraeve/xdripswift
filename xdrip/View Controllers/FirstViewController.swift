import UIKit
import CoreData
import os
import CoreBluetooth

class FirstViewController: UIViewController, CGMTransmitterDelegate {
    
    // MARK: - Properties
    var test:CGMGMiaoMiaoTransmitter?
    
    var address:String?
    var name:String?

    // TODO : move to other location ?
    private var coreDataManager = CoreDataManager(modelName: "xdrip")

    override func viewDidLoad() {
        super.viewDidLoad()
        //let test:CGMG4xDripTransmitter = CGMG4xDripTransmitter(addressAndName: CGMG4xDripTransmitter.G4DeviceAddressAndName.notYetConnected)
        test = CGMGMiaoMiaoTransmitter(addressAndName: CGMGMiaoMiaoTransmitter.MiaoMiaoDeviceAddressAndName.notYetConnected, delegate:self)
        let log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryBlueTooth)
        os_log("firstview", log: log, type: .info)


        
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
    

}


