//
//  ProgressBarViewController.swift
//  xdrip
//
//  Created by Eduardo Pietre on 13/05/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation



/// Struct that holds all the needed info to update a progress bar.
public struct ProgressBarStatus<T> {
	/// Should the progress bar be dismissed?
	public let complete: Bool
	
	/// How is the progress going? 0.0-1.0 values, 0 = nothing, 1 = full bar.
	public let progress: Float
	
	/// The data (optional) to be given to a callback.
	public let data: T?
	
	
	/// Default Init
	init(complete: Bool, progress: Float, data: T?) {
		self.complete = complete
		self.progress = progress
		self.data = data
	}
	
	/// Init just from progress
	init(progress: Float) {
		self.complete = progress >= 1.0
		self.progress = progress
		self.data = nil
	}
}


/// ProgressBarViewController is an utility UIViewController
/// that creates and manages the update of a progress bar.
public class ProgressBarViewController : UIViewController {
	
	/// Reference to the loading indicator.
	private var indicator = UIProgressView(progressViewStyle: .bar)
	
	/// loadView will ofuscate the background and centralize the indicator, starting
	public override func viewDidLoad() {
		/// Change the backgroundColor to ofuscate the stuff behind.
		view.backgroundColor = UIColor(white: 0, alpha: 0.80)
		
		/// Sets the trackTintColor and progressTintColor
		indicator.trackTintColor = .white
		indicator.progressTintColor = .lightGray

		/// Required to centralize the indicator
		indicator.translatesAutoresizingMaskIntoConstraints = false
		
		/// Starts it at 0
		indicator.setProgress(0, animated: false)
		view.addSubview(indicator)

		// Sets X and Y to centralize it
		indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
		indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
		
		// Set width and height
		indicator.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.60).isActive = true
		indicator.heightAnchor.constraint(equalToConstant: 15).isActive = true
		
		// UIProgressView has many subviews, if we want to round the corners
		// we must apply to each one of the subviews.
		for subview: UIView in self.indicator.subviews {
			if subview is UIImageView {
				subview.clipsToBounds = true
				subview.layer.cornerRadius = 7
			}
		}
	}
	
	/// Starts the ProgressBar.
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
	
	/// Ends the ProgressBar.
	/// This method can be called from any thread in a safe way.
	public func end() {
		DispatchQueue.main.async {
			self.willMove(toParent: nil)
			self.view.removeFromSuperview()
			self.removeFromParent()
		}
	}
	
	/// Updated the ProgressBar.
	/// This method can be called from any thread in a safe way.
	public func update<T>(status: ProgressBarStatus<T>) {
		/// If completed, end the loading bar.
		if (status.complete) {
			self.end()
			return
		}

		DispatchQueue.main.async {
			/// Otherwise, update it.
			self.indicator.setProgress(status.progress, animated: true)
		}
	}
}
