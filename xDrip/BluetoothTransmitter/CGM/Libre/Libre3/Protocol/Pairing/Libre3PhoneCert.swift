//
//  Libre3PhoneCert.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Sources/RoundWhiteDiscKit/Pairing/PhoneCert.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

/// Certificate supplied at runtime, this application bundles no app identity.
struct Libre3PhoneCert: Equatable, Sendable {
    let raw: Data           // full 162B blob
    let staticPub: Data     // 65B uncompressed P-256 point (with 0x04 prefix)

    static let totalSize: Int = 162
    static let pubkeyRange: Range<Int> = 33..<98

    init(raw: Data) throws {
        guard raw.count == Self.totalSize else { throw Libre3PhoneCertError.wrongSize(raw.count) }
        let pub = raw.subdata(in: Self.pubkeyRange)
        guard pub.first == 0x04 else { throw Libre3PhoneCertError.notUncompressedPoint }
        self.raw = raw
        self.staticPub = pub
    }

}

enum Libre3PhoneCertError: Error, Equatable {
    case wrongSize(Int)
    case notUncompressedPoint
}
