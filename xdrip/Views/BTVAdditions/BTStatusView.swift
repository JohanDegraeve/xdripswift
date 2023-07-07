//
//  BTStatusView.swift
//  xdrip
//
//  Created by Todd Dalton on 29/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import UIKit
import CoreBluetooth

/**
 A small `UIView`class to display a couloured indicator reflecting the CGM connection status
 */
class BTStatusView: UIView {
    
    var colour: UIColor = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /// Passed in by the view controller to ascertain the connection status of the CGM
    var btManager: BluetoothPeripheralManager? = nil {
        didSet {
            setNeedsDisplay()
        }
    }

    /// This is the status of the BT transmitter.
    ///
    /// Used by the `BGView` to help with correctly displaying when the app has just started
    /// and the colour of the BG level digits should be greyed.
    private (set) var status: CBPeripheralState? = nil
    
    /// This is the connected icon
    private var _connected: UIImageView = BTVImageView(image: UIImage(named: "BT_connected_icon")!.withTintColor(.green, renderingMode: .alwaysOriginal))
    
    /// This is the connecting icon
    private var _connecting: UIImageView = BTVImageView(image: UIImage(named: "BT_connecting_icon")!.withTintColor(.yellow, renderingMode: .alwaysOriginal))
    
    /// This is the disconnecting icon
    private var _disconnecting: UIImageView = BTVImageView(image: UIImage(named: "BT_disconnecting_icon")!.withTintColor(.orange, renderingMode: .alwaysOriginal))
    
    /// This is the disconnected icon
    private var _disconnected: UIImageView = BTVImageView(image: UIImage(named: "BT_disconnected_icon")!.withTintColor(.red, renderingMode: .alwaysOriginal))
    
    /// This is the alpha value for the unlit icons
    private let _disabledAlpha: CGFloat = 0.3
    
    override func didMoveToSuperview() {
        
        // Connected
        let _stackView = UIStackView(arrangedSubviews: [_connected, _connecting, _disconnecting, _disconnected])
        _stackView.arrangedSubviews.forEach { view in
            if let _view = view as? BTVImageView {
                _view.backgroundColor = .clear
                _view.contentMode = .scaleAspectFit
                _view.translatesAutoresizingMaskIntoConstraints = false
                _view.setIntrinsicHeight(to: 20.0)
            }
        }
        addSubview(_stackView)
        _stackView.translatesAutoresizingMaskIntoConstraints = false
        _stackView.axis = .horizontal
        _stackView.distribution = .equalSpacing
        _stackView.alignment = .center
        _stackView.clipsToBounds = true
        _stackView.spacing = 3.0
        let _left = NSLayoutConstraint.fix(constraint: .left, of: _stackView, toSameOfView: self, offset: 15.0)
        let _right = NSLayoutConstraint.fix(constraint: .right, of: _stackView, toSameOfView: self, offset: -15.0)
        let _height = NSLayoutConstraint.fix(constraint: .height, of: _stackView, toSameOfView: _stackView)
        let _centre = NSLayoutConstraint.fix(constraint: .centerY, of: _stackView, toSameOfView: self)
        
        addConstraints([_left, _right, _centre, _height])

        backgroundColor = .clear
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        
        let _box = UIBezierPath(roundedRect: rect.insetBy(dx: 2.0, dy: 2.0), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: rect.height, height: rect.height))
        UIColor.black.setFill()
        _box.fill()
        colour.setStroke()
        _box.lineWidth = 2.0
        _box.stroke()
        
        super.draw(rect)
        
        _connected.alpha = _disabledAlpha
        _connecting.alpha = _disabledAlpha
        _disconnected.alpha = _disabledAlpha
        _disconnecting.alpha = _disabledAlpha
        
        if let _btman = btManager {
            
            guard let _firstElement = _btman.bluetoothPeripherals.first, let _transmitter = _btman.getBluetoothTransmitter(for: _firstElement, createANewOneIfNecesssary: false) else {
                _disconnected.alpha = 1.0
                status = nil
                return
            }
            
            status = _transmitter.getConnectionStatus() ?? .connecting // provide a default value
            
            switch status {
            case .connected:
                _connected.alpha = 1.0
            case .connecting:
                _connecting.alpha = 1.0
            case .disconnected:
                _disconnected.alpha = 1.0
            case .disconnecting:
                _disconnecting.alpha = 1.0
            case .none:
                _disconnected.alpha = 1.0
            @unknown default:
                break
            }
        } else {
            _connecting.alpha = 1.0
        }
    }
}

/**
 Custom `UIImagegView` to properly resize an image within a `UIStackView`
 
 The pain with `UIImageView` is that it won't resize when inside a `UIStackView`.
 https://stackoverflow.com/a/33372740/372347
 
 */
class BTVImageView: UIImageView {
    
    // Private iVar to hold the required size. This is returned with the overridden intrinsicContentSize
    private var _constrainedSize: CGSize = CGSize(width: 100.0, height: 100.0)
    
    override func didMoveToSuperview() {
        guard let _image = image else { return }
        _constrainedSize = _image.size
    }
    
    public func setIntrinsicSize(to size: CGSize) {
        _constrainedSize = size
        self.invalidateIntrinsicContentSize()
    }
    
    /// Sets the height (and then the width of an image).
    public func setIntrinsicHeight(to height: CGFloat) {
        guard height > 0.0 else { return }
        let originalImage = image?.size ?? CGSize(width: 100, height: 100) // Arbitary default value
        let _aspect = originalImage.width / originalImage.height
        let _newWidth = height * _aspect
        setIntrinsicSize(to: CGSize(width: _newWidth, height: height))
    }
    
    /// Sets the width (and then the height of an image).
    public func setIntrinsicWidth(to width: CGFloat) {
        guard width > 0.0 else { return }
        let originalImage = image?.size ?? CGSize(width: 100, height: 100) // Arbitary default value
        let _aspect = originalImage.width / originalImage.height
        let _newHeight = width / _aspect
        setIntrinsicSize(to: CGSize(width: width, height: _newHeight))
    }
    
    /// Overridden to supply a required `CGSize`
    override var intrinsicContentSize: CGSize {
        return _constrainedSize
    }
}
