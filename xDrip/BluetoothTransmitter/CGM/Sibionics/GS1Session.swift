import CryptoKit
import Foundation
import GS1Native

/// Factory 14-day GS1 CN only. Sensor index is minutes since the original session start.
enum GS1Policy {
    static let warmup: TimeInterval = 60 * 60
    static let lifetime: TimeInterval = 14 * 24 * 60 * 60
    static let revision = "GS1-CN-AA55:11e6e29:115G:1"
    static func mayPublish(index: Int, timestamp: Date, start: Date, now: Date, live: Bool, confirmed: Bool) -> Bool {
        let age = timestamp.timeIntervalSince(start), freshness = now.timeIntervalSince(timestamp)
        return confirmed && live && index >= 60 && age >= warmup && age < lifetime && freshness >= 0 && freshness <= 120
    }
}

enum GS1SessionError: Error { case journal, checkpoint, conflictingSample, timeline, decoder, persistence }

enum GS1TimelineIssue {
    case invalidClock, invalidRecord
    case anchor(index: Int, delta: TimeInterval)
    case nonMonotonic(index: Int, delta: TimeInterval)

    var canRetry: Bool {
        switch self {
        case .anchor, .nonMonotonic: return true
        case .invalidClock, .invalidRecord: return false
        }
    }
    var diagnostic: String {
        switch self {
        case .invalidClock: return "invalid receive clock"
        case .invalidRecord: return "invalid record clock/index"
        case .anchor(let index, let delta): return "anchor index=\(index) deltaSeconds=\(Int(delta.rounded()))"
        case .nonMonotonic(let index, let delta): return "order index=\(index) deltaSeconds=\(Int(delta.rounded()))"
        }
    }
}

struct GS1SourceRecord: Codable, Equatable {
    let index: Int
    let chemical: Int
    let temperature: Int
    let impedance: Int
    let status: Int
    let timestamp: Date
    init(_ sample: GS1RawSample, received: Date) {
        index = sample.index; chemical = sample.chemicalSignal; temperature = sample.rawTemperature
        impedance = sample.impedance; status = sample.opaqueStatus; timestamp = sample.timestamp(receivedAt: received)
    }
    func sameSignal(as other: GS1SourceRecord) -> Bool {
        index == other.index && chemical == other.chemical && temperature == other.temperature && impedance == other.impedance && status == other.status
    }
}

/// Append-only source journal. The checkpoint is replaceable; original source records are not.
final class GS1Journal {
    struct Line: Codable { let record: GS1SourceRecord; let digest: String }
    struct Checkpoint: Codable {
        let identity: String, revision: String, digest: String
        let index: Int
        let start: Date?
        let confirmed: Bool
        let core: Data
    }
    private struct Envelope: Codable { let body: Data; let digest: String }
    let directory: URL
    let identity: String
    private(set) var records: [GS1SourceRecord] = []
    private var digests: [String] = []
    private var initialDigest: String { Self.hash(Data((identity + GS1Policy.revision).utf8)) }
    private var journalURL: URL { directory.appendingPathComponent("source.jsonl") }
    private var checkpointURL: URL { directory.appendingPathComponent("checkpoint.json") }
    init(base: URL, identity: String) throws {
        self.identity = identity
        directory = base.appendingPathComponent(Self.hash(Data(identity.utf8)), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: journalURL.path) else { return }
        let data = try Data(contentsOf: journalURL)
        guard data.isEmpty || data.last == 10, data.count <= 32_000_000 else { throw GS1SessionError.journal }
        var previous = initialDigest
        for raw in data.split(separator: 10) {
            let line = try JSONDecoder().decode(Line.self, from: Data(raw))
            guard line.record.index == records.count + 1, line.record.index <= 65535 else { throw GS1SessionError.journal }
            let expected = Self.hash(Data(previous.utf8) + (try Self.encode(line.record)))
            guard expected == line.digest else { throw GS1SessionError.journal }
            records.append(line.record); digests.append(expected); previous = expected
        }
    }
    func append(_ record: GS1SourceRecord) throws {
        guard record.index == records.count + 1 else { throw GS1SessionError.journal }
        let digest = Self.hash(Data((digests.last ?? initialDigest).utf8) + (try Self.encode(record)))
        let line = try Self.encode(Line(record: record, digest: digest)) + Data([10])
        if !FileManager.default.fileExists(atPath: journalURL.path) {
            try Data().write(to: journalURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        let file = try FileHandle(forWritingTo: journalURL)
        defer { try? file.close() }
        try file.seekToEnd(); try file.write(contentsOf: line); try file.synchronize()
        records.append(record); digests.append(digest)
    }
    func loadCheckpoint() -> Checkpoint? {
        guard let data = try? Data(contentsOf: checkpointURL), data.count <= 1_000_000,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data), Self.hash(envelope.body) == envelope.digest,
              let value = try? JSONDecoder().decode(Checkpoint.self, from: envelope.body), value.identity == identity,
              value.revision == GS1Policy.revision, value.index >= 1, value.index <= records.count,
              value.digest == digests[value.index - 1] else { return nil }
        return value
    }
    func saveCheckpoint(core: Data, index: Int, start: Date?, confirmed: Bool) throws {
        guard index >= 1, index == records.count else { throw GS1SessionError.checkpoint }
        let value = Checkpoint(identity: identity, revision: GS1Policy.revision, digest: digests[index - 1], index: index, start: start, confirmed: confirmed, core: core)
        let body = try Self.encode(value)
        try Self.encode(Envelope(body: body, digest: Self.hash(body))).write(to: checkpointURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    static func encode<T: Encodable>(_ value: T) throws -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(value) }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}

/// Runs only on the transmitter's serial Bluetooth queue. Historical records reconstruct
/// the exact core; a fresh final correction can enter the app's glucose pipeline only
/// after the contiguous history has caught up to the sensor's live tail.
final class GS1Session {
    struct Reading { let index: Int; let date: Date; let mgdl: Double }
    let identity: String
    let journal: GS1Journal
    private var engine: GS1V115GEngine
    // A five-minute correction may precede the one-minute tail in another packet.
    // Keep the original event time; never promote raw/intermediate output to glucose.
    // Pending delivery is intentionally not restored after a process restart.
    private var pendingFinal: Reading?
    private var lastPublishedIndex = 0
    private(set) var start: Date?
    private(set) var startConfirmed = false
    private(set) var historyReady = false
    var nextIndex: Int { Int(engine.lastAcceptedIndex) < 1 ? 1 : Int(engine.lastAcceptedIndex) + 1 }
    private(set) var lastStatus = "Waiting for complete sensor history"
    private(set) var timelineIssue: GS1TimelineIssue?

    init(identity: String, sensitivity: Float, storage: URL) throws {
        self.identity = identity
        journal = try GS1Journal(base: storage, identity: identity)
        engine = GS1V115GEngine(sensorIdentity: identity, factorySensitivity: sensitivity)
        if let saved = journal.loadCheckpoint() {
            let candidate = GS1V115GEngine(sensorIdentity: identity, factorySensitivity: sensitivity)
            if candidate.restore(snapshot: Self.kotlin(saved.core)), Int(candidate.lastAcceptedIndex) == saved.index,
               let first = journal.records.first, let savedStart = saved.start,
               abs(savedStart.timeIntervalSince(first.timestamp.addingTimeInterval(-60))) < 0.001,
               !saved.confirmed || saved.index >= 2 {
                engine = candidate; start = savedStart; startConfirmed = saved.confirmed
            }
        }
        // A missing or corrupt checkpoint is rebuilt from the original contiguous journal.
        for record in journal.records where record.index >= nextIndex { _ = try advance(record) }
    }

    func ingest(_ samples: [GS1RawSample], received: Date, now: Date) throws -> [Reading] {
        timelineIssue = nil
        guard received.timeIntervalSince1970.isFinite, now.timeIntervalSince1970.isFinite,
              received.timeIntervalSince(now) <= 5, received.timeIntervalSince1970 > 946_684_800 else {
            timelineIssue = .invalidClock
            throw GS1SessionError.timeline
        }
        var advanced = false
        let ordered = samples.sorted { $0.index < $1.index }
        for sample in ordered {
            let incoming = GS1SourceRecord(sample, received: received)
            let record: GS1SourceRecord
            if incoming.index > 0, incoming.index <= journal.records.count {
                let persisted = journal.records[incoming.index - 1]
                guard persisted.sameSignal(as: incoming) else { throw GS1SessionError.conflictingSample }
                // A crash can leave the source journal ahead of the checkpoint/core.
                // Replay exactly the immutable original record, including its timestamp.
                record = persisted
            } else { record = incoming }
            if record.index < nextIndex {
                guard record.index > 0, record.index <= journal.records.count,
                      journal.records[record.index - 1].sameSignal(as: record) else { throw GS1SessionError.conflictingSample }
                continue
            }
            guard record.index == nextIndex else {
                historyReady = false; lastStatus = "Downloading missing history from minute \(nextIndex)"; break
            }
            try validateTimeline(record)
            if record.index > journal.records.count { try journal.append(record) }
            let final = try advance(record)
            advanced = true
            historyReady = sample.isLastInHistory
            if let final {
                pendingFinal = .init(index: record.index, date: record.timestamp, mgdl: Double(final) * 18)
            }
        }
        if let snapshot = engine.snapshot(), engine.lastAcceptedIndex >= 1 {
            try journal.saveCheckpoint(core: Self.data(snapshot), index: Int(engine.lastAcceptedIndex), start: start, confirmed: startConfirmed)
        }
        if let start, historyReady {
            let age = now.timeIntervalSince(start)
            lastStatus = age < GS1Policy.warmup ? "Warming up: \(max(0, Int(ceil((GS1Policy.warmup-age)/60)))) min" : (age >= GS1Policy.lifetime ? "14-day sensor session ended" : "Connected; waiting for the next final reading")
        }
        guard let pending = pendingFinal else { return [] }
        guard pending.index > lastPublishedIndex, let start,
              GS1Policy.mayPublish(index: pending.index, timestamp: pending.date, start: start, now: now, live: true, confirmed: startConfirmed) else {
            // Expired, warming-up or future candidates cannot become publishable later.
            pendingFinal = nil
            return []
        }
        // A duplicate or empty packet is not evidence of a newly completed history.
        // Incomplete batches retain the correction while the missing minutes arrive.
        guard advanced, historyReady else { return [] }
        pendingFinal = nil
        lastPublishedIndex = pending.index
        return [pending]
    }

    private func validateTimeline(_ record: GS1SourceRecord) throws {
        guard record.index > 0, record.timestamp.timeIntervalSince1970.isFinite,
              record.timestamp.timeIntervalSince1970 > 946_684_800 else {
            timelineIssue = .invalidRecord
            throw GS1SessionError.timeline
        }
        if let start {
            let anchor = record.timestamp.addingTimeInterval(-Double(record.index) * 60)
            let delta = anchor.timeIntervalSince(start)
            guard abs(delta) <= 120 else {
                timelineIssue = .anchor(index: record.index, delta: delta)
                throw GS1SessionError.timeline
            }
        }
        if record.index > 1, record.index - 2 < journal.records.count {
            let delta = record.timestamp.timeIntervalSince(journal.records[record.index - 2].timestamp)
            guard delta > 0 else {
                timelineIssue = .nonMonotonic(index: record.index, delta: delta)
                throw GS1SessionError.timeline
            }
        }
    }
    private func advance(_ record: GS1SourceRecord) throws -> Float? {
        try validateTimeline(record)
        let anchor = record.timestamp.addingTimeInterval(-Double(record.index) * 60)
        if start == nil { start = anchor } else if record.index > 1 { startConfirmed = true }
        let result = engine.accept(rawMmol: Float(record.chemical)/10, temperatureC: Float(record.temperature)/10, index: Int32(record.index))
        guard result.status != .invalidConfiguration, result.status != .invalidInput, result.status != .nonContiguousIndex else { throw GS1SessionError.decoder }
        return result.status == .correction ? result.finalMmol?.floatValue : nil
    }
    static func data(_ value: KotlinByteArray) -> Data { Data((0..<value.size).map { UInt8(bitPattern: value.get(index: $0)) }) }
    static func kotlin(_ data: Data) -> KotlinByteArray {
        let result = KotlinByteArray(size: Int32(data.count))
        for (i, byte) in data.enumerated() { result.set(index: Int32(i), value: Int8(bitPattern: byte)) }
        return result
    }
}
