//
//  OttaiCloudClient.swift
//  xdrip
//
//  Ottai / Syai CGM driver — talks to the cloud (login, check and bind a sensor,
//  cgmAuth, unbind, decrypt the sensor keys). Works with all three servers:
//  China (api.ottai.com, phone + SMS), Global (seas.ottai.com), Syai
//  (api.syai.com), and also the website API for email login and sign-up.
//
//  This is a Swift copy of OttaiCloudClient.kt from JugglucoNG. The HTTP calls
//  wait for the answer, so call them from a background queue, never from the
//  main thread.
//

import CryptoKit
import Foundation

enum OttaiCloudClient {

    // The secret used to sign requests. The old endpoints and cgmAuth use MD5.
    private static let seed = "dy7234hbnrnfh7q89eru8ybfn899"
    private static let watchAppName = "ottai-watch"
    private static let watchPkg = "com.ottai.tag.watch"
    private static let phoneAppName = "ottai"
    private static let phonePkg = "com.ottai.tag"
    private static let timeoutMs = 30_000
    private static let temporaryUnbindDelayMs: UInt32 = 2_000

    // Error codes from the server that the caller must handle.
    static let bizAlreadyBinding = "AppUser_AlreadyBinding"
    static let bizOutOfProduceTime = "AppDevice_OutOfProduceTime"
    static let bizUpgradeVersion = "AppDevice_Upgrade_Version"
    static let bizEndUsing = "AppDevice_EndUsing"

    struct CloudFailure { let text: String; var code: String = "" }

    /// Why the last call failed (no secrets in it). Nil after a call that worked.
    static var lastFailure: CloudFailure?
    static var lastError: String { lastFailure?.text ?? "" }

    struct LoginResult {
        let userId: String
        let accessToken: String
        let glucoseSecretKey: String
        var ok: Bool { !accessToken.isEmpty && !glucoseSecretKey.isEmpty }
    }

    struct DeviceResp {
        var mac: String
        var keyA: String
        var method: String
        var coefficient: String
        var produceTime: Int64
        var methodUpdateTime: Int64
        var coeffUpdateTime: Int64
        var activeTime: Int64
        var activeExpireTime: Int64  // sensor lifetime in ms
        var preheatPeriodTime: Int64
        var retainTime: Int64        // "destruction" time in ms
        var deviceVersion: String
        var deviceId: Int
    }

    struct DeviceValidation {
        let device: DeviceResp
        /// New China sensors answer the V3 check with info only. keyA comes later from bindV3.
        let requiresV3Bind: Bool
    }

    struct DeviceSummary {
        let mac: String
        let serialNo: String
        let deviceType: String
        let deviceVersion: String
        let bindTime: Int64
        let unbindTime: Int64
        var isActive: Bool { unbindTime <= 0 }
    }

    struct V3AuthMaterial {
        let authHost: String
        let authFlag: String
        let keyB: String
        let cf: String
        var ok: Bool { !authHost.isEmpty && !authFlag.isEmpty }
    }

    // MARK: - identity / signature

    private struct ApiIdentity {
        let appName: String
        let packageName: String
        func deviceId(_ value: String) -> String { "\(appName):a:\(value)" }
    }

    private static func sessionIdentity(_ profile: OttaiRegistry.SessionProfile) -> ApiIdentity {
        profile == .cnPhone ? ApiIdentity(appName: phoneAppName, packageName: phonePkg)
                            : ApiIdentity(appName: watchAppName, packageName: watchPkg)
    }

    private static func md5Hex(_ s: String) -> String {
        // The cloud signs with MD5. CryptoKit returns a digest sequence; keep the previous
        // lowercase hex string format.
        Insecure.MD5.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func signForProfile(_ profile: OttaiRegistry.SessionProfile, deviceId: String, ts: Int64, _ args: String...) -> String {
        let identity = sessionIdentity(profile)
        return md5Hex(identity.appName + identity.deviceId(deviceId) + String(ts) + args.joined() + seed)
    }

    static func cgmAuthVerifySign(_ profile: OttaiRegistry.SessionProfile, deviceId: String, timestampMillis: Int64, mac: String, paramStr: String, shaInfo: String) -> String {
        let identity = sessionIdentity(profile)
        return md5Hex(identity.appName + identity.deviceId(deviceId) + mac.uppercased() + paramStr.uppercased() + shaInfo.uppercased() + String(timestampMillis) + seed)
    }

    private static func activeProfile(_ apiBase: String) -> OttaiRegistry.SessionProfile {
        apiBase == OttaiConstants.apiBase ? OttaiRegistry.loadSessionProfile() : .watch
    }

    private static func requestDeviceId(_ profile: OttaiRegistry.SessionProfile) -> String {
        profile == .cnPhone ? OttaiRegistry.loadCnHeaderDeviceId() : OttaiRegistry.loadOrCreateDeviceId()
    }

    private static func headers(ts: Int64, apiBase: String, authorizationOverride: String? = nil, profileOverride: OttaiRegistry.SessionProfile? = nil) -> [String: String] {
        let token = authorizationOverride ?? OttaiRegistry.loadAccessToken()
        let profile = profileOverride ?? activeProfile(apiBase)
        let deviceId = requestDeviceId(profile)
        if profile == .cnPhone {
            var h = cnPhoneHeaders(deviceId: deviceId, accessToken: token, timestamp: ts, traceId: UUID().uuidString)
            if token.isEmpty { h.removeValue(forKey: "Authorization") }
            return h
        }
        let identity = sessionIdentity(.watch)
        let offsetSec = TimeZone.current.secondsFromGMT()
        var h: [String: String] = [
            "appName": identity.appName,
            "versionName": "1.1.0",
            "versionCode": "244301",
            "packageName": identity.packageName,
            "ua": "Android_Watch_Ottai_Arc",
            "timezone": String(offsetSec),
            "timeZoneName": TimeZone.current.identifier,
            "language": Locale.current.language.languageCode?.identifier ?? "en",
            "traceId": "trace_testtest",
            "timestamp": String(ts),
            "country": "zh_CN",
            "deviceId": identity.deviceId(deviceId),
        ]
        // The China server only accepts China IPs. Send a fake one, but ONLY to that server.
        if apiBase == OttaiConstants.apiBase {
            h["X-Forwarded-For"] = OttaiConstants.cnForwardIp
            h["X-Real-IP"] = OttaiConstants.cnForwardIp
            h["CF-Connecting-IP"] = OttaiConstants.cnForwardIp
            h["True-Client-IP"] = OttaiConstants.cnForwardIp
        }
        if !token.isEmpty { h["Authorization"] = token }
        return h
    }

    private static func cnPhoneHeaders(deviceId: String, accessToken: String, timestamp: Int64, traceId: String) -> [String: String] {
        let identity = sessionIdentity(.cnPhone)
        return [
            "User-Agent": "Dart/3.8 (dart:io)",
            "ua": "Android",
            "deviceId": identity.deviceId(deviceId),
            "applicationType": "ottai_main",
            "appName": identity.appName,
            "versionCode": "263121",
            "country": "CN",
            "language": "zh",
            "timezone": "28800",
            "packageName": identity.packageName,
            "productModel": "MB",
            "unit": "mmol_L",
            "timeZoneName": "Asia/Shanghai",
            "deviceModel": "SM-A205FN",
            "versionName": "1.55.0",
            "X-Forwarded-For": OttaiConstants.cnForwardIp,
            "X-Real-IP": OttaiConstants.cnForwardIp,
            "CF-Connecting-IP": OttaiConstants.cnForwardIp,
            "True-Client-IP": OttaiConstants.cnForwardIp,
            "timestamp": String(timestamp),
            "traceId": traceId,
            "Authorization": accessToken,
        ]
    }

    private static func now() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    private static func base() -> String { OttaiRegistry.loadApiBase() }

    private static func normalizePhone(_ raw: String) -> String {
        var d = raw.filter { $0.isNumber }
        if d.count == 13 && d.hasPrefix("86") { d = String(d.dropFirst(2)) }
        if d.count == 14 && d.hasPrefix("0086") { d = String(d.dropFirst(4)) }
        return d
    }

    // MARK: - login

    static func getApiToken(apiBase: String = base(), authorizationOverride: String? = nil, profileOverride: OttaiRegistry.SessionProfile? = nil) -> String? {
        let ts = now()
        let profile = profileOverride ?? activeProfile(apiBase)
        let deviceId = requestDeviceId(profile)
        let sig = signForProfile(profile, deviceId: deviceId, ts: ts)
        let resp = httpGet(apiBase + OttaiConstants.epApiToken, ["signature": sig], headers(ts: ts, apiBase: apiBase, authorizationOverride: authorizationOverride, profileOverride: profile))
        return str(resp, "data").nilIfEmpty
    }

    static func requestSmsCode(phone: String, phoneCode: String = "86") -> String? {
        let profile = OttaiRegistry.SessionProfile.cnPhone
        guard let apiToken = getApiToken(apiBase: OttaiConstants.apiBase, authorizationOverride: "", profileOverride: profile) else {
            lastFailure = CloudFailure(text: "apiToken failed"); return nil
        }
        let ts = now()
        let deviceId = requestDeviceId(profile)
        let ph = normalizePhone(phone)
        let body: [String: Any] = [
            "phoneCode": phoneCode, "phone": ph, "apiToken": apiToken, "smsType": 1,
            "signature": signForProfile(profile, deviceId: deviceId, ts: ts, ph, apiToken),
        ]
        let resp = httpPostJson(OttaiConstants.apiBase + OttaiConstants.epSmsCode, json(body), headers(ts: ts, apiBase: OttaiConstants.apiBase, authorizationOverride: "", profileOverride: profile))
        return str(resp, "data").nilIfEmpty
    }

    static func smsLogin(phone: String, code: String, requestId: String, phoneCode: String = "86") -> LoginResult? {
        let profile = OttaiRegistry.SessionProfile.cnPhone
        let ts = now()
        let deviceId = requestDeviceId(profile)
        let ph = normalizePhone(phone)
        let body: [String: Any] = [
            "phoneCode": phoneCode, "phone": ph, "validCode": code, "requestId": requestId,
            "signature": signForProfile(profile, deviceId: deviceId, ts: ts, requestId, ph, code),
        ]
        guard let resp = httpPostJson(OttaiConstants.apiBase + OttaiConstants.epSmsLogin, json(body), headers(ts: ts, apiBase: OttaiConstants.apiBase, authorizationOverride: "", profileOverride: profile)),
              let data = dataObject(resp) else { return nil }
        let result = LoginResult(userId: str(data, "userId"), accessToken: str(data, "accessToken"), glucoseSecretKey: str(data, "glucoseSecretKey"))
        if result.ok {
            OttaiRegistry.saveApiBase(OttaiConstants.apiBase)
            OttaiRegistry.saveSessionProfile(profile)
            OttaiRegistry.saveAccessToken(result.accessToken)
            OttaiRegistry.saveGlucoseSecretKey(result.glucoseSecretKey)
            OttaiRegistry.saveUserId(result.userId)
        }
        return result
    }

    /// Login with user name and password for Global / Syai (no SMS). Only one try.
    static func passwordLogin(account: String, password: String, base baseUrl: String = OttaiConstants.apiBaseGlobal, authorizationOverride: String? = nil) -> LoginResult? {
        let acct = account.trimmingCharacters(in: .whitespaces)
        if acct.isEmpty || password.isEmpty { lastFailure = CloudFailure(text: "account/password required"); return nil }
        guard let apiToken = getApiToken(apiBase: baseUrl, authorizationOverride: authorizationOverride) else {
            lastFailure = CloudFailure(text: "apiToken failed"); return nil
        }
        let ts = now()
        let deviceId = requestDeviceId(.watch)
        let body: [String: Any] = [
            "account": acct, "username": acct, "userName": acct, "password": password, "apiToken": apiToken,
            "signature": signForProfile(.watch, deviceId: deviceId, ts: ts, apiToken, acct, password),
        ]
        guard let resp = httpPostJson(baseUrl + OttaiConstants.epAccountLogin, json(body), headers(ts: ts, apiBase: baseUrl, authorizationOverride: authorizationOverride)),
              let data = dataObject(resp) else { return nil }
        let result = LoginResult(userId: str(data, "userId"), accessToken: str(data, "accessToken"), glucoseSecretKey: str(data, "glucoseSecretKey"))
        if result.ok {
            OttaiRegistry.saveApiBase(baseUrl)
            OttaiRegistry.saveSessionProfile(.watch)
            OttaiRegistry.saveAccessToken(result.accessToken)
            OttaiRegistry.saveGlucoseSecretKey(result.glucoseSecretKey)
            OttaiRegistry.saveUserId(result.userId)
            return result
        }
        return nil
    }

    static func logout() {
        let ts = now()
        _ = httpPostJson(base() + OttaiConstants.epLogout, "{}", headers(ts: ts, apiBase: base()))
        OttaiRegistry.saveAccessToken(nil)
        OttaiRegistry.saveGlucoseSecretKey(nil)
        OttaiRegistry.saveUserId(nil)
        OttaiRegistry.saveAccountLogin(nil)
        OttaiRegistry.saveSessionProfile(nil)
        OttaiRegistry.saveApiBase(OttaiConstants.apiBase)
        OttaiRegistry.saveCloudUploadStatus(nil)
    }

    /// The account profile (`/user/getUser`) of the signed-in session, or nil.
    /// Used to find the customerId for the upload. Do not call this on the main thread.
    static func fetchUserProfile() -> [String: Any]? {
        let token = OttaiRegistry.loadAccessToken()
        if token.isEmpty { return nil }
        return mobileGetUser(base(), accessToken: token)
    }

    // MARK: - device validate / bind

    static func validateByMac(mac: String) -> DeviceResp? {
        guard let v = validateForSetup(mac: mac), !v.device.keyA.isEmpty else { return nil }
        return v.device
    }

    static func validateForSetup(mac: String) -> DeviceValidation? {
        let canonical = OttaiConstants.canonicalSensorId(mac)
        if canonical.isEmpty { return nil }
        let apiBase = base()
        let ts = now()
        let profile = activeProfile(apiBase)
        let deviceId = requestDeviceId(profile)
        let resp = httpGet(apiBase + OttaiConstants.epValidateByMac,
                           ["mac": canonical, "signature": signForProfile(profile, deviceId: deviceId, ts: ts, canonical)],
                           headers(ts: ts, apiBase: apiBase, profileOverride: profile))
        if let resp = resp, let device = parseDeviceResp(resp) {
            return DeviceValidation(device: device, requiresV3Bind: false)
        }
        if apiBase != OttaiConstants.apiBase || profile != .cnPhone ||
            !(lastFailure?.code.caseInsensitiveEquals(bizUpgradeVersion) ?? false) {
            return nil
        }
        let v3Ts = now()
        let body: [String: Any] = ["mac": canonical, "signature": signForProfile(profile, deviceId: deviceId, ts: v3Ts, canonical)]
        guard let v3 = httpPostJson(apiBase + OttaiConstants.epValidateByMacV3, json(body), headers(ts: v3Ts, apiBase: apiBase, profileOverride: profile)),
              let device = parseDeviceResp(v3, requireKeyA: false) else { return nil }
        OttaiRegistry.saveLastValidatedDeviceVersion(sensorId: canonical, version: device.deviceVersion)
        return DeviceValidation(device: device, requiresV3Bind: true)
    }

    enum BindContract { case legacy, v3 }

    static func bindRequestBody(mac: String, deviceVersion: String, userId: String?, activeTime: Int64, contract: BindContract) -> [String: Any] {
        var body: [String: Any] = ["mac": mac, "deviceType": "cgm", "deviceVersion": deviceVersion, "activeTime": activeTime]
        if let userId = userId, !userId.isEmpty { body["userId"] = userId }
        if contract == .v3 { body["newBindType"] = 2 }
        return body
    }

    static func bind(mac: String, deviceVersion: String, userId: String) -> DeviceResp? {
        bind(mac: mac, deviceVersion: deviceVersion, userId: userId, contract: .legacy)
    }

    static func bindV3(mac: String, deviceVersion: String) -> DeviceResp? {
        bind(mac: mac, deviceVersion: deviceVersion, userId: OttaiRegistry.loadUserId(), contract: .v3)
    }

    private static func bind(mac: String, deviceVersion: String, userId: String?, contract: BindContract) -> DeviceResp? {
        let canonical = OttaiConstants.canonicalSensorId(mac)
        if canonical.isEmpty || deviceVersion.isEmpty { lastFailure = CloudFailure(text: "bind requires mac and deviceVersion"); return nil }
        if contract == .v3 && (userId?.isEmpty ?? true) { lastFailure = CloudFailure(text: "bindV3 requires a signed-in session (userId)"); return nil }
        let ts = now()
        let body = bindRequestBody(mac: canonical, deviceVersion: deviceVersion.trimmingCharacters(in: .whitespaces), userId: userId,
                                   activeTime: contract == .v3 ? ts / 1000 : ts, contract: contract)
        let endpoint = contract == .v3 ? OttaiConstants.epBindV3 : OttaiConstants.epBind
        guard let resp = httpPostJson(base() + endpoint, json(body), headers(ts: ts, apiBase: base())) else { return nil }
        return parseDeviceResp(resp)
    }

    static let syaiMaterialBindDeviceVersion = "E1.1.4(V1.7.S2530.1)"
    static let globalMaterialBindDeviceVersion = "vE1.2.3(V1.7.SH2542.1)"

    static func materialBindDeviceVersion(apiBase: String, selectedDeviceVersion: String?, failureCode: String?) -> String? {
        if let sel = selectedDeviceVersion?.trimmingCharacters(in: .whitespaces), !sel.isEmpty { return sel }
        if !(failureCode?.caseInsensitiveEquals(bizOutOfProduceTime) ?? false) { return nil }
        switch apiBase {
        case OttaiConstants.apiBaseSyai: return syaiMaterialBindDeviceVersion
        case OttaiConstants.apiBaseGlobal: return globalMaterialBindDeviceVersion
        default: return nil
        }
    }

    static func materialBindDeviceVersion(selectedDeviceVersion: String?, failureCode: String?) -> String? {
        materialBindDeviceVersion(apiBase: base(), selectedDeviceVersion: selectedDeviceVersion, failureCode: failureCode)
    }

    static func bindForMaterials(mac: String, deviceVersion: String, historicalActiveTimeMs: Int64 = 0) -> DeviceResp? {
        let canonical = OttaiConstants.canonicalSensorId(mac)
        let userId = OttaiRegistry.loadUserId()
        guard let resp = bind(mac: canonical, deviceVersion: deviceVersion.trimmingCharacters(in: .whitespaces), userId: userId, contract: .legacy) else { return nil }
        let bindFailure = lastFailure
        usleep(temporaryUnbindDelayMs * 1000)
        _ = unbind(mac: canonical, headerOverride: nil)
        lastFailure = bindFailure
        return sanitizeTemporaryBindResponse(resp, historicalActiveTimeMs: historicalActiveTimeMs)
    }

    static func sanitizeTemporaryBindResponse(_ response: DeviceResp, historicalActiveTimeMs: Int64) -> DeviceResp {
        var r = response
        r.activeTime = historicalActiveTimeMs > 0 ? historicalActiveTimeMs : 0
        return r
    }

    // MARK: - cgmAuth (V3 Active_Auth)

    static func cgmAuthVerify(mac: String, authDevHex: String, authFlagHex: String) -> V3AuthMaterial? {
        let canonical = OttaiConstants.canonicalSensorId(mac)
        if canonical.isEmpty { lastFailure = CloudFailure(text: "verify requires mac"); return nil }
        let apiBase = base()
        let profile = activeProfile(apiBase)
        let deviceId = requestDeviceId(profile)
        let ts = now()
        let paramStr = authDevHex.uppercased()
        let shaInfo = authFlagHex.uppercased()
        let sign = cgmAuthVerifySign(profile, deviceId: deviceId, timestampMillis: ts, mac: canonical, paramStr: paramStr, shaInfo: shaInfo)
        let body: [String: Any] = ["mac": canonical, "paramStr": paramStr, "shaInfo": shaInfo, "sign": sign, "timestamp": String(ts)]
        guard let resp = httpPostJson(apiBase + OttaiConstants.epCgmAuthVerify, json(body), headers(ts: ts, apiBase: apiBase, profileOverride: profile), timeoutMs: 60_000) else { return nil }
        let data = dataObject(resp)
        let mat = V3AuthMaterial(authHost: str(data, "auth"), authFlag: str(data, "shaInfo"), keyB: str(data, "kb"), cf: str(data, "cf"))
        return mat.ok ? mat : nil
    }

    // MARK: - unbind / list

    static func unbind(mac: String) -> Bool { unbind(mac: mac, headerOverride: nil) }

    private static func unbind(mac: String, headerOverride: ((Int64) -> [String: String])?) -> Bool {
        let canonical = OttaiConstants.canonicalSensorId(mac)
        if canonical.isEmpty { return false }
        let ts = now()
        let body: [String: Any] = ["mac": canonical, "deviceType": "cgm", "unbindType": 0]
        let requestHeaders = headerOverride?(ts) ?? headers(ts: ts, apiBase: base())
        guard let resp = httpPutJson(base() + OttaiConstants.epUnbind, json(body), requestHeaders) else { return false }
        let bizCode = anyToString(resp["code"])
        return bizCode.isEmpty || bizCode == "200" || bizCode.caseInsensitiveEquals("OK") || bizCode.caseInsensitiveEquals(bizEndUsing)
    }

    static func getBindDevice() -> DeviceResp? {
        let ts = now()
        guard let resp = httpGet(base() + OttaiConstants.epGetBindDevice, [:], headers(ts: ts, apiBase: base())) else { return nil }
        return parseDeviceResp(resp)
    }

    static func listDevices(pageSize: Int = 80, pageNumber: Int = 1) -> [DeviceSummary] {
        let ts = now()
        guard let resp = httpGet(base() + OttaiConstants.epDeviceList,
                                 ["pageSize": String(pageSize), "pageNumber": String(pageNumber)],
                                 headers(ts: ts, apiBase: base())),
              let data = dataObject(resp) else { return [] }
        let items = (data["items"] as? [[String: Any]]) ?? (data["list"] as? [[String: Any]]) ?? (data["records"] as? [[String: Any]]) ?? []
        return items.compactMap { o in
            let mac = str(o, "mac")
            if mac.isEmpty { return nil }
            var version = str(o, "deviceVersion")
            if version.isEmpty { version = str(o["cgmDeviceRespVO"] as? [String: Any], "deviceVersion") }
            return DeviceSummary(mac: mac, serialNo: str(o, "serialNo"), deviceType: str(o, "deviceType"),
                                 deviceVersion: version, bindTime: longLoose(o, "bindTime"), unbindTime: longLoose(o, "unbindTime"))
        }
    }

    // MARK: - parse + decrypt

    private static func parseDeviceResp(_ resp: [String: Any], requireKeyA: Bool = true) -> DeviceResp? {
        guard let data = dataObject(resp) else { return nil }
        let vo = (data["cgmDeviceRespVO"] as? [String: Any]) ?? data
        let mvo = (data["cgmDeviceMethodVO"] as? [String: Any]) ?? vo
        let keyA = str(vo, "keyA")
        if requireKeyA && keyA.isEmpty { return nil }
        func pick(_ key: String) -> String { let m = str(mvo, key); return m.isEmpty ? str(vo, key) : m }
        func pickTime(_ key: String) -> Int64 { let m = longLoose(mvo, key); return m != 0 ? m : longLoose(vo, key) }
        return DeviceResp(
            mac: str(vo, "mac"), keyA: keyA, method: pick("method"), coefficient: pick("coefficient"),
            produceTime: longLoose(vo, "produceTime"), methodUpdateTime: pickTime("methodUpdateTime"), coeffUpdateTime: pickTime("coeffUpdateTime"),
            activeTime: longLoose(vo, "activeTime"), activeExpireTime: longLoose(vo, "activeExpireTime"),
            preheatPeriodTime: longLoose(vo, "preheatPeriodTime"), retainTime: longLoose(vo, "retainTime"),
            deviceVersion: str(vo, "deviceVersion"), deviceId: Int(longLoose(vo, "id"))
        )
    }

    /// Decrypt the sensor keys from the cloud answer with the account secret key.
    static func toMaterials(mac: String, resp: DeviceResp) -> OttaiRegistry.DeviceMaterials? {
        let secret = OttaiRegistry.loadGlucoseSecretKey()
        if secret.isEmpty { return nil }
        let canonical = OttaiConstants.canonicalSensorId(mac)
        guard let keyAPlain = OttaiCrypto.decryptKeyA(base64KeyA: resp.keyA, glucoseSecretKey: secret, produceTime: String(resp.produceTime), mac: canonical) else { return nil }
        if OttaiCrypto.parseAuthKeys(keyAPlain) == nil { return nil }
        let methodPlain = resp.method.isEmpty ? "" : (OttaiCrypto.decryptMethod(base64Method: resp.method, glucoseSecretKey: secret, methodUpdateTime: String(resp.methodUpdateTime), mac: canonical) ?? "")
        let coeffPlain = resp.coefficient.isEmpty ? "" : (OttaiCrypto.decryptCoefficient(base64Coeff: resp.coefficient, glucoseSecretKey: secret, coeffUpdateTime: String(resp.coeffUpdateTime), mac: canonical) ?? "")
        return OttaiRegistry.DeviceMaterials(
            keyAHex: keyAPlain,
            method: OttaiMethodDefaults.resolve(method: methodPlain, coefficient: coeffPlain),
            coefficient: coeffPlain,
            activeTimeMs: normalizeOttaiActiveTimeMs(resp.activeTime),
            deviceVersion: resp.deviceVersion,
            deviceId: resp.deviceId,
            activeExpireTimeMs: resp.activeExpireTime,
            retainTimeMs: resp.retainTime,
            preheatPeriodMs: resp.preheatPeriodTime
        )
    }

    // MARK: - get and save the keys of one sensor (same as fetchOttaiMaterials in JugglucoNG)

    /// After login, get the keys for [cloudId] and save them, so the Bluetooth part
    /// can log in. It tries, in this order: keys already saved -> check by mac ->
    /// the sensor bound to the account -> a short bind and unbind (for an old
    /// Syai / Global sensor). Returns true if good keys were saved. Do not call
    /// this on the main thread.
    static func fetchAndSaveMaterials(cloudId: String) -> Bool {
        let canonical = OttaiConstants.canonicalSensorId(cloudId)
        if canonical.isEmpty { return false }
        if OttaiRegistry.loadMaterials(sensorId: canonical).authKeys != nil { return true }

        var firstFailure: CloudFailure?
        func remember() { if firstFailure == nil { firstFailure = lastFailure } }

        if let v = validateForSetup(mac: canonical), !v.device.keyA.isEmpty,
           let m = toMaterials(mac: canonical, resp: v.device), m.authKeys != nil {
            return OttaiRegistry.saveMaterials(sensorId: canonical, m)
        }
        remember()

        if let resp = getBindDevice(),
           OttaiConstants.matchesCanonicalOrKnownNativeAlias(OttaiConstants.canonicalSensorId(resp.mac), canonical),
           let m = toMaterials(mac: OttaiConstants.canonicalSensorId(resp.mac), resp: resp), m.authKeys != nil {
            return OttaiRegistry.saveMaterials(sensorId: canonical, m)
        }
        remember()

        if let version = materialBindDeviceVersion(selectedDeviceVersion: nil, failureCode: firstFailure?.code),
           let resp = bindForMaterials(mac: canonical, deviceVersion: version),
           let m = toMaterials(mac: canonical, resp: resp), m.authKeys != nil {
            return OttaiRegistry.saveMaterials(sensorId: canonical, m)
        }
        if lastFailure == nil { lastFailure = firstFailure }
        return false
    }

    // MARK: - website API (email login and sign-up)

    private static let webApp = "ottai-seas"
    private static let webDeviceId = "8"
    private static let webAesKey = "miH5ngQ7z4NZU3JgZFq87Gg6v1Y7YJm9"
    private static let webFingerprint = "0123456789abcdef0123456789abcdef01234567"
    private static let webAppSyai = "cgm"
    private static let webFingerprintSyai = "90507337afdab98e443d3ec8fcccb672"

    private static func isSyaiWeb(_ webBase: String) -> Bool { webBase.contains("syai") }
    private static func webAppFor(_ webBase: String) -> String { isSyaiWeb(webBase) ? webAppSyai : webApp }
    private static func webSign(_ parts: String...) -> String { md5Hex(parts.joined() + seed) }

    private static func webHeaders(_ webBase: String, ts: Int64) -> [String: String] {
        if isSyaiWeb(webBase) {
            return ["appName": webAppSyai, "timestamp": String(ts), "deviceFingerprinting": webFingerprintSyai,
                    "country": "US", "region": "Americas", "ua": "Android", "versionCode": "5",
                    "traceId": "trace_\(ts)", "language": "en", "timezone": "-18000"]
        }
        return ["appName": webApp, "timestamp": String(ts), "deviceId": webDeviceId, "deviceFingerprinting": webFingerprint,
                "region": "Europe", "ua": "web", "versionCode": "253201", "traceId": "trace_\(ts)",
                "language": "en", "timezone": "0", "X-Canary-Mode": "OFF", "country": "RU"]
    }

    private static func webEncrypt(_ plainJson: String) -> String {
        guard let out = OttaiCrypto.aesECB(.encrypt, key: Array(webAesKey.utf8), data: Array(plainJson.utf8), pkcs7Padded: true) else { return "" }
        return Data(out).base64EncodedString()
    }

    private static func getWebApiToken(_ webBase: String) -> String? {
        for attempt in 0 ..< 2 {
            let ts = now()
            let resp = httpGet("\(webBase)/user/apiToken", ["signature": webSign(webAppFor(webBase), String(ts))], webHeaders(webBase, ts: ts))
            if let tok = str(resp, "data").nilIfEmpty { return tok }
            if attempt == 0 { usleep(900_000) }
        }
        return nil
    }

    private static func webPostRetry(_ webBase: String, _ path: String, buildBody: (_ apiToken: String, _ ts: Int64) -> [String: Any]) -> [String: Any]? {
        for attempt in 0 ..< 5 {
            guard let apiToken = getWebApiToken(webBase) else { lastFailure = CloudFailure(text: "apiToken failed"); return nil }
            let ts = now()
            guard let resp = httpPostJson("\(webBase)\(path)", json(buildBody(apiToken, ts)), webHeaders(webBase, ts: ts)) else { return nil }
            if !anyToString(resp["code"]).caseInsensitiveEquals("User_SignatureInvalid") { return resp }
            if attempt < 4 { usleep(500_000) }
        }
        return nil
    }

    static func mailLogin(email: String, password: String, webBase: String = OttaiConstants.webBaseOttai) -> LoginResult? {
        let em = email.trimmingCharacters(in: .whitespaces)
        if em.isEmpty || password.isEmpty { lastFailure = CloudFailure(text: "email/password required"); return nil }
        let resp: [String: Any]?
        if isSyaiWeb(webBase) {
            let encInfo = webEncrypt(json(["email": em, "password": password]))
            resp = webPostRetry(webBase, "/user/mail/login") { apiToken, ts in
                ["encryptInfo": encInfo, "email": em, "apiToken": apiToken, "signature": webSign(webAppSyai, String(ts), apiToken, em, password)]
            }
        } else {
            let encInfo = webEncrypt(json(["username": em, "password": password]))
            resp = webPostRetry(webBase, "/user/login/thirdLoginByPassword") { apiToken, ts in
                ["uuid": UUID().uuidString.replacingOccurrences(of: "-", with: ""), "encryptInfo": encInfo, "apiToken": apiToken, "source": 5,
                 "signature": webSign(webApp, webDeviceId, String(ts), apiToken, em, password)]
            }
        }
        guard let resp = resp else { return nil }
        let mobileBase = webBaseToMobile(webBase)
        let webToken = str(dataObject(resp), "accessToken")
        if !webToken.isEmpty {
            let profile = isSyaiWeb(webBase) ? mobileGetUser(mobileBase, accessToken: webToken) : webGetUser(webBase, accessToken: webToken)
            if let userName = str(profile, "userName").nilIfEmpty {
                if let r = passwordLogin(account: userName, password: password, base: mobileBase, authorizationOverride: webToken), r.ok { return r }
            }
        }
        if isSyaiWeb(webBase) {
            if lastError.isEmpty { lastFailure = CloudFailure(text: "Syai mobile login upgrade failed") }
            return nil
        }
        return persistWebLogin(resp, mobileBase: mobileBase, webBase: webBase)
    }

    static func sendMail(email: String, type: String = "SIGN_UP", webBase: String = OttaiConstants.webBaseOttai) -> String? {
        let em = email.trimmingCharacters(in: .whitespaces)
        guard let resp = webPostRetry(webBase, "/user/mail/sendMail", buildBody: { apiToken, ts in
            ["type": type, "isSend": 1, "email": em, "apiToken": apiToken, "signature": webSign(webAppFor(webBase), String(ts), em, apiToken)]
        }) else { return nil }
        if !anyToString(resp["code"]).caseInsensitiveEquals("OK") { return nil }
        return str(dataObject(resp), "key").nilIfEmpty
    }

    static func signUp(email: String, password: String, profileName: String, requestId: String, validCode: String, webBase: String = OttaiConstants.webBaseOttai) -> LoginResult? {
        let em = email.trimmingCharacters(in: .whitespaces)
        if isSyaiWeb(webBase) { return syaiSignUp(em: em, password: password, requestId: requestId, validCode: validCode, webBase: webBase) }
        let encInfo = webEncrypt(json(["email": em, "password": password, "profileName": profileName]))
        guard let resp = webPostRetry(webBase, "/user/mail/signUp", buildBody: { apiToken, ts in
            ["apiToken": apiToken, "encryptInfo": encInfo, "requestId": requestId, "validCode": validCode,
             "recommendFlag": false, "country": "RU", "language": "en", "signature": webSign(webApp, String(ts), requestId, em, validCode)]
        }) else { return nil }
        return persistWebLogin(resp, mobileBase: webBaseToMobile(webBase), webBase: webBase)
    }

    private static func syaiSignUp(em: String, password: String, requestId: String, validCode: String, webBase: String) -> LoginResult? {
        guard let verify = webPostRetry(webBase, "/user/mail/verifyMail", buildBody: { _, ts in
            ["type": "SIGN_UP", "validCode": validCode, "requestId": requestId, "email": em, "signature": webSign(webAppSyai, String(ts), requestId, em, validCode)]
        }), anyToString(verify["code"]).caseInsensitiveEquals("OK") else { return nil }
        let encInfo = webEncrypt(json(["email": em, "password": password]))
        guard let resp = webPostRetry(webBase, "/user/mail/signUp", buildBody: { _, ts in
            ["encryptInfo": encInfo, "requestId": requestId, "signature": webSign(webAppSyai, String(ts), requestId, em)]
        }) else { return nil }
        return persistWebLogin(resp, mobileBase: webBaseToMobile(webBase), webBase: webBase)
    }

    static func webBaseToMobile(_ webBase: String) -> String {
        webBase.contains("syai") ? OttaiConstants.apiBaseSyai : OttaiConstants.apiBaseGlobal
    }

    private static func persistWebLogin(_ resp: [String: Any], mobileBase: String, webBase: String) -> LoginResult? {
        guard let data = dataObject(resp) else { return nil }
        let accessToken = str(data, "accessToken")
        var glucoseSecretKey = str(data, "glucoseSecretKey")
        if !accessToken.isEmpty && glucoseSecretKey.isEmpty {
            glucoseSecretKey = str(webGetUser(webBase, accessToken: accessToken), "glucoseSecretKey")
        }
        let result = LoginResult(userId: str(data, "userId"), accessToken: accessToken, glucoseSecretKey: glucoseSecretKey)
        if !result.accessToken.isEmpty {
            OttaiRegistry.saveApiBase(mobileBase)
            OttaiRegistry.saveSessionProfile(.watch)
            OttaiRegistry.saveAccessToken(result.accessToken)
            if !result.glucoseSecretKey.isEmpty { OttaiRegistry.saveGlucoseSecretKey(result.glucoseSecretKey) }
            OttaiRegistry.saveUserId(result.userId)
        }
        return result
    }

    private static func webGetUser(_ webBase: String, accessToken: String) -> [String: Any]? {
        let ts = now()
        var headers = webHeaders(webBase, ts: ts)
        if isSyaiWeb(webBase) { headers["deviceId"] = webDeviceId }
        headers["Authorization"] = "Bearer \(accessToken)"
        guard let resp = httpGet("\(webBase)/user/getUser", [:], headers) else { return nil }
        return dataObject(resp)
    }

    private static func mobileGetUser(_ mobileBase: String, accessToken: String) -> [String: Any]? {
        let ts = now()
        guard let resp = httpGet(mobileBase + OttaiConstants.epGetUser, [:], headers(ts: ts, apiBase: mobileBase, authorizationOverride: accessToken)) else { return nil }
        return dataObject(resp)
    }

    // MARK: - HTTP

    private static func httpGet(_ base: String, _ query: [String: String], _ headers: [String: String]) -> [String: Any]? {
        let qs = query.map { "\(enc($0.key))=\(enc($0.value))" }.joined(separator: "&")
        let url = qs.isEmpty ? base : "\(base)?\(qs)"
        return request("GET", url: url, body: nil, headers: headers)
    }

    private static func httpPostJson(_ url: String, _ body: String, _ headers: [String: String], timeoutMs: Int = timeoutMs) -> [String: Any]? {
        var h = headers; h["Content-Type"] = "application/json;charset=UTF-8"
        return request("POST", url: url, body: body, headers: h, timeoutMs: timeoutMs)
    }

    private static func httpPutJson(_ url: String, _ body: String, _ headers: [String: String]) -> [String: Any]? {
        var h = headers; h["Content-Type"] = "application/json;charset=UTF-8"
        return request("PUT", url: url, body: body, headers: h)
    }

    private static func request(_ method: String, url: String, body: String?, headers: [String: String], timeoutMs: Int = timeoutMs) -> [String: Any]? {
        guard let u = URL(string: url) else { lastFailure = CloudFailure(text: "bad url"); return nil }
        var req = URLRequest(url: u)
        req.httpMethod = method
        req.timeoutInterval = TimeInterval(timeoutMs) / 1000.0
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let body = body { req.httpBody = body.data(using: .utf8) }

        let sem = DispatchSemaphore(value: 0)
        var outData: Data?
        var outCode = -1
        var outErr: Error?
        URLSession.shared.dataTask(with: req) { data, response, error in
            outData = data
            outErr = error
            if let http = response as? HTTPURLResponse { outCode = http.statusCode }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + .milliseconds(timeoutMs + 5_000))

        if let error = outErr { lastFailure = CloudFailure(text: "network: \(error.localizedDescription)"); return nil }
        let text = outData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let jsonObj = text.isEmpty ? nil : (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
        let bizCode = anyToString(jsonObj?["code"])
        let bizMsg = anyToString(jsonObj?["message"]).nilIfEmpty ?? anyToString(jsonObj?["msg"]).nilIfEmpty ?? anyToString(jsonObj?["detailMessage"])
        let bizOk = bizCode.isEmpty || bizCode == "200" || bizCode.caseInsensitiveEquals("OK")
        if !(200 ... 299).contains(outCode) || !bizOk {
            lastFailure = CloudFailure(text: "http=\(outCode) biz=\(bizCode) \(String(bizMsg.prefix(120)))".trimmingCharacters(in: .whitespaces), code: bizCode)
        } else {
            lastFailure = nil
        }
        return jsonObj
    }

    // MARK: - JSON helpers

    private static func json(_ obj: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func dataObject(_ resp: [String: Any]?) -> [String: Any]? {
        (resp?["data"] as? [String: Any]) ?? (resp?["result"] as? [String: Any])
    }

    private static func str(_ dict: [String: Any]?, _ key: String) -> String {
        anyToString(dict?[key])
    }

    private static func longLoose(_ dict: [String: Any]?, _ key: String) -> Int64 {
        guard let v = dict?[key] else { return 0 }
        if let n = v as? NSNumber { return n.int64Value }
        if let s = v as? String { return Int64(s) ?? 0 }
        return 0
    }

    private static func anyToString(_ any: Any?) -> String {
        guard let any = any else { return "" }
        if let s = any as? String { return s == "null" ? "" : s }
        if let n = any as? NSNumber { return n.stringValue }
        return ""
    }

    private static func enc(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? s
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
    func caseInsensitiveEquals(_ other: String) -> Bool { caseInsensitiveCompare(other) == .orderedSame }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=?+")
        return cs
    }()
}
