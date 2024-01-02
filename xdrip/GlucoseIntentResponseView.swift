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
        let domain = min(readings.map(\.valueInUserUnits).min() ?? Double.greatestFiniteMagnitude, 70 * unitFactor) ... max(readings.map(\.valueInUserUnits).max() ?? -Double.greatestFiniteMagnitude, 180 * unitFactor)
        Chart {
            if domain.contains(UserDefaults.standard.urgentLowMarkValueInUserChosenUnit) {
                RuleMark(y: .value("", UserDefaults.standard.urgentLowMarkValueInUserChosenUnit))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [1, 3]))
                    .foregroundStyle(.red)
            }
            if domain.contains(UserDefaults.standard.urgentLowMarkValueInUserChosenUnit) {
                RuleMark(y: .value("", UserDefaults.standard.urgentLowMarkValueInUserChosenUnit))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [1, 3]))
                    .foregroundStyle(.red)
            }

            if domain.contains(UserDefaults.standard.lowMarkValueInUserChosenUnit) {
                RuleMark(y: .value("", UserDefaults.standard.lowMarkValueInUserChosenUnit))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 4]))
                    .foregroundStyle(.yellow)
            }
            if domain.contains(UserDefaults.standard.highMarkValueInUserChosenUnit) {
                RuleMark(y: .value("", UserDefaults.standard.highMarkValueInUserChosenUnit))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 4]))
                    .foregroundStyle(.yellow)
            }

            if domain.contains(UserDefaults.standard.targetMarkValueInUserChosenUnit) {
                RuleMark(y: .value("", UserDefaults.standard.targetMarkValueInUserChosenUnit))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 8]))
                    .foregroundStyle(.green)
            }

            ForEach(readings, id: \.timeStamp) { reading in
                PointMark(x: .value("Time", reading.timeStamp),
                          y: .value("BG", reading.valueInUserUnits))
                    .symbol(Circle())
                    .foregroundStyle(symbolColor(value: reading.calculatedValue))
            }
        }
        .chartXAxis {
            AxisMarks {
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
            AxisMarks(values: axisTicks(for: domain)) { value in
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(v.formatted(.number.precision(.significantDigits(UserDefaults.standard.bloodGlucoseUnitIsMgDl ? 0 : 1))))
                            .font(.caption2)
                    }

                    if !userValues.contains(v) {
                        AxisValueLabel()
                            .foregroundStyle(Color.white)
                        AxisGridLine()
                            .foregroundStyle(Color.white)
                    }
                }
            }
        }
        .chartYScale(domain: domain)
        .aspectRatio(1.5, contentMode: .fit)
        .padding()
        .background {
            Color(red: 0.18, green: 0.18, blue: 0.19) // Match: this will match how Siri presents the response dialog in dark mode
        }
    }
}

extension BgReading {
    var valueInUserUnits: Double {
        calculatedValue * unitFactor
    }
}

private var unitFactor: Double {
    UserDefaults.standard.bloodGlucoseUnitIsMgDl ? 1 : ConstantsBloodGlucose.mgDlToMmoll
}

private var userValues = [UserDefaults.standard.urgentLowMarkValueInUserChosenUnit,
                          UserDefaults.standard.lowMarkValueInUserChosenUnit,
                          UserDefaults.standard.targetMarkValueInUserChosenUnit,
                          UserDefaults.standard.highMarkValueInUserChosenUnit,
                          UserDefaults.standard.urgentHighMarkValueInUserChosenUnit]

private func axisTicks(for domain: ClosedRange<Double>) -> [Double] {
    var values = [70, 180, 250].map { $0 * unitFactor }.filter { domain.contains($0) }
    for v in userValues where domain.contains(v) {
        if values.filter({ abs(v - $0) < 9.9 }).isEmpty {
            values.append(v)
        }
    }
    return values
}

extension [Double] {
    var range: ClosedRange<Double> {
        (self.min() ?? -Double.greatestFiniteMagnitude) ... (self.max() ?? Double.greatestFiniteMagnitude)
    }
}
