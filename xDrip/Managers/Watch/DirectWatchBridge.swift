//
//  DirectWatchBridge.swift
//  xDrip
//
//  Created by Paul Plant on 12/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK: - Transmitter roles and collection policy

enum DirectWatchTransmitterFamily: String, Codable {
    case g6
    case g7

    func availableSlots(isAnubis: Bool) -> [UInt8] {
        self == .g7 || isAnubis ? [1, 2, 3] : [1, 2]
    }
}

enum DirectWatchCollectionPolicy {
    enum InvalidConnectionRecovery: Equatable {
        case retryWithoutOptions
        case stopInvalidRequest
    }

    static func invalidConnectionRecovery(usedDelayOption: Bool) -> InvalidConnectionRecovery {
        usedDelayOption ? .retryWithoutOptions : .stopInvalidRequest
    }
    enum PendingRecovery: Equatable {
        case wait
        case retrySavedPeripheral
        case discoverInForeground
    }

    // Leave a pending CoreBluetooth connection in place across a complete transmitter cycle.
    static let pendingConnectionLimit: TimeInterval = 6 * 60
    static let discoveryFallbackLimit: TimeInterval = 6 * 60
    static let savedPeripheralRetriesBeforeDiscovery = 2
    static let phoneLinkTimeout: TimeInterval = 60
    static let liveSyncReplyTimeout: TimeInterval = 30

    /// Resume starts a new wait. A later Bluetooth connection resets it again.
    static func counterReference(resumedAt: Date?, lastConnectedAt: Date?) -> Date? {
        [resumedAt, lastConnectedAt].compactMap { $0 }.max()
    }

    static func counterElapsed(resumedAt: Date?, lastConnectedAt: Date?, isPaused: Bool, now: Date) -> TimeInterval? {
        guard !isPaused, let reference = counterReference(resumedAt: resumedAt, lastConnectedAt: lastConnectedAt) else { return nil }
        return max(0, now.timeIntervalSince(reference))
    }

    /// Let G6 finish its current advertising window without repeatedly authenticating
    /// the same sample. CoreBluetooth owns this delay even while watchOS suspends us.
    static func reconnectDelay(family: DirectWatchTransmitterFamily, completedAt: Date?, failedAttempts: Int, now: Date) -> TimeInterval {
        let cycleDelay: TimeInterval
        if family == .g6, let completedAt {
            // Clamp backward clock changes as well as the completed advertising window.
            let elapsed = max(0, now.timeIntervalSince(completedAt))
            cycleDelay = max(0, 60 - elapsed)
        } else { cycleDelay = 0 }
        let failureDelay: TimeInterval = failedAttempts > 0 ? min(30, pow(2, Double(min(failedAttempts, 5)))) : 0
        return max(cycleDelay, failureDelay)
    }

    static func pendingRecovery(startedAt: Date?, now: Date, isForeground: Bool, savedRetryCount: Int) -> PendingRecovery {
        guard let startedAt else { return .wait }
        let age = now.timeIntervalSince(startedAt)
        if !isForeground {
            // A restored request can remain connecting for hours without a failure callback.
            // Use an execution opportunity already granted by watchOS to retry the same bond,
            // but leave several complete transmitter cycles alone first. Issuing the retry
            // resets startedAt, so repeated phone messages cannot create a cancellation loop.
            // Discovery and central-manager recreation remain foreground-only recovery.
            return age >= ConstantsDirectWatch.readingOverdueAfter ? .retrySavedPeripheral : .wait
        }
        guard age >= pendingConnectionLimit else { return .wait }
        return savedRetryCount < savedPeripheralRetriesBeforeDiscovery ? .retrySavedPeripheral : .discoverInForeground
    }

    static func requiresBluetoothRestart(previous: DirectWatchConfiguration?, next: DirectWatchConfiguration?) -> Bool {
        previous?.transmitterID != next?.transmitterID
            || previous?.transmitterFamily != next?.transmitterFamily
            || previous?.slot != next?.slot
            || previous?.sensorStartDate != next?.sensorStartDate
            || previous?.pairingCode != next?.pairingCode
    }
}

// MARK: - Local Watch alert policy

/// Send the full daily schedule so crossing midnight or leaving the phone behind does not
/// leave the Watch using yesterday's threshold. Values are always stored in mg/dL.
/// Phone enabled/disabled flags are intentionally omitted. Only the Watch switches decide
/// whether these thresholds can issue local notifications.
struct DirectWatchAlertEntry: Codable, Equatable {
    let startMinute: Int
    let threshold: Double

    var isValid: Bool { (0..<1440).contains(startMinute) && threshold.isFinite && threshold > 0 }

    static func current(in entries: [Self]?, at date: Date, calendar: Calendar = .current) -> Self? {
        guard let entries, !entries.isEmpty, entries.allSatisfy(\.isValid) else { return nil }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let sorted = entries.sorted { $0.startMinute < $1.startMinute }
        return sorted.last { $0.startMinute <= minute } ?? sorted.last
    }
}

enum DirectWatchAlertPolicy {
    enum GlucoseAlert: String { case urgentLow, low }

    /// Queued transfers do not prove a live connection. Only successful live exchanges
    /// advance this clock. At exactly sixty seconds the phone still owns notifications.
    static func mayNotify(collecting: Bool, lastPhoneContact: Date?, now: Date) -> Bool {
        collecting && (lastPhoneContact.map { now.timeIntervalSince($0) > DirectWatchCollectionPolicy.phoneLinkTimeout } ?? true)
    }

    static func glucoseAlert(value: Double, measuredAt: Date, now: Date,
                             urgent: DirectWatchAlertEntry?, low: DirectWatchAlertEntry?,
                             urgentEnabled: Bool, lowEnabled: Bool,
                             lastUrgent: Date?, lastLow: Date?) -> GlucoseAlert? {
        let age = now.timeIntervalSince(measuredAt)
        guard value.isFinite, value > 0, age >= -60, age <= ConstantsDirectWatch.readingDelayedAfter else { return nil }
        func cooledDown(_ date: Date?) -> Bool {
            date.map { now.timeIntervalSince($0) >= ConstantsDirectWatch.glucoseAlertRepeatInterval } ?? true
        }
        if urgentEnabled, let urgent, value < urgent.threshold {
            // Never downgrade an urgent condition to Low while its repeat timer is active.
            return cooledDown(lastUrgent) ? .urgentLow : nil
        }
        if lowEnabled, let low, value < low.threshold,
           cooledDown(lastLow), cooledDown(lastUrgent) { return .low }
        return nil
    }

    /// A pending OS notification cannot run a reachability check at delivery time. Move its
    /// deadline on each live exchange so it can never fire inside the recent-contact window.
    static func missedReadingDeadline(collectedAt: Date, lastPhoneContact: Date?) -> Date {
        let missed = collectedAt.addingTimeInterval(ConstantsDirectWatch.missedReadingNotificationDelay)
        return max(missed, lastPhoneContact?.addingTimeInterval(DirectWatchCollectionPolicy.phoneLinkTimeout + 1) ?? missed)
    }
}

// MARK: - Setup and cross-device controls

/// Identifies the Bluetooth binding independently of sensor dates and display settings.
struct DirectWatchConnectionIdentity: Codable, Equatable {
    let transmitterID: String
    let family: DirectWatchTransmitterFamily
    let slot: UInt8
}

/// A separate clock keeps offline Watch choices independent of phone configuration updates.
/// UUID ordering resolves simultaneous changes consistently on both devices.
struct DirectWatchCollectionControl: Codable, Equatable {
    let connection: DirectWatchConnectionIdentity
    let isPaused: Bool
    let revision: Double
    let id: String
    // Optional for controls saved before the resume counter was introduced.
    let changedAt: Date?

    init(connection: DirectWatchConnectionIdentity, isPaused: Bool,
         previousRevision: Double = 0, now: Date = .now) {
        self.connection = connection
        self.isPaused = isPaused
        revision = max(now.timeIntervalSince1970, previousRevision + 1)
        id = UUID().uuidString
        changedAt = now
    }

    func resumedAt(for connection: DirectWatchConnectionIdentity?) -> Date? {
        self.connection == connection && !isPaused ? changedAt : nil
    }

    func isNewer(than previous: DirectWatchCollectionControl?) -> Bool {
        guard revision.isFinite, revision > 0 else { return false }
        guard let previous else { return true }
        return revision > previous.revision || (revision == previous.revision && id > previous.id)
    }

    func supersedes(_ previous: Self?, for connection: DirectWatchConnectionIdentity?) -> Bool {
        self.connection == connection && isNewer(than: previous?.connection == connection ? previous : nil)
    }

    static func decode(_ payload: [String: Any]) -> DirectWatchCollectionControl? {
        guard let data = payload["directWatchCollectionControl"] as? Data, data.count <= 2048,
              let control = try? JSONDecoder().decode(Self.self, from: data),
              control.revision.isFinite, control.revision > 0, UUID(uuidString: control.id) != nil else { return nil }
        return control
    }

    var payload: [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return ["directWatchCollectionControl": data]
    }
}

/// Connection telemetry is separate from readings: an authenticated reading may follow later.
struct DirectWatchConnectionEvent: Codable {
    let connection: DirectWatchConnectionIdentity
    let connectedAt: Date
    let controlID: String?

    func matches(_ configuration: DirectWatchConfiguration, control: DirectWatchCollectionControl?, now: Date) -> Bool {
        connection == configuration.connectionIdentity && controlID == control?.id
            && connectedAt.timeIntervalSince1970.isFinite && connectedAt >= configuration.sensorStartDate
            && connectedAt <= now.addingTimeInterval(60)
    }

    static func decode(_ payload: [String: Any]) -> Self? {
        guard let data = payload["directWatchConnectionEvent"] as? Data, data.count <= 2048 else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    var payload: [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return ["directWatchConnectionEvent": data]
    }
}

/// Configuration shared by the phone and Watch, without Core Data or Bluetooth objects.
struct DirectWatchConfiguration: Codable, Equatable {
    let transmitterID: String
    let slot: UInt8
    let isAnubis: Bool
    var sensorStartDate: Date
    var isMgDl: Bool
    var low: Double
    var high: Double
    // Older stored configurations may not contain the family or pairing code.
    var family: DirectWatchTransmitterFamily? = nil
    var pairingCode: String? = nil
    var deviceName: String? = nil
    // Optional so older phone and Watch builds can still exchange collection configuration.
    // Missing or invalid schedules silence their alerts without stopping Bluetooth collection.
    var urgentLowSchedule: [DirectWatchAlertEntry]? = nil
    var lowSchedule: [DirectWatchAlertEntry]? = nil

    var transmitterFamily: DirectWatchTransmitterFamily { family ?? .g6 }
    var connectionIdentity: DirectWatchConnectionIdentity {
        DirectWatchConnectionIdentity(transmitterID: transmitterID, family: transmitterFamily, slot: slot)
    }

    func isValid(phoneSlot: UInt8? = nil) -> Bool {
        guard transmitterFamily.availableSlots(isAnubis: isAnubis).contains(slot), slot != phoneSlot,
              sensorStartDate.timeIntervalSince1970.isFinite,
              low.isFinite, high.isFinite, low > 0, high > low else { return false }
        switch transmitterFamily {
        case .g6:
            return transmitterID.count == 6 && transmitterID.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        case .g7:
            return transmitterID.uppercased().hasPrefix("DX") && transmitterID.count >= 4
                && pairingCode?.count == 4 && pairingCode?.allSatisfy(\.isNumber) == true
        }
    }
}

// MARK: - Durable readings and local session boundaries

/// Local collection sessions use the time the Watch applies a choice, not the phone's request time.
struct DirectWatchCollectionSession: Codable, Equatable, Identifiable {
    let id: UUID
    let connection: DirectWatchConnectionIdentity
    let startedAt: Date
    let isResume: Bool
    var endedAt: Date?
    var endedByPause: Bool = false
    // Preserve this identity after old acknowledged readings expire from the local history.
    // Otherwise the oldest retained reading would incorrectly look like the session's first.
    var firstReadingID: String? = nil

    /// Acquisition times keep delayed phone sync and backfill timestamps separate from collection sessions.
    func intervalBefore(_ reading: DirectWatchReading, in readings: [DirectWatchReading]) -> TimeInterval? {
        guard reading.collectionSessionID == id, let collectedAt = reading.collectedAt else { return nil }
        let previous = readings.lazy.filter { $0.collectionSessionID == id && $0.id != reading.id }
            .compactMap(\.collectedAt).filter { $0 < collectedAt }.max()
        guard previous != nil || firstReadingID == nil || firstReadingID == reading.id else { return nil }
        return max(0, collectedAt.timeIntervalSince(previous ?? startedAt))
    }

    static func update(_ sessions: inout [Self], collecting: Bool, connection: DirectWatchConnectionIdentity?,
                       paused: Bool, now: Date) {
        if let index = sessions.indices.last, sessions[index].endedAt == nil {
            if collecting && sessions[index].connection == connection { return }
            sessions[index].endedAt = now
            sessions[index].endedByPause = paused
        }
        if collecting, let connection {
            let isResume = sessions.last.map { $0.connection == connection && $0.endedByPause } ?? false
            sessions.append(Self(id: UUID(), connection: connection, startedAt: now, isResume: isResume))
        }
    }
}

struct DirectWatchReading: Codable, Equatable, Identifiable {
    let transmitterID: String
    let sensorStartCounter: UInt32
    let sensorStartDate: Date
    let transmitterSeconds: UInt32
    let measuredAt: Date
    let mgDl: Double
    let state: UInt8
    var family: DirectWatchTransmitterFamily? = nil
    /// When the Watch obtained this value from the transmitter, independent of phone sync.
    var collectedAt: Date? = nil
    // Older readings stay ungrouped. Backfilled values belong to the session that collected them.
    var collectionSessionID: UUID? = nil

    var id: String { "\(family == .g7 ? "g7:" : "")\(transmitterID):\(sensorStartCounter):\(transmitterSeconds)" }
    var isUsable: Bool { (state == 6 || state == 7) && mgDl.isFinite && (12...400).contains(mgDl) }
    var isWatchBackfill: Bool {
        guard let collectedAt else { return false }
        return collectedAt.timeIntervalSince(measuredAt) >= ConstantsDirectWatch.minimumWatchBackfillAge
    }

    /// Accept only this transmitter's active sensor, plausible native values and nonfuture samples.
    /// The phone repeats this validation before importing or acknowledging a Watch batch.
    func belongs(to configuration: DirectWatchConfiguration, now: Date = Date()) -> Bool {
        transmitterID == configuration.transmitterID && (family ?? .g6) == configuration.transmitterFamily && isUsable
            && abs(sensorStartDate.timeIntervalSince(configuration.sensorStartDate)) <= 120
            && measuredAt >= sensorStartDate && measuredAt <= now.addingTimeInterval(60)
            && transmitterSeconds >= sensorStartCounter && sensorStartCounter > 0
    }
}

// MARK: - Phone settings and validated collector telemetry

/// Only the configured binding owns these settings. This never alters glucose provenance in Core Data.
enum DirectWatchSettings {
    static let changed = Notification.Name("DirectWatchConfigurationChanged")
    static let statusChanged = Notification.Name("DirectWatchStatusChanged")
    static let requestLogs = Notification.Name("DirectWatchRequestLogs")
    static let logsChanged = Notification.Name("DirectWatchLogsChanged")
    static let logsRequestedDateKey = "directWatch.logsRequestedDate"
    static let logsReceivedDateKey = "directWatch.logsReceivedDate"
    static let logsFailedKey = "directWatch.logsFailed"
    static let collectionControlKey = "directWatch.collectionControl"
    static let collectionControlClockKey = "directWatch.collectionControlClock"
    static let configurationKey = "directWatch.configuration.v1"
    static let pausedKey = "directWatch.pausedPhoneTransmitter"
    static let revisionKey = "directWatch.configurationRevision"
    static let lastConnectedDateKey = "directWatch.lastConnectedDate"
    static let lastCollectedDateKey = "directWatch.lastCollectedDate"
    static let lastContactDateKey = "directWatch.lastContactDate"
    static let lastStatusKey = "directWatch.lastStatus"
    static let lastStatusDateKey = "directWatch.lastStatusDate"
    static let unavailableReasonKey = "directWatch.unavailableReason"

    static var collectionControl: DirectWatchCollectionControl? {
        UserDefaults.standard.data(forKey: collectionControlKey)
            .flatMap { try? JSONDecoder().decode(DirectWatchCollectionControl.self, from: $0) }
    }

    static var watchIsPaused: Bool {
        guard let configuration, let control = collectionControl,
              control.connection == configuration.connectionIdentity else { return false }
        return control.isPaused
    }

    static func pauseWatch(_ paused: Bool) {
        guard let configuration else { return }
        let control = DirectWatchCollectionControl(connection: configuration.connectionIdentity, isPaused: paused,
                                                    previousRevision: UserDefaults.standard.double(forKey: collectionControlClockKey))
        _ = receiveCollectionControl(control)
    }

    @discardableResult static func receiveCollectionControl(_ control: DirectWatchCollectionControl) -> Bool {
        guard let configuration, control.supersedes(collectionControl, for: configuration.connectionIdentity),
              let data = try? JSONEncoder().encode(control) else { return false }
        UserDefaults.standard.set(data, forKey: collectionControlKey)
        UserDefaults.standard.set(max(control.revision, UserDefaults.standard.double(forKey: collectionControlClockKey)), forKey: collectionControlClockKey)
        NotificationCenter.default.post(name: changed, object: nil)
        NotificationCenter.default.post(name: statusChanged, object: nil)
        return true
    }

    /// Connection events carry the current control identity. Old queued events cannot reset a
    /// resume counter for a later pause/resume choice or for another Bluetooth slot.
    static func recordConnection(_ event: DirectWatchConnectionEvent, now: Date = .now) {
        guard let configuration, event.matches(configuration, control: collectionControl, now: now) else { return }
        let previous = UserDefaults.standard.object(forKey: lastConnectedDateKey) as? Date ?? .distantPast
        guard event.connectedAt > previous else { return }
        UserDefaults.standard.set(event.connectedAt, forKey: lastConnectedDateKey)
        NotificationCenter.default.post(name: statusChanged, object: nil)
    }

    static func advanceRevision(now: Date = .now, in defaults: UserDefaults = .standard) {
        DirectWatchCompatibility.migrateSettings(in: defaults)
        defaults.set(max(now.timeIntervalSince1970, defaults.double(forKey: revisionKey) + 1), forKey: revisionKey)
    }

    /// Communication can be fresh while glucose is stale. Only acknowledged reading batches
    /// supply latestReadingAt. A heartbeat updates contact time without making readings green.
    static func recordContact(latestReadingAt: Date? = nil, now: Date = .now, in defaults: UserDefaults = .standard) {
        DirectWatchCompatibility.migrateSettings(in: defaults)
        defaults.set(now, forKey: lastContactDateKey)
        if let latestReadingAt, latestReadingAt <= now.addingTimeInterval(60) {
            let previous = defaults.object(forKey: lastCollectedDateKey) as? Date ?? .distantPast
            defaults.set(max(previous, latestReadingAt), forKey: lastCollectedDateKey)
        }
        NotificationCenter.default.post(name: statusChanged, object: nil)
    }

    static var configuration: DirectWatchConfiguration? {
        DirectWatchCompatibility.migrateSettings()
        return UserDefaults.standard.data(forKey: configurationKey).flatMap { try? JSONDecoder().decode(DirectWatchConfiguration.self, from: $0) }
    }

    /// One setup owns telemetry at a time. Reusing another slot/transmitter's reading age would
    /// make a newly added connection appear healthy before it has collected anything.
    static func clearTelemetry(in defaults: UserDefaults = .standard) {
        for key in [lastConnectedDateKey, lastCollectedDateKey, lastContactDateKey,
                    lastStatusKey, lastStatusDateKey, unavailableReasonKey] {
            defaults.removeObject(forKey: key)
        }
    }

    static func save(_ configuration: DirectWatchConfiguration?) {
        DirectWatchCompatibility.migrateSettings()
        let previous = self.configuration
        let bindingChanged = previous?.connectionIdentity != configuration?.connectionIdentity
        let sensorChanged = previous?.sensorStartDate != configuration?.sensorStartDate
        UserDefaults.standard.set(configuration.flatMap { try? JSONEncoder().encode($0) }, forKey: configurationKey)
        advanceRevision()
        if bindingChanged || sensorChanged { clearTelemetry() }
        if configuration == nil {
            UserDefaults.standard.removeObject(forKey: pausedKey)
        } else if bindingChanged {
            // Keep the independent control clock monotonic, but start the new binding enabled.
            // A queued pause from the previous binding must never pause this one.
            pauseWatch(false)
        }
        NotificationCenter.default.post(name: changed, object: nil)
        NotificationCenter.default.post(name: statusChanged, object: nil)
    }

    /// Home and peripheral status use exactly the banner's state ordering and age thresholds.
    static func readingStatus(at date: Date = .now) -> DirectWatchReadingStatus {
        guard let configuration else { return .off }
        let collected = (UserDefaults.standard.object(forKey: lastCollectedDateKey) as? Date)
            .flatMap { $0 >= configuration.sensorStartDate ? $0 : nil }
        return DirectWatchReadingStatus(isConfigured: true,
                                       isSuspended: UserDefaults.standard.string(forKey: unavailableReasonKey) != nil,
                                       latestReadingAt: collected, now: date, isPaused: watchIsPaused,
                                       resumedAt: collectionControl?.resumedAt(for: configuration.connectionIdentity),
                                       lastConnectedAt: UserDefaults.standard.object(forKey: lastConnectedDateKey) as? Date)
    }

    static func phoneIsPaused(_ transmitterID: String) -> Bool {
        configuration?.transmitterID == transmitterID && UserDefaults.standard.string(forKey: pausedKey) == transmitterID
    }

    static func pausePhone(_ paused: Bool, transmitterID: String) {
        DirectWatchCompatibility.migrateSettings()
        UserDefaults.standard.set(paused ? transmitterID : nil, forKey: pausedKey)
        advanceRevision()
        NotificationCenter.default.post(name: changed, object: nil)
    }

    static var receivedLogURL: URL {
        DirectWatchCompatibility.logURL(in: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
    }

    /// Requesting another export must not erase the last successful receipt or its file.
    static func recordLogRequest(queued: Bool, now: Date = .now, in defaults: UserDefaults = .standard) {
        defaults.set(queued ? now : nil, forKey: logsRequestedDateKey)
        defaults.set(!queued, forKey: logsFailedKey)
        NotificationCenter.default.post(name: logsChanged, object: nil)
    }

    /// Call only after the incoming file has been saved. Transfer submission is not receipt.
    static func recordLogsReceived(now: Date = .now, in defaults: UserDefaults = .standard) {
        defaults.set(now, forKey: logsReceivedDateKey)
        defaults.removeObject(forKey: logsRequestedDateKey)
        defaults.set(false, forKey: logsFailedKey)
        NotificationCenter.default.post(name: logsChanged, object: nil)
    }
}



// MARK: - Shared status presentation

/// Reading freshness is shared by both status banners. Communication alone cannot reset it.
enum DirectWatchReadingStatus: Equatable {
    case off, paused, suspended, connecting, waiting, current, delayed, overdue

    init(isConfigured: Bool, isSuspended: Bool, latestReadingAt: Date?, now: Date, isPaused: Bool = false,
         resumedAt: Date? = nil, lastConnectedAt: Date? = nil) {
        if !isConfigured { self = .off }
        else if isPaused { self = .paused }
        else if isSuspended { self = .suspended }
        else if let resumedAt, lastConnectedAt.map({ $0 < resumedAt }) ?? true { self = .connecting }
        else if let latestReadingAt {
            self = Self(age: now.timeIntervalSince(latestReadingAt))
        } else { self = .waiting }
    }

    /// Also used for elapsed connection/session intervals, without manufacturing a reading date.
    init(age: TimeInterval) {
        if age > ConstantsDirectWatch.readingOverdueAfter { self = .overdue }
        else if age > ConstantsDirectWatch.readingDelayedAfter { self = .delayed }
        else { self = .current }
    }

    var title: String {
        switch self {
        case .connecting: TextsDirectWatch.connecting
        case .paused: TextsDirectWatch.pausedShort
        case .off: TextsDirectWatch.noConnection
        case .suspended: TextsDirectWatch.suspended
        case .waiting: TextsDirectWatch.waiting
        case .current: TextsDirectWatch.collecting
        case .delayed: TextsDirectWatch.delayed
        case .overdue: TextsDirectWatch.overdue
        }
    }
}
