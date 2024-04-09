//
//  ConstantsWidget.swift
//  xdrip
//
//  Created by Paul Plant on 9/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsWidget {
    
    /// the amount of time that should pass before a complication refresh is forced
    /// bear in mind there is a limit to 50 times per day whilst the Watch session is available
    /// so maybe 17 hours / 50 times = every 20.4 minutes
    static let forceComplicationRefreshTimeInMinutes = TimeInterval(minutes: 20)
}
