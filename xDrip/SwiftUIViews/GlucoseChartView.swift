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

struct GlucoseChartDataSet {
    
    let bgReadingValues: [Double]
    let bgReadingDates: [Date]
    let seriesIdentifier: String
    let lineColor: Color?
    let pointColor: Color?
    let lineWidth: Double
    let dash: [CGFloat]
    let showLine: Bool
    let showPoints: Bool
    let pointSizeMultiplier: Double
    let pointBorderColor: Color?
    let pointBorderSizeMultiplier: Double?
    
}

struct GlucoseChartView: View {
    
    var bgReadingValues: [Double]
    var bgReadingDates: [Date]
    var additionalBgReadingDataSets: [GlucoseChartDataSet]
    
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
    let overrideChartHeightWasPassed: Bool
    
    init(glucoseChartType: GlucoseChartType, bgReadingValues: [Double]?, bgReadingDates: [Date]?, additionalBgReadingDataSets: [GlucoseChartDataSet]? = nil, isMgDl: Bool, urgentLowLimitInMgDl: Double, lowLimitInMgDl: Double, highLimitInMgDl: Double, urgentHighLimitInMgDl: Double, liveActivityType: LiveActivityType?, hoursToShowScalingHours: Double?, glucoseCircleDiameterScalingHours: Double?, overrideChartHeight: Double?, overrideChartWidth: Double?, highContrast: Bool?) {
        
        self.chartType = glucoseChartType
        self.isMgDl = isMgDl
        self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
        self.lowLimitInMgDl = lowLimitInMgDl
        self.highLimitInMgDl = highLimitInMgDl
        self.urgentHighLimitInMgDl = urgentHighLimitInMgDl
        self.liveActivityType = liveActivityType ?? .normal
        self.showHighContrast = highContrast ?? false
        self.overrideChartHeightWasPassed = overrideChartHeight != nil
        
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
        self.additionalBgReadingDataSets = []
        
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
        
        if let additionalBgReadingDataSets = additionalBgReadingDataSets {
            self.additionalBgReadingDataSets = additionalBgReadingDataSets.map { dataSet in
                var filteredBgReadingValues = [Double]()
                var filteredBgReadingDates = [Date]()
                
                for (index, bgReadingDate) in dataSet.bgReadingDates.enumerated() {
                    if bgReadingDate > Date().addingTimeInterval(-hoursToShow * 60 * 60), index < dataSet.bgReadingValues.count {
                        filteredBgReadingValues.append(dataSet.bgReadingValues[index])
                        filteredBgReadingDates.append(bgReadingDate)
                    }
                }
                
                return GlucoseChartDataSet(bgReadingValues: filteredBgReadingValues, bgReadingDates: filteredBgReadingDates, seriesIdentifier: dataSet.seriesIdentifier, lineColor: dataSet.lineColor, pointColor: dataSet.pointColor, lineWidth: dataSet.lineWidth, dash: dataSet.dash, showLine: dataSet.showLine, showPoints: dataSet.showPoints, pointSizeMultiplier: dataSet.pointSizeMultiplier, pointBorderColor: dataSet.pointBorderColor, pointBorderSizeMultiplier: dataSet.pointBorderSizeMultiplier)
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
    
    var body: some View {
        let additionalValues = additionalBgReadingDataSets.flatMap { $0.bgReadingValues }
        let allBgValues = bgReadingValues + additionalValues
        let domain = (min((allBgValues.min() ?? 40), urgentLowLimitInMgDl) - 6) ... (max((allBgValues.max() ?? urgentHighLimitInMgDl), urgentHighLimitInMgDl) + 6)
        let xAxisLabelEveryHours = hoursToShow > 8 ? 2 : chartType.xAxisLabelEveryHours()
        
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

            ForEach(additionalBgReadingDataSets.indices, id: \.self) { dataSetIndex in
                let dataSet = additionalBgReadingDataSets[dataSetIndex]
                
                ForEach(dataSet.bgReadingValues.indices, id: \.self) { valueIndex in
                    if dataSet.showLine, let lineColor = dataSet.lineColor {
                        let bgReadingDate = dataSet.bgReadingDates[valueIndex]
                        let bgReadingValue = dataSet.bgReadingValues[valueIndex]
                        let strokeStyle = StrokeStyle(lineWidth: dataSet.lineWidth, dash: dataSet.dash)
                        
                        LineMark(x: .value("Time", bgReadingDate),
                                 y: .value("BG", bgReadingValue),
                                 series: .value("Series", dataSet.seriesIdentifier))
                        .lineStyle(strokeStyle)
                        .foregroundStyle(lineColor)
                    }
                }
            }
            
            ForEach(additionalBgReadingDataSets.indices, id: \.self) { dataSetIndex in
                let dataSet = additionalBgReadingDataSets[dataSetIndex]
                
                ForEach(dataSet.bgReadingValues.indices, id: \.self) { valueIndex in
                    if dataSet.showPoints && dataSet.pointBorderColor == nil {
                        let bgReadingDate = dataSet.bgReadingDates[valueIndex]
                        let bgReadingValue = dataSet.bgReadingValues[valueIndex]
                        let pointColor = dataSet.pointColor ?? dataSet.lineColor ?? .clear
                        
                        PointMark(x: .value("Time", bgReadingDate),
                                  y: .value("BG", bgReadingValue))
                        .symbol(Circle())
                        .symbolSize(glucoseCircleDiameter * dataSet.pointSizeMultiplier)
                        .foregroundStyle(pointColor)
                    }
                }
            }
            
            ForEach(bgReadingValues.indices, id: \.self) { index in
                    PointMark(x: .value("Time", bgReadingDates[index]),
                              y: .value("BG", bgReadingValues[index]))
                    .symbol(Circle())
                    .symbolSize(glucoseCircleDiameter)
                    .foregroundStyle(bgColor(bgValueInMgDl: bgReadingValues[index]))
            }
            
            ForEach(additionalBgReadingDataSets.indices, id: \.self) { dataSetIndex in
                let dataSet = additionalBgReadingDataSets[dataSetIndex]
                
                ForEach(dataSet.bgReadingValues.indices, id: \.self) { valueIndex in
                    if dataSet.showPoints, let pointBorderColor = dataSet.pointBorderColor, let pointBorderSizeMultiplier = dataSet.pointBorderSizeMultiplier {
                        let bgReadingDate = dataSet.bgReadingDates[valueIndex]
                        let bgReadingValue = dataSet.bgReadingValues[valueIndex]
                        let pointColor = dataSet.pointColor ?? dataSet.lineColor ?? .clear
                        
                        PointMark(x: .value("Time", bgReadingDate),
                                  y: .value("BG", bgReadingValue))
                        .symbol(Circle())
                        .symbolSize(glucoseCircleDiameter * pointBorderSizeMultiplier)
                        .foregroundStyle(pointBorderColor)
                        
                        PointMark(x: .value("Time", bgReadingDate),
                                  y: .value("BG", bgReadingValue))
                        .symbol(Circle())
                        .symbolSize(glucoseCircleDiameter * dataSet.pointSizeMultiplier)
                        .foregroundStyle(pointColor)
                    }
                }
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
            AxisMarks(values: .stride(by: .hour, count: xAxisLabelEveryHours)) {
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
        .if({ return chartType.aspectRatio().enable && !overrideChartHeightWasPassed ? true : false }()) { view in
            view.aspectRatio(chartType.aspectRatio().aspectRatio, contentMode: chartType.aspectRatio().contentMode)
        }
        .if(overrideChartHeightWasPassed) { view in
            view
                .frame(maxWidth: .infinity)
                .frame(height: chartHeight)
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
