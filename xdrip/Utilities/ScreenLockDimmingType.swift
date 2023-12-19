//
//  ScreenLockDimmingType.swift
//  xdrip
//
//  Created by Paul Plant on 27/11/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation

// MARK: ScreenLockDimmingType Enum

/// different screen dimming options for the screen lock function (to be able to chose if the screen should be dimmed when activated and if so, by how much)
public enum ScreenLockDimmingType: Int, CaseIterable {
    
    // when adding options, add new cases at the end (ie 11, ...)
    // if this is done in the middle then a database migration would be required, because the rawvalue is stored as Int16 in the coredata
    // the order of the data source types will in the uiview is determined by the initializer init(forRowAt row: Int)

    case disabled = 0
    case dimmed = 1
    case dark = 2
    case veryDark = 3
    
    
    init?() {
        self = .disabled
    }
    
    /// text description of the screen dimming type
    var description: String {
        
        switch self {
            
        case .disabled:
            return Texts_SettingsView.screenLockDimmingTypeDisabled
        case .dimmed:
            return Texts_SettingsView.screenLockDimmingTypeDimmed
        case .dark:
            return Texts_SettingsView.screenLockDimmingTypeDark
        case .veryDark:
            return Texts_SettingsView.screenLockDimmingTypeVeryDark
            
        }
        
    }
    
    /// returns the UIColor for the dimming type selected (this in turn comes from the constants file for Home View)
    var dimmingColor: UIColor {
        
        switch self {
            
        case .dimmed:
            return ConstantsHomeView.screenLockDimmingOptionsDark
        case .dark:
            return ConstantsHomeView.screenLockDimmingOptionsDark
        case .veryDark:
            return ConstantsHomeView.screenLockDimmingOptionsVeryDark
        default:
            return ConstantsHomeView.screenLockDimmingOptionsDark
            
        }
        
    }
    
    /// gives the raw value of the screenLockDimmingTypeRawValue for a specific section in a uitableview, is the opposite of the initializer
    static func screenLockDimmingTypeRawValue(rawValue: Int) -> Int {
        
        switch rawValue {
            
        case 0:// disabled
            return 0
        case 1:// dimmed
            return 1
        case 2:// dark
            return 2
        case 3:// very dark
            return 3
        default:
            fatalError("in ScreenLockDimmingType, unknown case")
            
        }
        
    }
    
}
