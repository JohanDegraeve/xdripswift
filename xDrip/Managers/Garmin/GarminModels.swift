import Foundation

struct GarminDevice: Equatable, Identifiable {
    let id: UUID
    let name: String
    /// Characteristics have been discovered, not merely a BLE connection established.
    var isConnected: Bool
}

enum GarminTransportError: Error, Equatable {
    case sdkUnavailable, noDeviceSelected, deviceNotConnected, appNotInstalled
    case disabled, cancelled, expired, superseded, invalidReading
    case sendFailed(String)

    var userFacingDescription: String {
        switch self {
        case .sdkUnavailable: return Self.text("SDKUnavailable", "Connect IQ SDK is not available in this build.")
        case .noDeviceSelected: return Self.text("NoDevice", "No Garmin watch is selected.")
        case .deviceNotConnected: return Self.text("NotReady", "The Garmin watch is not ready to receive data.")
        case .appNotInstalled: return Self.text("NoReceiver", "The Garmin receiver is not available on the watch.")
        case .disabled: return Self.text("Disabled", "Garmin sharing is disabled.")
        case .cancelled: return Self.text("Cancelled", "Garmin transfer was cancelled.")
        case .expired: return Self.text("Expired", "Garmin transfer expired. Delivery was not confirmed.")
        case .superseded: return Self.text("Superseded", "A newer Garmin transfer replaced this one.")
        case .invalidReading: return Self.text("InvalidReading", "The reading cannot be sent to Garmin.")
        case .sendFailed(let detail):
            return String(format: Self.text("SendFailed", "Send failed: %@"), detail)
        }
    }

    private static func text(_ key: String, _ value: String) -> String {
        NSLocalizedString("garmin_" + key, tableName: "SettingsViews", bundle: .main, value: value, comment: "Garmin transfer error")
    }
}

/// Validated, immutable v1 packet. The timestamp is never changed to make old data look fresh.
struct GarminGlucoseReading: Equatable {
    let mgDl: Int
    let trend: Int
    let measuredAt: Int
    private(set) var sequence: Int

    init?(mgDl: Double, xDripTrend: Int, measuredAt: Date) {
        let seconds = measuredAt.timeIntervalSince1970
        // Check before converting Double to Int (NaN/infinity/out-of-range values trap).
        // Signed 32-bit integers are portable across Connect IQ devices.
        guard mgDl.isFinite, mgDl >= 1, mgDl <= 1000,
              seconds.isFinite, seconds >= 1, seconds <= Double(Int32.max) else { return nil }
        self.mgDl = Int(mgDl.rounded())
        self.trend = (1...7).contains(xDripTrend) ? 8 - xDripTrend : 0
        self.measuredAt = Int(seconds)
        self.sequence = Int(seconds)
    }

    init?(packet: [String: Int]) {
        guard packet["v"] == 1, packet["s"] == 3,
              let glucose = packet["g"], (1...1000).contains(glucose),
              let trend = packet["t"], (0...7).contains(trend),
              let timestamp = packet["m"], (1...Int(Int32.max)).contains(timestamp),
              let sequence = packet["q"], (timestamp...Int(Int32.max)).contains(sequence) else { return nil }
        self.mgDl = glucose; self.trend = trend; self.measuredAt = timestamp; self.sequence = sequence
    }

    fileprivate func withSequence(_ sequence: Int) -> GarminGlucoseReading {
        var copy = self; copy.sequence = sequence; return copy
    }
}

/// Keep v1 sequences increasing for corrections to the same measurement. The receiver
/// accepts q > previous.q with m >= previous.m. Persist only this latest packet so
/// relaunch/reconnect can replay it without inventing a new measurement timestamp.
struct GarminReadingSequencer {
    private(set) var latest: GarminGlucoseReading?
    init(previous: GarminGlucoseReading? = nil) { latest = previous }

    mutating func prepare(_ reading: GarminGlucoseReading) -> GarminGlucoseReading? {
        if let previous = latest {
            guard reading.measuredAt >= previous.measuredAt else { return nil }
            if reading.measuredAt == previous.measuredAt,
               reading.mgDl == previous.mgDl, reading.trend == previous.trend { return previous }
            guard previous.sequence < Int(Int32.max) else { return nil }
            latest = reading.withSequence(max(reading.measuredAt, previous.sequence + 1))
        } else {
            latest = reading
        }
        return latest
    }
}

struct GarminMessage {
    let reading: GarminGlucoseReading
    func encoded() -> [String: Any] {
        ["v": 1, "g": reading.mgDl, "t": reading.trend,
         "m": reading.measuredAt, "s": 3, "q": reading.sequence]
    }
}

enum ConnectIQAppID {
    static func uuid(from identifier: String) -> UUID? {
        let hex = identifier.replacingOccurrences(of: "-", with: "")
        guard hex.count == 32, hex.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { return nil }
        let characters = Array(hex)
        return UUID(uuidString: [0..<8, 8..<12, 12..<16, 16..<20, 20..<32]
            .map { String(characters[$0]) }.joined(separator: "-"))
    }
}

/// Shared by the real SDK adapter and the standalone lifecycle tests. Main-thread confined.
struct GarminConnectionState {
    private(set) var enabled = false
    private(set) var devices: [GarminDevice] = []
    private(set) var selectedID: UUID?
    var selectedDevice: GarminDevice? { devices.first { $0.id == selectedID } }
    var canSend: Bool { enabled && selectedDevice?.isConnected == true }

    mutating func start() { enabled = true }
    mutating func stop() {
        enabled = false
        for index in devices.indices { devices[index].isConnected = false }
    }
    mutating func replaceDevices(_ found: [GarminDevice], preferredID: UUID?) {
        var seen = Set<UUID>()
        devices = found.filter { seen.insert($0.id).inserted }
        selectedID = devices.contains { $0.id == preferredID } ? preferredID : (devices.count == 1 ? devices.first?.id : nil)
    }
    mutating func select(_ id: UUID?) {
        selectedID = devices.contains { $0.id == id } ? id : nil
    }
    /// Returns true once per readiness transition for the selected watch.
    mutating func setReady(_ ready: Bool, for id: UUID) -> Bool {
        guard enabled, let index = devices.firstIndex(where: { $0.id == id }) else { return false }
        let wasReady = canSend
        devices[index].isConnected = ready
        return !wasReady && canSend
    }
}

enum GarminDestination: Hashable { case bridge, dataField }
enum GarminDeliveryOutcome: Equatable { case sent, skipped }

/// One SDK call at a time, at most one active and one pending reading. A newer pending
/// reading supersedes the previous pending one. Every request has a bounded lifetime.
///
/// The SDK has no cancellation API: a timeout releases our completion/background task,
/// but retains the wire slot until the SDK callback arrives. Reusing that slot early
/// would overlap transfers. Late/duplicate callbacks cannot affect a new session.
/// All entry points, scheduler callbacks and sender completions run on the main thread.
final class GarminDeliveryQueue {
    typealias WireCompletion = (Result<Void, GarminTransportError>) -> Void
    typealias Completion = (Result<GarminDeliveryOutcome, GarminTransportError>) -> Void
    typealias Sender = (GarminDestination, GarminGlucoseReading, @escaping WireCompletion) -> Void
    typealias Schedule = (TimeInterval, @escaping () -> Void) -> (() -> Void)

    private final class Request {
        let id = UUID()
        let reading: GarminGlucoseReading
        let force: Bool
        let deadline: TimeInterval
        let completion: Completion
        var cancelTimer: (() -> Void)?
        var bridgeResult: Result<GarminDeliveryOutcome, GarminTransportError>?
        init(_ reading: GarminGlucoseReading, force: Bool, deadline: TimeInterval, completion: @escaping Completion) {
            self.reading = reading; self.force = force; self.deadline = deadline; self.completion = completion
        }
    }
    private let sender: Sender
    private let schedule: Schedule
    private let timeout: TimeInterval
    private let now: () -> TimeInterval
    private var active: Request?
    private var pending: Request?
    private var wireToken: UUID?
    private var delivered: [GarminDestination: GarminGlucoseReading] = [:]
    var onBridgeResult: ((Result<GarminDeliveryOutcome, GarminTransportError>) -> Void)?

    init(timeout: TimeInterval = 20, now: @escaping () -> TimeInterval = GarminDeliveryQueue.monotonicNow,
         schedule: @escaping Schedule = GarminDeliveryQueue.scheduleOnMain,
         sender: @escaping Sender) {
        self.timeout = timeout; self.now = now; self.schedule = schedule; self.sender = sender
    }

    static func monotonicNow() -> TimeInterval {
        // iOS deployment target is 16.2. ContinuousClock also counts system sleep.
        if #available(iOS 16.0, macOS 13.0, *) { return ContinuousTime.now() }
        return ProcessInfo.processInfo.systemUptime // standalone tests on older macOS
    }

    @available(iOS 16.0, macOS 13.0, *)
    private enum ContinuousTime {
        static let origin = ContinuousClock.now
        static func now() -> TimeInterval {
            let elapsed = origin.duration(to: .now).components
            return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        }
    }

    static func scheduleOnMain(_ seconds: TimeInterval, action: @escaping () -> Void) -> () -> Void {
        let work = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
        return { work.cancel() }
    }

    func cancel(_ reason: GarminTransportError = .cancelled) {
        precondition(Thread.isMainThread)
        let oldActive = active, oldPending = pending
        active = nil; pending = nil
        delivered.removeAll()
        // Detach both before calling client code, which may enqueue another request.
        finish(oldActive, with: .failure(reason))
        finish(oldPending, with: .failure(reason))
    }

    func send(_ reading: GarminGlucoseReading, force: Bool = false, completion: @escaping Completion) {
        precondition(Thread.isMainThread)
        // Never let an out-of-order update evict the newest queued reading.
        if let newest = pending ?? active, reading.sequence < newest.reading.sequence {
            completion(.success(.skipped)); return
        }
        let request = Request(reading, force: force, deadline: now() + timeout, completion: completion)
        let replaced = pending
        pending = request
        request.cancelTimer = schedule(timeout) { [weak self] in self?.expire(request.id) }
        finish(replaced, with: .failure(.superseded))
        pump()
    }

    private func expire(_ id: UUID) {
        precondition(Thread.isMainThread)
        if let request = pending, request.id == id {
            pending = nil
            finish(request, with: .failure(.expired))
        } else if let request = active, request.id == id {
            active = nil
            let result = request.bridgeResult ?? .failure(.expired)
            if request.bridgeResult == nil { onBridgeResult?(result) }
            finish(request, with: result)
        }
        pump()
    }

    private func pump() {
        guard active == nil, wireToken == nil, let request = pending else { return }
        pending = nil; active = request
        deliver(.bridge, request: request)
    }

    private func deliver(_ target: GarminDestination, request: Request) {
        guard active?.id == request.id else { return }
        guard now() < request.deadline else { expire(request.id); return }
        if let previous = delivered[target],
           request.reading.sequence < previous.sequence || (!request.force && request.reading.sequence == previous.sequence) {
            advance(target, request: request, result: .success(.skipped)); return
        }
        let token = UUID()
        wireToken = token
        sender(target, request.reading) { [weak self] result in
            guard let self else { return }
            precondition(Thread.isMainThread)
            guard self.wireToken == token else { return } // duplicate SDK callback
            self.wireToken = nil
            guard self.active?.id == request.id else { self.pump(); return }
            guard self.now() < request.deadline else { self.expire(request.id); return }
            if case .success = result { self.delivered[target] = request.reading }
            self.advance(target, request: request, result: result.map { .sent })
        }
    }

    private func advance(_ target: GarminDestination, request: Request,
                         result: Result<GarminDeliveryOutcome, GarminTransportError>) {
        guard active?.id == request.id else { return }
        if target == .bridge {
            request.bridgeResult = result
            onBridgeResult?(result)
            deliver(.dataField, request: request)
        } else {
            active = nil
            finish(request, with: request.bridgeResult ?? result)
            pump()
        }
    }

    private func finish(_ request: Request?, with result: Result<GarminDeliveryOutcome, GarminTransportError>) {
        guard let request else { return }
        request.cancelTimer?(); request.cancelTimer = nil
        request.completion(result)
    }
}
