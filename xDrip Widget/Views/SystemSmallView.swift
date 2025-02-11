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
                    Text("\(entry.widgetState.bgValueStringInUserChosenUnit())\(entry.widgetState.trendArrow())")
                        .font(.title).fontWeight(.bold)
                        .foregroundStyle(entry.widgetState.bgTextColor())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer()
                    
                    if let deviceStatusIconImage = entry.widgetState.deviceStatusIconImage(), let deviceStatusColor = entry.widgetState.deviceStatusColor() {
                        deviceStatusIconImage
                            .font(.body).bold()
                            .foregroundStyle(deviceStatusColor)
                    } else {
                        Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                            .font(.title2).fontWeight(.semibold)
                            .foregroundStyle(entry.widgetState.deltaChangeTextColor())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
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
                // if the time is at night (and the user has selected the relevant option), then we'll force a high
                // contrast view which will render nicely in red with the StandBy Night Mode
                
                // we'll also check if the user is requesting the "big number view" in standby mode
                if !entry.widgetState.forceStandByBigNumbers {
                    // this is the standard standby view
                    HStack(alignment: .center) {
                        Text("\(entry.widgetState.bgValueStringInUserChosenUnit())\(entry.widgetState.trendArrow())")
                            .font(.largeTitle).fontWeight(.bold)
                            .foregroundStyle(isAtNight() ? .white : entry.widgetState.bgTextColor())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer()
                        
                        if let deviceStatusIconImage = entry.widgetState.deviceStatusIconImage(), let deviceStatusColor = entry.widgetState.deviceStatusColor() {
                            deviceStatusIconImage
                                .font(.title3).bold()
                                .foregroundStyle(isAtNight() ? .white : deviceStatusColor)
                        } else {
                            Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                                .font(.title2).fontWeight(.bold)
                                .foregroundStyle(isAtNight() ? .white : entry.widgetState.deltaChangeTextColor())
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                    .padding(.top, 0)
                    .padding(.bottom, 2)
                    
                    GlucoseChartView(glucoseChartType: .widgetSystemSmallStandBy, bgReadingValues: entry.widgetState.bgReadingValues, bgReadingDates: entry.widgetState.bgReadingDates, isMgDl: entry.widgetState.isMgDl, urgentLowLimitInMgDl: entry.widgetState.urgentLowLimitInMgDl, lowLimitInMgDl: entry.widgetState.lowLimitInMgDl, highLimitInMgDl: entry.widgetState.highLimitInMgDl, urgentHighLimitInMgDl: entry.widgetState.urgentHighLimitInMgDl, liveActivityType: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: isAtNight())
                    
                } else {
                    // this is the "big number" standby view
                    VStack(alignment: .center, spacing: -10) {
                        Text(entry.widgetState.bgValueStringInUserChosenUnit())
                            .font(.system(size: 200)).fontWeight(.bold)
                            .foregroundStyle(isAtNight() ? .white : entry.widgetState.bgTextColor())
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                        
                        HStack(alignment: .center) {
                            Text(entry.widgetState.trendArrow())
                                .font(.largeTitle).fontWeight(.bold)
                                .foregroundStyle(isAtNight() ? .white : entry.widgetState.bgTextColor())
                            
                            Spacer()
                            
                            Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                                .font(.largeTitle).fontWeight(.bold)
                                .foregroundStyle(isAtNight() ? .white : entry.widgetState.deltaChangeTextColor())
                            
                            if let deviceStatusIconImage = entry.widgetState.deviceStatusIconImage(), let deviceStatusColor = entry.widgetState.deviceStatusColor() {
                                Spacer()
                                
                                deviceStatusIconImage
                                    .font(.title2).bold()
                                    .foregroundStyle(isAtNight() ? .white : deviceStatusColor)
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)
                    }
                }
            }
        }
        .widgetBackground(backgroundView: Color.black)
    }
}
