//
//  TextsDirectWatch.swift
//  xDrip
//
//  Created by Paul Plant on 14/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Shared feature text uses each app's existing translation table.
enum TextsDirectWatch {
    private static func text(_ key: String, _ fallback: String) -> String {
        #if os(watchOS)
        let table = "WatchApp"
        #else
        let table = "Localizable"
        #endif
        return NSLocalizedString(key, tableName: table, bundle: .main, value: fallback, comment: "Direct to Watch")
    }

    static var title: String { text("directWatchTitle", "Direct to Watch") }
    static var noConnection: String { text("directWatchNoConnection", "No Connection Added") }
    static var suspended: String { text("directWatchSuspended", "Collection suspended") }
    static var collectedReadings: String { text("directWatchCollectedReadings", "Collected Readings") }
    static var connectionDetails: String { text("directWatchConnectionDetails", "Connection details") }
    static var cgmType: String { text("directWatchCGMType", "CGM Type") }
    static var bluetoothSlot: String { text("directWatchBluetoothSlot", "Bluetooth slot") }
    static var sendLogs: String { text("directWatchSendLogs", "Send logs") }
    static var logsQueued: String { text("directWatchLogsQueued", "Logs queued") }
    static var resetStarted: String { text("directWatchResetStarted", "Reset started") }
    static var tryAgain: String { text("directWatchTryAgain", "Try again") }
    static var requestQueued: String { text("directWatchRequestQueued", "Request queued") }
    static var lastLogsReceived: String { text("directWatchLastLogsReceived", "Last logs received") }
    static var waitingForLogs: String { text("directWatchWaitingForLogs", "Waiting for new logs…") }
    static var logsFailed: String { text("directWatchLogsFailed", "Could not get logs. Try again.") }
    static var resetConnection: String { text("directWatchResetConnection", "Reset connection") }
    static var cancel: String { text("directWatchCancel", "Cancel") }
    static var resetConnectionExplanation: String {
        text("directWatchResetConnectionExplanation", "Clears saved connection details and searches for the transmitter again. You may need to accept a Bluetooth pairing request.")
    }
    static func sessionBoundary(_ session: DirectWatchCollectionSession, ending: Bool) -> String {
        let date = ending ? session.endedAt ?? session.startedAt : session.startedAt
        let timestamp = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        let key = ending ? (session.endedByPause ? "directWatchSessionPaused" : "directWatchSessionEnded")
                         : (session.isResume ? "directWatchSessionResumed" : "directWatchSessionStarted")
        let fallback = ending ? (session.endedByPause ? "Paused at %@" : "Ended at %@")
                              : (session.isResume ? "Resumed at %@" : "Started at %@")
        return String(format: text(key, fallback), timestamp)
    }
    static func readingGap(_ interval: TimeInterval) -> String {
        let seconds = Int(max(0, interval).rounded())
        return String(format: text("directWatchReadingGapFormat", "(%dm %ds)"), seconds / 60, seconds % 60)
    }
    static var noCollectedReadings: String { text("directWatchNoCollectedReadings", "No Watch readings collected yet") }
    static var connecting: String { text("directWatchConnecting", "Waiting…") }
    static var waiting: String { text("directWatchWaiting", "Waiting for Watch reading") }
    static var collecting: String { text("directWatchCollecting", "Collecting") }
    static var delayed: String { connecting }
    static var overdue: String { text("directWatchOverdue", "Reading overdue") }
    static var diagnosis: String { text("directWatchDiagnosis", "Diagnosis") }
    static var alerts: String { text("directWatchAlerts", "Alerts") }
    static var urgentLow: String { text("directWatchUrgentLow", "Urgent Low") }
    static var low: String { text("directWatchLow", "Low") }
    static var alertExplanation: String {
        text("directWatchAlertExplanation", "Thresholds follow iPhone alarm schedules. Watch alerts require collection to be running and no iPhone communication for over 60 seconds.")
    }
    static var scheduleUnavailable: String { text("directWatchScheduleUnavailable", "Sync alarm settings from iPhone") }
    static var missedReadings: String { text("directWatchMissedReadings", "Missed Readings") }
    static var missedReadingsExplanation: String {
        text("directWatchMissedReadingsExplanation", "When enabled, the watch will notify when no reading is received for over 20 minutes")
    }
    static func pausedSince(_ date: Date?) -> String {
        let timestamp = date.map { $0.formatted(.dateTime.year(.twoDigits).month(.twoDigits).day(.twoDigits).hour().minute()) } ?? "--"
        return String(format: text("directWatchPausedSinceFormat", "Since %@"), timestamp)
    }

    static var pausedShort: String { text("directWatchPausedShort", "Paused") }
    static var paused: String { text("directWatchPaused", "Watch collection paused") }
    static var pause: String { text("directWatchPause", "Pause Collection") }
    static var resume: String { text("directWatchResume", "Resume Collection") }
    static var added: String { text("directWatchAdded", "Watch connection added") }
    static var pairingGuidance: String { text("directWatchPairingGuidance", "Scroll down to the Direct to Watch screen on the Watch and accept the Bluetooth pairing request if this is the first time you're adding this transmitter.\n\nAllow up to five minutes for the transmitter to connect.") }

    // Setup, slot safety and diagnosis copy. Keep titles short. Warnings retain the device-conflict context.
    static var testingLogs: String { text("directWatchTestingLogs", "Testing and Logs") }
    static var addConnection: String { text("directWatchAddConnection", "Add Watch connection") }
    static var removeConnection: String { text("directWatchRemoveConnection", "Remove Watch connection") }
    static var medicalSlot: String { text("directWatchMedicalSlot", "Medical device slot") }
    static var watchSlot: String { text("directWatchWatchSlot", "Watch slot") }
    static var confirmUnusedSlot: String { text("directWatchConfirmUnusedSlot", "Slot unused: add Watch") }
    static var slotMedical: String { text("directWatchSlotMedical", "Slot 1 · Medical device") }
    static var slotMobile: String { text("directWatchSlotMobile", "Slot 2 · Mobile app") }
    static var slotWatch: String { text("directWatchSlotWatch", "Slot 3 · Watch") }
    static var slotAnubis: String { text("directWatchSlotAnubis", "Slot 3 · Anubis extra") }
    static var usedWatch: String { text("directWatchUsedWatch", "Used by this Watch") }
    static var usedPhone: String { text("directWatchUsedPhone", "Used by this iPhone") }
    static var slotMedicalDetail: String { text("directWatchSlotMedicalDetail", "Only if no pump or receiver uses it") }
    static var slotMobileDetail: String { text("directWatchSlotMobileDetail", "Only if no other phone app uses it") }
    static var recommendedWatch: String { text("directWatchRecommendedWatch", "Recommended for the Watch") }
    static var recommendedTransmitter: String { text("directWatchRecommendedTransmitter", "Recommended for this transmitter") }
    static var anubisOnly: String { text("directWatchAnubisOnly", "Anubis transmitters only") }
    static var watchStatus: String { text("directWatchWatchStatus", "Watch status") }
    static var testingDiagnosis: String { text("directWatchTestingDiagnosis", "Testing and diagnosis") }
    static var pausePhone: String { text("directWatchPausePhone", "Pause iPhone BLE collection") }
    static var forTesting: String { text("directWatchForTesting", "For testing Watch collection") }
    static var getLogs: String { text("directWatchGetLogs", "Get Watch logs") }
    static var logs: String { text("directWatchLogs", "Logs") }
    static var shareLogs: String { text("directWatchShareLogs", "Share Watch logs") }
    static var pending: String { text("directWatchPending", "Pending") }
    static var receivedFormat: String { text("directWatchReceivedFormat", "Received %@") }
    static var selectedFormat: String { text("directWatchSelectedFormat", "%@, selected") }
    static var intro: String { text("directWatchIntro", "Your Watch can collect readings directly when your iPhone is away. Sensor controls stay on your iPhone.") }
    static var backgroundAdvice: String { text("directWatchBackgroundAdvice", "Background collection depends on watchOS. Test it on your Watch before relying on it away from your iPhone.") }
    static var separateSlots: String { text("directWatchSeparateSlots", "The Watch and iPhone need separate slots. Slot 1 may interrupt a pump or receiver already using it.") }
    static var nativeRequired: String { text("directWatchNativeRequired", "Direct Watch collection requires native calculated glucose on this iPhone.") }
    static var startSensor: String { text("directWatchStartSensor", "Start a sensor on this iPhone before adding the Watch connection.") }
    static var noSlot: String { text("directWatchNoSlot", "No compatible slot is available for the Watch.") }
    static var medicalWarning: String { text("directWatchMedicalWarning", "The Watch will use slot 1, normally used by a pump or receiver. Do not add this connection if a pump, receiver or other medical device uses this slot. Adding the Watch could interrupt that device’s glucose connection.") }
    static var watchSlotWarning: String { text("directWatchWatchSlotWarning", "The Watch will use slot 3. Do not add this connection if another smartwatch is already paired to this sensor. Adding this Watch could interrupt its glucose connection.") }
    static var slotConflict: String { text("directWatchSlotConflict", "This slot is assigned to the Watch. Remove the Watch connection before assigning it to the iPhone.") }
    static var openForStatus: String { String(format: text("directWatchOpenForStatus", "Open %@ on the Watch to receive its status."), title) }
    static var checkInstalled: String { text("directWatchCheckInstalled", "If this status stays stale, check that the app appears under Installed on Apple Watch in the iPhone’s Watch app.") }
    static var masterRequired: String { text("directWatchMasterRequired", "iPhone must be in master mode.") }
    static var g6Mismatch: String { text("directWatchG6Mismatch", "Configured G6 is not the active iPhone transmitter.") }
    static var g7Mismatch: String { text("directWatchG7Mismatch", "Configured G7-family sensor is not the active iPhone transmitter.") }
    static var primaryRequired: String { text("directWatchPrimaryRequired", "Direct Watch collection requires a primary G7-family iPhone connection.") }
    static var nativeG6Required: String { text("directWatchNativeG6Required", "Enable native G6 glucose on the iPhone.") }
    static var pairingCodeRequired: String { text("directWatchPairingCodeRequired", "A four-digit sensor code is required for Watch pairing.") }
    static var slotsConflict: String { text("directWatchSlotsConflict", "Watch and iPhone Bluetooth slots conflict.") }
    static var anubisRequired: String { text("directWatchAnubisRequired", "Slot 3 requires an Anubis transmitter.") }
    static var noActiveSensor: String { text("directWatchNoActiveSensor", "No active sensor on the iPhone.") }
    // Watch-only labels and operational states. Protocol details remain in the diagnostic log.
    static var cgm: String { text("directWatchCgm", "CGM") }
    static var toSync: String { text("directWatchToSync", "To sync") }
    // All current Watch languages have singular/plural forms. Keep the count inside the translated phrase.
    static var oneReadingFormat: String { text("directWatchOneReadingFormat", "%d reading") }
    static var readingsFormat: String { text("directWatchReadingsFormat", "%d readings") }
    static var blePaused: String { text("directWatchBlePaused", "BLE paused") }
    static var connected: String { text("directWatchConnected", "Connected") }
    static var checking: String { text("directWatchChecking", "Checking") }
    static var away: String { text("directWatchAway", "Away") }
    static var checkSensor: String { String(format: text("directWatchCheckSensor", "Check the active sensor in %@ on your iPhone."), title) }
    static var addOnPhone: String { text("directWatchAddOnPhone", "Add a Watch connection from the transmitter screen on your iPhone.") }
    static var g7Family: String { text("directWatchG7Family", "G7 family") }
    static var collectionOff: String { text("directWatchCollectionOff", "Watch collection is off") }
    static var storageReadFailed: String { text("directWatchStorageReadFailed", "Cannot read stored Watch data. Collection stopped.") }
    static var storageSaveFailedFormat: String { text("directWatchStorageSaveFailedFormat", "Cannot save Watch data: %@") }
    static var suspendedCheckPhone: String { text("directWatchSuspendedCheckPhone", "Collection suspended, check the iPhone") }
    static var suspendedReasonFormat: String { text("directWatchSuspendedReasonFormat", "Collection suspended: %@") }
    static var waitingTransmitter: String { text("directWatchWaitingTransmitter", "Waiting for transmitter") }
    static var waitingCycle: String { text("directWatchWaitingCycle", "Waiting for next transmitter cycle") }
    static var connectingSaved: String { text("directWatchConnectingSaved", "Connecting to saved transmitter") }
    static var retryingSaved: String { text("directWatchRetryingSaved", "Retrying saved transmitter") }
    static var checkingDiscovery: String { text("directWatchCheckingDiscovery", "Checking transmitter discovery") }
    static var scanningRetained: String { text("directWatchScanningRetained", "Scanning, saved connection retained") }
    static var waitingDiscovery: String { text("directWatchWaitingDiscovery", "Waiting to rediscover transmitter") }
    static var reconnectingSaved: String { text("directWatchReconnectingSaved", "Reconnecting to saved transmitter") }
    static var scanningToPair: String { text("directWatchScanningToPair", "Scanning for transmitter to pair again") }
    static var bluetoothUnavailableFormat: String { text("directWatchBluetoothUnavailableFormat", "Watch Bluetooth unavailable (%d)") }
    static var connectingTransmitter: String { text("directWatchConnectingTransmitter", "Connecting to transmitter") }
    static var authenticating: String { text("directWatchAuthenticating", "Authenticating transmitter") }
    static var transmitterTimeout: String { text("directWatchTransmitterTimeout", "Transmitter timed out, waiting for next cycle") }
    static var waitingNextReading: String { text("directWatchWaitingNextReading", "Waiting for next transmitter reading") }
    static var bluetoothRejected: String { String(format: text("directWatchBluetoothRejected", "Bluetooth rejected connection, use %@"), resetConnection) }
    static var g6AuthRejected: String { text("directWatchG6AuthRejected", "G6 authentication rejected") }
    static var acceptPairing: String { text("directWatchAcceptPairing", "Accept Bluetooth pairing on the Watch") }
    static var g6StateFormat: String { text("directWatchG6StateFormat", "G6 state %d, check sensor on iPhone") }
    static var g7Requesting: String { text("directWatchG7Requesting", "G7 authenticated, requesting reading") }
    static var g7KeyRejected: String { text("directWatchG7KeyRejected", "G7 rejected the saved Watch key, check slot ownership") }
    static var g7AuthFailed: String { text("directWatchG7AuthFailed", "G7 authentication failed. See logs.") }
    static var bluetoothErrorFormat: String { text("directWatchBluetoothErrorFormat", "Transmitter Bluetooth: %@") }
    static var backgroundLimit: String { text("directWatchBackgroundLimit", "watchOS Bluetooth background limit reached. Open this app to reset it.") }
    static var readingReceived: String { text("directWatchReadingReceived", "Watch reading received") }
    static var noRecentReading: String { String(format: text("directWatchNoRecentReading", "%@: no recent reading"), title) }
    static var checkConnection: String { String(format: text("directWatchCheckConnection", "Open %@ on your Watch to check the connection."), title) }
    static var lowGlucose: String { String(format: text("directWatchLowGlucose", "%@: low glucose"), title) }
    static var urgentLowGlucose: String { String(format: text("directWatchUrgentLowGlucose", "%@: urgent low glucose"), title) }
    static var exportFailedFormat: String { text("directWatchExportFailedFormat", "Cannot export Watch log: %@") }
}
