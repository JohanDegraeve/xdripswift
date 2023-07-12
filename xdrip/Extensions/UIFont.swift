//
//  UIFont.swift
//  xdrip
//
//  Created by Todd Dalton on 07/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit

extension UIFont {
    
    // Static vars to allow auto-complete of used `UIFonts`
    
    static let DefaultSize: CGFloat = 90.0
    static let SmallSize: CGFloat = UIFont.DefaultSize / 6
    
    // These are force unwrapped since we shouldn't be able to run without the resources
    
    /// Bold font indicating a very high BG
    static let UrgentFont: UIFont = UIFont(name: "Quicksand-Bold", size: UIFont.DefaultSize)!
    
    /// Semi-Bold font indicating a high BG
    static let NonUrgentFont: UIFont = UIFont(name: "Quicksand-SemiBold", size: UIFont.DefaultSize)!
    
    /// Regular font indicating in range BG or general message
    static let InRangeFont: UIFont = UIFont(name: "Quicksand-Regular", size: UIFont.DefaultSize)!
    
    /// Small, semi bold font - typically for the display of units.
    static let SmallFont: UIFont = UIFont(name: "Quicksand-SemiBold", size: UIFont.SmallSize)!
    
    /// Small, light font - typically for the display of units.
    static let MiniFont: UIFont = UIFont(name: "Quicksand-SemiBold", size: UIFont.SmallSize * 0.75)!

}
