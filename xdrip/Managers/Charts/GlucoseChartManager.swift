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
    
    /// reference to coreDataManager
    public var coreDataManager: CoreDataManager? {
        didSet {
            if let coreDataManager = coreDataManager {
                bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
            }
        }
    }
    
   // MARK: - private properties
    
    /// chartpoint array with glucose values and timestamp
    ///
    /// Whenever glucoseChartPoints is assigned a new value, glucoseChart is set to nil
    private var glucoseChartPoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
        }
    }
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryGlucoseChartManager)

    private let colors = ChartColorPalette(axisLine: ConstantsGlucoseChart.axisLineColor, axisLabel: ConstantsGlucoseChart.axisLabelColor, grid: ConstantsGlucoseChart.gridColor, glucoseTint: ConstantsGlucoseChart.glucoseTintColor)

    private let chartSettings: ChartSettings = {
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

    private let labelsWidthY = ConstantsGlucoseChart.yAxisLabelsWidth

    private var chartLabelSettings: ChartLabelSettings

    private var chartGuideLinesLayerSettings: ChartGuideLinesLayerSettings
    
    /// The latest date on the X-axis
    private var endDate: Date {
        didSet {
            if endDate != oldValue {
                
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
    
    /// a BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor?

    // MARK: - intializer
    
    init() {
        
        chartLabelSettings = ChartLabelSettings(
            font: .systemFont(ofSize: 14),
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
    
    /// updates the glucoseChartPoints array and calls completionHandler when finished, also chart is set to nil
    /// - parameters:
    ///     - completionHandler will be called when finished
    public func updateGlucoseChartPoints(completionHandler: @escaping () -> ()) {
        
        guard let bgReadingsAccessor = bgReadingsAccessor else {
            trace("in updateGlucoseChartPoints, bgReadingsAccessor, probably coreDataManager is not yet assigned", log: self.log, type: .info)
            return
        }
        
        let queue = OperationQueue()
        
        let operation = BlockOperation(block: {
            
            // reset endDate
            self.endDate = Date()
            
            // get glucosePoints from coredata
            let glucoseChartPoints = bgReadingsAccessor.getBgReadingOnPrivateManagedObjectContext(from: self.startDate, to: self.endDate).compactMap {
                
                ChartPoint(bgReading: $0, formatter: self.chartPointDateFormatter, unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                
            }
            
            //let glucosePoints = BgReadingsAccessor.get
            DispatchQueue.main.async {
                
                self.glucoseChartPoints = glucoseChartPoints
                
                completionHandler()
            }
            
        })
        
        queue.addOperation {
            operation.start()
        }
        
    }
    
    public func didReceiveMemoryWarning() {
        
        trace("in didReceiveMemoryWarning, Purging chart data in response to memory warning", log: self.log, type: .error)

        xAxisValues = nil
        glucoseChartPoints = []
        glucoseChartCache = nil
        
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
        var xAxisValues: [ChartAxisValue] = mappingArray.map { ChartAxisValueDate(date: Date(timeInterval: Double($0)*3600, since: startDateLower), formatter: axisLabelTimeFormatter, labelSettings: chartLabelSettings) }
        
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
