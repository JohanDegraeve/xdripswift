import AVFoundation
import CoreData
import UserNotifications
import XCTest
import UIKit
@testable import xdrip

@MainActor
final class RepeatingAlarmTests: XCTestCase {
    private final class Audio: AlarmAudioPlaying {
        var numberOfLoops = 0
        weak var delegate: AVAudioPlayerDelegate?
        var starts = 0
        var stops = 0
        var pauses = 0
        var succeeds = true
        func play() -> Bool {
            starts += 1
            return succeeds
        }
        func pause() { pauses += 1 }
        func stop() { stops += 1 }
    }

    private final class AudioHarness {
        var activations = [(Error?) -> Void]()
        var players = [Audio]()
        var vibrationEvents = [() -> Void]()
        var vibrationCancellations = 0
        lazy var sound = SoundPlayer(activateSession: { [unowned self] in self.activations.append($0) }, makePlayer: { [unowned self] _ in
            let audio = Audio()
            self.players.append(audio)
            return audio
        }, scheduleVibration: { [unowned self] action in
            self.vibrationEvents.append(action)
            return { [weak self] in self?.vibrationCancellations += 1 }
        })
        func activate() { activations.removeFirst()(nil) }
    }

    func testLoopingIsOptInAndConfiguredBeforePlayback() {
        let h = AudioHarness()
        h.sound.playSound(soundFileName: "xdripalert.aif")
        XCTAssertEqual(h.players[0].numberOfLoops, 0)
        XCTAssertEqual(h.players[0].starts, 0)
        h.activate()
        XCTAssertEqual(h.players[0].starts, 1)
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        XCTAssertEqual(h.players[1].numberOfLoops, -1)
        h.activate()
        XCTAssertEqual(h.players[0].stops, 1)
        XCTAssertTrue(h.sound.isPlaying())
        h.sound.stopPlaying()
    }

    func testStoppedOrSupersededActivationCannotStart() {
        let h = AudioHarness()
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        h.sound.stopPlaying()
        h.activate()
        XCTAssertEqual(h.players[0].starts, 0)
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        h.activate()
        XCTAssertEqual(h.players[1].starts, 0)
        h.activate()
        XCTAssertEqual(h.players[2].starts, 1)
        h.sound.stopPlaying()
    }

    func testInterruptionRetainsLoopAndResumesOnlyWhenPermitted() {
        let h = AudioHarness()
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        h.activate()
        h.sound.handleInterruption(type: .began, shouldResume: false)
        XCTAssertEqual(h.players[0].pauses, 1)
        XCTAssertTrue(h.sound.isPlaying())
        h.sound.handleInterruption(type: .ended, shouldResume: false)
        XCTAssertTrue(h.activations.isEmpty)
        h.sound.handleInterruption(type: .began, shouldResume: false)
        h.sound.handleInterruption(type: .ended, shouldResume: true)
        h.activate()
        XCTAssertEqual(h.players[0].starts, 2)
        h.sound.stopPlaying()
    }

    func testAcknowledgementDuringInterruptionPreventsResumption() {
        let h = AudioHarness()
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        h.activate()
        h.sound.handleInterruption(type: .began, shouldResume: false)
        h.sound.stopPlaying()
        h.sound.handleInterruption(type: .ended, shouldResume: true)
        XCTAssertTrue(h.activations.isEmpty)
        XCTAssertFalse(h.sound.isPlaying())
    }

    func testInterruptionCancelsActivationAlreadyInFlight() {
        let h = AudioHarness()
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        h.sound.handleInterruption(type: .began, shouldResume: false)
        h.activate()
        XCTAssertEqual(h.players[0].starts, 0)
        h.sound.handleInterruption(type: .ended, shouldResume: true)
        h.activate()
        XCTAssertEqual(h.players[0].starts, 1)
        h.sound.stopPlaying()
    }

    func testReplacementDuringInterruptionOnlyResumesNewAlarm() {
        let h = AudioHarness()
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        h.activate()
        h.sound.handleInterruption(type: .began, shouldResume: false)
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        XCTAssertTrue(h.activations.isEmpty)
        h.sound.handleInterruption(type: .ended, shouldResume: true)
        h.activate()
        XCTAssertEqual(h.players[0].starts, 1)
        XCTAssertEqual(h.players[1].starts, 1)
        h.sound.stopPlaying()
    }

    func testSinglePlaybackArrivingDuringInterruptionCanStartAfterCall() {
        let h = AudioHarness()
        h.sound.handleInterruption(type: .began, shouldResume: false)
        h.sound.playSound(soundFileName: "xdripalert.aif")
        XCTAssertTrue(h.activations.isEmpty)
        h.sound.handleInterruption(type: .ended, shouldResume: true)
        h.activate()
        XCTAssertEqual(h.players[0].starts, 1)
        XCTAssertEqual(h.players[0].numberOfLoops, 0)
        h.sound.stopPlaying()
    }

    func testSinglePlaybackReleasesOwnershipIfResumptionIsNotPermitted() {
        let h = AudioHarness()
        h.sound.handleInterruption(type: .began, shouldResume: false)
        h.sound.playSound(soundFileName: "xdripalert.aif")
        h.sound.handleInterruption(type: .ended, shouldResume: false)
        XCTAssertFalse(h.sound.isPlaying())
        XCTAssertTrue(h.activations.isEmpty)
    }

    func testOldCompletionCannotStopReplacementPlayer() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "xdripalert.aif", withExtension: ""))
        let first = try AVAudioPlayer(contentsOf: url)
        let second = try AVAudioPlayer(contentsOf: url)
        var players = [first, second]
        let sound = SoundPlayer(activateSession: { _ in }, makePlayer: { _ in players.removeFirst() })
        sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        sound.audioPlayerDidFinishPlaying(first, successfully: true)
        XCTAssertTrue(sound.isPlaying())
        sound.audioPlayerDecodeErrorDidOccur(second, error: CocoaError(.fileReadCorruptFile))
        XCTAssertFalse(sound.isPlaying())
    }

    func testFailuresReleasePlaybackAndCallCompletionOnce() {
        let h = AudioHarness()
        var completions = 0
        h.sound.playSound(soundFileName: "missing-alarm-file", repeatSound: true, onFinished: { completions += 1 })
        XCTAssertFalse(h.sound.isPlaying())
        XCTAssertEqual(completions, 1)
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true, onFinished: { completions += 1 })
        h.players[0].succeeds = false
        h.activate()
        XCTAssertFalse(h.sound.isPlaying())
        XCTAssertEqual(completions, 2)
        h.sound.stopPlaying()
        XCTAssertEqual(completions, 2)
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true, onFinished: { completions += 1 })
        h.activations.removeFirst()(CocoaError(.fileReadUnknown))
        XCTAssertFalse(h.sound.isPlaying())
        XCTAssertEqual(completions, 3)
        XCTAssertEqual(h.players[1].starts, 0)
    }

    private func setupAlarm() -> (CoreDataManager, AlertManager, AlertType, AudioHarness) {
        let core = CoreDataManager(inMemoryModelName: "xdrip")
        let type = AlertType(enabled: true, name: "Repeating alarm", overrideMute: true, snooze: true,
                             snoozePeriod: 30, vibrate: false, soundName: "xDrip", alertEntries: nil,
                             nsManagedObjectContext: core.mainManagedObjectContext, repeatSound: true)
        let h = AudioHarness()
        let manager = AlertManager(coreDataManager: core, soundPlayer: h.sound)
        return (core, manager, type, h)
    }

    @discardableResult
    private func present(_ manager: AlertManager, _ type: AlertType, _ kind: AlertKind, sound: String? = "xdripalert.aif", entry: AlertEntry? = nil) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        manager.presentImmediateSound(alertKind: kind, alertType: type, entry: entry, soundFileName: sound, content: content)
        return content
    }

    func testUrgencyProtectionAndSameAlarmDoesNotRestart() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        let content = present(manager, type, .verylow)
        h.activate()
        _ = present(manager, type, .verylow)
        _ = present(manager, type, .low)
        XCTAssertEqual(h.players.count, 1)
        XCTAssertEqual(manager.protectedAlarmNotificationIdentifier, AlertKind.verylow.notificationIdentifier())
        _ = present(manager, type, .fastdrop)
        h.activate()
        XCTAssertEqual(h.players.count, 2)
        manager.stopAlarmSound(alertKind: .verylow, content: content)
        XCTAssertTrue(h.sound.isPlaying())
    }

    func testHigherUrgencyAndSinglePlaybackCanReplaceLoop() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        _ = present(manager, type, .low)
        h.activate()
        let single = AlertType(enabled: true, name: "Single", overrideMute: true, snooze: true, snoozePeriod: 30,
                               vibrate: false, soundName: nil, alertEntries: nil, nsManagedObjectContext: core.mainManagedObjectContext)
        _ = present(manager, single, .verylow)
        h.activate()
        XCTAssertEqual(h.players.count, 2)
        XCTAssertEqual(h.players[1].numberOfLoops, 0)
        XCTAssertNil(manager.protectedAlarmNotificationIdentifier)
    }

    func testSilentAlarmDoesNotReplaceAndSystemSoundRespectsUrgency() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        _ = present(manager, type, .low)
        h.activate()
        _ = present(manager, type, .verylow, sound: "")
        XCTAssertEqual(h.players.count, 1)
        let system = AlertType(enabled: true, name: "System", overrideMute: false, snooze: true, snoozePeriod: 30,
                               vibrate: false, soundName: nil, alertEntries: nil, nsManagedObjectContext: core.mainManagedObjectContext)
        XCTAssertNil(present(manager, system, .phonebatterylow, sound: nil).sound)
        XCTAssertTrue(h.sound.isPlaying())
        XCTAssertNotNil(present(manager, system, .verylow, sound: nil).sound)
        XCTAssertFalse(h.sound.isPlaying())
    }

    func testObsoleteNotificationAndPickerCannotStopLaterCycle() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        let old = present(manager, type, .low)
        let picker = manager.createPickerViewData(forAlertKind: .low, content: old, actionHandler: nil, cancelHandler: nil)
        manager.stopAlarmSound()
        let current = present(manager, type, .low)
        manager.stopAlarmSound(alertKind: .low, content: old)
        picker.cancelHandler?()
        XCTAssertTrue(h.sound.isPlaying())
        manager.stopAlarmSound(alertKind: .low, content: current)
        XCTAssertFalse(h.sound.isPlaying())
    }

    func testPickerConfirmationAndCancellationAcknowledgeOwningLoop() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        let content = present(manager, type, .low)
        manager.createPickerViewData(forAlertKind: .low, content: content, actionHandler: nil, cancelHandler: nil).actionHandler(0)
        XCTAssertFalse(h.sound.isPlaying())
        let next = present(manager, type, .low)
        manager.createPickerViewData(forAlertKind: .low, content: next, actionHandler: nil, cancelHandler: nil).cancelHandler?()
        XCTAssertFalse(h.sound.isPlaying())
    }

    func testDirectSnoozeIsScopedAndSnoozeAllCancelsPendingPlayback() {
        let (core, manager, type, h) = setupAlarm()
        let saved = UserDefaults.standard.snoozeAllAlertsUntilDate
        defer {
            UserDefaults.standard.snoozeAllAlertsUntilDate = saved
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        _ = present(manager, type, .low)
        manager.snooze(alertKind: .high, snoozePeriodInMinutes: 30, response: nil)
        XCTAssertTrue(h.sound.isPlaying())
        manager.snooze(alertKind: .low, snoozePeriodInMinutes: 30, response: nil)
        XCTAssertFalse(h.sound.isPlaying())
        _ = present(manager, type, .low)
        UserDefaults.standard.snoozeAllAlertsUntilDate = Date().addingTimeInterval(3600)
        XCTAssertFalse(h.sound.isPlaying())
        while !h.activations.isEmpty { h.activate() }
        XCTAssertTrue(h.players.allSatisfy { $0.starts == 0 })
    }

    func testSavedConfigurationChangesStopLoopButThrottleDoesNot() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        core.saveChanges()
        _ = present(manager, type, .low)
        manager.getSnoozeParameters(alertKind: .low).snooze(snoozePeriodInMinutes: 5)
        core.saveChanges()
        XCTAssertTrue(h.sound.isPlaying())
        type.repeatSound = false
        core.saveChanges()
        XCTAssertFalse(h.sound.isPlaying())
        for change in [0, 1, 2] {
            type.enabled = true
            type.overridemute = true
            type.repeatSound = true
            type.soundname = nil
            core.saveChanges()
            _ = present(manager, type, .low)
            if change == 0 { type.enabled = false }
            if change == 1 { type.overridemute = false }
            if change == 2 { type.soundname = "" }
            core.saveChanges()
            XCTAssertFalse(h.sound.isPlaying())
        }
    }

    func testDisabledOwningEntryStopsLoop() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        let entry = AlertEntry(isDisabled: false, value: 80, triggerValue: 0, alertKind: .low, start: 0, alertType: type, nsManagedObjectContext: core.mainManagedObjectContext)
        core.saveChanges()
        _ = present(manager, type, .low, entry: entry)
        entry.isDisabled = true
        core.saveChanges()
        XCTAssertFalse(h.sound.isPlaying())
    }

    func testFreshSafeReadingDoesNotAcknowledgeLoop() {
        let (core, manager, type, h) = setupAlarm()
        let wasMaster = UserDefaults.standard.isMaster
        let until = UserDefaults.standard.snoozeAllAlertsUntilDate
        defer {
            manager.stopAlarmSound()
            UserDefaults.standard.isMaster = wasMaster
            UserDefaults.standard.snoozeAllAlertsUntilDate = until
        }
        UserDefaults.standard.isMaster = true
        UserDefaults.standard.snoozeAllAlertsUntilDate = nil
        let entries = AlertEntriesAccessor(coreDataManager: core).getAllEntries(forAlertKind: nil, alertTypesAccessor: AlertTypesAccessor(coreDataManager: core))
        for entry in entries { entry.isDisabled = true }
        let reading = BgReading(timeStamp: Date(), sensor: nil, calibration: nil, rawData: 120, deviceName: nil, nsManagedObjectContext: core.mainManagedObjectContext)
        reading.calculatedValue = 120
        _ = present(manager, type, .low)
        _ = manager.checkAlerts(maxAgeOfLastBgReadingInSeconds: 60)
        XCTAssertTrue(h.sound.isPlaying())
        XCTAssertEqual(manager.protectedAlarmNotificationIdentifier, AlertKind.low.notificationIdentifier())
    }

    func testPendingOwningNotificationSurvivesFreshReadingCleanup() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .provisional])
        XCTAssertTrue(granted)
        let (core, manager, type, h) = setupAlarm()
        let wasMaster = UserDefaults.standard.isMaster
        let until = UserDefaults.standard.snoozeAllAlertsUntilDate
        let identifiers = [AlertKind.low.notificationIdentifier(), AlertKind.high.notificationIdentifier()]
        defer {
            manager.stopAlarmSound()
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            UserDefaults.standard.isMaster = wasMaster
            UserDefaults.standard.snoozeAllAlertsUntilDate = until
        }
        UserDefaults.standard.isMaster = true
        UserDefaults.standard.snoozeAllAlertsUntilDate = nil
        let entries = AlertEntriesAccessor(coreDataManager: core).getAllEntries(forAlertKind: nil, alertTypesAccessor: AlertTypesAccessor(coreDataManager: core))
        for entry in entries { entry.isDisabled = true }
        let reading = BgReading(timeStamp: Date(), sensor: nil, calibration: nil, rawData: 120, deviceName: nil, nsManagedObjectContext: core.mainManagedObjectContext)
        reading.calculatedValue = 120
        let content = present(manager, type, .low)
        content.title = "Looping alarm"
        for identifier in identifiers {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)))
        }
        let before = await center.pendingNotificationRequests().map(\.identifier)
        XCTAssertTrue(before.contains(identifiers[0]), "The fixture must schedule the owning request")
        _ = manager.checkAlerts(maxAgeOfLastBgReadingInSeconds: 60)
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        XCTAssertTrue(pending.contains(identifiers[0]))
        XCTAssertFalse(pending.contains(identifiers[1]))
        XCTAssertTrue(h.sound.isPlaying())
    }

    func testTerminalFailureAndScheduledKindsNeverRepeat() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        for kind in [AlertKind.sensorTransmitterFailure, .missedreading, .sensorEndingSoon, .sensorExpectedExpiry] {
            _ = present(manager, type, kind)
            h.activate()
            XCTAssertEqual(h.players.last?.numberOfLoops, 0)
            XCTAssertNil(manager.protectedAlarmNotificationIdentifier)
        }
    }

    func testEditorVisibilityDraftAndHiddenValuePreservation() {
        let (core, manager, type, _) = setupAlarm()
        defer { manager.stopAlarmSound() }
        let editor = AlertTypeEditorViewModel(alertType: type, coreDataManager: core, close: {})
        XCTAssertTrue(editor.rows.contains(.repeatSound))
        editor.overrideMute = false
        XCTAssertFalse(editor.rows.contains(.repeatSound))
        XCTAssertTrue(editor.repeatSound)
        editor.overrideMute = true
        editor.soundName = ""
        XCTAssertFalse(editor.rows.contains(.repeatSound))
        editor.soundName = nil
        XCTAssertTrue(editor.rows.contains(.repeatSound))
        editor.repeatSound = false
        XCTAssertTrue(type.repeatSound)
        editor.save()
        XCTAssertFalse(type.repeatSound)
        let draft = AlertTypeEditorViewModel(alertType: nil, coreDataManager: core, close: {})
        XCTAssertFalse(draft.repeatSound)
        XCTAssertFalse(draft.rows.contains(.repeatSound))
    }

    func testForegroundEntryAcknowledgesPendingLoop() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        _ = present(manager, type, .low)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertFalse(h.sound.isPlaying())
        h.activate()
        XCTAssertEqual(h.players[0].starts, 0)
    }

    func testNotLoopingCleanupKeepsUnacknowledgedLoop() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        _ = present(manager, type, .notlooping)
        _ = manager.checkNotLoopingAlert(deviceStatus: nil)
        XCTAssertTrue(h.sound.isPlaying())
        XCTAssertEqual(manager.protectedAlarmNotificationIdentifier, AlertKind.notlooping.notificationIdentifier())
    }

    func testDeletingOwningEntryStopsLoop() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        let entry = AlertEntry(isDisabled: false, value: 80, triggerValue: 0, alertKind: .low, start: 0, alertType: type, nsManagedObjectContext: core.mainManagedObjectContext)
        core.saveChanges()
        _ = present(manager, type, .low, entry: entry)
        core.mainManagedObjectContext.delete(entry)
        core.saveChanges()
        XCTAssertFalse(h.sound.isPlaying())
    }

    func testBackupServiceExportsAndRestoresRepeatSetting() async throws {
        let core = CoreDataManager(inMemoryModelName: "xdrip")
        _ = AlertType(enabled: true, name: "Backup loop", overrideMute: true, snooze: true, snoozePeriod: 30,
                      vibrate: false, soundName: nil, alertEntries: nil, nsManagedObjectContext: core.mainManagedObjectContext, repeatSound: true)
        XCTAssertTrue(core.saveChangesSynchronously())
        let service = BackupService(coreDataManager: core)
        let created = try await service.createBackup(options: BackupOptions(includesSettings: true, includesAccounts: false, includesBgReadings: false, includesTreatments: false, passphrase: nil))
        defer { try? FileManager.default.removeItem(at: created.url) }
        let inspection = try service.inspectBackup(at: created.url)
        var record = try XCTUnwrap(inspection.payload.alertTypes.first { $0.name == "Backup loop" })
        XCTAssertEqual(record.repeatSound, true)
        let destination = CoreDataManager(inMemoryModelName: "xdrip")
        let restoreService = BackupService(coreDataManager: destination)
        for repeats in [true, false] {
            record.repeatSound = repeats ? true : nil
            // Keep settings empty so this test restores only its isolated alarm data.
            let payload = BackupPayload(manifest: inspection.payload.manifest, settings: [:], accounts: nil,
                                        alertTypes: [record], bgReadings: [], treatments: [], deviceStatuses: nil, profiles: nil)
            _ = try await restoreService.restore(inspection: BackupInspection(payload: payload), mode: .ignore,
                                                 restoresSettings: true, restoredAccountCategories: [])
            destination.mainManagedObjectContext.reset()
            let restored = try XCTUnwrap(destination.mainManagedObjectContext.fetch(AlertType.fetchRequest()).first)
            XCTAssertEqual(restored.repeatSound, repeats)
            XCTAssertEqual(restored.snoozeperiod, 30)
        }
    }

    func testEveryAlarmTypeFieldTracksChangesAndRevertingClearsDraft() {
        let (core, manager, type, _) = setupAlarm()
        defer { manager.stopAlarmSound() }
        let editor = AlertTypeEditorViewModel(alertType: type, coreDataManager: core, close: {})
        XCTAssertFalse(editor.hasChanges)
        let switches: [ReferenceWritableKeyPath<AlertTypeEditorViewModel, Bool>] = [\.enabled, \.overrideMute, \.repeatSound, \.snooze, \.vibrate]
        for key in switches {
            let saved = editor[keyPath: key]
            editor[keyPath: key] = !saved
            XCTAssertTrue(editor.hasChanges)
            editor[keyPath: key] = saved
            XCTAssertFalse(editor.hasChanges)
        }
        let name = editor.name
        editor.name = "Changed name"
        XCTAssertTrue(editor.hasChanges)
        editor.name = name
        XCTAssertFalse(editor.hasChanges)
        let sound = editor.soundName
        editor.soundName = nil
        XCTAssertTrue(editor.hasChanges)
        editor.soundName = sound
        XCTAssertFalse(editor.hasChanges)
        let snooze = editor.snoozePeriod
        editor.snoozePeriod = 120
        XCTAssertTrue(editor.hasChanges)
        editor.snoozePeriod = snooze
        XCTAssertFalse(editor.hasChanges)
        XCTAssertEqual(type.name, name)
        XCTAssertEqual(type.soundname, sound)
        XCTAssertEqual(type.snoozeperiod, snooze)
    }

    func testUnchangedNewTypeCannotBeSavedAndChangedDraftCan() throws {
        let core = CoreDataManager(inMemoryModelName: "xdrip")
        let count = try core.mainManagedObjectContext.count(for: AlertType.fetchRequest())
        var closes = 0
        let editor = AlertTypeEditorViewModel(alertType: nil, coreDataManager: core, close: { closes += 1 })
        XCTAssertFalse(editor.hasChanges)
        editor.save()
        XCTAssertEqual(closes, 0)
        XCTAssertEqual(try core.mainManagedObjectContext.count(for: AlertType.fetchRequest()), count)
        editor.name = "New alarm type"
        XCTAssertTrue(editor.hasChanges)
        editor.save()
        XCTAssertEqual(closes, 1)
        XCTAssertFalse(editor.hasChanges)
        XCTAssertTrue(try core.mainManagedObjectContext.fetch(AlertType.fetchRequest()).contains { $0.name == "New alarm type" })
    }

    func testPreviewPauseResumeUsesDraftWithoutMarkingItChanged() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            h.sound.stopPlaying()
        }
        let editor = AlertTypeEditorViewModel(alertType: type, coreDataManager: core, soundPlayer: h.sound, close: {})
        editor.togglePreview()
        XCTAssertTrue(editor.isPreviewPlaying)
        XCTAssertFalse(editor.hasChanges)
        XCTAssertEqual(h.players[0].numberOfLoops, -1)
        editor.togglePreview()
        XCTAssertFalse(editor.isPreviewPlaying)
        XCTAssertEqual(h.players[0].pauses, 1)
        h.activate()
        XCTAssertEqual(h.players[0].starts, 0)
        editor.togglePreview()
        h.activate()
        XCTAssertTrue(editor.isPreviewPlaying)
        XCTAssertEqual(h.players.count, 1)
        XCTAssertEqual(h.players[0].starts, 1)
        editor.stopSoundPlayerIfPlaying()
        XCTAssertFalse(editor.isPreviewPlaying)
        XCTAssertFalse(h.sound.isPlaying())
        XCTAssertFalse(editor.hasChanges)
    }

    func testPreviewStopsOnDraftChangesAndSilentPreviewIsDisabled() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            h.sound.stopPlaying()
        }
        let editor = AlertTypeEditorViewModel(alertType: type, coreDataManager: core, soundPlayer: h.sound, close: {})
        editor.togglePreview()
        h.activate()
        editor.repeatSound = false
        XCTAssertFalse(editor.isPreviewPlaying)
        XCTAssertFalse(h.sound.isPlaying())
        editor.soundName = ""
        editor.vibrate = false
        XCTAssertFalse(editor.canPreview)
        editor.togglePreview()
        XCTAssertFalse(h.sound.isPlaying())
        XCTAssertTrue(type.repeatSound)
        editor.soundName = nil
        XCTAssertTrue(editor.canPreview)
        editor.enabled = false
        XCTAssertFalse(editor.canPreview)
        XCTAssertEqual(editor.rows, [.enabled, .name])
    }

    func testPausedPreviewCannotResumeAfterStopOrInterruption() {
        let h = AudioHarness()
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        h.activate()
        h.sound.pausePlaying()
        h.sound.handleInterruption(type: .began, shouldResume: false)
        h.sound.handleInterruption(type: .ended, shouldResume: true)
        XCTAssertTrue(h.activations.isEmpty)
        h.sound.stopPlaying()
        h.sound.resumePlaying()
        XCTAssertTrue(h.activations.isEmpty)
        XCTAssertFalse(h.sound.isPlaying())
    }

    func testRepeatedVibrationStartsWithAudioAndStopsWithPlayback() {
        let h = AudioHarness()
        var pulses = 0
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true, repeatVibration: { pulses += 1 })
        XCTAssertTrue(h.vibrationEvents.isEmpty)
        h.activate()
        XCTAssertEqual(h.vibrationEvents.count, 1)
        h.vibrationEvents[0]()
        XCTAssertEqual(pulses, 1)
        h.sound.stopPlaying()
        XCTAssertEqual(h.vibrationCancellations, 1)
        h.vibrationEvents[0]()
        XCTAssertEqual(pulses, 1)
    }

    func testPausedAndInterruptedVibrationCannotLeakIntoResumedPlayback() {
        let h = AudioHarness()
        var pulses = 0
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true, repeatVibration: { pulses += 1 })
        h.activate()
        h.vibrationEvents[0]()
        h.sound.pausePlaying()
        h.vibrationEvents[0]()
        XCTAssertEqual(pulses, 1)
        h.sound.resumePlaying()
        h.activate()
        h.vibrationEvents[0]()
        XCTAssertEqual(pulses, 1)
        h.vibrationEvents[1]()
        XCTAssertEqual(pulses, 2)
        h.sound.handleInterruption(type: .began, shouldResume: false)
        h.vibrationEvents[1]()
        XCTAssertEqual(pulses, 2)
        h.sound.handleInterruption(type: .ended, shouldResume: true)
        h.activate()
        h.vibrationEvents[2]()
        XCTAssertEqual(pulses, 3)
        h.sound.stopPlaying()
        XCTAssertEqual(h.vibrationCancellations, 3)
    }

    func testVibrationRepetitionRequiresLoopingAndSuccessfulAudio() {
        let h = AudioHarness()
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true)
        h.activate()
        XCTAssertTrue(h.vibrationEvents.isEmpty)
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatVibration: {})
        h.activate()
        XCTAssertTrue(h.vibrationEvents.isEmpty)
        h.sound.playSound(soundFileName: "xdripalert.aif", repeatSound: true, repeatVibration: {})
        h.players.last?.succeeds = false
        h.activate()
        XCTAssertTrue(h.vibrationEvents.isEmpty)
        XCTAssertFalse(h.sound.isPlaying())
    }

    func testReplacementAndSnoozeCancelOwningAlarmVibration() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            withExtendedLifetime(core) {}
        }
        type.vibrate = true
        _ = present(manager, type, .low)
        h.activate()
        XCTAssertEqual(h.vibrationEvents.count, 1)
        type.vibrate = false
        _ = present(manager, type, .verylow)
        h.activate()
        XCTAssertEqual(h.vibrationCancellations, 1)
        XCTAssertEqual(h.vibrationEvents.count, 1)
        manager.stopAlarmSound()
        type.vibrate = true
        _ = present(manager, type, .low)
        h.activate()
        XCTAssertEqual(h.vibrationEvents.count, 2)
        manager.snooze(alertKind: .low, snoozePeriodInMinutes: 30, response: nil)
        XCTAssertEqual(h.vibrationCancellations, 2)
        XCTAssertFalse(h.sound.isPlaying())
    }

    func testPreviewVibrationPausesResumesAndStopsWhenVibrateIsDisabled() {
        let (core, manager, type, h) = setupAlarm()
        defer {
            manager.stopAlarmSound()
            h.sound.stopPlaying()
        }
        type.vibrate = true
        let editor = AlertTypeEditorViewModel(alertType: type, coreDataManager: core, soundPlayer: h.sound, close: {})
        editor.togglePreview()
        h.activate()
        XCTAssertEqual(h.vibrationEvents.count, 1)
        editor.togglePreview()
        XCTAssertEqual(h.vibrationCancellations, 1)
        editor.togglePreview()
        h.activate()
        XCTAssertEqual(h.vibrationEvents.count, 2)
        editor.vibrate = false
        XCTAssertEqual(h.vibrationCancellations, 2)
        XCTAssertFalse(editor.isPreviewPlaying)
    }

    func testLegacyBackupDefaultsToSinglePlaybackAndNewFieldRoundTrips() throws {
        let legacy = Data(#"{"enabled":true,"name":"Low","overrideMute":true,"snooze":true,"snoozePeriod":30,"vibrate":true,"entries":[]}"#.utf8)
        var record = try JSONDecoder().decode(BackupAlertType.self, from: legacy)
        XCTAssertFalse(record.repeatSound ?? false)
        record.repeatSound = true
        XCTAssertEqual(try JSONDecoder().decode(BackupAlertType.self, from: JSONEncoder().encode(record)).repeatSound, true)
    }

    func testV36SQLiteMigrationPreservesSettingsAndDefaultsRepetitionOff() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let models = try XCTUnwrap(Bundle.main.url(forResource: "xdrip", withExtension: "momd"))
        let oldModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: models.appendingPathComponent("xdrip v36.mom")))
        let newModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: models.appendingPathComponent("xdrip v37.mom")))
        let url = directory.appendingPathComponent("migration.sqlite")
        let old = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        let store = try old.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = old
        let type = NSEntityDescription.insertNewObject(forEntityName: "AlertType", into: context)
        type.setValue("Existing Low", forKey: "name")
        type.setValue(true, forKey: "enabled")
        type.setValue(true, forKey: "overridemute")
        type.setValue(true, forKey: "snooze")
        type.setValue(false, forKey: "vibrate")
        type.setValue(30, forKey: "snoozeperiod")
        type.setValue("Old sound", forKey: "soundname")
        try context.save()
        try old.remove(store)
        let current = NSPersistentStoreCoordinator(managedObjectModel: newModel)
        let migrated = try current.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url,
            options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        defer { try? current.remove(migrated) }
        let destination = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        destination.persistentStoreCoordinator = current
        let restored = try XCTUnwrap(destination.fetch(AlertType.fetchRequest()).first)
        XCTAssertEqual(restored.name, "Existing Low")
        XCTAssertTrue(restored.overridemute)
        XCTAssertEqual(restored.snoozeperiod, 30)
        XCTAssertEqual(restored.soundname, "Old sound")
        XCTAssertFalse(restored.repeatSound)
    }
}
