import Foundation
import SwiftUI

struct NumberImageView: View {
    @Binding var value: String?
    @Binding var slopeArrow: String?
    @Binding var range: BgRangeDescription?
    @Binding var valueIsUpToDate: Bool?
    @Binding var rangeIndicator: Bool
    @Binding var darkMode: Bool
    @Binding var fontSize: Int
    @Binding var fontWeight: UIFont.Weight
    @Binding var fontName: String?
        
    static let normalColorDark = Color(red: 17 / 256, green: 156 / 256, blue: 12 / 256)
    static let normalColorLight = Color(red: 17 / 256, green: 156 / 256, blue: 12 / 256)
    
    static let notUrgentColorDark = Color(red: 254 / 256, green: 149 / 256, blue: 4 / 256)
    static let notUrgentColorLight = Color(red: 254 / 256, green: 149 / 256, blue: 4 / 256)
    
    static let urgentColorDark = Color(red: 255 / 256, green: 52 / 256, blue: 0 / 256)
    static let urgentColorLight = Color(red: 255 / 256, green: 52 / 256, blue: 0 / 256)
    
    static let unknownColorDark = Color(red: 0x88 / 256, green: 0x88 / 256, blue: 0x88 / 256)
    static let unknownColorLight = Color(red: 0x88 / 256, green: 0x88 / 256, blue: 0x88 / 256)
    
    static func getColor(value: String, range: BgRangeDescription, valueIsUpToDate: Bool?, darkMode: Bool) -> Color {
        if let valueIsUpToDate, valueIsUpToDate {
            return switch range {
            case .inRange:
                darkMode ? Self.normalColorDark : Self.normalColorLight
            case .notUrgent:
                darkMode ? Self.notUrgentColorDark : Self.notUrgentColorLight
            case .urgent:
                darkMode ? Self.urgentColorDark : Self.urgentColorLight
            }
        } else {
            return darkMode ? Self.unknownColorDark : Self.unknownColorLight
        }

    }
    
    static func getImage(value: String?, range: BgRangeDescription?, slopeArrow: String?, valueIsUpToDate: Bool?, rangeIndicator: Bool, darkMode: Bool, fontSize: Int, fontWeight: UIFont.Weight, fontName: String?) -> UIImage {
        let width = 256.0
        let height = 256.0
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let color: Color
        let string: String?
                
        if value != nil && range != nil {
            color = getColor(value: value!, range: range!, valueIsUpToDate: valueIsUpToDate, darkMode: darkMode)
            string = value
        } else {
            color = darkMode ? Self.unknownColorDark : Self.unknownColorLight
            string = "—"
        }
        let textColor: Color = darkMode ?
            Color(red: 250 / 256, green: 2500 / 256, blue: 250 / 256) :
            Color(red: 20 / 256, green: 20 / 256, blue: 20 / 256)
                
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        
        let indicator = CGRect(x: (width - width*0.35)/2, y: height*0.15, width: width*0.35, height: height*0.10)
        
        if rangeIndicator {
            context?.setFillColor(color.cgColor!)
            let cornerRadius: CGFloat = 10.0
            
            if let context = UIGraphicsGetCurrentContext() {
                context.beginPath()
                context.move(to: CGPoint(x: indicator.minX + cornerRadius, y: indicator.minY))
                context.addArc(tangent1End: CGPoint(x: indicator.maxX, y: indicator.minY), tangent2End: CGPoint(x: indicator.maxX, y: indicator.maxY), radius: cornerRadius)
                context.addArc(tangent1End: CGPoint(x: indicator.maxX, y: indicator.maxY), tangent2End: CGPoint(x: indicator.minX, y: indicator.maxY), radius: cornerRadius)
                context.addArc(tangent1End: CGPoint(x: indicator.minX, y: indicator.maxY), tangent2End: CGPoint(x: indicator.minX, y: indicator.minY), radius: cornerRadius)
                context.addArc(tangent1End: CGPoint(x: indicator.minX, y: indicator.minY), tangent2End: CGPoint(x: indicator.maxX, y: indicator.minY), radius: cornerRadius)
                context.closePath()
                
                context.fillPath()
            }
        }
                
        var theFontSize = fontSize
        var font: UIFont
        
        if fontName != nil {
            font = UIFont(name: fontName!, size: CGFloat(fontSize)) ?? UIFont.systemFont(ofSize: CGFloat(fontSize), weight: fontWeight)
        } else {
            font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: fontWeight)
        }
        
        
        
        var attributes: [NSAttributedString.Key : Any] = [
            .font : font,
            .foregroundColor : UIColor(textColor),
            .tracking : -fontSize / 17,
        ]
        let slopeAttributes: [NSAttributedString.Key : Any] = [
            NSAttributedString.Key.font : UIFont.systemFont(ofSize: 80, weight: .regular),
            NSAttributedString.Key.foregroundColor : UIColor(textColor)
        ]
        
        
        if let string {
            var stringSize = string.size(withAttributes: attributes)
            while stringSize.width > width*0.9 {
                theFontSize = theFontSize - 10
                attributes = [
                    .font : font,
                    .foregroundColor : UIColor(textColor),
                    .tracking : -fontSize / 17,
                ]
                stringSize = string.size(withAttributes: attributes)
            }
            
            string.draw(
                in: CGRectMake(
                    (width - stringSize.width) / 2,
                    (height - stringSize.height) / 2,
                    stringSize.width,
                    stringSize.height
                ),
                withAttributes: attributes
            )
            if let slopeArrow {
                let slopeArrowSize = slopeArrow.size(withAttributes: slopeAttributes)
                slopeArrow.draw(
                    in: CGRectMake(
                        (width - slopeArrowSize.width) / 2,
                        height - slopeArrowSize.height * 1.05,
                        slopeArrowSize.width,
                        slopeArrowSize.height
                    ),
                    withAttributes: slopeAttributes
                )
            }
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    var uiImage: UIImage {
        return NumberImageView.getImage(value: value, range: range, slopeArrow: slopeArrow, valueIsUpToDate: valueIsUpToDate, rangeIndicator: rangeIndicator, darkMode: darkMode, fontSize: fontSize, fontWeight: fontWeight, fontName: fontName)
    }
    
    var body: some View {
        Image(uiImage: uiImage)
            .frame(width: 256, height: 256)
    }
}

struct NumberImageViewPreview: View {
    @Binding var value: String?
    @Binding var slopeArrow: String?
    @Binding var range: BgRangeDescription?
    @Binding var valueIsUpToDate: Bool?
    @Binding var rangeIndicator: Bool
    @Binding var darkMode: Bool
    @Binding var fontSize: Int
    @Binding var fontWeight: UIFont.Weight
    @Binding var fontName: String?
    
    var body: some View {
        ZStack {
            NumberImageView(value: $value, slopeArrow: $slopeArrow, range: $range, valueIsUpToDate: $valueIsUpToDate, rangeIndicator: $rangeIndicator, darkMode: $darkMode, fontSize: $fontSize, fontWeight: $fontWeight, fontName: $fontName)
            Circle()
                .stroke(lineWidth: 20)
                .foregroundColor(.white)
        }
        .frame(width: 256, height: 256)
        .clipShape(Circle())
        .preferredColorScheme($darkMode.wrappedValue ? .dark : .light)
    }
}

struct NumberImageView_Previews: PreviewProvider {
    struct Preview: View {
        @State var rangeIndicator: Bool = true
        @State var darkMode: Bool = true
        @State var fontSize: Int = 130
        @State var fontWeight: UIFont.Weight = .bold
        @State var fontName: String? = "AmericanTypewriter"
        
        var body: some View {
            NumberImageViewPreview(value: .constant("40"), slopeArrow: .constant(nil), range: .constant(BgRangeDescription.urgent),  valueIsUpToDate: .constant(true), rangeIndicator: $rangeIndicator, darkMode: $darkMode, fontSize: $fontSize, fontWeight: $fontWeight, fontName: $fontName).previewDisplayName("40")
            NumberImageViewPreview(value: .constant("63"), slopeArrow: .constant(nil), range: .constant(BgRangeDescription.notUrgent), valueIsUpToDate: .constant(true), rangeIndicator: $rangeIndicator, darkMode: $darkMode, fontSize: $fontSize, fontWeight: $fontWeight, fontName: $fontName).previewDisplayName("63")
            NumberImageViewPreview(value: .constant("69"), slopeArrow: .constant("\u{2192}" /* → */), range: .constant(BgRangeDescription.inRange), valueIsUpToDate: .constant(true), rangeIndicator: $rangeIndicator, darkMode: $darkMode, fontSize: $fontSize, fontWeight: $fontWeight, fontName: $fontName).previewDisplayName("69 →")
            NumberImageViewPreview(value: .constant("79"), slopeArrow: .constant(nil), range: .constant(BgRangeDescription.inRange), valueIsUpToDate: .constant(true), rangeIndicator: $rangeIndicator, darkMode: $darkMode, fontSize: $fontSize, fontWeight: $fontWeight, fontName: $fontName).previewDisplayName("79")
            NumberImageViewPreview(value: .constant("11.3"), slopeArrow: .constant("\u{2198}" /* ↘ */), range: .constant(BgRangeDescription.notUrgent), valueIsUpToDate: .constant(true), rangeIndicator: $rangeIndicator, darkMode: $darkMode, fontSize: $fontSize, fontWeight: $fontWeight, fontName: $fontName).previewDisplayName("11.3 ↘")
            NumberImageViewPreview(value: .constant("166"), slopeArrow: .constant("\u{2191}" /* ↑ */), range: .constant(BgRangeDescription.notUrgent), valueIsUpToDate: .constant(true), rangeIndicator: $rangeIndicator, darkMode: $darkMode, fontSize: $fontSize, fontWeight: $fontWeight, fontName: $fontName).previewDisplayName("166 ↑")
            NumberImageViewPreview(value: .constant("260"), slopeArrow: .constant(nil), range: .constant(BgRangeDescription.urgent), valueIsUpToDate: .constant(true), rangeIndicator: $rangeIndicator, darkMode: $darkMode, fontSize: $fontSize, fontWeight: $fontWeight, fontName: $fontName).previewDisplayName("260")
            NumberImageViewPreview(value: .constant(nil), slopeArrow: .constant(nil), range: .constant(nil), valueIsUpToDate: .constant(true), rangeIndicator: $rangeIndicator, darkMode: $darkMode, fontSize: $fontSize, fontWeight: $fontWeight, fontName: $fontName).previewDisplayName("Unknown")
            NumberImageViewPreview(value: .constant("120"), slopeArrow: .constant(nil), range: .constant(BgRangeDescription.notUrgent), valueIsUpToDate: .constant(false), rangeIndicator: $rangeIndicator, darkMode: $darkMode, fontSize: $fontSize, fontWeight: $fontWeight, fontName: $fontName).previewDisplayName("120,no real-time")
        }
    }
    static var previews: some View {
        Preview()
    }
}

