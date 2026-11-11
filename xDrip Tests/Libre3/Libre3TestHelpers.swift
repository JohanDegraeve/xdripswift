//
//  Libre3TestHelpers.swift
//  xdrip
//
// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Tests/RoundWhiteDiscKitTests/TestHelpers.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import Foundation

extension Data {
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
