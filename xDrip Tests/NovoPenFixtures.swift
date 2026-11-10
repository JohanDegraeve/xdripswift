//
//  NovoPenFixtures.swift
//  xdripTests
//
//  Ported from xDrip "OpenNov" by JamOrHam (NightscoutFoundation/xDrip, GPLv3).
//
//  Hex copied verbatim from opennov MessageTest.java. Each is one inner PHD record (what `NovoPenMessage.parse` takes).
//

import Foundation
@testable import xdrip

enum NovoPenFixtures {
    /// Hex with spaces, as written in the Android tests.
    private static func hex(_ string: String) -> Data {
        Data(hexadecimalString: string.filter { !$0.isWhitespace })!
    }

    /// A_REQUEST: the pen's association request.
    static let aRequest = hex(
        "e2 00 00 32 80 00 00 00 00 01 00 2a 50 79 00 26 " +
        "80 00 00 00 80 00 80 00 00 00 00 00 00 00 00 80 " +
        "00 00 00 08 00 14 65 00 45 07 b9 51 40 0a 00 01 " +
        "01 00 00 00 00 00 ")

    /// A_RESPONSE: our association response to `aRequest`.
    static let aResponse = hex(
        "e3 00 00 2c 00 03 50 79 00 26 80 00 00 00 80 00 " +
        "80 00 00 00 00 00 00 00 80 00 00 00 00 08 00 14 " +
        "65 00 45 07 b9 51 00 00 00 00 00 00 00 00 00 00 ")

    /// C_REPORT: the pen's configuration event report (invoke id 0, config id 0x400A).
    static let configReport = hex(
        "e7 00 00 c4 00 c2 00 00 01 01 00 bc 00 00 00 00  " +
        "00 00 0d 1c 00 b2 40 0a 00 04 00 ac 00 3d 01 00  " +
        "00 08 00 38 0a 4d 00 02 08 00 09 43 00 02 00 00 " +
        "09 41 00 04 00 00 03 20 09 53 00 02 00 00 0a 57  " +
        "00 04 00 02 50 4d 09 51 00 02 00 01 0a 63 00 04  " +
        "00 00 00 00 09 44 00 04 00 00 00 02 00 06 00 02  " +
        "00 04 00 20 09 2f 00 04 00 82 34 01 0a 46 00 02  " +
        "f0 40 09 96 00 02 15 60 0a 55 00 08 00 01 00 04  " +
        "0a 56 00 04 00 05 00 03 00 03 00 1a 09 2f 00 04  " +
        "00 82 34 02 0a 46 00 02 f0 40 0a 55 00 08 00 01  " +
        "00 04 0a 66 00 02 00 06 00 04 00 03 00 1a 09 2f  " +
        "00 04 00 82 f0 00 0a 46 00 02 f0 40 0a 55 00 08  " +
        "00 01 00 04 0a 66 00 02  ")

    /// C_ACCEPT: our acceptance of `configReport`.
    static let acceptConfig = hex(
        "e7 00 00 16 00 14 00 00 02 01 00 0e 00 00 00 00 " +
        "00 00 0d 1c 00 04 40 0a 00 00  ")

    /// A_INFO: our request for the device information.
    static let askInfo = hex(
        "e7 00 00 0e 00 0c 00 00 01 03 00 06 00 00 00 00" +
        "00 00")

    /// CA_SEG: our request for the segment info (invoke id 1).
    static let getSegmentInfo = hex(
        "e7 00 00 14 00 12 00 01 01 07 00 0c 01 00 0c 0d " +
        "00 06 00 01 00 02 00 00  ")

    /// S_INFO: the pen's segment info, one typical segment (instance 16, 3 entries).
    static let segmentInfo = hex(
        "e7 00 00 7c 00 7a 00 01 02 07 00 74 01 00 0c 0d " +
        "00 6e 00 01 00 6a 00 10 00 06 00 64 09 22 00 02 " +
        "00 10 0a 4e 00 36 40 00 00 03 00 30 00 06 00 82 " +
        "34 01 00 02 00 01 00 04 0a 56 00 04 00 05 00 82 " +
        "34 02 00 03 00 01 00 04 0a 66 00 02 00 06 00 82 " +
        "f0 00 00 04 00 01 00 04 0a 66 00 02 09 53 00 02 " +
        "00 00 0a 58 00 0a 00 08 44 6f 73 65 20 4c 6f 67 " +
        "09 7b 00 04 00 00 00 03 0a 64 00 04 00 02 71 00 ")

    /// T_XFER: our trigger for the transfer of segment 16 (invoke id 2).
    static let triggerTransfer = hex(
        "e7 00 00 10 00 0e 00 02 01 07 00 08 01 00 0c 1c " +
        "00 02 00 10")

    /// D_INFO (deviceParseTest): the pen's device information. Serial EGDO2U, clock 116243.
    static let deviceInfo = hex(
        "e7 00 00 d3 00 d1 00 00 02 03 00 cb 00 00 00 08 " +
        "00 c5 09 84 00 0a 00 08 00 14 65 00 45 07 d7 21 " +
        "09 8f 00 04 00 01 c6 13 0a 45 00 10 20 00 1f 00 " +
        "ff ff ff ff 00 00 1f 40 00 00 00 00 09 2d 00 4b " +
        "00 04 00 47 00 01 00 01 00 06 45 47 44 4f 32 55 " +
        "00 02 00 01 00 20 44 32 30 31 33 30 32 36 33 32 " +
        "30 30 30 30 30 20 44 32 30 31 33 30 32 36 33 32 " +
        "30 30 30 30 30 20 00 03 00 01 00 01 00 00 04 00 " +
        "01 00 08 30 31 2e 30 38 2e 30 30 0a 5a 00 08 00 " +
        "01 00 04 10 48 00 01 09 28 00 1c 00 10 4e 6f 76 " +
        "6f 20 4e 6f 72 64 69 73 6b 20 41 2f 53 00 08 4e " +
        "6f 76 6f 50 65 6e 00 0a 44 00 02 40 0a 0a 4b 00 " +
        "16 00 02 00 12 02 01 00 08 04 00 00 01 00 02 a0 " +
        "48 02 02 00 02 00 00 ")

    /// segmentXferTest: the pen's dose report, newest first (relative times 116177, 331, 0; the clock is 116243).
    /// Doses: 3.0 U, 2.0 U, and an error entry (flags 0x04000008).
    static let doseReport = hex(
        "e7 00 00 44 00 42 80 01 01 01 00 3c 01 00 00 01 " +
        "c6 13 0d 21 00 32 00 10 00 00 00 00 00 00 00 03 " +
        "c0 00 00 24 00 01 c5 d1 ff 00 00 1e 08 00 00 00 " +
        "00 00 01 4b ff 00 00 14 08 00 00 00 00 00 00 00 " +
        "00 7f ff ff 04 00 00 08 ")

    /// trigSegTest: the pen's answer to `triggerTransfer` (segment 16, response 0).
    static let triggerResponse = hex(
        "e7 00 00 12 00 10 00 02 02 07 00 0a 01 00 0c 1c " +
        "00 04 00 10 00 00 ")

    /// ackTest1: our confirmation of a segment data report (invoke id 0x8001, instance 16, index 0, count 2).
    static let segmentAck = hex(
        "e7 00 00 1e 00 1c 80 01 02 01 00 16 01 00 ff ff " +
        "ff ff 0d 21 00 0c 00 10 00 00 00 00 00 00 00 02 " +
        "00 80 ")
}
