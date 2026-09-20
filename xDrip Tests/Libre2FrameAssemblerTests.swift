//
//  Libre2FrameAssemblerTests.swift
//  xdripTests
//
//  Created by Paul Plant on 31/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class Libre2FrameAssemblerTests: XCTestCase {
    func testConsecutiveFramesCompleteWithoutWaitingForTimeout() {
        var assembler = Libre2FrameAssembler(expectedByteCount: 6)
        let start = ContinuousClock.now

        XCTAssertEqual(assembler.append(Data([0, 1]), arrival: start).frameResult, .incomplete)
        XCTAssertEqual(assembler.append(Data([2, 3]), arrival: start).frameResult, .incomplete)
        XCTAssertEqual(
            assembler.append(Data([4, 5]), arrival: start).frameResult,
            .complete(frame: Data([0, 1, 2, 3, 4, 5]), assemblyDuration: 0)
        )

        XCTAssertEqual(assembler.append(Data([6, 7, 8]), arrival: start).frameResult, .incomplete)
        XCTAssertEqual(
            assembler.append(Data([9, 10, 11]), arrival: start).frameResult,
            .complete(frame: Data([6, 7, 8, 9, 10, 11]), assemblyDuration: 0)
        )
    }

    func testPartialFrameIsDiscardedAfterAssemblyTimeout() {
        var assembler = Libre2FrameAssembler(expectedByteCount: 6, assemblyTimeout: .seconds(3))
        let start = ContinuousClock.now

        XCTAssertEqual(assembler.append(Data([0, 1, 2]), arrival: start).frameResult, .incomplete)

        let resultAfterTimeout = assembler.append(
            Data([3, 4, 5]),
            arrival: start.advanced(by: .seconds(4))
        )

        XCTAssertEqual(resultAfterTimeout.frameResult, .incomplete)
        XCTAssertEqual(
            resultAfterTimeout.timedOutPartialFrame,
            Libre2FrameAssembler.TimedOutPartialFrame(discardedByteCount: 3, assemblyDuration: 4)
        )

        // The fragment that exposed the timeout must remain as the start of the next frame.
        XCTAssertEqual(
            assembler.append(Data([6, 7, 8]), arrival: start.advanced(by: .seconds(5))).frameResult,
            .complete(frame: Data([3, 4, 5, 6, 7, 8]), assemblyDuration: 1)
        )
    }

    func testOversizedFrameIsDiscardedAndNextFrameCanComplete() {
        var assembler = Libre2FrameAssembler(expectedByteCount: 6)
        let start = ContinuousClock.now

        XCTAssertEqual(
            assembler.append(Data([0, 1, 2, 3, 4, 5, 6]), arrival: start).frameResult,
            .oversized(receivedByteCount: 7)
        )
        XCTAssertEqual(
            assembler.append(Data([7, 8, 9, 10, 11, 12]), arrival: start).frameResult,
            .complete(frame: Data([7, 8, 9, 10, 11, 12]), assemblyDuration: 0)
        )
    }
}
