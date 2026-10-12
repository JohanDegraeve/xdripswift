//
//  OttaiServerActivationTests.swift
//  xdripTests
//
//  Server-assisted activation of new Syai sensors.
//

import XCTest
@testable import xdrip

final class OttaiServerActivationTests: XCTestCase {

    // MARK: - entry mode

    private func mode(keys: Bool = false, pendingBind: Bool = false, bootstrap: Bool = true,
                      session: Bool = true, requested: Bool = true) -> OttaiAuthEntryMode {
        ottaiAuthEntryMode(hasAuthKeys: keys, pendingBind: pendingBind, bootstrapPending: bootstrap,
                           sessionAvailable: session, activationRequested: requested)
    }

    func testStoredKeysAlwaysWin() {
        XCTAssertEqual(mode(keys: true, pendingBind: true), .storedMaterialAuth)
    }

    func testPendingBindNeverActivatesAgain() {
        XCTAssertEqual(mode(pendingBind: true), .awaitingBind)
    }

    func testServerActivationNeedsTheUsersRequest() {
        XCTAssertEqual(mode(requested: false), .blocked)
        XCTAssertEqual(mode(), .serverAssistedActivation)
    }

    func testServerActivationNeedsAV3CheckAndASession() {
        XCTAssertEqual(mode(bootstrap: false), .blocked)
        XCTAssertEqual(mode(session: false), .blocked)
    }

    // MARK: - validateDeviceByMacV3 (China; Syai always uses V3)

    func testChinaMovesOnToV3OnlyOnUpgradeCode() {
        XCTAssertTrue(OttaiCloudClient.shouldTryValidateV3(apiBase: OttaiConstants.apiBase, profile: .cnPhone, v2FailureCode: "AppDevice_Upgrade_Version"))
        XCTAssertFalse(OttaiCloudClient.shouldTryValidateV3(apiBase: OttaiConstants.apiBase, profile: .cnPhone, v2FailureCode: "AppDevice_AlreadyUsed"))
        XCTAssertFalse(OttaiCloudClient.shouldTryValidateV3(apiBase: OttaiConstants.apiBase, profile: .watch, v2FailureCode: "AppDevice_Upgrade_Version"))
        XCTAssertFalse(OttaiCloudClient.shouldTryValidateV3(apiBase: OttaiConstants.apiBaseGlobal, profile: .watch, v2FailureCode: "AppDevice_Upgrade_Version"))
    }

    func testChinaBindV3Body() {
        let body = OttaiCloudClient.bindRequestBody(mac: "6CA04230E260", deviceVersion: "v", userId: "42", activeTime: 1_760_000_000, contract: .v3)
        XCTAssertEqual(body["newBindType"] as? Int, 2)
        XCTAssertEqual(body["userId"] as? String, "42")
    }

    // MARK: - Syai client

    func testUnbindTypeFollowsWearTime() {
        var m = OttaiRegistry.DeviceMaterials()
        m.activeTimeMs = 1_000_000
        m.activeExpireTimeMs = 15 * 86_400_000
        XCTAssertEqual(OttaiCloudClient.syaiUnbindType(materials: m, acceptedMaxActiveMs: 0, nowMs: 1_000_000 + 16 * 86_400_000), 10)
        XCTAssertEqual(OttaiCloudClient.syaiUnbindType(materials: m, acceptedMaxActiveMs: 0, nowMs: 1_000_000 + 86_400_000), 13)
    }

    func testTraceIdIsVersion1() {
        let id = OttaiSyaiClient.traceId()
        let parts = id.split(separator: "-")
        XCTAssertEqual(parts.map(\.count), [8, 4, 4, 4, 12])
        XCTAssertEqual(parts[2].first, "1")
    }

    func testJwtPayload() {
        // {"sub":"42","app_name":"Syai Tag"}
        let jwt = "x.eyJzdWIiOiI0MiIsImFwcF9uYW1lIjoiU3lhaSBUYWcifQ.y"
        XCTAssertEqual(OttaiSyaiClient.jwtPayload(jwt)?["sub"] as? String, "42")
        XCTAssertEqual(OttaiSyaiClient.jwtPayload(jwt)?["app_name"] as? String, "Syai Tag")
    }

    func testUploadAddsCheckpointEveryFifthReading() {
        func sample(_ n: Int) -> OttaiCloudUploader.Sample {
            OttaiCloudUploader.Sample(dataNo: n, runtimeSec: n * 60, voltage: 1, rawCurrent: 2, temperatureC: 30, mmol: 5.5,
                                      sampleMs: 0, receivedAtMs: 0, originBytes: [1, 2], live: true)
        }
        var m = OttaiRegistry.DeviceMaterials()
        m.deviceId = 7
        let list = OttaiCloudUploader.uploadBody(batch: [sample(4), sample(5)], materials: m)["dataList"] as? [[String: Any]]
        XCTAssertEqual(list?.map { $0["dataType"] as? Int }, [1, 1, 2])
        XCTAssertTrue(list?[2]["origin"] is NSNull)
    }

    // MARK: - firmware -> deviceVersion

    func testDeviceVersionFromFirmware() {
        XCTAssertEqual(OttaiCloudClient.deviceVersion(fromFirmware: "E2.0.3(V1.7.SH22601.3),STDRD"), "V1.7.SH22601.3")
        XCTAssertEqual(OttaiCloudClient.deviceVersion(fromFirmware: " V1.7.S2530.1 "), "V1.7.S2530.1")
        XCTAssertEqual(OttaiCloudClient.deviceVersion(fromFirmware: "E1.1()"), "E1.1()")
    }
}

final class OttaiUploadOutboxTests: XCTestCase {
    private var directory: URL!
    private var file: URL { directory.appendingPathComponent("sensor.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func sample(_ n: Int, mmol: Double = 5.5) -> OttaiCloudUploader.Sample {
        OttaiCloudUploader.Sample(dataNo: n, runtimeSec: n * 60, voltage: 123, rawCurrent: 4567,
                                  temperatureC: 31.25, mmol: mmol, sampleMs: 123456789,
                                  receivedAtMs: 123456999, originBytes: [0, 1, 128, 255], live: true)
    }

    func testRestartRestoresCompleteRawSample() throws {
        try OttaiUploadOutbox(url: file).enqueue(sample(7), account: "A", limit: 4000)
        let restored = try XCTUnwrap(OttaiUploadOutbox(url: file).pending(account: "A").first)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(restored), try encoder.encode(sample(7)))
    }

    func testAcknowledgementSurvivesRestartAndDeduplicatesBackfill() throws {
        let store = try OttaiUploadOutbox(url: file)
        try store.enqueue(sample(7), account: "A", limit: 4000)
        try store.enqueue(sample(8), account: "A", limit: 4000)
        try store.acknowledge([sample(7)], account: "A")
        let restored = try OttaiUploadOutbox(url: file)
        try restored.enqueue(sample(7), account: "A", limit: 4000)
        XCTAssertEqual(restored.pending(account: "A").map(\.dataNo), [8])
    }

    func testUnacknowledgedBatchRemainsAfterRestart() throws {
        let store = try OttaiUploadOutbox(url: file)
        try store.enqueue(sample(7), account: "A", limit: 4000)
        _ = store.pending(account: "A") // Sending a batch does not remove it.
        XCTAssertEqual(try OttaiUploadOutbox(url: file).pending(account: "A").map(\.dataNo), [7])
    }

    func testAccountsStaySeparateIncludingTheirAcknowledgements() throws {
        let store = try OttaiUploadOutbox(url: file)
        try store.enqueue(sample(7), account: "A", limit: 4000)
        try store.enqueue(sample(7), account: "B", limit: 4000)
        try store.acknowledge([sample(7)], account: "A")
        let restored = try OttaiUploadOutbox(url: file)
        XCTAssertTrue(restored.pending(account: "A").isEmpty)
        XCTAssertEqual(restored.pending(account: "B").map(\.dataNo), [7])
    }

    func testUnownedReadingsAssignedOnlyOnce() throws {
        let store = try OttaiUploadOutbox(url: file)
        try store.enqueue(sample(7), account: "", limit: 4000)
        try store.assignUnownedSamples(to: "A", limit: 4000)
        try store.assignUnownedSamples(to: "B", limit: 4000)
        let restored = try OttaiUploadOutbox(url: file)
        XCTAssertEqual(restored.pending(account: "A").map(\.dataNo), [7])
        XCTAssertTrue(restored.pending(account: "B").isEmpty)
        XCTAssertTrue(restored.pending(account: "").isEmpty)
    }

    func testPendingReplacementAndCapacitySurviveRestart() throws {
        let store = try OttaiUploadOutbox(url: file)
        for n in 1...3 { try store.enqueue(sample(n), account: "A", limit: 2) }
        try store.enqueue(sample(3, mmol: 6.2), account: "A", limit: 2)
        let pending = try OttaiUploadOutbox(url: file).pending(account: "A")
        XCTAssertEqual(pending.map(\.dataNo), [2, 3])
        XCTAssertEqual(pending.last?.mmol, 6.2)
    }

    func testCorruptStoreIsNotSilentlyReplaced() throws {
        let corrupt = Data("invalid JSON".utf8)
        try corrupt.write(to: file)
        XCTAssertThrowsError(try OttaiUploadOutbox(url: file))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }

    func testFailedWriteCanBeRetriedWithoutLosingSample() throws {
        let blocked = directory.appendingPathComponent("blocked")
        try Data().write(to: blocked) // Parent is a file, so creating a directory fails.
        let destination = blocked.appendingPathComponent("sensor.json")
        let store = try OttaiUploadOutbox(url: destination)
        XCTAssertThrowsError(try store.enqueue(sample(7), account: "A", limit: 4000))
        try FileManager.default.removeItem(at: blocked)
        try store.save()
        XCTAssertEqual(try OttaiUploadOutbox(url: destination).pending(account: "A").map(\.dataNo), [7])
    }
}
