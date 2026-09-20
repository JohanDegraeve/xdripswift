import Foundation

/// Creates the immediate `0x34` calibration command sent to a G7 sensor.
///
/// A successful write does not mean that the calibration was accepted. The transmitter first
/// returns a four-byte command response and then exposes the durable result in a `0x32` bounds
/// record. `CGMG7Transmitter` requires both stages before it reports completion to the UI.
struct DexcomG7CalibrationCommand: Equatable {
    /// Rounded whole-number glucose value in mg/dL.
    let glucose: UInt16

    /// Calibration entry date expressed in the sensor's relative clock.
    let transmitterTime: UInt32

    var data: Data {
        // G7 uses the established Dexcom calibration payload: opcode, glucose, transmitter time,
        // then CRC16. Both numeric fields are little-endian on the wire.
        var payload = Data([DexcomTransmitterOpCode.calibrateGlucoseTx.rawValue])
        payload.append(contentsOf: withUnsafeBytes(of: glucose.littleEndian, Array.init))
        payload.append(contentsOf: withUnsafeBytes(of: transmitterTime.littleEndian, Array.init))
        return payload.appendingCRC()
    }
}

/// Rejection detail carried in the secondary status byte of a rejected `0x34` response.
enum DexcomG7CalibrationRejectionReason: Equatable {
    case unspecified
    case outsideRange
    case timestampInFuture
    case duplicate
    case earlierThanSessionStart
    case notInOrder
    case alreadyEntered
    case disabled
    case notPermitted
    case calibrationBoundsFailed
    case extremeOutlier
    case stale
    case unknown(UInt8)

    init(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .unspecified
        case 1: self = .outsideRange
        case 2: self = .timestampInFuture
        case 3: self = .duplicate
        case 4: self = .earlierThanSessionStart
        case 5: self = .notInOrder
        case 6: self = .alreadyEntered
        case 7: self = .disabled
        case 8: self = .notPermitted
        case 9: self = .calibrationBoundsFailed
        case 10: self = .extremeOutlier
        case 11: self = .stale
        default: self = .unknown(rawValue)
        }
    }

    var traceDescription: String {
        switch self {
        case .unspecified: return "unspecified"
        case .outsideRange: return "outside range"
        case .timestampInFuture: return "timestamp in future"
        case .duplicate: return "duplicate"
        case .earlierThanSessionStart: return "earlier than session start"
        case .notInOrder: return "not in order"
        case .alreadyEntered: return "already entered"
        case .disabled: return "disabled"
        case .notPermitted: return "not permitted"
        case .calibrationBoundsFailed: return "calibration bounds failed"
        case .extremeOutlier: return "extreme outlier"
        case .stale: return "stale"
        case let .unknown(rawValue): return "unknown (\(rawValue))"
        }
    }

    var isTerminalDuplicate: Bool {
        self == .duplicate || self == .alreadyEntered
    }
}

/// Confidence or error detail carried in an accepted `0x34` response.
enum DexcomG7CalibrationAcceptanceDetail: Equatable {
    case accepted
    case error0
    case error1
    case unknown(UInt8)

    init(rawValue: UInt8) {
        switch rawValue {
        case 0: self = .accepted
        case 1: self = .error0
        case 2: self = .error1
        default: self = .unknown(rawValue)
        }
    }

    var traceDescription: String {
        switch self {
        case .accepted: return "accepted"
        case .error0: return "error 0"
        case .error1: return "error 1"
        case let .unknown(rawValue): return "unknown (\(rawValue))"
        }
    }
}

/// Decoded meaning of the two status bytes returned immediately after a calibration command.
enum DexcomG7CalibrationCommandStatus: Equatable {
    case acceptedHigh(DexcomG7CalibrationAcceptanceDetail)
    case acceptedLow(DexcomG7CalibrationAcceptanceDetail)
    case rejected(DexcomG7CalibrationRejectionReason)
    case factoryCalibrated
    case unknown(primary: UInt8, secondary: UInt8)

    var accepted: Bool {
        switch self {
        case let .acceptedHigh(detail), let .acceptedLow(detail): return detail == .accepted
        case .factoryCalibrated: return true
        case .rejected, .unknown: return false
        }
    }

    var traceDescription: String {
        switch self {
        case let .acceptedHigh(detail): return "accepted high likelihood: \(detail.traceDescription)"
        case let .acceptedLow(detail): return "accepted low likelihood: \(detail.traceDescription)"
        case let .rejected(reason): return "rejected: \(reason.traceDescription)"
        case .factoryCalibrated: return "factory calibrated"
        case let .unknown(primary, secondary): return "unknown primary=\(primary) secondary=\(secondary)"
        }
    }
}

/// Four-byte acknowledgement returned for the `0x34` calibration command.
struct DexcomG7CalibrationCommandResponse: Equatable {
    /// General command result byte returned by the transmitter.
    let transmitterResponse: UInt8

    /// Selects accepted-high, accepted-low, rejected, or factory-calibrated interpretation.
    let primaryStatus: UInt8

    /// Supplies the detailed acceptance or rejection reason selected by the primary status.
    let secondaryStatus: UInt8

    /// Typed interpretation consumed by the transmitter state machine and UI status tracker.
    let status: DexcomG7CalibrationCommandStatus

    init?(data: Data) {
        guard data.count == 4,
              data[0] == DexcomTransmitterOpCode.calibrateGlucoseTx.rawValue else { return nil }

        transmitterResponse = data[1]
        primaryStatus = data[2]
        secondaryStatus = data[3]

        switch primaryStatus {
        case 0: status = .acceptedHigh(DexcomG7CalibrationAcceptanceDetail(rawValue: secondaryStatus))
        case 1: status = .acceptedLow(DexcomG7CalibrationAcceptanceDetail(rawValue: secondaryStatus))
        case 2: status = .rejected(DexcomG7CalibrationRejectionReason(rawValue: secondaryStatus))
        case 3: status = .factoryCalibrated
        default: status = .unknown(primary: primaryStatus, secondary: secondaryStatus)
        }
    }
}

/// Durable processing state reported by the later `0x32` calibration bounds record.
enum DexcomG7CalibrationProcessingState: UInt8, Equatable {
    case none = 0
    case factoryCalibrated = 1
    case inProgress = 2
    case completeHigh = 3
    case completeLow = 4

    var traceDescription: String {
        switch self {
        case .none: return "none"
        case .factoryCalibrated: return "factory calibrated"
        case .inProgress: return "in progress"
        case .completeHigh: return "complete high"
        case .completeLow: return "complete low"
        }
    }
}

/// Device role that originally submitted the calibration stored in the bounds record.
enum DexcomG7CalibrationDisplay: UInt8, Equatable {
    case unknown = 0
    case medical = 1
    case phone = 2
    case watch = 3
    case receiver = 4
    case pump = 5
    case reader = 6
    case tool = 7
    case other = 8
    case transmitter = 9
}

/// Persistent `0x32` calibration record used to confirm that the accepted command was processed.
struct DexcomG7CalibrationBounds: Equatable {
    /// General command result byte returned by the transmitter.
    let transmitterResponse: UInt8

    /// Sensor session number that owns this persistent calibration record.
    let sessionNumber: UInt8

    /// Signature identifying the sensor session represented by this record.
    let sessionSignature: UInt32

    /// Whole-number glucose value stored for the most recent calibration.
    let glucose: UInt16

    /// Calibration entry time in the sensor's relative clock.
    let calibrationTime: UInt32

    /// Original processing byte retained even when a future value is not yet understood.
    let processingRawValue: UInt8

    /// Typed processing state when the raw byte is currently recognised.
    let processingState: DexcomG7CalibrationProcessingState?

    /// Sensor-level gate that reports whether this session currently accepts calibrations.
    let calibrationsPermitted: Bool

    /// Original display-role byte retained for tracing and future protocol additions.
    let originatingDisplayRawValue: UInt8

    /// Typed identity of the display that submitted the stored calibration when recognised.
    let originatingDisplay: DexcomG7CalibrationDisplay?

    /// Relative transmitter time of the most recent change to the processing record.
    let lastProcessingUpdateTime: UInt32

    init?(data: Data) {
        // The 20-byte 0x32 record is stable across connection cycles and remains the source of
        // truth after the immediate four-byte 0x34 command response.
        guard data.count == 20,
              data[0] == DexcomTransmitterOpCode.calibrationDataTx.rawValue else { return nil }

        transmitterResponse = data[1]
        sessionNumber = data[2]
        sessionSignature = Self.uint32(data, offset: 3)
        glucose = Self.uint16(data, offset: 7)
        calibrationTime = Self.uint32(data, offset: 9)
        processingRawValue = data[13]
        processingState = DexcomG7CalibrationProcessingState(rawValue: processingRawValue)
        calibrationsPermitted = data[14] != 0
        originatingDisplayRawValue = data[15]
        originatingDisplay = DexcomG7CalibrationDisplay(rawValue: originatingDisplayRawValue)
        lastProcessingUpdateTime = Self.uint32(data, offset: 16)
    }

    func matches(glucose expectedGlucose: Double, transmitterTime expectedTime: UInt32, tolerance: UInt32 = 2) -> Bool {
        // Value and time are both required because a stale bounds response can arrive immediately
        // after a new command. The small tolerance covers rounding between wall time and sensor time.
        guard glucose == UInt16(expectedGlucose.rounded()) else { return false }
        return abs(Int64(calibrationTime) - Int64(expectedTime)) <= Int64(tolerance)
    }

    private static func uint16(_ data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func uint32(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}

/// Anchors wall-clock calibration entry time to the most recently observed transmitter clock.
struct DexcomG7TransmitterClockReference: Equatable {
    /// Relative transmitter clock observed in the most recent valid glucose response.
    let transmitterTime: UInt32

    /// Wall-clock date represented by `transmitterTime`.
    let referenceDate: Date

    func transmitterTime(for date: Date) -> UInt32? {
        // Anchor calibration wall time to the latest glucose packet instead of an estimated sensor
        // start date. The estimate only spans the few seconds between entry and transmission.
        let delta = date.timeIntervalSince(referenceDate)
        let resolved = Double(transmitterTime) + delta
        guard resolved >= 0, resolved <= Double(UInt32.max) else { return nil }
        return UInt32(resolved.rounded())
    }
}
