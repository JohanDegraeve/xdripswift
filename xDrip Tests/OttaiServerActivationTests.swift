//
//  OttaiServerActivationTests.swift
//  xdripTests
//
//  Server-assisted activation of new Syai sensors.
//

import XCTest
import CryptoKit
@testable import xdrip

final class OttaiServerActivationTests: XCTestCase {

    func testServerSignatureRejectionRetriesThenScansForAnotherSensor() {
        let code = "DEVICE_AUTH_SIGN_ERROR"
        XCTAssertEqual(ottaiServerAuthRecovery(code: code, signatureFailures: 1, activateSent: false), .retryConnection)
        XCTAssertEqual(ottaiServerAuthRecovery(code: code, signatureFailures: 2, activateSent: false), .scanNextSensor)
        // A different device gets its own fresh-challenge retry.
        XCTAssertEqual(ottaiServerAuthRecovery(code: code, signatureFailures: 1, activateSent: false), .retryConnection)
    }

    func testServerAuthRecoveryNeverRetriesAfterActivationWasSent() {
        for failures in [1, 2, 3] {
            XCTAssertEqual(ottaiServerAuthRecovery(code: "DEVICE_AUTH_SIGN_ERROR", signatureFailures: failures, activateSent: true), .stop)
        }
    }

    func testOtherServerErrorsDoNotExcludeBluetoothSensors() {
        for code in ["", "AuthFailed_LoginElsewhere", "DEVICE_ALREADY_USED", "DEVICE_AUTH_SIGN_ERROR_OTHER"] {
            XCTAssertEqual(ottaiServerAuthRecovery(code: code, signatureFailures: 2, activateSent: false), .stop)
        }
    }

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

final class OttaiCloudOperationTests: XCTestCase {
    func testConcurrentOperationsKeepTheirOwnFailure() {
        let firstStarted = DispatchSemaphore(value: 0)
        let secondFinished = DispatchSemaphore(value: 0)
        let finished = expectation(description: "both operations finished")
        finished.expectedFulfillmentCount = 2
        DispatchQueue.global().async {
            let result = OttaiCloudClient.perform {
                OttaiCloudClient.lastFailure = .init(text: "activation refused", code: "activation")
                firstStarted.signal()
                XCTAssertEqual(secondFinished.wait(timeout: .now() + 3), .success)
                return false
            }
            XCTAssertEqual(result.failure?.code, "activation")
            finished.fulfill()
        }
        DispatchQueue.global().async {
            XCTAssertEqual(firstStarted.wait(timeout: .now() + 3), .success)
            let result = OttaiCloudClient.perform {
                OttaiCloudClient.lastFailure = .init(text: "upload failed", code: "upload")
                return false
            }
            XCTAssertEqual(result.failure?.code, "upload")
            secondFinished.signal()
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }

    func testResultKeepsFailureAcrossQueueHandoff() {
        let finished = expectation(description: "result delivered")
        DispatchQueue.global().async {
            let result = OttaiCloudClient.perform {
                OttaiCloudClient.lastFailure = .init(text: "sign-in failed", code: "auth")
                return false
            }
            _ = OttaiCloudClient.perform { OttaiCloudClient.lastFailure = nil }
            DispatchQueue.main.async {
                XCTAssertEqual(result.errorText, "sign-in failed")
                XCTAssertEqual(result.failure?.code, "auth")
                finished.fulfill()
            }
        }
        wait(for: [finished], timeout: 3)
    }

    func testNestedOperationsRestoreOuterFailureAndStartClean() {
        let outer = OttaiCloudClient.perform {
            OttaiCloudClient.lastFailure = .init(text: "outer", code: "outer")
            let inner = OttaiCloudClient.perform { true }
            XCTAssertNil(inner.failure)
            XCTAssertEqual(OttaiCloudClient.lastFailure?.code, "outer")
            return false
        }
        XCTAssertEqual(outer.failure?.code, "outer")
        XCTAssertNil(OttaiCloudClient.perform { true }.failure)
    }

    func testNewBoundIdIsSavedBeforeFirstUpload() {
        var materials = OttaiRegistry.DeviceMaterials()
        materials.deviceId = 10
        var saved: [Int] = []
        let ready = OttaiCloudUploader.refreshBoundDeviceId(&materials, lookup: {
            XCTAssertEqual(saved, [0])
            return .thisSensor(deviceId: 20)
        }, save: { saved.append($0) })
        XCTAssertTrue(ready)
        XCTAssertEqual(materials.deviceId, 20)
        XCTAssertEqual(saved, [0, 20])
        XCTAssertEqual(OttaiCloudUploader.uploadBody(batch: [], materials: materials)["deviceId"] as? Int, 20)
    }

    func testFailedOrUnconfirmedLookupCannotReuseOldId() {
        let replies: [OttaiCloudClient.BindState?] = [nil, .unbound, .other("other"), .thisSensor(deviceId: 0)]
        for reply in replies {
            var materials = OttaiRegistry.DeviceMaterials()
            materials.deviceId = 10
            var saved: [Int] = []
            XCTAssertFalse(OttaiCloudUploader.refreshBoundDeviceId(&materials, lookup: { reply }, save: { saved.append($0) }))
            XCTAssertEqual(materials.deviceId, 0)
            XCTAssertEqual(saved, [0])
        }
    }
}

final class OttaiServerDurationTests: XCTestCase {
    private let key = "00112233445566778899aabbccddeeff"

    private func frames(seconds: Int64 = 14 * 86_400) throws -> (duration: [UInt8], activate: [UInt8]) {
        let plain = (0..<4).map { UInt8(truncatingIfNeeded: seconds >> ($0 * 8)) }
        return (try XCTUnwrap(OttaiCrypto.encryptPayload(plain, sessionKeyHex: key)),
                try XCTUnwrap(OttaiCrypto.encryptActivateCmd([3], sessionKeyHex: key)))
    }

    func testVerifiedSessionTriesThirtyDownToFifteenThenServerDuration() throws {
        let f = try frames()
        let plan = try XCTUnwrap(OttaiServerDurationPlan.verified(keyHex: key, duration: f.duration, activate: f.activate))
        XCTAssertEqual(plan.candidates, Array(stride(from: Int64(30), through: 15, by: -1)).map { $0 * 86_400 } + [14 * 86_400])
        let frame = try XCTUnwrap(plan.frame(at: 0, original: f.duration))
        let plain = try XCTUnwrap(OttaiCrypto.aesECB(.decrypt, key: OttaiCrypto.hexToBytes(key), data: frame, pkcs7Padded: false))
        XCTAssertEqual(Array(plain.prefix(4)), [0x00, 0x8D, 0x27, 0x00])
        XCTAssertTrue(plain.dropFirst(4).allSatisfy { $0 == 0 })
        XCTAssertEqual(plan.frame(at: plan.candidates.count - 1, original: f.duration), f.duration)
    }

    func testUnknownKeyOrWrongSessionNeverOverridesServerFrame() throws {
        let f = try frames()
        for candidate in ["", "bad", String(repeating: "ff", count: 16)] {
            XCTAssertNil(OttaiServerDurationPlan.verified(keyHex: candidate, duration: f.duration, activate: f.activate))
        }
        let wrongCommand = try XCTUnwrap(OttaiCrypto.encryptActivateCmd([4], sessionKeyHex: key))
        XCTAssertNil(OttaiServerDurationPlan.verified(keyHex: key, duration: f.duration, activate: wrongCommand))
    }

    func testInvalidDurationOrPaddingCannotAuthorizeOverride() throws {
        let invalid = try frames(seconds: 1)
        XCTAssertNil(OttaiServerDurationPlan.verified(keyHex: key, duration: invalid.duration, activate: invalid.activate))
        let valid = try frames()
        var plain: [UInt8] = [0, 0x75, 0x12, 0]
        plain += [1] // Unknown frame fields must not be discarded.
        let frame = try XCTUnwrap(OttaiCrypto.encryptPayload(plain, sessionKeyHex: key))
        XCTAssertNil(OttaiServerDurationPlan.verified(keyHex: key, duration: frame, activate: valid.activate))
    }

    func testOnlyDurationOrRTCFailureBeforeActivateStepsDown() throws {
        let f = try frames()
        let plan = try XCTUnwrap(OttaiServerDurationPlan.verified(keyHex: key, duration: f.duration, activate: f.activate))
        XCTAssertEqual(plan.nextIndex(after: 0, durationOrRTCFailed: true, activateSent: false), 1)
        XCTAssertNil(plan.nextIndex(after: 0, durationOrRTCFailed: false, activateSent: false))
        XCTAssertNil(plan.nextIndex(after: 0, durationOrRTCFailed: true, activateSent: true))
        XCTAssertNil(plan.nextIndex(after: plan.candidates.count - 1, durationOrRTCFailed: true, activateSent: false))
        XCTAssertNil(plan.frame(at: -1, original: f.duration))
    }

    func testNeverShortensLongerServerLifetime() throws {
        let f = try frames(seconds: 35 * 86_400)
        let plan = try XCTUnwrap(OttaiServerDurationPlan.verified(keyHex: key, duration: f.duration, activate: f.activate))
        XCTAssertEqual(plan.candidates, [35 * 86_400])
        XCTAssertEqual(plan.frame(at: 0, original: f.duration), f.duration)
    }
}

extension OttaiServerDurationTests {
    func testVerificationReportsSpecificReasonsWithoutSecrets() throws {
        let f = try frames()
        func failure(_ kb: String, _ d: [UInt8], _ c: [UInt8]) -> OttaiServerDurationPlan.VerificationFailure? {
            switch OttaiServerDurationPlan.verification(keyHex: kb, duration: d, activate: c) {
            case .success: return nil
            case .failure(let reason): return reason
            }
        }
        XCTAssertEqual(failure("", f.duration, f.activate), .missingKey)
        XCTAssertEqual(failure(" \n", f.duration, f.activate), .missingKey)
        XCTAssertEqual(failure("zz", f.duration, f.activate), .invalidKeyHex)
        XCTAssertEqual(failure("00", f.duration, f.activate), .invalidKeyLength)
        XCTAssertEqual(failure(key, [], f.activate), .invalidDurationLength)
        XCTAssertEqual(failure(key, f.duration, []), .invalidActivateLength)
        let wrongKey = String(repeating: "ff", count: 16)
        let mismatch = try XCTUnwrap(failure(wrongKey, f.duration, f.activate))
        XCTAssertEqual(mismatch, .activateMismatch)
        XCTAssertFalse(mismatch.rawValue.contains(wrongKey))
        XCTAssertFalse(mismatch.rawValue.contains(key))
        let badPadding = try XCTUnwrap(OttaiCrypto.encryptPayload([0, 0x75, 0x12, 0, 1], sessionKeyHex: key))
        XCTAssertEqual(failure(key, badPadding, f.activate), .invalidDurationPadding)
        let invalid = try frames(seconds: 1)
        XCTAssertEqual(failure(key, invalid.duration, invalid.activate), .invalidDurationRange)
        XCTAssertNil(failure(key, f.duration, f.activate))
    }
}

final class OttaiRecordWidthBackportTests: XCTestCase {
    func testLowCurrentHistoryCannotPoisonLearnedWidth() {
        let page = OttaiCrypto.hexToBytes("00000000d7140000ce0344e0898a13660cc60344e0798b13740cae0344e0698c137e0c870344e0598d13890c870344e0498e13920c870344e0398f139b0c6f0344e0299013a30c770344e0199113ac0c7f0344e0099213b50c770344e0f99213bd0c770344e0e99313c80c6f0344e0d99413cd0c7f0344e0c99513d60c870344e0b99613d50c9f0344e0a99713c50cbe0344e0999813bd0cdd0344e0899913b50c00000000000000")
        XCTAssertNil(OttaiParser.contentRecordSize(page))
        XCTAssertEqual(OttaiParser.chooseRecordSize(page, deviceVersion: "", learned: 9), 9)
        XCTAssertEqual(OttaiParser.frameRecords(page, deviceVersion: "", learned: 9).count, 17)
    }
    func testVersionCannotForceWidthThatDoesNotFit() {
        let page: [UInt8] = Array(repeating: 0, count: 16)
        XCTAssertEqual(OttaiParser.chooseRecordSize(page, deviceVersion: "E1.2.3", learned: 9), 8)
        XCTAssertEqual(OttaiParser.frameRecords(page, deviceVersion: "E1.2.3", learned: 9).count, 1)
    }
}

final class OttaiTimeBackportTests: XCTestCase {
    func testCorrectionRequiresIndependentFramesAndStaysWithinOneMinute() {
        var correction = OttaiArrivalStartCorrection()
        correction.seed(start: 1_000_000, arrivalStart: 1_000_000)
        XCTAssertNil(correction.accept(anchor: 1_000_000, counter: 10, received: 1_585_000))
        XCTAssertNil(correction.accept(anchor: 1_000_000, counter: 10, received: 1_585_000))
        XCTAssertEqual(correction.accept(anchor: 1_000_000, counter: 11, received: 1_645_000), 985_000)
        correction.seed(start: 1_000_000, arrivalStart: 1_000_000)
        XCTAssertNil(correction.accept(anchor: 1_000_000, counter: 100, received: 1_585_000))
        XCTAssertNil(correction.accept(anchor: 1_000_000, counter: 101, received: 1_645_000))
    }
    func testHistorySeedCannotBeCorrectedFromArrivals() {
        var correction = OttaiArrivalStartCorrection()
        correction.seed(start: 1_000_000, arrivalStart: 0)
        XCTAssertNil(correction.accept(anchor: 1_000_000, counter: 10, received: 1_585_000))
        XCTAssertNil(correction.accept(anchor: 1_000_000, counter: 11, received: 1_645_000))
    }
}

final class OttaiRegionalTransportTests: XCTestCase {
    func testBothMobileTokenShapes() {
        XCTAssertEqual(OttaiCloudClient.mobileAccessToken(["accessToken":"legacy"]), "legacy")
        XCTAssertEqual(OttaiCloudClient.mobileAccessToken(["jwtToken":["accessToken":"secure"]]), "secure")
    }

    func testRegionsAndLegacyWatchIsolation() {
        let path = "/cgm/app/server/user/apiToken"
        XCTAssertNotNil(OttaiRegionalTransport.route("https://seas.ottai.com" + path, headers: [:]))
        XCTAssertNil(OttaiRegionalTransport.route("https://api.syai.com" + path, headers: [:]))
        XCTAssertNil(OttaiRegionalTransport.route("https://api.ottai.com" + path, headers: ["appName":"watch"]))
        XCTAssertNotNil(OttaiRegionalTransport.route("https://api.ottai.com" + path, headers: ["appName":"ottai", "packageName":"com.ottai.tag"]))
        XCTAssertNil(OttaiRegionalTransport.route("http://seas.ottai.com" + path, headers: [:]))
    }

    func testEncryptedExchangeRequestAndBusinessFailure() throws {
        let result = try encryptedRequest()
        XCTAssertEqual(result.json["code"] as? String, "DEVICE_AUTH_SIGN_ERROR")
    }

    func testChangedReplyCannotPassAuthentication() {
        XCTAssertThrowsError(try encryptedRequest(tamperReply: true))
    }

    func testInvalidExchangeStopsBeforeSendingBusinessRequest() throws {
        let route = try XCTUnwrap(OttaiRegionalTransport.route("https://seas.ottai.com/cgm/app/server/test", headers: [:]))
        var calls = 0
        XCTAssertThrowsError(try OttaiRegionalTransport.request("GET", route: route, body: nil, headers: ["deviceId": "test"]) { _, _, _, _ in
            calls += 1
            return (200, ["data": ["serverSignature": "wrong"]])
        })
        XCTAssertEqual(calls, 1)
    }

    private func encryptedRequest(tamperReply: Bool = false) throws -> OttaiRegionalTransport.Reply {
        let identity = "test-install", secret = "test-secret"
        let route = try XCTUnwrap(OttaiRegionalTransport.route("https://seas.ottai.com/cgm/app/server/test?q=a%2Bb", headers: [:]))
        var aes: SymmetricKey?
        var signing: SymmetricKey?
        var calls = 0
        let aad = Data((identity + "|" + secret).utf8)
        func seal(_ data: Data, key: SymmetricKey) throws -> AES.GCM.SealedBox { try AES.GCM.seal(data, using: key, authenticating: aad) }
        let result = try OttaiRegionalTransport.request("POST", route: route, body: "{\"test\":true}", headers: ["deviceId":identity]) { method, url, body, headers in
            calls += 1
            let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(body).utf8)) as? [String: Any])
            if calls == 1 {
                XCTAssertTrue(url.hasSuffix("/security/exchangeKey"))
                let client = try P256.KeyAgreement.PublicKey(rawRepresentation: Data(base64Encoded: obj["clientPubKeyX"] as! String)! + Data(base64Encoded: obj["clientPubKeyY"] as! String)!)
                let server = P256.KeyAgreement.PrivateKey()
                let shared = try server.sharedSecretFromKeyAgreement(with: client)
                let x = server.publicKey.rawRepresentation.prefix(32).base64EncodedString()
                let y = server.publicKey.rawRepresentation.suffix(32).base64EncodedString()
                let time = Int64(Date().timeIntervalSince1970 * 1000), expiry = time + 60_000
                let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: shared.withUnsafeBytes { Data($0) }), salt: Data(secret.utf8), info: Data("\(identity)#\(expiry)#\(secret)".utf8), outputByteCount: 64).withUnsafeBytes { Data($0) }
                aes = SymmetricKey(data: derived.prefix(32))
                signing = SymmetricKey(data: derived.suffix(32))
                let proof = try seal(Data((x+y).utf8), key: aes!)
                return (200,["code":"200", "data":["serverPubKeyX":x,"serverPubKeyY":y,"serverTimestamp":time,"serverSignature":SHA256.hash(data: Data((identity+x+y+String(time)).utf8)).map { String(format:"%02x",$0) }.joined(),"secretId":secret,"expireTime":expiry,"iv":Data(proof.nonce).base64EncodedString(),"authTag":proof.tag.base64EncodedString(),"ciphertext":proof.ciphertext.base64EncodedString()]])
            }
            XCTAssertEqual(headers["webDeviceId"],identity)
            XCTAssertEqual(headers["cipherSeq"],"1")
            XCTAssertTrue(url.contains("cipherParamText="))
            XCTAssertNil(obj["test"])
            let signed = try XCTUnwrap(headers["cipherNonceId"]) + "1" + XCTUnwrap(headers["cipherTimeNow"]) + XCTUnwrap(obj["cipherBodyText"] as? String)
            let signature = try XCTUnwrap(Data(base64Encoded: XCTUnwrap(obj["cipherBodySignature"] as? String)))
            XCTAssertTrue(HMAC<SHA256>.isValidAuthenticationCode(signature, authenticating: Data(signed.utf8), using: try XCTUnwrap(signing)))
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: Data(base64Encoded: obj["cipherBodyNonce"] as! String)!), ciphertext: Data(base64Encoded: obj["cipherBodyText"] as! String)!, tag: Data(base64Encoded: obj["cipherBodyMac"] as! String)!)
            XCTAssertEqual(String(decoding: try AES.GCM.open(box, using: aes!, authenticating: aad), as: UTF8.self), "{\"test\":true}")
            let reply = try seal(Data("{\"code\":\"DEVICE_AUTH_SIGN_ERROR\"}".utf8), key: aes!)
            var ciphertext = reply.ciphertext
            if tamperReply { ciphertext[ciphertext.startIndex] ^= 1 }
            return (200,["cipherSecretId":secret,"cipherText":ciphertext.base64EncodedString(),"cipherMac":reply.tag.base64EncodedString(),"cipherNonce":Data(reply.nonce).base64EncodedString()])
        }
        XCTAssertEqual(calls,2)
        return result
    }
}
