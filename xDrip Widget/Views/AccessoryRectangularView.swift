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
            
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Text("\(entry.widgetState.bgValueStringInUserChosenUnit)\(entry.widgetState.trendArrow())")
                            .font(.system(size: 30)).fontWeight(.semibold)
                            .foregroundStyle(Color(white: 1))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(entry.widgetState.deltaChangeStringInUserChosenUnit())
                            .font(.system(size: 30)).fontWeight(.semibold)
                            .foregroundStyle(Color(white: 0.8))
                            .lineLimit(1)
                    }
                
                    Spacer()
                    
                    Text("Last reading \(entry.widgetState.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.6))
                }
                .padding(6)
        }
        .widgetBackground(backgroundView: Color.black)
    }
}

