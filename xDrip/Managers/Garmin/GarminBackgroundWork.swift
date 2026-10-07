import UIKit

/// A finite opportunity to finish an already-triggered transfer, not a background scheduler.
final class GarminBackgroundWork {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    private let name: String
    init(_ name: String) { self.name = name }

    func begin(onExpiration: @escaping () -> Void) -> Bool {
        precondition(Thread.isMainThread)
        guard identifier == .invalid else { return true }
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            guard let self, self.identifier != .invalid else { return }
            onExpiration()
            self.end()
        }
        return identifier != .invalid
    }

    func end() {
        precondition(Thread.isMainThread)
        guard identifier != .invalid else { return }
        let finished = identifier
        identifier = .invalid
        UIApplication.shared.endBackgroundTask(finished)
    }

    deinit {
        if identifier != .invalid {
            let finished = identifier
            DispatchQueue.main.async { UIApplication.shared.endBackgroundTask(finished) }
        }
    }
}
