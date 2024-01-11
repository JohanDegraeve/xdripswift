//
//  SUIChartViewController.swift
//  xdrip
//
//  Created by Todd Dalton on 09/01/2024.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import CoreData

/**
 
 This `uiViewController` sets up the pie and AGP charts
 
 It passes down the current `StatisticsManager` to the `Swift UI` views
 which can use it to montior when a new batch of statistics is available.
 
 The controller has a `UIView` that is twice as wide as the screen. In order
 to flip between pie chart and AGP chart, we grab hold of the left layout constraint
 and animate it to reveal the required chart.
 
 */
class SUIChartViewController: UIViewController {
    
    /// This will be the controller for the SwiftUI chart view
    var suiChartView: SUIChartView!
    
    // This will be the SwiftUI view for the graularity buttons
    var suiGranularityButtons: SUIGranularityButtons!
    
    @IBOutlet weak var buttonsView: UIView!
    @IBOutlet weak var chartView: UIView!
    
    var statisticsManager: StatisticsManager?
    
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // prevent screen rotation
        (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait
    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // prevent screen rotation
        (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait
        
        if let appD = UIApplication.shared.delegate as? AppDelegate {
            
            
            guard let statsMan = appD.statisticManager else {
                fatalError("!!__No core data__!!")
            }
            
            // Setup SwiftUI chart view
            self.suiChartView = SUIChartView(statMan: statsMan)
            let cvc = UIHostingController(rootView: self.suiChartView)
            cvc.view!.translatesAutoresizingMaskIntoConstraints = false
            self.addChild(cvc)
            self.chartView.addSubview(cvc.view!)
            cvc.view!.backgroundColor = .black
            NSLayoutConstraint.fixAllSides(of: cvc.view!, to: self.chartView)
            
            // Setup SwiftUI granularity buttons
            self.suiGranularityButtons = SUIGranularityButtons()
            let gvc = UIHostingController(rootView: self.suiGranularityButtons)
            gvc.view!.translatesAutoresizingMaskIntoConstraints = false
            gvc.view!.backgroundColor = .black
            self.addChild(gvc)
            self.buttonsView.addSubview(gvc.view!)
            NSLayoutConstraint.fixAllSides(of: gvc.view!, to: self.buttonsView)
        }
    }
    
    @IBAction func close(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
}
