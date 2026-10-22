//
//  NightscoutFollowLinkTests.swift
//  xdripTests
//
//  Created by Soham Patankar on 30/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class NightscoutFollowLinkTests: XCTestCase {
    private typealias ParseResult = Result<NightscoutFollowLink, NightscoutFollowLinkError>

    // MARK: - Parsing

    private static let longToken = String(repeating: "a", count: NightscoutFollowLink.maximumTokenLength)
    private static let relayToken = "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_abcde"

    func testLinkParsing() {
        let base = "xdripswift://nightscout-follow"
        let cases: [(name: String, link: String, expected: ParseResult)] = [
            // valid
            ("url only", "\(base)?url=https%3A%2F%2Fmy.example.com", .success(.init(url: "https://my.example.com", port: 0, token: nil))),
            ("url, port and token", "\(base)?url=https%3A%2F%2Fmy.example.com&port=8443&token=readable-3f033c4515e623c2", .success(.init(url: "https://my.example.com", port: 8443, token: "readable-3f033c4515e623c2"))),
            ("scheme, route and host case, trailing slash", "XDRIPSWIFT://Nightscout-Follow?url=HTTPS%3A%2F%2FMy.Example.COM%2F", .success(.init(url: "https://my.example.com", port: 0, token: nil))),
            ("43 character token", "\(base)?url=https%3A%2F%2Fa.example.com&token=\(Self.relayToken)", .success(.init(url: "https://a.example.com", port: 0, token: Self.relayToken))),
            ("longest token", "\(base)?url=https%3A%2F%2Fa.example.com&token=\(Self.longToken)", .success(.init(url: "https://a.example.com", port: 0, token: Self.longToken))),
            ("percent-encoded token", "\(base)?url=https%3A%2F%2Fa.example.com&token=abc%2Ddef", .success(.init(url: "https://a.example.com", port: 0, token: "abc-def"))),
            ("empty port and token are absent", "\(base)?url=https%3A%2F%2Fa.example.com&port=&token=", .success(.init(url: "https://a.example.com", port: 0, token: nil))),
            ("lowest port", "\(base)?url=https%3A%2F%2Fa.example.com&port=1", .success(.init(url: "https://a.example.com", port: 1, token: nil))),
            ("highest port", "\(base)?url=https%3A%2F%2Fa.example.com&port=65535", .success(.init(url: "https://a.example.com", port: 65535, token: nil))),
            ("unknown parameters are ignored", "\(base)?utm=1&url=https%3A%2F%2Fa.example.com", .success(.init(url: "https://a.example.com", port: 0, token: nil))),
            ("http on a .local host", "\(base)?url=http%3A%2F%2Fnightscout.local", .success(.init(url: "http://nightscout.local", port: 0, token: nil))),
            ("http on 192.168 address", "\(base)?url=http%3A%2F%2F192.168.1.20&port=1337", .success(.init(url: "http://192.168.1.20", port: 1337, token: nil))),
            ("http on 10 address", "\(base)?url=http%3A%2F%2F10.0.0.2", .success(.init(url: "http://10.0.0.2", port: 0, token: nil))),
            ("http on first Tailscale address", "\(base)?url=http%3A%2F%2F100.64.0.0", .success(.init(url: "http://100.64.0.0", port: 0, token: nil))),
            ("http inside the Tailscale range", "\(base)?url=http%3A%2F%2F100.101.102.103&port=8080", .success(.init(url: "http://100.101.102.103", port: 8080, token: nil))),
            ("http on last Tailscale address", "\(base)?url=http%3A%2F%2F100.127.255.255", .success(.init(url: "http://100.127.255.255", port: 0, token: nil))),
            ("http on 172.16 address", "\(base)?url=http%3A%2F%2F172.31.255.1", .success(.init(url: "http://172.31.255.1", port: 0, token: nil))),

            // missing or unreadable url
            ("no parameters", base, .failure(.missingURL)),
            ("empty url", "\(base)?url=", .failure(.missingURL)),
            ("url without a value", "\(base)?url", .failure(.missingURL)),
            ("url without a scheme", "\(base)?url=example.com", .failure(.invalidURL)),
            ("url without a host", "\(base)?url=https%3A%2F%2F", .failure(.invalidURL)),
            ("host with an underscore", "\(base)?url=https%3A%2F%2Fexa_mple.com", .failure(.invalidURL)),
            ("host with an empty label", "\(base)?url=https%3A%2F%2Fexample..com", .failure(.invalidURL)),
            ("url given twice", "\(base)?url=https%3A%2F%2Fa.example.com&url=https%3A%2F%2Fb.example.com", .failure(.malformedLink)),

            // scheme
            ("plain http on the internet", "\(base)?url=http%3A%2F%2Fexample.com", .failure(.insecureURL)),
            ("other scheme", "\(base)?url=ftp%3A%2F%2Fexample.com", .failure(.insecureURL)),
            ("http on localhost", "\(base)?url=http%3A%2F%2Flocalhost", .failure(.insecureURL)),
            ("http just outside 172.16 to 172.31", "\(base)?url=http%3A%2F%2F172.32.0.1", .failure(.insecureURL)),
            ("http just below the Tailscale range", "\(base)?url=http%3A%2F%2F100.63.255.255", .failure(.insecureURL)),
            ("http just above the Tailscale range", "\(base)?url=http%3A%2F%2F100.128.0.0", .failure(.insecureURL)),
            ("http on a public address", "\(base)?url=http%3A%2F%2F8.8.8.8", .failure(.insecureURL)),
            ("http on 192.169 address", "\(base)?url=http%3A%2F%2F192.169.1.1", .failure(.insecureURL)),
            ("http on a name that only ends in local", "\(base)?url=http%3A%2F%2Fexample.locale", .failure(.insecureURL)),

            // more than a server address
            ("path", "\(base)?url=https%3A%2F%2Fa.example.com%2Fapi%2Fv1", .failure(.urlHasExtraComponents)),
            ("query", "\(base)?url=https%3A%2F%2Fa.example.com%3Ftoken%3Dabc", .failure(.urlHasExtraComponents)),
            ("fragment", "\(base)?url=https%3A%2F%2Fa.example.com%23top", .failure(.urlHasExtraComponents)),
            ("credentials", "\(base)?url=https%3A%2F%2Fuser%3Apw%40a.example.com", .failure(.urlHasExtraComponents)),
            ("port inside the url", "\(base)?url=https%3A%2F%2Fa.example.com%3A8443", .failure(.urlHasExtraComponents)),

            // port
            ("port zero", "\(base)?url=https%3A%2F%2Fa.example.com&port=0", .failure(.invalidPort)),
            ("port too high", "\(base)?url=https%3A%2F%2Fa.example.com&port=65536", .failure(.invalidPort)),
            ("negative port", "\(base)?url=https%3A%2F%2Fa.example.com&port=-1", .failure(.invalidPort)),
            ("port with a signed plus", "\(base)?url=https%3A%2F%2Fa.example.com&port=%2B80", .failure(.invalidPort)),
            ("port with a letter", "\(base)?url=https%3A%2F%2Fa.example.com&port=80a", .failure(.invalidPort)),
            ("port with a space", "\(base)?url=https%3A%2F%2Fa.example.com&port=8%200", .failure(.invalidPort)),
            ("port that overflows", "\(base)?url=https%3A%2F%2Fa.example.com&port=99999999999999999999", .failure(.invalidPort)),
            ("port given twice", "\(base)?url=https%3A%2F%2Fa.example.com&port=80&port=81", .failure(.malformedLink)),

            // token
            ("token with a space", "\(base)?url=https%3A%2F%2Fa.example.com&token=a%20b", .failure(.invalidToken)),
            ("token with a dot", "\(base)?url=https%3A%2F%2Fa.example.com&token=a.b", .failure(.invalidToken)),
            ("token with an equals sign", "\(base)?url=https%3A%2F%2Fa.example.com&token=a%3Db", .failure(.invalidToken)),
            ("token with a plus", "\(base)?url=https%3A%2F%2Fa.example.com&token=a%2Bb", .failure(.invalidToken)),
            ("token with a slash", "\(base)?url=https%3A%2F%2Fa.example.com&token=a%2Fb", .failure(.invalidToken)),
            ("token with a non-ASCII letter", "\(base)?url=https%3A%2F%2Fa.example.com&token=caf%C3%A9", .failure(.invalidToken)),
            ("token that is too long", "\(base)?url=https%3A%2F%2Fa.example.com&token=\(Self.longToken)a", .failure(.invalidToken))
        ]

        for testCase in cases {
            guard let link = URL(string: testCase.link) else {
                XCTFail("\(testCase.name): test link is not a URL")
                continue
            }
            XCTAssertEqual(NightscoutFollowLink.parse(link), testCase.expected, testCase.name)
        }
    }

    func testEveryRefusalExplainsItselfAndSaysNothingChanged() {
        let errors: [NightscoutFollowLinkError] = [.malformedLink, .missingURL, .invalidURL, .insecureURL, .urlHasExtraComponents, .invalidPort, .invalidToken]

        for error in errors {
            XCTAssertTrue(error.message.hasSuffix(Texts_SettingsView.nightscoutFollowLinkNoChanges), "\(error)")
            XCTAssertGreaterThan(error.message.count, Texts_SettingsView.nightscoutFollowLinkNoChanges.count, "\(error)")
        }
        XCTAssertEqual(Set(errors.map(\.message)).count, errors.count)
    }

    // MARK: - Routing

    func testIncomingURLRouting() {
        let follow = "xdripswift://nightscout-follow?url=https%3A%2F%2Fa.example.com"
        let cases: [(name: String, url: URL, expected: IncomingURLRoute)] = [
            ("backup document", URL(fileURLWithPath: "/tmp/export.XDRIPBACKUP"), .backupDocument),
            ("other file", URL(fileURLWithPath: "/tmp/export.pdf"), .ignored),
            ("open", URL(string: "xdripswift://open")!, .openApp),
            ("open ignores parameters", URL(string: "xdripswift://open?url=https%3A%2F%2Fa.example.com")!, .openApp),
            ("follow", URL(string: follow)!, .nightscoutFollow(.success(.init(url: "https://a.example.com", port: 0, token: nil)))),
            ("refused follow", URL(string: "xdripswift://nightscout-follow")!, .nightscoutFollow(.failure(.missingURL))),
            ("unknown host", URL(string: "xdripswift://elsewhere")!, .ignored),
            ("other scheme", URL(string: "https://nightscout-follow?url=https%3A%2F%2Fa.example.com")!, .ignored)
        ]

        for testCase in cases {
            XCTAssertEqual(IncomingURLRoute.resolve(testCase.url), testCase.expected, testCase.name)
        }
    }

    // MARK: - Confirmation text

    func testConfirmationShowsTheChangeAndMasksTheToken() {
        let link = NightscoutFollowLink(url: "https://a.example.com", port: 8443, token: "readable-3f033c4515e623c2")

        let message = link.confirmationMessage(isCurrentlyMaster: false)
        XCTAssertTrue(message.contains("https://a.example.com"))
        XCTAssertTrue(message.contains("8443"))
        XCTAssertTrue(message.contains(Texts_SettingsView.nightscoutFollowLinkSummary))
        XCTAssertFalse(message.contains(link.token!))
        XCTAssertFalse(message.contains(Texts_SettingsView.nightscoutFollowLinkMasterWarning))

        XCTAssertTrue(link.confirmationMessage(isCurrentlyMaster: true).contains(Texts_SettingsView.nightscoutFollowLinkMasterWarning))
    }

    // MARK: - Applying

    private static let suiteName = "NightscoutFollowLinkTests"

    private func makeDefaults() throws -> UserDefaults {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)
        return defaults
    }

    /// Keys that have a different value, or exist on only one side.
    private func changedKeys(from before: [String: Any], to after: [String: Any]) -> Set<String> {
        Set(before.keys).union(after.keys).filter { key in
            switch (before[key], after[key]) {
            case (nil, nil): return false
            case let (old?, new?): return !(old as AnyObject).isEqual(new)
            default: return true
            }
        }
    }

    /// Everything a user could have set that a follow link must leave alone.
    private func storeUnrelatedSettings(in defaults: UserDefaults) {
        defaults.bloodGlucoseUnitIsMgDl = false
        defaults.followerUploadDataToNightscout = true
        defaults.nightscoutFollowType = .openAPS
        defaults.nightscoutUseSchedule = true
        defaults.nightscoutSchedule = "0-60"
        defaults.followerBackgroundKeepAliveType = .aggressive
        defaults.followerPatientName = "Alex"
        defaults.masterUploadDataToNightscout = false
        defaults.uploadReadingstoDexcomShare = true
        defaults.libreLinkUpEmail = "user@example.com"
        defaults.set([70, 180], forKey: "unrelatedAlarmThresholds")
    }

    /// A previous connection to some other site, all of which must be replaced.
    private func storeExistingConnection(in defaults: UserDefaults) {
        defaults.nightscoutUrl = "https://old.example.com"
        defaults.nightscoutPort = 1234
        defaults.nightscoutToken = "old-token"
        defaults.nightscoutAPIKey = "old-secret"
        defaults.nightscoutEnabled = false
        defaults.followerDataSourceType = .libreLinkUp
        defaults.isMaster = true
        defaults.timeStampOfLastFollowerConnection = Date(timeIntervalSince1970: 1_700_000_000)
    }

    func testApplyWritesExactlyTheConnectionKeys() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        storeUnrelatedSettings(in: defaults)
        storeExistingConnection(in: defaults)
        let before = defaults.dictionaryRepresentation()

        NightscoutFollowLink(url: "https://a.example.com", port: 8443, token: "readable-3f033c4515e623c2").apply(to: defaults)

        let expectedKeys: Set<String> = [
            UserDefaults.Key.nightscoutUrl.rawValue,
            UserDefaults.Key.nightscoutPort.rawValue,
            UserDefaults.Key.nightscoutToken.rawValue,
            UserDefaults.Key.nightscoutAPIKey.rawValue,
            UserDefaults.Key.nightscoutEnabled.rawValue,
            UserDefaults.Key.followerDataSourceType.rawValue,
            UserDefaults.Key.isMaster.rawValue,
            UserDefaults.Key.timeStampOfLastFollowerConnection.rawValue
        ]
        XCTAssertEqual(changedKeys(from: before, to: defaults.dictionaryRepresentation()), expectedKeys)

        XCTAssertEqual(defaults.nightscoutUrl, "https://a.example.com")
        XCTAssertEqual(defaults.nightscoutPort, 8443)
        XCTAssertEqual(defaults.nightscoutToken, "readable-3f033c4515e623c2")
        XCTAssertNil(defaults.nightscoutAPIKey)
        XCTAssertTrue(defaults.nightscoutEnabled)
        XCTAssertEqual(defaults.followerDataSourceType, .nightscout)
        XCTAssertFalse(defaults.isMaster)
        XCTAssertNil(defaults.timeStampOfLastFollowerConnection)
    }

    func testApplyWithoutPortOrTokenClearsTheOldOnes() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        storeExistingConnection(in: defaults)

        NightscoutFollowLink(url: "https://a.example.com", port: 0, token: nil).apply(to: defaults)

        XCTAssertEqual(defaults.nightscoutPort, 0)
        XCTAssertNil(defaults.nightscoutToken)
        XCTAssertNil(defaults.nightscoutAPIKey)
    }

    /// The connection as an observer sees it during one change notification.
    private struct ConnectionSnapshot: Equatable {
        let url: String?
        let token: String?
        let apiKey: String?
    }

    /// Snapshots the connection on every change to one of its settings, as the follower and upload
    /// managers read it when they react.
    private final class ConnectionRecorder: NSObject {
        private let defaults: UserDefaults
        private let keys: [UserDefaults.Key] = [.nightscoutUrl, .nightscoutPort, .nightscoutToken, .nightscoutAPIKey]
        private(set) var snapshots: [ConnectionSnapshot] = []

        init(observing defaults: UserDefaults) {
            self.defaults = defaults
            super.init()
            keys.forEach { defaults.addObserver(self, forKeyPath: $0.rawValue, options: .new, context: nil) }
        }

        func stop() {
            keys.forEach { defaults.removeObserver(self, forKeyPath: $0.rawValue) }
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            snapshots.append(ConnectionSnapshot(url: defaults.nightscoutUrl, token: defaults.nightscoutToken, apiKey: defaults.nightscoutAPIKey))
        }
    }

    func testCredentialsAreNeverPairedWithTheOtherSite() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        storeExistingConnection(in: defaults)
        let recorder = ConnectionRecorder(observing: defaults)
        defer { recorder.stop() }

        NightscoutFollowLink(url: "https://a.example.com", port: 8443, token: "new-token").apply(to: defaults)

        XCTAssertFalse(recorder.snapshots.isEmpty)
        for snapshot in recorder.snapshots {
            switch snapshot.url {
            case "https://old.example.com":
                XCTAssertTrue([nil, "old-token"].contains(snapshot.token), "the old site was offered the token \(snapshot.token ?? "")")
            case "https://a.example.com":
                XCTAssertTrue([nil, "new-token"].contains(snapshot.token), "the new site was offered the token \(snapshot.token ?? "")")
                XCTAssertNil(snapshot.apiKey, "the new site was offered the old site's API secret")
            default:
                XCTFail("unexpected site \(snapshot.url ?? "nil")")
            }
        }
        XCTAssertEqual(recorder.snapshots.last, ConnectionSnapshot(url: "https://a.example.com", token: "new-token", apiKey: nil))
    }

    // MARK: - Confirmation before anything changes

    @MainActor private func makeStateModel(
        defaults: UserDefaults,
        verifications: @escaping () -> Void = {}
    ) -> RootTabStateModel {
        RootTabStateModel(settingsDefaults: defaults, nightscoutConnectionVerifier: { report in
            verifications()
            report("Verification Successful", "verified")
        })
    }

    @MainActor func testValidLinkChangesNothingUntilConfirmed() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        storeUnrelatedSettings(in: defaults)
        storeExistingConnection(in: defaults)
        let before = defaults.dictionaryRepresentation()
        var verifications = 0
        let stateModel = makeStateModel(defaults: defaults) { verifications += 1 }

        stateModel.receiveIncomingURL(try XCTUnwrap(URL(string: "xdripswift://nightscout-follow?url=https%3A%2F%2Fa.example.com&port=8443&token=abc-123")))

        let request = try XCTUnwrap(stateModel.alertRequest)
        XCTAssertEqual(request.actionTitle, Texts_SettingsView.nightscoutFollowLinkAction)
        XCTAssertEqual(request.cancelTitle, Texts_Common.Cancel)
        XCTAssertTrue(request.message.contains("https://a.example.com"))
        XCTAssertTrue(request.message.contains(Texts_SettingsView.nightscoutFollowLinkMasterWarning))
        XCTAssertTrue(changedKeys(from: before, to: defaults.dictionaryRepresentation()).isEmpty)
        XCTAssertEqual(verifications, 0)

        request.cancel()
        XCTAssertTrue(changedKeys(from: before, to: defaults.dictionaryRepresentation()).isEmpty)
        XCTAssertEqual(verifications, 0)
    }

    @MainActor func testConfirmingAppliesTheLinkThenRunsTheConnectionTest() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        storeExistingConnection(in: defaults)
        var verifications = 0
        let stateModel = makeStateModel(defaults: defaults) { verifications += 1 }

        stateModel.receiveIncomingURL(try XCTUnwrap(URL(string: "xdripswift://nightscout-follow?url=https%3A%2F%2Fa.example.com&port=8443&token=abc-123")))
        let request = try XCTUnwrap(stateModel.alertRequest)
        request.action()

        XCTAssertEqual(defaults.nightscoutUrl, "https://a.example.com")
        XCTAssertEqual(defaults.nightscoutPort, 8443)
        XCTAssertEqual(defaults.nightscoutToken, "abc-123")
        XCTAssertFalse(defaults.isMaster)
        XCTAssertEqual(verifications, 1)
    }

    @MainActor func testRefusedLinkChangesNothingAndOffersNoAction() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: Self.suiteName) }
        storeUnrelatedSettings(in: defaults)
        storeExistingConnection(in: defaults)
        let before = defaults.dictionaryRepresentation()
        let stateModel = makeStateModel(defaults: defaults)

        stateModel.receiveIncomingURL(try XCTUnwrap(URL(string: "xdripswift://nightscout-follow?url=http%3A%2F%2Fexample.com")))

        let request = try XCTUnwrap(stateModel.alertRequest)
        XCTAssertNil(request.cancelTitle)
        XCTAssertEqual(request.message, NightscoutFollowLinkError.insecureURL.message)
        request.action()
        XCTAssertTrue(changedKeys(from: before, to: defaults.dictionaryRepresentation()).isEmpty)
    }

    @MainActor func testOpenLinkPresentsNothing() throws {
        let stateModel = makeStateModel(defaults: try makeDefaults())

        stateModel.receiveIncomingURL(try XCTUnwrap(URL(string: "xdripswift://open")))

        XCTAssertNil(stateModel.alertRequest)
        XCTAssertNil(stateModel.incomingBackupRequest)
        XCTAssertFalse(stateModel.isPreparingIncomingBackup)
    }
}
