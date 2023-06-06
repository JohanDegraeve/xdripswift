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
    static func fix(_side: NSLayoutConstraint.Attribute, of _subView: UIView, to _superView: UIView) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: _subView, attribute: _side, relatedBy: .equal, toItem: _superView, attribute: _side, multiplier: 1.0, constant: 0.0)
    }
    
    static func fix(_side: NSLayoutConstraint.Attribute, of _subView: UIView, to __side: NSLayoutConstraint.Attribute, of _superView: UIView) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: _subView, attribute: _side, relatedBy: .equal, toItem: _superView, attribute: __side, multiplier: 1.0, constant: 0.0)
    }
}
