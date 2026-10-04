//
//  Libre2FrameAssembler.swift
//  xdrip
//
//  Created by Paul Plant on 31/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Reassembles the three CoreBluetooth notifications that normally make up one Libre 2 frame.
///
/// A completed buffer is cleared immediately. This allows a following frame to start without
/// waiting for the normal three-second inter-frame gap.
struct Libre2FrameAssembler {
    enum Result: Equatable {
        case incomplete
        case complete(frame: Data, assemblyDuration: TimeInterval)
        case oversized(receivedByteCount: Int)
    }

    struct TimedOutPartialFrame: Equatable {
        let discardedByteCount: Int
        let assemblyDuration: TimeInterval
    }

    /// Reports frame assembly and any timeout that occurred while accepting the new fragment.
    /// Keeping both results means the fragment that reveals a timeout can immediately become the
    /// first fragment of the next frame instead of being thrown away for diagnostic convenience.
    struct AppendResult: Equatable {
        let frameResult: Result
        let timedOutPartialFrame: TimedOutPartialFrame?
    }

    private let expectedByteCount: Int
    private let assemblyTimeout: Duration

    private var buffer = Data()
    private var firstFragmentArrival: ContinuousClock.Instant?

    init(expectedByteCount: Int = 46, assemblyTimeout: Duration = .seconds(3)) {
        self.expectedByteCount = expectedByteCount
        self.assemblyTimeout = assemblyTimeout
    }

    mutating func append(_ fragment: Data, arrival: ContinuousClock.Instant) -> AppendResult {
        var timedOutPartialFrame: TimedOutPartialFrame?

        if let firstFragmentArrival,
           firstFragmentArrival.duration(to: arrival) > assemblyTimeout
        {
            timedOutPartialFrame = TimedOutPartialFrame(
                discardedByteCount: buffer.count,
                assemblyDuration: firstFragmentArrival.duration(to: arrival).timeInterval
            )
            reset()
        }

        if firstFragmentArrival == nil {
            firstFragmentArrival = arrival
        }

        buffer.append(fragment)

        guard buffer.count >= expectedByteCount else {
            return AppendResult(frameResult: .incomplete, timedOutPartialFrame: timedOutPartialFrame)
        }

        guard buffer.count == expectedByteCount else {
            let receivedByteCount = buffer.count
            reset()
            return AppendResult(
                frameResult: .oversized(receivedByteCount: receivedByteCount),
                timedOutPartialFrame: timedOutPartialFrame
            )
        }

        let completedFrame = buffer
        let assemblyDuration = firstFragmentArrival?.duration(to: arrival).timeInterval ?? 0
        reset()

        return AppendResult(
            frameResult: .complete(frame: completedFrame, assemblyDuration: assemblyDuration),
            timedOutPartialFrame: timedOutPartialFrame
        )
    }

    mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
        firstFragmentArrival = nil
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
