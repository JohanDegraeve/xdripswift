//
//  DexcomShareUploadTests.swift
//  xdripTests
//
//  Created by Paul Plant on 10/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
import SwiftUI
@testable import xdrip

private final class ShareUploadURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))!
    static var delay: TimeInterval = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let result = Self.handler(request)
        let finish = {
            self.client?.urlProtocol(self, didReceive: HTTPURLResponse(url: self.request.url!, statusCode: result.0, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: result.1)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        if Self.delay > 0 { DispatchQueue.global().asyncAfter(deadline: .now() + Self.delay, execute: finish) }
        else { finish() }
    }
    override func stopLoading() {}
}

@MainActor final class DexcomShareUploadTests: XCTestCase {
    private var defaults: UserDefaults!
    private var session: URLSession!
    private var activity: [TroubleshootingLogEntry] = []
    private let readingDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let identifier = Data("\"11111111-2222-3333-4444-555555555555\"".utf8)

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "DexcomShareUploadTests")!
        defaults.removePersistentDomain(forName: "DexcomShareUploadTests")
        defaults.isMaster = true
        defaults.uploadReadingstoDexcomShare = true
        defaults.dexcomShareAccountName = "test-account"
        defaults.dexcomSharePassword = "test-password"
        defaults.dexcomShareUploadSerialNumber = "AB12345678"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ShareUploadURLProtocol.self]
        session = URLSession(configuration: configuration)
        ShareUploadURLProtocol.delay = 0
        activity = []
    }

    override func tearDown() async throws {
        session.invalidateAndCancel()
        defaults.removePersistentDomain(forName: "DexcomShareUploadTests")
        ShareUploadURLProtocol.handler = nil
    }

    private func manager(hasReadings: Bool = true) -> DexcomShareUploadManager {
        let date = readingDate
        return DexcomShareUploadManager(defaults: defaults, session: session, activityHandler: { [weak self] in self?.activity.append($0) }) { _, _ in
            hasReadings ? DexcomShareUploadBatch(readings: [["Value": 123]], latestReading: date) : nil
        }
    }

    func testManualCheckOnlyAuthenticatesAndDoesNotAdvanceUploadCursor() async {
        let requests = LockedRequests()
        let id = identifier
        ShareUploadURLProtocol.handler = { request in
            requests.append(request)
            return (200, id)
        }
        let manager = manager()
        await manager.testConnection()
        XCTAssertEqual(requests.paths.map { URL(fileURLWithPath: $0).lastPathComponent }, ["AuthenticatePublisherAccount", "LoginPublisherAccountById"])
        XCTAssertNotNil(manager.state.lastConnection)
        XCTAssertNil(manager.state.lastUpload)
        XCTAssertNil(defaults.timeStampLatestDexcomShareUploadedBgReading)
        XCTAssertFalse(manager.state.isChecking)
    }

    func testMalformedLoginResponsesAreRejected() async {
        for body in [Data("{}".utf8), Data("\"not-an-id\"".utf8), Data("\"00000000-0000-0000-0000-000000000000\"".utf8), Data()] {
            ShareUploadURLProtocol.handler = { _ in (200, body) }
            let manager = manager()
            await manager.testConnection()
            XCTAssertNotNil(manager.state.authenticationError)
            XCTAssertNil(manager.state.lastConnection)
            XCTAssertFalse(manager.state.isChecking)
        }
    }

    func testKnownLoginErrorIsTranslated() async {
        ShareUploadURLProtocol.handler = { _ in (500, Data("{\"Code\":\"SSO_AuthenticatePasswordInvalid\"}".utf8)) }
        let manager = manager()
        await manager.testConnection()
        XCTAssertEqual(manager.state.authenticationError, Texts_Common.invalidAccountOrPassword)
    }

    func testEmptyHTTPErrorDoesNotCountAsUploadSuccess() async {
        let id = identifier
        ShareUploadURLProtocol.handler = { request in
            request.url!.path.contains("PostReceiver") ? (503, Data()) : (200, id)
        }
        let manager = manager()
        await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil)
        XCTAssertNotNil(manager.state.uploadError)
        XCTAssertNil(manager.state.lastUpload)
        XCTAssertNil(defaults.timeStampLatestDexcomShareUploadedBgReading)
    }

    func testAcceptedAndDuplicateUploadsKeepReadingCursorSeparateFromAcceptanceTime() async {
        let id = identifier
        for duplicate in [false, true] {
            ShareUploadURLProtocol.handler = { request in
                guard request.url!.path.contains("PostReceiver") else { return (200, id) }
                return duplicate ? (500, Data("{\"Code\":\"DuplicateEgvPosted\"}".utf8)) : (200, Data())
            }
            let manager = manager()
            let before = Date()
            await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil)
            XCTAssertEqual(defaults.timeStampLatestDexcomShareUploadedBgReading, readingDate)
            XCTAssertGreaterThanOrEqual(manager.state.lastUpload!, before)
            XCTAssertNil(manager.state.uploadError)
        }
    }

    func testExpiredSessionRetriesOnlyOnce() async {
        let requests = LockedRequests()
        let id = identifier
        ShareUploadURLProtocol.handler = { request in
            requests.append(request)
            return request.url!.path.contains("PostReceiver") ? (500, Data("{\"Code\":\"SessionNotValid\"}".utf8)) : (200, id)
        }
        let manager = manager()
        await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil)
        XCTAssertEqual(requests.paths.filter { $0.contains("PostReceiver") }.count, 2)
        XCTAssertEqual(requests.paths.filter { $0.contains("Authenticate") }.count, 2)
        XCTAssertNotNil(manager.state.uploadError)
        XCTAssertNil(manager.state.lastUpload)
    }

    func testMonitoringRecoveryIsBounded() async {
        let requests = LockedRequests()
        let id = identifier
        ShareUploadURLProtocol.handler = { request in
            requests.append(request)
            if request.url!.path.contains("PostReceiver") { return (500, Data("{\"Code\":\"MonitoringSessionNotActive\"}".utf8)) }
            if request.url!.path.contains("StartRemote") { return (200, Data()) }
            return (200, id)
        }
        let manager = manager()
        await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil)
        XCTAssertEqual(requests.paths.filter { $0.contains("PostReceiver") }.count, 2)
        XCTAssertEqual(requests.paths.filter { $0.contains("StartRemote") }.count, 1)
        XCTAssertNotNil(manager.state.uploadError)
    }

    func testMonitoringRecoveryCanFinishWithAcceptedUpload() async {
        let requests = LockedRequests()
        let id = identifier
        ShareUploadURLProtocol.handler = { request in
            requests.append(request)
            if request.url!.path.contains("PostReceiver") {
                return requests.paths.filter { $0.contains("PostReceiver") }.count == 1
                    ? (500, Data("{\"Code\":\"MonitoringSessionNotActive\"}".utf8)) : (200, Data())
            }
            if request.url!.path.contains("StartRemote") { return (200, Data()) }
            return (200, id)
        }
        let manager = manager()
        await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil)
        XCTAssertNotNil(manager.state.lastUpload)
        XCTAssertNil(manager.state.uploadError)
    }

    func testSuccessfulCheckDoesNotClearSerialNumberUploadFailure() async {
        let id = identifier
        ShareUploadURLProtocol.handler = { request in
            request.url!.path.contains("PostReceiver") ? (500, Data("{\"Code\":\"MonitoredReceiverSerialNumberDoesNotMatch\"}".utf8)) : (200, id)
        }
        let manager = manager()
        await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil)
        await manager.testConnection()
        XCTAssertNil(manager.state.authenticationError)
        XCTAssertEqual(manager.state.uploadError, Texts_DexcomShareTestResult.monitoredReceiverSNDoesNotMatch)
        XCTAssertEqual(DexcomShareUploadPresentation.resolve(defaults: defaults, state: manager.state).status, .failed)
    }

    func testOverlappingChecksShareOneLogin() async {
        let requests = LockedRequests()
        let id = identifier
        ShareUploadURLProtocol.delay = 0.05
        ShareUploadURLProtocol.handler = { request in requests.append(request); return (200, id) }
        let manager = manager()
        async let first: Void = manager.testConnection()
        async let second: Void = manager.testConnection()
        _ = await (first, second)
        XCTAssertEqual(requests.paths.count, 2)
        XCTAssertNotNil(manager.state.lastConnection)
    }

    func testDisablingWhileCheckingIgnoresOldResponse() async throws {
        let id = identifier
        ShareUploadURLProtocol.delay = 0.1
        ShareUploadURLProtocol.handler = { _ in (200, id) }
        let manager = manager()
        let task = Task { await manager.testConnection() }
        try await Task.sleep(nanoseconds: 30_000_000)
        defaults.uploadReadingstoDexcomShare = false
        await task.value
        XCTAssertNil(manager.state.lastConnection)
        XCTAssertNil(manager.state.authenticationError)
        XCTAssertNil(manager.state.lastUpload)
    }

    func testChangingCredentialsDuringCheckInvalidatesOldResponse() async throws {
        let id = identifier
        ShareUploadURLProtocol.delay = 0.1
        ShareUploadURLProtocol.handler = { _ in (200, id) }
        let manager = manager(hasReadings: false)
        let task = Task { await manager.testConnection() }
        try await Task.sleep(nanoseconds: 30_000_000)
        // No automatic replacement request is possible once the credentials are incomplete.
        defaults.dexcomSharePassword = nil
        await task.value
        XCTAssertNil(manager.state.lastConnection)
        XCTAssertNil(manager.state.authenticationError)
    }

    func testObsoleteUploadAcceptanceCannotAdvanceCursor() async {
        for disable in [false, true] {
            let posted = expectation(description: "Upload in flight")
            let id = identifier
            ShareUploadURLProtocol.delay = 0.05
            ShareUploadURLProtocol.handler = { request in
                if request.url!.path.contains("PostReceiver") {
                    posted.fulfill()
                    return (200, Data())
                }
                return (200, id)
            }
            defaults.uploadReadingstoDexcomShare = true
            defaults.dexcomShareUploadSerialNumber = "AB12345678"
            let manager = manager()
            let task = Task { await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil) }
            await fulfillment(of: [posted], timeout: 2)
            if disable { defaults.uploadReadingstoDexcomShare = false }
            else { defaults.dexcomShareUploadSerialNumber = nil }
            await task.value
            XCTAssertNil(defaults.timeStampLatestDexcomShareUploadedBgReading)
            XCTAssertNil(manager.state.lastUpload)
            XCTAssertNil(manager.state.uploadError)
            // The serial-number change now also starts an account-only check. End that work
            // before reusing this defaults suite for the next independently owned manager.
            defaults.uploadReadingstoDexcomShare = false
            await manager.testConnection()
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }

    func testBackgroundLibreUnlockCountWriteDoesNotWaitForSettingsMainQueue() async {
        let defaults = defaults!
        let refresh = DexcomShareUploadSettingsRefresh(state: DexcomShareUploadState(), defaults: defaults)
        let refreshed = expectation(description: "Settings refresh still arrives on main")
        refreshed.assertForOverFulfill = false
        refresh.reload = {
            XCTAssertTrue(Thread.isMainThread)
            refreshed.fulfill()
        }
        let completed = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            // This is the write between Libre 2 notification setup and its unlock payload. A UI
            // observer must not hold the Bluetooth writer until the main queue gets another turn.
            defaults.libreActiveSensorUnlockCount += 1
            completed.signal()
        }
        let result = completed.wait(timeout: .now() + 1)
        XCTAssertEqual(result, .success, "A settings observer blocked the background defaults writer")
        await fulfillment(of: [refreshed], timeout: 3)
        withExtendedLifetime(refresh) {}
    }

    func testParentAndChildUseIdenticalPresentationAndRefreshOnStateChanges() async {
        let state = DexcomShareUploadState()
        let actions = DexcomShareUploadActions(state: state, testConnection: {})
        let parent = SettingsViewGroupedSettingsViewModel.sharingAndServices(dexcomShareUploadActions: actions, uploadDefaults: defaults)
        let child = SettingsViewDexcomShareUploadSettingsViewModel(rowGroup: .connection, actions: actions, defaults: defaults)
        let parentRefreshed = expectation(description: "Services refresh")
        let childRefreshed = expectation(description: "Upload refresh")
        parentRefreshed.assertForOverFulfill = false
        childRefreshed.assertForOverFulfill = false
        parent.storeSectionReloadClosure { parentRefreshed.fulfill() }
        child.storeSectionReloadClosure { childRefreshed.fulfill() }
        state.lastConnection = Date()
        await fulfillment(of: [parentRefreshed, childRefreshed], timeout: 2)
        for scenario in ["healthy", "failed", "stale"] {
            state.uploadError = scenario == "failed" ? "Upload failed" : nil
            state.lastConnection = Date(timeIntervalSinceNow: scenario == "stale" ? -311 : 0)
            let parentRow = parent.settingsRows(sectionID: 0).first { $0.id == "sharingServices.dexcomShare" }!
            let childRow = child.settingsRows(sectionID: 0).first { $0.id.hasSuffix("status") }!
            XCTAssertEqual(parentRow.detail, Texts_Common.enabled)
            XCTAssertEqual(parentRow.detailIndicator?.color, childRow.detailIndicator?.color)
        }
    }

    func testUploadActivityIncludesToggleChangesAccountChecksAndUploadOutcomes() async {
        let id = identifier
        var fail = true
        ShareUploadURLProtocol.handler = { request in
            request.url!.path.contains("PostReceiver")
                ? (fail ? 500 : 200, Data()) : (200, id)
        }
        let manager = manager()
        await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil)
        await manager.testConnection()
        XCTAssertEqual(activity.map(\.kind), [
            .integration(name: .dexcomShareUploadAccount, activity: .succeeded(itemCount: nil)),
            .integration(name: .dexcomShareUpload, activity: .failed),
            .integration(name: .dexcomShareUploadAccount, activity: .succeeded(itemCount: nil))
        ])
        fail = false
        await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil)
        XCTAssertEqual(activity.last?.kind, .integration(name: .dexcomShareUpload, activity: .succeeded(itemCount: 1)))
        defaults.uploadReadingstoDexcomShare = false
        await manager.testConnection() // Reconcile synchronously, without depending on KVO delivery.
        XCTAssertEqual(activity.last?.kind, .configuration(.dexcomShareUploadChanged(enabled: false)))
        defaults.uploadReadingstoDexcomShare = true
        await manager.testConnection()
        XCTAssertEqual(activity.filter { $0.kind == .configuration(.dexcomShareUploadChanged(enabled: true)) }.count, 1)
    }

    func testAuthenticationFailureIsLoggedWithoutAccountDetails() async throws {
        ShareUploadURLProtocol.handler = { _ in (500, Data("{\"Code\":\"SSO_AuthenticatePasswordInvalid\"}".utf8)) }
        let manager = manager()
        await manager.testConnection()
        XCTAssertEqual(activity.map(\.kind), [.integration(name: .dexcomShareUploadAccount, activity: .failed)])
        let data = try JSONEncoder().encode(activity)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("test-account"))
        XCTAssertFalse(text.contains("test-password"))
    }

    func testEnablingAutomaticallyVerifiesAccountWithoutSerialOrWhileScheduledOff() async {
        for missingSerial in [false, true] {
            defaults.uploadReadingstoDexcomShare = false
            defaults.dexcomShareUploadSerialNumber = missingSerial ? nil : "AB12345678"
            defaults.dexcomShareUploadUseSchedule = !missingSerial
            defaults.dexcomShareUploadSchedule = "0"
            let verified = expectation(description: "Automatic account check")
            let requests = LockedRequests()
            let id = identifier
            ShareUploadURLProtocol.handler = { request in requests.append(request); return (200, id) }
            let manager = DexcomShareUploadManager(defaults: defaults, session: session, activityHandler: { entry in
                if entry.kind == .integration(name: .dexcomShareUploadAccount, activity: .succeeded(itemCount: nil)) { verified.fulfill() }
            }, makeBatch: { _, _ in XCTFail("Must not upload"); return nil })
            defaults.uploadReadingstoDexcomShare = true
            await fulfillment(of: [verified], timeout: 2)
            try? await Task.sleep(nanoseconds: 50_000_000)
            XCTAssertEqual(requests.paths.count, 2)
            XCTAssertNotNil(manager.state.lastConnection)
            XCTAssertNil(manager.state.lastUpload)
        }
    }

    func testOldCursorCannotCreateUnboundedUploadAnd413KeepsCursor() async {
        let oldCursor = Date(timeIntervalSinceNow: -365 * 24 * 60 * 60)
        defaults.timeStampLatestDexcomShareUploadedBgReading = oldCursor
        let id = identifier
        ShareUploadURLProtocol.handler = { request in
            request.url!.path.contains("PostReceiver") ? (413, Data("<html>413 Request Entity Too Large</html>".utf8)) : (200, id)
        }
        var queriedFrom: Date?
        let manager = DexcomShareUploadManager(defaults: defaults, session: session, activityHandler: { _ in }) { fromDate, _ in
            queriedFrom = fromDate
            return DexcomShareUploadBatch(readings: [["Value": 123]], latestReading: Date())
        }
        await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil)
        XCTAssertGreaterThan(queriedFrom!, Date(timeIntervalSinceNow: -8 * 60 * 60 - 1))
        XCTAssertEqual(defaults.timeStampLatestDexcomShareUploadedBgReading, oldCursor)
        XCTAssertEqual(manager.state.uploadError, Texts_SettingsView.shareUploadTooLarge)
        await manager.testConnection()
        XCTAssertNil(manager.state.authenticationError)
        XCTAssertNotNil(manager.state.lastConnection)
        XCTAssertEqual(DexcomShareUploadPresentation.resolve(defaults: defaults, state: manager.state).title, Texts_SettingsView.shareUploadFailed)
    }

    func testPresentationAgeConfigurationAndSchedulePrecedence() {
        let state = DexcomShareUploadState()
        let now = Date()
        func status() -> DexcomShareUploadPresentation.Status {
            DexcomShareUploadPresentation.resolve(defaults: defaults, state: state, now: now).status
        }
        XCTAssertEqual(status(), .unchecked)
        state.isChecking = true
        XCTAssertEqual(status(), .checking)
        state.isChecking = false
        state.lastConnection = now.addingTimeInterval(-310)
        XCTAssertEqual(status(), .verified)
        state.lastConnection = now.addingTimeInterval(-311)
        XCTAssertEqual(status(), .stale)
        defaults.dexcomShareUploadUseSchedule = true
        defaults.dexcomShareUploadSchedule = "0"
        XCTAssertEqual(status(), .paused)
        state.uploadError = "Upload failed"
        XCTAssertEqual(status(), .failed)
        defaults.dexcomShareUploadSerialNumber = nil
        XCTAssertEqual(status(), .incomplete)
        defaults.isMaster = false
        XCTAssertEqual(status(), .unavailable)
        defaults.uploadReadingstoDexcomShare = false
        XCTAssertEqual(status(), .disabled)
        XCTAssertNil(DexcomShareUploadPresentation.resolve(defaults: defaults, state: state).indicator)
    }

    func testSettingsRowsAndSimulatorLayouts() async throws {
        let state = DexcomShareUploadState()
        let actions = DexcomShareUploadActions(state: state, testConnection: {})
        let connection = SettingsViewDexcomShareUploadSettingsViewModel(rowGroup: .connection, actions: actions, defaults: defaults)
        let account = SettingsViewDexcomShareUploadSettingsViewModel(rowGroup: .account, actions: actions, defaults: defaults)
        XCTAssertNotEqual(account.settingsRows(sectionID: 0).last?.detail, defaults.dexcomSharePassword)
        XCTAssertEqual(connection.settingsRows(sectionID: 0).first { $0.id.hasSuffix("status") }?.detail,
                       DexcomShareUploadPresentation.resolve(defaults: defaults, state: state).title)
        for scenario in ["disabled", "incomplete", "checking", "verified", "failed", "paused"] {
            state.reset()
            defaults.uploadReadingstoDexcomShare = scenario != "disabled"
            defaults.dexcomShareUploadSerialNumber = scenario == "incomplete" ? nil : "AB12345678"
            defaults.dexcomShareUploadUseSchedule = scenario == "paused"
            defaults.dexcomShareUploadSchedule = "0"
            state.isChecking = scenario == "checking"
            if scenario == "verified" { state.lastConnection = Date(); state.lastUpload = Date() }
            if scenario == "failed" { state.uploadError = Texts_DexcomShareTestResult.monitoredReceiverSNDoesNotMatch }
            let testRow = connection.settingsRows(sectionID: 0).first { $0.id.hasSuffix("test") }
            if scenario == "checking" { XCTAssertEqual(testRow?.isEnabled, false) }
            let presenter = SettingsActionPresenter(router: SettingsRouter())
            let screen = SettingsScreen(title: Texts_SettingsView.sectionTitleDexcomShareUpload, onlineHelpTopic: .dexcomShareService, providers: {
                DexcomShareUploadRowGroup.allCases.map {
                    SettingsViewDexcomShareUploadSettingsViewModel(rowGroup: $0, actions: actions, defaults: self.defaults)
                }
            })
            let host = UIHostingController(rootView: NavigationStack {
                SettingsScreenDestinationView(settingsScreen: screen, presenter: presenter)
            }.preferredColorScheme(.dark))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            try await Task.sleep(nanoseconds: 200_000_000)
            host.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(size: host.view.bounds.size).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "Share-upload-" + scenario
            attachment.lifetime = .keepAlways
            add(attachment)
            if scenario == "failed" || scenario == "paused" {
                func findScrollView(_ view: UIView) -> UIScrollView? {
                    if let scroll = view as? UIScrollView { return scroll }
                    return view.subviews.lazy.compactMap { findScrollView($0) }.first
                }
                if let scroll = findScrollView(host.view) {
                    scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                    try await Task.sleep(nanoseconds: 100_000_000)
                    let lower = UIGraphicsImageRenderer(size: host.view.bounds.size).image { _ in
                        host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
                    }
                    let attachment = XCTAttachment(image: lower)
                    attachment.name = "Share-upload-" + scenario + "-activity"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
            window.isHidden = true
        }
    }

    func testDiagnosticCodesExcludeDescriptionsURLsAndUnknownDomains() {
        let requestURL = "https://example.invalid/?sessionId=private-session"
        let transportError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [
            NSLocalizedDescriptionKey: "test-account test-password " + requestURL,
            NSURLErrorFailingURLErrorKey: URL(string: requestURL)!
        ])
        XCTAssertEqual(DexcomShareUploadManager.diagnosticCode(for: transportError), "NSURLErrorDomain code=-1001")
        XCTAssertEqual(DexcomShareUploadManager.diagnosticCode(for: NSError(domain: requestURL, code: 42)), "NSError code=42")
    }

    func testAgeRefreshStartsWhenConnectionRowsBecomeVisible() async throws {
        let state = DexcomShareUploadState()
        let refreshed = expectation(description: "Age refresh after enabling uploads")
        refreshed.assertForOverFulfill = false
        let host = UIHostingController(rootView: ShareUploadAgeRefreshHost(state: state, refresh: { refreshed.fulfill() }))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        // The list first appears without connection rows, then enabling the service adds them.
        try await Task.sleep(nanoseconds: 200_000_000)
        state.isChecking = true
        await fulfillment(of: [refreshed], timeout: 2)
    }

    func testScheduleStopsAutomaticUploadButAllowsManualCheck() async {
        let requests = LockedRequests()
        let id = identifier
        defaults.dexcomShareUploadUseSchedule = true
        defaults.dexcomShareUploadSchedule = "0"
        ShareUploadURLProtocol.handler = { request in requests.append(request); return (200, id) }
        let manager = manager()
        await manager.uploadIfNeeded(lastConnectionStatusChangeTimeStamp: nil)
        XCTAssertTrue(requests.paths.isEmpty)
        await manager.testConnection()
        XCTAssertEqual(requests.paths.count, 2)
        XCTAssertNil(manager.state.lastUpload)
    }
}

private final class LockedRequests {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    func append(_ request: URLRequest) { lock.lock(); defer { lock.unlock() }; requests.append(request) }
    var paths: [String] { lock.lock(); defer { lock.unlock() }; return requests.map { $0.url!.path } }
}

/// Models the same list staying on screen while the connection rows become relevant.
private struct ShareUploadAgeRefreshHost: View {
    @ObservedObject var state: DexcomShareUploadState
    let refresh: () -> Void

    var body: some View {
        Color.clear
            .modifier(DexcomShareUploadAgeRefresh(isRelevant: state.isChecking, refresh: refresh))
            .environment(\.scenePhase, .active)
    }
}
