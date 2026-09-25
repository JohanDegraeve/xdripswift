import CoreLocation
import WatchKit
import os

/// Optional execution support. Sensor connections, counters and readings stay in the collector.
/// All entry points and delegate callbacks run on main; no location history is retained.
final class Libre2WatchLocationSession: NSObject, CLLocationManagerDelegate {
    private let defaults: UserDefaults
    private let log = Logger(subsystem: "xDrip", category: "Libre2WatchLocationSession")
    private var enabled: Bool {
        get { defaults.bool(forKey: "directLibreWatchBackgroundLocation") }
        set { defaults.set(newValue, forKey: "directLibreWatchBackgroundLocation") }
    }
    private var accuracy: Libre2LocationRequest.Accuracy {
        get { Libre2LocationRequest.Accuracy(rawValue: defaults.integer(forKey: "directLibreWatchLocationAccuracy")) ?? .hundredMeters }
        set { defaults.set(newValue.rawValue, forKey: "directLibreWatchLocationAccuracy") }
    }
    private var locationManager: CLLocationManager?
    private var observers: [NSObjectProtocol] = []
    private var isUpdating = false
    private var requestedAuthorization = false
    private var receivedLocation = false
    private var lastLocationCallback: Date?
    private var locationCallbacks = 0
    private var lastDiagnosticLocation: Date?
    private var status = "Background location is off."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        for name in [Libre2ConnectionStore.didChange, WKApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in self?.refresh()
            })
        }
        refresh()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        locationManager?.stopUpdatingLocation()
    }

    @discardableResult
    func receive(_ dictionary: [String: Any], reply: ([String: Any]) -> Void) -> Bool {
        guard dictionary[Libre2LocationRequest.key] != nil else { return false }
        do {
            switch try Libre2LocationRequest.decode(dictionary) {
            case .inspect: break
            case .setEnabled(let enabled): self.enabled = enabled
            case .setAccuracy(let accuracy): self.accuracy = accuracy
            }
            refresh()
            reply(["enabled": enabled, "status": status,
                   "accuracy": accuracy.rawValue])
        } catch { reply(["error": error.localizedDescription]) }
        return true
    }

    private func refresh() {
        guard enabled else {
            stop(status: "Background location is off.")
            return
        }
        guard Libre2ConnectionStore.shared.snapshot?.allowsWatch == true else {
            stop(status: "Background location is enabled; waiting for Watch collection.")
            return
        }

        // Never create/start a new location session from a background WCSession delivery.
        // This target is a watchOS application, not a legacy WatchKit extension.
        let isActive = WKApplication.shared().applicationState == .active
        guard isUpdating || isActive else {
            publish("Open xDrip on the Watch to start background location.")
            return
        }
        if locationManager == nil {
            let manager = CLLocationManager()
            manager.delegate = self
            manager.distanceFilter = kCLDistanceFilterNone
            manager.activityType = .other
            manager.allowsBackgroundLocationUpdates = true
            locationManager = manager
        }
        guard let manager = locationManager else { return }
        // Apply to the existing session, including in the background; no location/BLE restart.
        let requestedAccuracy = Double(accuracy.rawValue)
        if manager.desiredAccuracy != requestedAccuracy { manager.desiredAccuracy = requestedAccuracy }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            guard !isUpdating else { return }
            isUpdating = true
            receivedLocation = false
            publish("Background location started; waiting for a location update.")
            Libre2WatchDiagnostics.shared.record("Location start issued accuracy=\(manager.desiredAccuracy)")
            manager.startUpdatingLocation()
        case .notDetermined:
            publish("Allow location access in xDrip on the Watch.")
            if isActive && !requestedAuthorization {
                requestedAuthorization = true
                manager.requestWhenInUseAuthorization()
            }
        case .denied, .restricted:
            stop(status: "Location access is unavailable. Check Location Services and xDrip permission on the Watch.")
        @unknown default:
            stop(status: "Location access is unavailable. Check Location Services and xDrip permission on the Watch.")
        }
    }

    private func stop(status: String) {
        if isUpdating { Libre2WatchDiagnostics.shared.record("Location stop issued reason=\(status)") }
        if isUpdating { locationManager?.stopUpdatingLocation() }
        isUpdating = false
        receivedLocation = false
        publish(status)
    }

    func recordDiagnosticSnapshot() {
        Libre2WatchDiagnostics.shared.record("Location snapshot enabled=\(enabled) updating=\(isUpdating) accuracy=\(accuracy.rawValue) authorization=\(locationManager?.authorizationStatus.rawValue ?? -1) receivedFix=\(receivedLocation) lastCallbackAge=\(lastLocationCallback.map { Date().timeIntervalSince($0) } ?? -1) status=\(status)")
    }

    private func publish(_ value: String) {
        guard status != value else { return }
        status = value
        Libre2WatchDiagnostics.shared.record("Location status: \(value)")
        log.info("\(value, privacy: .public)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Libre2WatchDiagnostics.shared.record("Location authorization=\(manager.authorizationStatus.rawValue)")
        refresh()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if Libre2WatchDiagnostics.shared.isRecording {
            let now = Date()
            let gap = lastLocationCallback.map { now.timeIntervalSince($0) } ?? -1
            lastLocationCallback = now
            locationCallbacks += 1
            if lastDiagnosticLocation == nil || now.timeIntervalSince(lastDiagnosticLocation!) >= 60 {
                Libre2WatchDiagnostics.shared.record("Location callbacks=\(locationCallbacks) previousGap=\(gap) fixAge=\(locations.last.map { now.timeIntervalSince($0.timestamp) } ?? -1); coordinates omitted")
                lastDiagnosticLocation = now
                locationCallbacks = 0
            }
        }
        guard isUpdating, !receivedLocation, !locations.isEmpty else { return }
        receivedLocation = true
        publish("Location updates received. Background glucose collection remains experimental.")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Libre2WatchDiagnostics.shared.record("Location error: \(BluetoothTransmitter.diagnosticError(error))")
        guard isUpdating else { return }
        if (error as? CLError)?.code == .denied {
            stop(status: "Location access is unavailable. Check Location Services and xDrip permission on the Watch.")
        } else {
            // A missing fix is not a reason to restart location or touch the sensor connection.
            receivedLocation = false
            publish("Location is temporarily unavailable; waiting for updates.")
        }
    }
}
