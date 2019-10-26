//
//  based on loopkit https://github.com/loopkit
//
import Foundation
import HealthKit
import SwiftCharts
import os.log

public final class StatusChartsManager {
    
    // MARK: - public properties
    
    /// The amount of horizontal space reserved for fixed margins
    public var fixedHorizontalMargin: CGFloat {
        return chartSettings.leading + chartSettings.trailing + labelsWidthY + chartSettings.labelsToAxisSpacingY
    }
    
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
    
    /// need to remove this, add an observer for UserDefaults.standard.bloodGlucoseUnitIsMgDl, then call glucoseDisplayRange didset whenever the value is changed
    public var glucoseUnit: HKUnit = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .milligramsPerDeciliter : .millimolesPerLiter {
        didSet {
            
            if glucoseUnit != oldValue {
                // this will call the didSet of variable glucoseDisplayRange to be called (see next)
                let oldRange = glucoseDisplayRange
                glucoseDisplayRange = oldRange
            }
        }
    }

    /// this is the range of the chart, in currently chosen unit (mgdl or mmol)
    ///
    /// Whenever glucoseDisplayRange is assigned a new value, glucoseChart is set to nil
    public var glucoseDisplayRange: (min: HKQuantity, max: HKQuantity)? {
        didSet {
            if let range = glucoseDisplayRange {
                glucoseDisplayRangePoints = [
                    ChartPoint(x: ChartAxisValue(scalar: 0), y: ChartAxisValueDouble(range.min.doubleValue(for: glucoseUnit))),
                    ChartPoint(x: ChartAxisValue(scalar: 0), y: ChartAxisValueDouble(range.max.doubleValue(for: glucoseUnit)))
                ]
            } else {
                glucoseDisplayRangePoints = []
            }
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

    private let labelsWidthY: CGFloat = 30

    private var integerFormatter: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.maximumFractionDigits = 0

        return numberFormatter
    }

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
    
    /// two chartPoints, one for minimum glucose value, one for maximum, value depends on chosen unit
    private var glucoseDisplayRangePoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
        }
    }
    
    /// dateformatter for chartpoints ???
    private let dateFormatter: DateFormatter = {
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

    // MARK: - public functions
    
    /// updates chart ?
    public func updateChart() {
        
        let now = Date()
        
        let glucose = [(now, 110.0), (now.addingTimeInterval(-300), 120.0), (now.addingTimeInterval(-600), 130.0)]
        
        glucoseChartPoints = glucose.map {
            ChartPoint(
                x: ChartAxisValueDate(date: $0.0, formatter: dateFormatter),
                y: ChartAxisValueDouble($0.1)
            )
        }

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
        
        guard let xAxisModel = xAxisModel, let xAxisValues = xAxisValues else {
            return nil
        }
        
        let points = glucoseChartPoints + glucoseDisplayRangePoints
        
        guard points.count > 1 else {
            return nil
        }
        
        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesWithChartPoints(points, minSegmentCount: 2, maxSegmentCount: 4, multiple: glucoseUnit.chartableIncrement * 25, axisValueGenerator: {
            
            ChartAxisValueDouble($0, labelSettings: self.chartLabelSettings)
            
        }
            , addPaddingSegmentIfEdge: false
        )
        
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(labelsWidthY))
        
        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)
        
        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
        
        
        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: chartGuideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)
        
        let circles = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: glucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: 4, height: 4), itemFillColor: colors.glucoseTint, optimized: true)
        
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
        
        /// the startdate and the enddate as ChartPoint
        let points = [
            ChartPoint(
                x: ChartAxisValueDate(date: startDate, formatter: axisLabelTimeFormatter),
                y: ChartAxisValue(scalar: 0)
            ),
            ChartPoint(
                x: ChartAxisValueDate(date: endDate, formatter: axisLabelTimeFormatter),
                y: ChartAxisValue(scalar: 0)
            )
        ]
        
        /// how many full hours between startdate and enddate
        let segments = ceil(endDate.timeIntervalSince(startDate).hours)
        
        let xAxisValues = ChartAxisValuesStaticGenerator.generateXAxisValuesWithChartPoints(points, minSegmentCount: segments - 1, maxSegmentCount: segments + 1, multiple: TimeInterval(hours: 2), axisValueGenerator: {
            ChartAxisValueDate(
                date: ChartAxisValueDate.dateFromScalar($0),
                formatter: axisLabelTimeFormatter,
                labelSettings: self.chartLabelSettings
            )
        }, addPaddingSegmentIfEdge: false)
        
        xAxisValues.first?.hidden = true
        xAxisValues.last?.hidden = true
        
        self.xAxisValues = xAxisValues
    }
    
}
