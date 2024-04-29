//
//  ConstantsWatchComplication.swift
//  xDrip Watch Complication Extension
//
//  Created by Paul Plant on 29/4/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

enum ConstantsWatchComplication {
    
    /// an array of placeholder BG values
    static let bgReadingValuesPlaceholderData: [Double] = [109, 109, 109, 110, 110, 111, 110, 112, 114, 114, 118, 118, 121, 123, 126, 128, 130, 133, 137, 139, 142, 144, 146, 146, 142, 138, 135, 131, 128, 126, 124, 122, 121, 120, 120, 118, 116, 112, 109, 106, 103, 101, 98, 97, 97, 97, 96, 96, 97, 96, 92, 89, 85, 78, 70, 65, 62, 63, 67, 72, 77, 81, 86, 88, 90, 92, 94, 95, 96, 99, 101, 102, 104, 106, 108, 110, 112, 114, 116, 116, 117, 120, 120, 121, 121, 120, 118, 115, 111, 108, 105, 103, 101, 101, 102, 106, 107, 109, 112, 114, 115, 117, 119, 121, 120, 119, 117, 115, 114, 115, 116, 117, 118, 118, 119, 122, 123, 125, 125, 123, 119, 110, 103, 99, 102, 101, 101, 101, 101, 101, 137, 140, 136, 141, 153, 154, 148, 147, 148, 142, 132, 128, 132, 134]
    
    /// an array of placeholder dates starting from "now" and counting back every 5 minutes until 12 hours ago (144 values)
    static func bgReadingDatesPlaceholderData() -> [Date] {
        let firstDate: Date = .now
        var dateArray: [Date] = [firstDate]
        
        for i in 1...143 {
            dateArray.append(firstDate.addingTimeInterval(-Double(i) * 5 * 60))
        }
        
        return dateArray
    }
}
