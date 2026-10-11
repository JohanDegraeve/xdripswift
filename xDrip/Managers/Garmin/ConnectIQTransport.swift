import Foundation

#if canImport(ConnectIQ)
import ConnectIQ

/// Main-thread SDK adapter. Connect IQ callbacks are marshalled onto the same queue.
final class ConnectIQTransport: NSObject, GarminTransport {
    static let watchAppID = "a1b2c3d4e5f647589a0b1c2d3e4f5061"
    static let dataFieldAppID = "7ca56fd800634cab90f28d5e72be2e05"
    static let returnURLScheme = "xdrip-garmin"
    private static let selectedDeviceKey = "garminWatch.selectedDeviceUUID"
    private static let knownDevicesKey = "garminWatch.knownDevices"

    private var state = GarminConnectionState()
    private var knownDevices: [UUID: IQDevice] = [:]
    private var generation = 0
    private var initialized = false
    private var registration = UUID()
    private var deviceEvents: GarminDeviceEvents?
    var devices: [GarminDevice] { state.devices }
    var selectedDevice: GarminDevice? { state.selectedDevice }
    private(set) var lastSentAt: Date?
    private(set) var lastError: GarminTransportError?
    var onReady: (() -> Void)?

    private lazy var delivery: GarminDeliveryQueue = {
        let queue = GarminDeliveryQueue { [weak self] target, reading, completion in
            guard let self else { completion(.failure(.cancelled)); return }
            self.transmit(reading, to: target, completion: completion)
        }
        queue.onBridgeResult = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(.sent): self.lastSentAt = Date(); self.lastError = nil
            case .success(.skipped): break
            case .failure(let error): self.lastError = error
            }
            self.notifyStateChanged()
        }
        return queue
    }()

    func start() {
        precondition(Thread.isMainThread)
        guard !state.enabled else { return }
        state.start()
        if !initialized {
            initialized = true
            ConnectIQ.sharedInstance().initialize(
                withUrlScheme: Self.returnURLScheme,
                uiOverrideDelegate: nil,
                stateRestorationIdentifier: (Bundle.main.bundleIdentifier ?? "xdripswift") + ".garmin.connectiq"
            )
        }
        let stored = UserDefaults.standard.array(forKey: Self.knownDevicesKey) as? [[String: String]] ?? []
        let restored = stored.compactMap { entry -> IQDevice? in
            guard let uuidString = entry["uuid"], let uuid = UUID(uuidString: uuidString) else { return nil }
            return IQDevice(id: uuid, modelName: entry["model"] ?? "", friendlyName: entry["name"] ?? "Garmin")
        }
        replaceDevices(restored)
    }

    func stop() {
        precondition(Thread.isMainThread)
        state.stop()
        invalidateSession()
        unregisterDevices()
        notifyStateChanged()
    }

    func cancelTransfers() {
        precondition(Thread.isMainThread)
        delivery.cancel(.expired)
        lastError = .expired
        notifyStateChanged()
    }

    func requestDevices() {
        precondition(Thread.isMainThread)
        guard state.enabled else { return }
        ConnectIQ.sharedInstance().showDeviceSelection()
    }

    func handleReturn(from url: URL) {
        precondition(Thread.isMainThread)
        guard state.enabled, url.scheme == Self.returnURLScheme,
              let returned = ConnectIQ.sharedInstance().parseDeviceSelectionResponse(from: url) as? [IQDevice] else { return }
        // Garmin's response is the full authorization list, including revocations.
        replaceDevices(returned)
    }

    func select(_ device: GarminDevice?) {
        precondition(Thread.isMainThread)
        guard state.enabled, state.selectedID != device?.id else { return }
        invalidateSession()
        state.select(device?.id)
        persistSelection()
        notifyStateChanged()
        notifyReady()
    }

    func send(_ reading: GarminGlucoseReading, force: Bool, completion: @escaping GarminDeliveryQueue.Completion) {
        precondition(Thread.isMainThread)
        guard state.enabled else { completion(.failure(.disabled)); return }
        guard selectedDevice != nil else { completion(.failure(.noDeviceSelected)); return }
        guard state.canSend else { completion(.failure(.deviceNotConnected)); return }
        let current = generation
        delivery.send(reading, force: force) { [weak self] result in
            if let self, self.generation == current,
               case .failure(let error) = result, error != .superseded, error != .cancelled {
                self.lastError = error
                self.notifyStateChanged()
            }
            completion(result)
        }
    }

    private func transmit(_ reading: GarminGlucoseReading, to target: GarminDestination,
                          completion: @escaping GarminDeliveryQueue.WireCompletion) {
        guard state.canSend, let id = state.selectedID, let device = knownDevices[id],
              ConnectIQ.sharedInstance().getDeviceStatus(device) == .connected else {
            completion(.failure(.deviceNotConnected)); return
        }
        let identifier = target == .bridge ? Self.watchAppID : Self.dataFieldAppID
        guard let uuid = ConnectIQAppID.uuid(from: identifier),
              let app = IQApp(uuid: uuid, store: nil, device: device) else {
            completion(.failure(.appNotInstalled)); return
        }
        ConnectIQ.sharedInstance().sendMessage(GarminMessage(reading: reading).encoded(), to: app, progress: nil) { result in
            DispatchQueue.main.async {
                completion(result == .success ? .success(()) : .failure(.sendFailed(Self.describe(result))))
            }
        }
    }

    private func unregisterDevices() {
        registration = UUID()
        if let deviceEvents {
            for device in knownDevices.values {
                ConnectIQ.sharedInstance().unregister(forDeviceEvents: device, delegate: deviceEvents)
            }
        }
        deviceEvents = nil
        knownDevices.removeAll()
    }

    private func replaceDevices(_ found: [IQDevice]) {
        invalidateSession()
        unregisterDevices()
        for device in found { knownDevices[device.uuid] = device }
        let preferred = UserDefaults.standard.string(forKey: Self.selectedDeviceKey).flatMap(UUID.init(uuidString:))
        state.replaceDevices(knownDevices.values.map {
            GarminDevice(id: $0.uuid, name: $0.friendlyName ?? $0.modelName ?? "Garmin", isConnected: false)
        }.sorted { $0.name == $1.name ? $0.id.uuidString < $1.id.uuidString : $0.name < $1.name }, preferredID: preferred)
        persistSelection()
        UserDefaults.standard.set(knownDevices.values.map {
            ["uuid": $0.uuid.uuidString, "model": $0.modelName ?? "", "name": $0.friendlyName ?? "Garmin"]
        }, forKey: Self.knownDevicesKey)
        let token = registration
        let events = GarminDeviceEvents { [weak self] device, ready in
            guard let self, self.state.enabled, self.registration == token,
                  self.knownDevices[device.uuid] != nil else { return }
            if ready {
                guard ConnectIQ.sharedInstance().getDeviceStatus(device) == .connected else { return }
                if self.state.setReady(true, for: device.uuid) { self.notifyReady() }
            } else {
                _ = self.state.setReady(false, for: device.uuid)
                if self.state.selectedID == device.uuid { self.invalidateSession() }
            }
            self.notifyStateChanged()
        }
        deviceEvents = events
        for device in knownDevices.values {
            ConnectIQ.sharedInstance().register(forDeviceEvents: device, delegate: events)
        }
        notifyStateChanged()
    }

    private func persistSelection() {
        UserDefaults.standard.set(state.selectedID?.uuidString, forKey: Self.selectedDeviceKey)
    }

    private func invalidateSession() {
        generation += 1
        delivery.cancel()
        lastSentAt = nil; lastError = nil
    }

    private func notifyReady() {
        guard state.canSend else { return }
        let current = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == current, self.state.canSend else { return }
            self.onReady?()
        }
    }

    private func notifyStateChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .garminWatchStateDidChange, object: nil)
        }
    }

    static func describe(_ result: IQSendMessageResult) -> String {
        // Stable SDK diagnostics; no glucose values, device IDs or names in logs.
        switch result {
        case .success: return "sent"
        case .failure_Unknown: return "unknown error"
        case .failure_InternalError: return "internal SDK error"
        case .failure_DeviceNotAvailable: return "watch not available"
        case .failure_AppNotFound: return "receiver app not found on watch"
        case .failure_DeviceIsBusy: return "watch is busy"
        case .failure_UnsupportedType: return "unsupported message type"
        case .failure_InsufficientMemory: return "watch is out of memory"
        case .failure_Timeout: return "timed out"
        case .failure_MaxRetries: return "maximum retries reached"
        case .failure_PromptNotDisplayed: return "watch ignored the message"
        case .failure_AppAlreadyRunning: return "receiver app already running"
        @unknown default: return "Connect IQ result \(result.rawValue)"
        }
    }
}

/// Each registration owns a new delegate so delayed events from revoked devices cannot
/// affect a later registration, even when both use the same UUID. SDK object identity
/// is not part of Garmin's public contract.
private final class GarminDeviceEvents: NSObject, IQDeviceEventDelegate {
    private let changed: (IQDevice, Bool) -> Void
    init(changed: @escaping (IQDevice, Bool) -> Void) { self.changed = changed }

    func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
        // Connected is insufficient; wait for deviceCharacteristicsDiscovered.
        guard status != .connected else { return }
        DispatchQueue.main.async { [changed] in changed(device, false) }
    }

    func deviceCharacteristicsDiscovered(_ device: IQDevice) {
        DispatchQueue.main.async { [changed] in changed(device, true) }
    }
}
#else
final class ConnectIQTransport: UnavailableGarminTransport {
    static let returnURLScheme = "xdrip-garmin"
}
#endif

extension Notification.Name {
    static let garminWatchStateDidChange = Notification.Name("garminWatchStateDidChange")
}
