//
//  SystemLargeView.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

extension XDripWidget.EntryView {
    var systemLargeView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("\(entry.widgetState.bgValueStringInUserChosenUnit)\(entry.widgetState.trendArrow())")
                    .font(.largeTitle).fontWeight(.semibold)
                    .foregroundStyle(entry.widgetState.bgTextColor())
                    .scaledToFill()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                        .font(.title).fontWeight(.bold)
                        .foregroundStyle(Color(white: 0.9))
                        .lineLimit(1)
                    Text(entry.widgetState.bgUnitString)
                        .font(.title)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 6)
            
            GlucoseChartView(glucoseChartType: .widgetSystemLarge, bgReadingValues: entry.widgetState.bgReadingValues, bgReadingDates: entry.widgetState.bgReadingDates, isMgDl: entry.widgetState.isMgDl, urgentLowLimitInMgDl: entry.widgetState.urgentLowLimitInMgDl, lowLimitInMgDl: entry.widgetState.lowLimitInMgDl, highLimitInMgDl: entry.widgetState.highLimitInMgDl, urgentHighLimitInMgDl: entry.widgetState.urgentHighLimitInMgDl, liveActivitySize: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil)
            
            HStack {
                Spacer()
                
                Text("Updated at \(entry.widgetState.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                    .font(.caption).bold()
                    .foregroundStyle(Color(white: 0.6))
            }
        }
        .widgetBackground(backgroundView: Color.black)
    }
}

