//
//  ConstantsAppleWatch.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 22/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

enum ConstantsAppleWatch {
    
    /// an array holding the different "chart hour to show" options when swiping left/right
    static let hoursToShow: [Double] = [2, 3, 4, 6, 9, 12]
    
    /// the default index of hoursToShow when the app is opened (i.e. for example [2] = 4 hours)
    static let hoursToShowDefaultIndex: Int = 2
    
    /// less than how many pixels wide should we consider the screen size to the "small"
    static let pixelWidthLimitForSmallScreen: Double = 185
    
    /// colour for the "requesting data" symbol
    static let requestingDataIconColorActive = Color(.green) //.opacity(0.9)
    static let requestingDataIconColorInactive = Color(.white).opacity(0.3)
    static let requestingDataIconFontSize: CGFloat = 6
    static let requestingDataIconSFSymbolName: String = "circle.fill" // "iphone.gen3.radiowaves.left.and.right" //
    
}
