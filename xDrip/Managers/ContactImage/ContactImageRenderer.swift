//
//  ContactImageRenderer.swift
//  xdrip
//
//  Created by Paul Plant on 13/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit

struct ContactImageRenderer {
    
    // public vars that need to be initialized when creating an instance of the view
    var bgValue: Double
    var isMgDl: Bool
    var slopeArrow: String
    var bgRangeDescription: BgRangeDescription
    var valueIsUpToDate: Bool
    var useHighContrastContactImage: Bool
    var disableContactImage: Bool

    var uiImage: UIImage {
        return getImage()
    }
    
    var bgColor: UIColor {
        if disableContactImage {
            return useHighContrastContactImage ? .white : .systemCyan
        }
        
        guard bgValue > 0, valueIsUpToDate else { return ConstantsContactImage.unknownColor }
        
        // if the user isn't requesting a high contrast image, then return the correct bg color
        if !useHighContrastContactImage {
            switch bgRangeDescription {
            case .inRange:
                return ConstantsContactImage.inRangeColor
            case .notUrgent:
                return ConstantsContactImage.notUrgentColor
            case .urgent:
                return ConstantsContactImage.urgentColor
            }
        } else {
            // return white as this will render nicely on watchfaces
            // with a color tint applied
            return .white
        }
    }
    
    var bgValueFont: UIFont {
        var fontSize: CGFloat = 100
        let showSlopeArrow: Bool = (valueIsUpToDate && slopeArrow != "") ? true : false
        
        if isMgDl {
            switch bgValue {
            case 1..<100:
                fontSize = showSlopeArrow ? 120 : 130
            case 100..<200:
                fontSize = showSlopeArrow ? 95 : 105
            default:
                fontSize = showSlopeArrow ? 90 : 100
            }
        } else {
            switch bgValue.mgDlToMmol() {
            case 0.1..<10.0:
                fontSize = showSlopeArrow ? 100 : 110
            case 10.0..<20.0:
                fontSize = showSlopeArrow ? 80 : 90
            default:
                fontSize = showSlopeArrow ? 80 : 85
            }
        }
        
        if disableContactImage {
            fontSize = 100
        }
        
        return UIFont.systemFont(ofSize: fontSize, weight: .bold)
    }

    var imageBackgroundColor: UIColor {
        .black
    }
    
    func getImage() -> UIImage {
        let width = 256.0
        let height = 256.0
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        
        // if there is no current value, 0 will be received so show this as a relevant "---" string
        var bgValueString: String = bgValue > 0 ? bgValue.mgDlToMmolAndToString(mgDl: isMgDl) : isMgDl ? "---" : "-.-"
        
        var showSlopeArrow: Bool = (valueIsUpToDate && slopeArrow != "") ? true : false
        
        // override the value and slope if the user is in follower mode and has disabled the keep-alive (to prevent showing an almost always out of date value)
        if disableContactImage {
            bgValueString = "OFF"
            showSlopeArrow = false
        }
        
        let bgValueAttributes: [NSAttributedString.Key : Any] = [
            .font : bgValueFont,
            .foregroundColor: bgColor,
            .tracking : -0.025, // "tight"
        ]
        
        let slopeArrowAttributes: [NSAttributedString.Key : Any] = [
            .font: UIFont.systemFont(ofSize: 80, weight: .bold),
            .foregroundColor: bgColor,
        ]

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)

        return renderer.image { _ in
            imageBackgroundColor.setFill()
            UIRectFill(rect)

            if bgValueString != "" {
                var size = bgValueString.size(withAttributes: bgValueAttributes)

                bgValueString.draw(
                    in: CGRectMake(
                        (width - size.width) / 2,
                        (height - size.height) / (showSlopeArrow ? 2 + ConstantsContactImage.bgValueVerticalOffsetIfSlopeArrow : 2),
                        size.width,
                        size.height
                    ),
                    withAttributes: bgValueAttributes
                )

                if showSlopeArrow {
                    size = slopeArrow.size(withAttributes: slopeArrowAttributes)

                    slopeArrow.draw(
                        in: CGRectMake(
                            (width - size.width) / 2,
                            (height - size.height) / (2 + ConstantsContactImage.slopeArrowVerticalOffset),
                            size.width,
                            size.height
                        ),
                        withAttributes: slopeArrowAttributes
                    )
                }
            }
        }
    }
}
