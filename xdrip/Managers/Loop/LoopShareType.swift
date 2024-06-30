//
//  LoopShareType.swift
//  xdrip
//
//  Created by Paul Plant on 27/6/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

/// types of share available to different APS systems via different shared app groups
public enum LoopShareType: Int, CaseIterable {
    
    // when adding to LoopShareType, add new cases at the end (ie 3, ...)
    case disabled = 0
    case loop = 1
    case trio = 2
    
    var description: String {
        switch self {
        case .disabled:
            return Texts_Common.disabled
        case .loop:
            return Texts_SettingsView.loopShareToLoop
        case .trio:
            return Texts_SettingsView.loopShareToTrio
        }
    }
    
    var sharedUserDefaultsSuiteName: String {
        switch self {
        case .disabled:
            return ""
        case .loop:
            return Bundle.main.appGroupSuiteName
        case .trio:
            return Bundle.main.appGroupSuiteNameTrio
        }
    }
    
}

