import Foundation
import Combine
import WatchConnectivity

/// Explicit commands only. A stopped Watch archive is downloaded in checked chunks;
/// the last complete phone report survives failed transfers, navigation and app restarts.
final class Libre2CaptureController: ObservableObject {
    @Published private(set) var status: Libre2DiagnosticCapture.Status?
    @Published private(set) var hasInspected = false
    @Published private(set) var isBusy = false
    @Published private(set) var error: String?
    @Published private(set) var reportURL: URL?
    @Published private(set) var savedAt: Date?
    private var requestID: UUID?
    private var timeout: DispatchWorkItem?
    private var pendingStartID: UUID?
    private let savedURL = Libre2JournalFile.url("WatchConnectionCapture.txt")

    init() {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: savedURL.path) {
            reportURL = savedURL
            savedAt = attributes[.modificationDate] as? Date
        }
    }

    var description: String {
        guard hasInspected else { return "Watch capture status has not been loaded." }
        guard let status else { return "No capture on the Watch." }
        if let failure = status.storageError { return failure }
        if status.isRecording {
            return "Recording since \(status.startedAt.formatted(date: .omitted, time: .standard)); "
                + "records until \(status.expiresAt.formatted(date: .omitted, time: .standard)) at most. \(status.events) events at last refresh."
        }
        return "\(status.reason ?? "Stopped"). \(status.events) events, \(status.bytes) bytes."
    }

    func refresh() {
        guard !isBusy else { return }
        request("status") { reply in
            self.status = try Libre2DiagnosticCapture.decodeStatus(reply)
            self.hasInspected = true
            self.error = reply["captureWarning"] as? String
            if self.status?.id == self.pendingStartID { self.pendingStartID = nil }
        }
    }

    func start() {
        guard !isBusy else { return }
        // Reuse the token if the previous start reply was lost.
        let id = pendingStartID ?? UUID()
        pendingStartID = id
        request("start", id: id) { reply in
            self.status = try Libre2DiagnosticCapture.decodeStatus(reply)
            self.hasInspected = true
            self.pendingStartID = nil
        }
    }

    func stopAndLoad() {
        guard !isBusy, let status else { return }
        request("stop", id: status.id) { reply in
            guard let stopped = try Libre2DiagnosticCapture.decodeStatus(reply), !stopped.isRecording else {
                throw Libre2DiagnosticCapture.CaptureError.invalidArchive
            }
            self.status = stopped
            self.loadChunk(Libre2DiagnosticCapture.Download(status: stopped))
        }
    }

    private func loadChunk(_ download: Libre2DiagnosticCapture.Download) {
        request("chunk", id: download.status.id, offset: download.data.count) { reply in
            var download = download
            try download.append(reply)
            if download.isComplete {
                let report = try Libre2DiagnosticCapture.report(status: download.status, data: download.data)
                try FileManager.default.createDirectory(at: self.savedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(report.utf8).write(to: self.savedURL, options: .atomic)
                self.reportURL = self.savedURL
                self.savedAt = Date()
            } else {
                self.loadChunk(download)
            }
        }
    }

    private func request(_ command: String, id: UUID? = nil, offset: Int? = nil,
                         accept: @escaping ([String: Any]) throws -> Void) {
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            error = "Open xDrip on the Watch to control or download its capture."
            isBusy = false
            return
        }
        isBusy = true
        error = nil
        let token = UUID()
        requestID = token
        var message: [String: Any] = [Libre2DiagnosticCapture.commandKey: command]
        if let id { message["captureID"] = id.uuidString }
        if let offset { message["offset"] = offset }
        let work = DispatchWorkItem { [weak self] in
            self?.failed("Watch did not reply. Refresh status or retry loading; the saved capture is retained.", token: token)
        }
        timeout?.cancel()
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                guard let self, self.requestID == token else { return }
                self.timeout?.cancel()
                self.requestID = nil
                self.isBusy = false
                do {
                    if let error = reply["error"] as? String { throw Libre2DiagnosticCapture.CaptureError.storage(error) }
                    try accept(reply)
                } catch { self.error = error.localizedDescription }
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async { self?.failed(error.localizedDescription, token: token) }
        })
    }

    private func failed(_ message: String, token: UUID) {
        guard requestID == token else { return }
        timeout?.cancel()
        requestID = nil
        isBusy = false
        error = message
    }
}
