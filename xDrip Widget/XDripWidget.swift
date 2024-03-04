//
//  XDripWidget.swift
//  XDripWidget
//
//  Created by Paul Plant on 30/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import WidgetKit
import SwiftUI

struct XDripWidget: Widget {
    let kind: String = "xDripWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            XDripWidget.EntryView(entry: entry)
        }
        .configurationDisplayName(ConstantsHomeView.applicationName)
        .description("Show the current blood glucose level")
    }
}

struct XDripWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            XDripWidget.EntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            //            EntryView(entry: Entry(date: Date()))
            //                .previewContext(WidgetPreviewContext(family: .systemMedium))
            //
            //            EntryView(entry: Entry(date: Date()))
            //                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}

//@available(iOS 17.0, *)
//#Preview(as: .systemSmall) {
//    XDripWidget()
//} timeline: {
//    XDripWidget.Entry.placeholder
//}

//struct Provider: TimelineProvider {
//    func placeholder(in context: Context) -> Entry {
//        
//        func placeholder(in context: Context) -> Entry {
//            .placeholder
//        }
//        
//        func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) {
//            completion(.placeholder)
//        }
//        
//        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
//            let entry = Entry(date: .now, widgetState: getWidgetStateFromSharedUserDefaults() ?? sampleWidgetStateFromProvider)
//            
//            completion(.init(entries: [entry], policy: .atEnd))
//        }
//    }
//}

//struct SimpleEntry: TimelineEntry {
//    let date: Date
//    let emoji: String
//}

//struct XDripWidgetEntryView : View {
//    var entry: Provider.Entry
//
//    var body: some View {
//        VStack {
//            Text("Time:")
//            Text(entry.date, style: .time)
//
//            Text("Emoji:")
//            Text(entry.emoji)
//        }
//    }
//}

