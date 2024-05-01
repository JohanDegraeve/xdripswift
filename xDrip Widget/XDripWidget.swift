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
                .widgetBackground(backgroundView: Color.black)
        }
        .configurationDisplayName(ConstantsHomeView.applicationName)
        .description("Show the current blood glucose level")
        .supportedFamilies([
                .systemSmall,
                .systemMedium,
                .systemLarge,
                .accessoryCircular,
                .accessoryRectangular
            ])
    }
}

struct XDripWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            XDripWidget.EntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("systemSmall")
            XDripWidget.EntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("systemMedium")
            XDripWidget.EntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("accessoryCircular")
            XDripWidget.EntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .previewDisplayName("accessoryInline")
        }
    }
}
