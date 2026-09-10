import Foundation

// MARK: - Frame Parser

/// Парсинг F003 фреймов, F002 ответов, history и calibration данных.
enum AidexParser {

    // MARK: - F003 Classification

    enum FrameType { case data, status, calibration, unknown }

    static func classifyFrame(_ data: Data) -> FrameType {
        switch data.count {
        case AidexFrame.dataFrameLength:                    return .data
        case AidexFrame.statusFrameLength:                  return .status
        case AidexFrame.calibrationNotificationLength:      return .calibration
        default:                                            return .unknown
        }
    }

    // MARK: - 17-byte Data Frame

    /// Парсинг 17-байтового дешифрованного F003-фрейма.
    static func parseDataFrame(_ data: Data) -> GlucoseFrame? {
        guard data.count == AidexFrame.dataFrameLength else { return nil }

        let opcode = data[0]
        let seconds = UInt32(littleEndianData: data.subdata(in: 1..<5))
        let timeOffsetMinutes = Int(seconds / 60)
        let glucosePacked = Int(data.subdata(in: 6..<8).toU16LE())
        let rawGlucose = glucosePacked & AidexFrame.glucoseMask
        let i1Raw = Int(data.subdata(in: 8..<10).toU16LE())
        let i2Raw = Int(data.subdata(in: 10..<12).toU16LE())
        let crc16 = data.subdata(in: 15..<17).toU16LE()

        let i1 = Float(i1Raw) / 100.0
        let i2 = Float(i2Raw) / 100.0
        let scale = scalingFactor(for: opcode)
        let glucoseMgDl = Float(rawGlucose) * scale

        let isSentinel = rawGlucose == AidexFrame.sentinelGlucose
        let isInRange = rawGlucose >= AidexFrame.minValidGlucose
                     && rawGlucose <= AidexFrame.maxValidGlucose
        let isValid = !isSentinel && isInRange

        return GlucoseFrame(
            opcode: opcode,
            timeOffsetMinutes: timeOffsetMinutes,
            glucoseMgDl: glucoseMgDl,
            rawGlucosePacked: rawGlucose,
            i1: i1,
            i2: i2,
            crc16: crc16,
            isValid: isValid
        )
    }

    /// Проверка CRC-16 в F003 фрейме (байты 0..14 payload, 15..16 CRC).
    static func validateFrameCRC(_ decrypted: Data) -> Bool {
        guard decrypted.count >= AidexFrame.dataFrameLength else { return false }
        let payload = decrypted.prefix(15)
        let frameCRC = decrypted.subdata(in: 15..<17).toU16LE()
        return CRC16.checksum(payload) == frameCRC
    }

    // MARK: - History Parsing

    /// GET_HISTORIES_RAW (0x23): калиброванная глюкоза, 2-байтные записи.
    static func parseHistoryResponse(_ data: Data) -> [CalibratedHistoryEntry] {
        guard data.count >= 4 else { return [] }

        let startOffset = Int(data.subdata(in: 0..<2).toU16LE())
        let body = data.subdata(in: 2..<data.count)
        let rowCount = body.count / 2

        return (0..<rowCount).map { i in
            let off = i * 2
            let b0 = Int(body[off])
            let b1 = Int(body[off + 1])
            let glucose = b0 | ((b1 & 0x03) << 8)
            return CalibratedHistoryEntry(
                timeOffsetMinutes: startOffset + i,
                glucoseMgDl: glucose,
                statusBit: (b1 & 0x04) != 0,
                isSentinel: glucose == AidexFrame.sentinelGlucose
            )
        }
    }

    /// GET_HISTORIES (0x24): сырые ADC данные, 5-байтные записи.
    static func parseBriefHistoryResponse(_ data: Data) -> [AdcHistoryEntry] {
        guard data.count >= 7 else { return [] }

        let startOffset = Int(data.subdata(in: 0..<2).toU16LE())
        let body = data.subdata(in: 2..<data.count)
        let rowCount = body.count / 5

        return (0..<rowCount).compactMap { i in
            let off = i * 5
            let i1Raw = Int(body.subdata(in: off..<off+2).toU16LE())
            let i2Raw = Int(body.subdata(in: off+2..<off+4).toU16LE())
            let vcRaw  = Int(body[off + 4])

            // Пропуск невалидных записей
            guard i1Raw != 0 || i2Raw != 0 || vcRaw != 0 else { return nil }

            let i1 = Float(i1Raw) / 100.0
            let i2 = Float(i2Raw) / 100.0
            let vc = Float(vcRaw) / 100.0

            return AdcHistoryEntry(
                timeOffsetMinutes: startOffset + i,
                i1: i1, i2: i2, vc: vc,
                rawValue: i1 * 10.0,
                sensorGlucose: i1 * 18.0182
            )
        }
    }

    // MARK: - GET_HISTORY_RANGE (0x22)

    static func parseHistoryRange(_ data: Data) -> HistoryRange? {
        guard data.count >= 6 else { return nil }
        return HistoryRange(
            briefStart: Int(data.subdata(in: 0..<2).toU16LE()),
            rawStart: Int(data.subdata(in: 2..<4).toU16LE()),
            newestOffset: Int(data.subdata(in: 4..<6).toU16LE())
        )
    }

    // MARK: - Calibration

    /// GET_CALIBRATION_RANGE (0x26).
    static func parseCalibrationRange(_ data: Data) -> CalibrationRange? {
        guard data.count >= 4 else { return nil }
        return CalibrationRange(
            startIndex: Int(data.subdata(in: 0..<2).toU16LE()),
            endIndex: Int(data.subdata(in: 2..<4).toU16LE())
        )
    }

    /// GET_CALIBRATION (0x27).
    static func parseCalibrationResponse(_ data: Data) -> [CalibrationRecord] {
        guard data.count >= 10 else { return [] }

        let startIndex = Int(data.subdata(in: 0..<2).toU16LE())
        guard startIndex <= 10000 else { return [] }

        let body = data.subdata(in: 2..<data.count)
        guard body.count % 8 == 0 else { return [] }

        let rowCount = body.count / 8
        return (0..<rowCount).map { i in
            let off = i * 8
            let timeOffset = Int(body.subdata(in: off..<off+2).toU16LE())
            let reference = Int(body.subdata(in: off+2..<off+4).toU16LE())
            let cfRaw = Int(body.subdata(in: off+4..<off+6).toU16LE())
            let offsetRaw = Int(body.subdata(in: off+6..<off+8).toS16LE())
            return CalibrationRecord(
                index: startIndex + i,
                timeOffsetMinutes: timeOffset,
                referenceGlucoseMgDl: reference,
                calibrationFactor: Float(cfRaw) / 100.0,
                calibrationOffset: Float(offsetRaw) / 100.0
            )
        }
    }

    // MARK: - Startup Device Info (0x10)

    static func parseStartupDeviceInfoPayload(_ payload: Data) -> StartupDeviceInfo? {
        guard payload.count >= 16 else { return nil }
        guard payload.subdata(in: 0..<2).toU16LE() == 0 else { return nil }

        let fwMajor = Int(payload[2])
        let fwMinor = Int(payload[3])
        let hwMajor = Int(payload[4])
        let hwMinor = Int(payload[5])
        let wearDays = Int(payload[6])
        let modelBytes = payload.subdata(in: 8..<payload.count)
        let modelName = String(bytes: modelBytes.prefix { $0 != 0 }, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        guard !modelName.isEmpty else { return nil }

        return StartupDeviceInfo(
            firmwareVersion: "\(fwMajor).\(fwMinor)",
            hardwareVersion: "\(hwMajor).\(hwMinor)",
            wearDays: wearDays,
            modelName: modelName
        )
    }

    static func parseStartupDeviceInfoFrame(_ frame: Data, payloadEndExclusive: Int? = nil) -> StartupDeviceInfo? {
        let end = payloadEndExclusive ?? frame.count
        guard end > 1, end <= frame.count else { return nil }

        if let parsed = parseStartupDeviceInfoPayload(frame.subdata(in: 1..<end)) {
            return parsed
        }
        guard end > 2 else { return nil }
        return parseStartupDeviceInfoPayload(frame.subdata(in: 2..<end))
    }

    // MARK: - Session Start Time

    static func parseLocalStartTimePayload(_ payload: Data) -> LocalStartTime? {
        guard payload.count >= 7 else { return nil }

        let parsed = LocalStartTime(
            year: Int(payload.subdata(in: 0..<2).toU16LE()),
            month: Int(payload[2]),
            day: Int(payload[3]),
            hour: Int(payload[4]),
            minute: Int(payload[5]),
            second: Int(payload[6]),
            tzQuarters: payload.count >= 8 ? Int(Int8(bitPattern: payload[7])) : 0,
            dstQuarters: payload.count >= 9 ? Int(payload[8]) : 0
        )

        if parsed.isAllZeros { return parsed }

        let plausible = parsed.year >= 2020 && parsed.year <= 2040
            && parsed.month >= 1 && parsed.month <= 12
            && parsed.day >= 1 && parsed.day <= 31
            && parsed.hour >= 0 && parsed.hour <= 23
            && parsed.minute >= 0 && parsed.minute <= 59
            && parsed.second >= 0 && parsed.second <= 59

        return plausible ? parsed : nil
    }

    // MARK: - Default Param (0x31)

    static func parseDefaultParamChunk(_ payload: Data) -> DefaultParamChunk? {
        guard payload.count >= 5 else { return nil }

        let totalWords = Int(payload[1])
        let startIndex = Int(payload[2])
        let rawChunk = payload.subdata(in: 3..<payload.count)

        guard totalWords > 0, startIndex > 0, startIndex <= totalWords else { return nil }
        guard !rawChunk.isEmpty, rawChunk.count % 2 == 0 else { return nil }

        return DefaultParamChunk(
            leadByte: payload[0],
            totalWords: totalWords,
            startIndex: startIndex,
            rawChunk: rawChunk
        )
    }
}

// MARK: - Data Extensions

extension Data {
    func toU16LE(at offset: Int = 0) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func toS16LE(at offset: Int = 0) -> Int16 {
        let u = toU16LE(at: offset)
        return Int16(bitPattern: u)
    }

    func toU32LE(at offset: Int = 0) -> UInt32 {
        var value: UInt32 = 0
        for i in 0..<4 {
            value |= UInt32(self[offset + i]) << (i * 8)
        }
        return value
    }
}

extension UInt32 {
    init(littleEndianData data: Data) {
        self = data.withUnsafeBytes { $0.load(as: UInt32.self) }
    }
}