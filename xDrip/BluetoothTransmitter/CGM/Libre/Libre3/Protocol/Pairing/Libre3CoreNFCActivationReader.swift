//
//  Libre3CoreNFCActivationReader.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

// Adapted from RoundWhiteDiscKit.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/CoreNFCActivationReader.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

#if os(iOS) && canImport(CoreNFC)
    @preconcurrency import CoreNFC

    @available(iOS 16.2, *)
    final class Libre3NFCActivationReader: NSObject, @unchecked Sendable {
        typealias Prepare = (Libre3NFCPatchInfo) throws -> Void
        typealias SaveResponse = (Libre3NFCPatchInfo, Libre3NFCActivationResponse) throws -> Void
        // Setup writes these on main. NFC work resumes on the cooperative executor, so
        // closure ownership must be synchronized just like the session continuation.
        private var prepareHandler: Prepare?
        private var responseHandler: SaveResponse?
        var prepare: Prepare? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return prepareHandler
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                prepareHandler = newValue
            }
        }
        var saveResponse: SaveResponse? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return responseHandler
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                responseHandler = newValue
            }
        }
        private let queue = DispatchQueue(label: "xdrip.libre3.nfc", qos: .userInitiated)
        private let lock = NSLock()
        private var session: NFCTagReaderSession?
        private var continuation: CheckedContinuation<Libre3NFCScanResult, Error>?
        private var mode: Libre3NFCScanMode?

        func scan(mode: Libre3NFCScanMode) async throws -> Libre3NFCScanResult {
            guard NFCTagReaderSession.readingAvailable else {
                Libre3Log.event(.nfcUnavailable)
                throw Libre3NFCError.readerUnavailable
            }

            return try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if self.continuation != nil {
                    lock.unlock()
                    continuation.resume(throwing: Libre3NFCError.sessionAlreadyActive)
                    return
                }
                self.continuation = continuation
                self.mode = mode

                let session = NFCTagReaderSession(pollingOption: [.iso15693], delegate: self, queue: queue)
                session?.alertMessage = TextsLibre3.localized(
                    "Hold the TOP of your iPhone very close to the Sensor",
                    comment: "NFC system sheet prompt while waiting for the sensor. TOP is capitalised deliberately: the antenna is at the iPhone's top edge, not its back."
                )
                self.session = session
                guard let session else {
                    // Fail this continuation while its ownership is still established.
                    // Unlocking and calling complete without a session identity could
                    // otherwise cancel a retry which started between those operations.
                    self.continuation = nil
                    self.mode = nil
                    lock.unlock()
                    Libre3Log.event(.nfcUnavailable)
                    continuation.resume(throwing: Libre3NFCError.readerUnavailable)
                    return
                }
                // Record the start before a session callback can report its outcome.
                Libre3Log.event(.nfcScanStarted)
                lock.unlock()
                session.begin()
            }
        }

        func cancel() { complete(.failure(CancellationError())) }

        private func complete(_ result: Result<Libre3NFCScanResult, Error>, for expectedSession: NFCTagReaderSession? = nil) {
            lock.lock()
            if let expectedSession, session !== expectedSession {
                lock.unlock()
                return
            }
            let continuation = self.continuation
            self.continuation = nil
            self.mode = nil
            let session = self.session
            self.session = nil
            lock.unlock()

            // Ownership is consumed above. A late invalidation or cancellation has no second outcome.
            guard let continuation else { return }
            switch result {
            case .success(let value):
                Libre3Log.event(.nfcScanSucceeded)
                session?.alertMessage = TextsLibreNFC.scanComplete
                session?.invalidate()
                continuation.resume(returning: value)
            case .failure(let error):
                Libre3Log.event(Self.scanOutcome(for: error), error: error)
                session?.invalidate(errorMessage: error.localizedDescription)
                continuation.resume(throwing: error)
            }
        }

        // Core NFC reports normal cancellation and timeout through its invalidation error codes.
        static func scanOutcome(for error: Error) -> TroubleshootingCGMActivity {
            let code = (error as? NFCReaderError)?.code
            if error is CancellationError || code == .readerSessionInvalidationErrorUserCanceled {
                return .nfcScanCancelled
            }
            if code == .readerSessionInvalidationErrorSessionTimeout { return .nfcScanTimedOut }
            if code == .readerErrorUnsupportedFeature || (error as? Libre3NFCError) == .readerUnavailable {
                return .nfcUnavailable
            }
            return .nfcScanFailed
        }

        private func run(tag: NFCISO15693Tag, in session: NFCTagReaderSession) async {
            do {
                guard let (mode, prepare, saveResponse) = inputs(for: session) else {
                    throw Libre3NFCError.noTag
                }

                let patchRaw = try await customCommand(
                    tag: tag,
                    code: 0xa1,
                    parameters: Libre3NFCActivationCommand.readPatchInfoCustomRequestParameters
                )
                let patchInfo = try Libre3NFCPatchInfo(raw: patchRaw)

                guard isCurrent(session) else { throw CancellationError() }
                try prepare?(patchInfo)

                switch mode {
                case .readPatchInfo:
                    complete(
                        .success(Libre3NFCScanResult(patchInfo: patchInfo)), for: session
                    )

                case .activateFreshSensor(let receiverID, let explicitTime):
                    guard patchInfo.recommendedCommandCode == .activate else {
                        throw Libre3NFCError.unexpectedSensorState(patchInfo: patchInfo)
                    }
                    try await runActivationCommand(
                        tag: tag,
                        session: session,
                        patchInfo: patchInfo,
                        commandCode: .activate,
                        receiverID: receiverID,
                        explicitTime: explicitTime,
                        saveResponse: saveResponse
                    )

                case .switchReceiver(let receiverID, let explicitTime):
                    guard patchInfo.recommendedCommandCode == .switchReceiver else {
                        throw Libre3NFCError.unexpectedSensorState(patchInfo: patchInfo)
                    }
                    try await runActivationCommand(
                        tag: tag,
                        session: session,
                        patchInfo: patchInfo,
                        commandCode: .switchReceiver,
                        receiverID: receiverID,
                        explicitTime: explicitTime,
                        saveResponse: saveResponse
                    )

                case .activateOrSwitchReceiver(let receiverID, let explicitTime):
                    let commandCode = patchInfo.recommendedCommandCode
                    try await runActivationCommand(
                        tag: tag,
                        session: session,
                        patchInfo: patchInfo,
                        commandCode: commandCode,
                        receiverID: receiverID,
                        explicitTime: explicitTime,
                        saveResponse: saveResponse
                    )

                case .forceActivationCommand(let commandCode, let receiverID, let explicitTime):
                    try await runActivationCommand(
                        tag: tag,
                        session: session,
                        patchInfo: patchInfo,
                        commandCode: commandCode,
                        receiverID: receiverID,
                        explicitTime: explicitTime,
                        saveResponse: saveResponse
                    )
                }
            } catch {
                complete(.failure(error), for: session)
            }
        }

        private func runActivationCommand(
            tag: NFCISO15693Tag,
            session: NFCTagReaderSession,
            patchInfo: Libre3NFCPatchInfo,
            commandCode: Libre3NFCActivationCommandCode,
            receiverID: UInt32,
            explicitTime: UInt32?,
            saveResponse: SaveResponse?
        ) async throws {
            guard isCurrent(session) else { throw CancellationError() }
            let timeSeconds = explicitTime ?? Self.defaultActivationTimeSeconds()
            let parameters = Libre3NFCActivationCommand.customRequestParameters(
                timeSeconds: timeSeconds,
                receiverID: receiverID
            )
            let activationRaw = try await customCommand(
                tag: tag,
                code: commandCode.rawValue,
                parameters: parameters
            )
            let activation: Libre3NFCActivationResponse
            do {
                activation = try Libre3NFCActivationResponse(raw: activationRaw)
            } catch Libre3NFCError.invalidActivationResponse(let raw) {
                throw Libre3NFCError.invalidActivationResponseForPatch(
                    commandCode: commandCode,
                    patchInfo: patchInfo,
                    raw: raw
                )
            }
            try saveResponse?(patchInfo, activation)
            complete(
                .success(
                    Libre3NFCScanResult(
                        patchInfo: patchInfo,
                        commandCode: commandCode,
                        commandParameters: parameters,
                        activationResponse: activation
                    )
                ),
                for: session
            )
        }

        private func isCurrent(_ candidate: NFCTagReaderSession) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return session === candidate && continuation != nil
        }

        /// Freeze one scan's inputs before any await. Cancellation can clear mode, and a
        /// retry can replace callbacks while an older NFC command is still completing.
        /// Its response must use the original persistence callback and session identity.
        private func inputs(for candidate: NFCTagReaderSession) -> (Libre3NFCScanMode, Prepare?, SaveResponse?)? {
            lock.lock()
            defer { lock.unlock() }
            guard session === candidate, continuation != nil, let mode else { return nil }
            return (mode, prepareHandler, responseHandler)
        }

        private func customCommand(tag: NFCISO15693Tag, code: UInt8, parameters: Data) async throws -> Data {
            try await withCheckedThrowingContinuation { continuation in
                tag.customCommand(
                    requestFlags: [.highDataRate],
                    customCommandCode: Int(code),
                    customRequestParameters: parameters
                ) { result in
                    continuation.resume(with: result)
                }
            }
        }

        private static func defaultActivationTimeSeconds() -> UInt32 {
            let now = UInt64(Date().timeIntervalSince1970.rounded(.down))
            return UInt32(max(0, now - 1))
        }
    }

    @available(iOS 16.2, *)
    extension Libre3NFCActivationReader: NFCTagReaderSessionDelegate {
        func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

        func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
            lock.lock()
            guard self.session === session else {
                lock.unlock()
                return
            }
            let continuation = self.continuation
            self.continuation = nil
            self.mode = nil
            self.session = nil
            lock.unlock()
            if let continuation {
                Libre3Log.event(Self.scanOutcome(for: error), error: error)
                continuation.resume(throwing: error)
            }
        }

        func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
            guard isCurrent(session) else { return }
            guard tags.count == 1, let tag = tags.first else {
                session.alertMessage = TextsLibre3.localized(
                    "More than one tag detected.",
                    comment: "NFC system sheet, several tags in range so the sensor is ambiguous. Polling restarts after this."
                )
                session.restartPolling()
                complete(.failure(tags.isEmpty ? Libre3NFCError.noTag : Libre3NFCError.multipleTags), for: session)
                return
            }

            guard case .iso15693(let isoTag) = tag else {
                complete(.failure(Libre3NFCError.nonISO15693Tag), for: session)
                return
            }

            Task { [weak self] in
                do {
                    try await session.connect(to: tag)
                    await self?.run(tag: isoTag, in: session)
                } catch {
                    self?.complete(.failure(error), for: session)
                }
            }
        }
    }
#endif
