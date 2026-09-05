import CoreBluetooth
import CoreData
import Foundation
import os

/*
 Manages the complete Bluetooth lifecycle for a Dexcom G7, Dexcom ONE+, or Stelo sensor.

 A G7-family device combines the glucose sensor and Bluetooth transmitter in one disposable
 unit. The advertised Bluetooth name, such as DXCM..., identifies that physical sensor. Its
 four-digit applicator code is the secret needed to establish primary ownership. The selected
 Bluetooth channel identifies which independent authentication slot inside the sensor xDrip4iOS
 will use.

 There are two deliberately separate connection modes.

 Primary mode

 In primary mode xDrip4iOS owns the selected Bluetooth channel. A valid four-digit sensor code is
 required before this mode can begin. connect() uses the normal direct Core Bluetooth path,
 didConnect resolves the advertised sensor name, and characteristic discovery passes the
 Receive_Authentication and Auth_Stream characteristics to DexcomG7AuthSession.

 DexcomG7AuthSession enables Auth_Stream notifications before Receive_Authentication. This
 order matters because a small control packet can be followed immediately by a much larger
 authentication payload. Once both notification streams are ready, the session selects one of
 two authentication paths.

 A sensor and Bluetooth channel with a previously confirmed shared key use the short path. The
 sensor sends a token and challenge. DexcomG7AuthBridge.authChallengeResponse uses the stored
 16-byte key to create the AES challenge response. If the sensor reports that the client is both
 authenticated and paired, authSessionDidAuthenticate() enables Write_Control and sends the
 0x4E GetData command through sendPrimaryGlucoseRequestIfReady().

 A new sensor or an unused Bluetooth channel uses the full ownership path. The applicator code,
 advertised transmitter name, and selected channel are supplied to DexcomG7AuthBridge. The
 bridge performs the three J-PAKE phases, validates the remote elliptic-curve points and their
 zero-knowledge proofs, and derives a candidate 16-byte shared key. The low-level P-256 point and
 scalar operations are provided by the vendored micro-ecc source through DexcomG7ECC.c.
 DexcomG7AuthSession then coordinates the certificate exchange and proof of possession. The
 proof signature itself is produced by DexcomG7CryptoKitProofSigner. The candidate shared key
 is not persisted until the sensor acknowledges the final ownership step with 0x0601, or with
 the compatible legacy 0x0700 and 0x0801 sequence.

 The shared key authenticates xDrip4iOS to the sensor. It does not directly decrypt every glucose
 packet in this class. Accessing the protected characteristics causes iOS to establish the
 encrypted Bluetooth link and to show the system pairing request when required. Core Bluetooth
 performs that link encryption and decryption. By the time didUpdateValueFor receives a
 characteristic value, it contains the bytes that our normal Dexcom packet parsers can read.

 Coexistence mode

 In coexistence mode the Dexcom app owns authentication. xDrip4iOS must not send J-PAKE packets,
 restore a primary shared key, or claim any Bluetooth channel. startCoexistenceObservation()
 first asks Core Bluetooth for the G7 peripheral that is already connected by the other app.
 Scanning is used only to notice later wake cycles and repeat that system-connected lookup.
 subscribeForCoexistenceAuthentication() subscribes only to Receive_Authentication. When
 handleCoexistenceAuthentication() observes the paired and authenticated status created by
 the other app, xDrip4iOS enables Write_Control and passively receives the shared data stream.

 Keeping primaryAuthenticated and coexistenceAuthenticated separate is essential. Every
 command guard checks the flag belonging to the active mode. The primary authentication state
 machine is never notified by coexistence packets, and primary code never treats the other
 app's authenticated status as proof that xDrip4iOS owns the connection.

 Glucose and sensor information

 Primary mode receives the 0x4E glucose response requested by xDrip4iOS. Coexistence mode observes
 a 0x31 glucose packet followed by a 0x25 transmitter clock packet. The coexistence packets
 must be joined because the glucose packet alone cannot establish an absolute sensor timestamp.
 Both paths then enter processGlucose(), which applies the sensor lifetime and repeated-value
 safety checks before delivering the reading, sensor age, start date, and algorithm status to
 the common CGM delegates.

 A valid current reading also establishes the clock reference needed to date backfill packets
 and user calibrations. Backfill packets that arrive before that reference are held as raw bytes
 and parsed only after a trustworthy sensor age becomes available. The one-time 0x52 extended
 version request reports whether the sensor has a 10-day or 15-day session. That reported value
 includes the 12-hour grace period and is persisted through the G7 delegate.

 Battery and firmware diagnostics

 Diagnostic requests are deliberately made only after a valid glucose packet has proved that the
 active authentication path and Write_Control notification are ready. sendPostGlucoseCommandIfReady()
 gives a pending calibration first priority, then requests unknown lifetime information, unknown
 firmware information, or battery information that is at least two hours old. It selects only one
 diagnostic request during each short sensor wake so metadata cannot delay the next glucose cycle.

 The CRC-framed 0x4A and 0x22 requests reuse the existing Dexcom request builders. G7-family
 responses differ from G6 because they repeat the request opcode instead of replying with 0x4B or
 0x23, and they do not carry the normal G6 response CRC. Dedicated decoders therefore validate the
 complete known G7 packet prefix without weakening the established G6 response handling. Successful
 values are persisted on the disposable DexcomG7 record. Battery timing is also saved there so a
 previous G6 or G7 sensor cannot suppress the first battery request for a newly added sensor.

 Calibration

 A calibration is detached from its Core Data object before entering the Bluetooth lifecycle.
 sendCalibrationOrBoundsIfReady() converts its date into transmitter time and writes the
 0x34 command only after the active mode is authenticated and Write_Control is ready. A
 successful Bluetooth write means only that the command left the phone. The immediate 0x34
 response says whether the sensor accepted the command for processing. The later 0x32 bounds
 record is matched against both the submitted glucose value and transmitter time before the
 calibration is marked complete or rejected. Interrupted commands remain queued for the next
 natural sensor connection.

 Connection boundaries

 A G7 wakes for a short Bluetooth window approximately every five minutes. didConnect creates
 a new cycle and clears all notification, clock, frame, and command state that belongs only to
 the previous connection. didDisconnectPeripheral resolves and delivers any safe backfill,
 discards incomplete data, and removes every Core Bluetooth characteristic reference. Confirmed
 primary shared keys survive this cleanup so normal reconnects can use the short authentication
 path. Partial J-PAKE exchanges and unconfirmed keys do not survive it.
 */

@objcMembers
class CGMG7Transmitter: BluetoothTransmitter, CGMTransmitter, DexcomG7AuthSessionTransport {
    /// Describes the single post-glucose action selected for one G7 wake. Keeping the priority in a
    /// small value type makes the safety rule testable without creating a Bluetooth connection.
    enum PostGlucoseCommand: Equatable {
        case calibrationOrBounds
        case lifetime
        case firmware
        case battery
        case routineBounds
    }

    /// Names every characteristic used from the single G7 service and provides readable labels
    /// for tracing notification state. Keeping the UUID mapping here makes the routing in
    /// `didUpdateValueFor` explicit and prevents raw UUID strings being scattered through the flow.
    private enum CharacteristicUUID: String, CustomStringConvertible {
        case communication = "F8083533-849E-531C-C594-30F1F86A4EA5"
        case writeControl = "F8083534-849E-531C-C594-30F1F86A4EA5"
        case receiveAuthentication = "F8083535-849E-531C-C594-30F1F86A4EA5"
        case backfill = "F8083536-849E-531C-C594-30F1F86A4EA5"
        case authStream = "F8083538-849E-531C-C594-30F1F86A4EA5"

        var description: String {
            switch self {
            case .communication: return "Communication"
            case .writeControl: return "Write_Control"
            case .receiveAuthentication: return "Receive_Authentication"
            case .backfill: return "Backfill"
            case .authStream: return "Auth_Stream"
            }
        }
    }

    /// The short advertisement UUID used to discover a waking G7-family sensor.
    let CBUUID_Advertisement_G7 = "FEBC"

    /// The service containing authentication, glucose, command, and backfill characteristics.
    let CBUUID_Service_G7 = "F8083532-849E-531C-C594-30F1F86A4EA5"

    /// Receives G7-specific information that is not part of the common CGM transmitter contract,
    /// including algorithm status, session start date, and the detected session length.
    public weak var cGMG7TransmitterDelegate: CGMG7TransmitterDelegate?

    /// Selects the connection owner. `false` is primary mode and `true` is coexistence mode. This
    /// name is retained because it is also the established G6 configuration concept.
    private(set) var useOtherApp: Bool

    /// Selects the independent G7 authentication identity used by primary mode.
    private(set) var bluetoothSlot: DexcomG7BluetoothSlot

    /// The validated four-digit applicator code. It is required only when xDrip4iOS owns primary
    /// authentication, but is retained here so configuration boundaries can enforce that rule.
    private var pairingCode: String?

    /// Owns the complete primary-only authentication state machine. The transport callbacks below
    /// are the only route by which it can touch Core Bluetooth or grant primary readiness.
    private let authSession: DexcomG7AuthSession

    /// Becomes true only after xDrip4iOS has completed either short authentication or full ownership.
    private var primaryAuthenticated = false

    /// Stops duplicate `0x4E` requests during the same short sensor wake cycle.
    private var primaryGlucoseRequestSent = false

    /// Stops repeated ownership attempts after the sensor rejects a previously confirmed key.
    /// Removing and adding the sensor again is the intentional user-facing reset for this state.
    private var primaryAuthenticationBlocked = false
    /// A newly created Core Data entry may not yet know the `DX...` device name used to scope its
    /// stored authentication key. The one-time reset waits for `didConnect` to resolve that name.
    private var clearPersistedAuthenticationWhenIdentityIsKnown: Bool

    /// Reflects only the paired and authenticated status observed from the other app's session.
    /// It never grants primary ownership and is reset at every physical connection boundary.
    private var coexistenceAuthenticated = false

    /// Holds the relative coexistence glucose packet until its companion clock packet arrives.
    private var pendingCoexistenceGlucose: G7CoexistenceGlucoseMessage?

    /// Holds the absolute transmitter and sensor dates needed to timestamp coexistence glucose.
    private var coexistenceTransmitterTime: DexcomTransmitterTimeRxMessage?

    /// The sensor-reported total session length, including the fixed 12-hour grace period. This
    /// is initialized from Core Data and updated immediately when the `0x52` response arrives.
    private var sensorSessionLength: TimeInterval?

    /// Protects the lifetime value consumed by main-thread presentation code. The full G7 state
    /// machine remains on `bt.central`; copying only this value avoids making UI refreshes wait
    /// synchronously for a Bluetooth callback that may already be notifying the main thread.
    private let maximumSensorAgeLock = NSLock()
    private var maximumSensorAgeInDaysSnapshot: Double

    /// Prevents repeated extended-version writes during one short G7 connection. It resets on
    /// disconnect so a missing or malformed response can be retried on a later connection.
    private var extendedVersionRequestSent = false

    /// The full `0x4A` record is requested until every persisted version field is known. Keeping
    /// this decision here prevents presentation state from becoming part of the BLE protocol.
    private var firmwareVersion: String?
    private var firmwareBuildVersion: UInt32?
    private var firmwareVersionCode: UInt32?
    private var fullVersionRequestSent = false
    private var completeFirmwareSkipWasTraced = false

    /// Battery cadence belongs to this disposable sensor. A shared timestamp could incorrectly
    /// suppress the first request after one G7-family sensor is replaced by another.
    private var batteryLastReadDate: Date?
    private var batteryStatusRequestSent = false
    private var currentBatterySkipWasTraced = false

    /// Snapshot the Core Data object before it crosses into the Bluetooth lifecycle. Only the
    /// managed-object context is retained so the final transmitter result can be written safely.
    private struct PendingTransmitterCalibration {
        /// Stable identifier used to re-fetch the original calibration after a transmitter result.
        let id: String

        /// User-entered glucose value expressed in mg/dL.
        let bg: Double

        /// Wall-clock entry time later converted into the relative transmitter clock.
        let timeStamp: Date

        /// Context used only to perform the final identifier-based Core Data update.
        let managedObjectContext: NSManagedObjectContext?

        /// Snapshot of whether an earlier path already sent this treatment to a transmitter.
        let sentToTransmitter: Bool

        init(calibration: Calibration) {
            id = calibration.id
            bg = calibration.bg
            timeStamp = calibration.timeStamp
            managedObjectContext = calibration.managedObjectContext
            sentToTransmitter = calibration.sentToTransmitter
        }
    }

    /// Calibration waiting to be written or waiting for its immediate `0x34` response. A local
    /// Bluetooth write success does not remove it because that is not transmitter acceptance.
    private var calibrationToSendToTransmitter: PendingTransmitterCalibration?

    /// Calibration accepted for processing and waiting for the authoritative `0x32` bounds record.
    private var calibrationAwaitingBounds: PendingTransmitterCalibration?

    /// Relative command time used with glucose to reject a stale bounds record.
    private var lastCalibrationCommandTransmitterTime: UInt32?

    /// Records that Core Bluetooth accepted the `0x34` write and a response is now expected.
    private var calibrationWriteInFlight = false

    /// Prevents overlapping `0x32` requests during one connection.
    private var calibrationBoundsRequestSent = false

    /// Converts calibration wall time into the sensor's clock using the latest valid glucose.
    private var latestTransmitterClock: DexcomG7TransmitterClockReference?

    /// Protects calibration status reads performed by UI and Bluetooth queues.
    private let calibrationStatusLock = NSLock()

    /// Applies the permitted calibration status transitions and filters duplicate reports.
    private var calibrationStatusTracker = CGMTransmitterCalibrationStatusTracker()

    /// Retains the existing CGM contract value. G7 supplies calibrated readings, so downstream
    /// processing must not apply an additional local calibration algorithm.
    private var webOOPEnabled = true

    /// The latest trustworthy age received during this connection. Backfill remains raw until
    /// this value is available because its packets contain relative rather than absolute time.
    private var sensorAge: TimeInterval?

    /// Keeps the six-reading stalled-stream safeguard on the Bluetooth queue. UserDefaults is only
    /// the persistence boundary between launches; writing it inside a Core Bluetooth callback can
    /// synchronously notify a main-thread observer and must never block protocol processing.
    private var recentRawGlucoseValues: [Int]

    /// Accumulates decoded historical readings until the connection finishes or the transmitter
    /// sends its explicit backfill-complete response.
    private var backfill = [GlucoseData]()

    /// Tracks the newest reading already delivered so backfill ordering cannot move backwards.
    private var timeStampLastReading: Date?

    /// Holds nine-byte historical frames that arrived before current glucose established time.
    private var pendingBackfillRawFrames = [Data]()

    /// Cached characteristic objects are valid only for the current Core Bluetooth connection.
    /// Every reference is cleared on disconnect and replaced by the next discovery pass.
    private var writeControlCharacteristic: CBCharacteristic?
    private var receiveAuthenticationCharacteristic: CBCharacteristic?
    private var communicationCharacteristic: CBCharacteristic?
    private var backfillCharacteristic: CBCharacteristic?
    private var authStreamCharacteristic: CBCharacteristic?

    /// Monotonically identifies each physical connection in trace output. It helps relate the
    /// authentication, glucose, calibration, and disconnect messages from one sensor wake.
    private var cycleId = 0

    /// The configured transmitter identifier. It can be the generic discovery placeholder until
    /// Core Bluetooth supplies the authoritative advertised `DX...` name.
    private let transmitterId: String?

    /// The device name belonging to the most recently authenticated session. Lifetime fallback
    /// and diagnostics prefer it over an identifier that was merely discovered.
    private var currentlyAuthenticatedDeviceName: String?

    /// During generic new-sensor discovery, skips the previously active `DX...` name once so a
    /// replacement sensor has a fair opportunity to advertise and be selected.
    private var avoidActiveTransmitterIdDuringDiscovery = true

    /// Delivers readings and common CGM state into the normal storage and presentation pipeline.
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMG7)

    /// A missing stored peripheral name means this object is searching for a sensor that has not
    /// previously completed the app's normal Bluetooth connection lifecycle.
    var isNewDeviceDiscovery: Bool { deviceName == nil }

    /// Creates one transmitter object from the Core Data configuration and any pending treatment.
    /// Values are copied at this boundary because Bluetooth callbacks can outlive the managed
    /// object access that created the transmitter.
    init(
        address: String?,
        name: String?,
        transmitterID: String?,
        useOtherApp: Bool,
        pairingCode: String?,
        bluetoothSlot: DexcomG7BluetoothSlot,
        sensorSessionLength: TimeInterval?,
        firmwareVersion: String?,
        firmwareBuildVersion: UInt32?,
        firmwareVersionCode: UInt32?,
        batteryLastReadDate: Date?,
        calibrationToSendToTransmitter: Calibration?,
        bluetoothTransmitterDelegate: BluetoothTransmitterDelegate,
        cGMG7TransmitterDelegate: CGMG7TransmitterDelegate,
        cGMTransmitterDelegate: CGMTransmitterDelegate
    ) {
        // Primary ownership cannot be derived without the four-digit applicator code. Treat an
        // incomplete value as absent and fall back to coexistence rather than beginning a primary
        // connection that can never authenticate.
        let hasValidPairingCode = pairingCode?.count == 4 && pairingCode?.allSatisfy(\.isNumber) == true
        let resolvedUseOtherApp = useOtherApp || !hasValidPairingCode

        var addressAndName: BluetoothTransmitter.DeviceAddressAndName = .notYetConnected(
            expectedName: (transmitterID == nil || transmitterID == ConstantsBluetoothPairing.dummyDexcomG7TypeTransmitterId) ? "DX" : transmitterID
        )
        if let name { UserDefaults.standard.activeSensorTransmitterId = name }
        if let address { addressAndName = .alreadyConnectedBefore(address: address, name: name) }

        transmitterId = transmitterID
        self.useOtherApp = resolvedUseOtherApp
        self.bluetoothSlot = bluetoothSlot
        self.pairingCode = hasValidPairingCode ? pairingCode : nil
        clearPersistedAuthenticationWhenIdentityIsKnown = address == nil
        let supportedSessionLength = DexcomG7SensorLifetime.supportedSessionLength(sensorSessionLength)
        self.sensorSessionLength = supportedSessionLength
        maximumSensorAgeInDaysSnapshot = DexcomG7SensorLifetime.maximumSensorAgeInDays(
            reportedSessionLength: supportedSessionLength,
            deviceName: name ?? transmitterID
        )
        recentRawGlucoseValues = Array((UserDefaults.standard.previousRawGlucoseValues ?? []).prefix(6))
        self.firmwareVersion = firmwareVersion
        self.firmwareBuildVersion = firmwareBuildVersion
        self.firmwareVersionCode = firmwareVersionCode
        self.batteryLastReadDate = batteryLastReadDate
        authSession = DexcomG7AuthSession(
            transmitterID: transmitterID,
            pairingCode: hasValidPairingCode ? pairingCode : nil,
            bluetoothSlot: bluetoothSlot
        )
        if let calibrationToSendToTransmitter,
           !calibrationToSendToTransmitter.sentToTransmitter
        {
            self.calibrationToSendToTransmitter = PendingTransmitterCalibration(calibration: calibrationToSendToTransmitter)
            calibrationStatusTracker.transition(to: .queued)
        }

        super.init(
            addressAndName: addressAndName,
            CBUUID_Advertisement: CBUUID_Advertisement_G7,
            servicesCBUUIDs: [CBUUID(string: CBUUID_Service_G7)],
            CBUUID_ReceiveCharacteristic: CharacteristicUUID.receiveAuthentication.rawValue,
            CBUUID_WriteCharacteristic: CharacteristicUUID.writeControl.rawValue,
            bluetoothTransmitterDelegate: bluetoothTransmitterDelegate
        )

        authSession.transport = self
        cgmTransmitterDelegate = cGMTransmitterDelegate
        self.cGMG7TransmitterDelegate = cGMG7TransmitterDelegate

        if !useOtherApp, !hasValidPairingCode {
            trace("G7 primary mode requires a four-digit pairing code. Falling back to coexistence", log: log, category: ConstantsLog.categoryCGMG7, type: .error)
        }
    }

    override func prepareForRelease() {
        // Authentication and characteristic state is owned by the Core Bluetooth queue. Incrementing
        // the auth generation here also makes every delayed write from this connection a no-op. Do
        // not wait from main: the queue may be finishing a callback that publishes back to main.
        runOnCentralQueue {
            self.authSession.resetForConnection()
            self.writeControlCharacteristic = nil
            self.receiveAuthenticationCharacteristic = nil
            self.communicationCharacteristic = nil
            self.backfillCharacteristic = nil
            self.authStreamCharacteristic = nil
        }
        super.prepareForRelease()
    }

    /// Primary mode owns its connection and uses the normal direct-connect path. Coexistence only
    /// attaches after the Dexcom app has established the system Bluetooth connection.
    override func connect() {
        runOnCentralQueue { [weak self] in
            self?.connectOnCentral()
        }
    }

    private func connectOnCentral() {
        assertOnCentral()
        if useOtherApp {
            startCoexistenceObservation()
        } else if primaryAuthenticationBlocked {
            trace("G7 primary connection remains stopped after authentication rejection", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
        } else {
            super.connect()
        }
    }

    /// Duplicate advertisements let coexistence re-check the live system-connected list after the
    /// Dexcom app authenticates. No timer or delayed retry is needed.
    override func scanOptions() -> [String: Any]? {
        useOtherApp ? [CBCentralManagerScanOptionAllowDuplicatesKey: true] : nil
    }

    func transitionToUseOtherApp(_ useOtherApp: Bool) {
        runOnCentralQueue { [weak self] in
            self?.transitionToUseOtherAppOnCentral(useOtherApp)
        }
    }

    private func transitionToUseOtherAppOnCentral(_ useOtherApp: Bool) {
        assertOnCentral()
        guard self.useOtherApp != useOtherApp else { return }

        // A non-UI caller can still request primary mode. Refuse that transition when there is no
        // secret from which a primary authentication key can be established.
        guard useOtherApp || pairingCode != nil else {
            trace("G7 primary mode was not enabled because no pairing code is available", log: log, category: ConstantsLog.categoryCGMG7, type: .error)
            return
        }

        // Mode selection is frozen by the current G7 UI after initial setup, but keeping this
        // boundary correct protects restored data and any future non-UI caller. Clear every piece
        // of connection-scoped state before the new mode is allowed to discover characteristics.
        self.useOtherApp = useOtherApp
        primaryAuthenticationBlocked = false
        authSession.resetForConnection()
        primaryAuthenticated = false
        primaryGlucoseRequestSent = false
        coexistenceAuthenticated = false
        pendingCoexistenceGlucose = nil
        coexistenceTransmitterTime = nil
        extendedVersionRequestSent = false
        fullVersionRequestSent = false
        batteryStatusRequestSent = false
        resetCalibrationConnectionState(requeueInFlightCommand: true)
        if useOtherApp {
            trace("G7 switching to coexistence. Yielding the current connection to the Dexcom app", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
        }

        // Both modes configure different authentication notifications during characteristic
        // discovery. Reconnect after either transition so the existing connection cannot retain
        // the notification layout and authentication state of the mode that it just left.
        reconnectForConfigurationChange()
    }

    func transitionToPairingCode(_ pairingCode: String?) {
        runOnCentralQueue { [weak self] in
            self?.transitionToPairingCodeOnCentral(pairingCode)
        }
    }

    private func transitionToPairingCodeOnCentral(_ pairingCode: String?) {
        assertOnCentral()
        // Normalise anything other than exactly four decimal digits to nil. This keeps every later
        // authentication check working with one unambiguous representation of a missing code.
        let validCode = pairingCode?.count == 4 && pairingCode?.allSatisfy(\.isNumber) == true ? pairingCode : nil
        guard self.pairingCode != validCode else { return }
        // Changing the code changes the primary authentication secret. The auth session clears its
        // confirmed key, and a live primary connection must be rebuilt from characteristic
        // discovery so no packet from the old exchange can be reused.
        self.pairingCode = validCode
        primaryAuthenticationBlocked = false
        authSession.updatePairingCode(validCode)
        primaryAuthenticated = false
        primaryGlucoseRequestSent = false
        coexistenceAuthenticated = false
        extendedVersionRequestSent = false
        fullVersionRequestSent = false
        batteryStatusRequestSent = false
        resetCalibrationConnectionState(requeueInFlightCommand: true)
        if !useOtherApp { reconnectForConfigurationChange() }
    }

    func transitionToBluetoothSlot(_ bluetoothSlot: DexcomG7BluetoothSlot) {
        runOnCentralQueue { [weak self] in
            self?.transitionToBluetoothSlotOnCentral(bluetoothSlot)
        }
    }

    private func transitionToBluetoothSlotOnCentral(_ bluetoothSlot: DexcomG7BluetoothSlot) {
        assertOnCentral()
        guard self.bluetoothSlot != bluetoothSlot else { return }
        // Slots are independent authentication identities. A primary slot change therefore resets
        // both authentication and all commands whose acknowledgement belongs to the old channel.
        self.bluetoothSlot = bluetoothSlot
        primaryAuthenticationBlocked = false
        authSession.updateBluetoothSlot(bluetoothSlot)
        primaryAuthenticated = false
        primaryGlucoseRequestSent = false
        coexistenceAuthenticated = false
        pendingCoexistenceGlucose = nil
        coexistenceTransmitterTime = nil
        resetCalibrationConnectionState(requeueInFlightCommand: true)
        trace(
            "G7 Bluetooth channel changed to %{public}@ slot 0x%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
            String(format: "%02X", bluetoothSlot.rawValue)
        )
        if !useOtherApp { reconnectForConfigurationChange() }
    }

    override func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let discoveredName = peripheral.name ?? "nil"
        trace("Did discover peripheral with name: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, discoveredName)

        if useOtherApp {
            // Scanning is only a wake-up signal in coexistence. We never connect to the advertised
            // peripheral directly because doing so can compete with the Dexcom app. Instead ask
            // Core Bluetooth for the already-connected instance owned by that app.
            if retrieveConnectedPeripheral(withServiceUUIDs: [CBUUID(string: CBUUID_Service_G7)]) {
                trace("G7 coexistence attached to the Dexcom app connection", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            }
            return
        }

        guard isNewDeviceDiscovery else {
            super.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
            return
        }

        // A generic "DX" discovery has no entered transmitter ID to distinguish the previous
        // active sensor from a replacement. Skip the stored active name once so a still-visible old
        // peripheral does not win the new-sensor scan before the replacement advertises.
        if transmitterId == nil,
           let name = peripheral.name,
           name.hasPrefix("DX"),
           let activeId = UserDefaults.standard.activeSensorTransmitterId,
           avoidActiveTransmitterIdDuringDiscovery,
           name == activeId
        {
            trace("    one-shot skip of active transmitter id (%{public}@) during new sensor discovery", log: log, category: ConstantsLog.categoryCGMG7, type: .info, activeId)
            avoidActiveTransmitterIdDuringDiscovery = false
            return
        }

        super.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    override func reconnectAfterDisconnect(_ central: CBCentralManager) {
        if useOtherApp {
            startCoexistenceObservation()
        } else if primaryAuthenticationBlocked {
            trace("G7 primary reconnect suppressed after authentication rejection", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
        } else {
            super.reconnectAfterDisconnect(central)
        }
    }

    override func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // A G7 wakes for a short connection window. Every callback and command below must belong to
        // this window, so clear cached clocks, paired coexistence frames, notification readiness,
        // and partial calibration transport before discovering the new characteristic instances.
        cycleId += 1
        sensorAge = nil
        pendingBackfillRawFrames.removeAll(keepingCapacity: true)
        backfill.removeAll(keepingCapacity: true)
        primaryAuthenticated = false
        primaryGlucoseRequestSent = false
        coexistenceAuthenticated = false
        pendingCoexistenceGlucose = nil
        coexistenceTransmitterTime = nil
        resetCalibrationConnectionState(requeueInFlightCommand: true)
        authSession.resetForConnection()
        // The advertised DX name is the authoritative authentication identity. The manually stored
        // value remains a fallback for unusual Core Bluetooth callbacks without a peripheral name.
        let resolvedTransmitterID = peripheral.name?.hasPrefix("DX") == true ? peripheral.name : transmitterId
        authSession.updateTransmitterID(resolvedTransmitterID)

        // Removing and adding the sensor again is the simple user-facing reset. Wait until the
        // actual Bluetooth name is known so only this sensor's stored authentication is cleared.
        if clearPersistedAuthenticationWhenIdentityIsKnown {
            authSession.clearPersistedAuthentication()
            clearPersistedAuthenticationWhenIdentityIsKnown = false
            trace("G7 authentication state cleared for newly added sensor", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
        }

        // Core Bluetooth can reconnect a known peripheral without passing through connect(). Keep
        // the rejection boundary here as well so no new primary authentication can start.
        if !useOtherApp, primaryAuthenticationBlocked {
            trace("G7 primary connection stopped before authentication because the saved key was rejected", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            disconnect()
            return
        }

        trace(
            "G7 connection mode=%{public}@ channel=%{public}@ slot=0x%{public}@ cid=%{public}d",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            useOtherApp ? "coexistence" : "primary",
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
            String(format: "%02X", bluetoothSlot.rawValue),
            cycleId
        )

        handleDidConnectCommon(peripheral)
        peripheral.discoverServices([CBUUID(string: CBUUID_Service_G7)])
    }

    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)

        // Backfill notifications can precede the current glucose packet that supplies sensor age.
        // Give pending frames one final opportunity to resolve, deliver the complete chronological
        // batch, then discard anything that still cannot be dated safely.
        currentlyAuthenticatedDeviceName = nil
        processPendingBackfillFramesIfPossible()
        flushBackfillDeliveringToDelegate()
        if !pendingBackfillRawFrames.isEmpty {
            trace("    discarded %{public}d backfill frame(s) without a fresh sensor age", log: log, category: ConstantsLog.categoryCGMG7, type: .info, pendingBackfillRawFrames.count)
        }
        // Do not retain mode readiness or CBCharacteristic objects across G7 wake cycles. Core
        // Bluetooth creates new characteristic instances after discovery and the sensor requires a
        // fresh authentication status on every connection.
        sensorAge = nil
        pendingBackfillRawFrames.removeAll(keepingCapacity: true)
        primaryAuthenticated = false
        primaryGlucoseRequestSent = false
        coexistenceAuthenticated = false
        pendingCoexistenceGlucose = nil
        coexistenceTransmitterTime = nil
        extendedVersionRequestSent = false
        fullVersionRequestSent = false
        batteryStatusRequestSent = false
        resetCalibrationConnectionState(requeueInFlightCommand: true)
        authSession.resetForConnection()
        writeControlCharacteristic = nil
        receiveAuthenticationCharacteristic = nil
        communicationCharacteristic = nil
        backfillCharacteristic = nil
        authStreamCharacteristic = nil
    }

    override func peripheral(_: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        trace("didDiscoverCharacteristicsFor service %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, service.uuid.uuidString)
        if let error {
            trace("    characteristic discovery failed: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, error.localizedDescription)
            return
        }
        guard let characteristics = service.characteristics else {
            trace("    no G7 characteristics were discovered", log: log, category: ConstantsLog.categoryCGMG7, type: .error)
            return
        }

        // Cache every known characteristic from this discovery pass. Unknown characteristics are
        // ignored so a future firmware addition does not disturb the currently supported flow.
        for characteristic in characteristics {
            switch CharacteristicUUID(rawValue: characteristic.uuid.uuidString) {
            case .communication: communicationCharacteristic = characteristic
            case .writeControl: writeControlCharacteristic = characteristic
            case .receiveAuthentication: receiveAuthenticationCharacteristic = characteristic
            case .backfill: backfillCharacteristic = characteristic
            case .authStream: authStreamCharacteristic = characteristic
            case nil: break
            }
        }

        if useOtherApp {
            // Coexistence subscribes only to the other app's authentication result. It never
            // configures `Auth_Stream` and can therefore never start J-PAKE or claim ownership.
            subscribeForCoexistenceAuthentication()
        } else if let receiveAuthenticationCharacteristic, let authStreamCharacteristic {
            // Primary mode owns the authentication exchange. Hand only the two authentication
            // characteristics to the dedicated state machine and wait for its completion callback.
            authSession.configure(receiveAuthentication: receiveAuthenticationCharacteristic, authStream: authStreamCharacteristic)
        } else {
            trace("G7 primary auth characteristics are incomplete", log: log, category: ConstantsLog.categoryCGMG7, type: .error)
        }
    }

    override func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            trace("G7 value update failed for %{public}@: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, characteristic.uuid.uuidString, error.localizedDescription)
            return
        }
        guard let value = characteristic.value,
              let characteristicUUID = CharacteristicUUID(rawValue: characteristic.uuid.uuidString) else { return }

        switch characteristicUUID {
        case .writeControl:
            // Both modes receive glucose and command responses here, but the sending side remains
            // gated by the mode-specific authenticated flag.
            handleWriteControlValue(value)
        case .backfill: handleBackfillValue(value)
        case .receiveAuthentication:
            // This is the central separation between the two modes. Coexistence only interprets
            // the status bits emitted by the Dexcom-owned session. Primary passes every opcode to
            // the xDrip4iOS-owned authentication state machine.
            if useOtherApp { handleCoexistenceAuthentication(value) } else { authSession.receiveAuthentication(value) }
        case .authStream:
            // Large ownership payloads are primary-only by design.
            if !useOtherApp { authSession.receiveAuthStream(value) }
        case .communication: break
        }
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)

        if let error {
            if useOtherApp, error.localizedDescription.contains(find: "Encryption is insufficient") {
                // Coexistence never authenticates or takes ownership. The Dexcom app must complete
                // authentication. The normal sensor disconnect then ends this passive attempt and
                // the standard Bluetooth lifecycle reconnects on a later wake.
                trace("G7 coexistence is waiting for the Dexcom app to authenticate", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            } else {
                trace("G7 notification update failed for %{public}@: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, characteristic.uuid.uuidString, error.localizedDescription)
            }
            return
        }

        traceNotifyState(characteristic, label: "notification state updated")

        switch CharacteristicUUID(rawValue: characteristic.uuid.uuidString) {
        case .authStream, .receiveAuthentication:
            if !useOtherApp { authSession.notificationStateUpdated(for: characteristic) }
        case .writeControl:
            if characteristic.isNotifying {
                // Notification readiness is the last transport prerequisite for control commands.
                // Coexistence may submit a queued calibration after observing Dexcom authentication.
                // Primary first asks for the current reading after completing its own authentication.
                if useOtherApp { sendCalibrationOrBoundsIfReady() }
                else { sendPrimaryGlucoseRequestIfReady() }
            }
        case .backfill, .communication, nil: break
        }
    }

    override func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didWriteValueFor: characteristic, error: error)

        guard error != nil,
              CharacteristicUUID(rawValue: characteristic.uuid.uuidString) == .writeControl else { return }

        if calibrationWriteInFlight {
            // CoreBluetooth rejected the local write before the transmitter could answer. Keep the
            // Core Data calibration unsent and retry it from a clean connection cycle.
            calibrationWriteInFlight = false
            setCalibrationStatus(.queued)
            trace(
                "G7 calibration write failed mode=%{public}@ channel=%{public}@ id=%{public}@. Queued for retry",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
                calibrationToSendToTransmitter?.id ?? "none"
            )
            disconnect()
        } else if calibrationBoundsRequestSent {
            calibrationBoundsRequestSent = false
            trace(
                "G7 calibration bounds write failed mode=%{public}@ channel=%{public}@. Retrying next connection",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name
            )
            disconnect()
        } else if fullVersionRequestSent {
            // A transport failure does not make the version available. Keep the connection guard
            // set so this short wake cannot retry or fall through to a different diagnostic. The
            // normal disconnect boundary clears it for the next authenticated sensor wake.
            trace(
                "G7 full version write failed mode=%{public}@ channel=%{public}@. Retrying next connection",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name
            )
            sendCalibrationOrBoundsIfReady()
        } else if batteryStatusRequestSent {
            // Do not advance the persisted read date until a complete response is decoded. This
            // keeps a failed request due without creating a rapid retry loop in the current wake.
            trace(
                "G7 battery status write failed mode=%{public}@ channel=%{public}@. Retrying next connection",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name
            )
            sendCalibrationOrBoundsIfReady()
        }
    }

    func cgmTransmitterType() -> CGMTransmitterType { .dexcomG7 }

    func maxSensorAgeInDays() -> Double? {
        maximumSensorAgeLock.lock()
        defer { maximumSensorAgeLock.unlock() }
        return maximumSensorAgeInDaysSnapshot
    }

    /// Keeps every lifetime consumer on the same decision. The authenticated peripheral name is
    /// preferred because it identifies the sensor that produced the reported duration. Stored
    /// names are used only before that first authenticated connection completes.
    private var maximumSensorAgeInDays: Double {
        DexcomG7SensorLifetime.maximumSensorAgeInDays(
            reportedSessionLength: sensorSessionLength,
            deviceName: currentlyAuthenticatedDeviceName ?? deviceName ?? transmitterId
        )
    }

    /// Refreshes the one lifetime value that may be read outside `bt.central`. The lock is held only
    /// while copying a `Double`; no delegate, persistence or queue operation can run while held.
    private func refreshMaximumSensorAgeSnapshot() {
        assertOnCentral()
        let value = maximumSensorAgeInDays
        maximumSensorAgeLock.lock()
        maximumSensorAgeInDaysSnapshot = value
        maximumSensorAgeLock.unlock()
    }

    func getCBUUID_Service() -> String { CBUUID_Service_G7 }
    func getCBUUID_Receive() -> String { CharacteristicUUID.receiveAuthentication.rawValue }
    func isWebOOPEnabled() -> Bool { webOOPEnabled }
    func overruleIsWebOOPEnabled() -> Bool { true }
    func shouldWarnOnLargeCalibrationStep() -> Bool { true }

    func transmitterCalibrationStatus() -> CGMTransmitterCalibrationStatus? {
        // Calibration callbacks and SwiftUI reads can arrive on different queues. Protect the
        // small value-type tracker rather than exposing any partially updated presentation state.
        calibrationStatusLock.lock()
        defer { calibrationStatusLock.unlock() }
        return calibrationStatusTracker.status
    }

    func calibrate(calibration: Calibration) {
        // Detach the values needed by the BLE command before validating them. The original managed
        // object is looked up again by identifier only when a transmitter result must be saved.
        let pendingCalibration = PendingTransmitterCalibration(calibration: calibration)

        runOnCentralQueue { [weak self] in
            self?.queueCalibrationOnCentral(pendingCalibration)
        }
    }

    private func queueCalibrationOnCentral(_ pendingCalibration: PendingTransmitterCalibration) {
        assertOnCentral()

        // Replace any older unsent command with the calibration the user has just submitted. An
        // invalid replacement is reported locally and must never leave a stale command queued.
        calibrationToSendToTransmitter = nil
        guard calibrationIsValid(pendingCalibration) else {
            trace(
                "G7 calibration rejected locally mode=%{public}@ channel=%{public}@ id=%{public}@ value=%{public}@ ageSeconds=%{public}@ alreadySent=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
                pendingCalibration.id,
                pendingCalibration.bg.description,
                Date().timeIntervalSince(pendingCalibration.timeStamp).description,
                pendingCalibration.sentToTransmitter.description
            )
            return
        }

        calibrationToSendToTransmitter = pendingCalibration
        calibrationWriteInFlight = false
        setCalibrationStatus(.queued)
        trace(
            "G7 calibration queued mode=%{public}@ channel=%{public}@ id=%{public}@ value=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            useOtherApp ? "coexistence" : "primary",
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
            pendingCalibration.id,
            pendingCalibration.bg.description
        )
        // Send immediately when the current wake is already authenticated. Otherwise the command
        // stays queued and the normal notification or glucose callback will retry this method.
        sendCalibrationOrBoundsIfReady()
    }

    /// Gives the isolated authentication state machine access to notification control without
    /// exposing the complete Bluetooth transmitter object to it.
    func authSessionSetNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        setNotifyValue(enabled, for: characteristic)
    }

    /// Gives the authentication state machine one checked write route for both acknowledged
    /// control packets and unacknowledged `Auth_Stream` fragments.
    @discardableResult
    func authSessionWrite(_ data: Data, to characteristic: CBCharacteristic, type: CBCharacteristicWriteType) -> Bool {
        writeDataToPeripheral(data: data, characteristicToWriteTo: characteristic, type: type)
    }

    func authSessionDidAuthenticate() {
        guard !useOtherApp, !primaryAuthenticated else { return }
        // This callback can only originate from the primary auth session. Set no coexistence state
        // here. Once `Write_Control` notifications are active, one GetData command starts the normal
        // glucose, lifetime, calibration, and backfill sequence for this wake cycle.
        primaryAuthenticated = true
        currentlyAuthenticatedDeviceName = deviceName
        refreshMaximumSensorAgeSnapshot()
        updateActiveTransmitterIdIfNeeded()
        trace("G7 primary authentication complete. Arming Write_Control", log: log, category: ConstantsLog.categoryCGMG7, type: .info)

        if let writeControlCharacteristic {
            if writeControlCharacteristic.isNotifying { sendPrimaryGlucoseRequestIfReady() }
            else { setNotifyValue(true, for: writeControlCharacteristic) }
        }
    }

    func authSessionDidRejectPersistedKey() {
        // A rejected confirmed key is not evidence that the sensor itself failed. It can mean that
        // another client owns this slot. Stop automatic primary reconnects for this transmitter
        // instance so xDrip4iOS does not repeatedly attempt ownership and disturb the external client.
        primaryAuthenticated = false
        primaryGlucoseRequestSent = false
        primaryAuthenticationBlocked = true
        resetCalibrationConnectionState(requeueInFlightCommand: true)
        trace("G7 primary authentication stopped. The saved key was preserved", log: log, category: ConstantsLog.categoryCGMG7, type: .error)
        disconnect()
    }

    func authSessionRequiresCleanReconnect() {
        // Authenticated but unpaired means a fresh bootstrap is required. Disconnecting is
        // intentional because characteristic notification and auth-stream state from the short
        // attempt must not be reused by the full ownership exchange.
        primaryAuthenticated = false
        primaryGlucoseRequestSent = false
        resetCalibrationConnectionState(requeueInFlightCommand: true)
        disconnect()
    }

    func authSessionSchedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
        runOnCentralQueue(after: delay, action)
    }

    private func handleWriteControlValue(_ value: Data) {
        guard let firstByte = value.first,
              let opCode = DexcomTransmitterOpCode(rawValue: firstByte) else { return }
        // `Write_Control` multiplexes live glucose, coexistence clock data, lifetime metadata,
        // calibration acknowledgements, and backfill completion. Keep parsing by opcode here so
        // authentication code never needs to know about sensor data or treatment commands.
        switch opCode {
        case .glucoseRx: handleCoexistenceGlucoseValue(value)
        case .glucoseG6Tx: handleGlucoseValue(value)
        case .transmitterTimeRx: handleCoexistenceTransmitterTime(value)
        case .extendedVersion: handleExtendedVersionValue(value)
        case .transmitterVersionTx: handleFullVersionValue(value)
        case .batteryStatusTx: handleBatteryStatusValue(value)
        case .calibrateGlucoseTx: handleCalibrationCommandResponse(value)
        case .calibrationDataTx: handleCalibrationBounds(value)
        case .backfillFinished:
            processPendingBackfillFramesIfPossible()
            flushBackfillDeliveringToDelegate()
        default:
            trace("G7 Write_Control RX %{public}@: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, opCode.description, value.hexEncodedString())
        }
    }

    private func handleGlucoseValue(_ value: Data) {
        guard let message = G7GlucoseMessage(data: value) else {
            trace(
                "failed to parse G7 glucose message length=%{public}@ data=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                value.count.description,
                value.hexEncodedString()
            )
            return
        }

        // A non-zero response status is a sensor response, not an authentication failure. Dexcom
        // can include the final cached glucose in the same complete frame. Surface the algorithm
        // state to status, Activity Log, alert, and banner consumers, but never publish that cached
        // value as a new glucose reading.
        guard message.responseStatus == 0 else {
            trace(
                "G7 glucose response is not current status=0x%{public}@ state=0x%{public}@ age=%{public}@ seconds value=%{public}@ mg/dL data=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                String(format: "%02X", message.responseStatus),
                String(format: "%02X", message.algorithmStatus.rawValue),
                String(format: "%.0f", message.sensorAge - TimeInterval(message.transmitterTime)),
                String(format: "%.1f", message.calculatedValue),
                value.hexEncodedString()
            )
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.cGMG7TransmitterDelegate?.received(sensorStatus: message.algorithmStatus.description, cGMG7Transmitter: self)
                self.cgmTransmitterDelegate?.sensorHealthEventOccurred(message.algorithmStatus.sensorHealthEvent)
            }
            return
        }

        processGlucose(
            calculatedValue: message.calculatedValue,
            algorithmStatus: message.algorithmStatus,
            sensorAge: message.sensorAge,
            timeStamp: message.timeStamp,
            transmitterTime: message.transmitterTime
        )
    }

    private func handleCoexistenceGlucoseValue(_ value: Data) {
        // The 0x31 packet observed from the Dexcom app lacks enough clock information to create an
        // absolute sensor date. Store it temporarily until its companion 0x25 packet arrives.
        guard useOtherApp, let message = G7CoexistenceGlucoseMessage(data: value) else { return }
        pendingCoexistenceGlucose = message
        processPendingCoexistenceGlucose()
    }

    private func handleCoexistenceTransmitterTime(_ value: Data) {
        // Either half of the coexistence pair can arrive first, so both handlers call the same
        // join function after updating their side of the pair.
        guard useOtherApp, let message = DexcomTransmitterTimeRxMessage(data: value) else { return }
        coexistenceTransmitterTime = message
        processPendingCoexistenceGlucose()
    }

    /// A `0x31` frame does not contain the sensor start time. The official app sends `0x25`
    /// immediately afterwards, which supplies both the transmitter and sensor start dates.
    private func processPendingCoexistenceGlucose() {
        guard let glucose = pendingCoexistenceGlucose,
              let transmitterTime = coexistenceTransmitterTime,
              let sensorStartDate = transmitterTime.sensorStartDate
        else { return }

        pendingCoexistenceGlucose = nil
        coexistenceTransmitterTime = nil
        let timeStamp = transmitterTime.transmitterStartDate.addingTimeInterval(TimeInterval(glucose.transmitterTime))
        let sensorAge = timeStamp.timeIntervalSince(sensorStartDate)
        guard sensorAge >= 0 else { return }

        trace("G7 coexistence decoded 0x31 glucose using the following 0x25 clock", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
        processGlucose(
            calculatedValue: glucose.calculatedValue,
            algorithmStatus: glucose.algorithmStatus,
            sensorAge: sensorAge,
            timeStamp: timeStamp,
            transmitterTime: glucose.transmitterTime
        )
    }

    private func processGlucose(
        calculatedValue: Double,
        algorithmStatus: DexcomAlgorithmState,
        sensorAge: TimeInterval,
        timeStamp: Date,
        transmitterTime: UInt32
    ) {
        // From this point onward primary 0x4E and coexistence 0x31 readings share exactly the same
        // validation and delivery pipeline. Keeping the mode-specific decoding above this method
        // prevents downstream UI and storage behavior from drifting between connection modes.
        latestTransmitterClock = DexcomG7TransmitterClockReference(
            transmitterTime: transmitterTime,
            referenceDate: timeStamp
        )
        // A lifetime query is sent only after a valid glucose packet proves that authentication
        // and the selected display channel are working. The one-time query is intentionally kept
        // behind any queued calibration so it cannot delay a user-requested treatment action.
        defer { sendPostGlucoseCommandIfReady() }
        let currentSensorAge = sensorAge
        self.sensorAge = currentSensorAge
        processPendingBackfillFramesIfPossible()

        // Reject packets beyond the detected product lifetime plus its included 12-hour grace
        // period. This also prevents an old sensor still visible to Core Bluetooth from becoming
        // the active source after a replacement has been added.
        let sensorAgeInDays = round((currentSensorAge / 3600 / 24) * 10) / 10
        guard sensorAgeInDays <= maximumSensorAgeInDays else {
            trace("G7 sensor is expired. Ignoring reading at age %{public}@ days", log: log, category: ConstantsLog.categoryCGMG7, type: .error, sensorAgeInDays.description)
            return
        }

        // Six identical raw values are a long-standing Dexcom safety check for a stalled stream.
        // Apply it before the reading reaches delegates or backfill ordering state.
        addGlucoseValueToUserDefaults(Int(calculatedValue))
        guard !hasSixIdenticalValues() else {
            trace("received six equal G7 values. Ignoring %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .info, calculatedValue.description)
            return
        }

        let glucose = GlucoseData(timeStamp: timeStamp, glucoseLevelRaw: calculatedValue)
        trace(
            "G7 connection cycle summary: value=%{public}@ mg/dL at %{public}@ cid=%{public}d mode=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            String(format: "%.1f", glucose.glucoseLevelRaw),
            DateFormatter.localizedString(from: glucose.timeStamp, dateStyle: .none, timeStyle: .medium),
            cycleId,
            useOtherApp ? "coexistence" : "primary"
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var readings = [glucose]
            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &readings, transmitterBatteryInfo: nil, sensorAge: currentSensorAge)
            self.cGMG7TransmitterDelegate?.received(sensorStatus: algorithmStatus.description, cGMG7Transmitter: self)
            self.cgmTransmitterDelegate?.sensorHealthEventOccurred(algorithmStatus.sensorHealthEvent)
            self.cGMG7TransmitterDelegate?.received(sensorStartDate: timeStamp.addingTimeInterval(-currentSensorAge), cGMG7Transmitter: self)
        }

        timeStampLastReading = timeStamp
        if let backfillCharacteristic, !backfillCharacteristic.isNotifying {
            trace(
                "G7 %{public}@ glucose received. Arming Backfill",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .info,
                useOtherApp ? "coexistence" : "primary"
            )
            setNotifyValue(true, for: backfillCharacteristic)
        }
    }

    /// Selects one control command after a glucose response. A real calibration always wins, then
    /// lifetime, firmware, and battery diagnostics are considered in that order. Only one
    /// diagnostic is selected during a sensor wake. This protects the short G7 connection window
    /// while allowing the existing calibration-bounds request to remain the final routine action.
    private func sendPostGlucoseCommandIfReady() {
        let command = Self.postGlucoseCommand(
            hasCalibrationWork: calibrationToSendToTransmitter != nil
                || calibrationAwaitingBounds != nil
                || transmitterCalibrationStatus() == .notPermitted,
            lifetimeIsUnknown: sensorSessionLength == nil,
            firmwareIsUnknown: firmwareVersion == nil || firmwareBuildVersion == nil || firmwareVersionCode == nil,
            batteryIsDue: Self.batteryReadingIsDue(lastReadDate: batteryLastReadDate)
        )

        // Record each saved-value skip once per useful interval. Logging it on every five-minute
        // wake would hide the protocol events that developers actually need to investigate.
        if !completeFirmwareSkipWasTraced,
           firmwareVersion != nil,
           firmwareBuildVersion != nil,
           firmwareVersionCode != nil
        {
            trace(
                "G7 full version request skipped because the complete saved record is current",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .debug
            )
            completeFirmwareSkipWasTraced = true
        }
        if !currentBatterySkipWasTraced,
           !Self.batteryReadingIsDue(lastReadDate: batteryLastReadDate),
           let batteryLastReadDate
        {
            trace(
                "G7 battery status request skipped because the saved reading is still current ageSeconds=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .debug,
                Date().timeIntervalSince(batteryLastReadDate).description
            )
            currentBatterySkipWasTraced = true
        }

        switch command {
        case .calibrationOrBounds:
            sendCalibrationOrBoundsIfReady()
        case .lifetime:
            _ = requestExtendedVersionIfNeeded()
        case .firmware:
            _ = requestFullVersionIfNeeded()
        case .battery:
            _ = requestBatteryStatusIfNeeded()
        case .routineBounds:
            sendCalibrationOrBoundsIfReady()
        }
    }

    /// Applies the fixed command priority without inspecting Core Bluetooth state. Exactly one
    /// result is returned, which prevents a rejected metadata write from falling through to a
    /// different metadata request during the same wake.
    static func postGlucoseCommand(
        hasCalibrationWork: Bool,
        lifetimeIsUnknown: Bool,
        firmwareIsUnknown: Bool,
        batteryIsDue: Bool
    ) -> PostGlucoseCommand {
        if hasCalibrationWork { return .calibrationOrBounds }
        if lifetimeIsUnknown { return .lifetime }
        if firmwareIsUnknown { return .firmware }
        if batteryIsDue { return .battery }
        return .routineBounds
    }

    /// Requests the complete version record once for this saved sensor. A partially populated
    /// record is treated as unknown so the three values can only become authoritative together.
    private func requestFullVersionIfNeeded() -> Bool {
        guard firmwareVersion == nil || firmwareBuildVersion == nil || firmwareVersionCode == nil else {
            trace(
                "G7 full version request skipped because the complete saved record is current",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .debug
            )
            return false
        }
        guard let writeControlCharacteristic,
              writeControlCharacteristic.isNotifying,
              useOtherApp ? coexistenceAuthenticated : primaryAuthenticated
        else { return false }

        if fullVersionRequestSent { return true }

        let request = TransmitterVersionTxMessage().data
        trace(
            "G7 full version TX mode=%{public}@ channel=%{public}@ data=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            useOtherApp ? "coexistence" : "primary",
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
            request.hexEncodedString()
        )
        // Mark the diagnostic as attempted before asking Core Bluetooth to write. Even an immediate
        // transport rejection must not allow another metadata command during this same wake.
        fullVersionRequestSent = true
        let writeAccepted = super.writeDataToPeripheral(
            data: request,
            characteristicToWriteTo: writeControlCharacteristic,
            type: .withResponse
        )
        if !writeAccepted {
            trace(
                "G7 full version TX was not accepted by the Bluetooth transport mode=%{public}@ channel=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name
            )
        }
        return true
    }

    /// Returns whether this disposable sensor is due another battery query. The two-hour interval
    /// intentionally matches the existing xDrip4iOS G6 cadence.
    static func batteryReadingIsDue(lastReadDate: Date?, now: Date = Date()) -> Bool {
        guard let lastReadDate else { return true }
        return now.timeIntervalSince(lastReadDate) >= ConstantsDexcomG5.batteryReadPeriod
    }

    /// Requests a fresh battery record only when this disposable sensor's saved reading is due.
    /// The request uses the established Dexcom CRC-framed `0x22` command, but the response is
    /// decoded by `DexcomG7BatteryStatusMessage` because G7-family sensors reply with `0x22`
    /// instead of the G6 `0x23` opcode. Returning `true` means this wake has already spent its one
    /// diagnostic opportunity, even if Core Bluetooth rejects the write immediately.
    private func requestBatteryStatusIfNeeded() -> Bool {
        guard Self.batteryReadingIsDue(lastReadDate: batteryLastReadDate) else {
            trace(
                "G7 battery status request skipped because the saved reading is still current ageSeconds=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .debug,
                batteryLastReadDate.map { Date().timeIntervalSince($0).description } ?? "unknown"
            )
            return false
        }
        guard let writeControlCharacteristic,
              writeControlCharacteristic.isNotifying,
              useOtherApp ? coexistenceAuthenticated : primaryAuthenticated
        else { return false }

        if batteryStatusRequestSent { return true }

        let request = BatteryStatusTxMessage().data
        trace(
            "G7 battery status TX mode=%{public}@ channel=%{public}@ data=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            useOtherApp ? "coexistence" : "primary",
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
            request.hexEncodedString()
        )
        // The attempt guard remains set until a valid response or a physical disconnect. The saved
        // date remains unchanged, so an unsuccessful attempt is still due on the next connection.
        batteryStatusRequestSent = true
        let writeAccepted = super.writeDataToPeripheral(
            data: request,
            characteristicToWriteTo: writeControlCharacteristic,
            type: .withResponse
        )
        if !writeAccepted {
            trace(
                "G7 battery status TX was not accepted by the Bluetooth transport mode=%{public}@ channel=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name
            )
        }
        return true
    }

    /// Requests the dynamic session length only while it is unknown. Returning `true` means the
    /// request is already in flight or was accepted by CoreBluetooth, so the caller must wait for
    /// the matching response before sending the next routine control command.
    private func requestExtendedVersionIfNeeded() -> Bool {
        guard sensorSessionLength == nil,
              let writeControlCharacteristic,
              writeControlCharacteristic.isNotifying,
              useOtherApp ? coexistenceAuthenticated : primaryAuthenticated
        else { return false }

        if extendedVersionRequestSent { return true }

        let request = Data([DexcomTransmitterOpCode.extendedVersion.rawValue])
        trace(
            "G7 extended version TX mode=%{public}@ channel=%{public}@ data=52",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            useOtherApp ? "coexistence" : "primary",
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name
        )

        extendedVersionRequestSent = super.writeDataToPeripheral(
            data: request,
            characteristicToWriteTo: writeControlCharacteristic,
            type: .withResponse
        )
        return extendedVersionRequestSent
    }

    /// Applies only a structurally valid, recognised session length. Unknown future products keep
    /// the conservative name-based fallback rather than weakening the repeated-reading expiry
    /// guard. The raw packet is retained in tracing so future formats can be investigated fairly.
    private func handleExtendedVersionValue(_ value: Data) {
        guard let message = DexcomG7ExtendedVersionMessage(data: value) else {
            trace("G7 extended version response malformed: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, value.hexEncodedString())
            sendCalibrationOrBoundsIfReady()
            return
        }

        guard let supportedSessionLength = DexcomG7SensorLifetime.supportedSessionLength(message.sessionLength) else {
            trace(
                "G7 extended version reported unsupported session length %{public}@ seconds: %{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                message.sessionLength.description,
                value.hexEncodedString()
            )
            sendCalibrationOrBoundsIfReady()
            return
        }

        sensorSessionLength = supportedSessionLength
        refreshMaximumSensorAgeSnapshot()
        trace(
            "G7 extended version RX mode=%{public}@ lifetime=%{public}@ session=%{public}@ days warmup=%{public}@ minutes algorithm=%{public}@ hardware=%{public}@ maxLifetimeDays=%{public}@ data=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            useOtherApp ? "coexistence" : "primary",
            DexcomG7SensorLifetime.diagnosticDescription(supportedSessionLength),
            maximumSensorAgeInDays.description,
            (message.warmupDuration / 60).description,
            message.algorithmVersion.description,
            message.hardwareVersion.description,
            message.maxLifetimeDays.description,
            value.hexEncodedString()
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cGMG7TransmitterDelegate?.received(
                sensorSessionLength: supportedSessionLength,
                cGMG7Transmitter: self
            )
        }

        sendCalibrationOrBoundsIfReady()
    }

    /// Stores a complete G7 full-version record. The same `0x4A` opcode is used in both directions,
    /// so the response is selected by its full length rather than being mistaken for our
    /// three-byte request. No G6 CRC check is applied because this G7 response format has none.
    private func handleFullVersionValue(_ value: Data) {
        guard let message = DexcomG7VersionMessage(data: value) else {
            trace(
                "G7 full version response malformed mode=%{public}@ channel=%{public}@ data=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
                value.hexEncodedString()
            )
            sendCalibrationOrBoundsIfReady()
            return
        }

        fullVersionRequestSent = false
        completeFirmwareSkipWasTraced = false
        // Update the in-memory copy before notifying the persistence delegate. A second glucose
        // packet during this connection must see one complete version record and must not queue a
        // duplicate request while the main-context save is being performed.
        firmwareVersion = message.firmwareVersion
        firmwareBuildVersion = message.buildVersion
        firmwareVersionCode = message.versionCode
        trace(
            "G7 full version RX mode=%{public}@ channel=%{public}@ status=%{public}@ firmware=%{public}@ build=%{public}@ versionCode=%{public}@ serial=%{public}@ data=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            useOtherApp ? "coexistence" : "primary",
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
            message.status.description,
            message.firmwareVersion,
            message.buildVersion.description,
            message.versionCode.description,
            message.serialNumber.description,
            value.hexEncodedString()
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cGMG7TransmitterDelegate?.received(version: message, cGMG7Transmitter: self)
        }
        sendCalibrationOrBoundsIfReady()
    }

    /// Accepts both a response to xDrip4iOS's own request and a valid response observed while the
    /// Dexcom app owns a coexistence connection. Observing the packet changes no authentication
    /// state. It only updates diagnostics when the saved value is due.
    private func handleBatteryStatusValue(_ value: Data) {
        guard let message = DexcomG7BatteryStatusMessage(data: value) else {
            trace(
                "G7 battery status response malformed mode=%{public}@ channel=%{public}@ data=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
                value.hexEncodedString()
            )
            sendCalibrationOrBoundsIfReady()
            return
        }

        batteryStatusRequestSent = false
        currentBatterySkipWasTraced = false
        // Another app may request battery data before our own two-hour interval expires. Decode
        // and trace that valid packet, but do not create extra persistence, alerts, or Activity Log
        // entries until this sensor's own cadence says that a new reading is due.
        let readAt = Date()
        let readingIsDue = Self.batteryReadingIsDue(lastReadDate: batteryLastReadDate, now: readAt)
        trace(
            "G7 battery status RX mode=%{public}@ channel=%{public}@ status=%{public}@ voltageA=%{public}@ voltageB=%{public}@ resistance=%{public}@ runtime=%{public}@ temperature=%{public}@ due=%{public}@ data=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            useOtherApp ? "coexistence" : "primary",
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
            message.status.description,
            message.voltageA.description,
            message.voltageB.description,
            message.resistance.description,
            message.runtime.description,
            message.temperature.description,
            readingIsDue.description,
            value.hexEncodedString()
        )

        if readingIsDue {
            let isFirstReading = batteryLastReadDate == nil
            // Advance the in-memory cadence only after the entire known packet has decoded. The
            // delegate receives the same timestamp for Core Data so runtime scheduling and the
            // saved disposable-sensor record cannot disagree about when the next query is due.
            batteryLastReadDate = readAt
            let batteryInfo = TransmitterBatteryInfo.dexcom(
                family: .g7,
                voltageA: message.voltageA,
                voltageB: message.voltageB,
                resist: message.resistance,
                runtime: message.runtime,
                temperature: message.temperature
            )
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Persist the complete G7-specific record first. The shared battery callback then
                // feeds the established Dexcom alert, Loop metadata, Nightscout, and active battery
                // cache without asking those consumers to understand another wire format.
                self.cGMG7TransmitterDelegate?.received(
                    battery: message,
                    readAt: readAt,
                    isFirstReading: isFirstReading,
                    cGMG7Transmitter: self
                )
                var emptyReadings = [GlucoseData]()
                self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(
                    glucoseData: &emptyReadings,
                    transmitterBatteryInfo: batteryInfo,
                    sensorAge: nil
                )
            }
        }

        sendCalibrationOrBoundsIfReady()
    }

    private func handleBackfillValue(_ value: Data) {
        guard value.count == 9 else { return }
        trace("G7 Backfill RX: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, value.hexEncodedString())
        // Backfill packets contain a relative age. Decode immediately only when this connection has
        // already supplied a trustworthy current sensor age. Otherwise retain the raw nine bytes
        // until the live glucose packet establishes the time reference.
        if let sensorAge, sensorAge < maximumSensorAgeInDays * 24 * 3600,
           let message = DexcomG7BackfillMessage(data: value, sensorAge: sensorAge)
        {
            if appendBackfillMessage(message), timeStampLastReading.map({ message.timeStamp > $0 }) ?? true {
                timeStampLastReading = message.timeStamp
            }
        } else {
            pendingBackfillRawFrames.append(value)
            processPendingBackfillFramesIfPossible()
        }
    }

    private func handleCoexistenceAuthentication(_ value: Data) {
        guard let message = AuthChallengeRxMessage(data: value) else { return }
        if message.paired, message.authenticated {
            // These flags describe the Dexcom app's session. We deliberately do not save a key or
            // notify `DexcomG7AuthSession`, because xDrip4iOS has not authenticated and owns nothing in
            // coexistence mode. They only permit passive data observation and an explicit queued
            // calibration while the shared connection is already authenticated.
            coexistenceAuthenticated = true
            currentlyAuthenticatedDeviceName = deviceName
            refreshMaximumSensorAgeSnapshot()
            updateActiveTransmitterIdIfNeeded()
            trace("G7 coexistence session is paired and authenticated", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
            if let writeControlCharacteristic, !writeControlCharacteristic.isNotifying {
                trace("G7 coexistence authenticated session observed. Arming Write_Control", log: log, category: ConstantsLog.categoryCGMG7, type: .debug)
                setNotifyValue(true, for: writeControlCharacteristic)
            } else {
                sendCalibrationOrBoundsIfReady()
            }
        } else {
            coexistenceAuthenticated = false
            trace("G7 coexistence is waiting for the Dexcom app to authenticate", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
        }
    }

    private func subscribeForCoexistenceAuthentication() {
        guard let receiveAuthenticationCharacteristic else {
            trace("G7 coexistence Receive_Authentication characteristic is unavailable", log: log, category: ConstantsLog.categoryCGMG7, type: .error)
            return
        }
        // `Receive_Authentication` is sufficient to observe readiness. Subscribing to `Auth_Stream`
        // would expose ownership payloads that coexistence neither needs nor should process.
        if !receiveAuthenticationCharacteristic.isNotifying {
            trace("G7 coexistence arming Receive_Authentication only", log: log, category: ConstantsLog.categoryCGMG7, type: .debug)
            setNotifyValue(true, for: receiveAuthenticationCharacteristic)
        }
    }

    private func sendPrimaryGlucoseRequestIfReady() {
        guard !useOtherApp,
              primaryAuthenticated,
              !primaryGlucoseRequestSent,
              let writeControlCharacteristic,
              writeControlCharacteristic.isNotifying else { return }

        // Send at most one GetData request per connection. The sensor wakes periodically and the
        // flag resets on disconnect, matching its natural five-minute connection lifecycle.
        primaryGlucoseRequestSent = true
        trace("G7 primary GetData TX: 4e", log: log, category: ConstantsLog.categoryCGMG7, type: .info)
        if !writeDataToPeripheral(
            data: Data([DexcomTransmitterOpCode.glucoseG6Tx.rawValue]),
            characteristicToWriteTo: writeControlCharacteristic,
            type: .withResponse
        ) {
            primaryGlucoseRequestSent = false
        }
    }

    private func sendCalibrationOrBoundsIfReady() {
        // Authentication and `Write_Control` notification readiness are common prerequisites for
        // both the calibration command and its later status query. The active mode decides which
        // readiness flag is authoritative.
        guard let writeControlCharacteristic,
              writeControlCharacteristic.isNotifying,
              useOtherApp ? coexistenceAuthenticated : primaryAuthenticated else { return }

        if let calibration = calibrationToSendToTransmitter,
           !calibrationWriteInFlight
        {
            // Revalidate at transmission time because a calibration can become too old while it
            // waits for the next sensor wake or for authentication to finish.
            guard calibrationIsValid(calibration) else {
                trace(
                    "G7 queued calibration became invalid before TX mode=%{public}@ channel=%{public}@ id=%{public}@ value=%{public}@ ageSeconds=%{public}@ alreadySent=%{public}@",
                    log: log,
                    category: ConstantsLog.categoryCGMG7,
                    type: .error,
                    useOtherApp ? "coexistence" : "primary",
                    TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
                    calibration.id,
                    calibration.bg.description,
                    Date().timeIntervalSince(calibration.timeStamp).description,
                    calibration.sentToTransmitter.description
                )
                calibrationToSendToTransmitter = nil
                clearQueuedCalibrationStatus()
                requestCalibrationBoundsIfNeeded()
                return
            }
            guard let transmitterTime = latestTransmitterClock?.transmitterTime(for: calibration.timeStamp) else {
                trace(
                    "G7 calibration waiting for a fresh transmitter clock mode=%{public}@ channel=%{public}@ id=%{public}@",
                    log: log,
                    category: ConstantsLog.categoryCGMG7,
                    type: .debug,
                    useOtherApp ? "coexistence" : "primary",
                    TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
                    calibration.id
                )
                return
            }

            let message = DexcomG7CalibrationCommand(
                glucose: UInt16(calibration.bg.rounded()),
                transmitterTime: transmitterTime
            )
            trace(
                "G7 calibration TX mode=%{public}@ channel=%{public}@ id=%{public}@ value=%{public}@ transmitterTime=%{public}@ data=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .info,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
                calibration.id,
                calibration.bg.description,
                transmitterTime.description,
                message.data.hexEncodedString()
            )
            if super.writeDataToPeripheral(
                data: message.data,
                characteristicToWriteTo: writeControlCharacteristic,
                type: .withResponse
            ) {
                // The write result confirms only that Core Bluetooth accepted the bytes. Keep the
                // calibration queued until the transmitter's `0x34` response is parsed.
                calibrationWriteInFlight = true
                lastCalibrationCommandTransmitterTime = transmitterTime
                setCalibrationStatus(.sentAwaitingResponse)
            } else {
                trace(
                    "G7 calibration TX was not accepted by the Bluetooth transport mode=%{public}@ channel=%{public}@ id=%{public}@",
                    log: log,
                    category: ConstantsLog.categoryCGMG7,
                    type: .error,
                    useOtherApp ? "coexistence" : "primary",
                    TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
                    calibration.id
                )
            }
            return
        }

        // Primary mode may refresh the bounds routinely. Coexistence requests them only for a
        // calibration submitted by this app or while showing a known not-permitted state. This
        // avoids treating the other app's unrelated calibration traffic as local history.
        if !useOtherApp || calibrationAwaitingBounds != nil || transmitterCalibrationStatus() == .notPermitted {
            requestCalibrationBoundsIfNeeded()
        }
    }

    /// Requests the authoritative `0x32` calibration record while preventing overlapping writes.
    /// `allowCoexistenceAfterOwnCommand` covers the small interval immediately after xDrip4iOS's own
    /// accepted `0x34` response, before all local status fields have reached their final shape.
    private func requestCalibrationBoundsIfNeeded(allowCoexistenceAfterOwnCommand: Bool = false) {
        guard !calibrationBoundsRequestSent,
              let writeControlCharacteristic,
              writeControlCharacteristic.isNotifying,
              useOtherApp ? coexistenceAuthenticated : primaryAuthenticated,
              !useOtherApp || calibrationAwaitingBounds != nil || allowCoexistenceAfterOwnCommand || transmitterCalibrationStatus() == .notPermitted else { return }

        let request = Data([DexcomTransmitterOpCode.calibrationDataTx.rawValue])
        trace(
            "G7 calibration bounds TX mode=%{public}@ channel=%{public}@ data=32",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .debug,
            useOtherApp ? "coexistence" : "primary",
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name
        )
        if super.writeDataToPeripheral(
            data: request,
            characteristicToWriteTo: writeControlCharacteristic,
            type: .withResponse
        ) {
            calibrationBoundsRequestSent = true
        } else {
            trace(
                "G7 calibration bounds TX was not accepted by the Bluetooth transport mode=%{public}@ channel=%{public}@ id=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .error,
                useOtherApp ? "coexistence" : "primary",
                TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
                calibrationAwaitingBounds?.id ?? "none"
            )
        }
    }

    private func handleCalibrationCommandResponse(_ value: Data) {
        guard let response = DexcomG7CalibrationCommandResponse(data: value) else {
            trace("G7 calibration response malformed: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, value.hexEncodedString())
            return
        }

        trace(
            "G7 calibration RX mode=%{public}@ channel=%{public}@ id=%{public}@ response=%{public}@ primary=%{public}@ secondary=%{public}@ status=%{public}@ data=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            useOtherApp ? "coexistence" : "primary",
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
            calibrationToSendToTransmitter?.id ?? calibrationAwaitingBounds?.id ?? "none",
            response.transmitterResponse.description,
            response.primaryStatus.description,
            response.secondaryStatus.description,
            response.status.traceDescription,
            value.hexEncodedString()
        )

        // In coexistence mode we can observe packets produced by the Dexcom app. Only consume a
        // response when xDrip4iOS has actually written a calibration during this connection window.
        guard calibrationWriteInFlight,
              let calibration = calibrationToSendToTransmitter
        else {
            trace(
                "G7 calibration response observed without an xDrip4iOS command in flight. Leaving the local queue unchanged",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .debug
            )
            return
        }

        // Record that the command reached the transmitter. Final acceptance remains provisional
        // until a matching `0x32` record reports the completed processing result.
        updateCalibrationTransmitterStatus(
            calibration: calibration,
            sentToTransmitter: true,
            acceptedByTransmitter: response.status.accepted
        )
        calibrationAwaitingBounds = calibration
        calibrationToSendToTransmitter = nil
        calibrationWriteInFlight = false

        // Translate the transmitter's immediate response into the user-facing intermediate state.
        // Terminal rejections stop tracking. Accepted and duplicate-like responses wait for bounds.
        switch response.status {
        case .acceptedHigh, .acceptedLow:
            if response.status.accepted {
                setCalibrationStatus(.processing, activity: .processing)
            } else {
                calibrationAwaitingBounds = nil
                let reason = DexcomG7CalibrationRejectionReason.unknown(response.secondaryStatus)
                setCalibrationStatus(.rejected(reason), activity: .rejected(.unknown))
            }
        case .factoryCalibrated:
            setCalibrationStatus(.processing, activity: .processing)
        case let .rejected(reason):
            if reason.isTerminalDuplicate {
                setCalibrationStatus(.processing, activity: .processing)
            } else if reason == .notPermitted || reason == .disabled {
                calibrationAwaitingBounds = nil
                setCalibrationStatus(.notPermitted, activity: .notPermitted)
            } else {
                calibrationAwaitingBounds = nil
                setCalibrationStatus(.rejected(reason), activity: .rejected(reason.activityReason))
            }
        case let .unknown(primary, _):
            calibrationAwaitingBounds = nil
            let reason = DexcomG7CalibrationRejectionReason.unknown(primary)
            setCalibrationStatus(.rejected(reason), activity: .rejected(.unknown))
        }

        requestCalibrationBoundsIfNeeded(allowCoexistenceAfterOwnCommand: true)
    }

    private func handleCalibrationBounds(_ value: Data) {
        guard let bounds = DexcomG7CalibrationBounds(data: value) else {
            trace("G7 calibration bounds malformed: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, value.hexEncodedString())
            return
        }

        let expectedCalibration = calibrationAwaitingBounds ?? calibrationToSendToTransmitter

        trace(
            "G7 calibration bounds RX response=%{public}@ session=%{public}@ signature=%{public}@ value=%{public}@ calibrationTime=%{public}@ processing=%{public}@ permitted=%{public}@ display=%{public}@ updated=%{public}@ data=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .debug,
            bounds.transmitterResponse.description,
            bounds.sessionNumber.description,
            bounds.sessionSignature.description,
            bounds.glucose.description,
            bounds.calibrationTime.description,
            bounds.processingRawValue.description,
            bounds.calibrationsPermitted.description,
            bounds.originatingDisplayRawValue.description,
            bounds.lastProcessingUpdateTime.description,
            value.hexEncodedString()
        )
        trace(
            "G7 calibration bounds decoded mode=%{public}@ channel=%{public}@ id=%{public}@ value=%{public}@ transmitterTime=%{public}@ state=%{public}@ permitted=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMG7,
            type: .info,
            useOtherApp ? "coexistence" : "primary",
            TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name,
            expectedCalibration?.id ?? "none",
            bounds.glucose.description,
            bounds.calibrationTime.description,
            bounds.processingState?.traceDescription ?? "unknown (\(bounds.processingRawValue))",
            bounds.calibrationsPermitted.description
        )

        // The transmitter can briefly return the previous calibration after a new command. Do not
        // let that stale record complete or reject the calibration currently being tracked.
        if let expectedCalibration,
           lastCalibrationCommandTransmitterTime.map({
               bounds.matches(glucose: expectedCalibration.bg, transmitterTime: $0)
           }) != true
        {
            trace(
                "G7 calibration bounds mismatch id=%{public}@ expectedValue=%{public}@ expectedTransmitterTime=%{public}@ receivedValue=%{public}@ receivedTransmitterTime=%{public}@. Waiting for a later record",
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .debug,
                expectedCalibration.id,
                expectedCalibration.bg.description,
                lastCalibrationCommandTransmitterTime?.description ?? "not sent",
                bounds.glucose.description,
                bounds.calibrationTime.description
            )
            return
        }

        // Activity Log entries are created only when this record belongs to a calibration entered
        // in this app instance. Routine status observations must update the UI without inventing a
        // local calibration event.
        let tracksSubmittedCalibration = calibrationAwaitingBounds != nil

        if !bounds.calibrationsPermitted {
            if let calibrationAwaitingBounds {
                updateCalibrationTransmitterStatus(
                    calibration: calibrationAwaitingBounds,
                    sentToTransmitter: true,
                    acceptedByTransmitter: false
                )
            }
            calibrationAwaitingBounds = nil
            lastCalibrationCommandTransmitterTime = nil
            setCalibrationStatus(
                .notPermitted,
                activity: tracksSubmittedCalibration ? .notPermitted : nil
            )
            return
        }

        // The processing state is the final transmitter authority. Complete states update Core
        // Data and clear the tracked command. An in-progress state keeps it available for another
        // bounds request on the next connection.
        switch bounds.processingState {
        case .some(.inProgress):
            setCalibrationStatus(
                .processing,
                activity: tracksSubmittedCalibration ? .processing : nil
            )
        case .some(.completeHigh):
            if let calibrationAwaitingBounds {
                updateCalibrationTransmitterStatus(calibration: calibrationAwaitingBounds, sentToTransmitter: true, acceptedByTransmitter: true)
            }
            setCalibrationStatus(
                .completedHigh,
                activity: tracksSubmittedCalibration ? .completedHigh : nil
            )
            calibrationAwaitingBounds = nil
            lastCalibrationCommandTransmitterTime = nil
        case .some(.completeLow):
            if let calibrationAwaitingBounds {
                updateCalibrationTransmitterStatus(calibration: calibrationAwaitingBounds, sentToTransmitter: true, acceptedByTransmitter: true)
            }
            setCalibrationStatus(
                .completedLow,
                activity: tracksSubmittedCalibration ? .completedLow : nil
            )
            calibrationAwaitingBounds = nil
            lastCalibrationCommandTransmitterTime = nil
        case .some(.none), .some(.factoryCalibrated), nil:
            clearCalibrationStatus(if: .notPermitted)
        }
    }

    private func calibrationIsValid(_ calibration: PendingTransmitterCalibration) -> Bool {
        // Match the established Dexcom validation boundary. Only an unsent, recent treatment in
        // the supported 40 to 400 mg/dL range can be converted into a transmitter command.
        guard !calibration.sentToTransmitter else { return false }
        let age = Date().timeIntervalSince(calibration.timeStamp)
        guard age >= 0, age <= ConstantsDexcomG5.maxUnSentCalibrationAge else { return false }
        return calibration.bg >= 40 && calibration.bg <= 400
    }

    private func updateCalibrationTransmitterStatus(
        calibration: PendingTransmitterCalibration,
        sentToTransmitter: Bool,
        acceptedByTransmitter: Bool
    ) {
        guard let managedObjectContext = calibration.managedObjectContext else { return }

        // Re-fetch by the detached identifier on the managed object's own queue. This avoids
        // carrying an NSManagedObject through asynchronous Bluetooth callbacks.
        managedObjectContext.perform {
            let request: NSFetchRequest<Calibration> = Calibration.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", calibration.id)
            do {
                guard let calibrationToUpdate = try managedObjectContext.fetch(request).first else { return }
                calibrationToUpdate.sentToTransmitter = sentToTransmitter
                calibrationToUpdate.acceptedByTransmitter = acceptedByTransmitter
                if managedObjectContext.hasChanges { try managedObjectContext.save() }
            } catch {
                trace("G7 calibration persistence failed: %{public}@", log: self.log, category: ConstantsLog.categoryCGMG7, type: .error, error.localizedDescription)
            }
        }
    }

    private func setCalibrationStatus(
        _ status: CGMTransmitterCalibrationStatus,
        activity: TroubleshootingTransmitterCalibrationActivity? = nil
    ) {
        // Update the thread-safe state first. Repeated transmitter records often contain the same
        // status, so emit trace and Activity Log output only for a real transition.
        calibrationStatusLock.lock()
        let changed = calibrationStatusTracker.transition(to: status)
        calibrationStatusLock.unlock()

        guard changed else { return }

        let calibrationID = calibrationToSendToTransmitter?.id
            ?? calibrationAwaitingBounds?.id
            ?? "none"
        let message: StaticString = "G7 calibration state changed mode=%{public}@ channel=%{public}@ id=%{public}@ state=%{public}@ writeInFlight=%{public}@ boundsRequested=%{public}@"
        let mode = useOtherApp ? "coexistence" : "primary"
        let channel = TroubleshootingDexcomBluetoothChannel(bluetoothSlot).name

        if let activity {
            trace(
                message,
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .info,
                troubleshooting: .standard(.transmitterCalibration(activity)),
                mode,
                channel,
                calibrationID,
                status.traceDescription,
                calibrationWriteInFlight.description,
                calibrationBoundsRequestSent.description
            )
        } else {
            trace(
                message,
                log: log,
                category: ConstantsLog.categoryCGMG7,
                type: .info,
                mode,
                channel,
                calibrationID,
                status.traceDescription,
                calibrationWriteInFlight.description,
                calibrationBoundsRequestSent.description
            )
        }
    }

    private func clearQueuedCalibrationStatus() {
        clearCalibrationStatus(if: .queued)
    }

    private func clearCalibrationStatus(if currentStatus: CGMTransmitterCalibrationStatus) {
        calibrationStatusLock.lock()
        calibrationStatusTracker.clear(if: currentStatus)
        calibrationStatusLock.unlock()
    }

    /// Authentication, notification and clock state is scoped to one BLE connection. Keep the
    /// detached calibration itself so a failed or interrupted command can be retried next cycle.
    private func resetCalibrationConnectionState(requeueInFlightCommand: Bool) {
        let shouldRequeue = requeueInFlightCommand
            && calibrationWriteInFlight
            && calibrationToSendToTransmitter != nil
        calibrationWriteInFlight = false
        calibrationBoundsRequestSent = false
        latestTransmitterClock = nil
        if shouldRequeue { setCalibrationStatus(.queued) }
    }

    private func reconnectForConfigurationChange() {
        // Disconnecting a live connection forces new characteristic objects and authentication
        // state. When currently idle, start the newly selected configuration immediately.
        switch getConnectionStatus() {
        case .connected, .connecting: disconnect()
        default: connect()
        }
    }

    /// Attach immediately when the Dexcom app is already connected. Otherwise keep scanning and
    /// let duplicate advertisements trigger another system-connected check.
    private func startCoexistenceObservation() {
        if !retrieveConnectedPeripheral(withServiceUUIDs: [CBUUID(string: CBUUID_Service_G7)]) {
            _ = startScanning()
        }
    }

    private func updateActiveTransmitterIdIfNeeded() {
        // Do not make a merely discovered name active. This method is called only after the active
        // mode has observed successful authentication, which prevents an old nearby G7 from
        // replacing the data-source identity during generic `DX` discovery.
        let expectedPrefix = transmitterId == nil || transmitterId == ConstantsBluetoothPairing.dummyDexcomG7TypeTransmitterId
            ? "DX"
            : transmitterId
        guard let authenticatedDeviceName = deviceName,
              authenticatedDeviceName.hasPrefix(expectedPrefix ?? "DX") else { return }

        // UserDefaults changes notify KVO and SwiftUI observers synchronously. Publish on main so
        // the Bluetooth queue can never wait for UI work while UI is querying transmitter state.
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  UserDefaults.standard.activeSensorTransmitterId != authenticatedDeviceName else { return }
            UserDefaults.standard.activeSensorTransmitterId = authenticatedDeviceName
            trace("active G7 transmitter id set after authentication: %{public}@", log: self.log, category: ConstantsLog.categoryCGMG7, type: .info, authenticatedDeviceName)
        }
    }

    private func traceNotifyState(_ characteristic: CBCharacteristic, label: String) {
        let name = CharacteristicUUID(rawValue: characteristic.uuid.uuidString)?.description ?? characteristic.uuid.uuidString
        trace("G7 notify: %{public}@ - %{public}@ isNotifying=%{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, label, name, characteristic.isNotifying.description)
    }

    private func processPendingBackfillFramesIfPossible() {
        // Decode all deferred frames against the current connection's sensor age, then clear the
        // raw queue even if an individual packet is malformed. A later connection must never reuse
        // historical bytes with a different time reference.
        guard let sensorAge,
              sensorAge < maximumSensorAgeInDays * 24 * 3600,
              !pendingBackfillRawFrames.isEmpty
        else { return }

        for raw in pendingBackfillRawFrames {
            if let message = DexcomG7BackfillMessage(data: raw, sensorAge: sensorAge) { appendBackfillMessage(message) }
            else { trace("deferred G7 backfill parse failed: %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .debug, raw.hexEncodedString()) }
        }
        pendingBackfillRawFrames.removeAll(keepingCapacity: true)
    }

    @discardableResult
    private func appendBackfillMessage(_ message: DexcomG7BackfillMessage) -> Bool {
        // Reject clock corruption and exact duplicates before the reading enters the delivery
        // batch. A one-minute tolerance allows small scheduling differences around the current time.
        guard message.timeStamp <= Date().addingTimeInterval(60) else {
            trace("ignored future-dated G7 backfill at %{public}@", log: log, category: ConstantsLog.categoryCGMG7, type: .error, message.timeStamp.description(with: .current))
            return false
        }
        guard !backfill.contains(where: { $0.timeStamp == message.timeStamp }) else { return false }
        backfill.append(GlucoseData(timeStamp: message.timeStamp, glucoseLevelRaw: message.calculatedValue, backfilledAt: Date()))
        return true
    }

    private func flushBackfillDeliveringToDelegate() {
        guard !backfill.isEmpty else { return }

        // The common delegate expects newest first. Empty the mutable connection buffer before the
        // asynchronous delivery so a disconnect or new packet cannot alter the captured batch.
        let batch = backfill.sorted(by: { $0.timeStamp > $1.timeStamp })
        backfill.removeAll(keepingCapacity: true)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var readings = batch
            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &readings, transmitterBatteryInfo: nil, sensorAge: nil)
        }
        timeStampLastReading = batch.first?.timeStamp
    }

    private func addGlucoseValueToUserDefaults(_ newValue: Int) {
        // Keep only the six values used by `hasSixIdenticalValues()`. This established shared store
        // lets the stalled-stream safeguard span app launches. Protocol decisions use the local
        // queue-owned copy immediately; persistence is handed to main without blocking Bluetooth.
        recentRawGlucoseValues.insert(newValue, at: 0)
        if recentRawGlucoseValues.count > 6 { recentRawGlucoseValues.removeLast() }
        let valuesToPersist = recentRawGlucoseValues
        DispatchQueue.main.async {
            UserDefaults.standard.previousRawGlucoseValues = valuesToPersist
        }
    }

    func hasSixIdenticalValues() -> Bool {
        // Six entries are required before equality is meaningful. A shorter startup history must
        // never suppress legitimate repeated readings.
        guard recentRawGlucoseValues.count == 6 else { return false }
        return recentRawGlucoseValues.allSatisfy { $0 == recentRawGlucoseValues[0] }
    }
}

private extension DexcomG7CalibrationRejectionReason {
    var activityReason: TroubleshootingCalibrationRejectionReason {
        switch self {
        case .unspecified: return .unspecified
        case .outsideRange: return .outsideRange
        case .timestampInFuture: return .timestampInFuture
        case .duplicate: return .duplicate
        case .earlierThanSessionStart: return .earlierThanSessionStart
        case .notInOrder: return .notInOrder
        case .alreadyEntered: return .alreadyEntered
        case .disabled: return .disabled
        case .notPermitted: return .notPermitted
        case .calibrationBoundsFailed: return .calibrationBoundsFailed
        case .extremeOutlier: return .extremeOutlier
        case .stale: return .stale
        case .unknown: return .unknown
        }
    }
}
