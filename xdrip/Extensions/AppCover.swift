//
//  AppCoverProtocol.swift
//  xdrip
//
//  Created by Todd Dalton on 17/11/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation


protocol AppCover: UIViewController {
    
    /// The protocol requires that the object sets a completion block to
    /// be executed each time the cover screen is applied or removed.
    var onAppCoverCompletion: (()->Void)? { get set }
    
    /// Show or hide the main screen when the app changes from foreground to background or visa versa.
    ///
    /// - parameter flag: if `true` then the cover goes on, `false` and the main screen is visible
    /// - parameter onCompletion: code block which will be executed on the main thread (so safe to do UI updates in it)
    func showAppCoverScreen(_ flag: Bool)
}

extension AppCover {
    
    func showAppCoverScreen(_ flag: Bool) {
        
        // Try and find  any cover that's already there
        let existingCover = view.subviews.filter { aView in
            return aView.tag == 1234567890 // << see later
        }
        
        if !flag && existingCover.count < 1 {
            // we're trying to remove a cover that isn't there
            return
        }
        
        if flag && existingCover.count > 0 {
            // we're trying to add a cover when there already is one
            return
        }
        
        if !flag {
            UIView.animate(withDuration: 0.5, animations: {
                existingCover.first?.alpha = 0.0
            }) { finished in
                existingCover.first?.removeFromSuperview()
                DispatchQueue.main.async {
                    self.onAppCoverCompletion?()
                }
            }
            return
        }
        
        let icon = UIImageView(image: UIImage(named: "AppCover"))
        icon.contentMode = .scaleAspectFit
        icon.contentScaleFactor = 0.5
        icon.backgroundColor = .black
        icon.alpha = 0.0
        icon.tag = 1234567890 // << arbitrary tag
        view.addSubview(icon)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.fixAllSides(of: icon, to: view)
        
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: {
            icon.alpha = 1.0
        }) { finished in
            DispatchQueue.main.async {
                self.onAppCoverCompletion?()
            }
        }
    }
}
