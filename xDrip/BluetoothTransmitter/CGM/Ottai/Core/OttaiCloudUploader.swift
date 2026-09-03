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

    // MARK: - constants (values seen in the Syai Tag app requests)

    private static let appName = "Syai Tag"
    private static let packageName = "com.syai.tag"
    private static let versionName = "1.23.0"
    private static let versionCode = "261933"
    private static let userAgent = "Dart/3.10 (dart:io)"
    /// The hardware model of this phone, e.g. "iPhone16,1".
    static let deviceModel: String = {
        var sys = utsname()
        uname(&sys)
        let machine = withUnsafeBytes(of: &sys.machine) { buf in
            String(decoding: buf.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return machine.isEmpty ? "iPhone" : machine
    }()
    private static let unit = "mmol_L"
    /// The Syai Tag app sends 1 for a reading from the sensor. Other values are unknown,
    /// so live and history readings are both sent as 1.
    private static let dataTypeSensor = 1
    private static let glucoseStatusNormal = 0

    private static let flushDelay: TimeInterval = 3.0
    private static let maxBatch = 200
    /// More than this and the oldest readings are dropped (about 3 days of 1-minute readings).
    private static let maxPending = 4000
    private static let firstRetryDelay: TimeInterval = 60
    private static let maxRetryDelay: TimeInterval = 15 * 60
    private static let requestTimeout: TimeInterval = 30

    // MARK: - state

    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMOttai)
    private let sensorId: String
    private let queue = DispatchQueue(label: "OttaiCloudUploader.work")
    private let session: URLSession

    private var pending: [Sample] = []
    private var uploadedDataNos = Set<Int>()
    private var flushWork: DispatchWorkItem?
    private var inFlight = false
    private var retryDelay: TimeInterval = OttaiCloudUploader.firstRetryDelay
    /// The customerId of the signed-in account, found once per app run.
    private var cachedCustomerId: String?

    init(sensorId: String) {
        self.sensorId = sensorId
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Self.requestTimeout
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    // MARK: - is the upload possible?

    /// Why the upload cannot run right now, or nil when it can.
    static func unavailableReason() -> String? {
        if !OttaiRegistry.loadCloudUploadEnabled() { return "Upload is off" }
        if OttaiRegistry.loadApiBase() != OttaiConstants.apiBaseSyai { return "Upload needs the Syai region" }
        if OttaiRegistry.loadAccessToken().isEmpty { return "Not signed in" }
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

        let materials = OttaiRegistry.loadMaterials(sensorId: sensorId)
        guard materials.deviceId > 0 else {
            trace("cloud upload skipped: no cloud device id for sensor %{public}@", log: log, category: ConstantsLog.categoryCGMOttai, type: .error, sensorId)
            Self.setStatus("No cloud device id for this sensor — fetch the sensor from the cloud")
            pending.removeAll()
            return
        }

        let customerId = resolveCustomerId()
        let batch = Array(pending.prefix(Self.maxBatch))
        guard let request = buildRequest(batch: batch, materials: materials, customerId: customerId) else {
            Self.setStatus("Could not build the upload request")
            return
        }

        inFlight = true
        trace("cloud upload: posting %{public}d readings (dataNo %{public}d…%{public}d) deviceId=%{public}d", log: log, category: ConstantsLog.categoryCGMOttai, type: .info,
              batch.count, batch.map { $0.dataNo }.min() ?? 0, batch.map { $0.dataNo }.max() ?? 0, materials.deviceId)
        session.dataTask(with: request) { [weak self] data, response, error in
            self?.queue.async { self?.handleResponse(batch: batch, data: data, response: response, error: error) }
        }.resume()
    }

    private func handleResponse(batch: [Sample], data: Data?, response: URLResponse?, error: Error?) {
        inFlight = false
        let httpCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let jsonObj = text.isEmpty ? nil : (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
        let bizCode = Self.anyToString(jsonObj?["code"])
        let bizMsg = [Self.anyToString(jsonObj?["message"]), Self.anyToString(jsonObj?["msg"]), Self.anyToString(jsonObj?["detailMessage"])]
            .first { !$0.isEmpty } ?? ""
        let bizOk = bizCode.isEmpty || bizCode == "200" || bizCode.caseInsensitiveCompare("OK") == .orderedSame

        if let error = error {
            fail("network: \(error.localizedDescription)")
            return
        }
        guard (200 ... 299).contains(httpCode), bizOk else {
            fail("http=\(httpCode) biz=\(bizCode) \(String(bizMsg.prefix(120)))".trimmingCharacters(in: .whitespaces))
            return
        }

        let sent = Set(batch.map { $0.dataNo })
        uploadedDataNos.formUnion(sent)
        pending.removeAll { sent.contains($0.dataNo) }
        retryDelay = Self.firstRetryDelay
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        Self.setStatus("\(batch.count) reading(s) uploaded at \(stamp)")
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

    // MARK: - customer id

    /// The customerId header. Always the signed-in account: read once from the account
    /// profile, or the user id when the profile has none. It can not be typed in, so an
    /// upload can never go to another account.
    private func resolveCustomerId() -> String {
        if let cached = cachedCustomerId { return cached }
        let resolved: String
        if let profile = OttaiCloudClient.fetchUserProfile(), let found = Self.findCustomerId(in: profile) {
            trace("cloud upload: customerId %{public}@ found in the account profile", log: log, category: ConstantsLog.categoryCGMOttai, type: .info, found)
            resolved = found
        } else {
            trace("cloud upload: no customerId in the account profile, using the user id", log: log, category: ConstantsLog.categoryCGMOttai, type: .info)
            resolved = OttaiRegistry.loadUserId()
        }
        cachedCustomerId = resolved
        return resolved
    }

    static func findCustomerId(in dict: [String: Any]) -> String? {
        for (key, value) in dict {
            let k = key.lowercased()
            if k == "customerid" || k == "customer_id" || k == "customerno" {
                let s = anyToString(value)
                if !s.isEmpty { return s }
            }
        }
        for (_, value) in dict {
            if let sub = value as? [String: Any], let found = findCustomerId(in: sub) { return found }
        }
        return nil
    }

    // MARK: - request

    private func buildRequest(batch: [Sample], materials: OttaiRegistry.DeviceMaterials, customerId: String) -> URLRequest? {
        guard let url = URL(string: OttaiConstants.apiBaseSyai + OttaiConstants.epCollectGlucoseV2) else { return nil }
        let body: [String: Any] = [
            "deviceId": materials.deviceId,
            "embeddedSoftVersion": Self.embeddedSoftVersion(materials.deviceVersion),
            "dataList": batch.map(Self.dataListEntry),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: []) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = data
        for (k, v) in Self.headers(customerId: customerId) { req.setValue(v, forHTTPHeaderField: k) }
        return req
    }

    static func dataListEntry(_ s: Sample) -> [String: Any] {
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
            "origin": s.originBytes.map { Int($0) },
            "dataType": dataTypeSensor,
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

    static func headers(customerId: String, now: Date = Date()) -> [String: String] {
        let ts = Int64(now.timeIntervalSince1970 * 1000)
        let tz = TimeZone.current
        let locale = Locale.current
        let country = locale.region?.identifier ?? "GB"
        let language = locale.language.languageCode?.identifier ?? "en"
        var h: [String: String] = [
            "user-agent": userAgent,
            "ua": "android",
            "deviceid": "\(appName):a:n:\(OttaiRegistry.loadOrCreateCloudUploadDeviceUuid())",
            "authorization": OttaiRegistry.loadAccessToken(),
            "appname": appName,
            "content-type": "application/json",
            "timestamp": String(ts),
            "versioncode": versionCode,
            "country": country,
            "traceid": UUID().uuidString.lowercased(),
            "language": language,
            "timezone": String(tz.secondsFromGMT(for: now)),
            "region": country,
            "packagename": packageName,
            "unit": unit,
            "timezonename": tz.abbreviation(for: now) ?? tz.identifier,
            "devicemodel": deviceModel,
            "versionname": versionName,
        ]
        if !customerId.isEmpty { h["customerid"] = customerId }
        return h
    }

    // MARK: - helpers

    private static func setStatus(_ text: String) {
        OttaiRegistry.saveCloudUploadStatus(text)
    }

    private static func anyToString(_ any: Any?) -> String {
        guard let any = any else { return "" }
        if let s = any as? String { return s == "null" ? "" : s }
        if let n = any as? NSNumber { return n.stringValue }
        return ""
    }
}
