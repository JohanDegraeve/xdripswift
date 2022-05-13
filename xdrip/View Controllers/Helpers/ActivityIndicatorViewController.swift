//
//  ActivityIndicatorViewController.swift
//  xdrip
//
//  Created by Eduardo Pietre on 13/05/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation


/// ActivityIndicatorViewController is an utility UIViewController
/// that creates a spinner loading indicator.
public class ActivityIndicatorViewController : UIViewController {
	
	/// Reference to the loading indicator.
	private var indicator = UIActivityIndicatorView(style: .whiteLarge)

	/// loadView will ofuscate the background and centralize the indicator, starting it.
	public override func loadView() {
		view = UIView()
		/// Change the backgroundColor to ofuscate the stuff behind.
		view.backgroundColor = UIColor(white: 0, alpha: 0.7)

		/// Centralizes the indicator
		self.indicator.translatesAutoresizingMaskIntoConstraints = false
		self.indicator.startAnimating()
		view.addSubview(self.indicator)

		self.indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
		self.indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
	}
	
	/// Starts the ActivityIndicator.
	/// This method can be called from any thread in a safe way.
	/// - parameters:
	///     - onParent: UIViewController: the parent UIViewController.
	public func start(onParent: UIViewController) {
		DispatchQueue.main.async {
			onParent.addChild(self)
			self.view.frame = onParent.view.frame
			onParent.view.addSubview(self.view)
			self.didMove(toParent: onParent)
		}
	}
	
	/// Ends the ActivityIndicator.
	/// This method can be called from any thread in a safe way.
	public func end() {
		DispatchQueue.main.async {
			self.willMove(toParent: nil)
			self.view.removeFromSuperview()
			self.removeFromParent()
		}
	}
}
