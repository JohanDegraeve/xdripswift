//
//  SystemSmallView.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

extension XDripWidget.EntryView {
    var systemSmallView: some View {
        VStack(spacing: 0) {
            if isNotBeingUsedInStandByMode {
                
                // this is the standard widget view
                HStack(alignment: .center) {
                    Text("\(entry.widgetState.bgValueStringInUserChosenUnit)\(entry.widgetState.trendArrow())")
                        .font(.title).fontWeight(.bold)
                        .foregroundStyle(entry.widgetState.bgTextColor())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                        .font(.title).fontWeight(.semibold)
                        .foregroundStyle(entry.widgetState.deltaChangeTextColor())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .padding(.top, -6)
                .padding(.bottom, 6)
                
                GlucoseChartView(glucoseChartType: .widgetSystemSmall, bgReadingValues: entry.widgetState.bgReadingValues, bgReadingDates: entry.widgetState.bgReadingDates, isMgDl: entry.widgetState.isMgDl, urgentLowLimitInMgDl: entry.widgetState.urgentLowLimitInMgDl, lowLimitInMgDl: entry.widgetState.lowLimitInMgDl, highLimitInMgDl: entry.widgetState.highLimitInMgDl, urgentHighLimitInMgDl: entry.widgetState.urgentHighLimitInMgDl, liveActivityType: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: nil)
                
                HStack(alignment: .center) {
                    Text(entry.widgetState.dataSourceDescription)
                        .font(.caption).bold()
                        .foregroundStyle(.colorSecondary)
                    
                    Spacer()
                    
                    Text("\(entry.widgetState.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                        .font(.caption)
                        .foregroundStyle(.colorTertiary)
                }
                .padding(.top, 6)
                
            } else {
                
                // this is the simpler widget view to be used in StandBy mode - it has bigger fonts and less info
                // if the time is at night, then we'll force a high contrast view which will render
                // nicely in red with the StandBy Night Mode
                HStack(alignment: .center) {
                    Text("\(entry.widgetState.bgValueStringInUserChosenUnit)\(entry.widgetState.trendArrow())")
                        .font(.largeTitle).fontWeight(.bold)
                        .foregroundStyle(isAtNight() ? .white : entry.widgetState.bgTextColor())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                        .font(.title).fontWeight(.bold)
                        .foregroundStyle(isAtNight() ? .white : entry.widgetState.deltaChangeTextColor())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .padding(.top, 0)
                .padding(.bottom, 2)
                
                GlucoseChartView(glucoseChartType: .widgetSystemSmallStandBy, bgReadingValues: entry.widgetState.bgReadingValues, bgReadingDates: entry.widgetState.bgReadingDates, isMgDl: entry.widgetState.isMgDl, urgentLowLimitInMgDl: entry.widgetState.urgentLowLimitInMgDl, lowLimitInMgDl: entry.widgetState.lowLimitInMgDl, highLimitInMgDl: entry.widgetState.highLimitInMgDl, urgentHighLimitInMgDl: entry.widgetState.urgentHighLimitInMgDl, liveActivityType: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: isAtNight())
            }
        }
        .widgetBackground(backgroundView: Color.black)
    }
}
