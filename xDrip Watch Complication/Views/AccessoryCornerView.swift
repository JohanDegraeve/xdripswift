//
//  AccessoryCornerView.swift
//  xDrip Watch Complication Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

extension XDripWatchComplication.EntryView {
    @ViewBuilder
    var accessoryCornerView: some View {
        if !entry.widgetState.keepAliveIsDisabled && entry.widgetState.liveDataIsEnabled {
            Text("\(entry.widgetState.bgValueStringInUserChosenUnit)\(entry.widgetState.trendArrow())")
                .font(.system(size: 20))
                .foregroundColor(entry.widgetState.bgTextColor())
                .minimumScaleFactor(0.2)
                .widgetCurvesContent()
                .widgetLabel {
                    Gauge(value: entry.widgetState.bgValueInMgDl ?? entry.widgetState.gaugeModel().nilValue, in: entry.widgetState.gaugeModel().minValue...entry.widgetState.gaugeModel().maxValue) {
                        Text("Not shown")
                    } currentValueLabel: {
                        Text("Not shown")
                    } minimumValueLabel: {
                        Text(entry.widgetState.gaugeModel().minValue.mgDlToMmolAndToString(mgDl: entry.widgetState.isMgDl))
                            .font(.system(size: 8))
                            .foregroundStyle(.colorPrimary)
                            .minimumScaleFactor(0.2)
                    } maximumValueLabel: {
                        Text(entry.widgetState.gaugeModel().maxValue.mgDlToMmolAndToString(mgDl: entry.widgetState.isMgDl))
                            .font(.system(size: 8))
                            .foregroundStyle(.colorPrimary)
                            .minimumScaleFactor(0.2)
                    }
                    .tint(entry.widgetState.gaugeModel().gaugeGradient)
                    .gaugeStyle(LinearCapacityGaugeStyle()) // Doesn't do anything
                }
                .widgetBackground(backgroundView: Color.clear)
        } else {
            Text(" ")
                .font(.system(size: 20))
                .minimumScaleFactor(0.2)
                .widgetCurvesContent()
                .widgetLabel("\(ConstantsHomeView.applicationName)")
                .widgetBackground(backgroundView: Color.clear)
        }
    }
}

