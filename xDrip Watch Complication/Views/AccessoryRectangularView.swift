//
//  AccessoryRectangularView.swift
//  xDrip Watch Complication Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

extension XDripWatchComplication.EntryView {
    @ViewBuilder
    var accessoryRectangularView: some View {
        if !entry.widgetState.disableComplications {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(entry.widgetState.bgValueStringInUserChosenUnit)\(entry.widgetState.trendArrow()) ")
                            .font(.system(size: 24)).bold()
                            .foregroundStyle(entry.widgetState.bgTextColor())
                        
                        Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                            .font(.system(size: 24)).bold()
                            .foregroundStyle(Color(white: 0.9))
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text(entry.widgetState.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(white: 0.6))
                        .minimumScaleFactor(0.2)
                }
                .padding(0)
                
                GlucoseChartView(glucoseChartType: .watchAccessoryRectangular, bgReadingValues: entry.widgetState.bgReadingValues, bgReadingDates: entry.widgetState.bgReadingDates, isMgDl: entry.widgetState.isMgDl, urgentLowLimitInMgDl: entry.widgetState.urgentLowLimitInMgDl, lowLimitInMgDl: entry.widgetState.lowLimitInMgDl, highLimitInMgDl: entry.widgetState.highLimitInMgDl, urgentHighLimitInMgDl: entry.widgetState.urgentHighLimitInMgDl, liveActivitySize: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil)
            }
            .widgetBackground(backgroundView: Color.clear)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(ConstantsHomeView.applicationName)
                    .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                    
                    Text("Enable background keep-alive")
                        .font(.system(size: 16))
                }
                .foregroundStyle(.yellow)
                .padding(2)
            }
            .widgetBackground(backgroundView: Color.clear)
        }
    }
}
