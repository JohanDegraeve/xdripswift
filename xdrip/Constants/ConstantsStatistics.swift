//
//  ConstantsStatistics.swift
//  xdrip
//
//  Created by Paul Plant on 25/04/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit

/// constants for statistics view
enum ConstantsStatistics {
    
    /// animation speed when drawing the pie chart
    static let pieChartAnimationSpeed = 0.3
    
    /// label colors for the statistics
    static let labelLowColor = UIColor.systemRed
    static let labelInRangeColor = UIColor.systemGreen
    static let labelHighColor = UIColor.systemYellow
    
    /// pie slice color for low
    static let pieChartLowSliceColor = UIColor.systemRed
    
    /// pie slice color for in range
    static let pieChartInRangeSliceColor = UIColor.init(red: 0.0, green: 0.6, blue: 0.0, alpha: 1)
    
    /// pie slice color for high
    static let pieChartHighSliceColor = UIColor.systemYellow
    
    // contstants to define the standardised "Time in Range" (TIR) values in case the user prefers to use them
    // published values from here: https://care.diabetesjournals.org/content/42/8/1593
    static let standardisedLowValueForTIRInMgDl = 70.0
    static let standardisedHighValueForTIRInMgDl = 180.0
    static let standardisedLowValueForTIRInMmol = 3.9
    static let standardisedHighValueForTIRInMmol = 10.0
    
    // contstants to define the newer "Time in Tight Range" (TITR) values in case the user prefers to use them
    // published values from here: https://pubmed.ncbi.nlm.nih.gov/37902743/
    static let standardisedLowValueForTITRInMgDl = 70.0
    static let standardisedHighValueForTITRInMgDl = 140.0
    static let standardisedLowValueForTITRInMmol = 3.9
    static let standardisedHighValueForTITRInMmol = 7.8
    
    /// highlight color when changing between TIR modes
    static let highlightColorTitles: UIColor = .white
    
    // minimum filter time in minutes (used for Libre 2 readings)
    static let minimumFilterTimeBetweenReadings: Double = 4.5
    
    // should we show the easter egg when the user is 100% in range?
    static let showInRangeEasterEgg: Bool = true
    // and if we want to show it, how many hours after midnight should we wait before showing it?
    static let minimumHoursInDayBeforeShowingEasterEgg = 16.0 // 16:00hrs in the afternoon
}

