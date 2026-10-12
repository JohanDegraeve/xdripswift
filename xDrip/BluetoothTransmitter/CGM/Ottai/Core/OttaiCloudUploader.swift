//
//  OttaiCloudUploader.swift
//  xdrip
//
//  Ottai / Syai CGM driver — sends the readings xDrip accepted to the Syai
//  cloud, so the Syai Tag app, the Syai website and its followers show the
//  same values as xDrip.
//

import Foundation
import os

final class OttaiCloudUploader {

    /// One reading, with the raw fields the Syai server wants.
    struct Sample: Codable {
        let dataNo: Int
        let runtimeSec: Int
        let voltage: Int
        let rawCurrent: Int
        let temperatureC: Double
        /// Glucose in mmol/L (the sensor formula result).
        let mmol: Double
        /// The time of the reading, ms since 1970.
        let sampleMs: Int64
        /// When the app received the packet, ms since 1970.
        let receivedAtMs: Int64
        /// The 12-byte record (00 00 ‖ dataNo ‖ 8 bytes) — sent as "origin".
        let originBytes: [UInt8]
        let live: Bool
    }

    // MARK: - constants

    /// The hardware model of this phone, e.g. "iPhone16,1".
    static let deviceModel: String = {
        var sys = utsname()
        uname(&sys)
        let machine = withUnsafeBytes(of: &sys.machine) { buf in
            String(decoding: buf.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return machine.isEmpty ? "iPhone" : machine
    }()
    /// 1 = a reading. Every 5th reading also goes as a 2 (checkpoint), as in SyaiKit.
    private static let dataTypeSensor = 1
    private static let dataTypeCheckpoint = 2
    private static let glucoseStatusNormal = 0

    private static let flushDelay: TimeInterval = 3.0
    private static let maxBatch = 200
    /// More than this and the oldest readings are dropped (about 3 days of 1-minute readings).
    private static let maxPending = 4000
    private static let firstRetryDelay: TimeInterval = 60
    private static let maxRetryDelay: TimeInterval = 15 * 60
    private static let bindCheckDelay: TimeInterval = 15 * 60

    // MARK: - state

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMOttai)
    private let sensorId: String
    // All instances share the queue and store, including briefly overlapping transmitters.
    private static let workQueue = DispatchQueue(label: "OttaiCloudUploader.work")
    private static var stores: [String: OttaiUploadOutbox] = [:]
    private var queue: DispatchQueue { Self.workQueue }
    private var outbox: OttaiUploadOutbox?
    private var boundAccount: String?
    private var flushWork: DispatchWorkItem?
    private var inFlight = false
    private var retryDelay: TimeInterval = OttaiCloudUploader.firstRetryDelay
    private var bindConfirmed = false
    private var nextBindCheck = Date.distantPast
    /// Shown after the upload status while the Syai app does not show this sensor.
    private var bindNotice: String?

    init(sensorId: String) {
        self.sensorId = OttaiConstants.canonicalSensorId(sensorId)
        queue.async { [self] in scheduleFlush(after: Self.flushDelay) }
    }

    private func loadOutbox() throws -> OttaiUploadOutbox {
        if let outbox = outbox { return outbox }
        if let stored = Self.stores[sensorId] {
            outbox = stored
            return stored
        }
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
            .appendingPathComponent("OttaiUploadOutbox", isDirectory: true)
        let store = try OttaiUploadOutbox(url: directory.appendingPathComponent(sensorId + ".json"))
        Self.stores[sensorId] = store
        outbox = store
        return store
    }

    private static var accountId: String {
        guard OttaiRegistry.loadApiBase() == OttaiConstants.apiBaseSyai else { return "" }
        return OttaiRegistry.loadUserId()
    }

    // MARK: - is the upload possible?

    /// Why the upload cannot run right now, or nil when it can.
    static func unavailableReason() -> String? {
        if !OttaiRegistry.loadCloudUploadEnabled() { return "Upload is off" }
        if OttaiRegistry.loadApiBase() != OttaiConstants.apiBaseSyai { return "Upload needs the Syai region" }
        if !OttaiCloudClient.isSignedIn { return "Not signed in" }
        return nil
    }

    // MARK: - enqueue

    /// Add one accepted reading. Nothing happens when the upload is off.
    func enqueue(reading: OttaiReading, mmol: Double, sampleMs: Int64, receivedAtMs: Int64, live: Bool) {
        guard OttaiRegistry.loadCloudUploadEnabled() else { return }
        let sample = Sample(
            dataNo: reading.record.dataNo,
            runtimeSec: reading.record.runtimeSec,
            voltage: reading.record.voltage,
            rawCurrent: reading.record.rawCurrent,
            temperatureC: reading.record.temperatureC,
            mmol: mmol,
            sampleMs: sampleMs,
            receivedAtMs: receivedAtMs,
            originBytes: reading.record.recordBytes,
            live: live
        )
        let account = Self.accountId
        // Called on the transmitter's work queue. Finish persistence before it can
        // advance xDrip's delivered watermark, otherwise a crash can still lose uploads.
        queue.sync {
            do {
                try loadOutbox().enqueue(sample, account: account, limit: Self.maxPending)
            } catch {
                fail("Could not save upload queue: \(error.localizedDescription)")
                return
            }
            // Only wait the short delay when no retry is already scheduled.
            if !self.inFlight && self.flushWork == nil {
                self.scheduleFlush(after: Self.flushDelay)
            }
        }
    }

    // MARK: - flush

    private func scheduleFlush(after delay: TimeInterval) {
        flushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.flushWork = nil
            self.flush()
        }
        flushWork = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func flush() {
        guard !inFlight else { return }
        let store: OttaiUploadOutbox
        do {
            store = try loadOutbox()
            // Retry a failed local write before sending anything to the server.
            try store.save()
        } catch {
            fail("Could not open/save upload queue: \(error.localizedDescription)")
            return
        }

        guard store.hasPending else { return }
        if let reason = Self.unavailableReason() {
            trace("cloud upload skipped: %{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, reason)
            Self.setStatus(reason)
            scheduleRetry()
            return
        }

        let account = Self.accountId
        guard !account.isEmpty else {
            fail("No Syai account id")
            return
        }
        do {
            try store.assignUnownedSamples(to: account, limit: Self.maxPending)
        } catch {
            fail("Could not save upload queue: \(error.localizedDescription)")
            return
        }
        let batch = Array(store.pending(account: account).prefix(Self.maxBatch))
        guard !batch.isEmpty else {
            // Also pick up sign-in/account changes without requiring another BLE reading.
            scheduleFlush(after: Self.firstRetryDelay)
            return
        }
        if boundAccount != account {
            boundAccount = account
            bindConfirmed = false
            nextBindCheck = .distantPast
            bindNotice = nil
        }
        var materials = OttaiRegistry.loadMaterials(sensorId: sensorId)
        let id = sensorId
        inFlight = true
        // The calls wait for the server, so they run off this queue.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let preparation = OttaiCloudClient.perform { () -> Bool in
                guard self.ensureBound(&materials) else { return false }
                if materials.deviceId <= 0, let serverId = Self.serverDeviceId(id) {
                    OttaiRegistry.saveDeviceId(id, serverId)
                    materials.deviceId = serverId
                }
                return materials.deviceId > 0
            }
            guard preparation.value else {
                self.queue.async {
                    self.inFlight = false
                    self.fail(preparation.errorText.isEmpty ? "no confirmed cloud device id for this sensor yet" : preparation.errorText)
                }
                return
            }
            trace("cloud upload: posting %{public}d readings (dataNo %{public}d…%{public}d) deviceId=%{public}d", log: self.log, category: ConstantsLog.categoryCGMOttai, type: .info,
                  batch.count, batch.map { $0.dataNo }.min() ?? 0, batch.map { $0.dataNo }.max() ?? 0, materials.deviceId)
            let result = OttaiCloudClient.perform {
                OttaiSyaiClient.uploadGlucose(Self.uploadBody(batch: batch, materials: materials), expectedUserId: account) != nil
            }
            self.queue.async { self.handleResponse(batch: batch, account: account, ok: result.value, failure: result.errorText) }
        }
    }

    /// The server device id (data.id of device/authInfo), as SyaiKit gets it.
    private static func serverDeviceId(_ sensorId: String) -> Int? {
        guard let data = OttaiSyaiClient.authInfo(mac: sensorId)?["data"] as? [String: Any],
              let id = (data["id"] as? NSNumber)?.intValue, id > 0 else { return nil }
        return id
    }

    private func handleResponse(batch: [Sample], account: String, ok: Bool, failure: String) {
        inFlight = false
        guard ok else {
            fail(failure.isEmpty ? "unknown error" : failure)
            return
        }

        do {
            try loadOutbox().acknowledge(batch, account: account)
        } catch {
            fail("Could not save upload confirmation: \(error.localizedDescription)")
            return
        }
        let remaining = outbox?.pending(account: account).count ?? 0
        retryDelay = Self.firstRetryDelay
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        Self.setStatus("\(batch.count) reading(s) uploaded at \(stamp)" + (bindNotice.map { " — \($0)" } ?? ""))
        trace("cloud upload: ok count=%{public}d pending=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, batch.count, remaining)
        scheduleFlush(after: remaining > 0 ? 0.5 : Self.firstRetryDelay)
    }

    private func fail(_ reason: String) {
        trace("cloud upload failed: %{public}@ (pending=%{public}d, retry in %{public}ds)", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, reason, outbox?.pending(account: Self.accountId).count ?? 0, Int(retryDelay))
        Self.setStatus("Failed: \(reason)")
        scheduleRetry()
    }

    private func scheduleRetry() {
        scheduleFlush(after: retryDelay)
        retryDelay = min(retryDelay * 2, Self.maxRetryDelay)
    }

    // MARK: - bind to the account

    /// The server takes readings of an unbound sensor, but the Syai app shows only the bound one.
    /// The setup binds an old Syai sensor only for a moment, so bind it here. Another bound
    /// sensor is left alone. Readings go to the deviceId of the bound record.
    private func ensureBound(_ materials: inout OttaiRegistry.DeviceMaterials) -> Bool {
        guard !bindConfirmed, Date() >= nextBindCheck else { return true }
        nextBindCheck = Date().addingTimeInterval(Self.bindCheckDelay)
        switch OttaiCloudClient.bindState(mac: sensorId) {
        case .thisSensor(let deviceId)?:
            if deviceId > 0 && deviceId != materials.deviceId {
                trace("cloud bind: bound deviceId=%{public}d, saved deviceId=%{public}d; uploading to the bound one", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, deviceId, materials.deviceId)
                OttaiRegistry.saveDeviceId(sensorId, deviceId)
                materials.deviceId = deviceId
            }
            bindConfirmed = true
            bindNotice = nil
        case .other(let bound)?:
            trace("cloud bind: the account has sensor %{public}@ bound, not %{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, bound, sensorId)
            bindNotice = "the Syai account has sensor \(bound) bound, unbind it in the Syai app"
        case .unbound?:
            if materials.activeTimeMs <= 0 {
                // wait for the confirmed activation time from the first live readings
                nextBindCheck = Date().addingTimeInterval(Self.firstRetryDelay)
            } else if OttaiCloudClient.bindPermanently(mac: sensorId, materials: materials) {
                trace("cloud bind: sensor %{public}@ bound, activeTime=%{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, sensorId, "\(materials.activeTimeMs / 1000)")
                // A new binding can create a new record. Invalidate the old id on disk
                // before looking it up, so a failed lookup or restart cannot reuse it.
                nextBindCheck = .distantPast
                guard Self.refreshBoundDeviceId(&materials,
                    lookup: { OttaiCloudClient.bindState(mac: self.sensorId) },
                    save: { OttaiRegistry.saveDeviceId(self.sensorId, $0) }) else { return false }
                bindConfirmed = true
                bindNotice = nil
            } else {
                trace("cloud bind failed: %{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, OttaiCloudClient.lastError)
                bindNotice = "bind failed: \(OttaiCloudClient.lastError)"
            }
        case nil:
            trace("cloud bind check failed: %{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, OttaiCloudClient.lastError)
        }
        return true
    }

    /// Persist invalidation before lookup; only the bound record can replace the old id.
    static func refreshBoundDeviceId(_ materials: inout OttaiRegistry.DeviceMaterials,
                                     lookup: () -> OttaiCloudClient.BindState?, save: (Int) -> Void) -> Bool {
        materials.deviceId = 0
        save(0)
        guard case .thisSensor(let deviceId)? = lookup(), deviceId > 0 else { return false }
        materials.deviceId = deviceId
        save(deviceId)
        return true
    }

    // MARK: - request

    static func uploadBody(batch: [Sample], materials: OttaiRegistry.DeviceMaterials) -> [String: Any] {
        [
            "deviceId": materials.deviceId,
            "embeddedSoftVersion": embeddedSoftVersion(materials.deviceVersion),
            "dataList": batch.flatMap { s -> [[String: Any]] in
                guard s.dataNo % 5 == 0, s.dataNo != 0 else { return [dataListEntry(s)] }
                return [dataListEntry(s), dataListEntry(s, dataType: dataTypeCheckpoint)]
            },
        ]
    }

    static func dataListEntry(_ s: Sample, dataType: Int = dataTypeSensor) -> [String: Any] {
        let mmol = (s.mmol * 10).rounded() / 10
        return [
            "runSec": s.runtimeSec,
            "voltage": s.voltage,
            "timeAppReceive": s.receivedAtMs,
            "frontIdx": s.dataNo,
            "glucose": mmol,
            "cgmGlucose": mmol,
            "adjGlucose": mmol,
            "current": s.rawCurrent,
            "time": s.sampleMs,
            "glucoseStatus": glucoseStatusNormal,
            "alignId": NSNull(),
            "temperature": (s.temperatureC * 10).rounded() / 10,
            "origin": dataType == dataTypeSensor ? s.originBytes.map { Int($0) } : NSNull(),
            "dataType": dataType,
        ]
    }

    /// The cloud stores the version as "E1.1.4(V1.7.S2530.1)". The app sends the
    /// part in the brackets — the sensor firmware. Old versions have no brackets.
    static func embeddedSoftVersion(_ deviceVersion: String) -> String {
        let v = deviceVersion.trimmingCharacters(in: .whitespaces)
        if let open = v.firstIndex(of: "("), let close = v.lastIndex(of: ")"), open < close {
            let inner = v[v.index(after: open) ..< close].trimmingCharacters(in: .whitespaces)
            if !inner.isEmpty { return inner }
        }
        return v
    }

    // MARK: - helpers

    private static func setStatus(_ text: String) {
        OttaiRegistry.saveCloudUploadStatus(text)
    }
}

/// Durable raw readings, independent of xDrip's delivered-data watermark. Access only
/// on OttaiCloudUploader.work. Kept here so every app target using the uploader includes it.
final class OttaiUploadOutbox {
    private struct Account: Codable {
        var pending: [OttaiCloudUploader.Sample] = []
        var uploadedDataNos: Set<Int> = []
    }

    private struct State: Codable {
        var version = 1
        var accounts: [String: Account] = [:]
    }

    private let url: URL
    private var state: State
    private var dirty = false

    init(url: URL) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            state = try JSONDecoder().decode(State.self, from: Data(contentsOf: url))
            guard state.version == 1 else {
                throw CocoaError(.fileReadCorruptFile)
            }
        } else {
            state = State()
        }
    }

    var hasPending: Bool { state.accounts.values.contains { !$0.pending.isEmpty } }

    func pending(account: String) -> [OttaiCloudUploader.Sample] {
        state.accounts[account]?.pending ?? []
    }

    func enqueue(_ sample: OttaiCloudUploader.Sample, account: String, limit: Int) throws {
        var entry = state.accounts[account] ?? Account()
        guard !entry.uploadedDataNos.contains(sample.dataNo) else { return }
        if let index = entry.pending.firstIndex(where: { $0.dataNo == sample.dataNo }) {
            entry.pending[index] = sample
        } else {
            entry.pending.append(sample)
        }
        if entry.pending.count > limit { entry.pending.removeFirst(entry.pending.count - limit) }
        state.accounts[account] = entry
        dirty = true
        try save()
    }

    /// Readings collected before the first sign-in can go to that account. Readings
    /// already owned by another account are never moved on logout or account changes.
    func assignUnownedSamples(to account: String, limit: Int) throws {
        guard !account.isEmpty, let unowned = state.accounts.removeValue(forKey: "") else { return }
        var entry = state.accounts[account] ?? Account()
        var known = entry.uploadedDataNos.union(entry.pending.map { $0.dataNo })
        let additional = unowned.pending.filter { known.insert($0.dataNo).inserted }
        entry.pending = (entry.pending + additional).sorted { $0.dataNo < $1.dataNo }
        if entry.pending.count > limit { entry.pending.removeFirst(entry.pending.count - limit) }
        state.accounts[account] = entry
        dirty = true
        try save()
    }

    func acknowledge(_ batch: [OttaiCloudUploader.Sample], account: String) throws {
        let sent = Set(batch.map { $0.dataNo })
        var entry = state.accounts[account] ?? Account()
        entry.uploadedDataNos.formUnion(sent)
        entry.pending.removeAll { sent.contains($0.dataNo) }
        state.accounts[account] = entry
        dirty = true
        try save()
    }

    func save() throws {
        guard dirty else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        // Atomic replacement leaves the previous queue intact on an interrupted write.
        // BLE background uploads must be able to read it after the phone locks again.
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        dirty = false
    }
}
