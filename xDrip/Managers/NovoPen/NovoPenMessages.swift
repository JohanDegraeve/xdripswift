//
//  NovoPenMessages.swift
//  xdrip
//
//  Ported from xDrip "OpenNov" by JamOrHam (NightscoutFoundation/xDrip, GPLv3).
//
//  IEEE 11073-20601 messages exchanged with a NovoPen: decoded from the inner PHD record, and the frames we answer with.
//  All protocol fields are big-endian. Both directions are stateless: every frame stands on its own.
//

import Foundation

/// The pen's association request (AARQ).
struct NovoPenAssociationRequest {
    /// The APOEP element as sent: version, encoding, nomenclature and functional (the first 14 bytes) are echoed in our response.
    let raw: Data
    let systemId: Data
    let configId: UInt16
    var protocolId: UInt16 = 20601

    var isValid: Bool { protocolId == 20601 && systemId.count == 8 }
}

/// The pen's configuration report.
struct NovoPenConfiguration {
    let configId: UInt16
    /// Handle of the event report, i.e. of the pen's device object. The device information request addresses it.
    let handle: UInt16
    let numberOfSegments: Int
    let storedEntries: Int
    let capacity: Int
    let unitCode: Int

    /// MDC_DIM_INTL_UNIT (international units of insulin)
    var isAsExpected: Bool { unitCode == 5472 && numberOfSegments >= 0 && storedEntries >= 0 }
}

struct NovoPenDeviceInfo {
    let serial: String?
    let model: String?
}

struct NovoPenSegmentInfo {
    let instance: UInt16
    let usage: Int
    /// The only layout the dose log is known to have: 3 entries, units, error and flags.
    let isTypical: Bool
}

struct NovoPenDose {
    let relativeTime: UInt32
    let rawUnits: UInt32
    let flags: UInt32

    private static let maxUnits = 60.0
    private static let validFlags: UInt32 = 0x08000000
    private static let maxAge: TimeInterval = 12 * 30 * 24 * 3600

    /// nil if the raw value is not a unit count (0xFF00xxxx, tenths of a unit) or is not in 0 < units <= 60.
    var units: Double? {
        guard rawUnits & 0xFFFF_0000 == 0xFF00_0000 else { return nil }
        let units = Double(rawUnits & 0xFFFF) / 10
        return units > 0 && units <= Self.maxUnits ? units : nil
    }

    /// The dose with its wall clock date, or nil for an invalid entry (error flags, bad units, date in the future or over 12 x 30 days old).
    /// `eventRelativeTime` is the pen's clock when it sent the report, so the dose is that much older than `now`.
    func record(eventRelativeTime: UInt32, now: Date) -> NovoPenDoseRecord? {
        guard let units, flags == Self.validFlags else { return nil }
        let age = Int64(eventRelativeTime) - Int64(relativeTime)
        let date = now.addingTimeInterval(-Double(age))
        guard date <= now, date >= now.addingTimeInterval(-Self.maxAge) else { return nil }
        return NovoPenDoseRecord(date: date, units: units, relativeTime: relativeTime)
    }
}

struct NovoPenDoseRecord: Equatable {
    let date: Date
    let units: Double
    let relativeTime: UInt32

    /// Dedupe key, e.g. "EGDO2U:Open116177:3.0"
    func identifier(serial: String) -> String { "\(serial):Open\(relativeTime):\(units)" }
}

struct NovoPenSegmentData {
    let instance: UInt16
    let index: UInt32
    let count: UInt32
    let eventRelativeTime: UInt32
    /// Only the complete entries that arrived, newest first.
    let doses: [NovoPenDose]
}

enum NovoPenMessage {
    case empty
    case associationRequest(NovoPenAssociationRequest)
    case configuration(NovoPenConfiguration)
    case deviceInfo(NovoPenDeviceInfo)
    case segmentInfo([NovoPenSegmentInfo])
    case transferResult(segment: UInt16, response: UInt16)
    case segmentData(NovoPenSegmentData)
    case releaseRequest
    case releaseResponse
    case abort
    /// Valid but of no interest, e.g. the frames the manager sends itself.
    case other

    /// Decodes one inner PHD record. `invokeId` is set for data (PRST) records only.
    /// Fewer than 4 bytes carry no APDU and are `.empty`; an unknown APDU type throws `.badFrame`.
    static func parse(_ inner: Data) throws -> (message: NovoPenMessage, invokeId: UInt16?) {
        guard inner.count >= 4 else { return (.empty, nil) }
        var r = NovoPenByteReader(inner)
        let type = try r.u16()
        _ = try r.u16()   // choice length, not trusted (as Android)

        switch type {
        case NovoPenCode.aarq: return (try associationRequest(&r), nil)
        case NovoPenCode.aare: return (.other, nil)
        case NovoPenCode.rlrq: return (.releaseRequest, nil)
        case NovoPenCode.rlre: return (.releaseResponse, nil)
        case NovoPenCode.abrt: return (.abort, nil)
        case NovoPenCode.prst: return try data(&r)
        default: throw NovoPenError.badFrame(String(format: "unknown APDU type %04X", type))
        }
    }

    // MARK: - APDUs

    private static func associationRequest(_ r: inout NovoPenByteReader) throws -> NovoPenMessage {
        _ = try r.u32()   // version
        let elements = try r.u16()
        _ = try r.u16()   // length
        var request = NovoPenAssociationRequest(raw: Data(), systemId: Data(), configId: 0, protocolId: 0)
        for _ in 0..<elements {
            let protocolId = try r.u16()
            let body = try r.bytes(Int(try r.u16()))
            request.protocolId = protocolId
            guard protocolId == 20601 else { continue }
            var e = NovoPenByteReader(body)
            _ = try e.bytes(18)   // version, encoding, nomenclature, functional, system type
            request = NovoPenAssociationRequest(raw: body, systemId: try e.bytes(Int(try e.u16())), configId: try e.u16(), protocolId: protocolId)
        }
        return .associationRequest(request)
    }

    private static func data(_ r: inout NovoPenByteReader) throws -> (message: NovoPenMessage, invokeId: UInt16?) {
        _ = try r.u16()   // length
        let invokeId = try r.u16()
        let choice = try r.u16()
        _ = try r.u16()   // length

        switch choice {
        case NovoPenCode.actionResponse: return (try actionResponse(&r), invokeId)
        case NovoPenCode.eventReport: return (try eventReport(&r), invokeId)
        case NovoPenCode.getResponse: return (try deviceInfo(&r), invokeId)
        default: return (.other, invokeId)
        }
    }

    private static func actionResponse(_ r: inout NovoPenByteReader) throws -> NovoPenMessage {
        _ = try r.u16()   // handle
        let type = try r.u16()
        _ = try r.u16()   // length
        switch type {
        case NovoPenCode.getSegmentInfo:
            return .segmentInfo(try segmentInfos(&r))
        case NovoPenCode.triggerTransfer:
            let segment = try r.u16()
            return .transferResult(segment: segment, response: try r.u16())
        default:
            return .other
        }
    }

    private static func eventReport(_ r: inout NovoPenByteReader) throws -> NovoPenMessage {
        let handle = try r.u16()
        let relativeTime = try r.u32()
        let type = try r.u16()
        _ = try r.u16()   // length
        switch type {
        case NovoPenCode.segmentDataEvent: return try segmentData(&r, eventRelativeTime: relativeTime)
        case NovoPenCode.configEvent: return try configuration(&r, handle: handle)
        default: return .other
        }
    }

    // MARK: - Event report bodies

    private static func segmentData(_ r: inout NovoPenByteReader, eventRelativeTime: UInt32) throws -> NovoPenMessage {
        let instance = try r.u16()
        let index = try r.u32()
        let count = try r.u32()
        _ = try r.u16()   // status
        _ = try r.u16()   // byte count
        var doses: [NovoPenDose] = []
        // The count is the pen's claim: stop at the first incomplete entry, never fail the frame.
        while doses.count < Int(count) && r.remaining >= 12 {
            doses.append(NovoPenDose(relativeTime: try r.u32(), rawUnits: try r.u32(), flags: try r.u32()))
        }
        return .segmentData(NovoPenSegmentData(instance: instance, index: index, count: count, eventRelativeTime: eventRelativeTime, doses: doses))
    }

    private static func configuration(_ r: inout NovoPenByteReader, handle: UInt16) throws -> NovoPenMessage {
        let configId = try r.u16()
        let objects = try r.u16()
        _ = try r.u16()   // length
        var segments = -1, stored = -1, capacity = -1, unit = -1
        for _ in 0..<objects {
            _ = try r.u16()   // class
            _ = try r.u16()   // handle
            let attributes = try r.u16()
            _ = try r.u16()   // length
            for _ in 0..<attributes {
                let a = try r.attribute()
                switch a.type {
                case NovoPenCode.numSegments: segments = a.intValue
                case NovoPenCode.storeUsageCount: stored = a.intValue
                case NovoPenCode.storeCapacityCount: capacity = a.intValue
                case NovoPenCode.unitCode: unit = a.intValue
                default: break
                }
            }
        }
        return .configuration(NovoPenConfiguration(configId: configId, handle: handle, numberOfSegments: segments, storedEntries: stored, capacity: capacity, unitCode: unit))
    }

    // MARK: - Action and get responses

    private static func deviceInfo(_ r: inout NovoPenByteReader) throws -> NovoPenMessage {
        _ = try r.u16()   // handle
        let attributes = try r.u16()
        _ = try r.u16()   // length
        var serial: String?
        var model: String?
        for _ in 0..<attributes {
            let a = try r.attribute()
            switch a.type {
            case NovoPenCode.productSpecification: serial = Self.serial(inSpecification: a.bytes)
            case NovoPenCode.model: model = Self.model(from: a.bytes)
            default: break   // clock, system id, ...
            }
        }
        return .deviceInfo(NovoPenDeviceInfo(serial: serial, model: model))
    }

    /// count, length, then (type, component, string) entries. The serial number is type 1.
    private static func serial(inSpecification bytes: Data) -> String? {
        var r = NovoPenByteReader(bytes)
        guard let entries = try? r.u16(), (try? r.u16()) != nil else { return nil }
        for _ in 0..<entries {
            guard let type = try? r.u16(), (try? r.u16()) != nil, let value = try? r.string() else { return nil }
            if type == 1 && !value.isEmpty { return value }
        }
        return nil
    }

    /// Strings one after the other, e.g. "Novo Nordisk A/S" and "NovoPen".
    private static func model(from bytes: Data) -> String? {
        var r = NovoPenByteReader(bytes)
        var parts: [String] = []
        while r.remaining > 0, let part = try? r.string() { parts.append(part) }
        let model = parts.filter { !$0.isEmpty }.joined(separator: " ")
        return model.isEmpty ? nil : model
    }

    private static func segmentInfos(_ r: inout NovoPenByteReader) throws -> [NovoPenSegmentInfo] {
        let segments = try r.u16()
        _ = try r.u16()   // length
        var infos: [NovoPenSegmentInfo] = []
        for _ in 0..<segments {
            let instance = try r.u16()
            let attributes = try r.u16()
            _ = try r.u16()   // length
            var usage = -1
            var typicalMap = false
            for _ in 0..<attributes {
                let a = try r.attribute()
                switch a.type {
                case NovoPenCode.segmentMap: typicalMap = (try? isTypical(map: a.bytes)) ?? false
                case NovoPenCode.segmentUsageCount: usage = a.intValue
                default: break   // an unknown attribute is skipped, not fatal
                }
            }
            infos.append(NovoPenSegmentInfo(instance: instance, usage: usage, isTypical: usage >= 0 && typicalMap))
        }
        return infos
    }

    /// bits, count, length, then entries of (class, metric type, object type, handle, attribute count, attribute length, attribute type, attribute length).
    private static func isTypical(map: Data) throws -> Bool {
        var r = NovoPenByteReader(map)
        _ = try r.u16()   // bits
        let entries = try r.u16()
        _ = try r.u16()   // length
        guard entries == 3 else { return false }
        for expected: (objectType: UInt16, attributeType: UInt16) in [(13313, 2646), (13314, 2662), (61440, 2662)] {
            _ = try r.u16()   // class
            let metricType = try r.u16()
            let objectType = try r.u16()
            _ = try r.u16()   // handle
            _ = try r.u16()   // attribute count
            guard try r.u16() == 4 else { return false }
            let attributeType = try r.u16()
            _ = try r.u16()   // attribute length
            guard metricType == 130, objectType == expected.objectType, attributeType == expected.attributeType else { return false }
        }
        return true
    }
}

// MARK: - Encoding

/// The frames the manager sends, each one inner PHD record.
enum NovoPenEncoder {
    private static let apoepProtocol: UInt16 = 20601
    /// Association result "accepted, configuration unknown"
    private static let acceptedUnknownConfig: UInt16 = 3
    private static let managerSystemType: UInt32 = 0x8000_0000
    /// The pen's data store object
    private static let storeHandle: UInt16 = 0x0100
    /// Version, encoding, nomenclature and functional, echoed from the pen's request.
    private static let echoedLength = 14

    /// Accepts the pen's association: its own APOEP element back, as manager, without configuration or object list.
    static func associationResponse(to request: NovoPenAssociationRequest) -> Data {
        var element = NovoPenByteWriter()
        element.bytes(request.raw.prefix(echoedLength))
        element.u32(managerSystemType)
        element.u16(UInt16(request.systemId.count))
        element.bytes(request.systemId)
        element.u16(0)   // config id
        element.u32(0)   // reception mode
        element.u16(0)   // object list count
        element.u16(0)   // object list length

        var body = NovoPenByteWriter()
        body.u16(acceptedUnknownConfig)
        body.u16(apoepProtocol)
        body.u16(UInt16(element.data.count))
        body.bytes(element.data)
        return apdu(NovoPenCode.aare, body.data)
    }

    /// Accepts the configuration (`configId` from the pen's report).
    static func acceptConfiguration(invokeId: UInt16, configId: UInt16) -> Data {
        var body = NovoPenByteWriter()
        body.u16(configId)
        body.u16(0)   // accepted
        return eventReply(invokeId: invokeId, handle: 0, time: 0, type: NovoPenCode.configEvent, body: body.data)
    }

    /// Asks for the device information (serial, model, clock) of the object with `handle`, all attributes.
    static func askInformation(invokeId: UInt16, handle: UInt16) -> Data {
        var body = NovoPenByteWriter()
        body.u16(handle)
        body.u16(0)   // attribute id list count
        body.u16(0)   // attribute id list length
        return data(invokeId: invokeId, choice: NovoPenCode.get, payload: body.data)
    }

    static func getSegmentInfo(invokeId: UInt16) -> Data {
        var selector = NovoPenByteWriter()
        selector.u16(1)   // all segments
        selector.u16(2)
        selector.u16(0)
        return action(invokeId: invokeId, type: NovoPenCode.getSegmentInfo, body: selector.data)
    }

    static func triggerTransfer(invokeId: UInt16, segment: UInt16) -> Data {
        var body = NovoPenByteWriter()
        body.u16(segment)
        return action(invokeId: invokeId, type: NovoPenCode.triggerTransfer, body: body.data)
    }

    /// Confirms the dose report of `count` entries from `index` in `instance`. It is never marked first or last block, as Android.
    static func confirmSegmentData(invokeId: UInt16, instance: UInt16, index: UInt32, count: UInt32) -> Data {
        var body = NovoPenByteWriter()
        body.u16(instance)
        body.u32(index)
        body.u32(count)
        body.u8(0)      // middle block
        body.u8(0x80)   // confirmed
        return eventReply(invokeId: invokeId, handle: storeHandle, time: 0xFFFF_FFFF, type: NovoPenCode.segmentDataEvent, body: body.data)
    }

    // ponytail: Android sends E4 both ways; switch to E5 only if a pen rejects it.
    /// Also the answer to the pen's own release request.
    static let releaseRequest = apdu(NovoPenCode.rlrq, Data(count: 2))

    // MARK: - Framing

    /// APDU type, length, payload.
    private static func apdu(_ type: UInt16, _ payload: Data) -> Data {
        var w = NovoPenByteWriter()
        w.u16(type)
        w.u16(UInt16(payload.count))
        w.bytes(payload)
        return w.data
    }

    /// PRST data APDU: length, invoke id, choice, length, payload.
    private static func data(invokeId: UInt16, choice: UInt16, payload: Data) -> Data {
        var w = NovoPenByteWriter()
        w.u16(UInt16(payload.count + 6))
        w.u16(invokeId)
        w.u16(choice)
        w.u16(UInt16(payload.count))
        w.bytes(payload)
        return apdu(NovoPenCode.prst, w.data)
    }

    /// Confirmed action on the data store: handle, type, length, body.
    private static func action(invokeId: UInt16, type: UInt16, body: Data) -> Data {
        var w = NovoPenByteWriter()
        w.u16(storeHandle)
        w.u16(type)
        w.u16(UInt16(body.count))
        w.bytes(body)
        return data(invokeId: invokeId, choice: NovoPenCode.confirmedAction, payload: w.data)
    }

    /// Reply to a confirmed event report: handle, time, event type, length, body.
    private static func eventReply(invokeId: UInt16, handle: UInt16, time: UInt32, type: UInt16, body: Data) -> Data {
        var w = NovoPenByteWriter()
        w.u16(handle)
        w.u32(time)
        w.u16(type)
        w.u16(UInt16(body.count))
        w.bytes(body)
        return data(invokeId: invokeId, choice: NovoPenCode.confirmedEventReport, payload: w.data)
    }
}

// MARK: - Codes

private enum NovoPenCode {
    // APDU types
    static let aarq: UInt16 = 0xE200
    static let aare: UInt16 = 0xE300
    static let rlrq: UInt16 = 0xE400
    static let rlre: UInt16 = 0xE500
    static let abrt: UInt16 = 0xE600
    static let prst: UInt16 = 0xE700
    // data APDU choices
    static let eventReport: UInt16 = 0x0101
    static let get: UInt16 = 0x0103
    static let confirmedAction: UInt16 = 0x0107
    static let confirmedEventReport: UInt16 = 0x0201
    static let getResponse: UInt16 = 0x0203
    static let actionResponse: UInt16 = 0x0207
    // actions
    static let getSegmentInfo: UInt16 = 0x0C0D
    static let triggerTransfer: UInt16 = 0x0C1C
    // event types
    static let configEvent: UInt16 = 3356
    static let segmentDataEvent: UInt16 = 3361
    // attribute types
    static let model: UInt16 = 2344
    static let productSpecification: UInt16 = 2349
    static let storeCapacityCount: UInt16 = 2369
    static let storeUsageCount: UInt16 = 2372
    static let numSegments: UInt16 = 2385
    static let segmentUsageCount: UInt16 = 2427
    static let unitCode: UInt16 = 2454
    static let segmentMap: UInt16 = 2638
}

private struct NovoPenAttribute {
    let type: UInt16
    let bytes: Data

    /// 2 or 4 bytes as a number, anything else -1 (as Android).
    var intValue: Int { [2, 4].contains(bytes.count) ? bytes.reduce(0) { $0 << 8 | Int($1) } : -1 }
}

private extension NovoPenByteReader {
    /// type, length, value
    mutating func attribute() throws -> NovoPenAttribute {
        let type = try u16()
        return NovoPenAttribute(type: type, bytes: try bytes(Int(try u16())))
    }

    /// length, then the characters, without the NUL padding.
    mutating func string() throws -> String {
        String(decoding: try bytes(Int(try u16())), as: UTF8.self).replacingOccurrences(of: "\0", with: "")
    }
}
