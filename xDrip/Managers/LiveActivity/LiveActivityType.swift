//
//  LiveActivityType.swift
//  xdrip
//
//  Created by Paul Plant on 1/1/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// selected live activity style; Disabled is retained for older stored values and activity payloads
public enum LiveActivityType: Int, CaseIterable, Codable {
    
    // show only styles in the picker; enablement is handled by its own switch
    public static var allCasesForList: [LiveActivityType] {
        return [.minimal, .normal, .large]
    }
    
    // keep the raw values stable because they are stored in UserDefaults and encoded in activity payloads
    
    case disabled = 0 // retained for compatibility; no longer a selectable style
    case normal = 1
    case minimal = 2
    case large = 3
    
    var description: String {
        switch self {
        case .disabled:
            return debugDescription // Disabled is now only used for diagnostics and legacy values
        case .normal:
            return Texts_SettingsView.liveActivityTypeNormal
        case .minimal:
            return Texts_SettingsView.liveActivityTypeMinimal
        case .large:
            return Texts_SettingsView.liveActivityTypeLarge
        }
    }
    
    var debugDescription: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .normal:
            return "Normal"
        case .minimal:
            return "Minimal"
        case .large:
            return "Large"
        }
    }
}

/// Layout used by the small supplemental Live Activity family in CarPlay and Apple Watch.
public enum CarPlayLiveActivityType: Int, CaseIterable, Codable {
    // Keep persisted raw values stable.
    case chart = 0
    case basic = 1

    var description: String {
        switch self {
        case .chart:
            return Texts_SettingsView.carPlayLiveActivityTypeChart
        case .basic:
            return Texts_SettingsView.carPlayLiveActivityTypeBasic
        }
    }
}
