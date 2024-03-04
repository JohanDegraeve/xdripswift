//
//  XDripWatchComplication+EntryView.swift
//  xDrip Watch Complication Extension
//
//  Created by Paul Plant on 28/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import SwiftUI
import Foundation

extension XDripWatchComplication {
    // main complication view body
    struct EntryView : View {
        // get the widget's family so that we can show the correct view
        @Environment(\.widgetFamily) private var widgetFamily
        
        var entry: Entry
        
        var body: some View {
            switch widgetFamily {
            case .accessoryRectangular:
                accessoryRectangularView
            case .accessoryCircular:
                accessoryCircularView
            case .accessoryCorner:
                accessoryCornerView
            case .accessoryInline:
                accessoryInlineView
            default:
                Image("AppIcon")
            }
        }
    }
}
