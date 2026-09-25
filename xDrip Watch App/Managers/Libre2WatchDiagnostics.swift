import Foundation
import WatchKit

/// Passive Watch capture. No timers, radio requests, automatic uploads or recovery actions.
final class Libre2WatchDiagnostics {
    static let shared = Libre2WatchDiagnostics()
    private let recorder = Libre2DiagnosticRecorder(directory: Libre2JournalFile.url("DiagnosticCapture"))
    private var observers: [NSObjectProtocol] = []

    private init() {
        recorder.whenReady { [weak self] in DispatchQueue.main.async { self?.recordSnapshot() } }
        for name in [WKApplication.didBecomeActiveNotification, WKApplication.willResignActiveNotification,
                     WKApplication.didEnterBackgroundNotification, WKApplication.willEnterForegroundNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                self?.record("Lifecycle: \(note.name.rawValue); appState=\(WKApplication.shared().applicationState.rawValue)")
            })
        }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    var isRecording: Bool { recorder.isRecording }
    func record(_ message: @autoclosure () -> String) { recorder.record(message()) }

    /// Called on main; the file queue returns only after preceding accepted events are drained.
    @discardableResult
    func receive(_ message: [String: Any], snapshot: @escaping () -> Void, reply: @escaping ([String: Any]) -> Void) -> Bool {
        guard message[Libre2DiagnosticCapture.commandKey] != nil else { return false }
        recorder.receive(message) { response in
            DispatchQueue.main.async {
                if message[Libre2DiagnosticCapture.commandKey] as? String == "start", response["error"] == nil {
                    self.recordSnapshot()
                    snapshot()
                }
                reply(response)
            }
        }
        return true
    }

    func recordSnapshot() {
        guard isRecording else { return }
        let bundle = Bundle.main
        record("Watch build=\(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "?")"
            + " (\(bundle.object(forInfoDictionaryKey: "CFBundleVersion") ?? "?")); OS=\(ProcessInfo.processInfo.operatingSystemVersionString);"
            + " appState=\(WKApplication.shared().applicationState.rawValue); lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)")
        Libre2WatchConnection.shared.recordDiagnosticSnapshot()
    }
}
