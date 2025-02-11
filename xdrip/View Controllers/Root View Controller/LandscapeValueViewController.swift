//
//  LandscapeValueViewController.swift
//  xdrip
//
//  Created by Johan Degraeve on 24/12/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import UIKit

class LandscapeValueViewController: UIViewController {

    // MARK: - Properties - Outlets for labels

    /// the main stackview, defined here to allow programmatic layout
    @IBOutlet weak var allViewsStackView: UIStackView!
    
    /// stackview that has the minutes and diff labels,  defined here to allow programmatic layout
    @IBOutlet weak var minutesAndDiffLabelStackView: UIStackView!
    
    /// stackview with just the minutes and minutes ago  labels,  defined here to allow programmatic layout
    @IBOutlet weak var minutesLabelStackView: UIStackView!
    
    /// outlet for label that shows how many minutes ago and so on
    @IBOutlet weak var minutesLabelOutlet: UILabel!
    /// outlet for label that shows the text "minuges ago.."
    @IBOutlet weak var minutesAgoLabelOutlet: UILabel!
    
    /// outlet for label that shows difference with previous reading
    @IBOutlet weak var diffLabelOutlet: UILabel!
    /// outlet for label that shows unit
    @IBOutlet weak var diffLabelUnitOutlet: UILabel!
    
    /// outlet for label that shows the current reading
    @IBOutlet weak var valueLabelOutlet: UILabel!
    

    // MARK: - overriden functions
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // set height of stackview with the minutes and diff labels to 20% of toal screen height, the remaining 80% is used to show the value and trend
        //   and width of stackview with just the minutes, 60% of total width?
        minutesAndDiffLabelStackView.translatesAutoresizingMaskIntoConstraints = false
        minutesAndDiffLabelStackView.heightAnchor.constraint(equalTo: allViewsStackView.heightAnchor, multiplier: 0.2).isActive = true
        minutesLabelStackView.widthAnchor.constraint(equalTo: minutesAndDiffLabelStackView.widthAnchor, multiplier: 0.6).isActive = true
        
    }
    
    override func viewDidLayoutSubviews() {
        
        super.viewDidLayoutSubviews()

        // adjust font of first label, maximize to fit the height of the label
        LandscapeValueViewController.adjustFontSizeToFitHeight(for: minutesLabelOutlet)
        
        // give the other labels in the top stackview the same height
        minutesAgoLabelOutlet.font = minutesLabelOutlet.font
        diffLabelOutlet.font = minutesLabelOutlet.font
        diffLabelUnitOutlet.font = minutesLabelOutlet.font
        
        // adjust also font size for value label
        LandscapeValueViewController.adjustFontSizeToFitHeight(for: valueLabelOutlet)
        
    }

    
    // MARK: - public functions
    
    /// updates the labels colors and texts
    public func updateLabels(minutesLabelTextColor:UIColor, minutesLabelText: String?, minuteslabelAgoTextColor: UIColor, minutesLabelAgoText: String?, diffLabelTextColor: UIColor, diffLabelText: String?, diffLabelUnitTextColor: UIColor, diffLabelUnitText: String?, valueLabelTextColor: UIColor, valueLabelText: String?, valueLabelAttributedText: NSAttributedString?) {
        
        minutesLabelOutlet.textColor = minutesLabelTextColor
        minutesLabelOutlet.text = minutesLabelText
        minutesAgoLabelOutlet.textColor = minuteslabelAgoTextColor
        minutesAgoLabelOutlet.text = " " + (minutesLabelAgoText ?? "")
        diffLabelOutlet.textColor = diffLabelTextColor
        diffLabelOutlet.text = diffLabelText
        diffLabelUnitOutlet.textColor = diffLabelUnitTextColor
        diffLabelUnitOutlet.text = " " + (diffLabelUnitText ?? "")
        valueLabelOutlet.textColor = valueLabelTextColor
        valueLabelOutlet.text = valueLabelText
        valueLabelOutlet.attributedText = valueLabelAttributedText
        
        // adjust size for value label, because the length of the text may have changed, eg when going from a value below 100 mg/dl to a value above 100 mg/dl
        LandscapeValueViewController.adjustFontSizeToFitHeight(for: valueLabelOutlet)
        
    }

    // MARK: - private functions
    
    /// increases the fontsize make sure it still fits in the label height
    private static func adjustFontSizeToFitHeight(for label: UILabel) {
        guard let text = label.text, !text.isEmpty else { return }

        let maxFontSize: CGFloat = 500  // Maximum font size to try
        let minFontSize: CGFloat = 5    // Minimum font size for readability
        let labelSize = label.frame.size

        for fontSize in stride(from: maxFontSize, through: minFontSize, by: -1) {
            // Create a font with the current size
            let font = UIFont.systemFont(ofSize: fontSize)
            
            // Calculate the bounding box for the text with this font
            let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
            let boundingBox = (text as NSString).boundingRect(
                with: CGSize(width: labelSize.width, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: textAttributes,
                context: nil
            )

            // Check if the bounding box fits within the label's dimensions
            if boundingBox.height <= labelSize.height && boundingBox.width <= labelSize.width {
                label.font = font  // Set the font
                break
            }
        }
    }

}
