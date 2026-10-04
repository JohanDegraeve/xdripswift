import CoreBluetooth
import Foundation
import os

protocol DexcomG7AuthSessionTransport: AnyObject {
    /// Enables or disables notifications on one authentication characteristic.
    func authSessionSetNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic)

    /// Writes one control packet or `Auth_Stream` fragment through the active peripheral.
    @discardableResult
    func authSessionWrite(_ data: Data, to characteristic: CBCharacteristic, type: CBCharacteristicWriteType) -> Bool

    /// Grants primary data access after short authentication or ownership completes.
    func authSessionDidAuthenticate()

    /// Stops reconnects when a previously confirmed key is rejected by the sensor.
    func authSessionDidRejectPersistedKey()

    /// Requests a new physical connection before an incomplete ownership state is rebuilt.
    func authSessionRequiresCleanReconnect()

    /// Schedules authentication fragments on the transmitter's Core Bluetooth queue.
    func authSessionSchedule(after delay: TimeInterval, _ action: @escaping () -> Void)
}

/// Implements the G7 primary authentication and ownership protocol.
///
/// A G7 has two very different connection paths. In primary mode xDrip4iOS owns one authentication
/// slot and must prove that ownership before asking for data. In coexistence mode xDrip4iOS only
/// observes the connection authenticated by the Dexcom app. Keeping this state machine in a
/// separate type prevents primary-only key creation and ownership packets from leaking into the
/// passive coexistence path in `CGMG7Transmitter`.
///
/// The cryptographic operations and persisted shared-key storage live in `DexcomG7AuthBridge`.
/// This Swift type owns the BLE ordering around that bridge: notification setup, control opcodes,
/// fragmented stream payloads, reconnect boundaries, and the exact point at which a new key is
/// safe to confirm.
final class DexcomG7AuthSession {
    /// Separates a rejected saved key from the valid recovery and full-bootstrap outcomes.
    enum AuthenticationStatusAction: Equatable {
        case continueAuthentication
        case rejectPersistedKey
        case startFullBootstrap
        case reject
    }

    /// Interprets the two known completion responses after the ownership keep-alive command.
    enum OwnershipKeepAliveAction: Equatable {
        case completeOwnership
        case requestLegacyBond
        case ignore
    }

    /// Records the one protocol phase whose control and stream packets are currently valid.
    private enum Stage: String {
        case idle
        case authenticating
        case certificateExchange
        case proofOfPossession
        case keepAlive
        case bondRequest
        case pairConfirmation
        case authenticated
    }

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMG7)

    /// Owns all cryptographic calculations and the confirmed shared-key store.
    private let authBridge: DexcomG7AuthBridge

    /// Authentication identity selected inside the G7 sensor.
    private(set) var bluetoothSlot: DexcomG7BluetoothSlot

    /// Small control characteristic used for opcodes, phase status, and challenge packets.
    private weak var receiveAuthenticationCharacteristic: CBCharacteristic?

    /// Fragment stream used for J-PAKE payloads, certificates, and ownership signatures.
    private weak var authStreamCharacteristic: CBCharacteristic?

    /// Bluetooth operations and completion callbacks supplied by `CGMG7Transmitter`.
    weak var transport: DexcomG7AuthSessionTransport?

    // `Receive_Authentication` carries small control packets. `Auth_Stream` carries the larger
    // J-PAKE, certificate, and signature payloads in BLE-sized fragments. The stage and pending
    // fields join those two asynchronous streams back into one ordered protocol exchange.
    /// Current protocol boundary used to reject packets from an earlier or unexpected phase.
    private var stage: Stage = .idle

    /// Reassembles large protocol payloads independently of Core Bluetooth notification chunks.
    private var authStreamBuffer = Data()

    /// Records that `Auth_Stream` notifications are ready to receive immediate phase payloads.
    private var authStreamNotifyReady = false

    /// Records that small authentication control packets can now be received.
    private var receiveAuthenticationNotifyReady = false

    /// Prevents a second opening packet if notification callbacks are repeated.
    private var initialControlPacketSent = false

    /// Prevents a duplicated token challenge from creating two responses in one connection.
    private var authChallengeResponseSent = false

    /// Distinguishes full ownership from the normal persisted-key reconnect path.
    private var usingFullBootstrap = false

    /// Prevents a repeated authenticated status from restarting the certificate exchange.
    private var certificateExchangeStarted = false

    /// J-PAKE phase announced on the control characteristic and waiting for 160 stream bytes.
    private var pendingPakePhase: UInt8?

    /// Certificate phase announced on the control characteristic and waiting for stream bytes.
    private var pendingCertificatePhase: UInt8?

    /// Exact number of remote certificate bytes declared for the pending phase.
    private var pendingCertificateSize: Int?

    /// Next certificate phase accepted by the ordered three-phase exchange.
    private var expectedCertificatePhase: UInt8 = 0

    /// Control packet holding the 16-byte challenge while the 64-byte proof arrives by stream.
    private var pendingProofStatus: Data?
    // Stream writes are deliberately spaced with asyncAfter because the characteristic uses
    // writes without response. Incrementing this generation invalidates any delayed writes left
    // behind by a disconnect or configuration change so old packets cannot enter a new session.
    private var writeGeneration = 0

    init(transmitterID: String?, pairingCode: String?, bluetoothSlot: DexcomG7BluetoothSlot) {
        self.bluetoothSlot = bluetoothSlot
        authBridge = DexcomG7AuthBridge(
            transmitterID: transmitterID,
            pairingCode: pairingCode,
            authenticationSlot: bluetoothSlot.rawValue
        )
    }

    func updateTransmitterID(_ transmitterID: String?) {
        authBridge.transmitterID = transmitterID
    }

    func updatePairingCode(_ pairingCode: String?) {
        // The four-digit applicator code participates in key derivation. A key derived from the
        // previous code is therefore not valid for the replacement code, even if the peripheral
        // name happens to be unchanged.
        authBridge.pairingCode = pairingCode
        authBridge.clearSharedKey()
        resetForConnection()
    }

    /// A newly added sensor must not inherit an authentication key left by an earlier app entry.
    /// The transmitter name is resolved before this is called so the correct stored key is removed.
    func clearPersistedAuthentication() {
        authBridge.clearSharedKey()
        resetForConnection()
    }

    func updateBluetoothSlot(_ bluetoothSlot: DexcomG7BluetoothSlot) {
        guard self.bluetoothSlot != bluetoothSlot else { return }

        // Each Bluetooth channel is a separate authentication identity inside the sensor. Never
        // carry an in-memory exchange across slots. The bridge resolves persisted key material by
        // transmitter and slot when the next authentication begins.
        self.bluetoothSlot = bluetoothSlot
        authBridge.authenticationSlot = bluetoothSlot.rawValue
        resetForConnection()
    }

    func resetForConnection() {
        // This is intentionally connection-scoped cleanup. It discards partially received packets
        // and cancels delayed writes, but it does not erase a confirmed shared key. Confirmed keys
        // are what make normal five-minute reconnects use the short authentication path.
        writeGeneration &+= 1
        stage = .idle
        receiveAuthenticationCharacteristic = nil
        authStreamCharacteristic = nil
        authStreamBuffer.removeAll(keepingCapacity: true)
        authStreamNotifyReady = false
        receiveAuthenticationNotifyReady = false
        initialControlPacketSent = false
        authChallengeResponseSent = false
        usingFullBootstrap = false
        certificateExchangeStarted = false
        pendingPakePhase = nil
        pendingCertificatePhase = nil
        pendingCertificateSize = nil
        expectedCertificatePhase = 0
        pendingProofStatus = nil
        authBridge.resetSession()
    }

    func configure(
        receiveAuthentication: CBCharacteristic,
        authStream: CBCharacteristic
    ) {
        receiveAuthenticationCharacteristic = receiveAuthentication
        authStreamCharacteristic = authStream

        // Enable `Auth_Stream` first. The transmitter can announce a J-PAKE phase on the control
        // characteristic and immediately send its 160-byte payload on `Auth_Stream`. Reversing this
        // order creates a race in which the first stream fragments arrive before we can observe
        // them. Juggluco uses the same ordering:
        // https://github.com/j-kaltes/Juggluco/blob/primary/Common/src/dex/java/tk/glucodata/DexGattCallback.java
        if authStream.isNotifying {
            authStreamNotifyReady = true
            subscribeToReceiveAuthentication()
        } else {
            trace("G7 primary auth: enabling Auth_Stream notifications", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            transport?.authSessionSetNotifyValue(true, for: authStream)
        }
    }

    func notificationStateUpdated(for characteristic: CBCharacteristic) {
        if characteristic === authStreamCharacteristic {
            authStreamNotifyReady = characteristic.isNotifying
            guard characteristic.isNotifying else { return }
            trace("G7 primary auth: Auth_Stream ready. Enabling Receive_Authentication", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            subscribeToReceiveAuthentication()
            return
        }

        if characteristic === receiveAuthenticationCharacteristic {
            receiveAuthenticationNotifyReady = characteristic.isNotifying
            guard characteristic.isNotifying else { return }
            trace("G7 primary auth: Receive_Authentication ready", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            startAuthenticationIfReady()
        }
    }

    func receiveAuthStream(_ value: Data) {
        guard stage != .idle else { return }
        trace("G7 primary J-PAKE stream RX: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, value.hexEncodedString())

        // Core Bluetooth notification boundaries do not represent protocol-message boundaries.
        // Append every fragment and let the active phase consume only its documented byte count.
        // Any remaining bytes stay buffered for the next control status.
        authStreamBuffer.append(value)
        processPendingPakeIfReady()
        processPendingCertificateIfReady()
        processPendingProofIfReady()
    }

    func receiveAuthentication(_ value: Data) {
        guard let firstByte = value.first,
              let opCode = DexcomTransmitterOpCode(rawValue: firstByte)
        else {
            trace("G7 primary auth received an unknown packet: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, value.hexEncodedString())
            return
        }

        trace("G7 primary auth RX %{public}@: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, opCode.description, value.hexEncodedString())

        switch opCode {
        case .authRequestRx:
            // Both the short and full paths finish with the normal token challenge. The bridge
            // chooses the correct confirmed or newly derived key for the response.
            handleAuthRequest(value)

        case .authChallengeRx:
            // This status tells us whether the sensor accepted the cryptographic response and
            // whether the selected slot already considers this client paired.
            handleAuthStatus(value)

        case .exchangePakePayload:
            // The control packet identifies the J-PAKE phase. Its corresponding 160-byte payload
            // arrives independently on `Auth_Stream` and may already be buffered.
            guard value.count >= 3, value[1] == 0 else {
                fail("transmitter rejected J-PAKE", packet: value)
                return
            }
            pendingPakePhase = value[2]
            processPendingPakeIfReady()

        case .certificateExchange:
            // Certificate control responses declare the phase and payload length. The actual
            // remote certificate bytes arrive on `Auth_Stream`.
            handleCertificateStatus(value)

        case .proofOfPossession:
            // The 16-byte challenge is carried here while the accompanying 64-byte remote proof
            // is carried on `Auth_Stream`. Both must be present before we sign our response.
            handleProofStatus(value)

        case .authStatusTx:
            guard stage == .proofOfPossession else { return }

            // The sensor has accepted our ownership signature. The 0619 exchange closes the
            // ownership transaction, but different G7-family firmware returns one of two valid
            // completion sequences handled below.
            trace("G7 primary ownership: proof accepted. Sending 0619", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            stage = .keepAlive
            writeControl(Data([DexcomTransmitterOpCode.keepAliveTx.rawValue, 0x19]))

        case .keepAliveTx:
            guard stage == .keepAlive else { return }
            switch Self.ownershipKeepAliveAction(for: value) {
            case .completeOwnership:
                // A G7 replies 0601 after accepting the proof and 0619 keep-alive request. Juggluco
                // also treats 0601 as the point where authenticated data access can begin:
                // https://github.com/j-kaltes/Juggluco/blob/primary/Common/src/dex/java/tk/glucodata/DexGattCallback.java
                // Confirm the derived key here so a later connection can restore it instead of
                // repeating ownership and replacing another app's authentication credential.
                authBridge.confirmSharedKey()
                stage = .authenticated
                trace("G7 primary ownership: received 0601. Shared key confirmed", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
                transport?.authSessionDidAuthenticate()

            case .requestLegacyBond:
                // Retain the older 0600 path for transmitter variants that require the explicit
                // bond request before returning their final pairing confirmation.
                trace("G7 primary ownership: received 0600. Sending bond request 07", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
                stage = .bondRequest
                writeControl(PairRequestTxMessage().data)

            case .ignore:
                return
            }

        case .bondRequestTx:
            // This branch exists only for the older 0600 completion sequence. It must not run
            // after the normal 0601 response because that would add an unnecessary pairing step.
            guard stage == .bondRequest, value == Data([DexcomTransmitterOpCode.bondRequestTx.rawValue, 0x00]) else { return }
            stage = .pairConfirmation
            trace("G7 primary ownership: received 0700. Waiting for 0801", log: log, category: ConstantsLog.categoryCGMG7, type: .info)

        case .pairRequestRx:
            guard stage == .pairConfirmation,
                  value == Data([DexcomTransmitterOpCode.pairRequestRx.rawValue, 0x01]) else { return }
            // 0801 is the final acknowledgement on the legacy bond path. Only now promote the
            // derived key from temporary session material to the persisted reconnect key.
            authBridge.confirmSharedKey()
            stage = .authenticated
            trace("G7 primary ownership: received 0801. Shared key confirmed", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            transport?.authSessionDidAuthenticate()

        default:
            break
        }
    }

    private func subscribeToReceiveAuthentication() {
        guard let receiveAuthenticationCharacteristic else { return }
        if receiveAuthenticationCharacteristic.isNotifying {
            receiveAuthenticationNotifyReady = true
            startAuthenticationIfReady()
        } else {
            transport?.authSessionSetNotifyValue(true, for: receiveAuthenticationCharacteristic)
        }
    }

    private func startAuthenticationIfReady() {
        guard authStreamNotifyReady,
              receiveAuthenticationNotifyReady,
              !initialControlPacketSent else { return }

        do {
            // The bridge returns either a short-auth control packet when a confirmed key exists or
            // the first J-PAKE packet when this slot still needs ownership. Inspecting the opcode
            // records which path is active so later status handling cannot confuse the two.
            let packet = try authBridge.initialControlPacket()
            usingFullBootstrap = packet.first == DexcomTransmitterOpCode.exchangePakePayload.rawValue
            stage = .authenticating
            initialControlPacketSent = true
            trace(
                "G7 primary auth: starting %{public}@ on %{public}@ slot 0x%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .info,
                usingFullBootstrap ? "full J-PAKE bootstrap" : "persisted-key short authentication",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
                String(format: "%02X", bluetoothSlot.rawValue)
            )
            writeControl(packet)
        } catch {
            fail("could not create the initial authentication packet: \(error.localizedDescription)")
        }
    }

    private func handleAuthRequest(_ value: Data) {
        guard !authChallengeResponseSent,
              let message = AuthRequestRxMessage(data: value) else { return }

        do {
            let response = try authBridge.authChallengeResponse(
                forTokenHash: message.tokenHash,
                challenge: message.challenge
            )
            authChallengeResponseSent = true
            trace("G7 primary auth: sending challenge response using %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, authBridge.lastResolvedAuthKeyLabel)
            writeControl(response)
        } catch {
            fail("could not create the challenge response: \(error.localizedDescription)")
        }
    }

    private func handleAuthStatus(_ value: Data) {
        guard let message = AuthChallengeRxMessage(data: value) else {
            fail("could not parse authentication status", packet: value)
            return
        }

        trace("G7 primary auth status: authenticated=%{public}@ paired=%{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, message.authenticated.description, message.paired.description)

        switch Self.authenticationStatusAction(
            usingFullBootstrap: usingFullBootstrap,
            authenticated: message.authenticated,
            paired: message.paired
        ) {
        case .rejectPersistedKey:
            // Do not automatically erase the key and claim ownership again. A failed saved key can
            // mean that another app now owns this slot. Stopping preserves that external ownership
            // and avoids a reconnect loop that repeatedly changes credentials.
            trace(
                "G7 primary auth: the saved key was not accepted. Stopping this primary attempt",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error
            )
            transport?.authSessionDidRejectPersistedKey()
            return

        case .startFullBootstrap:
            // Authenticated but not paired is different from an invalid key. The sensor recognised
            // the key material but reports incomplete ownership, so clear it and begin one clean
            // bootstrap on the next physical connection.
            trace(
                "G7 primary auth: ownership is incomplete. Clearing the key and reconnecting for full bootstrap",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .info
            )
            authBridge.clearSharedKey()
            transport?.authSessionRequiresCleanReconnect()
            return

        case .reject:
            // A full bootstrap rejection means the candidate key was never accepted. It must not
            // survive as reconnect material.
            authBridge.clearSharedKey()
            fail("authentication was rejected", packet: value)
            return

        case .continueAuthentication:
            break
        }

        if usingFullBootstrap {
            // Successful J-PAKE authentication establishes encrypted access, then the certificate
            // and proof exchange establishes ownership of the selected slot.
            guard !certificateExchangeStarted else { return }
            startCertificateExchange()
        } else if message.paired {
            // A confirmed key plus authenticated and paired status is the normal fast reconnect.
            // No ownership packets are needed, so data access can begin immediately.
            stage = .authenticated
            transport?.authSessionDidAuthenticate()
        }
    }

    /// A rejected saved key is terminal for this connection attempt. It must not silently start a
    /// new ownership exchange because that can replace the authentication used by the Dexcom app.
    /// The separate authenticated but unpaired state still uses the established bootstrap recovery.
    static func authenticationStatusAction(
        usingFullBootstrap: Bool,
        authenticated: Bool,
        paired: Bool
    ) -> AuthenticationStatusAction {
        if usingFullBootstrap {
            return authenticated ? .continueAuthentication : .reject
        }
        if authenticated {
            return paired ? .continueAuthentication : .startFullBootstrap
        }
        return .rejectPersistedKey
    }

    /// Decodes the keep-alive response that follows a successful ownership proof. Current G7
    /// sensors use 0601 to signal that authenticated data access is ready. The 0600 response is
    /// kept as a compatibility route into the older explicit bond exchange.
    static func ownershipKeepAliveAction(for value: Data) -> OwnershipKeepAliveAction {
        switch value {
        case Data([DexcomTransmitterOpCode.keepAliveTx.rawValue, 0x01]):
            return .completeOwnership
        case Data([DexcomTransmitterOpCode.keepAliveTx.rawValue, 0x00]):
            return .requestLegacyBond
        default:
            return .ignore
        }
    }

    private func processPendingPakeIfReady() {
        guard let phase = pendingPakePhase,
              authStreamBuffer.count >= 160 else { return }

        // Each J-PAKE phase has exactly 160 remote bytes. Consume one phase only after both its
        // control status and complete stream payload have arrived, regardless of arrival order.
        let payload = authStreamBuffer.prefix(160)
        authStreamBuffer.removeFirst(160)
        pendingPakePhase = nil

        do {
            var packetObjects: NSArray?
            let control = try authBridge.handlePakePayload(
                forPhase: phase,
                payload: Data(payload),
                streamPackets: &packetObjects
            )
            let packets = packetObjects as? [Data] ?? []
            trace("G7 primary J-PAKE phase %{public}d complete", log: log, category: ConstantsLog.categoryCGMG7, type: .info, Int(phase))
            writeExchange(streamPackets: packets, controlPacket: control, reason: "J-PAKE phase \(phase)")
        } catch {
            fail("J-PAKE phase \(phase) failed: \(error.localizedDescription)")
        }
    }

    private func startCertificateExchange() {
        // Clear the shared stream buffer at the protocol boundary. J-PAKE bytes must never be
        // interpreted as certificate bytes if a device delivered unusual fragment boundaries.
        certificateExchangeStarted = true
        stage = .certificateExchange
        expectedCertificatePhase = 0
        pendingCertificatePhase = nil
        pendingCertificateSize = nil
        authStreamBuffer.removeAll(keepingCapacity: true)

        do {
            trace("G7 primary ownership: starting certificate exchange", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            try writeControl(authBridge.certificateRequest(forPhase: 0))
        } catch {
            fail("could not create certificate phase 0: \(error.localizedDescription)")
        }
    }

    private func handleCertificateStatus(_ value: Data) {
        guard stage == .certificateExchange,
              value.count >= 7,
              value[1] == 0
        else {
            fail("certificate exchange was rejected", packet: value)
            return
        }

        let phase = value[2]
        guard phase == expectedCertificatePhase, phase <= 2 else {
            fail("certificate phase was out of order", packet: value)
            return
        }

        // The payload size is little-endian in the control response. Limit it before buffering or
        // passing anything to the native bridge so a malformed packet cannot request unbounded
        // memory. Phase 2 is the terminal phase and therefore has no remote payload.
        let size = Int(UInt32(value[3]) |
            (UInt32(value[4]) << 8) |
            (UInt32(value[5]) << 16) |
            (UInt32(value[6]) << 24))
        guard size <= 4096, phase < 2 || size == 0 else {
            fail("certificate payload size was invalid", packet: value)
            return
        }

        pendingCertificatePhase = phase
        pendingCertificateSize = size
        processPendingCertificateIfReady()
    }

    private func processPendingCertificateIfReady() {
        guard let phase = pendingCertificatePhase,
              let size = pendingCertificateSize,
              authStreamBuffer.count >= size else { return }

        // Remote certificate contents are validated inside the bridge. Swift only coordinates the
        // declared byte count and advances the three control phases in order.
        if size > 0 {
            authStreamBuffer.removeFirst(size)
        }
        pendingCertificatePhase = nil
        pendingCertificateSize = nil
        expectedCertificatePhase = phase &+ 1

        do {
            let packets = try authBridge.certificateStreamPackets(forPhase: phase)
            trace("G7 primary ownership: certificate phase %{public}d complete (%{public}d remote bytes)", log: log, category: ConstantsLog.categoryCGMG7, type: .info, Int(phase), size)
            if phase < 2 {
                let nextControl = try authBridge.certificateRequest(forPhase: phase + 1)
                writeExchange(streamPackets: packets, controlPacket: nextControl, reason: "certificate phase \(phase)")
            } else {
                writeControl(authBridge.makeProofOfPossessionChallengeRequest())
            }
        } catch {
            fail("certificate phase \(phase) failed: \(error.localizedDescription)")
        }
    }

    private func handleProofStatus(_ value: Data) {
        guard stage == .certificateExchange,
              value.count == 18,
              value[1] == 0
        else {
            fail("proof-of-possession request was invalid", packet: value)
            return
        }

        pendingProofStatus = value
        processPendingProofIfReady()
    }

    private func processPendingProofIfReady() {
        guard let status = pendingProofStatus,
              authStreamBuffer.count >= 64 else { return }

        // The bridge validates the remote proof while producing our signature. Consume the full
        // remote proof before moving to the ownership completion stage.
        authStreamBuffer.removeFirst(64)
        pendingProofStatus = nil

        do {
            let challenge = status.subdata(in: 2 ..< 18)
            let signature = try authBridge.proofOfPossessionResponse(forChallenge: challenge)
            let packets = signature.chunked(into: 20)
            stage = .proofOfPossession
            trace("G7 primary ownership: proof signed. Sending signature and 0d0002", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            writeExchange(
                streamPackets: packets,
                controlPacket: Data([DexcomTransmitterOpCode.authStatusTx.rawValue, 0x00, 0x02]),
                reason: "proof of possession"
            )
        } catch {
            fail("proof-of-possession signing failed: \(error.localizedDescription)")
        }
    }

    private func writeExchange(streamPackets: [Data], controlPacket: Data, reason: String) {
        guard authStreamCharacteristic != nil else {
            fail("Auth_Stream is unavailable for \(reason)")
            return
        }

        // Send all stream fragments before the control packet that tells the sensor to process
        // them. Writes without response have no per-packet acknowledgement, so modest spacing is
        // required to avoid overrunning the peripheral. The generation guard cancels the sequence
        // if the BLE connection is reset while these closures are waiting.
        let generation = writeGeneration
        let packetSpacing: TimeInterval = 0.04
        for (index, packet) in streamPackets.enumerated() where !packet.isEmpty {
            transport?.authSessionSchedule(after: packetSpacing * Double(index)) { [weak self] in
                guard let self,
                      self.writeGeneration == generation,
                      let authStreamCharacteristic = self.authStreamCharacteristic else { return }
                trace("G7 primary %{public}@ TX stream %{public}d/%{public}d: %{public}@", log: self.log, category: ConstantsLog.categoryCGMG7, type: .debug, reason, index + 1, streamPackets.count, packet.hexEncodedString())
                self.transport?.authSessionWrite(packet, to: authStreamCharacteristic, type: .withoutResponse)
            }
        }

        let delay = packetSpacing * Double(streamPackets.count + 1)
        transport?.authSessionSchedule(after: delay) { [weak self] in
            guard let self, self.writeGeneration == generation else { return }
            self.writeControl(controlPacket)
        }
    }

    private func writeControl(_ data: Data) {
        guard let receiveAuthenticationCharacteristic else {
            fail("Receive_Authentication is unavailable")
            return
        }
        trace("G7 primary auth TX: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, data.hexEncodedString())
        transport?.authSessionWrite(data, to: receiveAuthenticationCharacteristic, type: .withResponse)
    }

    private func fail(_ message: String, packet: Data? = nil) {
        trace("G7 primary auth failed at %{public}@: %{public}@ packet=%{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, stage.rawValue, message, packet?.hexEncodedString() ?? "none")
    }
}

private extension Data {
    func chunked(into size: Int) -> [Data] {
        stride(from: 0, to: count, by: size).map { offset in
            subdata(in: offset ..< Swift.min(offset + size, count))
        }
    }
}
