import Foundation

protocol CGMAidexTransmitterDelegate: AnyObject {

    /// received serial number from the sensor
    func received(serialNumber: String, from cGMAidexTransmitter: CGMAidexTransmitter)

    /// sensor start time updated
    func received(sensorStartTimeMs: Int64, from cGMAidexTransmitter: CGMAidexTransmitter)

    /// wear days reported by sensor
    func received(wearDays: Int, from cGMAidexTransmitter: CGMAidexTransmitter)

    /// battery millivolts
    func received(batteryMillivolts: Int, from cGMAidexTransmitter: CGMAidexTransmitter)

    /// pairing is needed (post-reset)
    func aidexNeedsPairing(from cGMAidexTransmitter: CGMAidexTransmitter)

    /// firmware version from DIS
    func received(firmwareVersion: String, from cGMAidexTransmitter: CGMAidexTransmitter)

    /// model name from DIS
    func received(modelName: String, from cGMAidexTransmitter: CGMAidexTransmitter)

    /// scan-only mode completed: list of discovered sensors (may include expired ones)
    func aidexDidFinishScanning(devices: [DiscoveredAidexSensor], from cGMAidexTransmitter: CGMAidexTransmitter)

    /// called when AidexSensor establishes a connection — used to persist shouldconnect = true
    /// so that setupBLEPeripherals reconnects after app restart/crash.
    func aidexDidConnect(_ sensor: AidexSensor, from cGMAidexTransmitter: CGMAidexTransmitter)

    /// called when AidexSensor disconnects — used to update currentCgmTransmitterAddress
    func aidexDidDisconnect(_ sensor: AidexSensor, from cGMAidexTransmitter: CGMAidexTransmitter)

    /// received a snapshot of the sensor state (age, wear days, etc.)
    func received(snapShot: SensorSnapshot?, from cGMAidexTransmitter: CGMAidexTransmitter)
}