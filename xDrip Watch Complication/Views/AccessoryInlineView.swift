//
//  AccessoryInlineView.swift
//  xDrip Watch Complication Extension
//
//  Created by Paul Plant on 4/3/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

extension XDripWatchComplication.EntryView {
    @ViewBuilder
    var accessoryInlineView: some View {
        Text("\(entry.widgetState.bgValueStringInUserChosenUnit) \(entry.widgetState.trendArrow())  \(entry.widgetState.deltaChangeStringInUserChosenUnit())")
    }
}

