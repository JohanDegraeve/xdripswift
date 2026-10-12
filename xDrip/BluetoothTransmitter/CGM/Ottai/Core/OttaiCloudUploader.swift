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
    struct Sample {
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
    private let queue = DispatchQueue(label: "OttaiCloudUploader.work")

    private var pending: [Sample] = []
    private var uploadedDataNos = Set<Int>()
    private var flushWork: DispatchWorkItem?
    private var inFlight = false
    private var retryDelay: TimeInterval = OttaiCloudUploader.firstRetryDelay
    private var bindConfirmed = false
    private var nextBindCheck = Date.distantPast
    /// Shown after the upload status while the Syai app does not show this sensor.
    private var bindNotice: String?

    init(sensorId: String) {
        self.sensorId = sensorId
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
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.uploadedDataNos.contains(sample.dataNo) { return }
            if let i = self.pending.firstIndex(where: { $0.dataNo == sample.dataNo }) {
                self.pending[i] = sample
            } else {
                self.pending.append(sample)
                if self.pending.count > Self.maxPending {
                    self.pending.removeFirst(self.pending.count - Self.maxPending)
                }
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
        guard !inFlight, !pending.isEmpty else { return }

        if let reason = Self.unavailableReason() {
            trace("cloud upload skipped: %{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, reason)
            if !OttaiRegistry.loadCloudUploadEnabled() { pending.removeAll() }
            Self.setStatus(reason)
            scheduleRetry()
            return
        }

        var materials = OttaiRegistry.loadMaterials(sensorId: sensorId)
        let batch = Array(pending.prefix(Self.maxBatch))
        let id = sensorId
        inFlight = true
        // The calls wait for the server, so they run off this queue.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            self.ensureBound(&materials)
            if materials.deviceId <= 0, let serverId = Self.serverDeviceId(id) {
                OttaiRegistry.saveDeviceId(id, serverId)
                materials.deviceId = serverId
            }
            guard materials.deviceId > 0 else {
                self.queue.async {
                    self.inFlight = false
                    self.fail("no cloud device id for this sensor yet")
                }
                return
            }
            trace("cloud upload: posting %{public}d readings (dataNo %{public}d…%{public}d) deviceId=%{public}d", log: self.log, category: ConstantsLog.categoryCGMOttai, type: .info,
                  batch.count, batch.map { $0.dataNo }.min() ?? 0, batch.map { $0.dataNo }.max() ?? 0, materials.deviceId)
            let ok = OttaiSyaiClient.uploadGlucose(Self.uploadBody(batch: batch, materials: materials)) != nil
            let failure = OttaiCloudClient.lastError
            self.queue.async { self.handleResponse(batch: batch, ok: ok, failure: failure) }
        }
    }

    /// The server device id (data.id of device/authInfo), as SyaiKit gets it.
    private static func serverDeviceId(_ sensorId: String) -> Int? {
        guard let data = OttaiSyaiClient.authInfo(mac: sensorId)?["data"] as? [String: Any],
              let id = (data["id"] as? NSNumber)?.intValue, id > 0 else { return nil }
        return id
    }

    private func handleResponse(batch: [Sample], ok: Bool, failure: String) {
        inFlight = false
        guard ok else {
            fail(failure.isEmpty ? "unknown error" : failure)
            return
        }

        let sent = Set(batch.map { $0.dataNo })
        uploadedDataNos.formUnion(sent)
        pending.removeAll { sent.contains($0.dataNo) }
        retryDelay = Self.firstRetryDelay
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        Self.setStatus("\(batch.count) reading(s) uploaded at \(stamp)" + (bindNotice.map { " — \($0)" } ?? ""))
        trace("cloud upload: ok count=%{public}d pending=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, batch.count, pending.count)
        if !pending.isEmpty { scheduleFlush(after: 0.5) }
    }

    private func fail(_ reason: String) {
        trace("cloud upload failed: %{public}@ (pending=%{public}d, retry in %{public}ds)", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, reason, pending.count, Int(retryDelay))
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
    private func ensureBound(_ materials: inout OttaiRegistry.DeviceMaterials) {
        guard !bindConfirmed, Date() >= nextBindCheck else { return }
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
                // check again on the next upload to take the deviceId of the new record
                nextBindCheck = .distantPast
                bindNotice = nil
            } else {
                trace("cloud bind failed: %{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, OttaiCloudClient.lastError)
                bindNotice = "bind failed: \(OttaiCloudClient.lastError)"
            }
        case nil:
            trace("cloud bind check failed: %{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, OttaiCloudClient.lastError)
        }
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
