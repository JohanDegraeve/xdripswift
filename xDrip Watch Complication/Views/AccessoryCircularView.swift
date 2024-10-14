//
//  AccessoryCircularView.swift
//  xDrip Watch Complication Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

extension XDripWatchComplication.EntryView {
    @ViewBuilder
    var accessoryCircularView: some View {
        if !entry.widgetState.keepAliveIsDisabled && entry.widgetState.liveDataIsEnabled {
            Gauge(value: entry.widgetState.bgValueInMgDl ?? entry.widgetState.gaugeModel().nilValue, in: entry.widgetState.gaugeModel().minValue...entry.widgetState.gaugeModel().maxValue) {
                Text("Not shown")
            } currentValueLabel: {
                Text(entry.widgetState.bgValueStringInUserChosenUnit)
                    .font(.system(size: 20)).bold()
                    .minimumScaleFactor(0.2)
                    .lineLimit(1)
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
            .gaugeStyle(.accessoryCircular)
            .tint(entry.widgetState.gaugeModel().gaugeGradient)
            .widgetBackground(backgroundView: Color.clear)
        } else {
            Image("ComplicationIcon")
                .resizable()
                .widgetBackground(backgroundView: Color.clear)
        }
    }
}
