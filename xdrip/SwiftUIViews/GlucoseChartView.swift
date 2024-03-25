//
//  GlucoseChartView.swift
//  xdrip
//
//  Created by Paul Plant on 13/01/2024.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI
import Foundation

@available(iOS 16, *)
struct GlucoseChartView: View {
    
    var bgReadingValues: [Double]
    var bgReadingDates: [Date]
    
    let glucoseChartType: GlucoseChartType
    let isMgDl: Bool
    let urgentLowLimitInMgDl: Double
    let lowLimitInMgDl: Double
    let highLimitInMgDl: Double
    let urgentHighLimitInMgDl: Double
    let liveActivitySize: LiveActivitySize
    let hoursToShow: Double
    let glucoseCircleDiameter: Double
    let chartHeight: Double
    let chartWidth: Double
    
    init(glucoseChartType: GlucoseChartType, bgReadingValues: [Double]?, bgReadingDates: [Date]?, isMgDl: Bool, urgentLowLimitInMgDl: Double, lowLimitInMgDl: Double, highLimitInMgDl: Double, urgentHighLimitInMgDl: Double, liveActivitySize: LiveActivitySize?, hoursToShowScalingHours: Double?, glucoseCircleDiameterScalingHours: Double?, overrideChartHeight: Double?, overrideChartWidth: Double?) {
        
        self.glucoseChartType = glucoseChartType
        self.isMgDl = isMgDl
        self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
        self.lowLimitInMgDl = lowLimitInMgDl
        self.highLimitInMgDl = highLimitInMgDl
        self.urgentHighLimitInMgDl = urgentHighLimitInMgDl
        self.liveActivitySize = liveActivitySize ?? .normal
        
        // here we want to automatically set the hoursToShow based upon the chart type, but some chart instances might need
        // this to be overriden such as for zooming in/out of the chart (i.e. the Watch App)
        self.hoursToShow = hoursToShowScalingHours ?? glucoseChartType.hoursToShow(liveActivitySize: self.liveActivitySize)
        
        self.chartHeight = overrideChartHeight ?? glucoseChartType.viewSize(liveActivitySize: self.liveActivitySize).height
        self.chartWidth = overrideChartWidth ?? glucoseChartType.viewSize(liveActivitySize: self.liveActivitySize).width
        
        // apply a scale to the glucoseCircleDiameter if an override value is passed
        self.glucoseCircleDiameter = glucoseChartType.glucoseCircleDiameter(liveActivitySize: self.liveActivitySize) * ((glucoseCircleDiameterScalingHours ?? self.hoursToShow) / self.hoursToShow)
        
        // as all widget instances are passed 12 hours of bg values, we must initialize this instance to use only the amount of hours of value required by the glucoseChartType passed
        self.bgReadingValues = []
        self.bgReadingDates = []
        
        if let bgReadingValues = bgReadingValues, let bgReadingDates = bgReadingDates {
            var index = 0
            for _ in bgReadingValues {
                if bgReadingDates[index] > Date().addingTimeInterval(-hoursToShow * 60 * 60) {
                    self.bgReadingValues.append(bgReadingValues[index])
                    self.bgReadingDates.append(bgReadingDates[index])
                }
                index += 1
            }
        }
    }
    
    /// Blood glucose color dependant on the user defined limit values
    /// - Returns: a Color object either red, yellow or green
    func bgColor(bgValueInMgDl: Double) -> Color {
        if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
            return Color(.red)
        } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
            return Color(.yellow)
        } else {
            return Color(.green)
        }
    }
    
    // adapted from generateXAxisValues() from GlucoseChartManager.swift in xDrip target
    func xAxisValues() -> [Date] {
        let startDate: Date = bgReadingDates.last ?? Date().addingTimeInterval(-hoursToShow * 3600)
        let endDate: Date = Date()
        
        /// how many full hours between startdate and enddate
        let amountOfFullHours = Int(ceil(endDate.timeIntervalSince(startDate) / 3600))
        
        /// create array that goes from 1 to number of full hours, as helper to map to array of ChartAxisValueDate - array will go from 1 to 6
        let mappingArray = Array(1...amountOfFullHours)
        
        /// set the stride count interval to make sure we don't add too many labels to the x-axis if the user wants to view >6 hours
        let intervalBetweenAxisValues: Int = glucoseChartType.intervalBetweenAxisValues(liveActivitySize: liveActivitySize)
        
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
                    .lineStyle(StrokeStyle(lineWidth: 1 * glucoseChartType.relativeYAxisLineSize, dash: [2 * glucoseChartType.relativeYAxisLineSize, 6 * glucoseChartType.relativeYAxisLineSize]))
                    .foregroundStyle(glucoseChartType.urgentLowHighLineColor)
            }
            
            if domain.contains(urgentHighLimitInMgDl) {
                RuleMark(y: .value("", urgentHighLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: 1 * glucoseChartType.relativeYAxisLineSize, dash: [2 * glucoseChartType.relativeYAxisLineSize, 6 * glucoseChartType.relativeYAxisLineSize]))
                    .foregroundStyle(glucoseChartType.urgentLowHighLineColor)
            }

            if domain.contains(lowLimitInMgDl) {
                RuleMark(y: .value("", lowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: 1 * glucoseChartType.relativeYAxisLineSize, dash: [4 * glucoseChartType.relativeYAxisLineSize, 3 * glucoseChartType.relativeYAxisLineSize]))
                    .foregroundStyle(glucoseChartType.lowHighLineColor)
            }
            
            if domain.contains(highLimitInMgDl) {
                RuleMark(y: .value("", highLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: 1 * glucoseChartType.relativeYAxisLineSize, dash: [4 * glucoseChartType.relativeYAxisLineSize, 3 * glucoseChartType.relativeYAxisLineSize]))
                    .foregroundStyle(glucoseChartType.lowHighLineColor)
            }
            
            // add a phantom glucose point at the beginning of the timeline to fix the start point in case there are no glucose values at that time (for instances after starting a new sensor)
            PointMark(x: .value("Time", Date().addingTimeInterval(-hoursToShow * 3600)),
                      y: .value("BG", 100))
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter)
            .foregroundStyle(.clear)

            ForEach(bgReadingValues.indices, id: \.self) { index in
                    PointMark(x: .value("Time", bgReadingDates[index]),
                              y: .value("BG", bgReadingValues[index]))
                    .symbol(Circle())
                    .symbolSize(glucoseCircleDiameter)
                    .foregroundStyle(bgColor(bgValueInMgDl: bgReadingValues[index]))
            }
            
            // add a phantom glucose point five minutes after the end of any BG values to fix the end point
            // we use it to make sure the chart ends "now" even if the last bg reading was some time ago
            // it also serves to make sure the last chartpoint circle isn't cut off by the y-axis
            PointMark(x: .value("Time", Date().addingTimeInterval(5 * 60)),
                      y: .value("BG", 100))
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter)
            .foregroundStyle(.clear)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: Int(hoursToShow))) {
                if $0.as(Date.self) != nil {
                    AxisGridLine()
                        .foregroundStyle(glucoseChartType.xAxisGridLineColor)
                }
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: domain)
        .frame(width: chartWidth, height: chartHeight)
    }
}
