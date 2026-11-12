//
//  OttaiMethodDefaults.swift
//  xdrip
//
//  Ottai / Syai CGM driver — the default formula for the common 14-coefficient
//  sensors. This is a Swift copy of OttaiMethodDefaults.kt from JugglucoNG.
//
//  The official app keeps the formula it got before. When the cloud later sends
//  only coefficients and no formula, the app keeps using the saved one. V1.5 and
//  V1.7 sensors seen so far all use these 14 numbers and this formula.
//

import Foundation

enum OttaiMethodDefaults {

    static let standard14CoeffMethod: String =
        "V1 C0 ad C1 ml C2 ad;" +
        "V0 R0 2 pw dv;" +
        "C3 0 ml C4 R1 2 pw ml ad C5 R1 ml ad C6 ad;" +
        "C7 R2 2 pw ml C8 R2 ml ad C9 ad;" +
        "C10 V2 86400 dv C11 ml sb V2 C12 1 le ml V2 C12 1 gt C13 ml ad;" +
        "R3 R4 ml 1 rd"

    /// Use the given formula. If it is empty and the coefficients look like the
    /// common 14-number set, use the default formula.
    static func resolve(method: String, coefficient: String) -> String {
        let explicit = method.trimmingCharacters(in: .whitespaces)
        if !explicit.isEmpty { return explicit }
        return matchesStandard14CoefficientProfile(coefficient) ? standard14CoeffMethod : ""
    }

    static func matchesStandard14CoefficientProfile(_ coefficient: String) -> Bool {
        let parts = coefficient.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var values: [Double] = []
        for part in parts {
            guard let d = Double(part) else { return false }
            values.append(d)
        }
        if values.count != 14 { return false }
        if values.contains(where: { !$0.isFinite }) { return false }
        let splitAgeSeconds = values[12]
        let lateWearMask = values[13]
        return splitAgeSeconds >= 86_400.0 && splitAgeSeconds <= 604_800.0 &&
            lateWearMask >= 0.0 && lateWearMask <= 2.0
    }
}
