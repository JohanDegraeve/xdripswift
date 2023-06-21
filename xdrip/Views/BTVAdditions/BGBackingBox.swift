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
    private var _alpha: CGFloat = 0.2

    private var _fillColour: UIColor!
    private var _strokeColour: UIColor!
    
    /// The text attributes for the value type
    private var _valueTypeAttributes: [NSAttributedString.Key : AnyObject] = [
        NSAttributedString.Key.font : UIFont.SmallFont,
        NSAttributedString.Key.paragraphStyle : NSParagraphStyle.centredText(),
        NSAttributedString.Key.foregroundColor : UIColor.black
    ]
    
    var isTranslucent: Bool = true {
        didSet {
            _alpha = isTranslucent ? 0.2 : 1.0
        }
    }
    
    private var _title:UILabel = UILabel()
    
    override func didMoveToSuperview() {
        _fillColour = UIColor(white: 1.0, alpha: _alpha)
        _strokeColour = UIColor.white
        addSubview(_title)
        bringSubviewToFront(_title)
        _title.translatesAutoresizingMaskIntoConstraints = false
        let _t_fix = NSLayoutConstraint.fix(constraint: .top, of: _title, toSameOfView: self)
        let _centre_fix = NSLayoutConstraint.fix(constraint: .centerX, of: _title, toSameOfView: self)
        let _width = NSLayoutConstraint.fix(constraint: .width, of: _title, toSameOfView: self, multiplier: 0.4)
        _title.fixedConstraint(of: .height, value: 18.0)
        addConstraints([_t_fix, _width, _centre_fix])
    }
    
    /// Set this range description to affect the colour of the box
    var bgValue: UniversalBGLevel? = nil {
        didSet {
            
            defer {
                backgroundColor = UIColor.clear
                setNeedsDisplay()
            }
            
            guard let _bg = bgValue, !_bg.isOld else { // 11 mins == 660 secs
                _strokeColour = UIColor.lightGray
                _fillColour = UIColor(white: 0.0, alpha: 0)
                return
            }
            
            _title.attributedText = NSAttributedString(string: _bg.userPrefersMGDL ? Texts_Common.mgdl : Texts_Common.mmol, attributes: _valueTypeAttributes)
            _strokeColour = _bg.mgdl.displaySettings(isOldValue: false).colour
            _fillColour = _bg.mgdl.displaySettings(isOldValue: false).colour.withAlphaComponent(_alpha)
        }
    }

    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        
        var _boxPath = UIBezierPath(roundedRect: rect.insetBy(dx: 10.0, dy: 10.0), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 15.0, height: 15.0))
        _boxPath.lineWidth = 4.0
        _strokeColour.setStroke()
        _fillColour.setFill()
        _boxPath.fill()
        _boxPath.stroke()
        
        _boxPath = UIBezierPath(roundedRect: _title.frame.offsetBy(dx: 0.0, dy: 1.0), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 5.0, height: 5.0))
        _strokeColour.setFill()
        _boxPath.fill()
        
    }


}
