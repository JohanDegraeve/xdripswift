//
//  based on loopkit https://github.com/loopkit
//
import Foundation
import HealthKit
import SwiftCharts
import os.log

public final class GlucoseChartManager {
    
    // MARK: - public properties
    
    public var gestureRecognizer: UIGestureRecognizer?
    
    /// The latest allowed date on the X-axis
    public var maxEndDate = Date.distantFuture {
        didSet {
            if maxEndDate != oldValue {
                
                trace("New chart max end date: %@", log: self.log, type: .info,  String(describing: maxEndDate))
                
            }
            
            endDate = min(endDate, maxEndDate)
        }
    }
    
    /// chartpoint array with actually reading values
    ///
    /// Whenever glucoseChartPoints is assigned a new value, glucoseChart is set to nil
    public var glucoseChartPoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
            
            if let lastDate = glucoseChartPoints.last?.x as? ChartAxisValueDate {
                updateEndDate(lastDate.date)
            }
            
        }
    }
    
    // MARK: - private properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryStatusChartsManager)

    private let colors: ChartColorPalette

    private let chartSettings: ChartSettings

    private let labelsWidthY = ConstantsGlucoseChart.yAxisLabelsWidth

    private var chartLabelSettings: ChartLabelSettings

    private var chartGuideLinesLayerSettings: ChartGuideLinesLayerSettings
    
    /// The latest date on the X-axis
    private var endDate: Date {
        didSet {
            if endDate != oldValue {
                
                trace("New chart enddate: %@", log: self.log, type: .info,  String(describing: endDate))
                
                xAxisValues = nil
                
                // current difference between end and startdate
                let diffEndAndStartDate = oldValue.timeIntervalSince(startDate).hours
                
                // Set a new startdate, difference is equal to previous difference
                startDate = endDate.addingTimeInterval(.hours(-diffEndAndStartDate))
                
            }
        }
    }
    
    /// The earliest date on the X-axis
    private var startDate: Date

    /// A ChartAxisValue models a value along a particular chart axis. For example, two ChartAxisValues represent the two components of a ChartPoint. It has a backing Double scalar value, which provides a canonical form for all subclasses to be laid out along an axis. It also has one or more labels that are drawn in the chart.
    ///
    /// see https://github.com/i-schuetz/SwiftCharts/blob/ec538d027d6d4c64028d85f86d3d72fcda41c016/SwiftCharts/AxisValues/ChartAxisValue.swift#L12, is not meant to be instantiated
    private var xAxisValues: [ChartAxisValue]? {
        didSet {
            if let xAxisValues = xAxisValues, xAxisValues.count > 1 {
                xAxisModel = ChartAxisModel(axisValues: xAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(20))
            } else {
                xAxisModel = nil
            }
            
            glucoseChart = nil
        }
    }
    
    private var xAxisModel: ChartAxisModel?
    
    /// the chart with glucose values
    private var glucoseChart: Chart?
    
    private var glucoseChartCache: ChartPointsTouchHighlightLayerViewCache?
    
    /// dateformatter for timestamp in chartpoints
    private let chartPointDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        
        return dateFormatter
    }()
    
    /// timeformatter for horizontal axis label
    private let axisLabelTimeFormatter:  DateFormatter
    
    // MARK: - intializer
    
    public init(colors: ChartColorPalette, settings: ChartSettings) {
        
        self.colors = colors
        self.chartSettings = settings
        
        chartLabelSettings = ChartLabelSettings(
            font: .systemFont(ofSize: 14),  // caption1, but hard-coded until axis can scale with type preference
            fontColor: colors.axisLabel
        )
        
        chartGuideLinesLayerSettings = ChartGuideLinesLayerSettings(linesColor: colors.grid)
        
        // initialize enddate
        endDate = Date()
        
        // intialize startdate, which is enddate minus a few hours
        startDate = endDate.addingTimeInterval(.hours(-UserDefaults.standard.chartWidthInHours))
        
        axisLabelTimeFormatter = DateFormatter()
        axisLabelTimeFormatter.dateFormat = UserDefaults.standard.chartTimeAxisLabelFormat

    }
    
    convenience public init() {
        
        self.init(
            colors: ChartColorPalette(
                axisLine: ConstantsGlucoseChart.axisLineColor,
                axisLabel: ConstantsGlucoseChart.axisLabelColor,
                grid: ConstantsGlucoseChart.gridColor,
                glucoseTint: ConstantsGlucoseChart.glucoseTintColor
            ),
            settings: {
                var settings = ChartSettings()
                settings.top = ConstantsGlucoseChart.top
                settings.bottom = ConstantsGlucoseChart.bottom
                settings.trailing = ConstantsGlucoseChart.trailing
                settings.leading = ConstantsGlucoseChart.leading
                settings.axisTitleLabelsToLabelsSpacing = ConstantsGlucoseChart.axisTitleLabelsToLabelsSpacing
                settings.labelsToAxisSpacingX = ConstantsGlucoseChart.labelsToAxisSpacingX
                settings.clipInnerFrame = false
                return settings
        }()
        )
    }

    // MARK: - public functions
    
    /// updates chart ?
    public func updateChart() {
        
        let now = Date()
        //for testing only, 1 per 5 minutes
        //let intervals = [5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
        let intervals = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]
        let glucose = intervals.map { (Date(timeInterval: -(Double($0)*900), since: now), (10.0 + Double($0)*20.0).mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)) }
        //let glucose = [(now, 110.0), (now.addingTimeInterval(-300), 120.0), (now.addingTimeInterval(-600), 130.0)]
        
        glucoseChartPoints = glucose.map {
            ChartPoint(
                x: ChartAxisValueDate(date: $0.0, formatter: chartPointDateFormatter),
                y: ChartAxisValueDouble($0.1)
            )
        }
        
        /*glucoseChartPoints.map {
            debuglogging("scalar = " + $0.y.scalar.description)
        }*/

    }
    
    public func didReceiveMemoryWarning() {
        
        trace("in didReceiveMemoryWarning, Purging chart data in response to memory warning", log: self.log, type: .error)

        xAxisValues = nil
        glucoseChartPoints = []
        glucoseChartCache = nil
        
    }

    /// Updates the endDate using a new candidate date
    /// 
    /// Dates are rounded up to the next hour.
    ///
    /// - Parameter date: The new candidate date
    public func updateEndDate(_ date: Date) {
        
        if date > endDate {
            var components = DateComponents()
            components.minute = 0
            endDate = min(
                maxEndDate,
                Calendar.current.nextDate(
                    after: date,
                    matching: components,
                    matchingPolicy: .strict,
                    direction: .forward
                ) ?? date
            )
        }
    }

    public func glucoseChartWithFrame(_ frame: CGRect) -> Chart? {
        
        if let chart = glucoseChart, chart.frame != frame {

            trace("Glucose chart frame changed to %{public}@", log: self.log, type: .info,  String(describing: frame))

            self.glucoseChart = nil
        }

        if glucoseChart == nil {
            glucoseChart = generateGlucoseChartWithFrame(frame)
        }

        return glucoseChart
    }

    /// Runs any necessary steps before rendering charts
    public func prerender() {

        if xAxisValues == nil {
            generateXAxisValues()
        }

    }
    
    // MARK: - private functions
    
    private func generateGlucoseChartWithFrame(_ frame: CGRect) -> Chart? {
        
        guard let xAxisModel = xAxisModel, let xAxisValues = xAxisValues else {return nil}
        
        // just to save typing
        let unitIsMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // create yAxisValues, start with 38 mgdl, this is to make sure we show a bit lower than the real lowest value which is isually 40 mgdl, make the label hidden
        let firstYAxisValue = ChartAxisValueDouble((ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl).mgdlToMmol(mgdl: unitIsMgDl), labelSettings: chartLabelSettings)
        firstYAxisValue.hidden = true
        
        // create now the yAxisValues and add the first
        var yAxisValues = [firstYAxisValue as ChartAxisValue]
        
        // determine the maximum value in the glucosechartPoint
        // start with maximum value defined in constants
        var maximumValueInGlucoseChartPoints = ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl.mgdlToMmol(mgdl: unitIsMgDl)
        // now iterate through glucosechartpoints to determine the maximum
        for glucoseChartPoint in glucoseChartPoints {
            maximumValueInGlucoseChartPoints = max(maximumValueInGlucoseChartPoints, glucoseChartPoint.y.scalar)
        }
        
        // add first series
        if unitIsMgDl {
            yAxisValues += ConstantsGlucoseChart.initialGlucoseValueRangeInMgDl.map { ChartAxisValueDouble($0, labelSettings: chartLabelSettings)}
        } else {
            yAxisValues += ConstantsGlucoseChart.initialGlucoseValueRangeInMmol.map { ChartAxisValueDouble($0, labelSettings: chartLabelSettings)}
        }
        
        // if the maxium yAxisValue doesn't support the maximum glucose value, then add the next range
        if yAxisValues.last!.scalar < maximumValueInGlucoseChartPoints {
            if unitIsMgDl {
                yAxisValues += ConstantsGlucoseChart.secondGlucoseValueRangeInMgDl.map { ChartAxisValueDouble($0, labelSettings: chartLabelSettings)}
            } else {
                yAxisValues += ConstantsGlucoseChart.secondGlucoseValueRangeInMmol.map { ChartAxisValueDouble($0, labelSettings: chartLabelSettings)}
            }
        }

        // if the maxium yAxisValue doesn't support the maximum glucose value, then add the next range
        if yAxisValues.last!.scalar < maximumValueInGlucoseChartPoints {
            if unitIsMgDl {
                yAxisValues += ConstantsGlucoseChart.thirdGlucoseValueRangeInMgDl.map { ChartAxisValueDouble($0, labelSettings: chartLabelSettings)}
            } else {
                yAxisValues += ConstantsGlucoseChart.thirdGlucoseValueRangeInMmol.map { ChartAxisValueDouble($0, labelSettings: chartLabelSettings)}
            }
        }
        
        // the last label should not be visible
        yAxisValues.last?.hidden = true
        
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(labelsWidthY))
        
        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)
        
        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
        
        
        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: chartGuideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)
        
        let circles = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: glucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: ConstantsGlucoseChart.glucoseCircleDiameter, height: ConstantsGlucoseChart.glucoseCircleDiameter), itemFillColor: colors.glucoseTint, optimized: true)
        
        if gestureRecognizer != nil {
            glucoseChartCache = ChartPointsTouchHighlightLayerViewCache(
                xAxisLayer: xAxisLayer,
                yAxisLayer: yAxisLayer,
                axisLabelSettings: self.chartLabelSettings,
                chartPoints: glucoseChartPoints,
                tintColor: colors.glucoseTint,
                gestureRecognizer: gestureRecognizer
            )
        }
        
        let layers: [ChartLayer?] = [
            gridLayer,
            xAxisLayer,
            yAxisLayer,
            glucoseChartCache?.highlightLayer,
            circles
        ]
        
        return Chart(
            frame: frame,
            innerFrame: innerFrame,
            settings: chartSettings,
            layers: layers.compactMap { $0 }
        )
    }

    private func generateXAxisValues() {

        // in the comments, assume it is now 13:26 and width is 6 hours, that means startDate = 07:26, endDate = 13:26
        
        /// how many full hours between startdate and enddate - result would be 6 - maybe we just need to use the userdefaults setting ?
        let amountOfFullHours = Int(ceil(endDate.timeIntervalSince(startDate).hours))
        
        /// create array that goes from 1 to number of full hours, as helper to map to array of ChartAxisValueDate - array will go from 1 to 6
        let mappingArray = Array(1...amountOfFullHours)
        
        /// first, for each int in mappingArray, we create a ChartAxisValueDate, which will have as date one of the hours, starting with the lower hour + 1 hour - we will create 5 in this example, starting with hour 08 (7 + 3600 seconds)
        let startDateLower = startDate.toLowerHour()
        var xAxisValues = mappingArray.map { ChartAxisValueDate(date: Date(timeInterval: Double($0)*3600, since: startDateLower), formatter: axisLabelTimeFormatter, labelSettings: chartLabelSettings) }
        
        /// insert the start Date as first element, in this example 07:26
        xAxisValues.insert(ChartAxisValueDate(date: startDate, formatter: axisLabelTimeFormatter, labelSettings: chartLabelSettings), at: 0)
        
        /// now append the endDate as last element, in this example 13:26
        xAxisValues.append(ChartAxisValueDate(date: endDate, formatter: axisLabelTimeFormatter, labelSettings: chartLabelSettings))
         
        /// don't show the first and last hour, because this is usually not something like 13 but rather 13:26
        xAxisValues.first?.hidden = true
        xAxisValues.last?.hidden = true
        
        self.xAxisValues = xAxisValues
    }
    
}
