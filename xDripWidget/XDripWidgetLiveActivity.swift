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
            
            LiveActivityView(state: context.state)
            
        } dynamicIsland: { context in
            
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                        .font(.largeTitle)
                        .foregroundStyle(context.state.getBgColor())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.getBgTitle())
                        .font(.largeTitle)
                        .foregroundStyle(context.state.getBgColor())
                }
                //                DynamicIslandExpandedRegion(.center) {
                //                    EmptyView()
                //                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        HStack {
                            Text("\(context.state.getDeltaChangeStringInUserChosenUnit()) \(context.state.bgUnitString)")
                                .font(.title3)
                                .foregroundStyle(Color(white: 0.8))
                                .bold()
                            Spacer()
                            VStack {
                                Text("Reading \(context.state.bgReadingDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(white: 0.6))
                                    .bold()
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                Text("Updated \(context.state.updatedDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(white: 0.6))
                                    .bold()
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                            }
                        }
                    }
                }
            } compactLeading: {
                Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                    .foregroundStyle(context.state.getBgColor())
            } compactTrailing: {
                Text(context.state.getDeltaChangeStringInUserChosenUnit())
            } minimal: {
                Text(context.state.bgValueStringInUserChosenUnit)
                    .foregroundStyle(context.state.getBgColor())
            }
            .widgetURL(URL(string: "xdripswift"))
            .keylineTint(context.state.getBgColor())
        }
        
    }
    
}

struct LiveActivityView: View {
    
    let state: XDripWidgetAttributes.ContentState
    
    var body: some View {
        // Lock screen/banner UI goes here
        VStack {
            HStack {
                Text("\(state.bgValueStringInUserChosenUnit)\(state.trendArrow())")
                    .font(.largeTitle).bold()
                    .foregroundStyle(state.getBgColor())
                Spacer()
                Text(state.getBgTitle())
                    .font(.title).bold()
                    .foregroundStyle(state.getBgColor())
            }
            
            HStack {
                Text("\(state.getDeltaChangeStringInUserChosenUnit()) \(state.bgUnitString)")
                    .font(.title3)
                    .foregroundStyle(Color(white: 0.8))
                    .bold()
                Spacer()
                VStack {
                    Text("Reading \(state.bgReadingDate.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.6))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    .bold()
                    Text("Updated \(state.updatedDate.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.6))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    .bold()
                }
            }
        }
        .padding(15)
    }
}

//@available(iOS 16.2, *)
struct XDripWidgetLiveActivity_Previews: PreviewProvider {
    static let attributes = XDripWidgetAttributes(eventStartDate: Date().addingTimeInterval(-1000))
    static let contentState = XDripWidgetAttributes.ContentState(bgValueInMgDl: 252, isMgDl: true, slopeOrdinal:5, deltaChangeInMgDl: -2, urgentLowLimitInMgDl: 70, lowLimitInMgDl: 80, highLimitInMgDl: 140, urgentHighLimitInMgDl: 180, bgReadingDate: Date().addingTimeInterval(-180), updatedDate: Date())
    
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

