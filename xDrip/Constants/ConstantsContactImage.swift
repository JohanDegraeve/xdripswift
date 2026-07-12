//
//  ConstantsContactImage.swift
//  xdrip
//
//  Created by Paul Plant on 13/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit

enum ConstantsContactImage {
    
    // Contact images are rendered as UIImages for the Contacts framework. These values mirror the
    // standard SwiftUI chart colours while remaining in the bitmap renderer's native colour type.
    static let inRangeColor = UIColor.green
    static let notUrgentColor = UIColor.yellow
    static let urgentColor = UIColor.red
    
    static let unknownColor = UIColor.gray
    
    /// the vertical offset of the bg value if the slope arrow is present (bigger number is higher)
    static let bgValueVerticalOffsetIfSlopeArrow: Double = 1.5
    
    /// the vertical offset of the slope arrow (bigger number is higher)
    static let slopeArrowVerticalOffset: Double = -0.8
    
}
