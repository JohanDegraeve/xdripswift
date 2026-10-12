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
