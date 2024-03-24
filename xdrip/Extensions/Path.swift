//
//  Path.swift
//  xdrip
//
//  Created by Todd Dalton on 11/01/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

extension Path {
    
    /// Adds a curve to the receiving path with control points
    ///
    /// The control points are offset along the x-axis by the horizontal distance between the receiver
    /// and a `point` which is divided by `curved`. the default, 2, gives a nice ease-in and out for the curve.
    /// `curved` is clamped to >= 0.1.
    mutating func addCurveWithControlPoints(to point: CGPoint, curved: CGFloat = 2.0) {
        
        guard let lastPoint = currentPoint else { return }
        
        let clampedCurved = max(0.1, curved)
        addCurve(to: point,
                 control1: lastPoint.offset(dx: (point.x - lastPoint.x) / clampedCurved),
                 control2: point.offset(dx: (lastPoint.x - point.x) / clampedCurved))
    }
    
}

