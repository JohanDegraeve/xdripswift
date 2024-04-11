//
//  AccessoryRectangularView.swift
//  xDrip Widget Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI
import WidgetKit

extension XDripWidget.EntryView {
    var accessoryRectangularView: some View {
        ZStack {
            AccessoryWidgetBackground()
                .cornerRadius(8)
            Text("\(entry.widgetState.bgValueStringInUserChosenUnit)\(entry.widgetState.trendArrow())")
                .font(.system(size: 50)).bold()
                .minimumScaleFactor(0.2)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .widgetBackground(backgroundView: Color.black)
    }
}

