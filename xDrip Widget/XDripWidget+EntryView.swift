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
        
        // check if the widget container background has been removed by iOS
        // this allows us to check if the widget is being displayed in StandBy mode
        @Environment(\.showsWidgetContainerBackground) var isNotBeingUsedInStandByMode
        
        // check if we should consider that we're during the night and use this
        // to display the widget in high-contrast mode
        // will only be used in conjunction with isNotInStandByMode
        func isAtNight() -> Bool {
            if let currentHour = Calendar.current.dateComponents([.hour], from: Date()).hour, currentHour > ConstantsWidgetExtension.nightModeFromHour || currentHour < ConstantsWidgetExtension.nightModeUntilHour {
                return entry.widgetState.allowStandByHighContrast
            } else {
                return false
            }
        }
        
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

