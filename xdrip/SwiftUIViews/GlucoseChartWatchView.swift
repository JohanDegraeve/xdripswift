//
//  GlucoseChartWatchView.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 11/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI
import Foundation

@available(iOS 16, *)
struct GlucoseChartWatchView: View {
    
    var bgReadingValues: [Double]
    var bgReadingDates: [Date]
    let isMgDl: Bool
    let urgentLowLimitInMgDl: Double
    let lowLimitInMgDl: Double
    let highLimitInMgDl: Double
    let urgentHighLimitInMgDl: Double
    
    init(bgReadingValues: [Double], bgReadingDates: [Date], isMgDl: Bool, urgentLowLimitInMgDl: Double, lowLimitInMgDl: Double, highLimitInMgDl: Double, urgentHighLimitInMgDl: Double) {
        
        // as all widget instances are passed 12 hours of bg values, we must initialize this instance to use only the amount of hours of value required by the glucoseChartType passed
        self.bgReadingValues = []
        self.bgReadingDates = []
        
        var index = 0
        
        for _ in bgReadingValues {
            if bgReadingDates[index] > Date().addingTimeInterval(-ConstantsGlucoseChartSwiftUI.hoursToShowLiveActivityNotificationNormal * 60 * 60) {
                self.bgReadingValues.append(bgReadingValues[index])
                self.bgReadingDates.append(bgReadingDates[index])
            }
            index += 1
        }
        
        self.isMgDl = isMgDl
        self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
        self.lowLimitInMgDl = lowLimitInMgDl
        self.highLimitInMgDl = highLimitInMgDl
        self.urgentHighLimitInMgDl = urgentHighLimitInMgDl
    }
    
    /// Blood glucose color dependant on the user defined limit values
    /// - Returns: a Color object either red, yellow or green
    func bgColor(bgValueInMgDl: Double) -> Color {
        if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
            return .red
        } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
            return .yellow
        } else {
            return .green
        }
    }
    
    func xAxisValues() -> [Date] {
        
        // adapted from generateXAxisValues() from GlucoseChartManager.swift in xDrip target
                
        let startDate: Date = bgReadingDates.last ?? Date().addingTimeInterval(-ConstantsGlucoseChartSwiftUI.hoursToShowLiveActivityNotificationNormal * 3600)
        let endDate: Date = Date()
        
        /// how many full hours between startdate and enddate
        let amountOfFullHours = Int(ceil(endDate.timeIntervalSince(startDate) / 3600))
        
        /// create array that goes from 1 to number of full hours, as helper to map to array of ChartAxisValueDate - array will go from 1 to 6
        let mappingArray = Array(1...amountOfFullHours)
        
        /// set the stride count interval to make sure we don't add too many labels to the x-axis if the user wants to view >6 hours
        let intervalBetweenAxisValues: Int = ConstantsGlucoseChartSwiftUI.intervalBetweenXAxisValuesLiveActivityNotificationNormal
        
        /// first, for each int in mappingArray, we create a Date, starting with the lower hour + 1 hour - we will create 5 in this example, starting with hour 08 (7 + 3600 seconds)
        let startDateLower = Date(timeIntervalSinceReferenceDate:
                                    (startDate.timeIntervalSinceReferenceDate / 3600.0).rounded(.down) * 3600.0)
        
        let xAxisValues: [Date] = stride(from: 1, to: mappingArray.count + 1, by: intervalBetweenAxisValues).map {
            startDateLower.addingTimeInterval(Double($0)*3600)
        }
        
        return xAxisValues
        
    }
    

    var body: some View {
        
        let domain = (min((bgReadingValues.min() ?? 40), urgentLowLimitInMgDl) - 6) ... (max((bgReadingValues.max() ?? 400), urgentHighLimitInMgDl) + 6)
        
        Chart {
            if domain.contains(urgentLowLimitInMgDl) {
                RuleMark(y: .value("", urgentLowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: 1 , dash: [2, 6]))
                    .foregroundStyle(ConstantsGlucoseChartSwiftUI.urgentLowHighLineLiveActivityNotification)
            }
            
            if domain.contains(urgentHighLimitInMgDl) {
                RuleMark(y: .value("", urgentHighLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: 1 * ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification, dash: [2 * ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification, 6 * ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification]))
                    .foregroundStyle(ConstantsGlucoseChartSwiftUI.urgentLowHighLineLiveActivityNotification)
            }

            if domain.contains(lowLimitInMgDl) {
                RuleMark(y: .value("", lowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: 1 * ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification, dash: [4 * ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification, 3 * ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification]))
                    .foregroundStyle(ConstantsGlucoseChartSwiftUI.lowHighLineColorLiveActivityNotification)
            }
            
            if domain.contains(highLimitInMgDl) {
                RuleMark(y: .value("", highLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: 1 * ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification, dash: [4 * ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification, 3 * ConstantsGlucoseChartSwiftUI.relativeYAxisLineSizeLiveActivityNotification]))
                    .foregroundStyle(ConstantsGlucoseChartSwiftUI.lowHighLineColorLiveActivityNotification)
            }
            
            // add a phantom glucose point at the beginning of the timeline to fix the start point in case there are no glucose values at that time (for instances after starting a new sensor
            // this will ensure that the x-axis scale remains correct and the few glucose points availabel don't stretch to cover the whole axis
            PointMark(x: .value("Time", Date().addingTimeInterval(-ConstantsGlucoseChartSwiftUI.hoursToShowLiveActivityNotificationNormal * 3600)),
                      y: .value("BG", 100))
            .symbol(Circle())
            .symbolSize(ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterLiveActivityNotification)
            .foregroundStyle(.clear)

            ForEach(bgReadingValues.indices, id: \.self) { index in
                    PointMark(x: .value("Time", bgReadingDates[index]),
                              y: .value("BG", bgReadingValues[index]))
                    .symbol(Circle())
                    .symbolSize(ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterLiveActivityNotification * 0.4)
                    .foregroundStyle(bgColor(bgValueInMgDl: bgReadingValues[index]))
            }
            
            // add a phantom glucose point five minutes after the end of any BG values just to give more context
            PointMark(x: .value("Time", Date().addingTimeInterval(5 * 60)),
                      y: .value("BG", 100))
            .symbol(Circle())
            .symbolSize(ConstantsGlucoseChartSwiftUI.glucoseCircleDiameterLiveActivityNotification)
            .foregroundStyle(.clear)
        }
        .chartXAxis {
            // https://developer.apple.com/documentation/charts/customizing-axes-in-swift-charts
//            AxisMarks(values: xAxisValues()) { value in
//
//                if let v = value.as(Date.self) {
//                    AxisValueLabel {
//                        Text(v.formatted(.dateTime.hour()))
//                            .foregroundStyle(Color.white)
//                    }
//                    //.offset(x: glucoseChartType.xAxisLabelOffset)
//
//                    AxisGridLine()
//                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisGridLineColorLiveActivityNotification)
//                }
//            }
            
            AxisMarks(values: .automatic(desiredCount: Int(ConstantsGlucoseChartSwiftUI.hoursToShowLiveActivityNotificationNormal))) {
                if $0.as(Date.self) != nil {
                    AxisGridLine()
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisGridLineColorLiveActivityNotification)
                }
            }
        }
//        .background(Color.purple)
        .chartYAxis(.hidden)
        .chartYScale(domain: domain)
        .frame(width: 200, height: 120)
//        .padding(.top, -20)
//        .padding(.bottom, 20)
    }
}
