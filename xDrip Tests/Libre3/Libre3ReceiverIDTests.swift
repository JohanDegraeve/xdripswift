//
//  Libre3ReceiverIDTests.swift
//  xdrip
//

// Copied from RoundWhiteDiscKit with xDrip4iOS integration changes.
// Source: https://github.com/airedev326/RoundWhiteDiscKit/blob/main/Tests/RoundWhiteDiscKitTests/Libre3ReceiverIDTests.swift
// Licensed under MIT. See license.md in the Libre3 folder.

import XCTest
@testable import xdrip

/// Published account-derivation vectors retained for the native implementation.
final class Libre3ReceiverIDTests: XCTestCase {
    /// DiaBLE's documented sample account, not a real one.
    private let sampleAccountID = "2977dec2-492a-11ea-9702-0242ac110002"

    func testSampleAccountFoldsToBothDocumentedReceiverIDs() {
        XCTAssertEqual(
            Libre3ReceiverID(accountID: sampleAccountID, derivation: .freeStyleLibre3).value,
            524_381_581
        )
        XCTAssertEqual(
            Libre3ReceiverID(accountID: sampleAccountID, derivation: .libreByAbbott).value,
            2_203_515_335
        )

        // 2203515335 is 0x8356f9c7, c7f95683 is that value on the wire.
        XCTAssertEqual(
            Libre3ReceiverID(accountID: sampleAccountID, derivation: .libreByAbbott).littleEndianHex,
            "c7f95683"
        )
    }

    /// The classic derivation must stay bit-identical to the long-validated
    /// `accountlessValue(from:)` path. These are the two receiver IDs captured
    /// from accepted activations, also pinned in `NFCActivationCommandTests`.
    func testFreeStyleLibre3DerivationMatchesAccountlessFoldOnCapturedVectors() {
        for uniqueID in ["5abb0ad8-dc2e-4ede-9e2d-67472a3e630e", "6147368e-c060-44a5-9e96-1c02333f43c0"] {
            XCTAssertEqual(
                Libre3ReceiverID(accountID: uniqueID, derivation: .freeStyleLibre3),
                Libre3ReceiverID(accountlessUniqueID: uniqueID)
            )
        }

        XCTAssertEqual(
            Libre3ReceiverID(accountID: "5abb0ad8-dc2e-4ede-9e2d-67472a3e630e", derivation: .freeStyleLibre3).littleEndianHex,
            "78830d6f"
        )
        XCTAssertEqual(
            Libre3ReceiverID(accountID: "6147368e-c060-44a5-9e96-1c02333f43c0", derivation: .freeStyleLibre3).littleEndianHex,
            "231f25c3"
        )
    }

    /// Account-ID entry points normalize case. `accountlessValue(from:)` does
    /// not, which is why the uppercase spelling only agrees with the lowercase
    /// one through this API.
    func testAccountIDDerivationsNormalizeCase() {
        for derivation in Libre3ReceiverID.Derivation.allCases {
            XCTAssertEqual(
                Libre3ReceiverID(accountID: sampleAccountID.uppercased(), derivation: derivation),
                Libre3ReceiverID(accountID: sampleAccountID, derivation: derivation)
            )
        }

        XCTAssertNotEqual(
            Libre3ReceiverID(accountlessUniqueID: sampleAccountID.uppercased()),
            Libre3ReceiverID(accountlessUniqueID: sampleAccountID)
        )
    }

    /// A trailing partial word is left-padded rather than dropped or
    /// right-padded. A 36-character account ID cannot reach this path, so the
    /// vector is a truncated one.
    func testShortTrailingWordIsLeftPadded() {
        // "2977dec2-4" -> 0x32393737 + 0x64656332 + 0x2d34
        XCTAssertEqual(
            Libre3ReceiverID(accountID: "2977dec2-4", derivation: .libreByAbbott).value,
            0x32393737 &+ 0x64656332 &+ 0x0000_2d34
        )
    }

    func testDerivationRoundTripsThroughItsRawValueForPersistence() throws {
        for derivation in Libre3ReceiverID.Derivation.allCases {
            let encoded = try JSONEncoder().encode(derivation)
            XCTAssertEqual(
                try JSONDecoder().decode(Libre3ReceiverID.Derivation.self, from: encoded),
                derivation
            )
        }

        XCTAssertEqual(Libre3ReceiverID.Derivation.freeStyleLibre3.rawValue, "freeStyleLibre3")
        XCTAssertEqual(Libre3ReceiverID.Derivation.libreByAbbott.rawValue, "libreByAbbott")
    }
}
