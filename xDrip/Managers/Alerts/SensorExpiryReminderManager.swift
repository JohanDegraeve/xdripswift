import Foundation
import os
import UserNotifications

/// Sensor details from one source. The display caches are cleared at launch
/// and can still contain details from the previous sensor.
struct SensorExpirySnapshot: Codable, Equatable, Sendable {
    let source: String
    let sessionID: String
    let startDate: Date
    let lifetimeDays: Double

    var expiryDate: Date? { Self.expiryDate(startDate: startDate, lifetimeDays: lifetimeDays) }

    static func expiryDate(startDate: Date?, lifetimeDays: Double) -> Date? {
        guard let startDate, startDate.timeIntervalSince1970.isFinite,
              lifetimeDays.isFinite, lifetimeDays > 0 else { return nil }
        let expiry = startDate.addingTimeInterval(lifetimeDays * 86400)
        return expiry.timeIntervalSince1970.isFinite ? expiry : nil
    }

    /// Include the account when identifying the source. Keep it out of notification identifiers and logs.
    static func currentSource(defaults: UserDefaults = .standard) -> String? {
        if defaults.isMaster {
            return defaults.cgmTransmitterType.map { "direct:\($0.rawValue)" }
        }
        guard defaults.followerDataSourceType == .libreLinkUp || defaults.followerDataSourceType == .libreLinkUpRussia,
              !defaults.libreLinkUpManuallyLoggedOut else { return nil }
        return "\(defaults.followerDataSourceType.rawValue):\(defaults.libreLinkUpEmail?.lowercased() ?? "")"
    }

    static var supportsCurrentSource: Bool {
        UserDefaults.standard.isMaster || UserDefaults.standard.followerDataSourceType == .libreLinkUp ||
            UserDefaults.standard.followerDataSourceType == .libreLinkUpRussia
    }
}

struct SensorExpiryReminderConfiguration: Equatable {
    let kind: AlertKind
    let enabled: Bool
    let hoursBefore: Int
    /// Nil uses the system sound. An empty name is silent.
    let soundName: String?
}

@MainActor
protocol SensorExpiryNotificationScheduling {
    func pendingRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func remove(identifiers: [String], delivered: Bool)
}

@MainActor
private struct SystemSensorExpiryNotifications: SensorExpiryNotificationScheduling {
    let center = UNUserNotificationCenter.current()

    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func remove(identifiers: [String], delivered: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        if delivered { center.removeDeliveredNotifications(withIdentifiers: identifiers) }
    }
}

/// Schedules the two expiry reminders without waiting for another glucose reading.
@MainActor
final class SensorExpiryReminderManager {
    nonisolated static let notificationPrefix = "sensorExpiry."
    nonisolated static let snapshotChanged = Notification.Name("SensorExpirySnapshotChanged")
    nonisolated static let snapshotKey = "snapshot"
    nonisolated static let sourceKey = "source"
    private static let storageKey = "sensorExpiryReminderState"

    private struct Record: Codable, Equatable {
        let sessionID: String
        let kind: Int
        let identifier: String
        var scheduledDate: Date?
        var consumed = false
    }

    private struct State: Codable, Equatable {
        var snapshot: SensorExpirySnapshot?
        var records = [Record]()
    }

    private struct Input: Equatable {
        let snapshot: SensorExpirySnapshot?
        let configurations: [SensorExpiryReminderConfiguration]
    }

    private let defaults: UserDefaults
    private let scheduler: any SensorExpiryNotificationScheduling
    private let now: () -> Date
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryAlertManager)
    private var state: State
    private var savedState: State
    private var desired: Input?
    private var generation = 0
    private var needsRetry = false
    private var reconciliation: Task<Void, Never>?

    var snapshot: SensorExpirySnapshot? { state.snapshot }

    init(
        userDefaults: UserDefaults = .standard,
        notificationScheduler: (any SensorExpiryNotificationScheduling)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        defaults = userDefaults
        scheduler = notificationScheduler ?? SystemSensorExpiryNotifications()
        self.now = now
        let restored = userDefaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
        state = restored
        savedState = restored
    }

    /// Apply updates in order so a sensor change cannot leave an old reminder scheduled.
    func reconcile(snapshot: SensorExpirySnapshot?, configurations: [SensorExpiryReminderConfiguration], force: Bool = false) {
        let input = Input(snapshot: snapshot?.expiryDate == nil ? nil : snapshot, configurations: configurations)
        guard desired != input || force || needsRetry else { return }
        if desired != input {
            desired = input
            generation += 1
        }
        guard reconciliation == nil else { return }
        reconciliation = Task { [weak self] in
            guard let self else { return }
            while let input = self.desired {
                let revision = self.generation
                await self.apply(input, revision: revision)
                if revision == self.generation { break }
            }
            self.reconciliation = nil
        }
    }

    /// Wait for pending scheduling work to finish.
    func waitForReconciliation() async {
        await reconciliation?.value
    }

    private func apply(_ input: Input, revision: Int) async {
        let pending = await scheduler.pendingRequests()
        guard generation == revision else { return }
        let referenceDate = now()
        needsRetry = false

        // Mark reminders as used once their scheduled time has passed.
        // Extending the sensor lifetime must not schedule them again.
        for index in state.records.indices {
            if let date = state.records[index].scheduledDate, date <= referenceDate {
                state.records[index].consumed = true
            }
        }
        let currentSession = input.snapshot.map { $0.source + "|" + $0.sessionID }
        let obsolete = state.records.indices.filter {
            state.records[$0].sessionID != currentSession && state.records[$0].scheduledDate != nil
        }
        if !obsolete.isEmpty {
            scheduler.remove(identifiers: obsolete.map { state.records[$0].identifier }, delivered: true)
            trace("cancelled previous sensor expiry reminders", log: log, category: ConstantsLog.categoryAlertManager, type: .info)
        }
        for index in obsolete { state.records[index].scheduledDate = nil }
        if state.snapshot != input.snapshot {
            trace("sensor expiry session updated", log: log, category: ConstantsLog.categoryAlertManager, type: .info)
        }
        state.snapshot = input.snapshot
        persist()
        guard let snapshot = input.snapshot, let expiry = snapshot.expiryDate, let currentSession else { return }

        for configuration in input.configurations where configuration.kind.isSensorExpiryReminder {
            guard generation == revision else { return }
            let kind = configuration.kind
            var index = state.records.firstIndex { $0.sessionID == currentSession && $0.kind == kind.rawValue }
            if index == nil {
                state.records.append(Record(sessionID: currentSession, kind: kind.rawValue,
                                            identifier: Self.notificationPrefix + UUID().uuidString))
                index = state.records.count - 1
                // Save the request identifier before scheduling so a restart reuses it.
                persist()
            }
            guard let index else { continue }
            let record = state.records[index]
            let validHours = (1...48).contains(configuration.hoursBefore)
            let deadline = kind == .sensorEndingSoon ? expiry.addingTimeInterval(-Double(configuration.hoursBefore) * 3600) : expiry
            guard configuration.enabled, kind != .sensorEndingSoon || validHours else {
                scheduler.remove(identifiers: [record.identifier], delivered: true)
                if record.scheduledDate != nil {
                    trace("cancelled disabled sensor expiry reminder", log: log, category: ConstantsLog.categoryAlertManager, type: .info)
                }
                state.records[index].scheduledDate = nil
                persist()
                continue
            }
            guard !record.consumed else { continue }
            guard deadline > referenceDate else {
                // Cancel the old warning if the new warning time has already passed.
                if let oldDate = record.scheduledDate, oldDate > referenceDate {
                    scheduler.remove(identifiers: [record.identifier], delivered: false)
                    state.records[index].scheduledDate = nil
                }
                persist()
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = kind.alertTitle()
            let dateText = expiry.formatted(date: .abbreviated, time: .shortened)
            content.body = String(format: kind == .sensorEndingSoon ? Texts_Alerts.sensorEndingSoonBody : Texts_Alerts.sensorExpectedExpiryBody, dateText)
            content.threadIdentifier = "sensorExpiry"
            content.interruptionLevel = .active
            if let name = configuration.soundName {
                if !name.isEmpty { content.sound = UNNotificationSound(named: UNNotificationSoundName(name)) }
            } else {
                content.sound = .default
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: deadline)
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            let request = UNNotificationRequest(identifier: record.identifier, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            if let existing = pending.first(where: { $0.identifier == record.identifier }),
               existing.content == content, existing.trigger == request.trigger {
                // The pending request confirms scheduling completed before the app stopped.
                state.records[index].scheduledDate = deadline
                persist()
                continue
            }

            do {
                try await scheduler.add(request)
                guard generation == revision else {
                    // This request may already have fired while the settings were changing.
                    if deadline <= now() {
                        state.records[index].scheduledDate = deadline
                        state.records[index].consumed = true
                        persist()
                    }
                    scheduler.remove(identifiers: [record.identifier], delivered: false)
                    continue
                }
                state.records[index].scheduledDate = deadline
                persist()
                trace("scheduled sensor expiry reminder '%{public}@' for %{public}@", log: log, category: ConstantsLog.categoryAlertManager, type: .info, kind.descriptionForLogging(), deadline.description)
            } catch {
                needsRetry = true
                trace("unable to schedule sensor expiry reminder: %{public}@", log: log, category: ConstantsLog.categoryAlertManager, type: .error, error.localizedDescription)
            }
        }
    }

    private func persist() {
        guard state != savedState, let data = try? JSONEncoder().encode(state) else { return }
        // Update savedState first to avoid repeated writes from defaults observers.
        savedState = state
        defaults.set(data, forKey: Self.storageKey)
    }
}
