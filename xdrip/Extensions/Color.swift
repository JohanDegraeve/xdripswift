//
//  Color.swift
//  xdrip
//
//  Created by Todd Dalton on 09/01/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

extension Color {
    
    static func rangeColourRGB(from description: BgRangeDescription, isForPieChart: Bool = false) -> [String: CGFloat] {
        switch description {

        case .inRange:
            return isForPieChart ? ["red": 0.217, "green": 0.998, "blue": 0.433] : ["red": 0.0, "green": 1.0, "blue": 0.0]
            
        case .low:
            return isForPieChart ? ["red": 0.219, "green": 0.768, "blue": 0.998] : ["red": 1.0, "green": 1.0, "blue": 0.0]
            
        case .high:
            return isForPieChart ? ["red": 1.000, "green": 0.445, "blue": 0.218] : ["red": 1.0, "green": 1.0, "blue": 0.0]
            
        case .urgentLow:
            return isForPieChart ? ["red": 1.000, "green": 0.216, "blue": 0.784] : ["red": 1.0, "green": 0.0, "blue": 0.0]
            
        case .urgentHigh:
            return isForPieChart ? ["red": 1.000, "green": 0.216, "blue": 0.383] : ["red": 1.0, "green": 0.0, "blue": 0.0]
            
        case .notUrgent:
            return ["red": 1.0, "green": 1.0, "blue": 0.0]
            
        case .special:
            return ["red": 1.0, "green": 0.5, "blue": 0.25]
            
        case .rangeNR:
            return ["red": 0.6, "green": 0.6, "blue": 0.6]
            
        case .urgent:
            return ["red": 1.0, "green": 0.0, "blue": 0.0]
        }
    }
    
    /// This is the color for the selected granularity buttons on stats pages
    static let SelectedColour: Color = Color(red: 0.814, green: 0.574, blue: 1.000)
    
     /// This is the color for the unselected granularity buttons on stats pages
    static let UnselectedColour: Color = Color(white: 0.8)
    
    /// Returns a colour for the SwiftUI pie or bar chart.
    ///
    /// For the pie chart, we need colours that are different for every range,
    /// but for a bar chart, they can be the more standard red, yellow, green
    static func rangeColour(from description: BgRangeDescription, isForPieChart: Bool = false) -> Color {
        
        let comps = Color.rangeColourRGB(from: description, isForPieChart: isForPieChart)
        
        return Color(red: comps["red"]!, green: comps["green"]!, blue: comps["blue"]!)
    }
    

    /// Returns a colour for the SwiftUI pie chart label text.
    ///
    static func oppositeRangeColour(from description: BgRangeDescription) -> Color {
        switch description {
            
        case .high, .inRange, .low, .urgentHigh:
            return Color.black
      
        default:
            return Color.white
        }
    }
}
