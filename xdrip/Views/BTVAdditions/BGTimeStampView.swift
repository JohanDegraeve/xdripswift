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
 
 If the `date` iVar is set to `nil` then 'Now' is displayed
 */
class BGTimeStampView: UIStackView {
    
    var date: Date? = nil {
        didSet {
            
            guard let _date = date else {
                // It's a current BG level so show now indicator
                displayComponents(flag: true)
                _displays[1].isHidden = false
                _displays[1].text = _timeFormat.string(from: Date())
                return
            }
            
            displayComponents(flag: true)
            
            let _dateComps = _calendar.dateComponents(_dateComponents, from: _date)
            
            _displays[0].text = _weekdays[_dateComps.weekday ?? (_weekdays.count - 1)]
            _displays[1].text = _dateFormat.string(from: _date)
            _displays[2].text = _timeFormat.string(from: _date)
        }
    }
    
    /// This set will hold the components of the `date`
    private var _dateComponents: Set<Calendar.Component> = Set()
    
    /// The current calendar so we don't have to keep setting up drawing re-draw
    private let _calendar = Calendar.current
    
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
    private var _displays: [UILabel] = Array(repeating: UILabel(), count: 3)
    
    /// This is the image that's displayed when the BG level is current
    private var _nowIndicator: UIImage = UIImage(named: "BGNowIndicator")!.withRenderingMode(.automatic)
    
    var colour: UIColor = UIColor.white

    /// D.R.Y. to hide and show all the views
    private func displayComponents(flag: Bool) {
        _displays[0].isHidden = !flag
        _displays[1].isHidden = !flag
        _displays[2].isHidden = !flag
    }
    
    override func didMoveToSuperview() {
        _timeFormat.dateStyle = .none
        _timeFormat.timeStyle = .short
        
        _dateFormat.dateStyle = .short
        _dateFormat.timeStyle = .none
        
        _weekdays.append("???")
        
        axis = .vertical
        
        for i in 0 ..< _displays.count {
            addArrangedSubview(_displays[i])
            _displays[i].translatesAutoresizingMaskIntoConstraints = false
            let _left = NSLayoutConstraint.fix(constraint: .left, of: _displays[i], toSameOfView: self)
            let _right = NSLayoutConstraint.fix(constraint: .right, of: _displays[i], toSameOfView: self)
            backgroundColor = .blue
        }
        
        alignment = .center
        spacing = 5.0
        distribution = .equalSpacing
        
        let _digitsAttributes: [NSAttributedString.Key : AnyObject] = [
            NSAttributedString.Key.font : UIFont.SmallFont,
            NSAttributedString.Key.paragraphStyle : NSParagraphStyle.centredText(),
            NSAttributedString.Key.foregroundColor : UIColor.white
        ]
        
        _displays[0].attributedText = NSAttributedString(string: "", attributes: _digitsAttributes)
        _displays[1].attributedText = NSAttributedString(string: "", attributes: _digitsAttributes)
        _displays[2].attributedText = NSAttributedString(string: "", attributes: _digitsAttributes)
        
        date = nil
        backgroundColor = .clear
    }

}
