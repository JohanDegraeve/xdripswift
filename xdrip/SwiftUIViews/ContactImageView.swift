import Foundation
import SwiftUI

struct ContactImageView: View {
    
    // public vars that need to be initialized when creating an instance of the view
    var bgValue: Double
    var isMgDl: Bool
    var slopeArrow: String
    var bgRangeDescription: BgRangeDescription
    var valueIsUpToDate: Bool

    var uiImage: UIImage {
        return getImage()
    }
    
    var body: some View {
        Image(uiImage: uiImage)
            .frame(width: 256, height: 256)
    }
    
    var bgColor: UIColor {
        guard bgValue > 0, valueIsUpToDate else { return ConstantsContactImage.unknownColor }
        
        switch bgRangeDescription {
        case .inRange:
            return ConstantsContactImage.inRangeColor
        case .notUrgent:
            return ConstantsContactImage.notUrgentColor
        case .urgent:
            return ConstantsContactImage.urgentColor
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
            switch bgValue.mgdlToMmol() {
            case 0.1..<10.0:
                fontSize = showSlopeArrow ? 100 : 110
            case 10.0..<20.0:
                fontSize = showSlopeArrow ? 80 : 90
            default:
                fontSize = showSlopeArrow ? 80 : 85
            }
        }
        
        return UIFont.systemFont(ofSize: fontSize, weight: .bold)
    }
    
//    var slopeArrowFont: UIFont {
//        var fontSize: CGFloat = 100
//        
//        if isMgDl {
//            switch bgValue {
//            case 1..<100:
//                fontSize = 90
//            case 100..<200:
//                fontSize = 90
//            default:
//                fontSize = 100
//            }
//        } else {
//            switch bgValue.mgdlToMmol() {
//            case 0.1..<10.0:
//                fontSize = 100
//            case 10.0..<20.0:
//                fontSize = 120
//            default:
//                fontSize = 120
//            }
//        }
//        
//        return UIFont.systemFont(ofSize: 80, weight: .bold)
//    }
    
    func getImage() -> UIImage {
        let width = 256.0
        let height = 256.0
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        
        let bgValueString: String = bgValue.mgdlToMmolAndToString(mgdl: isMgDl)
        let showSlopeArrow: Bool = (valueIsUpToDate && slopeArrow != "") ? true : false
                
        UIGraphicsBeginImageContext(rect.size)
        
        let bgValueAttributes: [NSAttributedString.Key : Any] = [
            .font : bgValueFont,
            .foregroundColor: bgColor,
            .tracking : -0.025, // "tight"
        ]
        
        let slopeArrowAttributes: [NSAttributedString.Key : Any] = [
            .font: UIFont.systemFont(ofSize: 80, weight: .bold),
            .foregroundColor: bgColor,
        ]
        
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
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image ?? UIImage()
    }
}

struct ContactImageViewPreview: View {
    var bgValue: Double
    var isMgDl: Bool
    var slopeArrow: String
    var bgRangeDescription: BgRangeDescription
    var valueIsUpToDate: Bool
    
    var body: some View {
        ZStack {
            ContactImageView(bgValue: bgValue, isMgDl: isMgDl, slopeArrow: slopeArrow, bgRangeDescription: bgRangeDescription, valueIsUpToDate: valueIsUpToDate)
            Circle()
                .stroke(lineWidth: 20)
                .foregroundColor(.white)
        }
        .frame(width: 256, height: 256)
        .clipShape(Circle())
        .preferredColorScheme(.dark)
    }
}

struct ContactImageView_Previews: PreviewProvider {
    struct Preview: View {
        var body: some View {
            
            ContactImageViewPreview(bgValue: 88, isMgDl: true, slopeArrow: "", bgRangeDescription: BgRangeDescription.notUrgent, valueIsUpToDate: true).previewDisplayName("88")
            ContactImageViewPreview(bgValue: 88, isMgDl: true, slopeArrow: "\u{2192}" /* → */, bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("88 →")
            ContactImageViewPreview(bgValue: 188, isMgDl: true, slopeArrow: "", bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("188")
            ContactImageViewPreview(bgValue: 188, isMgDl: true, slopeArrow: "\u{2198}" /* ↘ */, bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("188 ↘")
            ContactImageViewPreview(bgValue: 388, isMgDl: true, slopeArrow: "", bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("388")
            ContactImageViewPreview(bgValue: 388, isMgDl: true, slopeArrow: "\u{2191}\u{2191}" /* ↑↑ */, bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("388 ↑↑")
            
            ContactImageViewPreview(bgValue: 160, isMgDl: false, slopeArrow: "",  bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("8.9") /* → */
            ContactImageViewPreview(bgValue: 160, isMgDl: false, slopeArrow: "\u{2198}" /* ↘ */,  bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("8.9 ↘") /* → */
            ContactImageViewPreview(bgValue: 188, isMgDl: false, slopeArrow: "", bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("10.4")
            ContactImageViewPreview(bgValue: 188, isMgDl: false, slopeArrow: "\u{2198}" /* ↘ */, bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("10.4 ↘")
            ContactImageViewPreview(bgValue: 400, isMgDl: false, slopeArrow: "", bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("22.2")
            ContactImageViewPreview(bgValue: 400, isMgDl: false, slopeArrow: "\u{2191}\u{2191}" /* ↑↑ */, bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: true).previewDisplayName("22.2 ↑↑")
            
            ContactImageViewPreview(bgValue: 120, isMgDl: true, slopeArrow: "\u{2191}" /* ↑ */, bgRangeDescription: BgRangeDescription.inRange, valueIsUpToDate: false).previewDisplayName("120, not current")
        }
    }
    static var previews: some View {
        Preview()
    }
}

