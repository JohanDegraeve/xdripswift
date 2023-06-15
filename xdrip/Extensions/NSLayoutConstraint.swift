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
    static func fix(constraint: NSLayoutConstraint.Attribute, of subView: UIView, toSameOfView superView: UIView, offset: CGFloat = 0.0, multiplier: CGFloat = 1.0) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: subView, attribute:constraint, relatedBy: .equal, toItem: superView, attribute: constraint, multiplier: multiplier, constant: offset)
    }
    
    static func fix(constraint: NSLayoutConstraint.Attribute, of subView: UIView, to otherConstraint: NSLayoutConstraint.Attribute, ofView superView: UIView, offset: CGFloat = 0.0, multiplier: CGFloat = 1.0) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: subView, attribute: constraint, relatedBy: .equal, toItem: superView, attribute: otherConstraint, multiplier: multiplier, constant: offset)
    }
}
