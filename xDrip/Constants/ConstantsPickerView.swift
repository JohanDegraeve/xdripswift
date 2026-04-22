//
//  ConstantsPickerView.swift
//  xdrip
//
//  Created by Paul Plant on 8/3/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import Foundation

/// picker view specific constants
enum ConstantsPickerView {
    /// default height of the modal picker view controller
    static let defaultHeight: CGFloat = 390
    
    /// default height of the modal picker view controller when used with a full screen view (i.e. without the navigation controller tab in front)
    static let defaultHeightWhenFullScreen: CGFloat = 340
    
    /// height at which the modal picker view controller will be dismissed
    static let dismissibleHeight: CGFloat = 200
    
    /// maximum dimmed alpha value for the dimmed view overlay that covers the parent view
    static let maxDimmedAlpha: CGFloat = 0.7
    
    /// the background view for the modal view that pops over the dimmed overlay
    static let containerViewBackgroundColor: UIColor = UIColor(white: 0.15, alpha: 1)
    
    /// picker view title font type
    static let mainTitleFont: UIFont = .boldSystemFont(ofSize: 20)
    
    /// picker view subtitle font type
    static let subTitleFont: UIFont = .systemFont(ofSize: 15)
}
