//
//  GlucoseIntentResponseView.swift
//  xdrip
//
//  Created by Guy Shaviv on 29/12/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

@available(iOS 16, *)
struct GlucoseIntentResponseView: View {
    let readings: [BgReading]

    func symbolColor(value: Double) -> Color {
        switch value {
        case ..<UserDefaults.standard.urgentLowMarkValue:
            .red
        case UserDefaults.standard.urgentLowMarkValue..<UserDefaults.standard.lowMarkValue:
            .yellow
        case UserDefaults.standard.highMarkValue..<UserDefaults.standard.urgentHighMarkValue:
            .yellow
        case UserDefaults.standard.urgentHighMarkValue...:
            .red
        default:
            .green
        }
    }

    var body: some View {
        Chart {
            ForEach(readings, id: \.timeStamp) { reading in
                PointMark(x: .value("Time", reading.timeStamp),
                          y: .value("BG", reading.valueInUserUnits))
                    .symbol(Circle())
                    .foregroundStyle(symbolColor(value: reading.calculatedValue))
            }
        }
        .chartXAxis {
            AxisMarks() {
                if let v = $0.as(Date.self) {
                    AxisValueLabel {
                        Text(v.formatted(.dateTime.hour()))
                            .foregroundStyle(Color.white)
                    }
                    AxisGridLine()
                        .foregroundStyle(Color.gray)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [UserDefaults.standard.urgentLowMarkValueInUserChosenUnit,
                               UserDefaults.standard.lowMarkValueInUserChosenUnit,
                               UserDefaults.standard.targetMarkValueInUserChosenUnit,
                               UserDefaults.standard.highMarkValueInUserChosenUnit,
                               UserDefaults.standard.urgentHighMarkValueInUserChosenUnit]) {
                AxisValueLabel()
                    .foregroundStyle(Color.white)
                AxisGridLine()
                    .foregroundStyle(Color.white)
            }
        }
        .chartYScale(domain:
            min(readings.map(\.valueInUserUnits).min() ?? Double.greatestFiniteMagnitude, UserDefaults.standard.urgentLowMarkValueInUserChosenUnit) ... max(readings.map(\.valueInUserUnits).max() ?? -Double.greatestFiniteMagnitude, UserDefaults.standard.urgentHighMarkValueInUserChosenUnit)
        )
        .aspectRatio(1.5, contentMode: .fit)
        .padding()
        .background {
            Color(red: 0.18, green: 0.18, blue: 0.19) // Match: this will match how Siri presents the response dialog in dark mode
        }
    }
}

extension BgReading {
    var valueInUserUnits: Double {
        UserDefaults.standard.bloodGlucoseUnitIsMgDl ? calculatedValue : calculatedValue * ConstantsBloodGlucose.mgDlToMmoll
    }
}
