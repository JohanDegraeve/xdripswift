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
                    Text(context.state.getBgTitle()).foregroundStyle(context.state.getBgColor())
                    Spacer()
                    Text("\(context.state.bgValueStringInUserChosenUnit) \(context.state.trendArrow)").foregroundStyle(context.state.getBgColor())
                }.font(.largeTitle).bold().foregroundStyle(context.state.getBgColor())
                HStack {
                    Text("Started \(context.attributes.eventStartDate.formatted(date: .omitted, time: .shortened))")
                    Spacer()
                    Text(context.state.bgUnitString)
                        .foregroundStyle(.gray)
                }
                .font(.headline)
                Spacer()
                
                HStack {
                    Text("Message")
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
                    Text(context.state.getBgTitle())
                        .font(.largeTitle).bold().foregroundStyle(context.state.getBgColor())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.bgValueStringInUserChosenUnit) \(context.state.trendArrow)")
                        .font(.largeTitle).bold().foregroundStyle(context.state.getBgColor())
                }
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        HStack {
                                Text("Started \(context.attributes.eventStartDate.formatted(date: .omitted, time: .shortened))")
                            Spacer()
                            Text(context.state.bgUnitString)
                                .foregroundStyle(.gray)
                        }
                        .font(.headline)
                        Spacer()
                        HStack {
                            Text("Message")
                        }
                        .font(.body)
                        Spacer()
                    }
                }
            } compactLeading: {
                Text(context.state.getBgTitle()).foregroundStyle(context.state.getBgColor())
            } compactTrailing: {
                Text("\(context.state.bgValueStringInUserChosenUnit) \(context.state.trendArrow)").foregroundStyle(context.state.getBgColor())
            } minimal: {
                Text("\(context.state.bgValueStringInUserChosenUnit)")
                    .foregroundStyle(context.state.getBgColor())
            }
            .widgetURL(URL(string: "xdripswift"))
        }
        
    }
    
}

@available(iOS 16.2, *)
struct XDripWidgetLiveActivity_Previews: PreviewProvider {
    static let attributes = XDripWidgetAttributes(eventStartDate: Date().addingTimeInterval(-1000))
    static let contentState = XDripWidgetAttributes.ContentState(bgValueInMgDl: 75, isMgDl: true, trendArrow: "↘", deltaChangeInMgDl: -2, urgentLowLimitInMgDl: 70, lowLimitInMgDl: 80, highLimitInMgDl: 140, urgentHighLimitInMgDl: 180)
    
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

