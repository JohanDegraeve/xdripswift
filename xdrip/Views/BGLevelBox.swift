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
class BGLevelBox: RoundedBackingView {
    
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
            
            let display = _level.mmollValue.displaySettings(isOldValue: _level.isOld)
            fillColour = display.colour
            strokeColour = display.colour
        }
    }
    
    
    // To help with code legibility
    private var userLikesMgDl: Bool {
        return UserDefaults.standard.bloodGlucoseUnitIsMgDl
    }
    
    /// The text attributes for the digits and decimal point
    private var digitsAttributes: [NSAttributedString.Key : AnyObject] = [
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
    private var digitsViews: [UILabel] = [UILabel(), UILabel(), UILabel()]
    
    /// This is the decimal point that permanently stays in the middle of the view. Hidden when showing mg/dL
    private var pointView: UILabel = UILabel()

    // The views to make up the display
    // -------------------------------------------------------------
    
    override func didMoveToSuperview() {
        
        /// Sets the width of the delta view and the timestampt views' width
        backgroundColor = UIColor.clear
        
        // This is the UIStackView that holds the 3 digits.
        let digitsStackView: UIStackView = UIStackView()
        digitsStackView.axis = .horizontal
        digitsStackView.spacing = 5.0
        digitsStackView.alignment = .center
        digitsStackView.distribution = .fillEqually
        digitsStackView.backgroundColor = .clear
        addSubview(digitsStackView)
        digitsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.fixAllSides(of: digitsStackView, to: self, withInset: 10.0)
        
        let digitPadding: CGFloat = 15.0

        // Arguably this is a little too desperate an attempt at D.R.Y......
        for i in 0 ..< digitsViews.count {
            digitsStackView.addArrangedSubview(digitsViews[i])
            digitsViews[i].backgroundColor = UIColor(white: 1.0, alpha: 0.15) // give each digit a slightly opaque background for prettiness.
            digitsViews[i].translatesAutoresizingMaskIntoConstraints = false
            digitsStackView.addConstraint(NSLayoutConstraint.fix(constraint: .height, of: digitsViews[i], toSameOfView: digitsStackView))
            digitsViews[i].adjustsFontSizeToFitWidth = true
            digitsViews[i].minimumScaleFactor = 0.5
        }
        
        // Setup decimal point. Visible only when we're using md/dL.
        addSubview(pointView)
        pointView.backgroundColor = UIColor.clear
        pointView.adjustsFontSizeToFitWidth = true
        pointView.minimumScaleFactor = 1
        
        let leftFix = NSLayoutConstraint.fix(constraint: .left, of: pointView, to: .right, ofView: digitsViews[1], offset: -digitPadding)
        let topFix = NSLayoutConstraint.fix(constraint: .top, of: pointView, toSameOfView: self)
        let bottomFix = NSLayoutConstraint.fix(constraint: .bottom, of: pointView, toSameOfView: self, offset: -digitPadding * 2)
        let rightFix = NSLayoutConstraint.fix(constraint: .right, of: pointView, to: .left, ofView: digitsViews[2], offset: digitPadding)
        pointView.translatesAutoresizingMaskIntoConstraints = false
        addConstraints([leftFix, topFix, rightFix, bottomFix])
        bringSubviewToFront(pointView)
        pointView.attributedText = NSAttributedString(string: ".", attributes: digitsAttributes)
    }
    
    
    override func draw(_ rect: CGRect) {
        
        guard let level = level else {
            // We have a special case - typically at startup
            pointView.isHidden = true
            digitsViews[0].attributedText = NSAttributedString(string: "-", attributes: digitsAttributes)
            digitsViews[1].attributedText = NSAttributedString(string: "-", attributes: digitsAttributes)
            digitsViews[2].attributedText = NSAttributedString(string: "-", attributes: digitsAttributes)
            return
        }

        // Get the colour of the text according to range value
        // We'll have a tuple with the colour and the font.
        let displaySettings =  level.mmollValue.displaySettings(isOldValue: level.isOld)
        
        // Give the digits and decimal point a bold setting according to the level of the BG
        digitsAttributes[NSAttributedString.Key.font] = displaySettings.font
        
        var displayString = level.mmollValue.string
        
        if userLikesMgDl {
            
            displayString = level.mgdlValue.string
            pointView.isHidden = true
            
            if level.mgdlValue.rangeDescription == .special {
                // we've a special case
                pointView.isHidden = true
                displayString = level.mgdlValue.unitisedString
            } else {
                // Add any necessary front padding: " 84" or " 2.3"
                displayString = (level.mgdlValue < 100 ? " " : "") + displayString
            }
            
        } else {
            // User likes mmol/L
            // Add any necessary front padding: " 84" or " 2.3"
            displayString = (level.mmollValue < 10 ? " " : "") + displayString
            pointView.isHidden = false
        }
        
        // Assign the digits and format the decimal point
        digitsViews[0].attributedText = NSAttributedString(string: String(displayString[0]), attributes: digitsAttributes)
        digitsViews[1].attributedText = NSAttributedString(string: String(displayString[1]), attributes: digitsAttributes)
        digitsViews[2].attributedText = NSAttributedString(string: String(displayString.last!), attributes: digitsAttributes)
        pointView.attributedText = NSAttributedString(string: ".", attributes: digitsAttributes)
        
        super.draw(rect)
    }
}
