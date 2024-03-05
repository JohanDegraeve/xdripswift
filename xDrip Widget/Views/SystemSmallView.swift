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
            HStack {
                Text("\(entry.widgetState.bgValueStringInUserChosenUnit)\(entry.widgetState.trendArrow())")
                    .font(.title).fontWeight(.semibold)
                    .foregroundStyle(entry.widgetState.bgTextColor())
                    .scaledToFill()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(Color(white: 0.9))
                        .lineLimit(1)
                        .padding(.bottom, -3)
                    Text(entry.widgetState.bgUnitString)
                        .font(.footnote)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }
            .padding(.top, -6)
            .padding(.bottom, 6)
            
            GlucoseChartView(glucoseChartType: .widgetSystemSmall, bgReadingValues: entry.widgetState.bgReadingValues, bgReadingDates: entry.widgetState.bgReadingDates, isMgDl: entry.widgetState.isMgDl, urgentLowLimitInMgDl: entry.widgetState.urgentLowLimitInMgDl, lowLimitInMgDl: entry.widgetState.lowLimitInMgDl, highLimitInMgDl: entry.widgetState.highLimitInMgDl, urgentHighLimitInMgDl: entry.widgetState.urgentHighLimitInMgDl, liveActivitySize: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil)
            
            HStack {
                Spacer()
                
                Text("Last reading \(entry.widgetState.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                    .font(.caption).bold()
                    .minimumScaleFactor(0.2)
                    .foregroundStyle(Color(white: 0.6))
            }
        }
        .widgetBackground(backgroundView: Color.black)
    }
}
