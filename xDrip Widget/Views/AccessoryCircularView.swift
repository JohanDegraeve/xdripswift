//
//  AccessoryCircularView.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI
import WidgetKit

extension XDripWidget.EntryView {
    var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
                .cornerRadius(8)
            
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
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.2)
            } maximumValueLabel: {
                Text(entry.widgetState.gaugeModel().maxValue.mgDlToMmolAndToString(mgDl: entry.widgetState.isMgDl))
                    .font(.system(size: 8))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.2)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(entry.widgetState.gaugeModel().gaugeGradient)
        }
        .widgetBackground(backgroundView: Color.black)
    }
}
