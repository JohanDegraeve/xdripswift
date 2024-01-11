//
//  CGPoint.swift
//  xdrip
//
//  Created by Todd Dalton on 09/01/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

extension CGPoint {
    func offset(dx: CGFloat = 0.0, dy: CGFloat = 0.0) -> CGPoint {
        return CGPoint(x: x + dx, y: y + dy)
    }
    
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGFloat {
        let a = rhs.x - lhs.x
        let b = rhs.y - lhs.y
        
        return sqrt((a * a) + (b * b))
    }
    
    /// Find the angle a `pointB` is from a `pointA`
    func angle(of pointB: CGPoint) -> CGFloat {
        let b = pointB.y - self.y
        let a = pointB.x - self.x
        return atan(b / a)
    }
    
    /// Rotate a point around receiver
    ///
    /// https://stackoverflow.com/a/2259502
    func rotate(aPoint point: CGPoint, by radians: CGFloat) -> CGPoint {
        let normalised: CGPoint = CGPoint(x: point.x - x, y: point.y - y)
        let sine = sin(radians)
        let cosine = cos(radians)
        
        let xnew = normalised.x * cosine - normalised.y * sine
        let ynew = normalised.x * sine + normalised.y * cosine
        
        return CGPoint(x: xnew + self.x, y: ynew + self.y)
    }
    
    /// This gets a point for a bezier curve that passes through the middle CGPoint
    func controlPoint(with rightPoint: CGPoint) -> (CGPoint) {
        // Imagine a box where the left and right points form the bottom left and bottom right corners
        let box: CGRect = CGRect(origin: self, size: CGSize(width: (rightPoint - self), height: (rightPoint - self)))
        // At this point the box is sitting 'on the ground', i.e. the angle between the two points hasn't been accounted for
        let controlPoint: CGPoint = CGPoint(x: box.midX, y: box.maxY)
        let angle = self.angle(of: rightPoint)
        // Now apply the transform to take care of the angle between two points
        // Return the top right hand corner of the `CGRect`
        return self.rotate(aPoint: controlPoint, by: angle)
    }
}
