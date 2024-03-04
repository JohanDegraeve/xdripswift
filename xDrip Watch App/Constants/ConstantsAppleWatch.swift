//
//  ConstantsAppleWatch.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 22/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsAppleWatch {
    
    /// an array holding the different "chart hour to show" options when swiping left/right
    static let hoursToShow: [Double] = [2, 4, 6, 9, 12]
    
    /// the default index of hoursToShow when the app is opened (i.e. for example [1] = 4 hours)
    static let hoursToShowDefaultIndex: Int = 1
    
}
