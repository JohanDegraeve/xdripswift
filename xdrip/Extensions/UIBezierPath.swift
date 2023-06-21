//
//  CGPoint.swift
//  xdrip
//
//  Created by Todd Dalton on 20/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit

extension UIBezierPath {
    
    /**
     Rotates a path by `radians` within a given `CGRect`. The zero point is modified
     to be vertically straight up.
     
     - Parameter radians: a `CGFloat` of radians from the 12 o'clock position.
     - Parameter rect: The `CGRect` that the path is to be based in.
     
     This function applies a transformation, a rotation, and then the inverse transformation
     to get a path that's rotated around the centre of the `rect`.
     */
    func rotateBy(radians: CGFloat, within rect: CGRect) {
        apply(CGAffineTransform(translationX: -rect.midX, y: -rect.midY))
        apply(CGAffineTransform(rotationAngle: radians - CGFloat.pi))
        apply(CGAffineTransform(translationX: rect.midX, y: rect.midY))
    }
    
    /**
     The same as `rotateBy(_: _:)` but takes degrees and not radians.
     */
    func rotateBy(degrees: CGFloat, within rect: CGRect) {
        rotateBy(radians: (degrees / 360) * (CGFloat.pi * 2), within: rect)
    }
}
