//
//  BGBackingBox.swift
//  xdrip
//
//  Created by Todd Dalton on 10/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import UIKit

/**
 This is a custom `UIView` to draw a rounded rectangle around the BG level
 */
class BGBackingBox: UIView {
    
    // Alpha setting for fill colour
    private let _alpha: CGFloat = 0.2

    private var _fillColour: UIColor!
    private var _strokeColour: UIColor!
    
    override func didMoveToSuperview() {
    _fillColour = UIColor(white: 1.0, alpha: _alpha)
    _strokeColour = UIColor.white
    }

    /// Set this range description to affect the colour of the box
    var bgValue: UniversalBGLevel? = nil {
        didSet {
            
            defer {
                setNeedsDisplay()
            }
            
            guard let _bg = bgValue, _bg.timestamp.timeIntervalSinceNow > -660 else { // 11 mins == 660 secs
                _strokeColour = UIColor.lightGray
                _fillColour = UIColor(white: 0.0, alpha: 0)
                return
            }
            _strokeColour = _bg.mgdl.displaySettings(isOldValue: false).colour
            _fillColour = _bg.mgdl.displaySettings(isOldValue: false).colour.withAlphaComponent(_alpha)
        }
    }

    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        
        let _boxPath = UIBezierPath(roundedRect: rect.insetBy(dx: 10.0, dy: 10.0), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 15.0, height: 15.0))
        _boxPath.lineWidth = 4.0
        _strokeColour.setStroke()
        _fillColour.setFill()
        _boxPath.fill()
        _boxPath.stroke()
    }


}
