//
//  UIView.swift
//  xdrip
//
//  Created by Todd Dalton on 16/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import UIKit

extension UIView {
    /// Adds an `NSLayoutConstraint` to the `superView` and activates it.
    func fixedConstraint(of constraint: NSLayoutConstraint.Attribute, value: CGFloat) -> () {
        guard let sView = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        sView.addConstraint(NSLayoutConstraint(item: self, attribute: constraint, relatedBy: .equal, toItem: nil, attribute: constraint, multiplier: 1.0, constant: value))
    }
}
