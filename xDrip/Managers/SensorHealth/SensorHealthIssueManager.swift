//
//  SensorHealthIssueManager.swift
//  xdrip
//
//  Created by Paul Plant on 2/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import Foundation
import os
import UserNotifications

/// Owns the active sensor-health episode and all of its presentation state.
///
/// Noise calculation and transmitter decoding stay with their source-specific components. They
/// report typed results here so Home and notification presentation use the same episode state.
///
/// Sensor-health warnings are not normal glucose alarms. They do not need values, schedules,
/// repeating cycles or snooze state. Keeping them here prevents `AlertManager` from treating a
/// recoverable sensor condition like a glucose alarm. Home observes `visibleIssue` and presents a
/// dismissible banner. This manager sends one iOS notification for eligible background episodes.
///
/// A confirmed terminal sensor or transmitter failure is the exception. It is a real one-off
/// alarm, so this manager passes only that event to `AlertManager`. `AlertManager` applies the
/// user's Sensor/Transmitter Failure setting and Alert Type without adding repeat or snooze
/// behavior.
final class SensorHealthIssueManager: ObservableObject {
    static let notificationIdentifierPrefix = "sensorHealth."
    private static let testEpisodePrefix = "sensorHealth.test."
    static let notificationIsTerminalUserInfoKey = "sensorHealthIsTerminal"

    @Published private(set) var visibleIssue: SensorHealthIssue?

    private struct TemporaryStatus: Codable, Equatable {
        let source: SensorHealthSource
        let reason: SensorHealthReason
        let firstSeen: Date
        let sensorSessionID: String
    }

    private struct PersistedState: Codable {
        var activeIssue: SensorHealthIssue?
        var dismissedEpisodeID: String?
        var notifiedEpisodeID: String?
        var temporaryStatus: TemporaryStatus?
        var noiseRecoveryStartedAt: Date?
        var sessionID: String?
        var sessionStartDate: Date?
    }

    private enum Storage {
        static let state = "sensorHealthIssueManager.state"
    }

    private static let temporaryIssuePersistence: TimeInterval = .hours(3)
    private static let persistentNoiseRecovery: TimeInterval = .hours(1)

    private let userDefaults: UserDefaults
    private let notificationCenter: SensorHealthNotificationScheduling
    private let log = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categoryApplicationDataSensors
    )
    private weak var oneOffAlarmRaiser: SensorHealthOneOffAlarmRaising?
    private var persistedState: PersistedState

    init(
        userDefaults: UserDefaults = .standard,
        notificationCenter: SensorHealthNotificationScheduling = UNUserNotificationCenter.current()
    ) {
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter

        if let data = userDefaults.data(forKey: Storage.state),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            persistedState = state
        } else {
            persistedState = PersistedState()
        }

        if persistedState.dismissedEpisodeID == persistedState.activeIssue?.id {
            visibleIssue = nil
        } else {
            visibleIssue = persistedState.activeIssue
        }
    }

    /// Connects only confirmed terminal failures to their configured delivery in `AlertManager`.
    func configure(oneOffAlarmRaiser: SensorHealthOneOffAlarmRaising) {
        self.oneOffAlarmRaiser = oneOffAlarmRaiser
    }

    /// Reconciles calculated sensor state after each stored noise update.
    func reportCalculatedState(
        sensorID: String,
        sensorStartDate: Date,
        measurement: SensorNoiseMeasurement,
        persistence: SensorNoisePersistenceAssessment,
        sensitivity: SensorNoiseSensitivity,
        now: Date = Date()
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.reportCalculatedState(
                    sensorID: sensorID,
                    sensorStartDate: sensorStartDate,
                    measurement: measurement,
                    persistence: persistence,
                    sensitivity: sensitivity,
                    now: now
                )
            }
            return
        }

        // `showSensorNoise` controls optional presentation on Home, charts, Watch and Live Activity.
        // It must never gate calculation, episode detection or Activity Log collection: a hidden UI
        // preference must not erase the evidence that explains why a sensor-health alert appeared.
        let sessionID = reconcileSession(sensorID: sensorID, sensorStartDate: sensorStartDate)

        if measurement.state == .flatlineSuspected {
            persistedState.noiseRecoveryStartedAt = nil
            activate(
                kind: .flatline,
                severity: .actionRequired,
                source: .calculatedNoise,
                reason: .flatline,
                sessionID: sessionID,
                now: now
            )
            saveState()
            return
        }

        resolve(kind: .flatline)

        let veryHighThreshold = ConstantsSensorNoise.threshold(
            ConstantsSensorNoise.veryHighNoiseStandardDeviation,
            sensitivity: sensitivity
        )
        let meetsPersistentNoiseRule = (persistence.value ?? -.infinity) >= veryHighThreshold
            && (measurement.longTermNoise ?? -.infinity) >= veryHighThreshold

        if meetsPersistentNoiseRule {
            persistedState.noiseRecoveryStartedAt = nil
            activate(
                kind: .persistentNoise,
                severity: .actionRequired,
                source: .calculatedNoise,
                reason: .persistentNoise,
                sessionID: sessionID,
                now: now
            )
        } else if persistedState.activeIssue?.kind == .persistentNoise {
            if let recoveryStartedAt = persistedState.noiseRecoveryStartedAt {
                if now.timeIntervalSince(recoveryStartedAt) >= Self.persistentNoiseRecovery {
                    resolve(kind: .persistentNoise)
                    persistedState.noiseRecoveryStartedAt = nil
                }
            } else {
                persistedState.noiseRecoveryStartedAt = now
            }
        } else {
            persistedState.noiseRecoveryStartedAt = nil
        }

        saveState()
    }

    /// Reconciles a decoded transmitter state without treating generic BLE errors as sensor health.
    func report(
        _ event: CGMSensorHealthEvent,
        sensorID: String?,
        sensorStartDate: Date?,
        now: Date = Date()
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.report(event, sensorID: sensorID, sensorStartDate: sensorStartDate, now: now)
            }
            return
        }

        let sessionID = reconcileSession(
            sensorID: sensorID ?? persistedState.sessionID ?? "transmitter",
            sensorStartDate: sensorStartDate ?? persistedState.sessionStartDate ?? now
        )

        switch event {
        case .recovered:
            persistedState.temporaryStatus = nil
            resolve(kind: .temporaryTransmitterIssue)

        case let .temporary(source, reason):
            let existing = persistedState.temporaryStatus
            let temporaryStatus: TemporaryStatus

            if let existing,
               existing.source == source,
               existing.reason == reason,
               existing.sensorSessionID == sessionID {
                temporaryStatus = existing
            } else {
                temporaryStatus = TemporaryStatus(
                    source: source,
                    reason: reason,
                    firstSeen: now,
                    sensorSessionID: sessionID
                )
                persistedState.temporaryStatus = temporaryStatus
                resolve(kind: .temporaryTransmitterIssue)

                // A recoverable transmitter state is useful support evidence from its first
                // occurrence even though it does not become a user-facing warning for three hours.
                // Record only this new-condition boundary so five-minute transmitter reports do
                // not flood the Activity Log.
                recordTroubleshootingCondition(reason: reason, now: now, transition: "observed")
            }

            if now.timeIntervalSince(temporaryStatus.firstSeen) >= Self.temporaryIssuePersistence {
                activate(
                    kind: .temporaryTransmitterIssue,
                    severity: .caution,
                    source: source,
                    reason: reason,
                    sessionID: sessionID,
                    firstSeen: temporaryStatus.firstSeen,
                    now: now
                )
            }

        case let .terminal(source, reason):
            persistedState.temporaryStatus = nil
            activate(
                kind: .terminalFailure,
                severity: .terminal,
                source: source,
                reason: reason,
                sessionID: sessionID,
                now: now
            )
        }

        saveState()
    }

    /// Hides the current episode until its source genuinely recovers or a new sensor starts.
    func dismissVisibleIssue() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.dismissVisibleIssue() }
            return
        }

        if let visibleIssue, visibleIssue.id.hasPrefix(Self.testEpisodePrefix) {
            removeNotification(for: visibleIssue)

            if persistedState.dismissedEpisodeID == persistedState.activeIssue?.id {
                self.visibleIssue = nil
            } else {
                self.visibleIssue = persistedState.activeIssue
            }
            return
        }

        guard let activeIssue = persistedState.activeIssue else { return }

        persistedState.dismissedEpisodeID = activeIssue.id
        visibleIssue = nil
        removeNotification(for: activeIssue)
        saveState()
    }

    /// Queues an isolated synthetic presentation without changing the real sensor episode state.
    /// Each invocation has a unique identity so several test alarms can be queued together.
    func queueTestIssue(_ testKind: SensorHealthTestKind, after delay: TimeInterval = 5) {
        let issueID = Self.testEpisodePrefix + UUID().uuidString

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }

            let values = testKind.issueValues
            let issue = SensorHealthIssue(
                id: issueID,
                kind: values.kind,
                severity: values.severity,
                source: values.source,
                reason: values.reason,
                firstSeen: Date(),
                sensorSessionID: "test",
                destination: values.destination
            )

            self.visibleIssue = issue

            if issue.severity == .terminal {
                self.oneOffAlarmRaiser?.raiseOneOffSensorFailureAlarm(issue)
            } else if issue.reason != .persistentNoise {
                self.scheduleTestWarningNotification(for: issue)
            }
        }
    }

    // MARK: - Episode state

    /// Keeps episode identity tied to one sensor session and clears state when the session changes.
    @discardableResult private func reconcileSession(
        sensorID: String,
        sensorStartDate: Date
    ) -> String {
        let sessionStartDateDifference = persistedState.sessionStartDate.map {
            abs($0.timeIntervalSince(sensorStartDate))
        }

        if let existingSessionID = persistedState.sessionID,
           let sessionStartDateDifference,
           sessionStartDateDifference <= ConstantsSensorNoise.sessionStartDateReachBackTolerance {
            return existingSessionID
        }

        if let activeIssue = persistedState.activeIssue {
            removeNotification(for: activeIssue)
        }

        persistedState = PersistedState(
            activeIssue: nil,
            dismissedEpisodeID: nil,
            notifiedEpisodeID: nil,
            temporaryStatus: nil,
            noiseRecoveryStartedAt: nil,
            sessionID: sensorID,
            sessionStartDate: sensorStartDate
        )
        visibleIssue = nil
        saveState()
        return sensorID
    }

    /// Replaces the current episode only when the new condition has a higher priority.
    private func activate(
        kind: SensorHealthIssueKind,
        severity: SensorHealthSeverity,
        source: SensorHealthSource,
        reason: SensorHealthReason,
        sessionID: String,
        firstSeen: Date? = nil,
        now: Date
    ) {
        if persistedState.activeIssue?.kind == .terminalFailure { return }

        if let activeIssue = persistedState.activeIssue {
            if activeIssue.kind == kind,
               activeIssue.reason == reason,
               activeIssue.sensorSessionID == sessionID {
                return
            }

            guard kind.priority > activeIssue.kind.priority else { return }
            removeNotification(for: activeIssue)
        }

        let firstSeen = firstSeen ?? now
        let issueID = Self.episodeID(sessionID: sessionID, kind: kind, firstSeen: firstSeen)
        let issue = SensorHealthIssue(
            id: issueID,
            kind: kind,
            severity: severity,
            source: source,
            reason: reason,
            firstSeen: firstSeen,
            sensorSessionID: sessionID,
            destination: source == .calculatedNoise ? .sensorManagement : .bluetoothPeripheral
        )

        persistedState.activeIssue = issue
        persistedState.dismissedEpisodeID = nil
        visibleIssue = issue

        // Temporary transmitter conditions are recorded when first observed, before their
        // three-hour warning boundary. Every other condition first becomes reportable here.
        if kind != .temporaryTransmitterIssue {
            recordTroubleshootingCondition(reason: reason, now: now, transition: "activated")
        }

        scheduleNotificationIfNeeded(for: issue)
    }

    /// Records a controlled, share-safe condition without sensor IDs or raw transmitter data.
    private func recordTroubleshootingCondition(
        reason: SensorHealthReason,
        now: Date,
        transition: String
    ) {
        let troubleshootingAlert: TroubleshootingSensorHealthAlert
        switch reason {
        case .persistentNoise:
            troubleshootingAlert = .persistentNoise
        case .flatline:
            troubleshootingAlert = .possibleFlatline
        case .dexcomExcessNoise:
            troubleshootingAlert = .dexcomExcessNoise
        case .dexcomTemporarySensorIssue:
            troubleshootingAlert = .dexcomTemporarySensorIssue
        case .dexcomQuestionMarks:
            troubleshootingAlert = .dexcomQuestionMarks
        case .dexcomSensorFailure:
            troubleshootingAlert = .dexcomSensorFailure
        case .dexcomTransmitterFailure:
            troubleshootingAlert = .dexcomTransmitterFailure
        case .libreSensorFailure:
            troubleshootingAlert = .libreSensorFailure
        case .dexcomTransmitterBatteryFailure:
            troubleshootingAlert = .dexcomTransmitterBatteryFailure
        }

        trace(
            "sensor-health condition %{public}@: %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataSensors,
            type: .info,
            troubleshooting: .standard(.sensorHealthAlert(troubleshootingAlert), timestamp: now),
            transition,
            troubleshootingAlert.rawValue
        )
    }

    /// Clears the matching episode without disturbing a different active condition.
    private func resolve(kind: SensorHealthIssueKind) {
        guard let activeIssue = persistedState.activeIssue, activeIssue.kind == kind else { return }

        removeNotification(for: activeIssue)
        persistedState.activeIssue = nil
        persistedState.dismissedEpisodeID = nil
        persistedState.notifiedEpisodeID = nil
        visibleIssue = nil
    }

    /// Delivers each eligible episode once and routes terminal failures through AlertManager.
    private func scheduleNotificationIfNeeded(for issue: SensorHealthIssue) {
        guard persistedState.notifiedEpisodeID != issue.id else { return }

        if issue.severity == .terminal {
            // A confirmed terminal report is a real alarm. It enters AlertManager once so the
            // user keeps control of its enabled state and Alert Type from the main Alerts screen.
            persistedState.notifiedEpisodeID = issue.id
            oneOffAlarmRaiser?.raiseOneOffSensorFailureAlarm(issue)
            return
        }

        // Nonterminal issues remain sensor-health warnings. They never enter AlertManager because
        // they have no values, alarm cycle, repeat behavior or snooze state.

        // Sustained calculated noise is already visible on Home and in Noise History. It stays
        // in-app only because it does not need a system interruption.
        guard issue.reason != .persistentNoise else { return }
        guard userDefaults.sensorHealthNotificationsEnabled else { return }
        persistedState.notifiedEpisodeID = issue.id

        let content = UNMutableNotificationContent()
        content.title = issue.title
        content.body = issue.guidance
        content.threadIdentifier = "sensorHealth"
        content.interruptionLevel = .active
        content.userInfo = [
            Self.notificationIsTerminalUserInfoKey: issue.severity == .terminal
        ]

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifierPrefix + issue.id,
            content: content,
            trigger: nil
        )
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    private func scheduleTestWarningNotification(for issue: SensorHealthIssue) {
        let content = UNMutableNotificationContent()
        content.title = issue.title
        content.body = issue.guidance
        content.threadIdentifier = "sensorHealth"
        content.interruptionLevel = .active
        content.userInfo = [
            Self.notificationIsTerminalUserInfoKey: false
        ]

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifierPrefix + issue.id,
            content: content,
            trigger: nil
        )
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    private func removeNotification(for issue: SensorHealthIssue) {
        let identifier = Self.notificationIdentifierPrefix + issue.id
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func saveState() {
        guard let data = try? JSONEncoder().encode(persistedState) else { return }
        userDefaults.set(data, forKey: Storage.state)
    }

    private static func episodeID(sessionID: String, kind: SensorHealthIssueKind, firstSeen: Date) -> String {
        let safeSessionID = sessionID.replacingOccurrences(of: ".", with: "-")
        return safeSessionID + "." + kind.rawValue + "." + String(Int(firstSeen.timeIntervalSince1970))
    }
}
