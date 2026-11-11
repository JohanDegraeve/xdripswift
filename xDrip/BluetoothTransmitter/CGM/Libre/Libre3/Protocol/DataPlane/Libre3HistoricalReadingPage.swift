//
//  Libre3HistoricalReadingPage.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

// Adapted from RoundWhiteDiscKit.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/DataPlane/HistoricalReadingPage.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

struct Libre3HistoricalReadingSample: Equatable, Sendable {
    let lifeCount: UInt16
    let rawValue: UInt16

    var glucoseMgDL: UInt16? {
        glucoseStatus.displayMgDL
    }

    var glucoseStatus: Libre3GlucoseValueStatus {
        Libre3GlucoseValueStatus(rawSensorValue: rawValue)
    }
}

struct Libre3HistoricalReadingPage: Equatable, Sendable {
    static let plaintextSize = 14
    static let sampleSpacingLifeCounts: UInt16 = 5

    let startLifeCount: UInt16
    let values: [UInt16]

    init(plaintext: Data) throws {
        guard plaintext.count == Self.plaintextSize else {
            throw Libre3HistoricalReadingPageError.wrongPlaintextSize(plaintext.count)
        }
        let words = stride(from: 0, to: plaintext.count, by: 2).map { offset -> UInt16 in
            UInt16(plaintext[offset]) | (UInt16(plaintext[offset + 1]) << 8)
        }
        guard words[0] <= UInt16.max - 25 else { throw Libre3HistoricalReadingPageError.invalidLifeCount }
        self.startLifeCount = words[0]
        self.values = Array(words.dropFirst())
    }

    var samples: [Libre3HistoricalReadingSample] {
        values.enumerated().map { index, value in
            Libre3HistoricalReadingSample(
                lifeCount: startLifeCount + UInt16(index) * Self.sampleSpacingLifeCounts,
                rawValue: value
            )
        }
    }

    var endLifeCount: UInt16 {
        startLifeCount + UInt16(values.count - 1) * Self.sampleSpacingLifeCounts
    }
}

enum Libre3HistoricalReadingPageError: Error, Equatable {
    case wrongPlaintextSize(Int)
    case invalidLifeCount
}
