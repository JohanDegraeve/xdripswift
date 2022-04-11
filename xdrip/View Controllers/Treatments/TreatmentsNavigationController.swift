//
//  TreatmentsNavigationController.swift
//  xdrip
//
//  Created by Eduardo Pietre on 24/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import UIKit

final class TreatmentsNavigationController: UINavigationController {
	
	// set the status bar content colour to light to match new darker theme
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}
	
	// MARK: - private properties
	
	/// reference to coreDataManager
	private var coreDataManager:CoreDataManager!
	
	/// reference to treatmentEntryAccessor
	private var treatmentEntryAccessor: TreatmentEntryAccessor!

	// MARK: - public functions
	
	/// configure
	public func configure(coreDataManager: CoreDataManager) {
		// initalize private properties
		self.coreDataManager = coreDataManager
		self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
	}
	
	// MARK: - overrides
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		delegate = self
		
	}
	
	override func viewDidAppear(_ animated: Bool) {
		
		// remove titles from tabbar items
		self.tabBarController?.cleanTitles()
		
	}
	
	override func viewWillAppear(_ animated: Bool) {
	
		// restrict rotation of this Navigation Controller to just portrait
		(UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait
		
	}
	
}

extension TreatmentsNavigationController: UINavigationControllerDelegate {
    
	func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
		
		if let treatmentsViewController = viewController as? TreatmentsViewController {
            
			treatmentsViewController.configure(coreDataManager: coreDataManager)
            
		}
        
	}
    
}


