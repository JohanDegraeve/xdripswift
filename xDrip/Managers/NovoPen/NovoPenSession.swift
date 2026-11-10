//
//  NovoPenSession.swift
//  xdrip
//
//  Ported from xDrip "OpenNov" by JamOrHam (NightscoutFoundation/xDrip, GPLv3).
//
//  One IEEE 11073 conversation with a NovoPen, as opennov Machine.java and OpenNov.processTag:
//  association, configuration, device information, segment info, transfer, dose reports, release.
//

import Foundation
import OSLog

struct NovoPenReadResult {
    let serial: String
    let model: String
    /// Newest first, as the pen sends them.
    let doses: [NovoPenDoseRecord]
    /// error or invalid pen entries
    let skipped: Int
    /// false = read interrupted; `doses` holds what arrived
    let completed: Bool
}

final class NovoPenSession {
    static let importWindow: TimeInterval = 7 * 24 * 3600
    private static let maxErrors = 3
    private static let maxTransactions = 200

    private let channel: NovoPenChannel
    private let now: () -> Date
    private let progress: (Int) -> Void
    /// Asked once the serial is known: false ends the read there, with no doses (adding a pen, or a pen not added yet).
    private let wantsDoses: (String) -> Bool
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryNovoPen)

    private var errors = 0
    private var transactions = 0
    /// Echoed in every frame we send, as Android.
    private var invokeId: UInt16 = 0
    private var serial: String?
    private var model = ""
    private var doses: [NovoPenDoseRecord] = []
    private var skipped = 0
    /// A dose report arrived with fewer entries than its count. The pen moved on after our confirm, so those entries are lost for this read.
    private var missedEntries = false

    /// The pen released or aborted the association.
    private struct Ended: Error {}

    init(channel: NovoPenChannel, now: @escaping () -> Date = Date.init, wantsDoses: @escaping (String) -> Bool = { _ in true }, progress: @escaping (Int) -> Void = { _ in }) {
        self.channel = channel
        self.now = now
        self.wantsDoses = wantsDoses
        self.progress = progress
    }

    /// Throws only if the serial was never learned, or for a dose log layout we do not know.
    /// Any other failure returns the doses read so far with `completed == false`.
    func run() async throws -> NovoPenReadResult {
        do {
            try await read()
            try? await channel.send(NovoPenEncoder.releaseRequest)
            _ = try? await channel.receive()   // the pen's answer, best effort
            return result(completed: !missedEntries)
        } catch {
            if case NovoPenError.nonTypicalSegments = error { throw error }
            guard let serial else { throw error is Ended ? NovoPenError.badFrame("pen ended the session before sending its serial") : error }
            trace("NovoPen: read of %{public}@ interrupted after %{public}@ doses: %{public}@", log: log, category: ConstantsLog.categoryNovoPen, type: .info, serial, String(doses.count), String(describing: error))
            return result(completed: false)
        }
    }

    private func result(completed: Bool) -> NovoPenReadResult {
        NovoPenReadResult(serial: serial ?? "", model: model, doses: doses, skipped: skipped, completed: completed)
    }

    /// Returns when the log is read to the end, or far enough back.
    private func read() async throws {
        let request = try await receive { message -> NovoPenAssociationRequest? in
            guard case .associationRequest(let request) = message else { return nil }
            guard request.isValid else { throw NovoPenError.badFrame("association request is not IEEE 11073-20601") }
            return request
        }
        try await channel.send(NovoPenEncoder.associationResponse(to: request))

        let configuration = try await receive { message -> NovoPenConfiguration? in
            guard case .configuration(let configuration) = message else { return nil }
            guard configuration.isAsExpected else { throw NovoPenError.badFrame("configuration is not in insulin units") }
            return configuration
        }
        try await channel.send(NovoPenEncoder.acceptConfiguration(invokeId: invokeId, configId: configuration.configId))

        _ = try await next()
        let askInformation = { NovoPenEncoder.askInformation(invokeId: self.invokeId, handle: configuration.handle) }
        try await channel.send(askInformation())
        let info = try await receive(replying: { _ in askInformation() }) { message -> NovoPenDeviceInfo? in
            guard case .deviceInfo(let info) = message, info.serial != nil else { return nil }
            return info
        }
        serial = info.serial
        model = info.model ?? ""
        if let serial, !wantsDoses(serial) { return }

        try await channel.send(NovoPenEncoder.getSegmentInfo(invokeId: invokeId))
        let segment = try await receive { message -> NovoPenSegmentInfo? in
            guard case .segmentInfo(let infos) = message else { return nil }
            guard infos.count == 1, infos[0].isTypical else { throw NovoPenError.nonTypicalSegments("Non typical segments - please report to developers") }
            return infos[0]
        }

        // a new pen has nothing logged
        if segment.usage == 0 { return }

        let trigger = { NovoPenEncoder.triggerTransfer(invokeId: self.invokeId, segment: segment.instance) }
        try await channel.send(trigger())
        let accepted = try await receive(replying: { if case .empty = $0 { return Data() } else { return trigger() } }) { message -> Bool? in
            guard case .transferResult(let instance, let response) = message, instance != 0 else { return nil }
            if response == 0 { return true }
            // IEEE 11073-20601: 1 no such segment, 3 segment empty. Asking again only runs into the transaction cap.
            return instance == segment.instance ? false : nil
        }
        guard accepted else {
            trace("NovoPen: pen refused the transfer, nothing to read", log: log, category: ConstantsLog.categoryNovoPen, type: .info)
            return
        }
        try await channel.send(Data())   // the pen sends its first dose report on our next write (Android writeNull)

        while true {
            let report = try await receive { message -> NovoPenSegmentData? in
                guard case .segmentData(let report) = message else { return nil }
                return report
            }
            let date = now()
            var records: [NovoPenDoseRecord] = []
            for dose in report.doses {
                if let record = dose.record(eventRelativeTime: report.eventRelativeTime, now: date) {
                    records.append(record)
                } else {
                    skipped += 1
                    trace("NovoPen: skipped entry at %{public}@, units %{public}@, flags %{public}@", log: log, category: ConstantsLog.categoryNovoPen, type: .info, String(dose.relativeTime), String(format: "%08X", dose.rawUnits), String(format: "%08X", dose.flags))
                }
            }
            doses += records
            if report.doses.count < Int(report.count) { missedEntries = true }
            progress(doses.count)

            // newest first: the rest of the log is older still
            if !records.isEmpty && records.allSatisfy({ $0.date < date.addingTimeInterval(-Self.importWindow) }) { return }

            try await channel.send(NovoPenEncoder.confirmSegmentData(invokeId: invokeId, instance: report.instance, index: report.index, count: report.count))

            // a short dose list is not the end of the segment, whatever its index and count say
            if report.doses.count == Int(report.count) && Int(report.index) + Int(report.count) == segment.usage { return }
        }
    }

    // MARK: - Receiving

    /// Receives until `match` accepts a message. The others are answered with `reply`, by default an empty frame so the pen keeps talking.
    private func receive<T>(replying reply: (NovoPenMessage) -> Data = { _ in Data() }, _ match: (NovoPenMessage) throws -> T?) async throws -> T {
        while true {
            let message = try await next()
            if let value = try match(message) { return value }
            try await channel.send(reply(message))
        }
    }

    /// The next message from the pen. A transport or parse error costs one of `maxErrors`; a frame that does not parse is answered with an empty frame.
    /// The pen's release request is answered and, like an abort, ends the session (`Ended`).
    private func next() async throws -> NovoPenMessage {
        while true {
            transactions += 1
            guard transactions <= Self.maxTransactions else { throw NovoPenError.limitExceeded("more than \(Self.maxTransactions) transactions") }

            let inner: Data
            do {
                inner = try await channel.receive()
            } catch {
                try count(error)
                continue
            }

            let parsed: (message: NovoPenMessage, invokeId: UInt16?)
            do {
                parsed = try NovoPenMessage.parse(inner)
            } catch {
                trace("NovoPen: cannot parse %{public}@", log: log, category: ConstantsLog.categoryNovoPen, type: .error, inner.hexEncodedString())
                try count(error)
                try await channel.send(Data())
                continue
            }

            if let id = parsed.invokeId { invokeId = id }
            switch parsed.message {
            case .releaseRequest:
                try await channel.send(NovoPenEncoder.releaseRequest)
                throw Ended()
            case .abort:
                throw Ended()
            default:
                return parsed.message
            }
        }
    }

    /// Counts an error and rethrows it once there are `maxErrors`. Never reset.
    private func count(_ error: Error) throws {
        errors += 1
        trace("NovoPen: error %{public}@ of %{public}@: %{public}@", log: log, category: ConstantsLog.categoryNovoPen, type: .error, String(errors), String(Self.maxErrors), String(describing: error))
        if errors >= Self.maxErrors { throw error }
    }
}
