//
//  Libre3HistoricalBackfill.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/DataPlane/HistoricalBackfill.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

struct Libre3HistoricalBackfillGap: Equatable, Sendable {
    let afterLifeCount: UInt16
    let beforeLifeCount: UInt16

    init(afterLifeCount: UInt16, beforeLifeCount: UInt16) {
        self.afterLifeCount = afterLifeCount
        self.beforeLifeCount = beforeLifeCount
    }
}

struct Libre3HistoricalBackfill: Equatable, Sendable {
    private(set) var pages: [Libre3HistoricalReadingPage]

    init(pages: [Libre3HistoricalReadingPage] = []) {
        self.pages = pages
    }

    mutating func append(_ page: Libre3HistoricalReadingPage) {
        pages.append(page)
    }

    var samples: [Libre3HistoricalReadingSample] {
        pages
            .flatMap(\.samples)
            .sorted { $0.lifeCount < $1.lifeCount }
    }

    var firstLifeCount: UInt16? {
        samples.first?.lifeCount
    }

    var lastLifeCount: UInt16? {
        samples.last?.lifeCount
    }

    var gaps: [Libre3HistoricalBackfillGap] {
        let ordered = samples
        guard ordered.count > 1 else {
            return []
        }
        return zip(ordered, ordered.dropFirst()).compactMap { previous, next in
            next.lifeCount > previous.lifeCount + Libre3HistoricalReadingPage.sampleSpacingLifeCounts
                ? Libre3HistoricalBackfillGap(afterLifeCount: previous.lifeCount, beforeLifeCount: next.lifeCount)
                : nil
        }
    }

    var isContiguous: Bool {
        gaps.isEmpty
    }
}

enum Libre3BackfillStream: Equatable, Sendable {
    case historical
    case clinical

    var wireValue: UInt8 {
        switch self {
        case .historical:
            return 0x00
        case .clinical:
            return 0x01
        }
    }

    var label: String {
        switch self {
        case .historical:
            return "historic"
        case .clinical:
            return "clinical"
        }
    }
}
