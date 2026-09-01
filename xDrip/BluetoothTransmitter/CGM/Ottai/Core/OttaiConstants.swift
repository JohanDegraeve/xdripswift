//
//  OttaiConstants.swift
//  xdrip
//
//  Ottai / Syai CGM driver — Bluetooth UUIDs, cloud addresses, sensor id helpers
//  and lifetime rules. This is a Swift copy of OttaiConstants.kt from JugglucoNG
//  (without the Android preference keys).
//
//  The cloud "mac" is a 12-character hex id. The server and the Bluetooth login
//  use it. It is not always the same as the Bluetooth address of the sensor.
//
//  Only Foundation is used here, so this file can be tested without Bluetooth.
//

import Foundation

enum OttaiConstants {

    static let tag = "Ottai"
    static let defaultDisplayName = "Ottai CGM"
    static let provisionalSensorPrefix = "OTTAI-"
    static let maxNativeSensorIdChars = 16

    // MARK: - Bluetooth services and characteristics (UUID text)

    static let serviceDeviceInfo = "0000180a-0000-1000-8000-00805f9b34fb"
    static let charSoftwareVersion = "00002a28-0000-1000-8000-00805f9b34fb"
    static let charCurrentTime = "00002a2b-0000-1000-8000-00805f9b34fb"
    static let charMaxActiveTime = "b8fd9848-0ccd-423f-bd34-2419aa7ea004"
    static let charCgmInfoNotify = "cb627922-4e79-42e3-b107-a10e816f6caa"

    static let serviceCgm = "0000181f-0000-1000-8000-00805f9b34fb"
    static let charGlucoseLive = "00002aa7-0000-1000-8000-00805f9b34fb"
    static let charHistoryRequest = "ccecb015-6750-41fd-ba78-3fb77d350574"
    static let charGlucoseHistory = "69e4f45f-a180-422c-83c0-324146402112"
    static let charCommand = "d78d0706-c775-448d-8a78-01215e7c2e11"

    static let serviceAuth = "e06e1d43-1319-4ebf-94b0-5b0e5313b1f4"
    static let charAuthDeviceParam = "86805092-92b5-4d8c-9d73-0785ff6f9147"
    static let charAuthAppParam = "1756ef6e-884b-4eb0-b646-f04ab18408f9"
    static let charAuthSign = "785022c6-08c0-48af-ad17-684bb889aa83"

    /// Used only during activation.
    static let serviceDestructive = "84c5b711-655a-460d-89ca-337dbc981857"
    static let charDestructive = "6aa799b6-b374-4148-8f36-6d440c0ec203"

    static let cccd = "00002902-0000-1000-8000-00805f9b34fb"

    /// The "activate" command byte. It is padded with zeros and encrypted before it is sent.
    static let activateCmd: UInt8 = 0x03

    // MARK: - Cloud

    static let apiBase = "https://api.ottai.com"          // China app (phone + SMS account)
    static let apiBaseGlobal = "https://seas.ottai.com"   // Ottai global app (user name + password)
    static let apiBaseSyai = "https://api.syai.com"       // Syai global app
    static let apiBaseSyaiLegacy = "https://ru.syai.com"
    static let webBaseOttai = "https://www.ottai.com/api/cgm/web"
    static let webBaseSyai = "https://www.syai.com/api/cgm/web"
    static let prefix = "/cgm/app/server"

    static let epApiToken = "\(prefix)/user/apiToken"
    static let epSmsCode = "\(prefix)/user/smsCode"
    static let epSmsLogin = "\(prefix)/user/smsLogin"
    static let epAccountLogin = "\(prefix)/user/accountLogin"
    static let epLogout = "\(prefix)/user/logout"
    static let epGetUser = "\(prefix)/user/getUser"
    static let epValidateByMac = "\(prefix)/device/validateDeviceByMacV2"
    static let epValidateByMacV3 = "\(prefix)/device/validateDeviceByMacV3"
    static let epBind = "\(prefix)/deviceBind/composite/bind"
    static let epBindV3 = "\(prefix)/deviceBind/composite/bindV3"
    static let epCgmAuthVerify = "\(prefix)/cgmAuth/verify"
    static let epUnbind = "\(prefix)/deviceBind/unBindDevice"
    static let epGetBindDevice = "\(prefix)/deviceBind/getBindDevice"
    static let epDeviceList = "\(prefix)/deviceBind/list"
    static let epDownloadGlucose = "\(prefix)/search/downloadGlucose"
    /// Upload of readings, as the Syai Tag app does it (no `prefix`). Syai server only.
    static let epCollectGlucoseV2 = "/cgm/data/collect/collect/glucose/v2"

    static let headerAppName = "ottai"
    static let headerPackage = "com.ottai.tag"
    static let headerAppType = "ottai_main"
    /// A fake China IP. The China server only answers requests that look like they come from China.
    static let cnForwardIp = "114.114.114.114"

    // MARK: - Sensor id helpers

    private static let macColonRegex = try! NSRegularExpression(
        pattern: "^(?:[0-9A-F]{2}:){5}[0-9A-F]{2}$", options: [.caseInsensitive])
    private static let macPlainRegex = try! NSRegularExpression(
        pattern: "^[0-9A-F]{12}$", options: [.caseInsensitive])

    private static func fullMatch(_ regex: NSRegularExpression, _ s: String) -> Bool {
        let range = NSRange(s.startIndex..., in: s)
        return regex.firstMatch(in: s, options: [], range: range) != nil
    }

    static func isProvisionalSensorId(_ name: String?) -> Bool {
        guard let name = name?.trimmingCharacters(in: .whitespaces) else { return false }
        return name.lowercased().hasPrefix(provisionalSensorPrefix.lowercased())
    }

    /// The cloud id in its standard form: 12 upper-case hex characters, no colons.
    static func canonicalSensorId(_ sensorId: String?) -> String {
        let trimmed = sensorId?.trimmingCharacters(in: .whitespaces) ?? ""
        if trimmed.isEmpty { return "" }
        if fullMatch(macColonRegex, trimmed) { return trimmed.uppercased().replacingOccurrences(of: ":", with: "") }
        if fullMatch(macPlainRegex, trimmed) { return trimmed.uppercased() }
        return trimmed
    }

    /// Add colons to a 12-hex id. Only use this when you know it is a Bluetooth address.
    static func macWithColons(_ canonical: String) -> String {
        let c = canonicalSensorId(canonical)
        if !fullMatch(macPlainRegex, c) { return c }
        return stride(from: 0, to: c.count, by: 2).map { i -> String in
            let start = c.index(c.startIndex, offsetBy: i)
            let end = c.index(start, offsetBy: 2)
            return String(c[start ..< end])
        }.joined(separator: ":")
    }

    /// Make a Bluetooth address upper-case with colons. A plain 12-hex text is only
    /// accepted when the caller says so.
    static func normalizeBleAddress(_ address: String?, allowPlain: Bool = false) -> String? {
        let t = address?.trimmingCharacters(in: .whitespaces) ?? ""
        if t.isEmpty { return nil }
        if fullMatch(macColonRegex, t) { return t.uppercased() }
        if allowPlain && fullMatch(macPlainRegex, t) {
            return macWithColons(t.uppercased())
        }
        return nil
    }

    static func looksLikeBleAddress(_ address: String?) -> Bool {
        normalizeBleAddress(address, allowPlain: true) != nil
    }

    static func looksLikeMac(_ s: String?) -> Bool {
        let t = s?.trimmingCharacters(in: .whitespaces) ?? ""
        return fullMatch(macColonRegex, t) || fullMatch(macPlainRegex, t)
    }

    static func matchesCanonicalOrKnownNativeAlias(_ a: String?, _ b: String?) -> Bool {
        let ca = canonicalSensorId(a)
        let cb = canonicalSensorId(b)
        if ca.isEmpty || cb.isEmpty { return false }
        return ca.caseInsensitiveCompare(cb) == .orderedSame
    }

    /// Find the 12-hex sensor id in a QR / barcode text.
    ///
    /// The box label is a GS1 code. The id is the (21) serial number, NOT the (01)
    /// product number at the start. We score every 12-hex run: right after "21"
    /// (+8), has a letter A-F (+4), stands alone (+2). The best one wins. If nothing
    /// scores, the first 12-hex run is used.
    static func extractMacFromQr(_ qr: String?) -> String? {
        guard let qr = qr, !qr.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let raw = Array(qr.uppercased())
        // A MAC with colons wins at once.
        let rawStr = String(raw)
        let colonRange = NSRange(rawStr.startIndex..., in: rawStr)
        if let m = try? NSRegularExpression(pattern: "(?:[0-9A-F]{2}:){5}[0-9A-F]{2}")
            .firstMatch(in: rawStr, options: [], range: colonRange),
           let r = Range(m.range, in: rawStr) {
            return canonicalSensorId(String(rawStr[r]))
        }
        func isHex(_ c: Character) -> Bool {
            ("0" ... "9").contains(c) || ("A" ... "F").contains(c)
        }
        var best: String?
        var bestScore = -1
        var i = 0
        while i + 12 <= raw.count {
            if (i ..< i + 12).allSatisfy({ isHex(raw[$0]) }) {
                let sub = String(raw[i ..< i + 12])
                let afterAi21 = i >= 2 && raw[i - 1] == "1" && raw[i - 2] == "2"
                let standalone = (i == 0 || !isHex(raw[i - 1])) && (i + 12 == raw.count || !isHex(raw[i + 12]))
                let hasLetter = sub.contains { ("A" ... "F").contains($0) }
                let score = (afterAi21 ? 8 : 0) + (hasLetter ? 4 : 0) + (standalone ? 2 : 0)
                if score > bestScore { bestScore = score; best = sub }
            }
            i += 1
        }
        return best
    }

    // MARK: - Lifetime

    /// The sensor lifetime the cloud reports for the tested Chinese M8.
    static let defaultRatedLifetimeDays: Int64 = 15

    static let defaultRetainTimeMs: Int64 = 172_800_000
    static let defaultActiveExpireMs: Int64 = defaultRatedLifetimeDays * 24 * 3600 * 1000

    private static let minActiveExpireMs: Int64 = 10 * 24 * 3600 * 1000
    private static let maxActiveExpireMs: Int64 = 45 * 24 * 3600 * 1000

    /// The longest lifetime we ask for during activation.
    static let extendedLifetimeDays: Int64 = 30
    static let extendedLifetimeMs: Int64 = extendedLifetimeDays * 24 * 3600 * 1000

    /// Keep the value only if it is between 10 and 45 days. Else return 0.
    static func sanitizeActiveExpireMs(_ value: Int64) -> Int64 {
        (value >= minActiveExpireMs && value <= maxActiveExpireMs) ? value : 0
    }

    /// The lifetimes to try during activation, longest first.
    static func activationMaxActiveCandidatesMs(cloudActiveExpireMs: Int64) -> [Int64] {
        let cloudMs = sanitizeActiveExpireMs(cloudActiveExpireMs) > 0
            ? sanitizeActiveExpireMs(cloudActiveExpireMs)
            : defaultActiveExpireMs
        var candidates: [Int64] = []
        if cloudMs > extendedLifetimeMs { candidates.append(cloudMs) }
        var days = extendedLifetimeDays
        while days >= 15 {
            candidates.append(days * 24 * 3600 * 1000)
            days -= 1
        }
        candidates.append(cloudMs)
        // remove doubles, keep the order
        var seen = Set<Int64>()
        return candidates.filter { seen.insert($0).inserted }
    }

    static func expectedLifetimeMs(cloudActiveExpireMs: Int64, acceptedMaxActiveMs: Int64) -> Int64 {
        if sanitizeActiveExpireMs(acceptedMaxActiveMs) > 0 { return sanitizeActiveExpireMs(acceptedMaxActiveMs) }
        if sanitizeActiveExpireMs(cloudActiveExpireMs) > 0 { return sanitizeActiveExpireMs(cloudActiveExpireMs) }
        return defaultActiveExpireMs
    }

    static func shouldAttemptEndedSensorRecovery(commandStatus: Int, activeTimeMs: Int64, nowMs: Int64) -> Bool {
        commandStatus == 4 && activeTimeMs > 0 && nowMs >= activeTimeMs && nowMs < activeTimeMs + extendedLifetimeMs
    }

    /// The sensor's command byte is the truth. 0, 1 or 2 means "not activated yet".
    static func commandNeedsActivation(_ commandStatus: Int) -> Bool {
        commandStatus >= 0 && commandStatus <= 2
    }

    /// Activation cannot be undone, so the user must ask for it.
    static func shouldStartActivation(commandStatus: Int, explicitlyRequested: Bool) -> Bool {
        explicitlyRequested && commandNeedsActivation(commandStatus)
    }

    /// China Ottai and Syai sensors must be woken with NFC around activation.
    static func requiresNfcActivationWake(apiBase: String) -> Bool {
        apiBase == OttaiConstants.apiBase || apiBase == apiBaseSyai
    }

    // MARK: - Warmup

    static let defaultReadingIntervalMinutes = 1
    static let defaultWarmupSeconds = 3200
    static let defaultPreheatPeriodMs: Int64 = 3_600_000

    /// For this time after activation, readings are decoded but not used.
    /// The official app waits 60 minutes. Real sensors settle in about 10 minutes,
    /// so we use 10 minutes.
    static let warmupSuppressMs: Int64 = 600_000

    /// True if the sample is inside the warmup window. Pass 0 as the start to turn
    /// the check off.
    static func isWithinWarmup(activationStartMs: Int64, sampleMs: Int64) -> Bool {
        activationStartMs > 0 && sampleMs > 0 && sampleMs < activationStartMs + warmupSuppressMs
    }

    /// After the lifetime is over, wait this long without samples before calling the sensor expired.
    static let expiredStaleGraceMs: Int64 = 6 * 3600 * 1000
}
