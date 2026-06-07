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
    
    /// color for in range but darkened
    static let pieChartInRangeSliceColorDarkened = UIColor.init(red: 0.0, green: 0.3, blue: 0.0, alpha: 1)
    
    /// pie slice color for high
    static let pieChartHighSliceColor = UIColor.systemYellow
    
    /// contstants to define the standardised "Time in Range" (TIR) values in case the user prefers to use them
    /// published values from here: https://care.diabetesjournals.org/content/42/8/1593
    static let standardisedLowValueForTIRInMgDl = 70.0
    static let standardisedHighValueForTIRInMgDl = 180.0
    static let standardisedLowValueForTIRInMmol = 3.9
    static let standardisedHighValueForTIRInMmol = 10.0
    
    /// contstants to define the newer "Time in Tight Range" (TITR) values in case the user prefers to use them
    /// published values from here: https://pubmed.ncbi.nlm.nih.gov/37902743/
    static let standardisedLowValueForTITRInMgDl = 70.0
    static let standardisedHighValueForTITRInMgDl = 140.0
    static let standardisedLowValueForTITRInMmol = 3.9
    static let standardisedHighValueForTITRInMmol = 7.8
    
    /// highlight color when changing between TIR modes
    static let highlightColorTitles: UIColor = .white
    
    /// minimum filter time in minutes (used for Libre 2 readings)
    static let minimumFilterTimeBetweenReadings: Double = 4.5
    
    /// should we show the easter egg when the user is 100% in range?
    static let showInRangeEasterEgg: Bool = true
    
    /// and if we want to show it, how many hours after midnight should we wait before showing it?
    static let minimumHoursInDayBeforeShowingEasterEgg = 16.0 // 16:00hrs in the afternoon
    
    /// how many days should the TIR chart have in the landscape 24-hour view?
    static let numberOfDaysForTIRChartLandscapeView = 14
    
    /// what should be the minimum value we show as the y-axis value. Usually we aim for 75 so that we get at least one grid line for context
    /// remember to factor in the tirChartYAxisMinimumOffset by adding  it to the minimum axis value you really want
    /// if you want 75 minimum value and have you the minimum offset as 10, then use 85 as the minimum value
    static let tirChartYAxisMinimumAxisValue = 85.0
    
    /// how much offset should we use below the minimum TIR value to make the y-axis origin?
    static let tirChartYAxisMinimumOffset = 10.0
    
}

