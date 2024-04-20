//
//  xDripWatchComplication.swift
//  xDrip Watch Complication
//
//  Created by Paul Plant on 23/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import WidgetKit
import SwiftUI

@main
struct XDripWatchComplication: Widget {
    let kind: String = "xDripWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            XDripWatchComplication.EntryView(entry: entry)
        }
        .configurationDisplayName(ConstantsHomeView.applicationName)
        .description("Show the current blood glucose level")
    }
}

#Preview(as: .accessoryRectangular) {
    XDripWatchComplication()
} timeline: {
    XDripWatchComplication.Entry.placeholder
}
