//
//  LiveActivityContentActivityFamiliesView.swift
//  xdrip
//
//  Created by Paul Plant on 29/7/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import SwiftUI
import WidgetKit

// this is the newer live activity view which is used for >=iOS18 and uses the activity family to
// correctly show the view in Smart Stack and CarPlay if possible (>=iOS26)
@available(iOS 18.0, *)
struct LiveActivityViewContentActivityFamilies: View {
    @Environment(\.widgetFamily) var activityFamily
    @State var context: ActivityViewContext<XDripWidgetAttributes>
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                VStack(spacing: 3) {
                    HStack(alignment: .center) {
                        HStack(alignment: .center, spacing: 3) {
                            Text("\(context.state.bgValueStringInUserChosenUnit())\(context.state.trendArrow()) ")
                                .font(.headline)
                                .foregroundStyle(context.state.bgTextColor())
                            
                            Text(context.state.deltaChangeStringInUserChosenUnit())
                                .font(.subheadline)
                                .foregroundStyle(context.state.deltaChangeTextColor())
                                .lineLimit(1)
                        }
                        .padding(.leading, 10)
                        
                        Spacer()
                        
                        Text("\(context.state.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                            .font(.subheadline)
                            .foregroundStyle(.colorTertiary)
                            .minimumScaleFactor(0.2)
                            .padding(.trailing, 10)
                    }
                    .padding(.top, 4)
                    
                    GlucoseChartView(
                        glucoseChartType: .watchAccessoryRectangular,
                        bgReadingValues: context.state.bgReadingValues,
                        bgReadingDates: context.state.bgReadingDates,
                        isMgDl: context.state.isMgDl,
                        urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl,
                        lowLimitInMgDl: context.state.lowLimitInMgDl,
                        highLimitInMgDl: context.state.highLimitInMgDl,
                        urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl,
                        liveActivityType: nil,
                        hoursToShowScalingHours: 4,
                        glucoseCircleDiameterScalingHours: 5,
                        overrideChartHeight: min(activityFamily.toSidebarRowSize == .small ? ConstantsGlucoseChartSwiftUI.viewHeightWatchAccessoryRectangularSmall : ConstantsGlucoseChartSwiftUI.viewHeightWatchAccessoryRectangular, geo.size.height * 0.55),
                        overrideChartWidth: geo.size.width - 20,
                        highContrast: nil
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        
    }
}

// MARK: - extensions
extension WidgetFamily {
    var toSidebarRowSize: SidebarRowSize {
        switch self {
        case .systemSmall:  return .small
        case .systemMedium: return .medium
        case .systemLarge:  return .large
        default:            return .medium
        }
    }
}
