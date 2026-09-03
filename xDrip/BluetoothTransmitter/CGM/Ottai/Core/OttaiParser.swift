//
//  OttaiParser.swift
//  xdrip
//
//  Ottai / Syai CGM driver — reads the live and history packets from the sensor.
//
//  This is a Swift copy of OttaiParser.kt from JugglucoNG.
//
//  A decrypted packet looks like this:
//    bytes 0..3   status (not used)
//    bytes 4..5   the dataNo of the first record (little-endian)
//    bytes 6..7   marker / count (little-endian)
//    bytes 8..N   the records, 8 or 9 bytes each
//  We turn every record into a 12-byte record for the parser:
//    {0x00,0x00} || dataNo (little-endian) || the 8 record bytes
//  Fields of the 12-byte record:
//    [2..3]   dataNo (little-endian)
//    [4]      voltage
//    [5..7]   runtime = (b5<<16) | (b7<<8) | b6   (this mixed order is correct)
//    [8..9]   raw current (little-endian)
//    [10..11] temperature*100 (little-endian) -> /100.0
//
//  Live mode uses only the LAST record. History mode uses all records.
//

import Foundation

struct OttaiRecord {
    let dataNo: Int
    let voltage: Int
    let runtimeSec: Int
    let rawCurrent: Int
    let temperatureC: Double
    /// The 12-byte record (00 00 ‖ dataNo ‖ 8 bytes).
    let recordBytes: [UInt8]
}

struct OttaiReading {
    let record: OttaiRecord
    /// The formula result. 0.0 means too low or invalid.
    let adjustGlucose: Double
    /// activeTimeMs + runtimeSec*1000. 0 if the activation time is unknown.
    let monitorTimeMs: Int64
    /// False when the record fails the sanity check.
    let valid: Bool
}

enum OttaiParser {

    static let headerSize = 8
    static let bleRecordSize = 8
    /// Some V1.7 sensors use 9-byte records with a different layout.
    static let bleRecordSizeE12 = 9
    static let parserRecordSize = 12
    static let invalidDataNo = 65535

    /// Firmware families where we know the record size for sure.
    private static let confirmedEFamilies: [String: Int] = [
        "1.2": bleRecordSizeE12, // E1.2.3(V1.7.SH2542.1) — 9-byte
    ]

    /// The E-number at the start of a version text: `E1.1.4(...)`, `vE1.2.3(...)`.
    private static let eNumberRegex = try! NSRegularExpression(
        pattern: "(?:^|[^0-9A-Za-z])v?e(\\d+)\\.(\\d+)",
        options: [.caseInsensitive]
    )

    /// Choose the record size for a packet.
    ///
    /// The version text is not enough: a Syai sensor and a CN V3 sensor can both
    /// say E1.1.4(V1.7.S2530.1) but use different layouts. So we only trust the
    /// version for known families. For the rest we try both sizes and count how
    /// many records look valid (current >= 1000, temperature <= 45). The wrong size
    /// gives nonsense like 505 °C, so it loses.
    static func chooseRecordSize(_ payload: [UInt8], deviceVersion: String) -> Int {
        if let confirmed = confirmedRecordSize(deviceVersion) { return confirmed }
        let nine = vendorValidCount(payload, recSize: bleRecordSizeE12, curLo: 0, tempLo: 7)
        let eight = vendorValidCount(payload, recSize: bleRecordSize, curLo: 4, tempLo: 6)
        return nine > eight ? bleRecordSizeE12 : bleRecordSize
    }

    /// Record size for firmware we know; nil if unknown.
    private static func confirmedRecordSize(_ deviceVersion: String) -> Int? {
        let range = NSRange(deviceVersion.startIndex..., in: deviceVersion)
        if let m = eNumberRegex.firstMatch(in: deviceVersion, options: [], range: range),
           let r1 = Range(m.range(at: 1), in: deviceVersion),
           let r2 = Range(m.range(at: 2), in: deviceVersion) {
            let key = "\(deviceVersion[r1]).\(deviceVersion[r2])"
            if let size = confirmedEFamilies[key] { return size }
        }
        // Old version texts without an E-number. V1.5 is always 8 bytes.
        // V1.7 is not clear, so it is not listed here and we guess from the data.
        if deviceVersion.range(of: "V1.5", options: .caseInsensitive) != nil { return bleRecordSize }
        return nil
    }

    /// Count the records that pass the simple validity check for this record size.
    private static func vendorValidCount(_ payload: [UInt8], recSize: Int, curLo: Int, tempLo: Int) -> Int {
        let count = (payload.count - headerSize) / recSize
        if count <= 0 { return 0 }
        var valid = 0
        for i in 0 ..< count {
            let src = headerSize + i * recSize
            if src + tempLo + 1 >= payload.count { break }
            let current = le16(payload[src + curLo], payload[src + curLo + 1])
            let temperature = Double(le16(payload[src + tempLo], payload[src + tempLo + 1])) / 100.0
            if current >= 1000 && temperature <= 45.0 { valid += 1 }
        }
        return valid
    }

    private static func le16(_ lo: UInt8, _ hi: UInt8) -> Int {
        Int(lo) | (Int(hi) << 8)
    }

    /// The dataNo of the first record (bytes 4..5).
    static func frontDataNo(_ payload: [UInt8]) -> Int {
        if payload.count < 6 { return 0 }
        return le16(payload[4], payload[5])
    }

    /// Split a decrypted packet into 12-byte records. Extra bytes at the end are
    /// ignored. Returns an empty list if there are no records.
    static func frameRecords(_ payload: [UInt8], deviceVersion: String = "") -> [[UInt8]] {
        if payload.count <= headerSize { return [] }
        let front = frontDataNo(payload)
        let bleSize = chooseRecordSize(payload, deviceVersion: deviceVersion)
        let nineByte = bleSize == bleRecordSizeE12
        let bodyLen = payload.count - headerSize
        let count = bodyLen / bleSize
        if count <= 0 { return [] }
        var out: [[UInt8]] = []
        out.reserveCapacity(count)
        for i in 0 ..< count {
            let src = headerSize + i * bleSize
            // 9-byte packets fill the end with zero records. Skip them, so the live
            // path gets the real last record.
            if nineByte && (0 ..< bleSize).allSatisfy({ payload[src + $0] == 0 }) { continue }
            let dataNo = (front + i) & 0xFFFF
            var rec = [UInt8](repeating: 0, count: parserRecordSize)
            rec[2] = UInt8(dataNo & 0xFF)
            rec[3] = UInt8((dataNo >> 8) & 0xFF)
            if nineByte {
                // Move the 9-byte fields into the 12-byte layout, so the parser and the
                // formula stay the same. The 16-bit runtime counter wraps around, so we
                // take runtime from dataNo (= minutes since activation) instead.
                let runtime = dataNo * 60
                rec[4] = payload[src + 6]                        // voltage
                rec[5] = UInt8((runtime >> 16) & 0xFF)           // runtime (b5<<16)
                rec[6] = UInt8(runtime & 0xFF)                   // runtime (| b6)
                rec[7] = UInt8((runtime >> 8) & 0xFF)            // runtime (| b7<<8)
                rec[8] = payload[src + 0]                        // current LE lo
                rec[9] = payload[src + 1]                        // current LE hi
                rec[10] = payload[src + 7]                       // temp*100 LE lo
                rec[11] = payload[src + 8]                       // temp*100 LE hi
            } else {
                for j in 0 ..< bleRecordSize { rec[4 + j] = payload[src + j] }
            }
            out.append(rec)
        }
        return out
    }

    /// Read the fields of a 12-byte record.
    static func parseRecord(_ rec: [UInt8]) -> OttaiRecord {
        precondition(rec.count >= parserRecordSize, "record too short")
        let dataNo = le16(rec[2], rec[3])
        let voltage = Int(rec[4])
        let b5 = Int(rec[5])
        let b6 = Int(rec[6])
        let b7 = Int(rec[7])
        let runtime = (b5 << 16) | (b7 << 8) | b6
        let rawCurrent = le16(rec[8], rec[9])
        let temperature = Double(le16(rec[10], rec[11])) / 100.0
        return OttaiRecord(dataNo: dataNo, voltage: voltage, runtimeSec: runtime,
                           rawCurrent: rawCurrent, temperatureC: temperature, recordBytes: rec)
    }

    /// Sanity check from the official app: dataNo must not be 65535, and after
    /// dataNo 60 the dataNo and runtime/60 must not differ by more than 120.
    static func isRecordSane(_ rec: OttaiRecord) -> Bool {
        if rec.dataNo == invalidDataNo { return false }
        if rec.dataNo >= 60 && abs(rec.dataNo - (rec.runtimeSec / 60)) > 120 { return false }
        return true
    }

    /// True for an "average" record: runtime >= warmup, dataNo >= 5, dataNo is a multiple of 5.
    static func isAverageTick(_ rec: OttaiRecord, warmupSec: Int = 3200) -> Bool {
        rec.runtimeSec >= warmupSec && rec.dataNo >= 5 && rec.dataNo % 5 == 0
    }

    // MARK: - full parse (decrypt → records → formula)

    /// Live: decrypt, take the last record, run the formula.
    static func parseLive(cipher: [UInt8], sessionKeyHex: String, method: String, coefficients: [Double], activeTimeMs: Int64) -> OttaiReading? {
        guard let payload = OttaiCrypto.decryptPayload(cipher, sessionKeyHex: sessionKeyHex) else { return nil }
        let records = frameRecords(payload)
        guard let last = records.last else { return nil }
        return toReading(last, method: method, coefficients: coefficients, activeTimeMs: activeTimeMs)
    }

    /// History: decrypt, take all records, run the formula on each.
    static func parseHistory(cipher: [UInt8], sessionKeyHex: String, method: String, coefficients: [Double], activeTimeMs: Int64) -> [OttaiReading] {
        guard let payload = OttaiCrypto.decryptPayload(cipher, sessionKeyHex: sessionKeyHex) else { return [] }
        return frameRecords(payload).map { toReading($0, method: method, coefficients: coefficients, activeTimeMs: activeTimeMs) }
    }

    /// Make a reading from one 12-byte record (no decryption here).
    static func toReading(_ rec12: [UInt8], method: String, coefficients: [Double], activeTimeMs: Int64) -> OttaiReading {
        let record = parseRecord(rec12)
        let adjust: Double
        if method.trimmingCharacters(in: .whitespaces).isEmpty {
            adjust = 0.0
        } else {
            adjust = OttaiFormula.evaluate(
                methodText: method,
                coefficients: coefficients,
                v: OttaiFormula.buildVariables(
                    rawCurrent: record.rawCurrent,
                    temperature: record.temperatureC,
                    runtimeSec: record.runtimeSec,
                    dataNo: record.dataNo,
                    voltage: record.voltage
                ),
                recordBytes: rec12
            )
        }
        let monitorMs = activeTimeMs > 0 ? activeTimeMs + Int64(record.runtimeSec) * 1000 : 0
        return OttaiReading(record: record, adjustGlucose: adjust, monitorTimeMs: monitorMs, valid: isRecordSane(record))
    }
}
