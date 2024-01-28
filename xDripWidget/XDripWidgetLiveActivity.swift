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

@available(iOSApplicationExtension 16.2, *)
struct XDripWidgetLiveActivity: Widget {
    
    var body: some WidgetConfiguration {
        
        ActivityConfiguration(for: XDripWidgetAttributes.self) { context in
            
            // Lock screen/banner UI goes here
            
            if context.state.liveActivityNotificationSizeTypeAsInt == 0 {
                
                // 0 = normal size chart
                HStack(spacing: 20) {
                    VStack {
                        Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                            .font(.system(size: 50)).bold()
                            .foregroundStyle(context.state.getBgColor())
                            .minimumScaleFactor(0.1)
                            .lineLimit(1)
                        
                        context.state.deltaChangeFormatted(font: .title2)
                            .minimumScaleFactor(0.1)
                            .lineLimit(1)
                    }
                    .padding(4)
                    
//                    ZStack {
                        GlucoseChartView(bgReadingValues: context.state.bgReadingValues, bgReadingDates: context.state.bgReadingDates, glucoseChartWidgetType: .liveActivityNotification, isMgDl: context.state.isMgDl, urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl, lowLimitInMgDl: context.state.lowLimitInMgDl, highLimitInMgDl: context.state.highLimitInMgDl, urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl, liveActivityNotificationSizeType: LiveActivityNotificationSizeType(rawValue: context.state.liveActivityNotificationSizeTypeAsInt) ?? .normal)
                        
                        //Text(context.attributes.eventStartDate.formatted(date: .omitted, time: .shortened))
                        
                        /*
                        if context.state.remindUserToOpenApp(eventStartDate: context.attributes.eventStartDate) {
                            VStack(alignment: .center) {
                                Spacer()
                                Text("Please open xDrip4iOS")
                                    .font(.caption)
                                    .minimumScaleFactor(0.1)
                                    .foregroundStyle(.black)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                    .background(Color(white: 0.8, opacity: 0.8))
                                    .cornerRadius(15)
                                Spacer()
                            }
                            .padding(8)
                        }
                         */
//                    }
                }
                .activityBackgroundTint(.black)
                .padding(6)
                
            } else if context.state.liveActivityNotificationSizeTypeAsInt == 1 {
                
                // 1 = minimal widget with no chart
                
                HStack(alignment: .center) {
                    
                    Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                        .font(.largeTitle).bold()
                        .foregroundStyle(context.state.getBgColor())
                        .minimumScaleFactor(0.1)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    context.state.deltaChangeFormatted(font: .title)
                        .minimumScaleFactor(0.1)
                        .lineLimit(1)
                }
                .activityBackgroundTint(.black)
                .padding(15)
                
            } else {
                
                // 2 = large chart
                
                ZStack {
                    
                    GlucoseChartView(bgReadingValues: context.state.bgReadingValues, bgReadingDates: context.state.bgReadingDates, glucoseChartWidgetType: .liveActivityNotification, isMgDl: context.state.isMgDl, urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl, lowLimitInMgDl: context.state.lowLimitInMgDl, highLimitInMgDl: context.state.highLimitInMgDl, urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl, liveActivityNotificationSizeType: LiveActivityNotificationSizeType(rawValue: context.state.liveActivityNotificationSizeTypeAsInt) ?? .normal)
                    
                    //Text(context.attributes.eventStartDate.formatted(date: .omitted, time: .shortened))
                    
                    VStack {
                        
                        if context.state.placeTextAtBottomOfWidget(glucoseChartWidgetType: .liveActivityNotification) {
                            Spacer()
                        }
                        
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow()) ")
                                .font(.title2).bold()
                                .foregroundStyle(context.state.getBgColor())
                            
                            context.state.deltaChangeFormatted(font: .title3)
                        }
                        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .background(Color(white: 0, opacity: 0.7))
                        .cornerRadius(20)
                        
                        if !context.state.placeTextAtBottomOfWidget(glucoseChartWidgetType: .liveActivityNotification) {
                            Spacer()
                        }
                        
                        //                    if let bgTitle = state.getBgTitle() {
                        //                        Text(bgTitle)
                        //                            .foregroundStyle(state.getBgColor())
                        //                            .font(.subheadline).bold()
                        //                            .multilineTextAlignment(.center)
                        //                    }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    /*
                    if context.state.remindUserToOpenApp(eventStartDate: context.attributes.eventStartDate) {
                        VStack(alignment: .center) {
                            Spacer()
                            Text("Live activity ending soon\nPlease open xDrip4iOS")
                                .font(.footnote).bold()
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.center)
                                .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                                .background(Color(white: 0.8, opacity: 0.8))
                                .cornerRadius(15)
                            Spacer()
                        }
                    }
                    */
                    
                }
                .activityBackgroundTint(.black)
            }
            
        } dynamicIsland: { context in
            
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {                    Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                        .font(.largeTitle).bold()
                        .foregroundStyle(context.state.getBgColor())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .minimumScaleFactor(0.1)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    context.state.deltaChangeFormatted(font: .title)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    
                    GlucoseChartView(bgReadingValues: context.state.bgReadingValues, bgReadingDates: context.state.bgReadingDates, glucoseChartWidgetType: .dynamicIsland, isMgDl: context.state.isMgDl, urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl, lowLimitInMgDl: context.state.lowLimitInMgDl, highLimitInMgDl: context.state.highLimitInMgDl, urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl, liveActivityNotificationSizeType: LiveActivityNotificationSizeType(rawValue: context.state.liveActivityNotificationSizeTypeAsInt) ?? .normal)
                    
                }
            } compactLeading: {
                Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                    .foregroundStyle(context.state.getBgColor())
                    .minimumScaleFactor(0.1)
            } compactTrailing: {
                Text(context.state.getDeltaChangeStringInUserChosenUnit())
                    .minimumScaleFactor(0.1)
            } minimal: {
                Text(context.state.bgValueStringInUserChosenUnit)
                    .foregroundStyle(context.state.getBgColor())
                    .minimumScaleFactor(0.1)
            }
            .widgetURL(URL(string: "xdripswift"))
            .keylineTint(context.state.getBgColor())
        }
        
    }
    
}

//@available(iOSApplicationExtension 16.2, *)
//struct LiveActivityView: View {
//    
//    let state: XDripWidgetAttributes.ContentState
//    let glucoseChartWidgetType: GlucoseChartWidgetType = .liveActivityNotification
//    
//    var body: some View {
//    }
//}

@available(iOS 16.2, *)
struct XDripWidgetLiveActivity_Previews: PreviewProvider {
    
    static func bgDateArray() -> [Date] {
        
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-3600 * 12)
        var currentDate = startDate
        
        var dateArray: [Date] = []
        
        while currentDate < endDate {
            dateArray.append(currentDate)
            currentDate = currentDate.addingTimeInterval(60 * 5)
        }
        
        return dateArray
    }
    
    static func bgValueArray() -> [Double] {
        
        var bgValueArray:[Double] = Array(repeating: 0, count: 144)
        var currentValue: Double = 100
        var increaseValues: Bool = true
        
        for index in bgValueArray.indices {
            
            let randomValue = Double(Int.random(in: -10..<10))
            
            if currentValue < 80 {
                increaseValues = true
                bgValueArray[index] = currentValue + abs(randomValue)
            } else if currentValue > 160 {
                increaseValues = false
                bgValueArray[index] = currentValue - abs(randomValue)
            } else {
                bgValueArray[index] = currentValue + (increaseValues ? randomValue : -randomValue)
            }
            currentValue = bgValueArray[index]
        }
        
        return bgValueArray
        
    }
    
    
    static let attributes = XDripWidgetAttributes() //(eventStartDate: Date().addingTimeInterval(-1000))
    
    static let contentState = XDripWidgetAttributes.ContentState(bgReadingValues: bgValueArray(), bgReadingDates: bgDateArray(), isMgDl: true, slopeOrdinal:5, deltaChangeInMgDl: -2, urgentLowLimitInMgDl: 70, lowLimitInMgDl: 80, highLimitInMgDl: 140, urgentHighLimitInMgDl: 180, updatedDate: Date(), liveActivityNotificationSizeTypeAsInt: 0)
    
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

