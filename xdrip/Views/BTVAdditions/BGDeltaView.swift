//
//  BGDeltaView.swift
//  xdrip
//
//  Created by Todd Dalton on 16/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import UIKit

/**
 This class displays a dial with an arrow that indicates the rate of change of BG levels.
 
 As the rate of change approaches the maximun (±3.5) then a second arrow's alpha is changed to make it more visible.
 This should indicate to the user whether the rate of change is urgent or not.
 */
class BGDeltaView: UIView {
    
    /// When the slope is changed then this will be updated
    private var _angle: CGFloat = 0.0
    
    /// This is the slope calculated in the app. If set to `nil` then arrow will not be displayed
    var slope: (string: String, double: Double)? = nil {
        didSet {
            guard let _slope = slope else {
                _angle = 0.0
                return
            }
            
            // Not ideal, and a little confusing but converting to mmol/L is easier for this particular algorithm
            // slope is received in range -3.5 ... 3.5 mmol
            let normalisedSlope = -1 * max(-3.5, min(_slope.double.mgdlToMmol(), 3.5))
            
            // 0 is pointing right
            // -PI/2 is up
            // +PI/2 is down
            _angle = ((normalisedSlope / 3.5) * (CGFloat.pi)) / 2
            
            setNeedsDisplay()
        }
    }
    
    /// Colour of arrow and delta numbers
    var colour: UIColor = UIColor.green {
        didSet {
            tintColor = colour
            _deltaValue.textColor = colour
        }
    }
    
    /// The digits go here
    private var _deltaValue: UILabel = UILabel()
    
    
    // -------------------------------------------------------------
    // The views to make up the display
    // Use rendering mode .alwaysTemplate if the png has an alpha, or .alwaysOriginal if it doesn't. .automatic will correctly decide which more to use
    /// This is for the arrow
    private var _arrowImageView: UIImageView = UIImageView(image: UIImage(named: "BGArrow")!.withRenderingMode(.automatic))
    /// This is the additional arrow for very steep slopes
    private var _secondaryArrowImageView: UIImageView = UIImageView(image: UIImage(named: "BGSecondaryArrow")!.withRenderingMode(.automatic))
    /// This is the background of the delta view
    private var _backgroundImageView: UIImageView = UIImageView(image: UIImage(named: "BGDeltaBackground")!.withRenderingMode(.automatic))
    
    // The views to make up the display
    // -------------------------------------------------------------
    
    override func didMoveToSuperview() {
        
        // Setup background
        NSLayoutConstraint.fixAllSides(of: _backgroundImageView, to: self)
        
        // Setup arrow
        NSLayoutConstraint.fixAllSides(of: _arrowImageView, to: self)
        _arrowImageView.backgroundColor = UIColor.clear
        
        // Setup second arrow
        NSLayoutConstraint.fixAllSides(of: _secondaryArrowImageView, to: _arrowImageView)
        _secondaryArrowImageView.backgroundColor = UIColor.clear
        _arrowImageView.bringSubviewToFront(_arrowImageView)
        
        // Set up delta label
        addSubview(_deltaValue)
        _deltaValue.translatesAutoresizingMaskIntoConstraints = false
        _deltaValue.backgroundColor = .clear
        let _d_vert_fix = NSLayoutConstraint.fix(constraint: .centerY, of: _deltaValue, toSameOfView: self)
        let _d_horiz_fix = NSLayoutConstraint.fix(constraint: .centerX, of: _deltaValue, toSameOfView: self, offset: 10.0)
        let _d_width = NSLayoutConstraint.fix(constraint: .width, of: _deltaValue, toSameOfView: self)
        let _d_height_fix = NSLayoutConstraint.fix(constraint: .height, of: _deltaValue, toSameOfView: self, multiplier: 0.4)
        
        addConstraints([_d_vert_fix, _d_horiz_fix, _d_width, _d_height_fix])
        
        _deltaValue.attributedText = NSAttributedString(string: "--.--", attributes: [.font : UIFont.SmallFont, .foregroundColor : UIColor.white, .paragraphStyle : NSParagraphStyle.leftJustified(), .backgroundColor : UIColor.clear])
        
        bringSubviewToFront(_deltaValue)
        sendSubviewToBack(_backgroundImageView)
        
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        guard let _slope = slope else { return }
        
        // Rotate the arrow according to the slope
        _arrowImageView.transform = CGAffineTransform(rotationAngle: _angle)
        _secondaryArrowImageView.alpha = ((max(abs(_angle / (CGFloat.pi / 2)), 0.5)) - 0.5) * 2
        _deltaValue.text = _slope.string
    }
}
