import Foundation

/// Owns the opt-in lifecycle and takes immutable snapshots on the main thread.
final class GarminManager {
    static let shared = GarminManager()
    private let transport: GarminTransport
    private var bgReadingsAccessor: BgReadingsAccessor?
    private var started = false
    private static let latestPacketKey = "garminWatch.latestPacket"
    private let defaults: UserDefaults
    private var sequencer: GarminReadingSequencer
    private var defaultsObserver: NSObjectProtocol?
    private var lastUnitIsMgDl: Bool

    init(transport: GarminTransport = GarminTransportFactory.make(), defaults: UserDefaults = .standard) {
        self.transport = transport
        self.defaults = defaults
        self.lastUnitIsMgDl = defaults.bloodGlucoseUnitIsMgDl
        self.sequencer = GarminReadingSequencer(previous:
            (defaults.dictionary(forKey: Self.latestPacketKey) as? [String: Int])
                .flatMap(GarminGlucoseReading.init(packet:)))
        transport.onReady = { [weak self] in self?.sendLatestReading(force: true) }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let unit = self.defaults.bloodGlucoseUnitIsMgDl
            guard unit != self.lastUnitIsMgDl else { return }
            self.lastUnitIsMgDl = unit
            self.sendLatestReading()
        }
    }

    deinit {
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
    }

    var devices: [GarminDevice] { transport.devices }
    var selectedDevice: GarminDevice? { transport.selectedDevice }
    var lastSentAt: Date? { transport.lastSentAt }
    var lastError: GarminTransportError? { transport.lastError }
    var isConnected: Bool { started && selectedDevice?.isConnected == true }
    var statusText: String {
        guard GarminTransportFactory.isAvailable else { return Texts_SettingsView.garminWatchSDKUnavailable }
        guard started else { return Texts_SettingsView.garminWatchDisabled }
        guard selectedDevice != nil else { return Texts_SettingsView.garminWatchNotConfigured }
        return isConnected ? Texts_SettingsView.garminWatchConnected : Texts_SettingsView.garminWatchDisconnected
    }

    func configure(coreDataManager: CoreDataManager) {
        precondition(Thread.isMainThread)
        if bgReadingsAccessor == nil { bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager) }
        if defaults.garminWatchEnabled { start() }
    }

    func setEnabled(_ enabled: Bool) {
        precondition(Thread.isMainThread)
        defaults.garminWatchEnabled = enabled
        if enabled { start() } else { stop() }
    }

    private func start() {
        guard !started, defaults.garminWatchEnabled else { return }
        started = true
        transport.start()
        notifyStateChanged()
    }

    private func stop() {
        guard started else { return }
        started = false
        transport.stop()
        notifyStateChanged()
    }

    func requestDevices() {
        precondition(Thread.isMainThread)
        guard started else { return }
        transport.requestDevices()
    }

    func handleReturn(from url: URL) {
        precondition(Thread.isMainThread)
        guard started else { return }
        transport.handleReturn(from: url)
    }

    func select(_ device: GarminDevice?) {
        precondition(Thread.isMainThread)
        guard started else { return }
        transport.select(device)
    }

    /// Uses the latest final value after upstream post-processing, including follower mode.
    /// force retransmits the original packet; it never fabricates a fresh measurement date.
    func sendLatestReading(force: Bool = false) {
        precondition(Thread.isMainThread)
        lastUnitIsMgDl = defaults.bloodGlucoseUnitIsMgDl
        guard started, defaults.garminWatchEnabled, isConnected,
              let snapshot = bgReadingsAccessor?.lastSnapshot(forSensor: nil),
              let reading = GarminGlucoseReading(mgDl: snapshot.finalValue,
                                                xDripTrend: snapshot.slopeOrdinal(),
                                                measuredAt: snapshot.timeStamp,
                                                displayUnit: lastUnitIsMgDl ? 0 : 1) else { return }
        guard let packet = sequencer.prepare(reading) else { return }
        defaults.set(GarminMessage(reading: packet).encoded(), forKey: Self.latestPacketKey)
        let backgroundWork = GarminBackgroundWork("Send glucose to Garmin")
        guard backgroundWork.begin(onExpiration: { [weak self] in self?.transport.cancelTransfers() }) else { return }
        transport.send(packet, force: force) { [backgroundWork] _ in backgroundWork.end() }
    }

    private func notifyStateChanged() {
        NotificationCenter.default.post(name: .garminWatchStateDidChange, object: nil)
    }
}
