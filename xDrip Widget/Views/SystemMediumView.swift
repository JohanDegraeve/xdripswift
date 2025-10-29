//
//  SystemMediumView.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

extension XDripWidget.EntryView {
    var systemMediumView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("\(entry.widgetState.bgValueStringInUserChosenUnit()) \(entry.widgetState.trendArrow())")
                    .font(.title).fontWeight(.bold)
                    .foregroundStyle(entry.widgetState.bgTextColor())
                    .scaledToFill()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(alignment: .center, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                            .font(.title2).fontWeight(.semibold)
                            .foregroundStyle(entry.widgetState.deltaChangeTextColor())
                            .lineLimit(1)
                        
                        Text(entry.widgetState.bgUnitString)
                            .font(.title2)
                            .foregroundStyle(.colorTertiary)
                            .lineLimit(1)
                    }
                    
                    if let deviceStatusIconImage = entry.widgetState.deviceStatusIconImage(), let deviceStatusColor = entry.widgetState.deviceStatusColor() {
                        deviceStatusIconImage
                            .font(.headline).bold()
                            .foregroundStyle(deviceStatusColor)
                    }
                }
            }
            .padding(.top, -6)
            .padding(.bottom, 6)
            
            GlucoseChartView(glucoseChartType: .widgetSystemMedium, bgReadingValues: entry.widgetState.bgReadingValues, bgReadingDates: entry.widgetState.bgReadingDates, isMgDl: entry.widgetState.isMgDl, urgentLowLimitInMgDl: entry.widgetState.urgentLowLimitInMgDl, lowLimitInMgDl: entry.widgetState.lowLimitInMgDl, highLimitInMgDl: entry.widgetState.highLimitInMgDl, urgentHighLimitInMgDl: entry.widgetState.urgentHighLimitInMgDl, liveActivityType: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: nil)
            
            HStack(alignment: .center) {
                // if we're in follower mode and a patient name exists, let's use it with preference over the data source
                Text(entry.widgetState.followerPatientName ?? entry.widgetState.dataSourceDescription)
                    .font(.caption).bold()
                    .foregroundStyle(.colorSecondary)
                
                Spacer()
                
                Text("Last reading at \(entry.widgetState.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                    .font(.caption)
                    .foregroundStyle(.colorSecondary)
            }
            .padding(.top, 6)
        }
        .widgetBackground(backgroundView: Color.black)
    }
}
