//
//  Libre3SetupView.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import CoreBluetooth
import os

struct Libre3SetupView: View {
    @ObservedObject var router: BluetoothPeripheralsRouter
    var recoverySerial: String? = nil
    @State private var mode = 0
    @State private var accountID = ""
    @State private var receiverHex = ""
    @State private var savedReceiverHex: String?
    @State private var scannedReceiverHex: String?
    @State private var derivation = Libre3ReceiverID.Derivation.freeStyleLibre3
    @State private var busy = false
    @State private var credentialsReady = false
    @State private var credentialError: String?
    @State private var message: String?
    @State private var task: Task<Void, Never>?
    @State private var reader = Libre3NFCActivationReader()

    private var canScan: Bool {
        guard credentialsReady, !busy else { return false }
        switch mode {
        case 1: return Libre3ReceiverID.parseLittleEndianHex(receiverHex) != nil
        case 2: return UUID(uuidString: accountID.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        default: return true
        }
    }

    private var scanFooter: String {
        switch mode {
        case 1:
            return TextsLibre3.localized(
                "Scan the active sensor using its original Receiver ID. After a successful NFC scan, Bluetooth connects automatically. Connecting does not restart the sensor's wear period.")
        case 2:
            return TextsLibre3.localized("Stop the original app's Bluetooth connection before scanning. After a successful NFC scan, Bluetooth connects automatically.")
        default:
            return TextsLibre3.localized(
                "Starting a fresh sensor begins its wear period. Keep the Receiver ID from the device details for recovery. After a successful NFC scan, Bluetooth connects automatically. Wait for authentication and sensor warm-up."
            )
        }
    }

    private var savedIDTitle: String {
        guard let savedReceiverHex else { return TextsLibre3.localized("Use Saved ID") }
        return String(format: TextsLibre3.localized("Use Saved ID (%@)"), savedReceiverHex)
    }

    var body: some View {
        Form {
            Section {
                Picker(TextsLibre3.localized("Add Libre 3 Type"), selection: $mode) {
                    Text(TextsLibre3.localized("Start a new sensor")).tag(0)
                    Text(TextsLibre3.localized("Connect using Receiver ID")).tag(1)
                    Text(TextsLibre3.localized("Import from original app")).tag(2)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text(TextsLibre3.localized("Add Libre 3 Type"))
            } footer: {
                Text(TextsLibre3.localized("Libre 3 connects directly by Bluetooth after an NFC scan. Keep this screen open until scanning finishes."))
            }
            if mode == 1 {
                Section {
                    HStack {
                        Text(TextsLibre3.localized("Receiver ID"))
                            .foregroundStyle(ConstantsAppColors.rowTitleText)
                            .layoutPriority(1)
                        TextField(text: $receiverHex) { Text(verbatim: "a1b2c3d4") }
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(ConstantsAppColors.rowDetailText)
                            .keyboardType(.asciiCapable)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel(TextsLibre3.localized("Receiver ID"))
                    }
                    Button(savedIDTitle) {
                        if let savedReceiverHex { receiverHex = savedReceiverHex }
                    }
                    .disabled(savedReceiverHex == nil)
                } footer: {
                    Text(TextsLibre3.localized("Use the Receiver ID that originally started this sensor. Reinstalling the app or restoring a backup does not restore its device-only credentials."))
                }
            }
            if mode == 2 {
                Section {
                    Libre3AppUsedPicker(derivation: $derivation)
                    HStack {
                        Text(TextsLibre3.localized("Account ID"))
                            .foregroundStyle(ConstantsAppColors.rowTitleText)
                            .layoutPriority(1)
                        TextField(TextsLibre3.localized("Enter Account ID"), text: $accountID)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(ConstantsAppColors.rowDetailText)
                            .keyboardType(.asciiCapable)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel(TextsLibre3.localized("Account ID"))
                    }
                    NavigationLink {
                        Libre3AccountLookupView(accountID: $accountID, derivation: $derivation)
                    } label: {
                        Label {
                            Text(TextsLibre3.localized("I don't know my Account ID"))
                                .foregroundStyle(ConstantsAppColors.rowTitleText)
                        } icon: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                } footer: {
                    Text(
                        TextsLibre3.localized(
                            "Experimental import: use the account that started this sensor, not a follower or caregiver account. A scan alone cannot recover an unknown Receiver ID. Stop the official app's Bluetooth connection before connecting here."
                        ))
                }
            }
            Section {
                Button(action: scan) {
                    Label(TextsLibre3.localized("Scan Sensor with NFC"), systemImage: "wave.3.right")
                        .foregroundStyle(canScan ? Color.accentColor : ConstantsAppColors.disabledText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canScan)
                if busy && credentialsReady { ProgressView() }
                if let message { Text(message).foregroundStyle(.secondary) }
                if mode == 0, let scannedReceiverHex {
                    Button(String(format: TextsLibre3.localized("Use Saved ID (%@)"), scannedReceiverHex)) {
                        receiverHex = scannedReceiverHex
                        savedReceiverHex = scannedReceiverHex
                        mode = 1
                        message = nil
                    }
                }
            } footer: {
                Text(scanFooter)
            }
            if !credentialsReady {
                Section {
                    if busy {
                        ProgressView(TextsLibre3.localized("Preparing Libre 3 credentials…"))
                    } else {
                        Label(TextsLibre3.localized("Libre 3 credentials are unavailable. Scanning is disabled."), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        if let credentialError { Text(credentialError).font(.footnote).foregroundStyle(.secondary) }
                        Button(TextsLibre3.localized("Retry download"), action: prepareCredentials)
                    }
                } header: {
                    Text(TextsLibre3.localized("Libre 3 Credentials"))
                } footer: {
                    Text(TextsLibre3.localized("Credentials download automatically before the first scan. Manage downloaded versions in Advanced Settings → Libre 3 Credentials."))
                }
            }
        }
        .disabled(busy)
        .navigationTitle(TextsLibre3.localized("Libre 3 / 3 Plus"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prepareCredentials()
            savedReceiverHex = (try? Libre3CredentialStore().pending()).map {
                Libre3ReceiverID($0.receiverID).littleEndianHex
            }
            if let recoverySerial {
                mode = 1
                if let record = try? Libre3CredentialStore().load(serial: recoverySerial) {
                    receiverHex = Libre3ReceiverID(record.receiverID).littleEndianHex
                }
            }
        }
        .onDisappear {
            task?.cancel()
            reader.cancel()
        }
        .onChange(of: accountID) { _ in message = nil }
    }

    private func prepareCredentials() {
        guard !busy else { return }
        busy = true
        credentialError = nil
        task = Task { @MainActor in
            defer { busy = false }
            do {
                let version = try await Libre3IdentityStore.shared.ensureAvailable()
                if version.id != Libre3IdentitySource.current.version {
                    // A new build can provision its new version without delaying cached setup.
                    Task { _ = try? await Libre3IdentityStore.shared.downloadCurrent() }
                }
                try Task.checkCancellation()
                if !credentialsReady { Libre3Log.event(.credentialsReady) }
                credentialsReady = true
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                Libre3Log.event(.credentialsUnavailable, error: error)
                credentialsReady = false
                credentialError = error.localizedDescription
            }
        }
    }

    private func scan() {
        guard canScan else { return }
        busy = true
        message = nil
        scannedReceiverHex = nil
        let setupMode = mode
        let enteredID = receiverHex
        let enteredAccount = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedDerivation = derivation
        task = Task { @MainActor in
            defer { busy = false }
            do {
                guard CBCentralManager.authorization != .denied, CBCentralManager.authorization != .restricted else {
                    throw Libre3ConnectionError.disconnected
                }
                let store = Libre3CredentialStore()
                let receiver: UInt32
                switch setupMode {
                case 0: receiver = try store.appReceiverID()
                case 1: receiver = try Libre3ReceiverID(littleEndianHex: enteredID).value
                default:
                    guard UUID(uuidString: enteredAccount) != nil else { throw Libre3ConnectionError.identity }
                    receiver = Libre3ReceiverID(accountID: enteredAccount, derivation: selectedDerivation).value
                }
                // Complete provisioning before any command changes the sensor's receiver/PIN.
                let credentials = try await Libre3IdentityStore.shared.ensureAvailable()
                reader.prepare = { patch in
                    if let recoverySerial, recoverySerial != patch.serialNumber { throw Libre3ConnectionError.identity }
                    let existing = try store.load(serial: patch.serialNumber)
                    guard patch.wearDurationMinutes > 0, patch.warmupMinutes < patch.wearDurationMinutes else {
                        throw Libre3ConnectionError.malformed
                    }
                    // Read-only patch information is available before activation or PIN changes.
                    // Even a known sensor must use the existing-sensor option explicitly.
                    if setupMode == 0, patch.stateByte != 1 {
                        throw Libre3ConnectionError.alreadyStarted(receiverID: existing?.receiverID)
                    }
                    if setupMode != 0, patch.stateByte == 1 { throw Libre3ConnectionError.notStarted }
                    if let existing, existing.nfcCompleted, existing.receiverID != receiver {
                        throw Libre3ConnectionError.identity
                    }
                    var pending =
                        existing?.receiverID == receiver
                        ? existing!
                        : Libre3PairingRecord(
                            serial: patch.serialNumber, receiverID: receiver,
                            firmware: patch.firmwareVersion, generation: patch.generation,
                            wearMinutes: Int(patch.wearDurationMinutes), warmupMinutes: Int(patch.warmupMinutes))
                    if existing?.receiverID == receiver {
                        pending.startedAt = existing?.startedAt
                        pending.rejectedMinutes = existing?.rejectedMinutes ?? []
                    }
                    try store.save(pending)
                    Self.logReceiver(patch: patch, receiver: receiver, version: credentials.id, confirmed: false)
                }
                reader.saveResponse = { patch, response in
                    guard var pending = try store.load(serial: patch.serialNumber), pending.receiverID == receiver else {
                        throw Libre3ConnectionError.storage
                    }
                    pending.phase5Key = nil
                    pending.cryptoVersion = 1
                    pending.identityVersion = credentials.id
                    pending.identityLabel = nil
                    pending.securityVersion = patch.securityVersion
                    pending.region = patch.region
                    pending.authenticated = false
                    pending.blePIN = response.blePIN
                    pending.bleAddress = response.bleAddressDisplay
                    pending.nfcCompleted = true
                    try store.save(pending)
                    Self.logReceiver(patch: patch, receiver: receiver, version: credentials.id, confirmed: true)
                }
                _ = try await reader.scan(mode: setupMode == 0 ? .activateFreshSensor(receiverID: receiver) : .switchReceiver(receiverID: receiver))
                try Task.checkCancellation()
                router.openPeripheral(nil, type: .Libre3Type, startLibre3AfterNFC: true)
            } catch is CancellationError {
            } catch {
                if let connectionError = error as? Libre3ConnectionError,
                    case .alreadyStarted(let savedID) = connectionError
                {
                    scannedReceiverHex = savedID.map { Libre3ReceiverID($0).littleEndianHex }
                }
                message = (error as? LocalizedError)?.errorDescription ?? TextsLibre3.localized("The scan could not complete. Retry with the original Receiver ID.")
            }
        }
    }

    private static func logReceiver(patch: Libre3NFCPatchInfo, receiver: UInt32, version: String, confirmed: Bool) {
        // Keep recovery identifiers in optional debug traces, outside shared Activity Log reports.
        let serial = String(patch.serialNumber.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(18))
        let operation = patch.stateByte == 1 ? "activate" : "switch receiver"
        let context = "NFC \(operation) \(confirmed ? "confirmed" : "attempt"), wearMinutes=\(patch.wearDurationMinutes), warmupMinutes=\(patch.warmupMinutes)"
        let log = OSLog(subsystem: ConstantsLog.subSystem, category: "Libre3Setup")
        trace(
            "%{public}@", log: log, category: "Libre3Setup", type: .info, context)
        if UserDefaults.standard.addDebugLevelLogsInTraceFileAndNSLog {
            let details = "NFC details, sensor=\(serial), Receiver ID=\(Libre3ReceiverID(receiver).littleEndianHex) (little-endian), region=\(patch.region), security=\(patch.securityVersion), generation=\(patch.generation), firmware=\(patch.firmwareVersion), credentials=\(version)"
            trace("%{public}@", log: log, category: "Libre3Setup", type: .debug, details)
        }
    }
}

/// Both screens edit the same selection, so account lookup cannot leave pairing on a different app.
private struct Libre3AppUsedPicker: View {
    @Binding var derivation: Libre3ReceiverID.Derivation

    var body: some View {
        HStack {
            Text(TextsLibre3.localized("App used"))
                .foregroundStyle(ConstantsAppColors.rowTitleText)
                .layoutPriority(1)
            Spacer()
            Picker(TextsLibre3.localized("App used"), selection: $derivation) {
                Text(verbatim: "FreeStyle Libre 3").tag(Libre3ReceiverID.Derivation.freeStyleLibre3)
                Text(verbatim: "Libre by Abbott").tag(Libre3ReceiverID.Derivation.libreByAbbott)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(ConstantsAppColors.rowDetailText)
            .accessibilityLabel(TextsLibre3.localized("App used"))
        }
    }
}

private struct Libre3AccountLookupView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var accountID: String
    @Binding var derivation: Libre3ReceiverID.Derivation
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var task: Task<Void, Never>?

    var body: some View {
        Form {
            Section {
                Libre3AppUsedPicker(derivation: $derivation)
                HStack {
                    Text(Texts_Common.username)
                        .foregroundStyle(ConstantsAppColors.rowTitleText)
                        .layoutPriority(1)
                    TextField(TextsLibre3.localized("Email address"), text: $email)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(ConstantsAppColors.rowDetailText)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel(Texts_Common.username)
                }
                HStack {
                    Text(Texts_Common.password)
                        .foregroundStyle(ConstantsAppColors.rowTitleText)
                        .layoutPriority(1)
                    SecureField(Texts_Common.password, text: $password)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(ConstantsAppColors.rowDetailText)
                        .textContentType(.password)
                        .accessibilityLabel(Texts_Common.password)
                }
            } footer: {
                Text(TextsLibre3.localized("Use the email address and password for the account that started this sensor. Your password is not saved."))
            }
            Section {
                Button(TextsLibre3.localized("Log in"), action: lookup)
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                if busy { ProgressView(TextsLibre3.localized("Looking up Account ID…")) }
                if let message { Text(message).foregroundStyle(.secondary) }
            }
        }
        .disabled(busy)
        .navigationTitle(TextsLibre3.localized("Log in to get Account ID"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            task?.cancel()
            password = ""
        }
    }

    private func lookup() {
        guard !busy else { return }
        busy = true
        message = nil
        let username = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Libre3Log.event(.accountLookupStarted)
        task = Task { @MainActor in
            defer {
                busy = false
                password = ""
            }
            do {
                let result = try await Libre3AccountLookup().accountID(email: username, password: password)
                // A cancelled lookup must not update the parent after the user has left this screen.
                try Task.checkCancellation()
                guard let id = UUID(uuidString: result) else { throw Libre3AccountLookup.LookupError.unsupported }
                accountID = id.uuidString.lowercased()
                Libre3Log.event(.accountLookupSucceeded)
                dismiss()
            } catch is CancellationError {
                Libre3Log.event(.accountLookupCancelled)
            } catch {
                if Task.isCancelled {
                    Libre3Log.event(.accountLookupCancelled)
                    return
                }
                Libre3Log.event(.accountLookupFailed, error: error)
                message = error.localizedDescription
            }
        }
    }
}
