//
//  CareLinkClient.swift
//  xdripswift
//
//  Created by Paul Plant on 1/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import os

/// Owns the CareLink web session, account lookup and glucose-route resolution.
///
/// Actor isolation serializes timer and heartbeat requests, including web-token refresh, so two
/// callers cannot rotate the same session concurrently or overwrite a newly selected route.
/// The persisted region is authoritative. Requests never probe the other CareLink environment.
actor CareLinkClient {
    private let session: URLSession
    private let tokenStore: CareLinkTokenStoring
    private let now: () -> Date
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCareLinkFollowManager)
    private var cachedRoute: CareLinkDataRoute?
    private var refreshTask: Task<CareLinkToken, Error>?
    private var refreshIdentifier: UUID?
    /// Invalidates work started by an older browser session or before an explicit logout.
    private var sessionGeneration = 0
    private var lastTokenRefreshAt: Date?

    /// Dependencies are injectable so URL loading, secure storage and time remain deterministic.
    init(session: URLSession = URLSession(configuration: .ephemeral), tokenStore: CareLinkTokenStoring = CareLinkKeychainTokenStore(), now: @escaping () -> Date = Date.init) {
        self.session = session
        self.tokenStore = tokenStore
        self.now = now
    }

    /// Reports authentication without returning the web token or cookies to UI code.
    func hasToken() -> Bool { (try? tokenStore.load()) != nil }
    func tokenRefreshDate() -> Date? { lastTokenRefreshAt }
    func authenticatedRegion() -> CareLinkRegion? { try? tokenStore.load()?.region }

    /// Creates the personal web-login URL for the selected region and best available country.
    func loginURL(region: CareLinkRegion) -> URL {
        let country = Self.resolvedCountryCode(region: region, accountCountry: nil).lowercased()
        var components = URLComponents(url: configuration(region: region).careLinkBaseURL.appendingPathComponent("patient/sso/login"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "lang", value: Locale.current.language.languageCode?.identifier ?? "en")
        ]
        return components.url!
    }

    /// Validates the two required browser cookies before saving the session in Keychain.
    @discardableResult
    func installWebSession(cookies: [HTTPCookie], region: CareLinkRegion, countryCode: String? = nil) throws -> CareLinkToken {
        let expiryCandidates = cookies.filter { $0.name == Self.expiryCookieName }.compactMap { cookie in
            Self.parseExpiry(cookie.value).map { (cookie, $0) }
        }
        guard let (expiryCookie, expiry) = expiryCandidates.max(by: { $0.1 < $1.1 }), expiry > now(),
              let authCookie = cookies.last(where: {
                  $0.name == Self.authCookieName && $0.domain == expiryCookie.domain
              }) ?? cookies.last(where: { $0.name == Self.authCookieName }) else {
            throw CareLinkError.invalidCallback
        }
        // A login can leave expired cookies from an earlier redirect domain. Keep the newest
        // credential pair once, while retaining unrelated CareLink cookies needed by reauth.
        let normalizedCookies = cookies.filter {
            $0.name != Self.authCookieName && $0.name != Self.expiryCookieName
        } + [authCookie, expiryCookie]
        let storedCookies = normalizedCookies.filter { Self.belongsToCareLink($0, region: region) }.map {
            CareLinkCookie(name: $0.name, value: $0.value, domain: $0.domain, path: $0.path, secure: $0.isSecure, expiresAt: $0.expiresDate)
        }
        let token = CareLinkToken(accessToken: authCookie.value, expiresAt: expiry, cookies: storedCookies, region: region, countryCode: countryCode)
        refreshTask?.cancel()
        refreshTask = nil
        refreshIdentifier = nil
        sessionGeneration += 1
        try tokenStore.save(token)
        lastTokenRefreshAt = now()
        cachedRoute = nil
        return token
    }

    /// Resolves either the patient account holder or the patients linked to a Care Partner account.
    func userAndPatients(region: CareLinkRegion) async throws -> (metadata: CareLinkMetadata, patients: [CareLinkPatient]) {
        let root = configuration(region: region).careLinkBaseURL
        let userData: Data
        do {
            userData = try await authenticated(root.appendingPathComponent("patient/users/me"))
        } catch CareLinkError.http(401) {
            throw CareLinkError.accountRejected(region)
        }
        guard var user = try JSONSerialization.jsonObject(with: userData) as? [String: Any] else {
            throw CareLinkError.malformedResponse
        }
        let role = (user["role"] as? String ?? "").uppercased()
        // Personal web responses frequently omit username and country from `/users/me`.
        if user["username"] == nil || user["country"] == nil {
            let profileData = try await authenticated(root.appendingPathComponent("patient/users/me/profile"))
            guard let profile = try JSONSerialization.jsonObject(with: profileData) as? [String: Any] else {
                throw CareLinkError.malformedResponse
            }
            if user["username"] == nil { user["username"] = profile["username"] }
            if user["country"] == nil { user["country"] = profile["country"] }
            if user["firstName"] == nil { user["firstName"] = profile["firstName"] }
            if user["lastName"] == nil { user["lastName"] = profile["lastName"] }
        }
        let account = user["username"] as? String ?? user["email"] as? String
        var metadata = CareLinkMetadata(accountName: account, role: role, countryCode: user["country"] as? String)
        if CareLinkAccountRole.isPatient(role) {
            guard let patient = Self.patient(user) else { throw CareLinkError.patientIdentityMissing }
            metadata.patientName = patient.displayName
            return (metadata, [patient])
        }
        if CareLinkAccountRole.isCarePartner(role) {
            let linksData = try await authenticated(root.appendingPathComponent("patient/m2m/links/patients"))
            guard let links = try JSONSerialization.jsonObject(with: linksData) as? [[String: Any]] else {
                throw CareLinkError.malformedResponse
            }
            // A malformed or repeated link must never create an ambiguous patient selection.
            var seen = Set<String>()
            let patients = links.compactMap { Self.patient($0) }.filter { seen.insert($0.username).inserted }
            if patients.count == 1 { metadata.patientName = patients[0].displayName }
            return (metadata, patients)
        }
        throw CareLinkError.unsupportedRole(metadata)
    }

    /// Tries the proven patient and Care Partner data families and caches only a glucose response.
    func fetchPatientData(region: CareLinkRegion, patient: CareLinkPatient, username: String?, accountRole: String?, countryCode: String? = nil, linkedPatientCount: Int = 1) async throws -> (Data, CareLinkDataRoute) {
        guard CareLinkAccountRole.isSupportedFollower(accountRole) else {
            throw CareLinkError.unsupportedRole(CareLinkMetadata(accountName: username, role: accountRole))
        }
        let requestRole = CareLinkAccountRole.isCarePartner(accountRole) ? "carepartner" : "patient"
        // Monitor and legacy Connect do not encode a linked-patient identifier. They remain
        // valid for a single link, but a multi-patient Care Partner account must use a route
        // that explicitly carries the selection.
        let preferred: [CareLinkDataRoute] = CareLinkAccountRole.isCarePartner(accountRole) && linkedPatientCount > 1
            ? [.periodic, .guardianM2M]
            : [.monitor, .periodic, .guardianM2M, .legacyConnect]
        let routes = cachedRoute.map { cached in [cached] + preferred.filter { $0 != cached } } ?? preferred
        var lastError: Error = CareLinkError.malformedResponse
        var receivedSuccessfulEmptyResponse = false
        for route in routes {
            trace("CareLink trying route=%{public}@ role=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, route.rawValue, requestRole)
            do {
                let data = try await fetch(route: route, region: region, patient: patient, username: username, requestRole: requestRole, countryCode: countryCode)
                guard Self.isPatientDataPayload(data) else { throw CareLinkError.malformedResponse }
                cachedRoute = route
                trace("CareLink selected route=%{public}@ role=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, route.rawValue, requestRole)
                return (data, route)
            } catch let error as CareLinkError {
                lastError = error
                if error == .noGlucoseData { receivedSuccessfulEmptyResponse = true }
                trace("CareLink route=%{public}@ role=%{public}@ failed: %{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, route.rawValue, requestRole, error.localizedDescription)
                switch error {
                case .http(403), .http(404), .http(500 ... 599), .malformedResponse, .noGlucoseData: continue
                default: throw error
                }
            }
        }
        cachedRoute = nil
        // A 2xx/204 response proves that login and routing reached CareLink. When later
        // device-family fallbacks fail, retain the more useful fact that the account had no data.
        if receivedSuccessfulEmptyResponse { throw CareLinkError.noGlucoseData }
        throw lastError
    }

    /// Removes the local session before making the best-effort server logout request.
    /// The request uses the captured credential so a slow response cannot clear a newer login.
    func revokeAndClear() async {
        let credential = try? tokenStore.load()
        refreshTask?.cancel()
        refreshTask = nil
        refreshIdentifier = nil
        sessionGeneration += 1
        try? tokenStore.clear()
        cachedRoute = nil
        guard let credential else { return }
        let logout = configuration(region: credential.region).careLinkBaseURL.appendingPathComponent("patient/sso/logout")
        _ = try? await authorizedRequest(logout, credential: credential)
    }

    func clearCachedConfiguration() { cachedRoute = nil }

    /// Builds each route using the role-specific browser-session contract seen in production clients.
    private func fetch(route: CareLinkDataRoute, region: CareLinkRegion, patient: CareLinkPatient, username: String?, requestRole: String, countryCode: String?) async throws -> Data {
        let webRoot = configuration(region: region).careLinkBaseURL
        let cloudRoot = cloudBaseURL(region: region)
        switch route {
        case .monitor:
            return try await authenticated(webRoot.appendingPathComponent("patient/monitor/data"))
        case .periodic:
            let accountName = username ?? patient.username
            let endpoint = cloudRoot.appendingPathComponent("connect/carepartner/v13/display/message")
            var bodies = [["username": accountName, "role": requestRole, "patientId": patient.username, "appVersion": "3.6.0"]]
            // Personal accounts have historically accepted both body shapes. A Care Partner
            // request must remain patient-scoped so a fallback can never select another link.
            if requestRole == "patient" {
                bodies.append(["username": accountName, "role": requestRole, "appVersion": "3.6.0"])
            }
            let currentResult = try await periodicPayload(endpoint: endpoint, bodies: bodies)
            if let data = currentResult.payload { return data }

            // Retain the older deployment endpoint as a controlled compatibility fallback.
            let country = Self.resolvedCountryCode(region: region, accountCountry: countryCode)
            var settings = URLComponents(url: webRoot.appendingPathComponent("patient/countries/settings"), resolvingAgainstBaseURL: false)!
            settings.queryItems = [URLQueryItem(name: "countryCode", value: country), URLQueryItem(name: "language", value: "en")]
            let settingsData: Data
            do {
                settingsData = try await authenticated(settings.url!)
            } catch let error as CareLinkError {
                // The current endpoint already proved the authenticated session works. Do not
                // replace its empty-success result with an irrelevant compatibility lookup error.
                if currentResult.receivedSuccessfulResponse {
                    switch error {
                    case .http(403), .http(404), .http(500 ... 599), .malformedResponse:
                        throw CareLinkError.noGlucoseData
                    default:
                        break
                    }
                }
                throw error
            }
            guard let object = try JSONSerialization.jsonObject(with: settingsData) as? [String: Any],
                  let endpointText = object["blePereodicDataEndpoint"] as? String ?? object["blePeriodicDataEndpoint"] as? String,
                  let oldEndpoint = URL(string: endpointText) else { throw CareLinkError.malformedResponse }
            let compatibilityResult = try await periodicPayload(endpoint: oldEndpoint, bodies: bodies.map { body in
                var old = body
                old.removeValue(forKey: "appVersion")
                return old
            })
            if let data = compatibilityResult.payload { return data }
            if currentResult.receivedSuccessfulResponse || compatibilityResult.receivedSuccessfulResponse {
                throw CareLinkError.noGlucoseData
            }
            throw CareLinkError.malformedResponse
        case .guardianM2M:
            let endpoint = cloudRoot.appendingPathComponent("patient/m2m/connect/data/gc/patients/\(patient.username)")
            return try await authenticated(endpoint)
        case .legacyConnect:
            let cloudEndpoint = cloudRoot.appendingPathComponent("patient/connect/data")
            do {
                let data = try await authenticated(cloudEndpoint)
                guard Self.isPatientDataPayload(data) else { throw CareLinkError.malformedResponse }
                return data
            } catch let error as CareLinkError {
                switch error {
                case .http(403), .http(404), .http(500 ... 599), .malformedResponse: break
                default: throw error
                }
            }
            var components = URLComponents(url: webRoot.appendingPathComponent("patient/connect/data"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "cpSerialNumber", value: "NONE"),
                URLQueryItem(name: "msgType", value: "last24hours"),
                URLQueryItem(name: "requestTime", value: String(Int(now().timeIntervalSince1970 * 1000)))
            ]
            return try await authenticated(components.url!)
        }
    }

    /// Empty or unrelated success responses advance only to another known request shape.
    private func periodicPayload(endpoint: URL, bodies: [[String: String]]) async throws -> (payload: Data?, receivedSuccessfulResponse: Bool) {
        var receivedSuccessfulResponse = false
        for body in bodies {
            do {
                let data = try await authenticated(endpoint, method: "POST", json: body)
                receivedSuccessfulResponse = true
                if Self.isPatientDataPayload(data) { return (data, true) }
            } catch let error as CareLinkError {
                switch error {
                case .http(403), .http(404), .http(500 ... 599), .malformedResponse: continue
                default: throw error
                }
            }
        }
        return (nil, receivedSuccessfulResponse)
    }

    /// Performs exactly one refresh-and-retry when a personal endpoint rejects the web token.
    private func authenticated(_ url: URL, method: String = "GET", json: [String: String]? = nil) async throws -> Data {
        var credential = try await validToken()
        do { return try await authorizedRequest(url, method: method, json: json, credential: credential) }
        catch CareLinkError.http(401) {
            credential = try await refresh(force: true)
            return try await authorizedRequest(url, method: method, json: json, credential: credential)
        }
    }

    /// Applies both the Bearer token and retained browser cookies required by personal sessions.
    private func authorizedRequest(_ url: URL, method: String = "GET", json: [String: String]? = nil, credential: CareLinkToken) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        let cookie = Self.cookieHeader(credential.cookies, for: url)
        if !cookie.isEmpty { request.setValue(cookie, forHTTPHeaderField: "Cookie") }
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en;q=0.9, *;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(Self.browserClientHint, forHTTPHeaderField: "Sec-Ch-Ua")
        if let json {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        return try await send(request).data
    }

    private func validToken() async throws -> CareLinkToken {
        guard let token = try tokenStore.load() else { throw CareLinkError.notAuthenticated }
        return token.needsRefresh(at: now()) ? try await refresh(force: false) : token
    }

    /// Coalesces `/patient/sso/reauth` and persists every cookie rotated by the response.
    private func refresh(force: Bool) async throws -> CareLinkToken {
        if let refreshTask { return try await refreshTask.value }
        guard let old = try tokenStore.load() else { throw CareLinkError.notAuthenticated }
        if !force && !old.needsRefresh(at: now()) { return old }
        let generation = sessionGeneration
        let identifier = UUID()
        let task = Task<CareLinkToken, Error> {
            var request = URLRequest(url: self.configuration(region: old.region).careLinkBaseURL.appendingPathComponent("patient/sso/reauth"))
            request.httpMethod = "POST"
            request.httpBody = Data()
            request.timeoutInterval = 30
            request.setValue("Bearer \(old.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(Self.cookieHeader(old.cookies, for: request.url!), forHTTPHeaderField: "Cookie")
            request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
            request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
            do {
                let result = try await self.send(request)
                let responseCookies = HTTPCookie.cookies(withResponseHeaderFields: result.response.allHeaderFields.reduce(into: [:]) { partial, pair in
                    partial[String(describing: pair.key)] = String(describing: pair.value)
                }, for: request.url!)
                // A rotated credential can move from a parent cookie domain to a specific host.
                // Remove every older value with the returned name so request order cannot revive it.
                let rotatedNames = Set(responseCookies.map(\.name))
                let retainedCookies = old.cookies.filter { !rotatedNames.contains($0.name) }
                let merged = Self.merge(retainedCookies, with: responseCookies)
                guard let auth = responseCookies.last(where: { $0.name == Self.authCookieName })
                        .map({ CareLinkCookie(name: $0.name, value: $0.value, domain: $0.domain, path: $0.path, secure: $0.isSecure, expiresAt: $0.expiresDate) })
                        ?? merged.first(where: { $0.name == Self.authCookieName }),
                      let expiryCookie = merged.first(where: { $0.name == Self.expiryCookieName }),
                      let expiry = Self.parseExpiry(expiryCookie.value), expiry > self.now() else {
                    throw CareLinkError.reconnectRequired
                }
                let updated = CareLinkToken(accessToken: auth.value, expiresAt: expiry, cookies: merged, region: old.region, countryCode: old.countryCode)
                try Task.checkCancellation()
                guard self.sessionGeneration == generation else { throw CancellationError() }
                try self.tokenStore.save(updated)
                self.lastTokenRefreshAt = self.now()
                return updated
            } catch CareLinkError.http(400), CareLinkError.http(401), CareLinkError.http(403) {
                // A dormant CareLink web session can become non-refreshable while the app sleeps.
                // Keep the Keychain item until the user logs in again or logs out so a
                // server rejection never silently turns into a local logout.
                throw CareLinkError.reconnectRequired
            }
        }
        refreshTask = task
        refreshIdentifier = identifier
        defer {
            if refreshIdentifier == identifier {
                refreshTask = nil
                refreshIdentifier = nil
            }
        }
        return try await task.value
    }

    /// Returns response metadata as well as data so refresh can capture rotated Set-Cookie values.
    private func send(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        do {
            traceRequest(request)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw CareLinkError.malformedResponse }
            traceResponse(data: data, response: http, request: request)
            try validate(http)
            return (data, http)
        } catch let error as CareLinkError { throw error }
        catch let error as URLError where error.code == .notConnectedToInternet || error.code == .cannotConnectToHost || error.code == .timedOut {
            trace("CareLink transport failure url=%{public}@ error=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, request.url?.absoluteString ?? "<missing>", error.localizedDescription)
            throw CareLinkError.offline
        } catch {
            trace("CareLink request failure url=%{public}@ error=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, request.url?.absoluteString ?? "<missing>", error.localizedDescription)
            throw error
        }
    }

    /// Logs full non-credential request context in Debug while suppressing reusable session values.
    private func traceRequest(_ request: URLRequest) {
        let headers = request.allHTTPHeaderFields?.map { key, value in
            "\(key)=\(["Authorization", "Cookie"].contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) ? "<redacted>" : value)"
        }.sorted().joined(separator: "; ") ?? ""
        let body = diagnosticBody(request.httpBody)
        trace("CareLink request method=%{public}@ url=%{public}@ headers=%{public}@ body=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, request.httpMethod ?? "GET", request.url?.absoluteString ?? "<missing>", headers, body)
    }

    private func traceResponse(data: Data, response: HTTPURLResponse, request: URLRequest) {
        let headers = response.allHeaderFields.map { key, value in
            let name = String(describing: key)
            return "\(name)=\(name.caseInsensitiveCompare("Set-Cookie") == .orderedSame ? "<redacted>" : String(describing: value))"
        }.sorted().joined(separator: "; ")
        trace("CareLink response status=%{public}d url=%{public}@ headers=%{public}@ body=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: response.statusCode >= 400 ? .error : .info, response.statusCode, request.url?.absoluteString ?? "<missing>", headers, diagnosticBody(data))
    }

    private func diagnosticBody(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "<empty>" }
        #if DEBUG
        return String(data: data, encoding: .utf8) ?? "<\(data.count) non-UTF8 bytes>"
        #else
        return "<\(data.count) bytes>"
        #endif
    }

    private func validate(_ response: HTTPURLResponse) throws {
        if response.statusCode == 429 {
            let value = response.value(forHTTPHeaderField: "Retry-After") ?? ""
            if let seconds = TimeInterval(value) { throw CareLinkError.rateLimited(now().addingTimeInterval(max(0, seconds))) }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
            throw CareLinkError.rateLimited(formatter.date(from: value) ?? now().addingTimeInterval(60))
        }
        guard (200..<300).contains(response.statusCode) else { throw CareLinkError.http(response.statusCode) }
    }

    private func configuration(region: CareLinkRegion) -> CareLinkAPIConfiguration {
        CareLinkAPIConfiguration(careLinkBaseURL: Self.debugBaseURL ?? region.webBaseURL)
    }

    private func cloudBaseURL(region: CareLinkRegion) -> URL {
        if let debug = Self.debugBaseURL { return debug }
        return URL(string: region == .unitedStates ? "https://clcloud.minimed.com" : "https://clcloud.minimed.eu")!
    }

    private static func patient(_ object: [String: Any]) -> CareLinkPatient? {
        guard let username = object["username"] as? String ?? object["patientId"] as? String ?? object["id"] as? String else { return nil }
        return CareLinkPatient(id: (object["id"] as? String) ?? username, username: username, firstName: object["firstName"] as? String, lastName: object["lastName"] as? String)
    }

    /// Accepts glucose or pump therapy payloads so a temporary sensor gap does not hide pump data.
    private static func isPatientDataPayload(_ data: Data) -> Bool {
        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        let payload = (envelope["patientData"] as? [String: Any]) ?? envelope
        return payload.keys.contains("sgs")
            || payload.keys.contains("lastSG")
            || payload.keys.contains("markers")
            || payload.keys.contains("activeInsulin")
            || payload.keys.contains("reservoirRemainingUnits")
    }

    static func resolvedCountryCode(region: CareLinkRegion, accountCountry: String?) -> String {
        if let country = accountCountry?.trimmingCharacters(in: .whitespacesAndNewlines), !country.isEmpty { return country.uppercased() }
        if region == .unitedStates { return "US" }
        guard let device = Locale.current.region?.identifier.uppercased(), device != "US" else { return "GB" }
        return device
    }

    static func parseExpiry(_ value: String) -> Date? {
        var value = value.removingPercentEncoding ?? value
        value = value.replacingOccurrences(of: "+", with: " ").trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        if let epoch = TimeInterval(value) {
            return Date(timeIntervalSince1970: epoch > 100_000_000_000 ? epoch / 1000 : epoch)
        }
        let formats = ["EEE MMM d HH:mm:ss zzz yyyy", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ssz", "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ss'Z'"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            formatter.isLenient = true
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    /// Retains only cookies scoped to the selected CareLink environment. This excludes unrelated
    /// identity-provider cookies created while Medtronic redirects between login pages.
    private static func belongsToCareLink(_ cookie: HTTPCookie, region: CareLinkRegion) -> Bool {
        if debugBaseURL != nil { return true }
        let suffix = region == .unitedStates ? "minimed.com" : "minimed.eu"
        return cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased().hasSuffix(suffix)
    }

    private static func cookieHeader(_ cookies: [CareLinkCookie], for url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        return cookies.filter { cookie in
            let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
            return host == domain || host.hasSuffix(".\(domain)")
        }.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    private static func merge(_ old: [CareLinkCookie], with new: [HTTPCookie]) -> [CareLinkCookie] {
        var values = Dictionary(uniqueKeysWithValues: old.map { ("\($0.domain)|\($0.path)|\($0.name)", $0) })
        for cookie in new {
            let value = CareLinkCookie(name: cookie.name, value: cookie.value, domain: cookie.domain, path: cookie.path, secure: cookie.isSecure, expiresAt: cookie.expiresDate)
            values["\(value.domain)|\(value.path)|\(value.name)"] = value
        }
        return Array(values.values)
    }

    private static let authCookieName = "auth_tmp_token"
    private static let expiryCookieName = "c_token_valid_to"
    private static let browserUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1"
    private static let browserClientHint = "\"Safari\";v=\"18\""

    #if DEBUG
    /// Establishes the simulator's disposable web session when explicitly requested at launch.
    /// This test hook never compiles into Release and avoids putting synthetic credentials in code.
    func installDebugSimulatorSessionIfRequested(region: CareLinkRegion) async throws {
        guard Self.debugBaseURL != nil,
              ProcessInfo.processInfo.environment["CARELINK_SIMULATOR_AUTO_LOGIN"] == "1",
              !hasToken() else { return }
        let request = URLRequest(url: loginURL(region: region))
        let result = try await send(request)
        let headers = result.response.allHeaderFields.reduce(into: [String: String]()) { values, pair in
            values[String(describing: pair.key)] = String(describing: pair.value)
        }
        // URLSession's cookie store preserves repeated Set-Cookie fields that may be collapsed in
        // `allHeaderFields`. Merge both views so the loopback server follows real WebKit behavior.
        let responseCookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: request.url!)
        let storedCookies = session.configuration.httpCookieStorage?.cookies(for: request.url!) ?? []
        var cookies = responseCookies + storedCookies
        if let token = result.response.value(forHTTPHeaderField: "X-CareLink-Simulator-Token"),
           let expiry = result.response.value(forHTTPHeaderField: "X-CareLink-Simulator-Expiry"),
           let host = request.url?.host {
            let common: [HTTPCookiePropertyKey: Any] = [.domain: host, .path: "/", .secure: "FALSE"]
            cookies.append(HTTPCookie(properties: common.merging([.name: Self.authCookieName, .value: token]) { _, new in new })!)
            cookies.append(HTTPCookie(properties: common.merging([.name: Self.expiryCookieName, .value: expiry]) { _, new in new })!)
        }
        _ = try installWebSession(cookies: cookies, region: region, countryCode: Self.resolvedCountryCode(region: region, accountCountry: nil))
    }

    static var debugBaseURL: URL? {
        ProcessInfo.processInfo.environment["CARELINK_SIMULATOR_BASE_URL"].flatMap(URL.init(string:))
    }
    #else
    static let debugBaseURL: URL? = nil
    #endif
}
