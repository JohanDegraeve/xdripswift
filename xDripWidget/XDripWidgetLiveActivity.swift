//
//  XDripWidgetLiveActivity.swift
//  XDripWidget
//
//  Created by Paul Plant on 29/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct XDripWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: XDripWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                HStack {
                    Text(context.state.eventType.title).foregroundStyle(getBgColor(bgColorInt: context.state.bgValueColorInt, isTitle: true))
                    Spacer()
                    Text("\(context.state.bgValueString) \(context.state.trendArrow)").foregroundStyle(getBgColor(bgColorInt: context.state.bgValueColorInt, isTitle: false))
                }.font(.largeTitle).bold().foregroundStyle(getBgColor(bgColorInt: context.state.bgValueColorInt, isTitle: false))
                HStack {
                    Text("Started \(context.attributes.eventStartDate.formatted(date: .omitted, time: .shortened))")
                    Spacer()
                    Text(context.attributes.bgValueUnitString)
                        .foregroundStyle(.gray)
                }
                .font(.headline)
                Spacer()
                
                HStack {
                    Text(context.state.eventType.explanation)
                }
                .font(.body)
                Spacer()
            }
            .padding(15)
            //.activityBackgroundTint(Color.cyan)
            //.activitySystemActionForegroundColor(Color.black)
            //.background(.ultraThinMaterial)
            //.activityBackgroundTint(Color.red)
            //.activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.eventType.title)
                        .font(.largeTitle).bold().foregroundStyle(getBgColor(bgColorInt: context.state.eventType.bgColorInt, isTitle: true))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.bgValueString) \(context.state.trendArrow) ")
                        .font(.largeTitle).bold().foregroundStyle(getBgColor(bgColorInt: context.state.eventType.bgColorInt, isTitle: false))
                }
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        HStack {
                                Text("Started \(context.attributes.eventStartDate.formatted(date: .omitted, time: .shortened))")
                            Spacer()
                            Text(context.attributes.bgValueUnitString)
                                .foregroundStyle(.gray)
                        }
                        .font(.headline)
                        Spacer()
                        HStack {
                            Text(context.state.eventType.explanation)
                        }
                        .font(.body)
                        Spacer()
                    }
                }
            } compactLeading: {
                Text(context.state.eventType.title)
            } compactTrailing: {
                Text("\(context.state.bgValueString) \(context.state.trendArrow)")
            } minimal: {
                Text(context.state.bgValueString)
                    .foregroundStyle(getBgColor(bgColorInt: context.state.eventType.bgColorInt, isTitle: false))
            }
            .widgetURL(URL(string: "xdripswift"))
        }
    }
    
    
    func getBgColor(bgColorInt: Int, isTitle: Bool) -> Color {
        switch bgColorInt {
        case 1:
            return .red
        case 2:
            return isTitle ? .primary : .green
        case 3:
            return .yellow
        default:
            return .green
        }
    }
}

@available(iOS 16.2, *)
struct XDripWidgetLiveActivity_Previews: PreviewProvider {
    static let attributes = XDripWidgetAttributes(bgValueUnitString: "mg/dL", eventStartDate: Date().addingTimeInterval(-1000))
    static let contentState = XDripWidgetAttributes.ContentState(eventType: .inRangeDropping, trendArrow: "↘", bgValueString: "134")
    
    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Notification")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Compact")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Expanded")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Minimal")
    }
}

