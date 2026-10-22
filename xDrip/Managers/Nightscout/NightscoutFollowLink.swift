//
//  NightscoutFollowLink.swift
//  xdrip
//
//  Created by Soham Patankar on 30/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// What an incoming `xdripswift://` or file URL asks the app to do. Every URL the app receives is
/// classified here, by host, so the app has one place that decides where a URL goes.
enum IncomingURLRoute: Equatable {
    /// A backup document handed over by iOS.
    case backupDocument
    /// `xdripswift://open`, used by the Live Activity only to bring the app to the foreground.
    case openApp
    /// `xdripswift://nightscout-follow`, carrying either a valid link or the reason it was refused.
    case nightscoutFollow(Result<NightscoutFollowLink, NightscoutFollowLinkError>)
    case ignored

    static let scheme = "xdripswift"

    static func resolve(_ url: URL) -> IncomingURLRoute {
        if url.isFileURL {
            return url.pathExtension.caseInsensitiveCompare("xdripbackup") == .orderedSame ? .backupDocument : .ignored
        }

        guard url.scheme?.lowercased() == scheme else { return .ignored }

        switch url.host?.lowercased() {
        case "open":
            return .openApp
        case NightscoutFollowLink.host:
            return .nightscoutFollow(NightscoutFollowLink.parse(url))
        default:
            return .ignored
        }
    }
}

/// Why a Nightscout follow link was refused. A refused link never changes any setting.
enum NightscoutFollowLinkError: Error, Equatable {
    case malformedLink
    case missingURL
    case invalidURL
    case insecureURL
    case urlHasExtraComponents
    case invalidPort
    case invalidToken

    var message: String {
        let reason: String
        switch self {
        case .malformedLink: reason = Texts_SettingsView.nightscoutFollowLinkMalformed
        case .missingURL: reason = Texts_SettingsView.nightscoutFollowLinkMissingURL
        case .invalidURL: reason = Texts_SettingsView.nightscoutFollowLinkInvalidURL
        case .insecureURL: reason = Texts_SettingsView.nightscoutFollowLinkInsecureURL
        case .urlHasExtraComponents: reason = Texts_SettingsView.nightscoutFollowLinkExtraComponents
        case .invalidPort: reason = Texts_SettingsView.nightscoutFollowLinkInvalidPort
        case .invalidToken: reason = Texts_SettingsView.nightscoutFollowLinkInvalidToken
        }
        return reason + "\n\n" + Texts_SettingsView.nightscoutFollowLinkNoChanges
    }
}

/// A validated request to follow a Nightscout site, from
/// `xdripswift://nightscout-follow?url=<url>&port=<port>&token=<token>`.
///
/// Validation rules, all of which must hold or the whole link is refused:
/// - `url` is required, appears once, and is a bare server address: scheme and host only, with no
///   port, path (other than a single trailing `/`), query, fragment or credentials.
/// - The scheme is `https`. `http` is accepted only when the host is a `.local` name, a private
///   IPv4 address (10/8, 172.16/12, 192.168/16) or a Tailscale address (100.64.0.0/10, which
///   Tailscale encrypts end to end).
/// - The host is ASCII letters, digits, `-` and `.` only (IDN hosts arrive as punycode).
/// - `port` is optional and, when present, is digits only within 1...65535.
/// - `token` is optional and, when present, is 1 to 128 characters from `A-Z a-z 0-9 - _`.
/// - An empty `port` or `token` counts as absent. Unknown parameters are ignored.
struct NightscoutFollowLink: Equatable {
    static let host = "nightscout-follow"
    static let maximumTokenLength = 128

    /// Scheme and host only, as stored in the Nightscout URL setting.
    let url: String
    /// 0 means no port, matching the stored setting.
    let port: Int
    let token: String?

    // MARK: - Parsing

    static func parse(_ link: URL) -> Result<NightscoutFollowLink, NightscoutFollowLinkError> {
        guard let components = URLComponents(url: link, resolvingAgainstBaseURL: false) else {
            return .failure(.malformedLink)
        }

        let items = components.queryItems ?? []
        var values: [String: String] = [:]
        for item in items where ["url", "port", "token"].contains(item.name) {
            guard values[item.name] == nil else { return .failure(.malformedLink) }
            values[item.name] = item.value ?? ""
        }

        guard let urlValue = values["url"], !urlValue.isEmpty else { return .failure(.missingURL) }

        let normalizedURL: String
        switch normalizeServerURL(urlValue) {
        case let .success(url): normalizedURL = url
        case let .failure(error): return .failure(error)
        }

        var port = 0
        if let portValue = values["port"], !portValue.isEmpty {
            guard portValue.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                  let parsedPort = Int(portValue),
                  (1...65535).contains(parsedPort) else { return .failure(.invalidPort) }
            port = parsedPort
        }

        var token: String?
        if let tokenValue = values["token"], !tokenValue.isEmpty {
            guard tokenValue.utf8.count <= maximumTokenLength,
                  tokenValue.utf8.allSatisfy(isTokenCharacter) else { return .failure(.invalidToken) }
            token = tokenValue
        }

        return .success(NightscoutFollowLink(url: normalizedURL, port: port, token: token))
    }

    private static func normalizeServerURL(_ value: String) -> Result<String, NightscoutFollowLinkError> {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty else { return .failure(.invalidURL) }

        guard components.user == nil, components.password == nil, components.port == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/" else { return .failure(.urlHasExtraComponents) }

        guard isValidHost(host) else { return .failure(.invalidURL) }

        switch scheme {
        case "https":
            break
        case "http":
            guard isLocalNetworkHost(host) else { return .failure(.insecureURL) }
        default:
            return .failure(.insecureURL)
        }

        return .success("\(scheme)://\(host)")
    }

    private static func isTokenCharacter(_ byte: UInt8) -> Bool {
        (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
            || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "_")
    }

    private static func isValidHost(_ host: String) -> Bool {
        guard host.utf8.count <= 253 else { return false }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        return labels.allSatisfy { label in
            !label.isEmpty && label.utf8.count <= 63 && !label.hasPrefix("-") && !label.hasSuffix("-")
                && label.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 122) || $0 == UInt8(ascii: "-") }
        }
    }

    private static func isLocalNetworkHost(_ host: String) -> Bool {
        if host.hasSuffix(".local") { return true }

        let octets = host.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ $0 != nil && (0...255).contains($0!) }) else { return false }

        let bytes = octets.compactMap { $0 }
        switch (bytes[0], bytes[1]) {
        case (10, _), (192, 168): return true
        case (172, 16...31): return true
        case (100, 64...127): return true
        default: return false
        }
    }

    // MARK: - Confirmation

    /// The lines of the confirmation shown before anything is applied. The token is masked.
    func confirmationMessage(isCurrentlyMaster: Bool) -> String {
        var lines = [Texts_SettingsView.nightscoutFollowLinkSummary]

        if isCurrentlyMaster {
            lines.append(Texts_SettingsView.nightscoutFollowLinkMasterWarning)
        }

        var details = ["\(Texts_SettingsView.labelNightscoutUrl) \(url)"]
        if port != 0 {
            details.append("\(Texts_SettingsView.nightscoutPort) \(port)")
        }
        if let token {
            details.append("\(Texts_SettingsView.nightscoutToken): \(token.obscured())")
        }

        return lines.joined(separator: "\n\n") + "\n\n" + details.joined(separator: "\n")
    }

    // MARK: - Applying

    /// Makes the app a Nightscout follower with this connection. The connection settings are
    /// replaced as a whole, because a port, token or API secret left from another site would be
    /// sent to this one. Nothing else the user has set is touched.
    func apply(to defaults: UserDefaults = .standard) {
        // The managers connect on every change to these, so the old credentials go before the URL
        // and the new token after it.
        defaults.nightscoutAPIKey = nil
        defaults.nightscoutToken = nil
        defaults.nightscoutUrl = url
        defaults.nightscoutPort = port
        defaults.nightscoutToken = token
        defaults.nightscoutEnabled = true
        defaults.followerDataSourceType = .nightscout
        defaults.timeStampOfLastFollowerConnection = nil
        // Last, so that the follower manager sees the complete connection when it reacts.
        defaults.isMaster = false
    }
}
