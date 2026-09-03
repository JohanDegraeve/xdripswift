//
//  OttaiRegistry.swift
//  xdrip
//
//  Ottai / Syai CGM driver — saves the account login and the sensor keys.
//
//  This is a Swift copy of OttaiRegistry.kt from JugglucoNG. It uses UserDefaults
//  instead of Android preferences. It stores the account session (tokens, secret
//  key, region) and the decrypted keys of each sensor, so the Bluetooth part can
//  log in, stream and activate without the server.
//

import Foundation

/// Old cloud answers use milliseconds. The China V3 bind answer uses seconds.
/// We always store milliseconds.
func normalizeOttaiActiveTimeMs(_ value: Int64) -> Int64 {
    (value >= 1 && value <= 9_999_999_999) ? value * 1000 : value
}

enum OttaiRegistry {

    enum SessionProfile: String {
        case watch = "WATCH"
        case cnPhone = "CN_PHONE"
    }

    // MARK: - UserDefaults keys (same names as in the Kotlin code)

    private enum K {
        static let accessToken = "ottai_access_token"
        static let glucoseSecret = "ottai_glucose_secret_key"
        static let userId = "ottai_user_id"
        static let accountLogin = "ottai_account_login"
        static let apiBase = "ottai_api_base"
        static let sessionProfile = "ottai_session_profile"
        static let selfDeviceId = "ottai_self_device_id"
        static let cnCommonDeviceId = "ottai_cn_common_device_id"
        static let sensorsSet = "ottai_sensors"
        // xDrip only: upload of readings to the Syai cloud (see OttaiCloudUploader)
        static let cloudUploadEnabled = "ottai_cloud_upload_enabled"
        static let cloudUploadDeviceUuid = "ottai_cloud_upload_device_uuid"
        static let cloudUploadStatus = "ottai_cloud_upload_status"
        static let draftSensorsSet = "ottai_draft_sensors"

        static let keyAPrefix = "ottai_keya_"
        static let methodPrefix = "ottai_method_"
        static let coeffPrefix = "ottai_coeff_"
        static let activeTimePrefix = "ottai_active_time_"
        static let provisionalActiveTimePrefix = "ottai_provisional_active_time_"
        static let activeExpirePrefix = "ottai_active_expire_"
        static let acceptedMaxActivePrefix = "ottai_accepted_max_active_"
        static let preheatPeriodPrefix = "ottai_preheat_period_"
        static let retainTimePrefix = "ottai_retain_time_"
        static let deviceVersionPrefix = "ottai_device_version_"
        static let lastDataNoPrefix = "ottai_last_datano_"
        static let continuityBaselinePrefix = "ottai_continuity_baseline_"
        static let deviceIdPrefix = "ottai_device_id_"
        static let activationAttemptedPrefix = "ottai_act_tried_"
        static let v3BootstrapPendingPrefix = "ottai_v3_bootstrap_pending_"
        static func validatedVersion(_ id: String) -> String { "ottai_v3_validated_version_\(id)" }
    }

    private static let cnDeviceIdLength = 32
    private static let cnDeviceIdAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    private static let cnGeneratedPrefix = "g:"

    private static var d: UserDefaults { UserDefaults.standard }

    // MARK: - decrypted per-sensor materials

    struct DeviceMaterials {
        var keyAHex: String = ""
        var method: String = ""
        var coefficient: String = ""
        var activeTimeMs: Int64 = 0
        var deviceVersion: String = ""
        var deviceId: Int = 0
        var activeExpireTimeMs: Int64 = 0
        var retainTimeMs: Int64 = 0
        var preheatPeriodMs: Int64 = 0

        var authKeys: [[UInt8]]? { OttaiCrypto.parseAuthKeys(keyAHex) }

        var coefficients: [Double] {
            coefficient.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        }

        var hasAll: Bool {
            !keyAHex.isEmpty && !method.isEmpty && activeTimeMs > 0
        }
    }

    struct SensorRecord {
        let sensorId: String   // the cloud id; the server and the Bluetooth login use it
        let address: String    // Bluetooth address with colons; may be empty
        let displayName: String

        func matchesId(_ id: String?) -> Bool {
            OttaiConstants.matchesCanonicalOrKnownNativeAlias(sensorId, id)
        }
    }

    // MARK: - session accessors

    static func loadAccessToken() -> String { d.string(forKey: K.accessToken) ?? "" }
    static func saveAccessToken(_ v: String?) { setOrRemove(K.accessToken, v) }

    static func loadGlucoseSecretKey() -> String { d.string(forKey: K.glucoseSecret) ?? "" }
    static func saveGlucoseSecretKey(_ v: String?) { setOrRemove(K.glucoseSecret, v) }

    static func loadUserId() -> String { d.string(forKey: K.userId) ?? "" }
    static func saveUserId(_ v: String?) { setOrRemove(K.userId, v) }

    static func loadAccountLogin() -> String { d.string(forKey: K.accountLogin) ?? "" }
    static func saveAccountLogin(_ v: String?) { setOrRemove(K.accountLogin, v) }

    static func loadApiBase() -> String {
        let stored = d.string(forKey: K.apiBase)
        let normalized = normalizeApiBase(stored)
        if let stored = stored, !stored.isEmpty, stored != normalized {
            d.set(normalized, forKey: K.apiBase)
        }
        return normalized
    }

    static func normalizeApiBase(_ stored: String?) -> String {
        switch stored?.trimmingCharacters(in: .whitespaces) {
        case nil, "": return OttaiConstants.apiBase
        case OttaiConstants.apiBaseSyaiLegacy: return OttaiConstants.apiBaseSyai
        case let s?: return s
        }
    }

    static func saveApiBase(_ v: String) { d.set(v, forKey: K.apiBase) }

    static func loadSessionProfile() -> SessionProfile {
        SessionProfile(rawValue: d.string(forKey: K.sessionProfile) ?? "") ?? .watch
    }

    static func saveSessionProfile(_ profile: SessionProfile?) {
        setOrRemove(K.sessionProfile, profile?.rawValue)
    }

    // MARK: - upload to the Syai cloud (xDrip only)

    static func loadCloudUploadEnabled() -> Bool { d.bool(forKey: K.cloudUploadEnabled) }
    static func saveCloudUploadEnabled(_ v: Bool) { d.set(v, forKey: K.cloudUploadEnabled) }

    /// A short text for the settings screen: what the last upload did.
    static func loadCloudUploadStatus() -> String { d.string(forKey: K.cloudUploadStatus) ?? "" }
    static func saveCloudUploadStatus(_ v: String?) { setOrRemove(K.cloudUploadStatus, v) }

    /// The uuid in the deviceId header of the upload ("Syai Tag:a:n:<uuid>"). Made once, kept forever.
    static func loadOrCreateCloudUploadDeviceUuid() -> String {
        if let existing = d.string(forKey: K.cloudUploadDeviceUuid), !existing.isEmpty { return existing }
        let generated = UUID().uuidString.lowercased()
        d.set(generated, forKey: K.cloudUploadDeviceUuid)
        return generated
    }

    static func saveLastValidatedDeviceVersion(sensorId: String, version: String) {
        let v = version.trimmingCharacters(in: .whitespaces)
        if sensorId.isEmpty || v.isEmpty { return }
        d.set(v, forKey: K.validatedVersion(sensorId))
    }

    static func loadLastValidatedDeviceVersion(sensorId: String) -> String? {
        let v = d.string(forKey: K.validatedVersion(sensorId))?.trimmingCharacters(in: .whitespaces)
        return (v?.isEmpty ?? true) ? nil : v
    }

    /// A fixed id for this phone. It goes into the cloud signature and the deviceId header.
    static func loadOrCreateDeviceId() -> String {
        if let existing = d.string(forKey: K.selfDeviceId), !existing.isEmpty { return existing }
        let generated = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))
        d.set(generated, forKey: K.selfDeviceId)
        return generated
    }

    /// The device id for the China app headers. iOS has no ANDROID_ID, so we
    /// always make a random one in the `g:<32 chars>` form.
    static func loadCnHeaderDeviceId() -> String {
        if let existing = d.string(forKey: K.cnCommonDeviceId), !existing.isEmpty { return existing }
        var s = cnGeneratedPrefix
        let alphabet = Array(cnDeviceIdAlphabet)
        for _ in 0 ..< cnDeviceIdLength {
            s.append(alphabet[Int.random(in: 0 ..< alphabet.count)])
        }
        d.set(s, forKey: K.cnCommonDeviceId)
        return s
    }

    // MARK: - bootstrap / activation flags

    static func isV3CredentialBootstrapPending(_ id: String) -> Bool {
        d.bool(forKey: K.v3BootstrapPendingPrefix + OttaiConstants.canonicalSensorId(id))
    }

    static func setV3CredentialBootstrapPending(_ id: String, _ pending: Bool) {
        d.set(pending, forKey: K.v3BootstrapPendingPrefix + OttaiConstants.canonicalSensorId(id))
    }

    static func loadActivationAttempted(_ id: String) -> Bool {
        d.bool(forKey: K.activationAttemptedPrefix + OttaiConstants.canonicalSensorId(id))
    }

    static func setActivationAttempted(_ id: String, _ v: Bool) {
        d.set(v, forKey: K.activationAttemptedPrefix + OttaiConstants.canonicalSensorId(id))
    }

    // MARK: - materials

    static func saveMaterials(sensorId: String, _ m: DeviceMaterials) -> Bool {
        let id = canonical(sensorId)
        if id.isEmpty { return false }
        let existing = loadMaterials(sensorId: id)
        let coefficient = m.coefficient.isEmpty ? existing.coefficient : m.coefficient
        let method = OttaiMethodDefaults.resolve(method: m.method.isEmpty ? existing.method : m.method, coefficient: coefficient)
        let activeExpireTimeMs = OttaiConstants.sanitizeActiveExpireMs(m.activeExpireTimeMs)
        d.set(m.keyAHex, forKey: K.keyAPrefix + id)
        d.set(method, forKey: K.methodPrefix + id)
        d.set(coefficient, forKey: K.coeffPrefix + id)
        d.set(NSNumber(value: normalizeOttaiActiveTimeMs(m.activeTimeMs)), forKey: K.activeTimePrefix + id)
        if activeExpireTimeMs > 0 {
            d.set(NSNumber(value: activeExpireTimeMs), forKey: K.activeExpirePrefix + id)
        } else {
            d.removeObject(forKey: K.activeExpirePrefix + id)
        }
        d.set(NSNumber(value: m.retainTimeMs), forKey: K.retainTimePrefix + id)
        d.set(NSNumber(value: m.preheatPeriodMs), forKey: K.preheatPeriodPrefix + id)
        d.set(m.deviceVersion, forKey: K.deviceVersionPrefix + id)
        d.set(m.deviceId, forKey: K.deviceIdPrefix + id)
        setV3CredentialBootstrapPending(id, false)
        return true
    }

    static func loadMaterials(sensorId: String) -> DeviceMaterials {
        let id = canonical(sensorId)
        let coefficient = d.string(forKey: K.coeffPrefix + id) ?? ""
        let method = OttaiMethodDefaults.resolve(method: d.string(forKey: K.methodPrefix + id) ?? "", coefficient: coefficient)
        let storedActiveTime = int64(K.activeTimePrefix + id)
        let activeTimeMs = normalizeOttaiActiveTimeMs(storedActiveTime)
        if activeTimeMs != storedActiveTime { d.set(NSNumber(value: activeTimeMs), forKey: K.activeTimePrefix + id) }
        let storedExpire = int64(K.activeExpirePrefix + id)
        let activeExpireTimeMs = OttaiConstants.sanitizeActiveExpireMs(storedExpire)
        if activeExpireTimeMs != storedExpire { d.removeObject(forKey: K.activeExpirePrefix + id) }
        return DeviceMaterials(
            keyAHex: d.string(forKey: K.keyAPrefix + id) ?? "",
            method: method,
            coefficient: coefficient,
            activeTimeMs: activeTimeMs,
            deviceVersion: d.string(forKey: K.deviceVersionPrefix + id) ?? "",
            deviceId: d.integer(forKey: K.deviceIdPrefix + id),
            activeExpireTimeMs: activeExpireTimeMs,
            retainTimeMs: int64(K.retainTimePrefix + id),
            preheatPeriodMs: int64(K.preheatPeriodPrefix + id)
        )
    }

    static func saveActiveTimeMs(_ id: String, _ activeTimeMs: Int64) {
        d.set(NSNumber(value: normalizeOttaiActiveTimeMs(activeTimeMs)), forKey: K.activeTimePrefix + canonical(id))
    }

    static func loadProvisionalActiveTime(_ id: String) -> Int64 {
        int64(K.provisionalActiveTimePrefix + canonical(id))
    }

    static func saveProvisionalActiveTime(_ id: String, _ activeTimeMs: Int64) {
        d.set(NSNumber(value: activeTimeMs), forKey: K.provisionalActiveTimePrefix + canonical(id))
    }

    static func loadAcceptedMaxActive(_ id: String) -> Int64 {
        int64(K.acceptedMaxActivePrefix + canonical(id))
    }

    static func saveAcceptedMaxActive(_ id: String, _ durationMs: Int64) {
        d.set(NSNumber(value: durationMs), forKey: K.acceptedMaxActivePrefix + canonical(id))
    }

    static func loadLastDataNo(_ id: String) -> Int {
        d.integer(forKey: K.lastDataNoPrefix + canonical(id))
    }

    static func saveLastDataNo(_ id: String, _ dataNo: Int) {
        d.set(dataNo, forKey: K.lastDataNoPrefix + canonical(id))
    }

    /// The last good reading used by the spike filter. Saved so it is still there
    /// after an app restart. Stored as "dataNo,sampleMs,mmol,rawCurrent".
    struct ContinuityBaseline {
        let dataNo: Int
        let sampleMs: Int64
        let mmol: Float
        let rawCurrent: Int
    }

    static func saveContinuityBaseline(_ id: String, dataNo: Int, sampleMs: Int64, mmol: Float, rawCurrent: Int) {
        guard mmol.isFinite else { return }
        d.set("\(dataNo),\(sampleMs),\(mmol),\(rawCurrent)", forKey: K.continuityBaselinePrefix + canonical(id))
    }

    static func loadContinuityBaseline(_ id: String) -> ContinuityBaseline? {
        guard let raw = d.string(forKey: K.continuityBaselinePrefix + canonical(id)) else { return nil }
        let parts = raw.split(separator: ",").map(String.init)
        guard parts.count == 4,
              let dataNo = Int(parts[0]), let sampleMs = Int64(parts[1]),
              let mmol = Float(parts[2]), mmol.isFinite, let raw = Int(parts[3]) else { return nil }
        return ContinuityBaseline(dataNo: dataNo, sampleMs: sampleMs, mmol: mmol, rawCurrent: raw)
    }

    // MARK: - sensor record set

    static func persistedRecords() -> [SensorRecord] { readRecords(K.sensorsSet) }

    static func findRecord(_ sensorId: String?) -> SensorRecord? {
        guard let id = sensorId?.trimmingCharacters(in: .whitespaces), !id.isEmpty else { return nil }
        let target = OttaiConstants.canonicalSensorId(id)
        return persistedRecords().first { OttaiConstants.canonicalSensorId($0.sensorId) == target }
    }

    static func ensureSensorRecord(sensorId: String, address: String, displayName: String) {
        let id = canonical(sensorId)
        if id.isEmpty { return }
        var records = persistedRecords().filter { !$0.matchesId(id) }
        let ble = OttaiConstants.normalizeBleAddress(address, allowPlain: false) ?? (findRecord(id)?.address ?? "")
        records.append(SensorRecord(sensorId: id, address: ble, displayName: displayName.isEmpty ? id : displayName))
        writeRecords(K.sensorsSet, records)
    }

    static func removeSensor(_ sensorId: String?) {
        guard let raw = sensorId?.trimmingCharacters(in: .whitespaces) else { return }
        let id = canonical(raw).isEmpty ? raw : canonical(raw)
        writeRecords(K.sensorsSet, persistedRecords().filter { !$0.matchesId(id) })
        for prefix in [K.keyAPrefix, K.methodPrefix, K.coeffPrefix, K.activeTimePrefix,
                       K.provisionalActiveTimePrefix, K.activeExpirePrefix, K.retainTimePrefix,
                       K.preheatPeriodPrefix, K.deviceVersionPrefix, K.lastDataNoPrefix,
                       K.deviceIdPrefix, K.activationAttemptedPrefix, K.v3BootstrapPendingPrefix] {
            d.removeObject(forKey: prefix + id)
        }
        d.removeObject(forKey: K.validatedVersion(id))
        // The accepted lifetime is kept on purpose, same as in the Kotlin code.
    }

    // MARK: - private helpers

    private static func canonical(_ s: String) -> String {
        let c = OttaiConstants.canonicalSensorId(s)
        return c.isEmpty ? s : c
    }

    private static func int64(_ key: String) -> Int64 {
        (d.object(forKey: key) as? NSNumber)?.int64Value ?? 0
    }

    private static func setOrRemove(_ key: String, _ v: String?) {
        if let v = v, !v.isEmpty { d.set(v, forKey: key) } else { d.removeObject(forKey: key) }
    }

    private static func readRecords(_ key: String) -> [SensorRecord] {
        guard let raw = d.stringArray(forKey: key) else { return [] }
        return raw.compactMap { line in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 3 else { return nil }
            return SensorRecord(sensorId: parts[0], address: parts[1], displayName: parts[2])
        }
    }

    private static func writeRecords(_ key: String, _ records: [SensorRecord]) {
        d.set(records.map { "\($0.sensorId)|\($0.address)|\($0.displayName)" }, forKey: key)
    }
}
