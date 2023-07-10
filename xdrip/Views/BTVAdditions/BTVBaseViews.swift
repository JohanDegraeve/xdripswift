//
//  BTVBaseViews.swift
//  xdrip
//
//  Created by Todd Dalton on 27/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit


//MARK: -

/**
 This subclass adds a `UILabel` on top of the `BTVRoundedBackingView`
 */
class BTVRoundRectLabel: BTVRoundedBackingView {
    
    fileprivate var _label: UILabel = UILabel()
    
    var text: String = "" {
        didSet {
            _label.text = text
            setNeedsDisplay()
        }
    }

    var attributedText: NSAttributedString  = NSAttributedString() {
        didSet {
            _label.attributedText = attributedText
            setNeedsDisplay()
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        addSubview(_label)
        bringSubviewToFront(_label)
        NSLayoutConstraint.fixAllSides(of: _label, to: self)
    }
}

//MARK: -
/// This class draws a rounded rect in a `UIView`
///
/// It's used as a backing to text (`UILabel`) and is the basis for the timestamp and BGLevel displays.
/// It has a title box which can be drawn by setting the `title` iVar and is positioned top, middle of the view.
/// You can set the border width as well as the fill and stroke colours.
///
/// If `isTranslucent` is true then the box has a 0.2 alpha fill applied, otherwise it's a clear background. The border is always drawn with an `alpha` of 1.0
/// irrespective of what the `fillColour` is set to.
class BTVRoundedBackingView: UIView {
    
    // Alpha setting for background fill colour
    fileprivate var _alpha: CGFloat = 0.2

    fileprivate var _fillColour: UIColor = .white
    /// Fill of the rectangle. Brightness of this is affected by `isTranslucent`
    var fillColour: UIColor = .white {
        didSet {
            setBackgroundBrightness()
        }
    }
    /// Colour of the outline - always solid
    var strokeColour: UIColor = UIColor.white
    
    /// Fills the rectangle with the fill colour. If it's `true` then the fill is mainly transparent
    var isTranslucent: Bool = true {
        didSet {
            setBackgroundBrightness()
        }
    }
    
    var borderWidth: CGFloat = 4.0 {
        didSet {
            setNeedsDisplay()
        }
    }    
    
    func setBorderAndFillColour(colour: UIColor) {
        fillColour = colour
        strokeColour = colour
        setNeedsDisplay()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        backgroundColor = UIColor.clear
    }
    
    /// We need to dim the brightness of the colour. Fill with alpha is not well supported.
    private func setBackgroundBrightness() {
        var h: CGFloat = 0.0, s: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
        fillColour.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        _fillColour = UIColor(hue: h, saturation: s, brightness: (isTranslucent ? 0.35 : 1.0), alpha: 1.0)
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        
        //Draw main outline
        let _boxPath = UIBezierPath(roundedRect: rect.insetBy(dx: borderWidth, dy: borderWidth), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 10.0, height: 10.0))
        _boxPath.lineWidth = borderWidth
        _fillColour.setFill()
        _boxPath.fill()
        strokeColour.setStroke()
        _boxPath.stroke(with: .normal, alpha: 1.0)
        
    }
}

