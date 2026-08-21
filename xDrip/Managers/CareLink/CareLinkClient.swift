//
//  CareLinkClient.swift
//  xdripswift
//
//  Created by Paul Plant on 1/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CryptoKit
import Security
import os

/// Owns the CarePartner OAuth session, account lookup and glucose-route resolution.
///
/// Actor isolation serializes timer and heartbeat requests, including OAuth token refresh, so two
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

    /// Reports authentication without returning OAuth credentials to UI code.
    /// A storage failure remains distinct from a confirmed missing session.
    func hasToken() throws -> Bool { try tokenStore.load() != nil }
    func tokenRefreshDate() -> Date? { lastTokenRefreshAt }
    func authenticatedRegion() -> CareLinkRegion? { try? tokenStore.load()?.region }

    /// Removes local authentication without contacting CareLink. This is used when an app install
    /// has no configured account but a Keychain item from an earlier installation still exists.
    func clearLocalSession() {
        refreshTask?.cancel()
        refreshTask = nil
        refreshIdentifier = nil
        sessionGeneration += 1
        try? tokenStore.clear()
        cachedRoute = nil
        lastTokenRefreshAt = nil
    }

    /// xDrip+ moved to the CarePartner mobile flow after browser sessions proved short-lived.
    /// Reference: NightscoutFoundation/xDrip, `carelinkfollow/auth/CareLinkAuthenticator.java`.
    /// Medtronic's live configuration advertises S256, so each browser transaction also uses
    /// state and PKCE instead of copying the reference client's unprotected authorization URL.
    func authorizationTransaction(region: CareLinkRegion) async throws -> CareLinkAuthorizationTransaction {
        let oauth = try await discoverOAuthConfiguration(region: region)
        let state = try Self.randomBase64URL(byteCount: 32)
        let verifier = try Self.randomBase64URL(byteCount: 64)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        var components = URLComponents(url: oauth.authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: oauth.clientID),
            URLQueryItem(name: "response_type", value: ConstantsCareLink.oauthResponseType),
            URLQueryItem(name: "scope", value: oauth.scope),
            URLQueryItem(name: "redirect_uri", value: oauth.redirectURI.absoluteString),
            URLQueryItem(name: "audience", value: oauth.audience),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: ConstantsCareLink.oauthCodeChallengeMethod)
        ]
        guard let authorizationURL = components?.url else { throw CareLinkError.invalidConfiguration }
        return CareLinkAuthorizationTransaction(authorizationURL: authorizationURL, configuration: oauth, state: state, codeVerifier: verifier)
    }

    /// Validates the browser callback and exchanges its one-time code before persisting anything.
    @discardableResult
    func installOAuthSession(callbackURL: URL, transaction: CareLinkAuthorizationTransaction, region: CareLinkRegion) async throws -> CareLinkToken {
        guard CareLinkOAuthCallback.matches(callbackURL, redirectURI: transaction.configuration.redirectURI),
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              components.queryValue("state") == transaction.state,
              components.queryValue("error") == nil,
              let code = components.queryValue("code"), !code.isEmpty else {
            throw CareLinkError.invalidCallback
        }
        let response = try await oauthToken(
            configuration: transaction.configuration,
            fields: [
                "client_id": transaction.configuration.clientID,
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": transaction.configuration.redirectURI.absoluteString,
                "code_verifier": transaction.codeVerifier
            ],
            isRefresh: false
        )
        let token = try makeToken(response: response, old: nil, region: region, configuration: transaction.configuration)
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
        // CareLink responses can omit username and country from `/users/me`.
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
        clearLocalSession()
        guard let credential else { return }
        var request = URLRequest(url: credential.oauthConfiguration.revocationEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = ConstantsCareLink.requestTimeout
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formData([
            "client_id": credential.oauthConfiguration.clientID,
            "token": credential.refreshToken
        ])
        _ = try? await send(request)
    }

    func clearCachedConfiguration() { cachedRoute = nil }

    /// Builds each route using the role-specific CareLink contract seen in production clients.
    private func fetch(route: CareLinkDataRoute, region: CareLinkRegion, patient: CareLinkPatient, username: String?, requestRole: String, countryCode: String?) async throws -> Data {
        let webRoot = configuration(region: region).careLinkBaseURL
        let cloudRoot = cloudBaseURL(region: region)
        switch route {
        case .monitor:
            return try await authenticated(webRoot.appendingPathComponent("patient/monitor/data"))
        case .periodic:
            let accountName = username ?? patient.username
            let endpoint = cloudRoot.appendingPathComponent("connect/carepartner/v13/display/message")
            var bodies = [["username": accountName, "role": requestRole, "patientId": patient.username, "appVersion": ConstantsCareLink.carePartnerAppVersion]]
            // Personal accounts have historically accepted both body shapes. A Care Partner
            // request must remain patient-scoped so a fallback can never select another link.
            if requestRole == "patient" {
                bodies.append(["username": accountName, "role": requestRole, "appVersion": ConstantsCareLink.carePartnerAppVersion])
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

    /// Performs exactly one refresh-and-retry when a CareLink endpoint rejects the access token.
    private func authenticated(_ url: URL, method: String = "GET", json: [String: String]? = nil) async throws -> Data {
        var credential = try await validToken()
        do { return try await authorizedRequest(url, method: method, json: json, credential: credential) }
        catch CareLinkError.http(401) {
            credential = try await refresh(force: true)
            return try await authorizedRequest(url, method: method, json: json, credential: credential)
        }
    }

    /// CarePartner OAuth uses a Bearer token without browser-session cookies.
    private func authorizedRequest(_ url: URL, method: String = "GET", json: [String: String]? = nil, credential: CareLinkToken) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = ConstantsCareLink.requestTimeout
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en;q=0.9, *;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(ConstantsCareLink.browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(ConstantsCareLink.browserClientHint, forHTTPHeaderField: "Sec-Ch-Ua")
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

    /// Coalesces refreshes and atomically persists each rotated refresh token.
    private func refresh(force: Bool) async throws -> CareLinkToken {
        if let refreshTask { return try await refreshTask.value }
        guard let old = try tokenStore.load() else { throw CareLinkError.notAuthenticated }
        if !force && !old.needsRefresh(at: now()) { return old }
        let generation = sessionGeneration
        let identifier = UUID()
        let task = Task<CareLinkToken, Error> {
            // Do not automatically retry a rotating-token request after an ambiguous transport
            // failure: the server may have consumed it even when the response never arrived.
            let response = try await self.oauthToken(
                configuration: old.oauthConfiguration,
                fields: [
                    "client_id": old.oauthConfiguration.clientID,
                    "refresh_token": old.refreshToken,
                    "grant_type": "refresh_token"
                ],
                isRefresh: true
            )
            let updated = try self.makeToken(response: response, old: old, region: old.region, configuration: old.oauthConfiguration)
            try Task.checkCancellation()
            guard self.sessionGeneration == generation else { throw CancellationError() }
            try self.tokenStore.save(updated)
            self.lastTokenRefreshAt = self.now()
            return updated
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

    /// Keeps Medtronic's configuration dynamic while restricting every discovered HTTPS endpoint
    /// to the selected region's CareLink domain, so discovery cannot authorize an arbitrary host.
    private func discoverOAuthConfiguration(region: CareLinkRegion) async throws -> CareLinkOAuthConfiguration {
        let discoveryData = try await send(URLRequest(url: ConstantsCareLink.carePartnerDiscoveryURL)).data
        guard let discovery = try JSONSerialization.jsonObject(with: discoveryData) as? [String: Any],
              let regions = discovery["CP"] as? [[String: Any]],
              let selected = regions.first(where: {
                  ($0["region"] as? String) == (region == .unitedStates
                      ? ConstantsCareLink.carePartnerRegionUS
                      : ConstantsCareLink.carePartnerRegionOutsideUS)
              }),
              let selector = selected["UseSSOConfiguration"] as? String,
              let configurationText = selected[selector] as? String,
              let configurationURL = URL(string: configurationText),
              Self.isAllowedHTTPS(configurationURL, region: region) else {
            throw CareLinkError.invalidConfiguration
        }

        let data = try await send(URLRequest(url: configurationURL)).data
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let server = root["server"] as? [String: Any],
              let client = root["client"] as? [String: Any],
              let endpoints = root["system_endpoints"] as? [String: Any],
              let hostname = server["hostname"] as? String,
              let clientID = client["client_id"] as? String, !clientID.isEmpty,
              let scope = client["scope"] as? String, scope.split(separator: " ").contains("offline_access"),
              let redirectText = client["redirect_uri"] as? String,
              let redirectURI = URL(string: redirectText),
              redirectURI.scheme == "com.medtronic.carepartner",
              let audience = client["audience"] as? String,
              let authorizationPath = endpoints["authorization_endpoint_path"] as? String,
              let tokenPath = endpoints["token_endpoint_path"] as? String,
              let revocationPath = endpoints["token_revocation_endpoint_path"] as? String else {
            throw CareLinkError.invalidConfiguration
        }
        var base = URLComponents()
        base.scheme = "https"
        base.host = hostname
        if let port = server["port"] as? Int, port != 443 { base.port = port }
        let prefix = (server["prefix"] as? String ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let baseURL = base.url else { throw CareLinkError.invalidConfiguration }
        func endpoint(_ path: String) -> URL {
            [prefix, path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]
                .filter { !$0.isEmpty }
                .reduce(baseURL) { $0.appendingPathComponent($1) }
        }
        let configuration = CareLinkOAuthConfiguration(
            authorizationEndpoint: endpoint(authorizationPath),
            tokenEndpoint: endpoint(tokenPath),
            revocationEndpoint: endpoint(revocationPath),
            clientID: clientID,
            scope: scope,
            redirectURI: redirectURI,
            audience: audience
        )
        guard [configuration.authorizationEndpoint, configuration.tokenEndpoint, configuration.revocationEndpoint]
            .allSatisfy({ Self.isAllowedHTTPS($0, region: region) }) else {
            throw CareLinkError.invalidConfiguration
        }
        return configuration
    }

    private func oauthToken(configuration: CareLinkOAuthConfiguration, fields: [String: String], isRefresh: Bool) async throws -> [String: Any] {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = ConstantsCareLink.requestTimeout
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formData(fields)
        do {
            traceRequest(request)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw CareLinkError.malformedResponse }
            traceResponse(data: data, response: http, request: request)
            if isRefresh, [400, 401, 403].contains(http.statusCode) {
                // Only an explicit grant rejection retires the session. Other server or transport
                // failures retain the rotating credential so background polling can recover later.
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if object?["error"] as? String == "invalid_grant" || http.statusCode == 403 {
                    throw CareLinkError.reconnectRequired
                }
            }
            try validate(http)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CareLinkError.malformedResponse
            }
            return object
        } catch let error as CareLinkError { throw error }
        catch let error as URLError where error.code == .notConnectedToInternet || error.code == .cannotConnectToHost || error.code == .timedOut {
            throw CareLinkError.offline
        }
    }

    private func makeToken(response: [String: Any], old: CareLinkToken?, region: CareLinkRegion, configuration: CareLinkOAuthConfiguration) throws -> CareLinkToken {
        guard let accessToken = response["access_token"] as? String, !accessToken.isEmpty,
              let refreshToken = response["refresh_token"] as? String, !refreshToken.isEmpty,
              let expiresIn = (response["expires_in"] as? NSNumber)?.doubleValue, expiresIn > 0 else {
            throw CareLinkError.malformedResponse
        }
        return CareLinkToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: now().addingTimeInterval(expiresIn),
            region: region,
            countryCode: old?.countryCode,
            oauthConfiguration: configuration
        )
    }

    private static func formData(_ fields: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = fields.sorted(by: { $0.key < $1.key }).map(URLQueryItem.init)
        return Data((components.percentEncodedQuery ?? "").utf8)
    }

    private static func randomBase64URL(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CareLinkError.invalidConfiguration
        }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func isAllowedHTTPS(_ url: URL, region: CareLinkRegion) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        let suffix = region == .unitedStates ? ConstantsCareLink.allowedUSHostSuffix : ConstantsCareLink.allowedOutsideUSHostSuffix
        return host == suffix || host.hasSuffix(".\(suffix)")
    }

    /// Returns response metadata as well as data for normal CareLink API requests.
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
            trace("CareLink transport failure url=%{public}@ error=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, Self.diagnosticURL(request.url), error.localizedDescription)
            throw CareLinkError.offline
        } catch {
            trace("CareLink request failure url=%{public}@ error=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .error, Self.diagnosticURL(request.url), error.localizedDescription)
            throw error
        }
    }

    /// Keeps routine traces payload-free while retaining redacted protocol details at debug level.
    private func traceRequest(_ request: URLRequest) {
        let method = request.httpMethod ?? "GET"
        let url = Self.diagnosticURL(request.url)
        trace("CareLink request method=%{public}@ url=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .info, method, url)

        let headers = request.allHTTPHeaderFields?.map { key, value in
            "\(key)=\(["Authorization", "Cookie"].contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) ? "<redacted>" : value)"
        }.sorted().joined(separator: "; ") ?? ""
        let body = Self.diagnosticBody(request.httpBody)
        trace("CareLink request debug headers=%{public}@ body=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: .debug, headers, body)
    }

    private func traceResponse(data: Data, response: HTTPURLResponse, request: URLRequest) {
        let url = Self.diagnosticURL(request.url)
        trace("CareLink response status=%{public}d url=%{public}@", log: log, category: ConstantsLog.categoryCareLinkFollowManager, type: response.statusCode >= 400 ? .error : .info, response.statusCode, url)

        let headers = response.allHeaderFields.map { key, value in
            let name = String(describing: key)
            return "\(name)=\(name.caseInsensitiveCompare("Set-Cookie") == .orderedSame ? "<redacted>" : String(describing: value))"
        }.sorted().joined(separator: "; ")
        // Response payloads can contain account and medical data. Record only their size.
        trace(
            "CareLink response debug headers=%{public}@ bodyBytes=%{public}d",
            log: log,
            category: ConstantsLog.categoryCareLinkFollowManager,
            type: .debug,
            headers,
            data.count
        )
    }

    /// Produces a stable endpoint description without query values or patient identifiers.
    /// CareLink's Guardian route embeds the selected patient's username directly after `patients`.
    /// That value is useful to the request but must never be copied into OSLog or support material.
    static func diagnosticURL(_ url: URL?) -> String {
        guard let url else { return "<missing>" }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        var redactedPathComponents = pathComponents
        if let patientsIndex = redactedPathComponents.firstIndex(where: {
            $0.caseInsensitiveCompare("patients") == .orderedSame
        }), redactedPathComponents.indices.contains(patientsIndex + 1) {
            redactedPathComponents[patientsIndex + 1] = "<redacted>"
        }

        var authority = url.host ?? "<missing-host>"
        if let port = url.port {
            authority += ":\(port)"
        }
        let scheme = url.scheme.map { "\($0)://" } ?? ""
        let path = redactedPathComponents.isEmpty ? "" : "/" + redactedPathComponents.joined(separator: "/")
        return scheme + authority + path
    }

    /// Request bodies can contain CareLink account and patient identifiers. Their size is enough
    /// to diagnose the protocol shape in both Debug and Release builds.
    static func diagnosticBody(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "<empty>" }
        return "<\(data.count) bytes>"
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

    #if DEBUG
    static var debugBaseURL: URL? {
        ProcessInfo.processInfo.environment["CARELINK_SIMULATOR_BASE_URL"].flatMap(URL.init(string:))
    }
    #else
    static let debugBaseURL: URL? = nil
    #endif
}

private extension URLComponents {
    func queryValue(_ name: String) -> String? {
        queryItems?.first(where: { $0.name == name })?.value
    }
}
