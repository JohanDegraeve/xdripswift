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
    
    // Contact images use the same semantic range colors as the application interface.
    static let inRangeColor = ConstantsAppColors.normal
    static let notUrgentColor = ConstantsAppColors.warning
    static let urgentColor = ConstantsAppColors.urgent
    
    static let unknownColor = ConstantsAppColors.disabledText
    
    /// the vertical offset of the bg value if the slope arrow is present (bigger number is higher)
    static let bgValueVerticalOffsetIfSlopeArrow: Double = 1.5
    
    /// the vertical offset of the slope arrow (bigger number is higher)
    static let slopeArrowVerticalOffset: Double = -0.8
    
}
