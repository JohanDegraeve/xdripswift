import Foundation

var passed = 0
func test(_ name: String, _ body: () -> Void) {
    body(); passed += 1; print("PASS \(name)")
}
func check(_ condition: @autoclosure () -> Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if !condition() { fatalError("\(message)", file: file, line: line) }
}
func reading(_ sequence: Int = 1_700_000_000, glucose: Double = 123) -> GarminGlucoseReading {
    GarminGlucoseReading(mgDl: glucose, xDripTrend: 2, measuredAt: Date(timeIntervalSince1970: Double(sequence)))!
}
let idA = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
let idB = UUID(uuidString: "11111111-2222-3333-4444-666666666666")!
let watchA = GarminDevice(id: idA, name: "A", isConnected: false)
let watchB = GarminDevice(id: idB, name: "B", isConnected: false)

final class Clock {
    struct Task { let id: UUID; let due: TimeInterval; let action: () -> Void }
    var now: TimeInterval = 0
    var tasks: [Task] = []
    func schedule(_ seconds: TimeInterval, _ action: @escaping () -> Void) -> () -> Void {
        let id = UUID()
        tasks.append(Task(id: id, due: now + seconds, action: action))
        return { [weak self] in self?.tasks.removeAll { $0.id == id } }
    }
    func advance(_ seconds: TimeInterval) {
        now += seconds
        while let next = tasks.filter({ $0.due <= now }).min(by: { $0.due < $1.due }) {
            tasks.removeAll { $0.id == next.id }; next.action()
        }
    }
}
final class Harness {
    struct Call {
        let target: GarminDestination
        let reading: GarminGlucoseReading
        let completion: GarminDeliveryQueue.WireCompletion
    }
    let clock = Clock()
    var calls: [Call] = []
    var bridgeResults: [Result<GarminDeliveryOutcome, GarminTransportError>] = []
    lazy var queue: GarminDeliveryQueue = {
        let queue = GarminDeliveryQueue(now: { [unowned self] in clock.now }, schedule: clock.schedule) { [unowned self] target, value, done in
            calls.append(Call(target: target, reading: value, completion: done))
        }
        queue.onBridgeResult = { [unowned self] in bridgeResults.append($0) }
        return queue
    }()
    func complete(_ index: Int, _ result: Result<Void, GarminTransportError> = .success(())) { calls[index].completion(result) }
}

// Packet validation and compatibility with the existing Mmolio receiver.
test("v1 packet is mg/dL with opposite trend and original timestamp") {
    let value = GarminGlucoseReading(mgDl: 123.6, xDripTrend: 1, measuredAt: Date(timeIntervalSince1970: 1_700_000_000.9))!
    check(GarminMessage(reading: value).encoded() as? [String: Int] == ["v": 1, "g": 124, "t": 7, "m": 1_700_000_000, "s": 3, "q": 1_700_000_000])
}
test("all seven trend directions and unknown trend") {
    for trend in -2...10 {
        let value = GarminGlucoseReading(mgDl: 100, xDripTrend: trend, measuredAt: Date(timeIntervalSince1970: 100))!
        check(value.trend == ((1...7).contains(trend) ? 8 - trend : 0))
    }
}
test("malformed glucose cannot trap integer conversion") {
    for invalid in [Double.nan, .infinity, -.infinity, -1, 0, 0.5, 1001, Double.greatestFiniteMagnitude] {
        check(GarminGlucoseReading(mgDl: invalid, xDripTrend: 4, measuredAt: Date()) == nil)
    }
}
test("invalid timestamps and protocol integer boundaries") {
    for invalid in [Double.nan, .infinity, -.infinity, -1, 0, Double(Int32.max) + 1] {
        check(GarminGlucoseReading(mgDl: 100, xDripTrend: 4, measuredAt: Date(timeIntervalSince1970: invalid)) == nil)
    }
    check(GarminGlucoseReading(mgDl: 1000, xDripTrend: 4, measuredAt: Date(timeIntervalSince1970: Double(Int32.max))) != nil)
}
test("Connect IQ IDs parse only ASCII hex and retain original identities") {
    check(ConnectIQAppID.uuid(from: "a1b2c3d4e5f647589a0b1c2d3e4f5061")?.uuidString.lowercased() == "a1b2c3d4-e5f6-4758-9a0b-1c2d3e4f5061")
    check(ConnectIQAppID.uuid(from: "7ca56fd800634cab90f28d5e72be2e05") != nil)
    check(ConnectIQAppID.uuid(from: "bogus") == nil)
    check(ConnectIQAppID.uuid(from: String(repeating: "ａ", count: 32)) == nil)
}

// The same connection state used by ConnectIQTransport.
test("sharing is initially off; connected alone cannot send") {
    var state = GarminConnectionState()
    state.replaceDevices([watchA], preferredID: nil)
    check(!state.canSend)
    state.start()
    check(!state.canSend)
    check(state.setReady(true, for: idA)); check(state.canSend)
}
test("authorization replacement switches A to B and removes revoked A") {
    var state = GarminConnectionState(); state.start()
    state.replaceDevices([watchA], preferredID: nil)
    _ = state.setReady(true, for: idA)
    state.replaceDevices([watchB], preferredID: idA)
    check(state.devices == [watchB]); check(state.selectedID == idB); check(!state.canSend)
    check(!state.setReady(true, for: idA))
    check(state.setReady(true, for: idB))
}
test("multiple authorized watches require a selection and use full UUID") {
    var state = GarminConnectionState(); state.start()
    state.replaceDevices([watchA, watchB, watchA], preferredID: nil)
    check(state.devices.count == 2); check(state.selectedID == nil)
    _ = state.setReady(true, for: idB)
    state.select(idB); check(state.canSend)
    state.select(idA); check(!state.canSend)
    state.select(UUID()); check(state.selectedID == nil)
}
test("empty authorization response revokes all watches") {
    var state = GarminConnectionState(); state.start()
    state.replaceDevices([watchA], preferredID: nil)
    state.replaceDevices([], preferredID: idA)
    check(state.devices.isEmpty); check(state.selectedDevice == nil)
}
test("reconnect requests a reading once after characteristics discovery") {
    var state = GarminConnectionState(); state.start()
    state.replaceDevices([watchA], preferredID: nil)
    check(state.setReady(true, for: idA))
    check(!state.setReady(true, for: idA))
    check(!state.setReady(false, for: idA)); check(!state.canSend)
    check(state.setReady(true, for: idA))
}
test("disabled state rejects late readiness; enabling waits for discovery again") {
    var state = GarminConnectionState(); state.start()
    state.replaceDevices([watchA], preferredID: nil); _ = state.setReady(true, for: idA)
    state.stop(); check(!state.canSend); check(!state.setReady(true, for: idA))
    state.start(); check(!state.canSend); check(state.setReady(true, for: idA))
}

// Deterministic delivery tests: no Bluetooth, sleeps, or duplicate implementation.
test("Bridge then data field; completion and timer released once") {
    let h = Harness(); var results: [Result<GarminDeliveryOutcome, GarminTransportError>] = []
    h.queue.send(reading()) { results.append($0) }
    check(h.calls.count == 1); check(h.calls[0].target == .bridge)
    h.complete(0); check(h.calls.count == 2); check(h.calls[1].target == .dataField); check(results.isEmpty)
    h.complete(1); check(results == [.success(.sent)]); check(h.clock.tasks.isEmpty)
    h.complete(1); check(results.count == 1)
}
test("duplicates are skipped without changing last-transfer status") {
    let h = Harness(); h.queue.send(reading()) { _ in }; h.complete(0); h.complete(1)
    var outcome: Result<GarminDeliveryOutcome, GarminTransportError>?
    h.queue.send(reading()) { outcome = $0 }
    check(outcome == .success(.skipped)); check(h.calls.count == 2)
}
test("force retransmits unchanged packet; older readings are still skipped") {
    let h = Harness(); h.queue.send(reading()) { _ in }; h.complete(0); h.complete(1)
    h.queue.send(reading(), force: true) { _ in }
    check(h.calls[2].reading == h.calls[0].reading); h.complete(2); h.complete(3)
    h.queue.send(reading(1_699_999_999), force: true) { check($0 == .success(.skipped)) }
    check(h.calls.count == 4)
}
test("failed Bridge does not suppress retry or optional activity delivery") {
    let h = Harness(); var outcome: Result<GarminDeliveryOutcome, GarminTransportError>?
    h.queue.send(reading()) { outcome = $0 }; h.complete(0, .failure(.appNotInstalled)); h.complete(1)
    check(outcome == .failure(.appNotInstalled))
    h.queue.send(reading()) { _ in }; check(h.calls.count == 3); h.complete(2)
    check(h.calls.count == 3) // successful field is not resent
}
test("optional field failure does not replace successful Bridge status") {
    let h = Harness(); h.queue.send(reading()) { check($0 == .success(.sent)) }
    h.complete(0); h.complete(1, .failure(.appNotInstalled))
    check(h.bridgeResults == [.success(.sent)])
    h.queue.send(reading()) { check($0 == .success(.skipped)) }
    check(h.calls.count == 3); check(h.calls[2].target == .dataField); h.complete(2)
}
test("pending queue coalesces to newest reading; old update cannot evict it") {
    let h = Harness(); var replaced = 0
    h.queue.send(reading()) { _ in }
    h.queue.send(reading(1_700_000_001)) { check($0 == .failure(.superseded)); replaced += 1 }
    h.queue.send(reading(1_700_000_002)) { _ in }
    h.queue.send(reading(1_700_000_001)) { check($0 == .success(.skipped)) }
    check(replaced == 1); check(h.calls.count == 1)
    h.complete(0); h.complete(1)
    check(h.calls.count == 3); check(h.calls[2].reading.sequence == 1_700_000_002)
}
test("switch/off cancels active and pending; late success cannot send old field") {
    let h = Harness(); var cancelled = 0
    h.queue.send(reading()) { check($0 == .failure(.cancelled)); cancelled += 1 }
    h.queue.send(reading(1_700_000_001)) { check($0 == .failure(.cancelled)); cancelled += 1 }
    h.queue.cancel(); check(cancelled == 2); check(h.clock.tasks.isEmpty)
    h.complete(0); check(h.calls.count == 1); check(h.bridgeResults.isEmpty)
    h.complete(0); check(cancelled == 2)
}
test("new watch waits for old wire callback, without inheriting dedup or status") {
    let h = Harness(); h.queue.send(reading()) { _ in }; h.queue.cancel()
    h.queue.send(reading()) { _ in }; check(h.calls.count == 1)
    h.complete(0); check(h.calls.count == 2); check(h.calls[1].target == .bridge)
    check(h.bridgeResults.isEmpty)
    h.complete(0, .failure(.deviceNotConnected)); check(h.calls.count == 2)
    h.complete(1); h.complete(2); check(h.bridgeResults == [.success(.sent)])
}
test("missing callback expires request but never overlaps SDK sends") {
    let h = Harness(); var results: [Result<GarminDeliveryOutcome, GarminTransportError>] = []
    h.queue.send(reading()) { results.append($0) }
    h.clock.advance(20); check(results == [.failure(.expired)]); check(h.clock.tasks.isEmpty)
    h.queue.send(reading(1_700_000_001)) { results.append($0) }
    check(h.calls.count == 1)
    h.clock.advance(20); check(results == [.failure(.expired), .failure(.expired)])
    h.complete(0); check(h.calls.count == 1); check(results.count == 2)
    h.queue.send(reading(1_700_000_002)) { _ in }; check(h.calls.count == 2)
}
test("pending deadline includes wait time; expiry does not cancel active request") {
    let h = Harness(); var activeDone = 0; var pendingDone = 0
    h.queue.send(reading()) { _ in activeDone += 1 }
    h.clock.advance(5)
    h.queue.send(reading(1_700_000_001)) { check($0 == .failure(.expired)); pendingDone += 1 }
    h.clock.advance(15); check(activeDone == 1); check(pendingDone == 0)
    h.clock.advance(5); check(pendingDone == 1); check(h.calls.count == 1)
}
test("optional field timeout preserves Bridge success and ends request") {
    let h = Harness(); var results: [Result<GarminDeliveryOutcome, GarminTransportError>] = []
    h.queue.send(reading()) { results.append($0) }; h.complete(0)
    h.clock.advance(20); check(results == [.success(.sent)]); check(h.bridgeResults == [.success(.sent)])
    h.complete(1); check(results.count == 1)
}
test("iOS expiration cancels both requests and ignores subsequent SDK callbacks") {
    let h = Harness(); var expired = 0
    h.queue.send(reading()) { check($0 == .failure(.expired)); expired += 1 }
    h.queue.send(reading(1_700_000_001)) { check($0 == .failure(.expired)); expired += 1 }
    h.queue.cancel(.expired); check(expired == 2); check(h.clock.tasks.isEmpty)
    h.complete(0); check(h.calls.count == 1); check(h.bridgeResults.isEmpty)
}
test("disconnect/reconnect resends same sequence only in new session") {
    let h = Harness(); h.queue.send(reading()) { _ in }; h.complete(0); h.complete(1)
    h.queue.cancel(.deviceNotConnected)
    h.queue.send(reading()) { _ in }; check(h.calls.count == 3)
}
test("synchronous sender callbacks and reentrant completions are safe") {
    var calls = 0; var done = 0
    let queue = GarminDeliveryQueue { _, _, callback in calls += 1; callback(.success(())) }
    queue.send(reading()) { _ in
        done += 1
        queue.send(reading(1_700_000_001)) { _ in done += 1 }
    }
    check(calls == 4); check(done == 2)
}

test("same-timestamp calibration increments sequence without changing freshness") {
    var sequencer = GarminReadingSequencer()
    let first = sequencer.prepare(reading())!
    let corrected = sequencer.prepare(reading(glucose: 150))!
    check(corrected.measuredAt == first.measuredAt)
    check(corrected.sequence == first.sequence + 1)
    check(corrected.mgDl == 150)
    check(sequencer.prepare(reading(glucose: 150)) == corrected)
    check(sequencer.prepare(reading(1_699_999_999)) == nil)
    // These are the existing Bridge/DataField v1 acceptance conditions.
    check(corrected.sequence > first.sequence && corrected.measuredAt >= first.measuredAt)
}
test("restored sequence preserves corrections, then resumes normal measurement times") {
    var sequencer = GarminReadingSequencer()
    _ = sequencer.prepare(reading()); let corrected = sequencer.prepare(reading(glucose: 150))!
    let stored = GarminMessage(reading: corrected).encoded() as! [String: Int]
    var restored = GarminReadingSequencer(previous: GarminGlucoseReading(packet: stored))
    check(restored.prepare(reading(glucose: 150)) == corrected)
    check(restored.prepare(reading(1_700_000_300))?.sequence == 1_700_000_300)
}
test("invalid cached packets are rejected; sequence exhaustion does not overflow") {
    var packet = GarminMessage(reading: reading()).encoded() as! [String: Int]
    packet["q"] = -1; check(GarminGlucoseReading(packet: packet) == nil)
    packet["q"] = 1_700_000_000; packet["g"] = Int.max; check(GarminGlucoseReading(packet: packet) == nil)
    let maxValue = reading(Int(Int32.max))
    var sequencer = GarminReadingSequencer(previous: maxValue)
    check(sequencer.prepare(maxValue) == maxValue)
    check(sequencer.prepare(reading(Int(Int32.max), glucose: 150)) == nil)
}
test("corrected packet is delivered to both destinations, including same timestamp") {
    let h = Harness(); var sequencer = GarminReadingSequencer()
    h.queue.send(sequencer.prepare(reading())!) { _ in }; h.complete(0); h.complete(1)
    h.queue.send(sequencer.prepare(reading(glucose: 150))!) { check($0 == .success(.sent)) }
    check(h.calls.count == 3); h.complete(2); h.complete(3)
    check(h.calls[2].reading.measuredAt == h.calls[0].reading.measuredAt)
    check(h.calls[2].reading.sequence > h.calls[0].reading.sequence)
}

final class MockTransport: GarminTransport {
    var devices = [watchA, watchB]
    var selectedDevice: GarminDevice? = watchA
    var lastSentAt: Date?
    var lastError: GarminTransportError?
    var onReady: (() -> Void)?
    var starts = 0, stops = 0, cancellations = 0, selections = 0, requests = 0, returns = 0
    var sent: [(GarminGlucoseReading, Bool)] = []
    var completions: [GarminDeliveryQueue.Completion] = []
    func start() { starts += 1 }
    func stop() { stops += 1; cancelTransfers() }
    func cancelTransfers() {
        cancellations += 1
        let old = completions; completions = []
        for done in old { done(.failure(.cancelled)) }
    }
    func requestDevices() { requests += 1 }
    func handleReturn(from url: URL) { returns += 1 }
    func select(_ device: GarminDevice?) { selections += 1; selectedDevice = device; cancelTransfers() }
    func send(_ reading: GarminGlucoseReading, force: Bool, completion: @escaping GarminDeliveryQueue.Completion) {
        sent.append((reading, force)); completions.append(completion)
    }
    func ready() {
        selectedDevice?.isConnected = true
        onReady?()
    }
}
func withManager(_ body: (GarminManager, MockTransport, CoreDataManager, UserDefaults) -> Void) {
    let domain = "xdrip.garmin.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    GarminBackgroundWork.instances = []; GarminBackgroundWork.allowed = true
    let transport = MockTransport(), data = CoreDataManager()
    data.snapshot = TestSnapshot(finalValue: 123, timeStamp: Date(timeIntervalSince1970: 1_700_000_000), trend: 2)
    let manager = GarminManager(transport: transport, defaults: defaults)
    manager.configure(coreDataManager: data)
    body(manager, transport, data, defaults)
}
test("manager does not start SDK when disabled, including forced send and URL callback") {
    withManager { manager, transport, _, _ in
        manager.sendLatestReading(force: true)
        manager.requestDevices(); manager.handleReturn(from: URL(string: "xdrip-garmin://selection")!)
        manager.select(watchB)
        check(transport.starts == 0); check(transport.sent.isEmpty)
        check(transport.requests == 0 && transport.returns == 0 && transport.selections == 0)
    }
}
test("manager enables once and automatically sends on readiness/reconnect") {
    withManager { manager, transport, _, _ in
        manager.setEnabled(true); manager.setEnabled(true); check(transport.starts == 1)
        manager.sendLatestReading(); check(transport.sent.isEmpty)
        transport.ready(); check(transport.sent.count == 1); check(transport.sent[0].1)
        transport.selectedDevice?.isConnected = false
        manager.sendLatestReading(); check(transport.sent.count == 1)
        transport.ready(); check(transport.sent.count == 2)
        check(transport.sent[1].0 == transport.sent[0].0)
    }
}
test("manager toggle off stops transport and closes background work; late readiness cannot send") {
    withManager { manager, transport, _, defaults in
        manager.setEnabled(true); transport.ready()
        check(GarminBackgroundWork.instances.count == 1)
        manager.setEnabled(false); check(!defaults.garminWatchEnabled)
        check(transport.stops == 1); check(GarminBackgroundWork.instances[0].endCount == 1)
        transport.ready(); manager.sendLatestReading(force: true); check(transport.sent.count == 1)
    }
}
test("manager background expiration cancels transport and releases work once") {
    withManager { manager, transport, _, _ in
        manager.setEnabled(true); transport.ready()
        let work = GarminBackgroundWork.instances[0]
        work.expire(); work.expire()
        check(transport.cancellations == 1); check(work.endCount == 1)
    }
}
test("manager manual resend preserves packet; calibration and relaunch preserve sequence") {
    withManager { manager, transport, data, defaults in
        manager.setEnabled(true); transport.ready()
        manager.sendLatestReading(force: true)
        check(transport.sent[0].0 == transport.sent[1].0)
        data.snapshot?.finalValue = 150
        manager.sendLatestReading()
        let corrected = transport.sent[2].0
        check(corrected.sequence == 1_700_000_001); check(corrected.measuredAt == 1_700_000_000)
        let second = MockTransport()
        let relaunched = GarminManager(transport: second, defaults: defaults)
        relaunched.configure(coreDataManager: data); second.ready()
        check(second.sent[0].0 == corrected)
    }
}
test("manager handles missing/invalid readings and unavailable background budget") {
    withManager { manager, transport, data, _ in
        data.snapshot = nil
        manager.setEnabled(true); transport.ready(); check(transport.sent.isEmpty)
        data.snapshot = TestSnapshot(finalValue: .nan, timeStamp: Date(), trend: 4)
        manager.sendLatestReading(); check(transport.sent.isEmpty)
        data.snapshot?.finalValue = 100
        GarminBackgroundWork.allowed = false
        manager.sendLatestReading(); check(transport.sent.isEmpty)
    }
}
test("resume after deadline rejects SDK callback even before timer callback runs") {
    let h = Harness(); var results: [Result<GarminDeliveryOutcome, GarminTransportError>] = []
    h.queue.send(reading()) { results.append($0) }
    h.clock.now = 21 // suspension: monotonic time advances while callbacks are not processed
    h.complete(0)
    check(h.calls.count == 1); check(results == [.failure(.expired)])
    check(h.clock.tasks.isEmpty)
}
test("unit metadata round-trips and legacy packets remain valid") {
    for unit in [0, 1] {
        let value = GarminGlucoseReading(mgDl: 180, xDripTrend: 4, measuredAt: Date(timeIntervalSince1970: 1_700_000_000), displayUnit: unit)!
        let packet = GarminMessage(reading: value).encoded() as! [String: Int]
        check(packet["g"] == 180 && packet["u"] == unit)
        check(GarminGlucoseReading(packet: packet) == value)
    }
    var legacy = GarminMessage(reading: reading()).encoded() as! [String: Int]
    check(GarminGlucoseReading(packet: legacy)?.displayUnit == nil)
    legacy["u"] = 2; check(GarminGlucoseReading(packet: legacy) == nil)
}
test("unit change sends unchanged glucose/time with a newer sequence to both targets") {
    let h = Harness(); var sequencer = GarminReadingSequencer()
    for unit in [1, 0, 1] {
        let value = GarminGlucoseReading(mgDl: 180, xDripTrend: 4, measuredAt: Date(timeIntervalSince1970: 1_700_000_000), displayUnit: unit)!
        let packet = sequencer.prepare(value)!
        let count = h.calls.count
        h.queue.send(packet) { check($0 == .success(.sent)) }
        h.complete(count); h.complete(count + 1)
        check(packet.measuredAt == 1_700_000_000 && packet.mgDl == 180)
        check(sequencer.prepare(value) == packet)
    }
    check(h.calls[4].reading.sequence == 1_700_000_002)
}
test("manager follows xDrip units and reacts to settings without a new measurement") {
    withManager { manager, transport, _, defaults in
        defaults.bloodGlucoseUnitIsMgDl = false
        manager.setEnabled(true); transport.ready()
        let initial = transport.sent.last!.0
        check(initial.displayUnit == 1)
        defaults.bloodGlucoseUnitIsMgDl = true
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        let updated = transport.sent.last!.0
        check(updated.displayUnit == 0 && updated.sequence == initial.sequence + 1)
        check(updated.measuredAt == initial.measuredAt && updated.mgDl == initial.mgDl)
        let count = transport.sent.count
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        check(transport.sent.count == count)
    }
}
test("offline and disabled unit changes wait until enabled and ready") {
    withManager { manager, transport, _, defaults in
        manager.setEnabled(true); transport.ready()
        transport.selectedDevice?.isConnected = false
        let count = transport.sent.count
        defaults.bloodGlucoseUnitIsMgDl = false
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        check(transport.sent.count == count)
        transport.ready(); check(transport.sent.last!.0.displayUnit == 1)
        manager.setEnabled(false)
        defaults.bloodGlucoseUnitIsMgDl = true
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        check(transport.sent.count == count + 1)
        manager.setEnabled(true); transport.ready()
        check(transport.sent.last!.0.displayUnit == 0)
    }
}
print("\(passed) Garmin tests passed")
