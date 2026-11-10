//
//  NovoPenNFCReader.swift
//  xdrip
//
//  Ported from xDrip "OpenNov" by JamOrHam (NightscoutFoundation/xDrip, GPLv3).
//
//  The only NovoPen file that imports CoreNFC. Runs one NFC reader session against an ISO 7816 tag (the pen)
//  and hands the caller a `NovoPenTagTransport` to work with while the session is open.
//

import Foundation

#if os(iOS) && canImport(CoreNFC)
    @preconcurrency import CoreNFC

    /// Sends command APDUs through a connected CoreNFC ISO 7816 tag.
    private struct CoreNFCTransport: NovoPenTagTransport {
        let tag: NFCISO7816Tag

        func send(_ apdu: Data) async throws -> (data: Data, status: UInt16) {
            guard let command = NFCISO7816APDU(data: apdu) else {
                throw NovoPenError.badFrame("not an ISO 7816 APDU: \(apdu.hexEncodedString())")
            }
            let (data, sw1, sw2) = try await tag.sendCommand(apdu: command)
            return (data, UInt16(sw1) << 8 | UInt16(sw2))
        }
    }

    final class NovoPenNFCReader: NSObject, @unchecked Sendable {
        /// One running scan. Type-erased so the delegate need not know the caller's result type.
        private struct ActiveScan {
            let session: NFCTagReaderSession
            /// Runs the caller's work on the connected tag. Finishes the scan itself.
            let run: (NFCISO7816Tag) async -> Void
            /// Resumes the caller with an error, for outcomes that arrive before `run`.
            let fail: (Error) -> Void
        }

        private let queue = DispatchQueue(label: "xdrip.novopen.nfc", qos: .userInitiated)
        private let lock = NSLock()
        private var active: ActiveScan?

        /// Opens an NFC session, waits for the pen, connects and runs `work`. `setMessage` updates the system sheet text.
        /// The sheet closes with `scanComplete`, or with the error message `failureMessage` gives for a result that is only partly good.
        /// Throws `CancellationError` if the user cancels, `NFCReaderError` if the session times out, `NovoPenError.notAPen` for a tag that is not ISO 7816.
        func scan<T>(failureMessage: @escaping (T) -> String? = { _ in nil }, _ work: @escaping (NovoPenTagTransport, _ setMessage: @escaping (String) -> Void) async throws -> T) async throws -> T {
            guard NFCTagReaderSession.readingAvailable else { throw NFCReaderError(.readerErrorUnsupportedFeature) }

            return try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                // ponytail: one scan at a time; a second scan() fails instead of queueing
                if active != nil {
                    lock.unlock()
                    continuation.resume(throwing: NovoPenError.limitExceeded("a scan is already running"))
                    return
                }
                guard let session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: queue) else {
                    lock.unlock()
                    continuation.resume(throwing: NFCReaderError(.readerErrorUnsupportedFeature))
                    return
                }
                session.alertMessage = Texts_NovoPen.holdPenNearPhone
                // Strong self on purpose: the reader stays alive until `take` clears `active`, so the continuation always resumes.
                active = ActiveScan(
                    session: session,
                    run: { tag in
                        // The session can end while the tag connects. Then there is nobody to work for.
                        guard self.current(session) != nil else { return }
                        do {
                            let value = try await work(CoreNFCTransport(tag: tag), { session.alertMessage = $0 })
                            guard self.take(session) != nil else { return }
                            if let message = failureMessage(value) {
                                session.invalidate(errorMessage: message)
                            } else {
                                session.alertMessage = Texts_NovoPen.scanComplete
                                session.invalidate()
                            }
                            continuation.resume(returning: value)
                        } catch {
                            guard self.take(session) != nil else { return }
                            session.invalidate(errorMessage: Self.message(for: error))
                            continuation.resume(throwing: error)
                        }
                    },
                    fail: { continuation.resume(throwing: $0) }
                )
                lock.unlock()
                session.begin()
            }
        }

        private func current(_ session: NFCTagReaderSession) -> ActiveScan? {
            lock.lock()
            defer { lock.unlock() }
            return active?.session === session ? active : nil
        }

        /// Removes and returns the scan if `session` still owns it. Whoever gets it back resumes the continuation, exactly once.
        private func take(_ session: NFCTagReaderSession) -> ActiveScan? {
            lock.lock()
            defer { lock.unlock() }
            guard let scan = active, scan.session === session else { return nil }
            active = nil
            return scan
        }

        private static func message(for error: Error) -> String {
            (error as? NovoPenError) == .notAPen ? Texts_NovoPen.notAPen : Texts_NovoPen.scanFailed
        }
    }

    extension NovoPenNFCReader: NFCTagReaderSessionDelegate {
        func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

        // User cancel, timeout, or iOS ended the session. Our own invalidate() calls find `active` already taken.
        func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
            let userCancelled = (error as? NFCReaderError)?.code == .readerSessionInvalidationErrorUserCanceled
            take(session)?.fail(userCancelled ? CancellationError() : error)
        }

        func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
            // two pens in range is ambiguous, keep polling
            guard let scan = current(session) else { return }
            guard tags.count == 1, let tag = tags.first else {
                session.restartPolling()
                return
            }
            guard case .iso7816(let isoTag) = tag else {
                guard take(session) != nil else { return }
                session.invalidate(errorMessage: Texts_NovoPen.notAPen)
                scan.fail(NovoPenError.notAPen)
                return
            }
            Task {
                do {
                    try await session.connect(to: tag)
                } catch {
                    guard take(session) != nil else { return }
                    session.invalidate(errorMessage: Texts_NovoPen.scanFailed)
                    scan.fail(error)
                    return
                }
                // `run` skips `work` if the session ended while connecting
                await scan.run(isoTag)
            }
        }
    }
#endif
