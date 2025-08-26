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

struct GlucoseChartView: View {
    
    var bgReadingValues: [Double]
    var bgReadingDates: [Date]
    
    let chartType: GlucoseChartType // shortened to chartType to make reading easier below
    let isMgDl: Bool
    let urgentLowLimitInMgDl: Double
    let lowLimitInMgDl: Double
    let highLimitInMgDl: Double
    let urgentHighLimitInMgDl: Double
    let liveActivityType: LiveActivityType
    let hoursToShow: Double
    let glucoseCircleDiameter: Double
    let chartHeight: Double
    let chartWidth: Double
    let showHighContrast: Bool
    
    init(glucoseChartType: GlucoseChartType, bgReadingValues: [Double]?, bgReadingDates: [Date]?, isMgDl: Bool, urgentLowLimitInMgDl: Double, lowLimitInMgDl: Double, highLimitInMgDl: Double, urgentHighLimitInMgDl: Double, liveActivityType: LiveActivityType?, hoursToShowScalingHours: Double?, glucoseCircleDiameterScalingHours: Double?, overrideChartHeight: Double?, overrideChartWidth: Double?, highContrast: Bool?) {
        
        self.chartType = glucoseChartType
        self.isMgDl = isMgDl
        self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
        self.lowLimitInMgDl = lowLimitInMgDl
        self.highLimitInMgDl = highLimitInMgDl
        self.urgentHighLimitInMgDl = urgentHighLimitInMgDl
        self.liveActivityType = liveActivityType ?? .normal
        self.showHighContrast = highContrast ?? false
        
        // here we want to automatically set the hoursToShow based upon the chart type, but some chart instances might need
        // this to be overriden such as for zooming in/out of the chart (i.e. the Watch App)
        self.hoursToShow = hoursToShowScalingHours ?? chartType.hoursToShow(liveActivityType: self.liveActivityType)
        
        self.chartHeight = overrideChartHeight ?? chartType.viewSize(liveActivityType: self.liveActivityType).height
        
        self.chartWidth = overrideChartWidth ?? chartType.viewSize(liveActivityType: self.liveActivityType).width
        
        // apply a scale to the glucoseCircleDiameter if an override value is passed
        self.glucoseCircleDiameter = chartType.glucoseCircleDiameter(liveActivityType: self.liveActivityType) * ((glucoseCircleDiameterScalingHours ?? self.hoursToShow) / self.hoursToShow)
        
        // as all widget instances are passed 12 hours of bg values, we must initialize this instance to use only the amount of hours of value required by the chartType passed
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
        if chartType != .widgetSystemSmallStandBy || !showHighContrast {
            if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                return .red
            } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                return .yellow
            } else {
                return .green
            }
        } else {
            return .white
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
        let intervalBetweenAxisValues: Int = chartType.intervalBetweenAxisValues(liveActivityType: liveActivityType)
        
        /// first, for each int in mappingArray, we create a Date, starting with the lower hour + 1 hour - we will create 5 in this example, starting with hour 08 (7 + 3600 seconds)
        let startDateLower = Date(timeIntervalSinceReferenceDate:
                                    (startDate.timeIntervalSinceReferenceDate / 3600.0).rounded(.down) * 3600.0)
        
        let xAxisValues: [Date] = stride(from: 1, to: mappingArray.count + 1, by: intervalBetweenAxisValues).map {
            startDateLower.addingTimeInterval(Double($0)*3600)
        }
        
        return xAxisValues
        
    }
    

    var body: some View {
        let domain = (min((bgReadingValues.min() ?? 40), urgentLowLimitInMgDl) - 6) ... (max((bgReadingValues.max() ?? urgentHighLimitInMgDl), urgentHighLimitInMgDl) + 6)
        
        let yAxisLineSize = chartType.yAxisLineSize()
        
        Chart {
            if domain.contains(urgentLowLimitInMgDl) {
                RuleMark(y: .value("", urgentLowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [2 * yAxisLineSize, 6 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisUrgentLowHighLineColor())
            }
            
            if domain.contains(urgentHighLimitInMgDl) {
                RuleMark(y: .value("", urgentHighLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [2 * yAxisLineSize, 6 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisUrgentLowHighLineColor())
            }

            if domain.contains(lowLimitInMgDl) {
                RuleMark(y: .value("", lowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [4 * yAxisLineSize, 3 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisLowHighLineColor())
            }
            
            if domain.contains(highLimitInMgDl) {
                RuleMark(y: .value("", highLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [4 * yAxisLineSize, 3 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisLowHighLineColor())
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
            AxisMarks(values: .stride(by: .hour, count: chartType.xAxisLabelEveryHours())) {
                if let value = $0.as(Date.self) {
                    if chartType.xAxisShowLabels() {
                        AxisValueLabel {
                            let shouldHideLabel = abs(Date().distance(to: value)) < ConstantsGlucoseChartSwiftUI.xAxisLabelFirstClippingInMinutes || abs(Date().addingTimeInterval(-hoursToShow * 3600).distance(to: value)) < ConstantsGlucoseChartSwiftUI.xAxisLabelLastClippingInMinutes ? true : false
                            
                            Text(!shouldHideLabel ? value.formatted(.dateTime.hour()) : "")
                                .foregroundStyle(Color(.colorSecondary))
                                .font(.footnote)
                                .offset(x: chartType.xAxisLabelOffsetX(), y: chartType.xAxisLabelOffsetY())
                        }
                    }
                    
                    AxisGridLine()
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisGridLineColor)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [lowLimitInMgDl, highLimitInMgDl]) {
                if let value = $0.as(Double.self) {
                    AxisValueLabel {
                        Text(value.mgDlToMmolAndToString(mgDl: isMgDl))
                            .foregroundStyle(Color(.colorPrimary))
                            .font(.footnote)
                            .offset(x: chartType.yAxisLabelOffsetX(), y: chartType.yAxisLabelOffsetY())
                    }
                }
            }
            
            AxisMarks(values: [urgentLowLimitInMgDl, urgentHighLimitInMgDl]) {
                if let value = $0.as(Double.self) {
                    AxisValueLabel {
                        Text(value.mgDlToMmolAndToString(mgDl: isMgDl))
                            .foregroundStyle(Color(.colorSecondary))
                            .font(.footnote)
                            .offset(x: chartType.yAxisLabelOffsetX(), y: chartType.yAxisLabelOffsetY())
                    }
                }
            }
        }
        .if({ return chartType.frame() ? true : false }()) { view in 
            view.frame(width: chartWidth, height: chartHeight)
        }
        .if({ return chartType.aspectRatio().enable ? true : false }()) { view in
            view.aspectRatio(chartType.aspectRatio().aspectRatio, contentMode: chartType.aspectRatio().contentMode)
        }
        .if({ return chartType.padding().enable ? true : false }()) { view in 
            view.padding(chartType.padding().padding)
        }
        .chartYAxis(chartType.yAxisShowLabels())
        .chartYScale(domain: domain)
        .modifier(ChartBackgroundModifier(chartType: chartType))
        .clipShape(RoundedRectangle(cornerRadius: chartType.cornerRadius()))
    }
}

// apply a view modifier so that we can correctly show the chart views when displayed as a widget
// this ensures that the widgets can be displayed in tinted or clear styles (in iOS26)
private struct ChartBackgroundModifier: ViewModifier {
    let chartType: GlucoseChartType
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(.clear, for: .widget)
        } else {
            content.background(chartType.backgroundColor())
        }
    }
}
