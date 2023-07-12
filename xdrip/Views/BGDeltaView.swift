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
    private var arrowAngle: CGFloat = 0.0
    
    /// This is the slope calculated in the app. If set to `nil` then arrow will not be displayed
    var slope: (string: String, double: Double)? = nil {
        didSet {
            guard let slope = slope else {
                arrowAngle = 0.0
                return
            }
            
            // Not ideal, and a little confusing but converting to mmol/L is easier for this particular algorithm
            // slope is received in range -3.5 ... 3.5 mmol
            let normalisedSlope = -1 * max(-3.5, min(slope.double.mgdlToMmol(), 3.5))
            
            // 0 is pointing right
            // -PI/2 is up
            // +PI/2 is down
            arrowAngle = ((normalisedSlope / 3.5) * (CGFloat.pi)) / 2
            
            setNeedsDisplay()
        }
    }
    
    /// Colour of arrow and delta numbers
    var colour: UIColor = UIColor.green {
        didSet {
            tintColor = colour
            deltaValue.textColor = colour
        }
    }
    
    /// The digits go here
    private var deltaValue: UILabel = UILabel()
    
    
    // -------------------------------------------------------------
    // The views to make up the display
    // Use rendering mode .alwaysTemplate if the png has an alpha, or .alwaysOriginal if it doesn't. .automatic will correctly decide which more to use
    /// This is for the arrow
    private var arrowImageView: UIImageView = UIImageView(image: UIImage(named: "BGArrow")!.withRenderingMode(.automatic))
    /// This is the additional arrow for very steep slopes
    private var secondaryArrowImageView: UIImageView = UIImageView(image: UIImage(named: "BGSecondaryArrow")!.withRenderingMode(.automatic))
    /// This is the background of the delta view
    private var backgroundImageView: UIImageView = UIImageView(image: UIImage(named: "BGDeltaBackground")!.withRenderingMode(.automatic))
    
    // The views to make up the display
    // -------------------------------------------------------------
    
    override func didMoveToSuperview() {
        
        // Setup background
        NSLayoutConstraint.fixAllSides(of: backgroundImageView, to: self)
        
        // Setup arrow
        NSLayoutConstraint.fixAllSides(of: arrowImageView, to: self)
        arrowImageView.backgroundColor = UIColor.clear
        
        // Setup second arrow
        NSLayoutConstraint.fixAllSides(of: secondaryArrowImageView, to: arrowImageView)
        secondaryArrowImageView.backgroundColor = UIColor.clear
        arrowImageView.bringSubviewToFront(arrowImageView)
        
        // Set up delta label
        addSubview(deltaValue)
        deltaValue.translatesAutoresizingMaskIntoConstraints = false
        deltaValue.backgroundColor = .clear
        let dVertFix = NSLayoutConstraint.fix(constraint: .centerY, of: deltaValue, toSameOfView: self)
        let dHorizFix = NSLayoutConstraint.fix(constraint: .centerX, of: deltaValue, toSameOfView: self, offset: 10.0)
        let dWidthFix = NSLayoutConstraint.fix(constraint: .width, of: deltaValue, toSameOfView: self)
        let dHeightFix = NSLayoutConstraint.fix(constraint: .height, of: deltaValue, toSameOfView: self, multiplier: 0.4)
        
        addConstraints([dVertFix, dHorizFix, dWidthFix, dHeightFix])
        
        deltaValue.attributedText = NSAttributedString(string: "--.--", attributes: [.font : UIFont.SmallFont, .foregroundColor : UIColor.white, .paragraphStyle : NSParagraphStyle.leftJustified(), .backgroundColor : UIColor.clear])
        
        bringSubviewToFront(deltaValue)
        sendSubviewToBack(backgroundImageView)
        
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        guard let slope = slope else { return }
        
        // Rotate the arrow according to the slope
        arrowImageView.transform = CGAffineTransform(rotationAngle: arrowAngle)
        secondaryArrowImageView.alpha = ((max(abs(arrowAngle / (CGFloat.pi / 2)), 0.5)) - 0.5) * 2
        deltaValue.text = slope.string
    }
}
