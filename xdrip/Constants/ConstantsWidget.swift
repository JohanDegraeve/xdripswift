//
//  ConstantsWidget.swift
//  xdrip
//
//  Created by Paul Plant on 9/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsWidget {
    
    /// the amount of time that should pass before a watch complication refresh is forced
    /// bear in mind there is a limit to 50 times per day whilst the Watch session is available
    /// the theoretical calculation could be 17 hours / 50 times = every 20.4 minutes but this needs testing on a real device
    static let forceComplicationRefreshTimeInMinutes = TimeInterval(minutes: 10)
}
