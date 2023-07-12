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
    private let dateLabels: [RoundRectLabelView] = [RoundRectLabelView(), RoundRectLabelView(), RoundRectLabelView()]
    
    
    /// The text attributes for the date labels
    private var dateAttributes: [NSAttributedString.Key : AnyObject] = [
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
            
            guard let date = date else {
                
                dateAttributes[NSAttributedString.Key.backgroundColor] = UIColor.clear
                dateAttributes[NSAttributedString.Key.foregroundColor] = UIColor.black
                
                dateLabels[1].attributedText = NSAttributedString(string: timeFormat.string(from: Date()), attributes: dateAttributes)
                dateLabels[1].isTranslucent = false
                dateLabels[1].alpha = 1.0
                
                dateLabels[0].alpha = 0.0
                
                dateLabels[2].alpha = 0.0
                
                borderColour = .white
                return
            }
            
            dateAttributes[NSAttributedString.Key.backgroundColor] = UIColor.clear
            dateAttributes[NSAttributedString.Key.foregroundColor] = UIColor.white
            
            dateLabels[0].alpha = 1.0
            dateLabels[1].alpha = 1.0
            dateLabels[2].alpha = 1.0
            
            // Top 'pill' with time
            dateLabels[0].isTranslucent = true
            dateLabels[0].attributedText =  NSAttributedString(string: timeFormat.string(from: date), attributes: dateAttributes)
            dateLabels[0].fillColour = dateAttributes[NSAttributedString.Key.backgroundColor] as! UIColor
            
            // Middle 'pill' with day
            dateLabels[1].isTranslucent = true
            dateLabels[1].attributedText = NSAttributedString(string: dayFormat.string(from: date), attributes: dateAttributes)
            dateLabels[1].fillColour = dateAttributes[NSAttributedString.Key.backgroundColor] as! UIColor
            
            // Lower 'pill' with date
            dateLabels[2].isTranslucent = true
            dateLabels[2].attributedText =  NSAttributedString(string: dateFormat.string(from: date), attributes: dateAttributes)
            dateLabels[2].fillColour = dateAttributes[NSAttributedString.Key.backgroundColor] as! UIColor
        }
    }
    
    private var dateFormat: DateFormatter = DateFormatter()
    private var timeFormat: DateFormatter = DateFormatter()
    private var dayFormat: DateFormatter = DateFormatter()
    
    var borderColour: UIColor = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var boxColour: UIColor = UIColor.white
    
    override func didMoveToSuperview() {
        
        backgroundColor = UIColor.clear
        
        for i in 0 ..< dateLabels.count {
            addArrangedSubview(dateLabels[i])
            dateLabels[i].translatesAutoresizingMaskIntoConstraints = false
            dateLabels[i].borderWidth = 1.0
        }
        
        dateFormat.dateStyle = .short
        dateFormat.timeStyle = .none
        dayFormat.dateFormat = "EE"
        
        timeFormat.dateFormat = .none
        timeFormat.timeStyle = .short
        
        alignment = .fill
        spacing = 5.0
        axis = .vertical
        distribution = .fillEqually
    }
    
    override func draw(_ rect: CGRect) {
        
        for i in 0 ..< dateLabels.count {
            dateLabels[i].strokeColour = borderColour
            dateLabels[i].fillColour = boxColour
        }
        
        super.draw(rect)
    }
}
