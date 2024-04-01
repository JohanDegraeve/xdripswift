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
        ZStack {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    HStack(alignment: .center, spacing: 4) {
                        Text("\(entry.widgetState.bgValueStringInUserChosenUnit)\(entry.widgetState.trendArrow()) ")
                            .font(.system(size: entry.widgetState.isSmallScreen() ? 20 : 24)).bold()
                            .foregroundStyle(entry.widgetState.bgTextColor())
                        
                        Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                            .font(.system(size: entry.widgetState.isSmallScreen() ? 20 : 24)).fontWeight(.semibold)
                            .foregroundStyle(entry.widgetState.deltaChangeTextColor())
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text("\(entry.widgetState.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                        .font(.system(size: entry.widgetState.isSmallScreen() ? 14 : 16))
                        .foregroundStyle(Color(white: 0.7))
                        .minimumScaleFactor(0.2)
                }
                .padding(0)
                
                GlucoseChartView(glucoseChartType: .watchAccessoryRectangular, bgReadingValues: entry.widgetState.bgReadingValues, bgReadingDates: entry.widgetState.bgReadingDates, isMgDl: entry.widgetState.isMgDl, urgentLowLimitInMgDl: entry.widgetState.urgentLowLimitInMgDl, lowLimitInMgDl: entry.widgetState.lowLimitInMgDl, highLimitInMgDl: entry.widgetState.highLimitInMgDl, urgentHighLimitInMgDl: entry.widgetState.urgentHighLimitInMgDl, liveActivitySize: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: entry.widgetState.overrideChartHeight(), overrideChartWidth: entry.widgetState.overrideChartWidth())
                
                if entry.widgetState.disableComplications {
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: entry.widgetState.isSmallScreen() ? 12 : 14))
                        
                        Text("Keep-alive disabled")
                            .font(.system(size: entry.widgetState.isSmallScreen() ? 12 : 14))
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.teal)
                    .padding(0)
                }
            }
        }
        .widgetBackground(backgroundView: Color.clear)
    }
}
