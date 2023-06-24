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
class BGBackingBox: BTVRoundedBackingView {
    
    /// The text attributes for the value type
    private var _valueTypeAttributes: [NSAttributedString.Key : AnyObject] = [
        NSAttributedString.Key.font : UIFont.SmallFont,
        NSAttributedString.Key.paragraphStyle : NSParagraphStyle.centredText(),
        NSAttributedString.Key.foregroundColor : UIColor.black
    ]

    override func didMoveToSuperview() {
        fillColour = UIColor(white: 1.0, alpha: _alpha)
        strokeColour = UIColor.white
        addSubview(_titleLabel)
        bringSubviewToFront(_titleLabel)
        _titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let _t_fix = NSLayoutConstraint.fix(constraint: .top, of: _titleLabel, toSameOfView: self)
        let _centre_fix = NSLayoutConstraint.fix(constraint: .centerX, of: _titleLabel, toSameOfView: self)
        let _width = NSLayoutConstraint.fix(constraint: .width, of: _titleLabel, toSameOfView: self, multiplier: 0.4)
        _titleLabel.fixedConstraint(of: .height, value: 18.0)
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
                strokeColour = UIColor.lightGray
                fillColour = UIColor(white: 0.0, alpha: 0)
                return
            }
            
            _titleLabel.attributedText = NSAttributedString(string: _bg.userPrefersMGDL ? Texts_Common.mgdl : Texts_Common.mmol, attributes: _valueTypeAttributes)
            strokeColour = _bg.mgdl.displaySettings(isOldValue: false).colour
            fillColour = _bg.mgdl.displaySettings(isOldValue: false).colour.withAlphaComponent(_alpha)
        }
    }

}

/// This class draws a rounded rect as a backing to text
class BTVRoundedBackingView: UIView {
    
    // Alpha setting for background fill colour
    fileprivate var _alpha: CGFloat = 0.2

    var fillColour: UIColor = UIColor.white
    var strokeColour: UIColor = UIColor.white
    
    var isTranslucent: Bool = true {
        didSet {
            _alpha = isTranslucent ? 0.5 : 0.0
            setNeedsDisplay()
        }
    }
    
    var borderWidth: CGFloat = 4.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /// The text attributes for the title
    private var _titleAttributes: [NSAttributedString.Key : AnyObject] = [
        NSAttributedString.Key.font : UIFont.SmallFont,
        NSAttributedString.Key.paragraphStyle : NSParagraphStyle.centredText(),
        NSAttributedString.Key.foregroundColor : UIColor.black
    ]
    
    /// The `UILabel` that holds the title string
    fileprivate var _titleLabel:UILabel = UILabel()
    
    /// The displayed title label.
    ///
    /// Set to `nil` to hide the label
    var title: String? = nil {
        didSet {
            
            defer {
                setNeedsDisplay()
            }
            
            guard let _title = title else {
                _titleLabel.isHidden = true
                return
            }
            
            _titleLabel.attributedText = NSAttributedString(string: _title, attributes: _titleAttributes)
            _titleLabel.isHidden = false
        }
    }
    
    override func didMoveToSuperview() {
        addSubview(_titleLabel)
        bringSubviewToFront(_titleLabel)
        _titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let _t_fix = NSLayoutConstraint.fix(constraint: .top, of: _titleLabel, toSameOfView: self)
        let _centre_fix = NSLayoutConstraint.fix(constraint: .centerX, of: _titleLabel, toSameOfView: self)
        let _width = NSLayoutConstraint.fix(constraint: .width, of: _titleLabel, toSameOfView: self, multiplier: 0.4)
        _titleLabel.fixedConstraint(of: .height, value: 18.0)
        addConstraints([_t_fix, _width, _centre_fix])
        _titleLabel.isHidden = true
    }
    
    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        
        var _boxPath = UIBezierPath(roundedRect: rect.insetBy(dx: borderWidth, dy: borderWidth), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 10.0, height: 10.0))
        _boxPath.lineWidth = borderWidth
        strokeColour.setStroke()
        fillColour.withAlphaComponent(_alpha).setFill()
        _boxPath.fill()
        _boxPath.stroke()
        
        if !_titleLabel.isHidden {
            // Draw the backing to the title
            _boxPath = UIBezierPath(roundedRect: _titleLabel.frame.offsetBy(dx: 0.0, dy: 1.0), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 5.0, height: 5.0))
            strokeColour.setFill()
            _boxPath.fill()
        }
    }
}
