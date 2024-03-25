//
//  ConstantsLiveActivity.swift
//  xDripWidgetExtension
//
//  Created by Paul Plant on 19/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsLiveActivity {
    // restart the live activity after time in (minutes)
    // this is to prevent it being restarted too often
    static let allowLiveActivityRestartAfterMinutes: Double = 4 * 60 * 60
    
    // warn that live activity will soon end (in minutes)
    static let warnLiveActivityAfterMinutes: Double = 7.25 * 60 * 60
    
    // end live activity after time in (minutes) we give a bit of margin
    // in case there is a missed reading (and therefore no update cycle) towards the end
    static let endLiveActivityAfterMinutes: Double = 7.75 * 60 * 60
}
