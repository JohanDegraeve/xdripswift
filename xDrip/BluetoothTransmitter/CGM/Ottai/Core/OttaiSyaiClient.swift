//
//  OttaiSyaiClient.swift
//  xdrip
//
//  Ottai / Syai CGM driver — talks to api.syai.com like the Syai Tag iOS app,
//  ported from SyaiKit (SyaiSecureChannel, SyaiEnvelopedClient, login). Every
//  call is sealed with AES-GCM under a key from /security/exchangeKey, and the
//  account signs in as "Syai Tag" with a JWT pair (access + refresh token).
//  The calls wait for the answer: never call them on the main thread.
//

import CryptoKit
import Foundation
import Security

enum OttaiSyaiClient {

    private static let base = OttaiConstants.apiBaseSyai
    private static let appServerPrefix = "/cgm/security/app/server"
    private static let uploadPath = "/cgm/security/data/collect/collect/glucose/v2"
    private static let signKey = "dy7234hbnrnfh7q89eru8ybfn899"
    private static let loginAesKey = "miH5ngQ7z4NZU3JgZFq87Gg6v1Y7YJm9"
    private static let fallbackAppName = "Syai Tag"
    private static let packageName = "com.syai.tag"
    private static let versionName = "1.35.0"
    private static let versionCode = "263931"
    private static let productModel = "X1"
    private static let timeout: TimeInterval = 30
    private static let loginElsewhere = "AuthFailed_LoginElsewhere"

    // MARK: - identity (from the JWT, like SyaiKit)

    static var appName: String { claim("app_name") ?? fallbackAppName }
    static var deviceId: String { claim("device_id") ?? OttaiRegistry.loadOrCreateSyaiInstallDeviceId() }
    static var userId: String { claim("sub") ?? OttaiRegistry.loadUserId() }

    private static func claim(_ name: String) -> String? {
        let token = [OttaiRegistry.loadAccessToken(), OttaiRegistry.loadRefreshToken()].first { !$0.isEmpty }
        guard let value = token.flatMap({ jwtPayload($0)?[name] as? String }), !value.isEmpty else { return nil }
        return value
    }

    // MARK: - account

    /// GET user/apiToken, then POST user/mail/login. Saves the session.
    static func login(email: String, password: String) -> OttaiCloudClient.LoginResult? {
        gate.lock(); defer { gate.unlock() }
        clearSession()
        let ts = timestamp()
        guard let tokenResp = call("GET", path: "user/apiToken", body: ["signature": md5(appName + deviceId + ts + signKey)],
                                   headers: ["timestamp": ts], authed: false) else { return nil }
        let apiToken = (tokenResp["data"] as? String) ?? str(tokenResp["data"] as? [String: Any], "apiToken")
        guard !apiToken.isEmpty else { return fail("no apiToken") }

        let loginTs = timestamp()
        let json = "{\"email\":\"\(jsonEscape(email))\",\"password\":\"\(jsonEscape(password))\"}"
        guard let cipher = OttaiCrypto.aesECB(.encrypt, key: Array(loginAesKey.utf8), data: Array(json.utf8), pkcs7Padded: true) else {
            return fail("login encryption failed")
        }
        let body: [String: Any] = [
            "encryptInfo": Data(cipher).base64EncodedString(),
            "apiToken": apiToken,
            "signature": md5(appName + deviceId + loginTs + apiToken + email + password + signKey),
        ]
        guard let resp = call("POST", path: "user/mail/login", body: body, headers: ["timestamp": loginTs], authed: false) else { return nil }
        let data = resp["data"] as? [String: Any]
        let jwt = (data?["jwtToken"] as? [String: Any]) ?? data
        let access = str(jwt, "accessToken")
        let refresh = str(jwt, "refreshToken")
        guard !access.isEmpty, !refresh.isEmpty else { return fail("no tokens in the login answer") }

        OttaiRegistry.saveApiBase(base)
        OttaiRegistry.saveSessionProfile(.watch)
        OttaiRegistry.saveAccessToken(access)
        OttaiRegistry.saveRefreshToken(refresh)
        OttaiRegistry.saveGlucoseSecretKey(str(data, "glucoseSecretKey"))
        OttaiRegistry.saveUserId(str(data, "userId").isEmpty ? userId : str(data, "userId"))
        Keychain.savePassword(password)
        signedInElsewhere = false
        return OttaiCloudClient.LoginResult(userId: OttaiRegistry.loadUserId(), accessToken: access, glucoseSecretKey: str(data, "glucoseSecretKey"))
    }

    static func logout() {
        gate.lock(); defer { gate.unlock() }
        clearSession()
        Keychain.savePassword(nil)
    }

    private static func clearSession() {
        channel = nil
        OttaiRegistry.saveAccessToken(nil)
        OttaiRegistry.saveRefreshToken(nil)
    }

    // MARK: - device calls (answers keep the server shape {code, data})

    static func validateDeviceByMacV3(mac: String) -> [String: Any]? {
        let ts = timestamp()
        return authed("POST", path: "device/validateDeviceByMacV3",
                      body: ["mac": mac, "signature": md5(appName + deviceId + ts + mac + signKey)],
                      headers: ["timestamp": ts], productModel: true)
    }

    static func cgmAuthVerify(mac: String, paramStr: String, shaInfo: String) -> [String: Any]? {
        let ts = timestamp()
        return authed("POST", path: "cgmAuth/verify",
                      body: ["mac": mac, "paramStr": paramStr, "shaInfo": shaInfo,
                             "sign": md5(appName + deviceId + mac + paramStr + shaInfo + ts + signKey)],
                      headers: ["timestamp": ts], productModel: true)
    }

    /// bindV3, with the "binding in progress" mark around it like the app.
    static func bindV3(mac: String, deviceVersion: String, activeTimeMs: Int64) -> [String: Any]? {
        _ = authed("POST", path: "deviceBind/markDeviceStatus", body: ["mac": mac, "state": 1, "duration": 5])
        let resp = authed("POST", path: "deviceBind/composite/bindV3", body: [
            "mac": mac, "deviceType": "cgm", "deviceVersion": deviceVersion,
            "activeTime": activeTimeMs, "newBindType": 1, "deviceInfo": "",
        ])
        let bindFailure = OttaiCloudClient.lastFailure
        _ = authed("POST", path: "deviceBind/markDeviceStatus", body: ["mac": mac, "state": 0, "duration": 5])
        OttaiCloudClient.lastFailure = bindFailure
        return resp
    }

    /// unbindType: 10 = wear time over, 13 = ended early (SyaiUnbindReason).
    static func unbind(mac: String, unbindType: Int) -> [String: Any]? {
        authed("PUT", path: "deviceBind/unBindDevice", body: ["mac": mac, "deviceType": "cgm", "unbindType": unbindType])
    }

    static func getBindDevice() -> [String: Any]? {
        authed("GET", path: "deviceBind/getBindDevice", body: [:])
    }

    /// The sensor's keys and the server device id (data.id), as the app reads them.
    static func authInfo(mac: String) -> [String: Any]? {
        let ts = timestamp()
        return authed("GET", path: "device/authInfo", body: ["mac": mac, "sign": md5(signKey + appName + deviceId + mac + ts + signKey)],
                      headers: ["timestamp": ts], productModel: true)
    }

    static func uploadGlucose(_ body: [String: Any]) -> [String: Any]? {
        authed("POST", path: uploadPath, body: body, absolute: true)
    }

    // MARK: - session (access token refresh, one retry after an auth error)

    /// All calls go one at a time: they share the channel, its seq and the tokens.
    private static let gate = NSRecursiveLock()
    /// The account was signed in somewhere else. No silent new sign-in then: it would only
    /// sign the other app out again. The user signs in by hand.
    private(set) static var signedInElsewhere = false

    private static func authed(_ method: String, path: String, body: [String: Any], headers: [String: String] = [:],
                               productModel: Bool = false, absolute: Bool = false) -> [String: Any]? {
        gate.lock(); defer { gate.unlock() }
        guard !OttaiRegistry.loadRefreshToken().isEmpty else { return fail("not signed in to Syai") }
        if !accessTokenValid(), !renewSession() { return nil }
        let reply = send(method, path: path, body: body, headers: headers, productModel: productModel, authed: true, absolute: absolute)
        if reply.isAuthError, renewSession() {
            return finish(send(method, path: path, body: body, headers: headers, productModel: productModel, authed: true, absolute: absolute))
        }
        return finish(reply)
    }

    private static func call(_ method: String, path: String, body: [String: Any], headers: [String: String], authed: Bool) -> [String: Any]? {
        finish(send(method, path: path, body: body, headers: headers, productModel: false, authed: authed, absolute: false))
    }

    private static func accessTokenValid() -> Bool {
        guard let exp = (jwtPayload(OttaiRegistry.loadAccessToken())?["exp"] as? NSNumber)?.doubleValue else { return false }
        return exp - Date().timeIntervalSince1970 > 60
    }

    /// Refresh the tokens, or sign in again with the saved password.
    private static func renewSession() -> Bool {
        if signedInElsewhere { return false }
        var headers = ["customerId": userId, "refreshToken": OttaiRegistry.loadRefreshToken()]
        if !OttaiRegistry.loadAccessToken().isEmpty { headers["accessToken"] = OttaiRegistry.loadAccessToken() }
        if let resp = finish(send("POST", path: "jwt/refreshToken", body: [:], headers: headers, productModel: false, authed: true, absolute: false)) {
            let data = resp["data"] as? [String: Any]
            let jwt = (data?["jwtToken"] as? [String: Any]) ?? data
            let access = str(jwt, "accessToken")
            if !access.isEmpty {
                OttaiRegistry.saveAccessToken(access)
                if !str(jwt, "refreshToken").isEmpty { OttaiRegistry.saveRefreshToken(str(jwt, "refreshToken")) }
                if !str(data, "glucoseSecretKey").isEmpty { OttaiRegistry.saveGlucoseSecretKey(str(data, "glucoseSecretKey")) }
                return true
            }
        }
        if signedInElsewhere { return false }
        let email = OttaiRegistry.loadAccountLogin()
        guard !email.isEmpty, let password = Keychain.loadPassword() else { return false }
        return login(email: email, password: password) != nil
    }

    // MARK: - secure channel

    private struct Channel {
        let secretId: String
        let deviceId: String
        let gcmKey: SymmetricKey
        let hmacKey: SymmetricKey
        let expireTime: Int64
        var aad: Data { Data("\(deviceId)|\(secretId)".utf8) }
    }

    private static var channel: Channel?
    private static var seq = 0

    /// POST security/exchangeKey: P-256 ECDH, then HKDF-SHA256 gives the GCM and HMAC keys.
    private static func openChannel() -> Channel? {
        if let c = channel, c.deviceId == deviceId, c.expireTime > nowMs() { return c }
        let id = deviceId
        let priv = P256.KeyAgreement.PrivateKey()
        let raw = priv.publicKey.rawRepresentation
        let x = raw.prefix(32).base64EncodedString()
        let y = raw.suffix(32).base64EncodedString()
        let ts = nowMs()
        let body: [String: Any] = [
            "clientPubKeyX": x, "clientPubKeyY": y, "clientTimestamp": ts,
            "clientSignature": SHA256.hash(data: Data((id + x + y + String(ts)).utf8)).map { String(format: "%02x", $0) }.joined(),
        ]
        var req = URLRequest(url: URL(string: base + appServerPrefix + "/security/exchangeKey")!)
        req.httpMethod = "POST"
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        baseHeaders(&req, productModel: false)
        let (data, status, error) = http(req)
        if let error = error { return fail("network: \(error.localizedDescription)") }
        guard (200 ... 299).contains(status),
              let root = data.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) else {
            return fail("secure channel: http=\(status)")
        }
        let server = (root["data"] as? [String: Any]) ?? root
        guard let sx = Data(base64Encoded: str(server, "serverPubKeyX")), let sy = Data(base64Encoded: str(server, "serverPubKeyY")),
              let serverKey = try? P256.KeyAgreement.PublicKey(rawRepresentation: sx + sy),
              let shared = try? priv.sharedSecretFromKeyAgreement(with: serverKey) else {
            return fail("secure channel: bad server key")
        }
        let secretId = str(server, "secretId").isEmpty ? str(server, "cipherSecretId") : str(server, "secretId")
        guard !secretId.isEmpty else { return fail("secure channel: no secretId") }
        let expire = int64(server["expireTime"]) ?? int64(server["expiresAt"]) ?? 0
        let okm = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: shared.withUnsafeBytes { Data($0) }),
            salt: Data(secretId.utf8),
            info: Data("\(id)#\(expire)#\(secretId)".utf8),
            outputByteCount: 64
        ).withUnsafeBytes { Data($0) }
        let c = Channel(secretId: secretId, deviceId: id, gcmKey: SymmetricKey(data: okm.prefix(32)),
                        hmacKey: SymmetricKey(data: okm.suffix(32)), expireTime: expire)
        channel = c
        seq = 0
        return c
    }

    private struct Reply {
        let status: Int
        let json: [String: Any]?
        let error: String?
        var code: String { anyToString(json?["code"]) }
        var isAuthError: Bool { (status == 401 || status == 403) && code != loginElsewhere }
    }

    /// Seals the body: GET puts cipherParam* in the query, POST/PUT cipherBody* in the body.
    private static func send(_ method: String, path: String, body: [String: Any], headers: [String: String],
                             productModel: Bool, authed: Bool, absolute: Bool) -> Reply {
        guard let c = openChannel() else { return Reply(status: -1, json: nil, error: OttaiCloudClient.lastError) }
        guard let plain = try? JSONSerialization.data(withJSONObject: body),
              let sealed = try? AES.GCM.seal(plain, using: c.gcmKey, nonce: AES.GCM.Nonce(), authenticating: c.aad) else {
            return Reply(status: -1, json: nil, error: "secure channel: seal failed")
        }
        let text = sealed.ciphertext.base64EncodedString()
        let mac = sealed.tag.base64EncodedString()
        let nonce = Data(sealed.nonce).base64EncodedString()
        let mySeq = seq
        seq += 1
        let nonceId = String((nowMs() << 12) | Int64.random(in: 0 ..< 0x1000))
        let timeNow = nowMs()
        let signature = Data(HMAC<SHA256>.authenticationCode(for: Data("\(nonceId)\(mySeq)\(timeNow)\(text)".utf8), using: c.hmacKey)).base64EncodedString()

        let urlString = base + (absolute ? path : appServerPrefix + "/" + path)
        var req: URLRequest
        if method == "GET" {
            func q(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s }
            req = URLRequest(url: URL(string: urlString + "?cipherParamText=\(q(text))&cipherParamMac=\(q(mac))&cipherParamNonce=\(q(nonce))&cipherParamSignature=\(q(signature))")!)
        } else {
            req = URLRequest(url: URL(string: urlString)!)
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "cipherBodyText": text, "cipherBodyMac": mac, "cipherBodyNonce": nonce, "cipherBodySignature": signature,
            ])
            req.setValue("application/json", forHTTPHeaderField: "content-type")
        }
        req.httpMethod = method
        req.setValue(c.secretId, forHTTPHeaderField: "cipherSecretId")
        req.setValue(String(mySeq), forHTTPHeaderField: "cipherSeq")
        req.setValue(nonceId, forHTTPHeaderField: "cipherNonceId")
        req.setValue(String(timeNow), forHTTPHeaderField: "cipherTimeNow")
        req.setValue(c.deviceId, forHTTPHeaderField: "cipherUserId")
        baseHeaders(&req, productModel: productModel)
        let token = OttaiRegistry.loadAccessToken()
        if authed, !token.isEmpty {
            req.setValue(token, forHTTPHeaderField: "Authorization")
            req.setValue(userId, forHTTPHeaderField: "customerId")
        }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        let (data, status, error) = http(req)
        if let error = error { return Reply(status: status, json: nil, error: "network: \(error.localizedDescription)") }
        guard let data = data, let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return Reply(status: status, json: nil, error: nil)
        }
        let cText = (root["cipherText"] ?? root["cipherParamText"] ?? root["cipherBodyText"]) as? String
        let cMac = (root["cipherMac"] ?? root["cipherParamMac"] ?? root["cipherBodyMac"]) as? String
        let cNonce = (root["cipherNonce"] ?? root["cipherParamNonce"] ?? root["cipherBodyNonce"]) as? String
        guard let cText = cText, let cMac = cMac, let cNonce = cNonce else { return Reply(status: status, json: root, error: nil) }
        guard let ct = Data(base64Encoded: cText), let tag = Data(base64Encoded: cMac), let nd = Data(base64Encoded: cNonce),
              let n = try? AES.GCM.Nonce(data: nd), let box = try? AES.GCM.SealedBox(nonce: n, ciphertext: ct, tag: tag),
              let opened = try? AES.GCM.open(box, using: c.gcmKey, authenticating: c.aad),
              let json = try? JSONSerialization.jsonObject(with: opened) as? [String: Any] else {
            return Reply(status: status, json: nil, error: "secure channel: could not open the answer")
        }
        return Reply(status: status, json: json, error: nil)
    }

    /// Sets OttaiCloudClient.lastFailure the same way the plain client does.
    private static func finish(_ r: Reply) -> [String: Any]? {
        if let error = r.error {
            OttaiCloudClient.lastFailure = OttaiCloudClient.CloudFailure(text: error)
            return nil
        }
        let code = r.code
        if code == loginElsewhere { signedInElsewhere = true }
        let ok = code.isEmpty || code == "200" || code.caseInsensitiveCompare("OK") == .orderedSame || code.caseInsensitiveCompare("SUCCESS") == .orderedSame
        if !(200 ... 299).contains(r.status) || !ok {
            let msg = [anyToString(r.json?["message"]), anyToString(r.json?["msg"]), anyToString(r.json?["detailMessage"])].first { !$0.isEmpty } ?? ""
            OttaiCloudClient.lastFailure = OttaiCloudClient.CloudFailure(text: "http=\(r.status) biz=\(code) \(msg.prefix(120))".trimmingCharacters(in: .whitespaces), code: code)
            return nil
        }
        OttaiCloudClient.lastFailure = nil
        return r.json ?? [:]
    }

    private static func baseHeaders(_ req: inout URLRequest, productModel withModel: Bool) {
        let tz = TimeZone.current
        let region = Locale.current.region?.identifier ?? "US"
        var h: [String: String] = [
            "timestamp": timestamp(),
            "traceId": traceId(),
            "appName": appName,
            "packageName": packageName,
            "versionName": versionName,
            "versionCode": versionCode,
            "ua": "ios",
            "timeZoneName": tz.abbreviation() ?? "UTC",
            "timezone": String(tz.secondsFromGMT()),
            "language": Locale.current.language.languageCode?.identifier ?? "en",
            "country": region,
            "region": region,
            "deviceId": deviceId,
            "unit": "mmol_L",
            "deviceModel": OttaiCloudUploader.deviceModel,
        ]
        if withModel { h["productModel"] = productModel }
        for (k, v) in h { req.setValue(v, forHTTPHeaderField: k) }
    }

    private static func http(_ req: URLRequest) -> (Data?, Int, Error?) {
        var req = req
        req.timeoutInterval = timeout
        let sem = DispatchSemaphore(value: 0)
        var out: (Data?, Int, Error?) = (nil, -1, nil)
        URLSession.shared.dataTask(with: req) { data, response, error in
            out = (data, (response as? HTTPURLResponse)?.statusCode ?? -1, error)
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + timeout + 5)
        return out
    }

    // MARK: - helpers

    private static func fail<T>(_ text: String) -> T? {
        OttaiCloudClient.lastFailure = OttaiCloudClient.CloudFailure(text: text)
        return nil
    }

    private static func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    private static func timestamp() -> String { String(nowMs()) }

    private static func md5(_ s: String) -> String {
        Insecure.MD5.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func jsonEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func str(_ dict: [String: Any]?, _ key: String) -> String { anyToString(dict?[key]) }

    private static func anyToString(_ any: Any?) -> String {
        if let s = any as? String { return s == "null" ? "" : s }
        if let n = any as? NSNumber { return n.stringValue }
        return ""
    }

    private static func int64(_ any: Any?) -> Int64? {
        if let n = any as? NSNumber { return n.int64Value }
        if let s = any as? String { return Int64(s) }
        return nil
    }

    static func jwtPayload(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let data = Data(base64Encoded: b) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// A version-1 (time based) UUID, like the app's traceId.
    static func traceId(now: Date = Date()) -> String {
        let ticks = UInt64(now.timeIntervalSince1970 * 10_000_000) &+ 0x01B2_1DD2_1381_4000
        let timeHi = UInt16(truncatingIfNeeded: (ticks >> 48) & 0x0FFF) | 0x1000
        let clock = UInt16.random(in: 0 ... 0x3FFF) | 0x8000
        let node = (0 ..< 6).map { i in String(format: "%02x", UInt8.random(in: 0 ... 255) | (i == 0 ? 1 : 0)) }.joined()
        return String(format: "%08x-%04x-%04x-%04x-%@", UInt32(truncatingIfNeeded: ticks), UInt16(truncatingIfNeeded: ticks >> 32), timeHi, clock, node)
    }

    /// The password, for a new sign-in when the refresh token is dead (as SyaiKit does).
    private enum Keychain {
        private static let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "xdrip.ottai.syai",
            kSecAttrAccount as String: "password",
        ]

        static func savePassword(_ password: String?) {
            SecItemDelete(query as CFDictionary)
            guard let password = password, !password.isEmpty else { return }
            var add = query
            add[kSecValueData as String] = Data(password.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }

        static func loadPassword() -> String? {
            var q = query
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var out: AnyObject?
            guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }
}
