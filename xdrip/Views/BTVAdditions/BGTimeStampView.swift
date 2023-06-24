//
//  BGTimeStampView.swift
//  xdrip
//
//  Created by Todd Dalton on 20/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import UIKit

class BTVRoundRectLabel: BTVRoundedBackingView {
    
    fileprivate var _label: UILabel = UILabel()
    
    var text: String = "" {
        didSet {
            _label.text = text
        }
    }
    
    var attributedText: NSAttributedString  = NSAttributedString() {
        didSet {
            _label.attributedText = attributedText
        }
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        addSubview(_label)
        bringSubviewToFront(_label)
        NSLayoutConstraint.fixAllSides(of: _label, to: self)
    }
}

/**
 This class takes a `date` of the displayed BG level and splits it into day, date and time of
 sample.
 
 If the `date` iVar is set to `nil` then 'Now' is displayed
 */
class BGTimeStampView: UIStackView {
    
    var date: Date? = nil {
        didSet {
            
            guard let _date = date else {
                // It's a current BG level so show now indicator
                displayComponents(flag: false)
                _displays[1].alpha = 1.0
                _displays[1].attributedText = NSAttributedString(string: _timeFormat.string(from: Date()), attributes: _digitsAttributes)
                return
            }
            
            displayComponents(flag: true)
            
            let _dateComps = _calendar.dateComponents([.weekday], from: _date)
            _displays[0].attributedText = NSAttributedString(string: _weekdays[(_dateComps.weekday ?? _weekdays.count) - 1], attributes: _digitsAttributes)
            _displays[1].attributedText = NSAttributedString(string: _dateFormat.string(from: _date), attributes: _digitsAttributes)
            _displays[2].attributedText = NSAttributedString(string: _timeFormat.string(from: _date), attributes: _digitsAttributes)
        }
    }
    
    /// This set will hold the components of the `date`
    private var _dateComponents: Set<Calendar.Component> = Set()
    
    /// The current calendar so we don't have to keep setting up drawing re-draw
    ///
    /// According to
    /// https://stackoverflow.com/a/39842835/19730436
    /// The days can sometimes not match betweem a `Date` result and a `Calendar.components` one.
    /// This creates a whole new calendar (as recommended in one of the comments to the SO answer).
    /// The timezone is set when the view loads and is "UTC".
    private var _calendar = Calendar(identifier: .gregorian)
    
    /// Formatter for the date of the sample
    private var _dateFormat = DateFormatter()
    
    /// Store the short, localised weekday symbols
    ///
    /// In order to allow for a problem getting the weekday from the `date` components, the last element is an error
    /// message and the above `didSet` code will default to it
    private var _weekdays: [String] = Calendar.current.shortWeekdaySymbols
    
    /// Formatter for the time of the sample
    private var _timeFormat = DateFormatter()
    
    /// This array will hold the day, date and time of the `time`
    ///
    /// If the `date` is `nil` then they will all be hidden and the indicator shown
    private var _displays: [BTVRoundRectLabel] = [BTVRoundRectLabel(), BTVRoundRectLabel(), BTVRoundRectLabel()]
    
    /// This is the image that's displayed when the BG level is current
    private var _nowIndicator: UIImage = UIImage(named: "BGNowIndicator")!.withRenderingMode(.automatic)
    
    private var _digitsAttributes: [NSAttributedString.Key : AnyObject] = [
        NSAttributedString.Key.font : UIFont.MiniFont,
        NSAttributedString.Key.paragraphStyle : NSParagraphStyle.centredText(),
        NSAttributedString.Key.foregroundColor : UIColor.black
    ]
    
    var textColour: UIColor = UIColor.white {
        didSet {
            _digitsAttributes[NSAttributedString.Key.foregroundColor] = textColour
        }
    }

    /// D.R.Y. to hide and show all the views
    private func displayComponents(flag: Bool) {
        _displays[0].alpha = flag.rawCGFloatValue
        _displays[1].alpha = flag.rawCGFloatValue
        _displays[2].alpha = flag.rawCGFloatValue
    }
    
    /// Set the border and translucent fill colours to the same
    func setBorderAndFill(to colour:UIColor) {
        _displays[0].fillColour = colour
        _displays[0].strokeColour = colour
        
        _displays[1].fillColour = colour
        _displays[1].strokeColour = colour
        
        _displays[2].fillColour = colour
        _displays[2].strokeColour = colour
    }
    
    /// Pass translucense flag to the backing subviews
    func isTranslucent(flag: Bool) {
        _displays[0].isTranslucent = flag
        _displays[1].isTranslucent = flag
        _displays[2].isTranslucent = flag
    }
    
    override func didMoveToSuperview() {
        _timeFormat.dateStyle = .none
        _timeFormat.timeStyle = .short
        
        _dateFormat.dateStyle = .short
        _dateFormat.timeStyle = .none
        
        _calendar.timeZone = TimeZone(abbreviation: "UTC")!
        
        _weekdays.append("???")
        
        axis = .vertical
        
        for i in 0 ..< _displays.count {
            addArrangedSubview(_displays[i])
            _displays[i].isTranslucent = true
            _displays[i].translatesAutoresizingMaskIntoConstraints = false
            _displays[i].attributedText = NSAttributedString(string: "", attributes: _digitsAttributes)
            _displays[i].borderWidth = 1.0
            _displays[i].fillColour = UIColor(red: 0.392, green: 0.827, blue: 0.933, alpha: 1.00)
            _displays[i].strokeColour = UIColor(red: 0.392, green: 0.827, blue: 0.933, alpha: 1.00)
        }
        
        alignment = .fill
        distribution = .fillEqually
        
        backgroundColor = .clear
    }
}
