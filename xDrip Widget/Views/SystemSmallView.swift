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
            
            GlucoseChartView(glucoseChartType: .widgetSystemSmall, bgReadingValues: entry.widgetState.bgReadingValues, bgReadingDates: entry.widgetState.bgReadingDates, isMgDl: entry.widgetState.isMgDl, urgentLowLimitInMgDl: entry.widgetState.urgentLowLimitInMgDl, lowLimitInMgDl: entry.widgetState.lowLimitInMgDl, highLimitInMgDl: entry.widgetState.highLimitInMgDl, urgentHighLimitInMgDl: entry.widgetState.urgentHighLimitInMgDl, liveActivitySize: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil)
            
            HStack {
                Text(entry.widgetState.dataSourceDescription)
                    .font(.system(size: 11)).bold()
                    .foregroundStyle(Color(white: 0.8))
                
                Spacer()
                
                Text("\(entry.widgetState.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.6))
            }
        }
        .widgetBackground(backgroundView: Color.black)
    }
}
