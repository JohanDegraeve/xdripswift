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
    
    /// The earliest date on the X-axis
    public var startDate = Date() {
        didSet {
            if startDate != oldValue {
                
                trace("New chart start date: %@", log: self.log, type: .info,  String(describing: startDate))
                
                xAxisValues = nil
                
                // Set a new minimum end date
                endDate = startDate.addingTimeInterval(.hours(3))
                
            }
        }
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
    
    public var glucoseUnit: HKUnit = UserDefaults.standard.bloodGlucoseUnitIsMgDl ? .milligramsPerDeciliter : .millimolesPerLiter {
        didSet {
            
            if glucoseUnit != oldValue {
                // Regenerate the glucose display points
                let oldRange = glucoseDisplayRange
                glucoseDisplayRange = oldRange
            }
        }
    }

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

    public var glucosePoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
            
            if let lastDate = glucosePoints.last?.x as? ChartAxisValueDate {
                updateEndDate(lastDate.date)
            }
        }
    }
    
    public var glucoseDisplayRangePoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
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

    private var axisLabelSettings: ChartLabelSettings

    private var guideLinesLayerSettings: ChartGuideLinesLayerSettings
    
    /// The latest date on the X-axis
    private var endDate = Date() {
        didSet {
            if endDate != oldValue {
                
                trace("New chart end date: %@", log: self.log, type: .info,  String(describing: endDate))
                
                xAxisValues = nil
                
            }
        }
    }
    
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
    
    private var glucoseChart: Chart?
    
    private var glucoseChartCache: ChartPointsTouchHighlightLayerViewCache?
    
    // MARK: - intializer
    
    public init(colors: ChartColorPalette, settings: ChartSettings) {
        
        self.colors = colors
        self.chartSettings = settings
        
        axisLabelSettings = ChartLabelSettings(
            font: .systemFont(ofSize: 14),  // caption1, but hard-coded until axis can scale with type preference
            fontColor: colors.axisLabel
        )
        
        guideLinesLayerSettings = ChartGuideLinesLayerSettings(linesColor: colors.grid)
        
    }

    // MARK: - public functions
    
    public func didReceiveMemoryWarning() {
        
        trace("in didReceiveMemoryWarning, Purging chart data in response to memory warning", log: self.log, type: .error)

        xAxisValues = nil
        glucosePoints = []
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
        
        let points = glucosePoints + glucoseDisplayRangePoints
        
        guard points.count > 1 else {
            return nil
        }
        
        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesWithChartPoints(points,
                                                                                            minSegmentCount: 2,
                                                                                            maxSegmentCount: 4,
                                                                                            multiple: glucoseUnit.chartableIncrement * 25,
                                                                                            axisValueGenerator: {
                                                                                                ChartAxisValueDouble($0, labelSettings: self.axisLabelSettings)
        },
                                                                                            addPaddingSegmentIfEdge: false
        )
        
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(labelsWidthY))
        
        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)
        
        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
        
        
        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: guideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)
        
        let circles = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: glucosePoints, displayDelay: 0, itemSize: CGSize(width: 4, height: 4), itemFillColor: colors.glucoseTint, optimized: true)
        
        if gestureRecognizer != nil {
            glucoseChartCache = ChartPointsTouchHighlightLayerViewCache(
                xAxisLayer: xAxisLayer,
                yAxisLayer: yAxisLayer,
                axisLabelSettings: self.axisLabelSettings,
                chartPoints: glucosePoints,
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
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h a"
        
        let points = [
            ChartPoint(
                x: ChartAxisValueDate(date: startDate, formatter: timeFormatter),
                y: ChartAxisValue(scalar: 0)
            ),
            ChartPoint(
                x: ChartAxisValueDate(date: endDate, formatter: timeFormatter),
                y: ChartAxisValue(scalar: 0)
            )
        ]
        
        let segments = ceil(endDate.timeIntervalSince(startDate).hours)
        
        let xAxisValues = ChartAxisValuesStaticGenerator.generateXAxisValuesWithChartPoints(points, minSegmentCount: segments - 1, maxSegmentCount: segments + 1, multiple: TimeInterval(hours: 1), axisValueGenerator: {
            ChartAxisValueDate(
                date: ChartAxisValueDate.dateFromScalar($0),
                formatter: timeFormatter,
                labelSettings: self.axisLabelSettings
            )
        }, addPaddingSegmentIfEdge: false)
        
        xAxisValues.first?.hidden = true
        xAxisValues.last?.hidden = true
        
        self.xAxisValues = xAxisValues
    }
    
}
