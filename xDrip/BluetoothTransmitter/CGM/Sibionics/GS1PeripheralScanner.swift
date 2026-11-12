import CoreBluetooth
import Foundation

enum GS1SetupError: Error { case alreadyConfigured }

/// Setup helpers deliberately do not infer the regional algorithm from BLE names.
enum GS1Setup {
    static func normalizedCode(_ value: String) -> String? {
        let code = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.utf8.count == 8, code.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) }),
              !code.hasPrefix("P"), !code.hasPrefix("XPT"), GS1Sensitivity.decode(code) != nil else { return nil }
        return code
    }
    static func matches(name: String?, code: String) -> Bool {
        guard let code = normalizedCode(code), let name else { return false }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean == code || (clean.count == 11 && clean.hasPrefix(code)) { return true }
        let bytes = Array(clean.utf8)
        return bytes.count == 10 && clean.hasPrefix("LT") && bytes[2..<6].allSatisfy({ (48...57).contains($0) }) && clean.suffix(4) == code.prefix(4)
    }
    /// Factory GS1/SISENSING returns six little-endian address bytes. Verified
    /// independently against HCI on GS1 hardware V1.2 / firmware 01.02.06.
    /// Keep the separately verified 17-byte ASCII format in normal order.
    static func readOnlyMAC(_ data: Data, model: String? = nil, manufacturer: String? = nil) -> GS1MAC? {
        if data.count == 6 {
            guard normalizedInformation(model) == "GS1",
                  normalizedInformation(manufacturer) == "SISENSING",
                  let high = data.last, high & 0xc0 == 0xc0 else { return nil }
            guard !(high & 0x3f == 0 && data.prefix(5).allSatisfy({ $0 == 0 })) else { return nil }
            return try? GS1MAC(data.reversed().map { String(format: "%02X", $0) }.joined(separator: ":"))
        }
        guard data.count == 17, data.allSatisfy({ $0 < 128 }), let string = String(data: data, encoding: .ascii) else { return nil }
        let bytes = Array(data)
        guard [2,5,8,11,14].allSatisfy({ bytes[$0] == 58 }) else { return nil }
        return try? GS1MAC(string)
    }
    static func deviceInformationMAC(_ fields: [String: Data]) -> GS1MAC? {
        guard let serial = fields["2A25"] else { return nil }
        return readOnlyMAC(serial,
            model: fields["2A24"].flatMap { String(data: $0, encoding: .utf8) },
            manufacturer: fields["2A29"].flatMap { String(data: $0, encoding: .utf8) })
    }
    private static func normalizedInformation(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0"))).uppercased()
    }
}

/// Foreground setup only. Scans without connecting. A separate explicit selection
/// may read Device Information; it never subscribes to FF31 or writes to FF32.
final class GS1PeripheralScanner: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    struct Candidate {
        let id: UUID
        let name: String
        let rssi: Int
        fileprivate let peripheral: CBPeripheral
    }
    private var central: CBCentralManager!
    private var code = ""
    private var candidates: [UUID: Candidate] = [:]
    private var scanCompletion: (([Candidate], String?) -> Void)?
    private var probeCompletion: ((GS1MAC?) -> Void)?
    private var probeValues: [String: Data] = [:]
    private var pendingProbeFields = Set<String>()
    private var selected: CBPeripheral?
    private var deadline: DispatchWorkItem?
    private var stopped = false
    init(code: String, completion: @escaping ([Candidate], String?) -> Void) {
        self.code = code; scanCompletion = completion
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }
    func stop() {
        stopped = true; deadline?.cancel(); scanCompletion = nil; probeCompletion = nil
        probeValues.removeAll(); pendingProbeFields.removeAll()
        central?.stopScan()
        if let selected { selected.delegate = nil; central?.cancelPeripheralConnection(selected) }
        selected = nil
    }
    deinit { deadline?.cancel() }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard !stopped else { return }
        guard central.state == .poweredOn else {
            if central.state != .unknown && central.state != .resetting { finishScan(error: "Bluetooth is unavailable") }
            return
        }
        guard scanCompletion != nil else { return }
        central.scanForPeripherals(withServices: [CBUUID(string: GS1ChineseProtocol.serviceUUID)])
        armTimeout(seconds: 12) { [weak self] in self?.finishScan(error: nil) }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        guard scanCompletion != nil, GS1Setup.matches(name: name, code: code), let name else { return }
        candidates[peripheral.identifier] = Candidate(id: peripheral.identifier, name: name, rssi: RSSI.intValue, peripheral: peripheral)
    }
    private func finishScan(error: String?) {
        deadline?.cancel(); central.stopScan()
        let callback = scanCompletion; scanCompletion = nil
        callback?(candidates.values.sorted { $0.rssi > $1.rssi }, error)
    }
    func readMAC(from candidate: Candidate, completion: @escaping (GS1MAC?) -> Void) {
        guard !stopped, central.state == .poweredOn else { completion(nil); return }
        central.stopScan(); scanCompletion = nil
        probeValues.removeAll(); pendingProbeFields.removeAll()
        selected = candidate.peripheral; selected?.delegate = self; probeCompletion = completion
        central.connect(candidate.peripheral)
        armTimeout(seconds: 10) { [weak self] in self?.finishProbe(nil) }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == selected?.identifier, probeCompletion != nil else { central.cancelPeripheralConnection(peripheral); return }
        peripheral.discoverServices([CBUUID(string: "180A")])
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral.identifier == selected?.identifier, probeCompletion != nil else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == CBUUID(string: "180A") }) else { finishProbe(nil); return }
        peripheral.discoverCharacteristics([CBUUID(string: "2A24"), CBUUID(string: "2A25"), CBUUID(string: "2A29")], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral.identifier == selected?.identifier, service.uuid == CBUUID(string: "180A"), probeCompletion != nil else { return }
        let fields = (service.characteristics ?? []).filter { ["2A24", "2A25", "2A29"].contains($0.uuid.uuidString) && $0.properties.contains(.read) }
        guard error == nil, fields.contains(where: { $0.uuid == CBUUID(string: "2A25") }) else { finishProbe(nil); return }
        pendingProbeFields = Set(fields.map { $0.uuid.uuidString })
        for value in fields { peripheral.readValue(for: value) }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let key = characteristic.uuid.uuidString
        guard peripheral.identifier == selected?.identifier, characteristic.service?.uuid == CBUUID(string: "180A"),
              probeCompletion != nil, pendingProbeFields.remove(key) != nil else { return }
        if error == nil, let value = characteristic.value { probeValues[key] = value }
        if let mac = GS1Setup.deviceInformationMAC(probeValues) { finishProbe(mac) }
        else if pendingProbeFields.isEmpty { finishProbe(nil) }
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if peripheral.identifier == selected?.identifier { finishProbe(nil) }
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if peripheral.identifier == selected?.identifier { finishProbe(nil) }
    }
    private func finishProbe(_ mac: GS1MAC?) {
        deadline?.cancel()
        let callback = probeCompletion; probeCompletion = nil
        probeValues.removeAll(); pendingProbeFields.removeAll()
        if let selected { selected.delegate = nil; central.cancelPeripheralConnection(selected) }
        selected = nil
        callback?(mac)
    }
    private func armTimeout(seconds: Double, action: @escaping () -> Void) {
        deadline?.cancel(); let task = DispatchWorkItem(block: action); deadline = task
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
    }
}
