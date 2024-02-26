//
//  ConstantsLiveActivity.swift
//  xDripWidgetExtension
//
//  Created by Paul Plant on 19/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsLiveActivity {
    
    // warn that live activity will soon end (in minutes)
    static let warnLiveActivityAfterMinutes: Double = 7.25 * 60 * 60
    
    // end live activity after time in (minutes) we give a bit of margin
    // in case there is a missed reading (and therefore no update cycle) towards the end
    static let endLiveActivityAfterMinutes: Double = 7.75 * 60 * 60
    
    // what time should the automatic stand-by configuration start from?
    static let configureForStandByAtNightFromHour: Int = 22
    
    // what time should the automatic stand-by configuration end at?
    static let configureForStandByAtNightToHour: Int = 9
    
}
