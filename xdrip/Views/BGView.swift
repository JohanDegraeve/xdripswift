//
//  CGMVView.swift
//  xDripCGMValueView
//
//  Created by Todd Dalton on 01/06/2023.
//

import UIKit

/**
 This is a view to hold the BG level (either curernt or if the user is panning), a `UIView` to show the delta of the latest reading (this is hidden if the user is panning), and a time stamp view.
 
 In order to distinguish between a current value and an older one, this view colours the BG level according to the colours defined in the constants.
 
 It uses a `BGLevelBox` to display the level which constantly displays the user's preferred units.
 For the numerical value, there are three digit displays (`UILabel`s) with slighty opaque backgrounds.
 The idea is that the level was originally just centre justified which meant during panning, the horizontal
 position of the number shifted to keep the whole figure centralised. Constantly displaying three digits
 (the most significant one, MSD, shows 1 ...9 or is empty) means that the value is held in one `x` position.
 A decimal place is shown when the user selects mmol/L as it's typically in the form of 10.7, or suchlike.
 */
class BGView: UIView {
    
    // -------------------------------------------------------------
    //MARK: - Main iVars
    
    /// This is the actual iVar that stores the BG level
    ///
    /// It gets set with either the members of the `bgReading` object that's put in
    /// or from the direct `Double` value passed in. It's typically `nil` at startup
    /// or loss of link(?)
    private var bg: UniversalBGLevel? = nil
    
    public static let BTChangePost: NSNotification.Name = NSNotification.Name("BTV_BT_Status_Update")
    
    // To help with code legibility
    private var userLikesMgDl: Bool {
        return UserDefaults.standard.bloodGlucoseUnitIsMgDl
    }
    
    /// The text attributes for the title
    private var titleAttributes: [NSAttributedString.Key : AnyObject] = [
        NSAttributedString.Key.font : UIFont.SmallFont,
        NSAttributedString.Key.paragraphStyle : NSParagraphStyle.centredText(),
        NSAttributedString.Key.backgroundColor : UIColor.clear,
        NSAttributedString.Key.foregroundColor : UIColor.black
    ]

    // Main iVars
    // -------------------------------------------------------------
    
    // -------------------------------------------------------------
    // MARK: -  The views to make up the display
    
    /// This is the delta display of the last reading
    private var deltaView: BGDeltaView = BGDeltaView()
    
    /// This is the backing box that is a rounded rectangle of the level value
    private var levelView: BGLevelBox = BGLevelBox()
 
    /// This is the timestamp for the current reading.
    ///
    /// If it shows anything other than 'now' then the delta view is switched off
    private var timeStampView: BGTimeStampView = BGTimeStampView()
    
    ///This holds a small view to indicate the BT status, connected, scanning, etc.
    private var btStatusView: BTStatusView = BTStatusView()
    
    /// The `UILabel` that holds the title string
    fileprivate var titleLabel:RoundRectLabelView = RoundRectLabelView()
    
    // The views to make up the display
    // -------------------------------------------------------------
    
    // -------------------------------------------------------------
    //MARK: - Methods
    
    /// Main `func` to set the level for display.
    ///
    /// This is called from the `RootController`when not panning and can be out of date if the last reading
    /// was > 1 minute ago.
    public func setValues(for reading: BgReading?, slope: (String, Double)?,btManager BTManager: BluetoothPeripheralManager?) {
        if let reading = reading {
            bg = bg ?? UniversalBGLevel() // make sure that we only create one of these
            bg!.mgdlValue = reading.mgdl
            bg!.timeStamp = reading.timeStamp
            if bg!.isOld {
                // It's old.... We set the time stamp so that the user can see the full date.
                timeStampView.date = bg!.timeStamp
                return
            } else {
                // It's current, setting this view to `nil` will main the current time with no date is displayed.
                timeStampView.date = nil
            }
        } else {
            bg = nil
        }
        btStatusView.btManager = BTManager
        deltaView.slope = slope
        levelView.setNeedsDisplay()
    }
    
    /**
     Function to directly set the BG level for display
     
     It's sometimes necessary to be able to set the BG level directly rather than via a `BgReading` var.
     For instance when the user pans around on the chart. The `bg` is set to `nil`, so turning off the arrow indicator.
     
     - Parameter _value: `Double` that is the BG level. **This can be in mmol/L or mg/dL**
     
     Currently this is only called during the panning operation from the `RootController`
     */
    public func directSetBGValue(value: Double, date: Date,btManager bTManager: BluetoothPeripheralManager?) {
        // In this case, setting the timestamp view's date to distant past will make the `BGView` look at this as an out of date level
        bg = UniversalBGLevel(aTimeStamp: Date.distantPast, aMgdlValue: MgDl(value.mmolToMgdl(mgdl: userLikesMgDl)))
        timeStampView.date = date
        setNeedsDisplay()
            btStatusView.btManager = bTManager
    }
    
    /// Convenience to set display to "- - -"
    public func setBlank() {
        bg = nil
        setNeedsDisplay()
    }
    
    override func didMoveToSuperview() {
        /// This is the vertical offset for the delta and BT status views the delta goes this far above centre, the status is this far below
        let centreOffset: CGFloat = 30.0
        
        /// Sets the width of the delta view and the timestampt views' width
        let sideViewsWidth: CGFloat = 80.0
        
        backgroundColor = UIColor.clear

        // Set up backing box. This draws the rounded rectangle box around the level
        levelView.isAccessibilityElement = true
        addSubview(levelView)
        levelView.translatesAutoresizingMaskIntoConstraints = false
        
        let bLeftFix = NSLayoutConstraint.fix(constraint: .left, of: levelView, to: .left, ofView: self, offset: sideViewsWidth)
        let bRightFix = NSLayoutConstraint.fix(constraint: .right, of: levelView, to: .right, ofView: self, offset: -sideViewsWidth)
        let bTopFix = NSLayoutConstraint.fix(constraint: .top, of: levelView, toSameOfView: self)
        let bBottomFix = NSLayoutConstraint.fix(constraint: .bottom, of: levelView, toSameOfView: self)
        
        addConstraints([bTopFix,bLeftFix,bRightFix,bBottomFix])
        sendSubviewToBack(levelView)
 
        //set up delta view. This is the small 'dial' to the right of the level showing the change rate.
        addSubview(deltaView)
        deltaView.isAccessibilityElement = false
        deltaView.translatesAutoresizingMaskIntoConstraints = false
        
        let dRightFix = NSLayoutConstraint.fix(constraint: .right, of: deltaView, toSameOfView: self)
        let dVertFix = NSLayoutConstraint.fix(constraint: .centerY, of: deltaView, toSameOfView: self)
        let dHeight = NSLayoutConstraint(item: deltaView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: sideViewsWidth)
        let dWidth = NSLayoutConstraint(item: deltaView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: sideViewsWidth)
        
        addConstraints([dVertFix, dRightFix, dHeight, dWidth])
        
        // Setup the timestamp view. 3 x text labels showing the date of the displayed level.
        addSubview(timeStampView)
        timeStampView.translatesAutoresizingMaskIntoConstraints = false
        timeStampView.isAccessibilityElement = false
        let tRightFix = NSLayoutConstraint.fix(constraint: .left, of: timeStampView, toSameOfView: self)
        let tVertFix = NSLayoutConstraint.fix(constraint: .centerY, of: timeStampView, toSameOfView: deltaView)
        let tHeight = NSLayoutConstraint(item: timeStampView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: sideViewsWidth)
        let tWidth = NSLayoutConstraint(item: timeStampView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: sideViewsWidth)
        
        addConstraints([tVertFix, tRightFix, tHeight, tWidth])
        
        timeStampView.isHidden = true
        
        // Bluetooth Status
        addSubview(btStatusView)
        btStatusView.isAccessibilityElement = true
        btStatusView.translatesAutoresizingMaskIntoConstraints = false
        let sVertFix = NSLayoutConstraint.fix(constraint: .bottom, of: btStatusView, to: .bottom, ofView: self)
        let sWidth = NSLayoutConstraint.fix(constraint: .width, of: btStatusView, toSameOfView: self, offset: 0.0, multiplier: 0.4)
        let sHeight = NSLayoutConstraint(item: btStatusView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: centreOffset)
        let sCentre = NSLayoutConstraint.fix(constraint: .centerX, of: btStatusView, toSameOfView: self)
        
        addConstraints([sWidth,sCentre,sHeight,sVertFix])
        
        // Fix the title to the top middle of this view
        addSubview(titleLabel)
        titleLabel.isAccessibilityElement = false
        titleLabel.isTranslucent = false
        bringSubviewToFront(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let tFix = NSLayoutConstraint.fix(constraint: .top, of: titleLabel, toSameOfView: self)
        let centreFix = NSLayoutConstraint.fix(constraint: .centerX, of: titleLabel, toSameOfView: self)
        let width = NSLayoutConstraint.fix(constraint: .width, of: titleLabel, toSameOfView: deltaView)
        titleLabel.fixedConstraint(of: .height, value: 28.0)
        addConstraints([tFix,width,centreFix])
        
        // Hide by default
        titleLabel.isHidden = false
    }
    
    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        
        levelView.level = bg
        
        guard let level = bg else { return }
        
        
        // -------- Voice over accessibility ----------
        var voiceover: String = ""

        if level.isOld {
            voiceover = "\((timeStampView.date ?? Date()).toString(timeStyle: .short, dateStyle: .short)) "
        } else {
            voiceover = "Latest reading "
        }
        
        voiceover += "\((userLikesMgDl ? level.mgdlValue.unitisedString : level.mmollValue.unitisedString).replacingOccurrences(of: ".", with: " point "))"
        
        if !level.isOld {
            voiceover += " with change of \(deltaView.slope?.string ?? "zero")"
        }
        
        levelView.accessibilityLabel = voiceover
        // ---------------------------------------------
        
        
        btStatusView.colour = levelView.strokeColour
        
        if btStatusView.status != .connected {
            titleLabel.fillColour = .lightGray
            titleLabel.strokeColour = .white
            levelView.level?.timeStamp = Date.distantPast
        } else {
            titleLabel.fillColour = levelView.fillColour
            titleLabel.strokeColour = levelView.strokeColour
        }
        
        if userLikesMgDl {
            titleLabel.attributedText = NSAttributedString(string: Texts_Common.mgdl, attributes: titleAttributes)
        } else {
            titleLabel.attributedText = NSAttributedString(string: Texts_Common.mmol, attributes: titleAttributes)
        }
        
        deltaView.isHidden = level.isOld
        
        timeStampView.isHidden = false
        
        levelView.setNeedsDisplay()
    }
}
