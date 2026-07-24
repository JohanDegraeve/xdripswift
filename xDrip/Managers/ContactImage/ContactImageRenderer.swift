//
//  ContactImageRenderer.swift
//  xdrip
//
//  Created by Paul Plant on 13/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct ContactImageRenderer: View {
    
    // public vars that need to be initialized when creating an instance of the view
    var bgValue: Double
    var isMgDl: Bool
    var slopeArrow: String
    var bgRangeDescription: BgRangeDescription
    var valueIsUpToDate: Bool
    var useHighContrastContactImage: Bool
    var disableContactImage: Bool

    private var bgColor: Color {
        if disableContactImage {
            return useHighContrastContactImage ? .white : .cyan
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
    
    private var bgValueFontSize: CGFloat {
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
        
        return fontSize
    }

    private var content: (value: String, showsSlopeArrow: Bool) {
        // if there is no current value, 0 will be received so show this as a relevant "---" string
        var bgValueString: String = bgValue > 0 ? bgValue.mgDlToMmolAndToString(mgDl: isMgDl) : isMgDl ? "---" : "-.-"
        var showSlopeArrow: Bool = (valueIsUpToDate && slopeArrow != "") ? true : false

        // override the value and slope if the user is in follower mode and has disabled the keep-alive (to prevent showing an almost always out of date value)
        if disableContactImage {
            bgValueString = "OFF"
            showSlopeArrow = false
        }

        return (bgValueString, showSlopeArrow)
    }

    var body: some View {
        let content = content

        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

            guard !content.value.isEmpty else { return }

            let value = context.resolve(
                Text(content.value)
                    .font(.system(size: bgValueFontSize, weight: .bold))
                    .foregroundColor(bgColor)
                    .tracking(-0.025)
            )
            let valueSize = value.measure(in: size)
            let valueOriginY = (size.height - valueSize.height) / (content.showsSlopeArrow ? 2 + ConstantsContactImage.bgValueVerticalOffsetIfSlopeArrow : 2)

            context.draw(
                value,
                at: CGPoint(x: size.width / 2, y: valueOriginY + valueSize.height / 2),
                anchor: .center
            )

            if content.showsSlopeArrow {
                let arrow = context.resolve(
                    Text(slopeArrow)
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(bgColor)
                )
                let arrowSize = arrow.measure(in: size)
                let arrowOriginY = (size.height - arrowSize.height) / (2 + ConstantsContactImage.slopeArrowVerticalOffset)

                context.draw(
                    arrow,
                    at: CGPoint(x: size.width / 2, y: arrowOriginY + arrowSize.height / 2),
                    anchor: .center
                )
            }
        }
        .frame(width: 256, height: 256)
    }

    /// Renders the contact image directly to PNG data without creating a UIKit image.
    @MainActor
    func pngData() -> Data? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 1

        guard let cgImage = renderer.cgImage else { return nil }

        let imageData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(imageData, UTType.png.identifier as CFString, 1, nil) else { return nil }

        CGImageDestinationAddImage(destination, cgImage, nil)

        guard CGImageDestinationFinalize(destination) else { return nil }

        return imageData as Data
    }
}
