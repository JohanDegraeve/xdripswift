//
//  ConstantsContactImage.swift
//  xdrip
//
//  Created by Paul Plant on 13/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

enum ConstantsContactImage {
    
    // we need these colours as UIColors but we'll create them based off standard SwiftUI colors
    // so that they match the rest of the xDrip4iOS Watch widgets
    static let inRangeColor = UIColor(Color.green)
    static let notUrgentColor = UIColor(Color.yellow)
    static let urgentColor = UIColor(Color.red)
    
    static let unknownColor = UIColor(Color.gray)
    
    /// the vertical offset of the bg value if the slope arrow is present (bigger number is higher)
    static let bgValueVerticalOffsetIfSlopeArrow: Double = 1.5
    
    /// the vertical offset of the slope arrow (bigger number is higher)
    static let slopeArrowVerticalOffset: Double = -0.8
    
}
