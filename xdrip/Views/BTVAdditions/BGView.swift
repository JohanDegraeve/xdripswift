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
    private var _bg: UniversalBGLevel? = nil
    
    public static let BTChangePost: NSNotification.Name = NSNotification.Name("BTV_BT_Status_Update")
    
    // To help with code legibility
    private var userLikesMgDl: Bool {
        return UserDefaults.standard.bloodGlucoseUnitIsMgDl
    }
    
    /// The text attributes for the title
    private var _titleAttributes: [NSAttributedString.Key : AnyObject] = [
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
    private var _deltaView: BGDeltaView = BGDeltaView()
    
    /// This is the backing box that is a rounded rectangle of the level value
    private var _levelView: BGLevelBox = BGLevelBox()
 
    /// This is the timestamp for the current reading.
    ///
    /// If it shows anything other than 'now' then the delta view is switched off
    private var _timeStampView: BGTimeStampView = BGTimeStampView()
    
    ///This holds a small view to indicate the BT status, connected, scanning, etc.
    private var _btStatusView: BTStatusView = BTStatusView()
    
    /// The `UILabel` that holds the title string
    fileprivate var _titleLabel:BTVRoundRectLabel = BTVRoundRectLabel()

    /// This is the view that covers the whole of this and is used for voiceover
    fileprivate var _accessibilityView: UIView = UIView()
    
    // The views to make up the display
    // -------------------------------------------------------------
    
    // -------------------------------------------------------------
    //MARK: - Methods
    
    /// Main `func` to set the level for display.
    ///
    /// This is called from the `RootController`when not panning and can be out of date if the last reading
    /// was > 1 minute ago.
    public func setValues(for reading: BgReading?, slope: (String, Double)?,btManager BTManager: BluetoothPeripheralManager?) {
        if let _reading = reading {
            _bg = _bg ?? UniversalBGLevel() // make sure that we only create one of these
            _bg!.mgdl = _reading.mgdl
            _bg!.timestamp = _reading.timeStamp
            if _bg!.isOld {
                // It's old.... We set the time stamp so that the user can see the full date.
                _timeStampView.date = _bg!.timestamp
                return
            } else {
                // It's current, setting this view to `nil` will main the current time with no date is displayed.
                _timeStampView.date = nil
            }
        } else {
            _bg = nil
        }
        _btStatusView.btManager = BTManager
        _deltaView.slope = slope
        _levelView.setNeedsDisplay()
    }
    
    /**
     Function to directly set the BG level for display
     
     It's sometimes necessary to be able to set the BG level directly rather than via a `BgReading` var.
     For instance when the user pans around on the chart. The `bg` is set to `nil`, so turning off the arrow indicator.
     
     - Parameter _value: `Double` that is the BG level. **This can be in mmol/L or mg/dL**
     
     Currently this is only called during the panning operation from the `RootController`
     */
    public func directSetBGValue(value: Double, date: Date,btManager BTManager: BluetoothPeripheralManager?) {
        // In this case, setting the timestamp view's date to distant past will make the `BGView` look at this as an out of date level
        _bg = UniversalBGLevel(_timestamp: Date.distantPast, _mgdl: MGDL(value.mmolToMgdl(mgdl: userLikesMgDl)))
        _timeStampView.date = date
        setNeedsDisplay()
            _btStatusView.btManager = BTManager
    }
    
    /// Convenience to set display to "- - -"
    public func setBlank() {
        _bg = nil
        setNeedsDisplay()
    }
    
    /// D.R.Y. to setup all the views and ranges.
    private func _setup() {
        
        /// This is the vertical offset for the delta and BT status views the delta goes this far above centre, the status is this far below
        let _centreOffset: CGFloat = 30.0
        
        /// Sets the width of the delta view and the timestampt views' width
        let _sideViewsWidth: CGFloat = 80.0
        
        backgroundColor = UIColor.clear

        // Set up backing box. This draws the rounded rectangle box around the level
        _levelView.isAccessibilityElement = true
        addSubview(_levelView)
        _levelView.translatesAutoresizingMaskIntoConstraints = false
        
        let _b_left_fix = NSLayoutConstraint.fix(constraint: .left, of: _levelView, to: .left, ofView: self, offset: _sideViewsWidth)
        let _b_right_fix = NSLayoutConstraint.fix(constraint: .right, of: _levelView, to: .right, ofView: self, offset: -_sideViewsWidth)
        let _b_top_fix = NSLayoutConstraint.fix(constraint: .top, of: _levelView, toSameOfView: self)
        let _b_bottom_fix = NSLayoutConstraint.fix(constraint: .bottom, of: _levelView, toSameOfView: self)
        
        addConstraints([_b_top_fix, _b_left_fix, _b_right_fix, _b_bottom_fix])
        sendSubviewToBack(_levelView)
 
        //set up delta view. This is the small 'dial' to the right of the level showing the change rate.
        addSubview(_deltaView)
        _deltaView.isAccessibilityElement = false
        _deltaView.translatesAutoresizingMaskIntoConstraints = false
        
        let _d_right_fix = NSLayoutConstraint.fix(constraint: .right, of: _deltaView, toSameOfView: self)
        let _d_vert_fix = NSLayoutConstraint.fix(constraint: .centerY, of: _deltaView, toSameOfView: self)
        let _d_height = NSLayoutConstraint(item: _deltaView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: _sideViewsWidth)
        let _d_width = NSLayoutConstraint(item: _deltaView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: _sideViewsWidth)
        
        addConstraints([_d_vert_fix, _d_right_fix, _d_height, _d_width])
        
        // Setup the timestamp view. 3 x text labels showing the date of the displayed level.
        addSubview(_timeStampView)
        _timeStampView.translatesAutoresizingMaskIntoConstraints = false
        _timeStampView.isAccessibilityElement = false
        let _t_right_fix = NSLayoutConstraint.fix(constraint: .left, of: _timeStampView, toSameOfView: self)
        let _t_vert_fix = NSLayoutConstraint.fix(constraint: .centerY, of: _timeStampView, toSameOfView: _deltaView)
        let _t_height = NSLayoutConstraint(item: _timeStampView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: _sideViewsWidth)
        let _t_width = NSLayoutConstraint(item: _timeStampView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: _sideViewsWidth)
        
        addConstraints([_t_vert_fix, _t_right_fix, _t_height, _t_width])
        
        _timeStampView.isHidden = true
        
        // Bluetooth Status
        addSubview(_btStatusView)
        _btStatusView.isAccessibilityElement = true
        _btStatusView.translatesAutoresizingMaskIntoConstraints = false
        let _s_vert_fix = NSLayoutConstraint.fix(constraint: .bottom, of: _btStatusView, to: .bottom, ofView: self)
        let _s_width = NSLayoutConstraint.fix(constraint: .width, of: _btStatusView, toSameOfView: self, offset: 0.0, multiplier: 0.4)
        let _s_height = NSLayoutConstraint(item: _btStatusView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: _centreOffset)
        let _s_centre = NSLayoutConstraint.fix(constraint: .centerX, of: _btStatusView, toSameOfView: self)
        
        addConstraints([_s_width, _s_centre, _s_height, _s_vert_fix])
        
        // Fix the title to the top middle of this view
        addSubview(_titleLabel)
        _titleLabel.isAccessibilityElement = false
        _titleLabel.isTranslucent = false
        bringSubviewToFront(_titleLabel)
        _titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let _t_fix = NSLayoutConstraint.fix(constraint: .top, of: _titleLabel, toSameOfView: self)
        let _centre_fix = NSLayoutConstraint.fix(constraint: .centerX, of: _titleLabel, toSameOfView: self)
        let _width = NSLayoutConstraint.fix(constraint: .width, of: _titleLabel, toSameOfView: _deltaView)
        _titleLabel.fixedConstraint(of: .height, value: 28.0)
        addConstraints([_t_fix, _width, _centre_fix])
        
        // Hide by default
        _titleLabel.isHidden = false
        
        NSLayoutConstraint.fixAllSides(of: _accessibilityView, to: self)
    }
    
    override func didMoveToSuperview() {
        _setup()
    }
    
    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        
        _levelView.level = _bg
        
        guard let _level = _bg else { return }
        
        
        // -------- Voice over accessibility ----------
        var _voiceover: String = ""

        if _level.isOld {
            _voiceover = "\((_timeStampView.date ?? Date()).toString(timeStyle: .short, dateStyle: .short)) "
        } else {
            _voiceover = "Latest reading "
        }
        
        _voiceover += "\((userLikesMgDl ? _level.mgdl.unitisedString : _level.mmoll.unitisedString).replacingOccurrences(of: ".", with: " point "))"
        
        if !_level.isOld {
            _voiceover += " with change of \(_deltaView.slope?.string ?? "zero")"
        }
        
        _levelView .accessibilityLabel = _voiceover
        // ---------------------------------------------
        
        
        _btStatusView.colour = _levelView.strokeColour
        
        if _btStatusView.status != .connected {
            _titleLabel.fillColour = .lightGray
            _titleLabel.strokeColour = .white
            _levelView.level?.timestamp = Date.distantPast
        } else {
            _titleLabel.fillColour = _levelView.fillColour
            _titleLabel.strokeColour = _levelView.strokeColour
        }
        
        if userLikesMgDl {
            _titleLabel.attributedText = NSAttributedString(string: Texts_Common.mgdl, attributes: _titleAttributes)
        } else {
            _titleLabel.attributedText = NSAttributedString(string: Texts_Common.mmol, attributes: _titleAttributes)
        }
        
        _deltaView.isHidden = _level.isOld
        
        _timeStampView.isHidden = false
        
        _levelView.setNeedsDisplay()
    }
}
