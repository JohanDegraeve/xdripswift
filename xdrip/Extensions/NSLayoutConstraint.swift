//
//  NSLayoutConstraint.swift
//  xdrip
//
//  Created by Todd Dalton on 09/01/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit

extension NSLayoutConstraint {
    
    // Convenience functions for the NSLayoutContraint methods - I find them tedious to set out!
    
    /// Fixes a constraint of the `subView` to a definite value.
    ///
    /// Optionally you can also provide a multiplier, an offset (a.k.a constant in the original method signatures), and an identifier `String`
    static func fix(constraint: NSLayoutConstraint.Attribute, of subView: UIView, by relation:NSLayoutConstraint.Relation, with constant: CGFloat, multiplier: CGFloat = 1.0, id: String = "") -> NSLayoutConstraint {
        let retConstraint = NSLayoutConstraint(item: subView, attribute:constraint, relatedBy: relation, toItem: nil, attribute: constraint, multiplier: multiplier, constant: constant)
        retConstraint.identifier = (id.isEmpty ? UUID().uuidString : id)
        return retConstraint
    }
    
    /// Fixes a constraint of the `subView` to the same constraint of `superView`
    ///
    /// Optionally you can also provide a multiplier, an offset (a.k.a constant in the original method signatures), and an identifier `String`
    static func fix(constraint: NSLayoutConstraint.Attribute, of subView: UIView, toSameOfView superView: UIView, offset: CGFloat = 0.0, multiplier: CGFloat = 1.0, id: String = "") -> NSLayoutConstraint {
        let retConstraint = NSLayoutConstraint(item: subView, attribute:constraint, relatedBy: .equal, toItem: superView, attribute: constraint, multiplier: multiplier, constant: offset)
        retConstraint.identifier = (id.isEmpty ? UUID().uuidString : id)
        return retConstraint
    }
    
    /// Fixes a constraint of the `subView` to another constraint of `superView`
    ///
    /// Optionally you can also provide a multiplier, an offset (a.k.a constant in the original method signatures), and an identifier `String`
    static func fix(constraint: NSLayoutConstraint.Attribute, of subView: UIView, to otherConstraint: NSLayoutConstraint.Attribute, ofView superView: UIView, offset: CGFloat = 0.0, multiplier: CGFloat = 1.0, id:String = "") -> NSLayoutConstraint {
        let retConstraint = NSLayoutConstraint(item: subView, attribute: constraint, relatedBy: .equal, toItem: superView, attribute: otherConstraint, multiplier: multiplier, constant: offset)
        retConstraint.identifier = (id.isEmpty ? UUID().uuidString : id)
        return retConstraint
    }
    
    /// Fixes left, right, top ,bottom of `aView` to it's `superView`.
    ///
    /// Optionally you can also provide a multiplier, an offset (a.k.a constant in the original method signatures), and an identifier `String`
    static func fixAllSides(of aView: UIView, to theSuperView: UIView, withInset delta:CGFloat = 0.0, idPrefix: String = "") {
        theSuperView.addSubview(aView)
        aView.translatesAutoresizingMaskIntoConstraints = false
        let left = NSLayoutConstraint.fix(constraint: .left, of: aView, toSameOfView: theSuperView, offset: delta, id: "left_\(idPrefix.isEmpty ? String(describing: aView.self) : idPrefix)")
        let right = NSLayoutConstraint.fix(constraint: .right, of: aView, toSameOfView: theSuperView, offset: -delta, id: "right_\(String(describing: aView.self))")
        let top = NSLayoutConstraint.fix(constraint: .top, of: aView, toSameOfView: theSuperView, offset: delta, id: "top_\(String(describing: aView.self))")
        let bottom = NSLayoutConstraint.fix(constraint: .bottom, of: aView, toSameOfView: theSuperView, offset: -delta, id: "bottom_\(String(describing: aView.self))")
        
        theSuperView.addConstraints([left, right, top, bottom])
    }
    
    convenience init(item view1: Any,
                     attribute attr1: NSLayoutConstraint.Attribute,
                     relatedBy relation: NSLayoutConstraint.Relation,
                     toItem view2: Any?,
                     attribute attr2: NSLayoutConstraint.Attribute,
                     multiplier: CGFloat,
                     constant c: CGFloat,
                     id: String) {
        self.init()
        self.init(item: view1, attribute: attr1, relatedBy: relation, toItem: view2, attribute: attr2, multiplier: multiplier, constant: constant)
        self.identifier = id.isEmpty ? "_!_" : id
    }
}
