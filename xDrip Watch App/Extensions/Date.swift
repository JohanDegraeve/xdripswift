//
//  Date.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 11/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

extension Date {

    func toMillisecondsAsDouble() -> Double {
        return Double(self.timeIntervalSince1970 * 1000)
    }
    
    /// creates a new date, rounded to lower hour, eg if date = 26 10 2019 23:23:35, returnvalue is date 26 10 2019 23:00:00
    func toLowerHour() -> Date {
        return Date(timeIntervalSinceReferenceDate:
            (timeIntervalSinceReferenceDate / 3600.0).rounded(.down) * 3600.0)
    }
}

