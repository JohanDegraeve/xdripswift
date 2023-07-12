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
    
    /// Passed in by the view controller to get the connection status of the CGM
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
    private var connectedIcon: UIImageView = FixedSizeImageView(image: UIImage(named: "BT_connected_icon")!.withTintColor(.green, renderingMode: .alwaysOriginal))
    
    /// This is the connecting icon
    private var connectingImage: UIImageView = FixedSizeImageView(image: UIImage(named: "BT_connecting_icon")!.withTintColor(.yellow, renderingMode: .alwaysOriginal))
    
    /// This is the disconnecting icon
    private var disconnectingImage: UIImageView = FixedSizeImageView(image: UIImage(named: "BT_disconnecting_icon")!.withTintColor(.orange, renderingMode: .alwaysOriginal))
    
    /// This is the disconnected icon
    private var disconnectedImage: UIImageView = FixedSizeImageView(image: UIImage(named: "BT_disconnected_icon")!.withTintColor(.red, renderingMode: .alwaysOriginal))
    
    /// This is the alpha value for the unlit icons
    private let disabledAlpha: CGFloat = 0.3
    
    override func didMoveToSuperview() {
        
        let imagesStackView = UIStackView(arrangedSubviews: [connectedIcon, connectingImage, disconnectingImage, disconnectedImage])
        imagesStackView.arrangedSubviews.forEach { view in
            if let _view = view as? FixedSizeImageView {
                _view.backgroundColor = .clear
                _view.contentMode = .scaleAspectFit
                _view.translatesAutoresizingMaskIntoConstraints = false
                _view.setIntrinsicHeight(to: 20.0)
            }
        }
        addSubview(imagesStackView)
        imagesStackView.translatesAutoresizingMaskIntoConstraints = false
        imagesStackView.axis = .horizontal
        imagesStackView.distribution = .equalSpacing
        imagesStackView.alignment = .center
        imagesStackView.clipsToBounds = true
        imagesStackView.spacing = 3.0
        let left = NSLayoutConstraint.fix(constraint: .left, of: imagesStackView, toSameOfView: self, offset: 15.0)
        let right = NSLayoutConstraint.fix(constraint: .right, of: imagesStackView, toSameOfView: self, offset: -15.0)
        let height = NSLayoutConstraint.fix(constraint: .height, of: imagesStackView, toSameOfView: imagesStackView)
        let centre = NSLayoutConstraint.fix(constraint: .centerY, of: imagesStackView, toSameOfView: self)
        
        addConstraints([left, right, centre, height])

        backgroundColor = .clear
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        
        let box = UIBezierPath(roundedRect: rect.insetBy(dx: 2.0, dy: 2.0), byRoundingCorners: .allCorners, cornerRadii: CGSize(width: rect.height, height: rect.height))
        UIColor.black.setFill()
        box.fill()
        colour.setStroke()
        box.lineWidth = 2.0
        box.stroke()
        
        super.draw(rect)
        
        // Switch them all off
        connectedIcon.alpha = disabledAlpha
        connectingImage.alpha = disabledAlpha
        disconnectedImage.alpha = disabledAlpha
        disconnectingImage.alpha = disabledAlpha
        
        if let btMan = btManager {

            // Get the main transmitter
            guard let firstElement = btMan.bluetoothPeripherals.first, let transmitter = btMan.getBluetoothTransmitter(for: firstElement, createANewOneIfNecesssary: false) else {
                // Turn on the disconnected icon
                disconnectedImage.alpha = 1.0
                status = nil
                return
            }
            
            status = transmitter.getConnectionStatus() ?? .connecting // < provide a default value
            
            switch status {
            case .connected:
                connectedIcon.alpha = 1.0
                accessibilityLabel = "Bluetooth Connected"
            case .connecting:
                connectingImage.alpha = 1.0
                accessibilityLabel = "Bluetooth Connecting"
            case .disconnected:
                disconnectedImage.alpha = 1.0
                accessibilityLabel = "Bluetooth disconnected"
            case .disconnecting:
                disconnectingImage.alpha = 1.0
                accessibilityLabel = "Bluetooth disconnecting"
            case .none:
                disconnectedImage.alpha = 1.0
                accessibilityLabel = "Bluetooth disconnected"
            @unknown default:
                disconnectedImage.alpha = 1.0
                accessibilityLabel = "Bluetooth disconnected"
            }
        } else {
            accessibilityLabel = "Bluetooth status unknown"
        }
    }
}
