//
//  BgReadingsDetailView.swift
//
//
//  Created by Paul Plant on 20/7/23.
//

import SwiftUI

struct BgReadingsDetailView: View {
    /// this must be passed in by the parent view
    let bgReading: BgReadingSnapshot
    
    // MARK: - private properties
    
    /// a common string to show in case a BgReading property is nil
    private let nilString = "-"

    /// is true if the user is using mg/dL units (pulled from UserDefaults)
    private let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
    
    // MARK: - SwiftUI views
    
    var body: some View {
        List {
            Section(header: Text(Texts_BgReadings.generalSectionHeader)) {
                row(title: Texts_BgReadings.deviceName, data: bgReading.deviceName ?? nilString)
                row(title: Texts_BgReadings.finalGlucose, data: displayBgValue(bgReading.finalValue), indicatorColor: bgRangeIndicatorColor(bgRangeDescription: bgReading.bgRangeDescription()))
                row(title: Texts_BgReadings.timestamp, data: bgReading.timeStamp.formatted(date: .abbreviated, time: .shortened))
            }
            
            Section(header: Text(Texts_BgReadings.slopeSectionHeader)) {
                row(title: Texts_BgReadings.slopeArrow, data: bgReading.slopeArrow())
                row(title: Texts_BgReadings.slopePerMinute, data: (bgReading.calculatedValueSlope.mgDlToMmol(mgDl: isMgDl) * 60000).formatted(.number.rounded(increment: isMgDl ? 0.01 : 0.001)) + " " + String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol))
                row(title: Texts_BgReadings.slopePer5Minutes, data: (bgReading.calculatedValueSlope.mgDlToMmol(mgDl: isMgDl) * 60000 * 5).formatted(.number.rounded(increment: isMgDl ? 0.01 : 0.001)) + " " + String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol))
            }
            
            if let calibration = bgReading.calibrationSnapshot {
                Section(header: Text(Texts_BgReadings.calibrationTitle)) {
                    row(title: Texts_BgReadings.id, data: calibration.id)
                    row(title: Texts_BgReadings.date, data: calibration.timeStamp.formatted(date: .abbreviated, time: .shortened))
                    row(title: Texts_BgReadings.slope, data: calibration.slope.formatted(.number.rounded(increment: 0.0001)))
                    row(title: Texts_BgReadings.intercept, data: calibration.intercept.formatted(.number.rounded(increment: 0.0001)))
                    row(title: Texts_BgReadings.calibrationValue, data: calibration.bg.bgValueToString(mgDl: true))
                    row(title: Texts_BgReadings.sensorRawValue, data: calibration.rawValue.bgValueToString(mgDl: true))
                }
            }
            
            Section(header: Text(Texts_BgReadings.glucoseValueSectionHeader)) {
                row(title: Texts_BgReadings.rawValue, data: displayBgValue(bgReading.rawData))
                row(title: Texts_BgReadings.calibratedValue, data: displayBgValue(bgReading.calculatedValue))
                row(title: Texts_BgReadings.adjustedValue, data: displayOptionalBgValue(bgReading.adjustedValue))
                row(title: Texts_BgReadings.smoothedValue, data: displayOptionalBgValue(bgReading.smoothedValue))
            }

            Section(header: Text(Texts_BgReadings.internalDataSectionHeader)) {
                row(title: Texts_BgReadings.rawData, data: bgReading.rawData.bgValueToString(mgDl: true))
                row(title: Texts_BgReadings.id, data: bgReading.id)
            }
        }
        .navigationTitle(Texts_BgReadings.glucoseReadingTitle)
    }
    
    // MARK: - private functions
    
    /// returns a row view so that all rows are the same
    /// - parameters:
    ///   - title: the title text
    ///   - data: the value text
    /// - returns:
    ///   - a view with the formatted row inside it
    private func row(title: String, data: String, indicatorColor: Color? = nil) -> AnyView {
        // wrap the HStack in an AnyView so that it can be returned back to the caller
        let rowView = AnyView(HStack {
            Text(title)
            
            Spacer()

            if let indicatorColor {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(indicatorColor)
            }
            
            Text(data)
                .foregroundColor(.secondary)
        })
        
        return rowView
    }

    private func displayBgValue(_ valueInMgDl: Double) -> String {
        return valueInMgDl.mgDlToMmol(mgDl: isMgDl).bgValueRounded(mgDl: isMgDl).bgValueToString(mgDl: isMgDl) + " " + String(isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
    }

    private func displayOptionalBgValue(_ valueInMgDl: Double?) -> String {
        guard let valueInMgDl = valueInMgDl else { return nilString }
        
        return displayBgValue(valueInMgDl)
    }

    private func bgRangeIndicatorColor(bgRangeDescription: BgRangeDescription) -> Color {
        switch bgRangeDescription {
        case .inRange:
            return Color(ConstantsGlucoseChart.glucoseInRangeColor)
        case .notUrgent:
            return Color(ConstantsGlucoseChart.glucoseNotUrgentRangeColor)
        case .urgent:
            return Color(ConstantsGlucoseChart.glucoseUrgentRangeColor)
        }
    }
}
