//
//  TextsLibre3.swift
//  xDrip
//
//  Created by Paul Plant on 15/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Keep native Libre 3 setup, connection states and recovery errors in one translation table.
enum TextsLibre3 {
    static func localized(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, tableName: "Libre3", bundle: .main, value: key, comment: comment)
    }
}
