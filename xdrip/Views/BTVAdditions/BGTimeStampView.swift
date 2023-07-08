//
//  BGTimeStampView.swift
//  xdrip
//
//  Created by Todd Dalton on 20/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import UIKit

/**
 This class takes a `date` of the displayed BG level and splits it into day, date and time of
 sample.
 
 If the `date` iVar is set to `nil` then 'Now' is displayed.
 It's made up of 3 `BTVRoundedRectLabel`s the top one holds the time, the middle is the day
 and the bottom is the date.
 
 When it's displaying the current time then only the top label is visible.
 */
class BGTimeStampView: UIStackView {

    /// These are the rounded, 'pill' views that hold the timestamp.
    private let _dateLabels: [BTVRoundRectLabel] = [BTVRoundRectLabel(), BTVRoundRectLabel(), BTVRoundRectLabel()]
    
    
    /// The text attributes for the date labels
    private var _dateAttributes: [NSAttributedString.Key : AnyObject] = [
        NSAttributedString.Key.font : UIFont.MiniFont,
        NSAttributedString.Key.paragraphStyle : NSParagraphStyle.centredText(),
        NSAttributedString.Key.backgroundColor : UIColor.clear,
        NSAttributedString.Key.foregroundColor : UIColor.white
    ]
    
    var date: Date? = nil {
        didSet {
            
            defer {
                setNeedsDisplay()
            }
            
            guard let _date = date else {
                
                _dateAttributes[NSAttributedString.Key.backgroundColor] = UIColor.clear
                _dateAttributes[NSAttributedString.Key.foregroundColor] = UIColor.black
                
                _dateLabels[1].attributedText = NSAttributedString(string: _timeFormat.string(from: Date()), attributes: _dateAttributes)
                _dateLabels[1].isTranslucent = false
                _dateLabels[1].alpha = 1.0
                
                _dateLabels[0].alpha = 0.0
                
                _dateLabels[2].alpha = 0.0
                
                borderColour = .white
                return
            }
            
            _dateAttributes[NSAttributedString.Key.backgroundColor] = UIColor.clear
            _dateAttributes[NSAttributedString.Key.foregroundColor] = UIColor.white
            
            _dateLabels[0].alpha = 1.0
            _dateLabels[1].alpha = 1.0
            _dateLabels[2].alpha = 1.0
            
            // Top 'pill' with time
            _dateLabels[0].isTranslucent = true
            _dateLabels[0].attributedText =  NSAttributedString(string: _timeFormat.string(from: _date), attributes: _dateAttributes)
            _dateLabels[0].fillColour = _dateAttributes[NSAttributedString.Key.backgroundColor] as! UIColor
            
            // Middle 'pill' with day
            _dateLabels[1].isTranslucent = true
            _dateLabels[1].attributedText = NSAttributedString(string: _dayFormat.string(from: _date), attributes: _dateAttributes)
            _dateLabels[1].fillColour = _dateAttributes[NSAttributedString.Key.backgroundColor] as! UIColor
            
            // Lower 'pill' with date
            _dateLabels[2].isTranslucent = true
            _dateLabels[2].attributedText =  NSAttributedString(string: _dateFormat.string(from: _date), attributes: _dateAttributes)
            _dateLabels[2].fillColour = _dateAttributes[NSAttributedString.Key.backgroundColor] as! UIColor
        }
    }
    
    private var _dateFormat: DateFormatter = DateFormatter()
    private var _timeFormat: DateFormatter = DateFormatter()
    private var _dayFormat: DateFormatter = DateFormatter()
    private let _calendar: Calendar = Calendar.autoupdatingCurrent
    
    var borderColour: UIColor = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var boxColour: UIColor = UIColor.white
    
    override func didMoveToSuperview() {
        
        backgroundColor = UIColor.clear
        
        for i in 0 ..< _dateLabels.count {
            addArrangedSubview(_dateLabels[i])
            _dateLabels[i].translatesAutoresizingMaskIntoConstraints = false
            _dateLabels[i].borderWidth = 1.0
        }
        
        _dateFormat.dateStyle = .short
        _dateFormat.timeStyle = .none
        _dayFormat.dateFormat = "EE"
        
        _timeFormat.dateFormat = .none
        _timeFormat.timeStyle = .short
        
        alignment = .fill
        spacing = 5.0
        axis = .vertical
        distribution = .fillEqually
    }
    
    override func draw(_ rect: CGRect) {
        
        for i in 0 ..< _dateLabels.count {
            _dateLabels[i].strokeColour = borderColour
            _dateLabels[i].fillColour = boxColour
        }
        
        super.draw(rect)
    }
}
