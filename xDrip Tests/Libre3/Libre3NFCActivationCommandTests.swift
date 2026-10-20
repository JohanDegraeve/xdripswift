//
//  Libre3NFCActivationCommandTests.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Tests/RoundWhiteDiscKitTests/NFCActivationCommandTests.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import XCTest
@testable import xdrip

final class Libre3NFCActivationCommandTests: XCTestCase {
    func testAccountlessReceiverIDMatchesCapturedPristineUUIDs() {
        let freshPair = Libre3NFCActivationCommand.accountlessReceiverID(
            from: "5abb0ad8-dc2e-4ede-9e2d-67472a3e630e"
        )
        XCTAssertEqual(freshPair, 0x6f0d8378)
        XCTAssertEqual(littleEndianHex(freshPair), "78830d6f")
        XCTAssertEqual(
            Libre3ReceiverID(accountlessUniqueID: "5abb0ad8-dc2e-4ede-9e2d-67472a3e630e").littleEndianHex,
            "78830d6f"
        )

        let freshInstall = Libre3NFCActivationCommand.accountlessReceiverID(
            from: "6147368e-c060-44a5-9e96-1c02333f43c0"
        )
        XCTAssertEqual(freshInstall, 0xc3251f23)
        XCTAssertEqual(littleEndianHex(freshInstall), "231f25c3")
    }

    func testReceiverIDRecoveryEncodingParsesLittleEndianHex() throws {
        let receiverID = try Libre3ReceiverID(littleEndianHex: "78:83:0d:6f")

        XCTAssertEqual(receiverID.value, 0x6f0d8378)
        XCTAssertEqual(receiverID.littleEndianData.hex, "78830d6f")
        XCTAssertEqual(receiverID.littleEndianHex, "78830d6f")
        XCTAssertEqual(receiverID.displayString, "0x6f0d8378 / 78830d6f")
        XCTAssertEqual(Libre3ReceiverID.parseLittleEndianHex("0x78830d6f"), 0x6f0d8378)
    }

    func testAbbottCRC16MatchesAcceptedFreshPairVector() {
        let prefix = Data(hexString: "fc2bee6978830d6f")
        XCTAssertEqual(Libre3NFCActivationCommand.abbottCRC16(prefix), 0x71b4)
        XCTAssertEqual(Libre3NFCActivationCommand.metcrc(timeSeconds: 1777216508, receiverID: 0x6f0d8378).hex, "fc2bee6978830d6fb471")
    }

    func testActivationAndSwitchCommandsMatchCapturedWire() {
        XCTAssertEqual(
            Libre3NFCActivationCommand.command(code: .activate, timeSeconds: 1777216508, receiverID: 0x6f0d8378).hex,
            "02a07afc2bee6978830d6fb471"
        )
        XCTAssertEqual(
            Libre3NFCActivationCommand.command(code: .switchReceiver, timeSeconds: 1778097295, receiverID: 0xc3251f23).hex,
            "02a87a8f9cfb69231f25c3aac8"
        )
        XCTAssertEqual(
            Libre3NFCActivationCommand.command(code: .switchReceiver, timeSeconds: 1778100341, receiverID: 0x6f0d8378).hex,
            "02a87a75a8fb6978830d6f4cd4"
        )
    }

    func testCoreNFCPayloadsExcludeRequestFlagAndCommandCode() {
        XCTAssertEqual(Libre3NFCActivationCommand.readPatchInfoCustomRequestParameters.hex, "")
        XCTAssertEqual(
            Libre3NFCActivationCommand.customRequestParameters(timeSeconds: 1777216508, receiverID: 0x6f0d8378).hex,
            "fc2bee6978830d6fb471"
        )
    }

    func testPatchInfoParserMatchesFreshAndActiveCaptures() throws {
        let fresh = try Libre3NFCPatchInfo(
            raw: Data(hexString: "00a50001000200010060541e020401040c0130525243393839415151ff17")
        )
        XCTAssertEqual(fresh.serialNumber, "0RRC989AQ")
        XCTAssertEqual(fresh.stateByte, 0x01)
        XCTAssertEqual(fresh.wearDurationMinutes, 21600)
        XCTAssertEqual(fresh.recommendedCommandCode, .activate)
        XCTAssertEqual(fresh.firmwareVersion, "1.4.2.30")
        XCTAssertEqual(fresh.generation, 1)
        XCTAssertEqual(fresh.productType, 4)
        XCTAssertEqual(fresh.warmupMinutes, 60)

        let active = try Libre3NFCPatchInfo(
            raw: Data(hexString: "00a50001000200010060541e020401040c04305252433938394151c6ca")
        )
        XCTAssertEqual(active.serialNumber, "0RRC989AQ")
        XCTAssertEqual(active.stateByte, 0x04)
        XCTAssertEqual(active.wearDurationMinutes, 21600)
        XCTAssertEqual(active.recommendedCommandCode, .switchReceiver)
        XCTAssertEqual(active.firmwareVersion, "1.4.2.30")
        XCTAssertEqual(active.generation, 1)
        XCTAssertEqual(active.productType, 4)
        XCTAssertEqual(active.warmupMinutes, 60)
    }

    func testPatchInfoParserAcceptsCoreNFCResponseParameters() throws {
        let response = try Libre3NFCPatchInfo(
            raw: Data(hexString: "a50001000200010060541e020401040c04305252433938394151c6ca")
        )
        XCTAssertEqual(response.raw.hex, "00a50001000200010060541e020401040c04305252433938394151c6ca")
        XCTAssertEqual(response.serialNumber, "0RRC989AQ")
        XCTAssertEqual(response.stateByte, 0x04)
    }

    func testPatchInfoParserCollapsesRepeatedA5PadFromCoreNFC() throws {
        let response = try Libre3NFCPatchInfo(
            raw: Data(hexString: "00a5a5a5a5a5a5a5a50001000200010060541e020401040c04305252433938394151c6ca")
        )
        XCTAssertEqual(response.inputRaw.hex, "00a5a5a5a5a5a5a5a50001000200010060541e020401040c04305252433938394151c6ca")
        XCTAssertEqual(response.raw.hex, "00a50001000200010060541e020401040c04305252433938394151c6ca")
        XCTAssertEqual(response.serialNumber, "0RRC989AQ")
        XCTAssertEqual(response.stateByte, 0x04)
        XCTAssertEqual(response.recommendedCommandCode, .switchReceiver)
    }

    func testActivationResponseParserUsesCorrectedBlePinBoundary() throws {
        let response = try Libre3NFCActivationResponse(
            raw: Data(hexString: "00a50058f9b8df22cc3225ec7200000000ad06")
        )
        XCTAssertEqual(response.bleAddressLittleEndian.hex, "58f9b8df22cc")
        XCTAssertEqual(response.bleAddressDisplay, "CC:22:DF:B8:F9:58")
        XCTAssertEqual(response.blePIN.hex, "3225ec72")
        XCTAssertEqual(response.activationTimeRaw.hex, "00000000")
        XCTAssertEqual(response.trailingCRC.hex, "ad06")

        let state = try response.sensorState(
            serialNumber: "0RRC989AQ",
            receiverID: Libre3ReceiverID(0x6f0d8378)
        )
        XCTAssertEqual(state.serialNumber, "0RRC989AQ")
        XCTAssertEqual(state.bleAddress, "CC:22:DF:B8:F9:58")
        XCTAssertEqual(state.blePIN.hex, "3225ec72")
        XCTAssertEqual(state.receiverID?.littleEndianHex, "78830d6f")
        XCTAssertEqual(state.source, "NFC activation response")
    }

    func testSwitchResponseWithOriginalReceiverParsesAsActivationLikePayload() throws {
        let response = try Libre3NFCActivationResponse(
            raw: Data(hexString: "00a50058f9b8df22cc02bafbbbfc2bee698e6e")
        )
        XCTAssertEqual(response.bleAddressLittleEndian.hex, "58f9b8df22cc")
        XCTAssertEqual(response.bleAddressDisplay, "CC:22:DF:B8:F9:58")
        XCTAssertEqual(response.blePIN.hex, "02bafbbb")
        XCTAssertEqual(response.activationTimeRaw.hex, "fc2bee69")
        XCTAssertEqual(response.trailingCRC.hex, "8e6e")
    }

    func testActivationResponseParserAcceptsCoreNFCResponseParameters() throws {
        let response = try Libre3NFCActivationResponse(
            raw: Data(hexString: "a50058f9b8df22cc3225ec7200000000ad06")
        )
        XCTAssertEqual(response.raw.hex, "00a50058f9b8df22cc3225ec7200000000ad06")
        XCTAssertEqual(response.bleAddressDisplay, "CC:22:DF:B8:F9:58")
        XCTAssertEqual(response.blePIN.hex, "3225ec72")
    }

    private func littleEndianHex(_ value: UInt32) -> String {
        Data([
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff),
        ]).hex
    }
}

private extension Data {
    init(hexString: String) {
        var data = Data(capacity: hexString.count / 2)
        var idx = hexString.startIndex
        while idx < hexString.endIndex {
            let next = hexString.index(idx, offsetBy: 2)
            if let byte = UInt8(hexString[idx..<next], radix: 16) {
                data.append(byte)
            }
            idx = next
        }
        self = data
    }
}
