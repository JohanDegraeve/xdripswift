import Foundation

protocol GarminTransport: AnyObject {
    var devices: [GarminDevice] { get }
    var selectedDevice: GarminDevice? { get }
    var lastSentAt: Date? { get }
    var lastError: GarminTransportError? { get }
    var onReady: (() -> Void)? { get set }
    func start()
    func stop()
    func cancelTransfers()
    func requestDevices()
    func handleReturn(from url: URL)
    func select(_ device: GarminDevice?)
    func send(_ reading: GarminGlucoseReading, force: Bool, completion: @escaping GarminDeliveryQueue.Completion)
}

class UnavailableGarminTransport: GarminTransport {
    var devices: [GarminDevice] { [] }
    var selectedDevice: GarminDevice? { nil }
    var lastSentAt: Date? { nil }
    var lastError: GarminTransportError? { .sdkUnavailable }
    var onReady: (() -> Void)?
    func start() {}
    func stop() {}
    func cancelTransfers() {}
    func requestDevices() {}
    func handleReturn(from url: URL) {}
    func select(_ device: GarminDevice?) {}
    func send(_ reading: GarminGlucoseReading, force: Bool, completion: @escaping GarminDeliveryQueue.Completion) {
        completion(.failure(.sdkUnavailable))
    }
}

enum GarminTransportFactory {
    static func make() -> GarminTransport { ConnectIQTransport() }
    static var isAvailable: Bool {
        #if canImport(ConnectIQ)
        return true
        #else
        return false
        #endif
    }
}
