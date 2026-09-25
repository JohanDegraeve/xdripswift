import Foundation

/// Bounded capture file and export protocol. The Watch recorder owns this on its serial file queue.
/// Captures never schedule wakes, touch Bluetooth, or contain credentials, packets or locations.
final class Libre2DiagnosticCapture {
    static let commandKey = "libre2CaptureCommand"
    static let maximumEvents = 100_000
    static let maximumBytes = 10_000_000
    static let chunkBytes = 40_000
    static let duration: TimeInterval = 24 * 60 * 60

    struct Status: Codable {
        let id: UUID
        let startedAt: Date
        let expiresAt: Date
        var endedAt: Date?
        var reason: String?
        var events = 0
        var bytes = 0
        var storageError: String?
        var isRecording: Bool { endedAt == nil && storageError == nil }
    }

    private let directory: URL
    private let clock: () -> Date
    private let uptime: () -> TimeInterval
    private let runID = String(UUID().uuidString.prefix(8))
    private var state: Status?
    private var startupError: String?
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private var metadataURL: URL { directory.appendingPathComponent("capture.json") }
    private var eventsURL: URL { directory.appendingPathComponent((state?.id.uuidString ?? "none") + ".txt") }

    init(directory: URL, clock: @escaping () -> Date = Date.init,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.directory = directory
        self.clock = clock
        self.uptime = uptime
        do {
            state = try Libre2JournalFile.load(Status?.self, from: metadataURL, fallback: nil)
            if state != nil {
                let attributes = try FileManager.default.attributesOfItem(atPath: eventsURL.path)
                guard let size = attributes[.size] as? NSNumber, size.intValue <= Self.maximumBytes else {
                    throw CaptureError.invalidArchive
                }
                // Recount incrementally so restoring a day-long capture uses bounded Watch memory.
                let handle = try FileHandle(forReadingFrom: eventsURL)
                defer { try? handle.close() }
                var bytes = 0, events = 0
                var lastByte: UInt8?
                while let data = try handle.read(upToCount: Self.chunkBytes), !data.isEmpty {
                    bytes += data.count
                    guard bytes <= Self.maximumBytes else { throw CaptureError.invalidArchive }
                    events += data.reduce(0) { $0 + ($1 == 10 ? 1 : 0) }
                    lastByte = data.last
                }
                state?.bytes = bytes
                state?.events = events
                // A killed process can leave an incomplete final append. Preserve it and mark it.
                if bytes > 0 && lastByte != 10 {
                    state?.storageError = "Incomplete final event after interruption."
                }
            }
        } catch {
            startupError = "Capture could not be restored: \(error.localizedDescription)"
            state?.storageError = startupError
        }
    }

    var status: Status? {
        expireIfNeeded()
        return state
    }

    /// A repeated start with the same ID is safe after a lost WatchConnectivity reply.
    func start(id: UUID) throws {
        expireIfNeeded()
        if state?.id == id { return }
        guard state?.isRecording != true else { throw CaptureError.alreadyRecording }
        let now = clock()
        let next = Status(id: id, startedAt: now, expiresAt: now.addingTimeInterval(Self.duration))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Retain no older archives. The phone asks explicitly before replacing this capture.
        let newURL = directory.appendingPathComponent(id.uuidString + ".txt")
        try Data().write(to: newURL, options: .atomic)
        do { try Libre2JournalFile.save(next, to: metadataURL) }
        catch { try? FileManager.default.removeItem(at: newURL); throw error }
        state = next
        // Also remove an old archive left by a crash between metadata commit and cleanup.
        for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            if url.lastPathComponent != newURL.lastPathComponent, url.pathExtension == "txt", UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil {
                try? FileManager.default.removeItem(at: url)
            }
        }
        startupError = nil
        record("Capture started; limit=\(Int(Self.duration / 3600))h/\(Self.maximumEvents) events/\(Self.maximumBytes / 1_000_000)MB; no radio polling")
        if let error = state?.storageError { throw CaptureError.storage(error) }
    }

    func stop(id: UUID, reason: String = "Stopped by user") throws {
        guard state?.id == id else { throw CaptureError.staleCapture }
        expireIfNeeded()
        finish(reason)
    }

    func record(_ message: @autoclosure () -> String, date: Date? = nil, uptime: TimeInterval? = nil) {
        expireIfNeeded()
        guard state?.isRecording == true else { return }
        append(message(), date: date, eventUptime: uptime)
    }

    private func expireIfNeeded() {
        guard let state, state.isRecording, clock() >= state.expiresAt else { return }
        finish("Capture duration limit reached; later events were not recorded")
    }

    private func finish(_ reason: String) {
        guard state?.endedAt == nil, state != nil else { return }
        if state?.storageError == nil { append("Capture ended: " + reason, terminal: true) }
        state?.endedAt = clock()
        state?.reason = reason
        persistStatus()
    }

    private func append(_ message: String, terminal: Bool = false, date: Date? = nil, eventUptime: TimeInterval? = nil) {
        guard let current = state, current.storageError == nil else { return }
        // Single-line bounded messages prevent error descriptions from flooding the archive.
        let clean = String(message.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ").prefix(1_200))
        let line = "\(formatter.string(from: date ?? clock())) uptime=\(String(format: "%.3f", eventUptime ?? uptime()))"
            + " run=\(runID) event=\(current.events + 1) | \(clean)\n"
        let data = Data(line.utf8)
        if !terminal && (current.events >= Self.maximumEvents - 1
            || current.bytes + data.count > Self.maximumBytes - 8_000) {
            finish("Capture capacity reached; later events were not recorded")
            return
        }
        do {
            let handle = try FileHandle(forWritingTo: eventsURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            state?.events += 1
            state?.bytes += data.count
        } catch {
            state?.storageError = "Capture write failed: \(error.localizedDescription)"
            state?.endedAt = clock()
            state?.reason = "Storage failure; capture is incomplete"
            persistStatus()
        }
    }

    private func persistStatus() {
        do { try Libre2JournalFile.save(state, to: metadataURL) }
        catch { state?.storageError = "Capture metadata write failed: \(error.localizedDescription)" }
    }

    /// Export only a stopped, immutable capture. Offset/ID checks prevent mixed archives.
    func chunk(id: UUID, offset: Int) throws -> Data {
        guard let state = status, state.id == id else { throw CaptureError.staleCapture }
        guard !state.isRecording, offset >= 0, offset <= state.bytes else { throw CaptureError.invalidArchive }
        let handle = try FileHandle(forReadingFrom: eventsURL)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        let expected = min(Self.chunkBytes, state.bytes - offset)
        let data = try handle.read(upToCount: expected) ?? Data()
        guard data.count == expected else { throw CaptureError.invalidArchive }
        return data
    }

    /// Interactive capture commands only; no background transfer queue.
    func receive(_ dictionary: [String: Any], reply: ([String: Any]) -> Void) {
        do {
            guard let command = dictionary[Self.commandKey] as? String else { throw CaptureError.invalidArchive }
            if command != "status" {
                guard let text = dictionary["captureID"] as? String, let id = UUID(uuidString: text) else {
                    throw CaptureError.invalidArchive
                }
                switch command {
                case "start": try start(id: id)
                case "stop": try stop(id: id)
                case "chunk":
                    guard let offset = dictionary["offset"] as? Int else { throw CaptureError.invalidArchive }
                    let data = try chunk(id: id, offset: offset)
                    reply(["captureID": id.uuidString, "offset": offset, "data": data])
                    return
                default: throw CaptureError.invalidArchive
                }
            }
            var response: [String: Any] = ["captureStatus": try JSONEncoder().encode(status)]
            if let startupError { response["captureWarning"] = startupError }
            reply(response)
        } catch { reply(["error": error.localizedDescription]) }
    }

    static func decodeStatus(_ reply: [String: Any]) throws -> Status? {
        if let error = reply["error"] as? String { throw CaptureError.storage(error) }
        guard let data = reply["captureStatus"] as? Data else { throw CaptureError.invalidArchive }
        return try JSONDecoder().decode(Status?.self, from: data)
    }

    static func report(status: Status, data: Data) throws -> String {
        guard data.count == status.bytes, let body = String(data: data, encoding: .utf8) else {
            throw CaptureError.invalidArchive
        }
        return "Direct Libre Watch connection capture (UTC)\nCapture: \(status.id)\n"
            + "Result: \(status.reason ?? "Incomplete")\nStorage: \(status.storageError ?? "OK")\n"
            + "Events: \(status.events); bytes: \(status.bytes)\n"
            + "Timestamps are captured at event origin; file order follows queue submission. Callback/request association is not guaranteed when requests overlap.\nGaps do not prove RF loss, suspension or Apple throttling. A write acknowledgement does not prove successful streaming.\n\n" + body
    }

    struct Download {
        let status: Status
        private(set) var data = Data()
        var isComplete: Bool { data.count == status.bytes }

        mutating func append(_ reply: [String: Any]) throws {
            guard !status.isRecording, status.bytes >= 0, status.bytes <= Libre2DiagnosticCapture.maximumBytes,
                reply["captureID"] as? String == status.id.uuidString,
                reply["offset"] as? Int == data.count,
                let chunk = reply["data"] as? Data,
                chunk.count == min(Libre2DiagnosticCapture.chunkBytes, status.bytes - data.count)
            else { throw CaptureError.invalidArchive }
            data.append(chunk)
        }
    }

    enum CaptureError: LocalizedError {
        case alreadyRecording, staleCapture, invalidArchive, storage(String)
        var errorDescription: String? {
            switch self {
            case .alreadyRecording: return "A capture is already running. Stop and load it before starting another."
            case .staleCapture: return "The Watch capture changed. Refresh its status and load it again."
            case .invalidArchive: return "The capture could not be read completely. Retry loading it."
            case .storage(let message): return message
            }
        }
    }
}

/// The Bluetooth and main queues submit bounded metadata here; only this queue touches files.
/// The lock protects admission/order, never file I/O. Disabled captures do not evaluate details.
final class Libre2DiagnosticRecorder {
    private let queue = DispatchQueue(label: "Libre2.capture", qos: .utility)
    private let lock = NSLock()
    private var activeID: UUID?
    private var stoppingID: UUID?
    private var pending = 0
    private var dropped = 0
    private var capture: Libre2DiagnosticCapture!
    static let maximumPendingEvents = 256

    init(directory: URL) {
        queue.async {
            self.capture = Libre2DiagnosticCapture(directory: directory)
            self.capture.record("Process initialized; prior capture resumed if still active. Relaunch does not establish crash cause.")
            self.updateAdmission()
        }
    }

    func whenReady(_ callback: @escaping () -> Void) { queue.async(execute: callback) }

    var isRecording: Bool {
        lock.lock(); defer { lock.unlock() }
        return activeID != nil
    }

    func record(_ message: @autoclosure () -> String) {
        lock.lock(); defer { lock.unlock() }
        guard let id = activeID else { return }
        guard pending < Self.maximumPendingEvents else { dropped += 1; return }
        let date = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        let origin = Thread.isMainThread ? "main" : "background"
        let detail = String(message().prefix(1_200))
        pending += 1
        queue.async {
            self.lock.lock()
            self.pending -= 1
            self.lock.unlock()
            guard self.capture.status?.id == id else { return }
            self.flushDropped()
            self.capture.record("origin=\(origin) \(detail)", date: date, uptime: uptime)
            self.updateAdmission()
        }
    }

    /// Commands share ordering with events. Stop closes admission immediately, then drains
    /// accepted events before freezing the file. Replies are delivered on the file queue.
    func receive(_ message: [String: Any], reply: @escaping ([String: Any]) -> Void) {
        lock.lock(); defer { lock.unlock() }
        if message[Libre2DiagnosticCapture.commandKey] as? String == "stop",
           message["captureID"] as? String == activeID?.uuidString { stoppingID = activeID; activeID = nil }
        queue.async {
            self.flushDropped()
            self.capture.receive(message) { response in
                self.lock.lock()
                if message[Libre2DiagnosticCapture.commandKey] as? String == "stop",
                   message["captureID"] as? String == self.stoppingID?.uuidString { self.stoppingID = nil }
                self.lock.unlock()
                self.updateAdmission()
                reply(response)
            }
        }
    }

    private func updateAdmission() {
        let status = capture.status
        lock.lock(); defer { lock.unlock() }
        activeID = status?.isRecording == true && status?.id != stoppingID ? status?.id : nil
    }

    private func flushDropped() {
        lock.lock()
        let count = dropped
        dropped = 0
        lock.unlock()
        if count > 0 { capture.record("Capture overloaded: \(count) events dropped before file queue; timeline incomplete.") }
    }
}
