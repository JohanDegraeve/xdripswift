//
//  BGBackingBox.swift
//  xdrip
//
//  Created by Todd Dalton on 10/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import UIKit

/**
 This is a custom `BTVRoundedBackingView` and is used to draw a rounded rectangle around the BG level.
 
 The title is set to the user's desired units of the BG level,
 
 This has a 3 element `UILabel` array that will hold the digits used to make up the BG reading
 
If the units are mmol/l then the views will hold 1, 2, 3 for 12.3 and if the units
are mg/dl then they will hold 1, 2, 3 for 123. The units are shown by both the
title label and whether the decimal point view is hidden or not.

They're held in a horizontal `UIStackView` and this allows for the digits to always be nicely centralised within this view.
 */
class BGLevelBox: BTVRoundedBackingView {
    
    // -------------------------------------------------------------
    //MARK: - Main iVars
    
    /// This is the actual iVar that stores the BG level
    ///
    /// It gets set with either the members of the `bgReading` object that's put in
    /// or from the direct `Double` value passed in. It's typically `nil` at startup
    /// or loss of link(?)
    var level: UniversalBGLevel? = nil {
        didSet {
            
            defer {
                setNeedsDisplay()
                
            }
            guard let _level = level else {
                fillColour = .lightGray
                strokeColour = .white
                return
            }
            
            let _display = _level.mmoll.displaySettings(isOldValue: _level.isOld)
            fillColour = _display.colour
            strokeColour = _display.colour
        }
    }
    
    
    // To help with code legibility
    private var userLikesMgDl: Bool {
        return UserDefaults.standard.bloodGlucoseUnitIsMgDl
    }
    
    /// The text attributes for the value type
    private var _valueTypeAttributes: [NSAttributedString.Key : AnyObject] = [
        NSAttributedString.Key.font : UIFont.SmallFont,
        NSAttributedString.Key.paragraphStyle : NSParagraphStyle.centredText(),
        NSAttributedString.Key.foregroundColor : UIColor.black
    ]
    
    /// The text attributes for the digits and decimal point
    private var _digitsAttributes: [NSAttributedString.Key : AnyObject] = [
        NSAttributedString.Key.font : UIFont.InRangeFont,
        NSAttributedString.Key.paragraphStyle : NSParagraphStyle.centredText(),
        NSAttributedString.Key.foregroundColor : UIColor.white
    ]
    
    // Main iVars
    // -------------------------------------------------------------
    
    // -------------------------------------------------------------
    // MARK: -  The views to make up the display
    
    /// This is a 3 element `UILabel` array that will hold the digits used to make up the BG reading
    ///
    /// If the units are mmol/l then the views will hold 1, 2, 3 for 12.3 and if the units
    /// are mg/dl then they will hold 1, 2, 3 for 123. The difference in units is shown on both the
    /// title label and whether the decimal point view is hidden or not.
    ///
    /// This allows for the digits to always be nicely centralised within this view.
    private var _digitsViews: [UILabel] = [UILabel(), UILabel(), UILabel()]
    
    /// This is the decimal point that permanently stays in the middle of the view. Hidden when showing mg/dL
    private var _pointView: UILabel = UILabel()

    // The views to make up the display
    // -------------------------------------------------------------
    
    override func didMoveToSuperview() {
        
        /// Sets the width of the delta view and the timestampt views' width
        backgroundColor = UIColor.clear
        
        // This is the UIStackView that holds the 3 digits.
        let _digitsStackView: UIStackView = UIStackView()
        _digitsStackView.axis = .horizontal
        _digitsStackView.spacing = 5.0
        _digitsStackView.alignment = .center
        _digitsStackView.distribution = .fillEqually
        _digitsStackView.backgroundColor = .clear
        addSubview(_digitsStackView)
        _digitsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.fixAllSides(of: _digitsStackView, to: self, withInset: 10.0)
        
        let _digitPadding: CGFloat = 15.0

        // Arguably this is a little too desperate an attempt at D.R.Y......
        for i in 0 ..< _digitsViews.count {
            _digitsStackView.addArrangedSubview(_digitsViews[i])
            _digitsViews[i].backgroundColor = UIColor(white: 1.0, alpha: 0.15) // give each digit a slightly opaque background for prettiness.
            _digitsViews[i].translatesAutoresizingMaskIntoConstraints = false
            _digitsStackView.addConstraint(NSLayoutConstraint.fix(constraint: .height, of: _digitsViews[i], toSameOfView: _digitsStackView))
            _digitsViews[i].adjustsFontSizeToFitWidth = true
            _digitsViews[i].minimumScaleFactor = 0.5
        }
        
        // Setup decimal point. Visible only when we're using md/dL.
        addSubview(_pointView)
        _pointView.backgroundColor = UIColor.clear
        _pointView.adjustsFontSizeToFitWidth = true
        _pointView.minimumScaleFactor = 1
        
        let _left_fix = NSLayoutConstraint.fix(constraint: .left, of: _pointView, to: .right, ofView: _digitsViews[1], offset: -_digitPadding)
        let _top_fix = NSLayoutConstraint.fix(constraint: .top, of: _pointView, toSameOfView: self)
        let _bottom_fix = NSLayoutConstraint.fix(constraint: .bottom, of: _pointView, toSameOfView: self, offset: -_digitPadding * 2)
        let _right_fix = NSLayoutConstraint.fix(constraint: .right, of: _pointView, to: .left, ofView: _digitsViews[2], offset: _digitPadding)
        _pointView.translatesAutoresizingMaskIntoConstraints = false
        addConstraints([_left_fix, _top_fix, _right_fix, _bottom_fix])
        bringSubviewToFront(_pointView)
        _pointView.attributedText = NSAttributedString(string: ".", attributes: _digitsAttributes)
    }
    
    
    override func draw(_ rect: CGRect) {
        
        guard let _level = level else {
            // We have a special case - typically at startup
            _pointView.isHidden = true
            _digitsViews[0].attributedText = NSAttributedString(string: "-", attributes: _digitsAttributes)
            _digitsViews[1].attributedText = NSAttributedString(string: "-", attributes: _digitsAttributes)
            _digitsViews[2].attributedText = NSAttributedString(string: "-", attributes: _digitsAttributes)
            return
        }

        // Get the colour of the text according to range value
        // We'll have a tuple with the colour and the font.
        let _displaySettings =  _level.mmoll.displaySettings(isOldValue: _level.isOld)
        
        // Give the digits and decimal point a bold setting according to the level of the BG
        _digitsAttributes[NSAttributedString.Key.font] = _displaySettings.font
        
        var _displayString = _level.mmoll.string
        
        if userLikesMgDl {
            
            _displayString = _level.mgdl.string
            _pointView.isHidden = true
            
            if _level.mgdl.rangeDescription == .special {
                // we've a special case
                _pointView.isHidden = true
                _displayString = _level.mgdl.unitisedString
            } else {
                // Add any necessary front padding: " 84" or " 2.3"
                _displayString = (_level.mgdl < 100 ? " " : "") + _displayString
            }
            
        } else {
            // User likes mmol/L
            // Add any necessary front padding: " 84" or " 2.3"
            _displayString = (_level.mmoll < 10 ? " " : "") + _displayString
            _pointView.isHidden = false
        }
        
        // Assign the digits and format the decimal point
        _digitsViews[0].attributedText = NSAttributedString(string: String(_displayString[0]), attributes: _digitsAttributes)
        _digitsViews[1].attributedText = NSAttributedString(string: String(_displayString[1]), attributes: _digitsAttributes)
        _digitsViews[2].attributedText = NSAttributedString(string: String(_displayString.last!), attributes: _digitsAttributes)
        _pointView.attributedText = NSAttributedString(string: ".", attributes: _digitsAttributes)
        
        super.draw(rect)
    }
}
