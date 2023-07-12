//
//  NSLayoutConstraint.swift
//  xdrip
//
//  Created by Todd Dalton on 03/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit

extension NSLayoutConstraint {
    
    // Convenience functions for the NSLayoutContraint methods - I find them tedious to set out!
    
    /// Fixes a constraint of the `subView` to the same constraint of `superView`
    ///
    /// Optionally you can also provide a multiplier and offset (a.k.a constant in the original method signatures)
    static func fix(constraint: NSLayoutConstraint.Attribute, of subView: UIView, toSameOfView superView: UIView, offset: CGFloat = 0.0, multiplier: CGFloat = 1.0) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: subView, attribute:constraint, relatedBy: .equal, toItem: superView, attribute: constraint, multiplier: multiplier, constant: offset)
    }
    
    /// Fixes a constraint of the `subView` to another constraint of `superView`
    ///
    /// Optionally you can also provide a multiplier and offset (a.k.a constant in the original method signatures)
    static func fix(constraint: NSLayoutConstraint.Attribute, of subView: UIView, to otherConstraint: NSLayoutConstraint.Attribute, ofView superView: UIView, offset: CGFloat = 0.0, multiplier: CGFloat = 1.0) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: subView, attribute: constraint, relatedBy: .equal, toItem: superView, attribute: otherConstraint, multiplier: multiplier, constant: offset)
    }
    
    /// Fixes left, right, top ,bottom of `aView` to it's `superView`.
    ///
    /// Optionally you can also provide a multiplier an inset (+/- constant from the original edges
    static func fixAllSides(of aView: UIView, to theSuperView: UIView, withInset delta:CGFloat = 0.0) {
        theSuperView.addSubview(aView)
        aView.translatesAutoresizingMaskIntoConstraints = false
        let left = NSLayoutConstraint.fix(constraint: .left, of: aView, toSameOfView: theSuperView, offset: delta)
        left.identifier = "left \(String(describing: aView.self))"
        let right = NSLayoutConstraint.fix(constraint: .right, of: aView, toSameOfView: theSuperView, offset: -delta)
        right.identifier = "right \(String(describing: aView.self))"
        let top = NSLayoutConstraint.fix(constraint: .top, of: aView, toSameOfView: theSuperView, offset: delta)
        top.identifier = "top \(String(describing: aView.self))"
        let bottom = NSLayoutConstraint.fix(constraint: .bottom, of: aView, toSameOfView: theSuperView, offset: -delta)
        bottom.identifier = "bottom \(String(describing: aView.self))"
        
        theSuperView.addConstraints([left, right, top, bottom])
    }
}
