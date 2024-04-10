//
//  XDripWidget+EntryView.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI
import Foundation

extension XDripWidget {
    // main complication view body
    struct EntryView : View {
        // get the widget's family so that we can show the correct view
        @Environment(\.widgetFamily) private var widgetFamily
        
        @Environment(\.colorScheme) var colorScheme
        
        var entry: Entry
        
        var body: some View {
            switch widgetFamily {
            case .systemSmall:
                systemSmallView
            case .systemMedium:
                systemMediumView
            case .systemLarge:
                systemLargeView
            case .accessoryCircular:
                accessoryCircularView
            case .accessoryRectangular:
                accessoryRectangularView
            default:
                Text("No Data Available")
            }
        }
    }
}

