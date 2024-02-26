//
//  xDripWatchComplication.swift
//  xDrip Watch Complication
//
//  Created by Paul Plant on 23/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), bgValueInMgDl: 123, isMgDl: true, slopeOrdinal: 3, bgValueStringInUserChosenUnit: "234")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), bgValueInMgDl: 123, isMgDl: true, slopeOrdinal: 3, bgValueStringInUserChosenUnit: "234")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, bgValueInMgDl: 123, isMgDl: true, slopeOrdinal: 3, bgValueStringInUserChosenUnit: "234")
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    var date: Date
    
    let bgValueInMgDl: Double
    let isMgDl: Bool
    let slopeOrdinal: Int
    let bgValueStringInUserChosenUnit: String
    
    ///  returns a string holding the trend arrow
    /// - Returns: trend arrow string (i.e.  "↑")
    func trendArrow() -> String {
        switch slopeOrdinal {
        case 7:
            return "\u{2193}\u{2193}" // ↓↓
        case 6:
            return "\u{2193}" // ↓
        case 5:
            return "\u{2198}" // ↘
        case 4:
            return "\u{2192}" // →
        case 3:
            return "\u{2197}" // ↗
        case 2:
            return "\u{2191}" // ↑
        case 1:
            return "\u{2191}\u{2191}" // ↑↑
        default:
            return ""
        }
    }
}

// main complication view body
struct xDripWatchComplicationEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            HStack {
                Text(entry.bgValueStringInUserChosenUnit)
                Text(entry.trendArrow())
            }
        }
    }
}

@main
struct xDripWatchComplication: Widget {
    let kind: String = "xDripWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(watchOS 10.0, *) {
                xDripWatchComplicationEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                xDripWatchComplicationEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName(ConstantsHomeView.applicationName)
        .description("This is an example widget.")

    }
    
    
    
    
    
}

//@available(watchOS 10.0, *)
#Preview(as: .accessoryRectangular) {
    xDripWatchComplication()
} timeline: {
    SimpleEntry(date: Date(), bgValueInMgDl: 123, isMgDl: true, slopeOrdinal: 3, bgValueStringInUserChosenUnit: "234")
}
