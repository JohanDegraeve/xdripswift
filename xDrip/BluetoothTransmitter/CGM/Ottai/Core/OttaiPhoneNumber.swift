//
//  OttaiPhoneNumber.swift
//  xdrip
//
//  Ottai / Syai CGM driver — checks a phone number for the China SMS login.
//  This is a Swift copy of OttaiPhoneNumber.kt from JugglucoNG.
//

import Foundation

enum OttaiSmsCountry: CaseIterable {
    case mainlandChina
    case hongKong

    var phoneCode: String {
        switch self {
        case .mainlandChina: return "86"
        case .hongKong: return "852"
        }
    }

    var prefix: String {
        switch self {
        case .mainlandChina: return "+86"
        case .hongKong: return "+852"
        }
    }

    var subscriberDigits: Int {
        switch self {
        case .mainlandChina: return 11
        case .hongKong: return 8
        }
    }

    private var pattern: String {
        switch self {
        case .mainlandChina: return "^1[3-9]\\d{9}$"
        case .hongKong: return "^[4-9]\\d{7}$"
        }
    }

    func accepts(_ raw: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(raw.startIndex..., in: raw)
        return regex.firstMatch(in: raw, options: [], range: range) != nil
    }
}

/// Returns the digits if they are a valid number for the country, else nil.
func normalizeOttaiPhone(_ raw: String, country: OttaiSmsCountry) -> String? {
    country.accepts(raw) ? raw : nil
}
