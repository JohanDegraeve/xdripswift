//
//  BGBaseViews.swift
//  xdrip
//
//  Created by Todd Dalton on 27/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit

//MARK: -

/**
 Custom `UIImageView` to properly resize an image within a `UIStackView`
 
 The pain with `UIImageView` is that it won't resize when inside a `UIStackView`.
 https://stackoverflow.com/a/33372740/372347
 
 */
class FixedSizeImageView: UIImageView {
    
    // Private iVar to hold the required size. This is returned with the overridden intrinsicContentSize
    private var constrainedSize: CGSize = CGSize(width: 100.0, height: 100.0)
    
    override func didMoveToSuperview() {
        guard let image = image else { return }
        constrainedSize = image.size
    }
    
    /// Set the intrisic width and height of the image
    public func setIntrinsicSize(to size: CGSize) {
        constrainedSize = size
        self.invalidateIntrinsicContentSize()
    }
    
    /// Sets the height (and then - from the aspect ratio - the width of an image).
    public func setIntrinsicHeight(to height: CGFloat) {
        guard height > 0.0 else { return }
        let originalImage = image?.size ?? CGSize(width: 100, height: 100) // Arbitary default value
        let aspect = originalImage.width / originalImage.height
        let newWidth = height * aspect
        setIntrinsicSize(to: CGSize(width: newWidth, height: height))
    }
    
    /// Sets the width (and then - from the aspect ratio - the height of an image).
    public func setIntrinsicWidth(to width: CGFloat) {
        guard width > 0.0 else { return }
        let originalImage = image?.size ?? CGSize(width: 100, height: 100) // Arbitary default value
        let aspect = originalImage.width / originalImage.height
        let newHeight = width / aspect
        setIntrinsicSize(to: CGSize(width: width, height: newHeight))
    }
    
    /// Overridden to supply the required `CGSize`
    override var intrinsicContentSize: CGSize {
        return constrainedSize
    }
}

/**
 This subclass adds a `UILabel` on top of the `BTVRoundedBackingView`
 */
class RoundRectLabelView: RoundedBackingView {
    
    fileprivate var label: UILabel = UILabel()
    
    var text: String = "" {
        didSet {
            label.text = text
            setNeedsDisplay()
        }
    }

    var attributedText: NSAttributedString  = NSAttributedString() {
        didSet {
            label.attributedText = attributedText
            setNeedsDisplay()
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        addSubview(label)
        bringSubviewToFront(label)
        NSLayoutConstraint.fixAllSides(of: label, to: self)
    }
}

//MARK: -
/// This class draws a rounded rect in a `UIView`
///
/// It's used as a backing to text (`UILabel`) and is the basis for the timestamp and BGLevel displays.
/// It has a title box which can be drawn by setting the `title` iVar and is positioned top, middle of the view.
/// You can set the border width as well as the fill and stroke colours.
///
/// If `isTranslucent` is true then the box has a 0.2 alpha fill applied, otherwise it's a clear background. The border is always drawn with an `alpha` of 1.0
/// irrespective of what the `fillColour` is set to.
class RoundedBackingView: UIView {
    
    // Alpha setting for background fill colour
    fileprivate var backingPlateAlpha: CGFloat = 0.2

    fileprivate var pFillColour: UIColor = .white
    /// Fill of the rectangle. Brightness of this is affected by `isTranslucent`
    var fillColour: UIColor = .white {
        didSet {
            setBackgroundBrightness()
        }
    }
    /// Colour of the outline - always solid
    var strokeColour: UIColor = UIColor.white
    
    /// Fills the rectangle with the fill colour. If it's `true` then the fill is mainly transparent
    var isTranslucent: Bool = true {
        didSet {
            setBackgroundBrightness()
        }
    }
    
    var borderWidth: CGFloat = 4.0 {
        didSet {
            setNeedsDisplay()
        }
    }    
    
    func setBorderAndFillColour(colour: UIColor) {
        fillColour = colour
        strokeColour = colour
        setNeedsDisplay()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        backgroundColor = UIColor.clear
    }
    
    /// We need to dim the brightness of the colour. Fill with alpha is not well supported.
    private func setBackgroundBrightness() {
        var h: CGFloat = 0.0, s: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
        fillColour.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        pFillColour = UIColor(hue: h, saturation: s, brightness: (isTranslucent ? 0.35 : 1.0), alpha: 1.0)
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        
        //Draw main outline
        let boxPath = UIBezierPath(roundedRect: rect.insetBy(dx: borderWidth, dy: borderWidth), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 10.0, height: 10.0))
        boxPath.lineWidth = borderWidth
        pFillColour.setFill()
        boxPath.fill()
        strokeColour.setStroke()
        boxPath.stroke(with: .normal, alpha: 1.0)
        
    }
}

