//
//  ConstantsAppleWatch.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 22/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

#if canImport(WatchKit)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#endif

enum ConstantsAppleWatch {
    
    /// an array holding the different "chart hour to show" options when swiping left/right
    static let hoursToShow: [Double] = [2, 3, 4, 6, 9, 12]
    
    /// the default index of hoursToShow when the app is opened (i.e. for example [2] = 4 hours)
    static let hoursToShowDefaultIndex: Int = 2
    
    /// less than how many pixels wide should we consider the screen size to the "small"
    static let pixelWidthLimitForSmallScreen: Double = 185
    
    /// colour for the "requesting data" symbol when active
    static let requestingDataIconColorActive = Color.green
    
    /// colour for the "requesting data" symbol when inactive
    static let requestingDataIconColorInactive = Color.white.opacity(0.3)
    
    /// colour for the "requesting data" symbol whilst waiting for data back
    static let requestingDataIconColorPending = Color.orange
    
    /// font size for the "requesting data" symbol
    static let requestingDataIconFontSize: CGFloat = 6
    
    /// SFSymbol name as a string for the "requesting data" symbol
    static let requestingDataIconSFSymbolName: String = "circle.fill"
    
    static func screenWidth() -> Double {
        #if canImport(WatchKit)
        return WKInterfaceDevice.current().screenBounds.size.width
        #elseif canImport(UIKit)
        return UIScreen.main.bounds.size.width
        #else
        return 0
        #endif
    }

    // return the physical screen height so the watch app can size layouts across different watch models
    static func screenHeight() -> Double {
        #if canImport(WatchKit)
        return WKInterfaceDevice.current().screenBounds.size.height
        #elseif canImport(UIKit)
        return UIScreen.main.bounds.size.height
        #else
        return 0
        #endif
    }
    
    static func isSmallScreen() -> Bool {
        return screenWidth() < pixelWidthLimitForSmallScreen
    }
    
}
