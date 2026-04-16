//
//  GlucoseMiniChartManager.swift
//  xdrip
//
//  Created by Paul Plant on 16/6/22.
//  Copyright © 2022 Johan Degraeve. All rights reserved.
//

import Foundation
import HealthKit
import SwiftCharts
import os.log
import UIKit
import CoreData

public class GlucoseMiniChartManager {
    
    /// to hold range of glucose chartpoints
    /// - urgentRange = above urgentHighMarkValue or below urgentLowMarkValue
    /// - in range = between lowMarkValue and highMarkValue
    /// - notUrgentRange = between highMarkValue and urgentHighMarkValue or between urgentLowMarkValue and lowMarkValue
    /// - firstGlucoseChartPoint is the first ChartPoint considering the three arrays together
    /// - lastGlucoseChartPoint is the last ChartPoint considering the three arrays together
    /// - maximumValueInGlucoseChartPoints = the largest x value (ie the highest Glucose value) considering the three arrays together
    typealias GlucoseChartPointsType = (urgentRange: [ChartPoint], inRange: [ChartPoint], notUrgentRange: [ChartPoint], maximumValueInGlucoseChartPoints: Double?)
    
    // MARK: - private properties
    
    /// glucoseChartPoints to reuse for each iteration, or for each redrawing of glucose chart
    ///
    /// Whenever glucoseChartPoints is assigned a new value, glucoseChart is set to nil
    private var glucoseChartPoints: GlucoseChartPointsType = ([ChartPoint](), [ChartPoint](), [ChartPoint](), nil) {
        didSet {
            glucoseChart = nil
        }
    }

    /// ChartPoints to be shown on chart, procssed only in main thread - urgent Range
    private var urgentRangeGlucoseChartPoints = [ChartPoint]()
    
    /// ChartPoints to be shown on chart, procssed only in main thread - in Range
    private var inRangeGlucoseChartPoints = [ChartPoint]()
    
    /// ChartPoints to be shown on chart, procssed only in main thread - not Urgent Range
    private var notUrgentRangeGlucoseChartPoints = [ChartPoint]()
    
    /// for logging
    private var oslog = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryGlucoseChartManager)
    
    private var chartSettings: ChartSettings?
    
    private var chartLabelSettings: ChartLabelSettings?
    
    private var chartLabelSettingsHidden: ChartLabelSettings?
    
    private var chartGuideLinesLayerSettings: ChartGuideLinesLayerSettings?
    
    /// The latest date on the X-axis
    private(set) var endDate: Date
    
    /// The earliest date on the X-axis
    private var startDate: Date
    
    /// the (mini) chart with glucose values
    private var glucoseChart: Chart?
    
    /// dateformatter for timestamp in chartpoints
    private var chartPointDateFormatter: DateFormatter?
    
    /// timeformatter for horizontal axis label
    private var axisLabelTimeFormatter: DateFormatter?
    
    /// a BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor?
    
    /// a coreDataManager
    private var coreDataManager: CoreDataManager
    
    /// innerFrame width
    ///
    /// default value 300.0 which is probably not correct but it can't be initiated as long as glusoseChart is not initialized, to avoid having to work with optional, i assign it to 300.0
    private var innerFrameWidth: Double = 300.0
    
    /// used for getting bgreadings on a background thread, bgreadings are used to create list of chartPoints
    private var operationQueue: OperationQueue?
    
    /// - the maximum value in glucoseChartPoints array between start and endPoint
    /// - the value will never get smaller during the run time of the app
    /// - in mgdl
    private var maximumValueInGlucoseChartPointsInMgDl: Double = ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl
    
    
    // MARK: - intializer
    init(coreDataManager: CoreDataManager) {
        
        // set coreDataManager and bgReadingsAccessor
        self.coreDataManager = coreDataManager
        
        // now set the start date to the end date minus the amount of hours we want to show
        startDate = Date().addingTimeInterval(-UserDefaults.standard.miniChartHoursToShow * 60 * 60)
        
        // set the end date to the current time
        endDate = Date()
                
    }
    
    // MARK: - public functions
    
    /// - updates the chartPoints arrays , and the chartOutlet, and calls completionHandler when finished
    /// - if called multiple times after each other there might be calls skipped,
    /// - completionhandler will be called when chartOutlet is updated
    /// - parameters:
    ///     - completionHandler : will be called when glucoseChartPoints and chartOutlet are updated
    ///     - endDate :endDate to apply
    ///     - coreDataManager : needed to create a private managed object context, which will be used to fetch readings from CoreData
    ///
    /// update of chartPoints array will be done on background thread. The actual redrawing of the chartoutlet is  done on the main thread. Also the completionHandler runs in the main thread.
    /// While updating glucoseChartPoints in background thread, the main thread may call again updateChartPoints with a new endDate (because a new value has arrived). A new block will be added in the operation queue and processed later. If there's multiple operations waiting in the queue, only the last one will be executed.
    public func updateChartPoints(chartOutlet: BloodGlucoseChartView, completionHandler: (() -> ())?) {
        
        // create a new operation
        let operation = BlockOperation(block: {
            
            // if there's more than one operation waiting for execution, it makes no sense to execute this one, the next one has a newer endDate to use
            guard self.data().operationQueue.operations.count <= 1 else {
                return
            }
            
            // set the start date based upon the current time less the number of hours that we want to display
            let startDate: Date = Date().addingTimeInterval(-UserDefaults.standard.miniChartHoursToShow * 60 * 60)
            
            // set the end date to now
            let endDate: Date = Date()
            
            // we're going to check if we have already all chartpoints in the arrays self.glucoseChartPoints for the new start and date time. If not we're going to prepand a arrays and/or append a arrays
            
            // initialize new list of chartPoints to prepend with empty arrays
            var glucoseChartPoints: GlucoseChartPointsType = ([ChartPoint](), [ChartPoint](), [ChartPoint](), nil)
            
            // get glucosePoints from coredata
            glucoseChartPoints = self.getGlucoseChartPoints(startDate: startDate, endDate: endDate, bgReadingsAccessor: self.data().bgReadingsAccessor, on: self.coreDataManager.privateManagedObjectContext)
            
            self.maximumValueInGlucoseChartPointsInMgDl = self.getNewMaximumValueInGlucoseChartPoints(currentMaximumValueInGlucoseChartPoints: self.maximumValueInGlucoseChartPointsInMgDl, glucoseChartPoints: glucoseChartPoints)
            
            self.glucoseChartPoints.urgentRange = glucoseChartPoints.urgentRange
            self.glucoseChartPoints.inRange = glucoseChartPoints.inRange
            self.glucoseChartPoints.notUrgentRange = glucoseChartPoints.notUrgentRange
            
            DispatchQueue.main.async {
                
                // so we're in the main thread, now endDate and startDate and glucoseChartPoints can be safely assigned to value that was passed in the call to updateChartPoints
                self.endDate = endDate
                self.startDate = startDate
                
                // also assign urgentRangeGlucoseChartPoints, urgentRangeGlucoseChartPoints and urgentRangeGlucoseChartPoints to the corresponding arrays in glucoseChartPoints - can also be safely done because we're in the main thread
                self.urgentRangeGlucoseChartPoints = self.glucoseChartPoints.urgentRange
                self.inRangeGlucoseChartPoints = self.glucoseChartPoints.inRange
                self.notUrgentRangeGlucoseChartPoints = self.glucoseChartPoints.notUrgentRange
                
                // update the chart outlet
                chartOutlet.reloadChart()
                
                // call completionhandler if not nil
                if let completionHandler = completionHandler {
                    completionHandler()
                }
                
            }
            
        })
            
        // add the operation to the queue and start it. As maxConcurrentOperationCount = 1, it may be kept until a previous operation has finished
        data().operationQueue.addOperation {
            operation.start()
        }
        
    }
    
    public func cleanUpMemory() {
        
        trace("in cleanUpMemory", log: self.oslog, category: ConstantsLog.categoryGlucoseChartManager, type: .info)
        
        nillifyData()
        
    }
    
    public func glucoseChartWithFrame(_ frame: CGRect) -> Chart? {
        
        if let chart = glucoseChart, chart.frame != frame {
            
            trace("Glucose chart frame changed to %{public}@", log: self.oslog, category: ConstantsLog.categoryGlucoseChartManager, type: .info,  String(describing: frame))
            
            self.glucoseChart = nil
        }
        
        if glucoseChart == nil {
            glucoseChart = generateGlucoseChartWithFrame(frame)
        }
        
        return glucoseChart
    }
    
    
    // MARK: - private functions
    
    private func generateGlucoseChartWithFrame(_ frame: CGRect) -> Chart? {
                
        // let's set up the x-axis for the chart. We just want the first and late values - no need for anything in between
        var xAxisValues = [ ChartAxisValueDate(date: startDate, formatter: data().axisLabelTimeFormatter, labelSettings: data().chartLabelSettingsHidden) ]
        
        // let's set a visible axis for each midnight we find between the start and end dates. This helps the user to get context from a quick glance at the mini-chart
        
        // get the timestamp of the previous midnight as our starting point. This will be before the start date but we'll add 24 hours to it in the next step
        var midnightDate = startDate.toMidnight()
            
        // add 24hrs to the midnightDate and add it to the xAxisValues array. Repeat until we've gone past the endDate. The first loop will always work. Subsequent loops will be processed if the mini-chart hours to show is long enough
        repeat {
            
            // add 24 hours to midnightDate
            midnightDate = midnightDate.addingTimeInterval(60 * 60 * 24)
            
            xAxisValues += [ ChartAxisValueDate(date: midnightDate, formatter: data().axisLabelTimeFormatter, labelSettings: data().chartLabelSettingsHidden) ]
            
        } while midnightDate < endDate
        
        xAxisValues += [ ChartAxisValueDate(date: endDate, formatter: data().axisLabelTimeFormatter, labelSettings: data().chartLabelSettingsHidden) ]
        
        // don't show the first and last hour, because this is usually not something like 13 but rather 13:26
        xAxisValues.first?.hidden = true
        xAxisValues.last?.hidden = false
        
        guard xAxisValues.count > 1 else {return nil}
        
        let xAxisModel = ChartAxisModel(axisValues: xAxisValues)
        
        // just to save typing
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // create yAxisValues, start with 38 mgdl, this is to make sure we show a bit lower than the real lowest value which is usually 40 mgdl, make the label hidden. We must do this with by using a clear color label setting as the hidden property doesn't work (even if we don't know why).
        let firstYAxisValue = ChartAxisValueDouble((ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl).mgDlToMmol(mgDl: isMgDl), labelSettings: data().chartLabelSettingsHidden)
        
        // create now the yAxisValues and add the first
        var yAxisValues = [firstYAxisValue as ChartAxisValue]
        
        yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.highMarkValueInUserChosenUnit.bgValueRounded(mgDl: isMgDl), labelSettings: data().chartLabelSettingsHidden) as ChartAxisValue]

        if maximumValueInGlucoseChartPointsInMgDl.mgDlToMmol(mgDl: isMgDl) >
            UserDefaults.standard.highMarkValueInUserChosenUnit.bgValueRounded(mgDl: isMgDl) {
            yAxisValues += [ChartAxisValueDouble((maximumValueInGlucoseChartPointsInMgDl.mgDlToMmol(mgDl: isMgDl)), labelSettings: data().chartLabelSettingsHidden) as ChartAxisValue]
        }
        
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: ConstantsGlucoseChart.axisLineColor, labelSpaceReservationMode: .fixed(0))
        
        // put Y axis on right side
        let coordsSpace = ChartCoordsSpaceRightBottomSingleAxis(chartSettings: data().chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)
        
        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
        
        // now that we know innerFrame we can set innerFrameWidth
        innerFrameWidth = Double(innerFrame.width)
                
        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: data().chartGuideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: [])
        
        // Guidelines
        let highLowLineLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: ConstantsGlucoseChart.guidelineMiniChartHighLowColor, linesWidth: 0.3, dotWidth: 3, dotSpacing: 3)
        
        let highLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: highLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.highMarkValueInUserChosenUnit)])
        
        let lowLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: highLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.lowMarkValueInUserChosenUnit)])
        
        // glucose circle diameter for the mini-chart, declared here to save typing
        let glucoseCircleDiameter: CGFloat = ConstantsGlucoseChart.miniChartGlucoseCircleDiameter
        
        // In Range circle layers
        let inRangeGlucoseCircles = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: inRangeGlucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter, height: glucoseCircleDiameter), itemFillColor: ConstantsGlucoseChart.glucoseInRangeColor, optimized: true)

        // urgent Range circle layers
        let urgentRangeGlucoseCircles = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: urgentRangeGlucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter, height: glucoseCircleDiameter), itemFillColor: ConstantsGlucoseChart.glucoseUrgentRangeColor, optimized: true)

        // above target circle layers
        let notUrgentRangeGlucoseCircles = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: notUrgentRangeGlucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter, height: glucoseCircleDiameter), itemFillColor: ConstantsGlucoseChart.glucoseNotUrgentRangeColor, optimized: true)

        let layers: [ChartLayer?] = [
            gridLayer,
            // guideline layers
            highLineLayer,
            lowLineLayer,
            // glucosePoint layers
            inRangeGlucoseCircles,
            notUrgentRangeGlucoseCircles,
            urgentRangeGlucoseCircles
        ]
        
        return Chart(
            frame: frame,
            innerFrame: innerFrame,
            settings: data().chartSettings,
            layers: layers.compactMap { $0 }
        )
    }
    
    /// - returns:
    ///     - tuple of three chartpoint arrays, with readings that have calculatedvalue> 0, order ascending, ie first element is the oldest
    ///     - the three arrays in the tuple according to value compared to lowMarkValue, highMarkValue,  urgentHighMarkValue, urgentLowMarkValue stored in UserDefaults
    ///     - the firstGlucoseChartPoint in the tuple is the oldest ChartPoint in the three arrays
    ///     - the lastGlucoseChartPoint in the tuple is the most recent ChartPoint in the three arrays
    private func getGlucoseChartPoints(startDate: Date, endDate: Date, bgReadingsAccessor: BgReadingsAccessor, on managedObjectContext: NSManagedObjectContext) -> GlucoseChartPointsType {
        
        // get bgReadings between the two dates
        let bgReadings = bgReadingsAccessor.getBgReadings(from: startDate, to: endDate, on: managedObjectContext)

        // intialize the three arrays
        var urgentRangeChartPoints = [ChartPoint]()
        var inRangeChartPoints = [ChartPoint]()
        var notUrgentRangeChartPoints = [ChartPoint]()
        
        // initiliaze maximumValueInGlucoseChartPoints
        var maximumValueInGlucoseChartPoints: Double?
        
        // bgReadings array has been fetched from coredata using a private mangedObjectContext
        // we need to use the same context to perform next piece of code which will use those bgReadings, in order to stay thread-safe
        managedObjectContext.performAndWait {
            
            for reading in bgReadings {
                
                if reading.calculatedValue > 0.0 {
                    
                    let newGlucoseChartPoint = ChartPoint(bgReading: reading, formatter: data().chartPointDateFormatter, unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                    
                    if (reading.calculatedValue < UserDefaults.standard.lowMarkValue && reading.calculatedValue > UserDefaults.standard.urgentLowMarkValue) || (reading.calculatedValue > UserDefaults.standard.highMarkValue && reading.calculatedValue < UserDefaults.standard.urgentHighMarkValue) {
                        
                        notUrgentRangeChartPoints.append(newGlucoseChartPoint)
                        
                    } else if reading.calculatedValue >= UserDefaults.standard.urgentHighMarkValue || reading.calculatedValue <= UserDefaults.standard.urgentLowMarkValue {
                        
                        urgentRangeChartPoints.append(newGlucoseChartPoint)
                        
                    } else {
                        
                        inRangeChartPoints.append(newGlucoseChartPoint)
                        
                    }
                    
                    maximumValueInGlucoseChartPoints = (maximumValueInGlucoseChartPoints != nil ? max(maximumValueInGlucoseChartPoints!, reading.calculatedValue) : reading.calculatedValue)
                    
                }
                
            }

        }
        
        return (urgentRangeChartPoints, inRangeChartPoints, notUrgentRangeChartPoints, maximumValueInGlucoseChartPoints)
        
    }
    

    /// - set data to nil, will be called eg to clean up memory when going to the background
    /// - all needed variables will will be reinitialized as soon as data() is called
    private func nillifyData() {
        
        glucoseChartPoints = ([ChartPoint](), [ChartPoint](), [ChartPoint](), nil)
        
        chartSettings = nil
        
        chartPointDateFormatter = nil
        
        operationQueue = nil
        
        chartLabelSettings = nil
        
        chartGuideLinesLayerSettings = nil
        
        axisLabelTimeFormatter = nil
        
        bgReadingsAccessor = nil
        
        urgentRangeGlucoseChartPoints = []

        inRangeGlucoseChartPoints = []

        notUrgentRangeGlucoseChartPoints = []
        
        chartLabelSettingsHidden = nil

    }
    
    /// function which gives is variables that are set back to nil when nillifyData is called
        private func data() -> (chartSettings: ChartSettings, chartPointDateFormatter: DateFormatter, operationQueue: OperationQueue, chartLabelSettings: ChartLabelSettings,  chartLabelSettingsHidden: ChartLabelSettings, chartGuideLinesLayerSettings: ChartGuideLinesLayerSettings, axisLabelTimeFormatter: DateFormatter, bgReadingsAccessor: BgReadingsAccessor){
        
        // setup chartSettings
        if chartSettings == nil {
            
            var newChartSettings = ChartSettings()
            newChartSettings.top = 10
            newChartSettings.bottom = 15
            newChartSettings.trailing = 10
            newChartSettings.leading = 10
            newChartSettings.axisTitleLabelsToLabelsSpacing = 0
            newChartSettings.labelsToAxisSpacingX = 0
            newChartSettings.spacingBetweenAxesX = 0
            newChartSettings.labelsSpacing = 0
            newChartSettings.labelsToAxisSpacingY = 0
            newChartSettings.spacingBetweenAxesY = 0
            newChartSettings.axisStrokeWidth = 0
            
            newChartSettings.clipInnerFrame = false
            
            chartSettings = newChartSettings
            
        }
        
        // setup chartPointDateFormatter
        if chartPointDateFormatter == nil {
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .none
            
            chartPointDateFormatter = dateFormatter
            
        }
        
        // setup operationqueue
        if operationQueue == nil {
            // initialize operationQueue
            operationQueue = OperationQueue()
            
            // operationQueue will be queue of blocks that gets readings and updates glucoseChartPoints, startDate and endDate. To avoid race condition, the operations should be one after the other
            operationQueue!.maxConcurrentOperationCount = 1
        }
        
        // intialize chartlabelsettings - this is used for the standard grid labels
        if chartLabelSettings == nil {
            chartLabelSettings = ChartLabelSettings(
                font: .systemFont(ofSize: 1),
                fontColor: ConstantsGlucoseChart.axisLabelColor
            )
        }
        
        
        // intialize chartlabelsettingsHidden - used to hide the first 38mg/dl value etc
        if chartLabelSettingsHidden == nil {
            chartLabelSettingsHidden = ChartLabelSettings(
                fontColor: ConstantsGlucoseChart.axisLabelColorHidden
            )
        }
        
        // intialize chartGuideLinesLayerSettingsalp
        if chartGuideLinesLayerSettings == nil {
            chartGuideLinesLayerSettings = ChartGuideLinesLayerSettings(linesColor: UIColor.darkGray.withAlphaComponent(0.8), linesWidth: 1.5)
        }
            
        // intialize axisLabelTimeFormatter
        if axisLabelTimeFormatter == nil {
            axisLabelTimeFormatter = DateFormatter()
            axisLabelTimeFormatter?.timeStyle = .none
            axisLabelTimeFormatter?.dateStyle = .none
        }
            
        // initialize bgReadingsAccessor
        if bgReadingsAccessor == nil {
            bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        }
        
        return (chartSettings!, chartPointDateFormatter!, operationQueue!, chartLabelSettings!, chartLabelSettingsHidden!, chartGuideLinesLayerSettings!,  axisLabelTimeFormatter!, bgReadingsAccessor!)
        
    }
    
    /// finds new maximum, either currentMaximumValueInGlucoseChartPoints, or glucoseChartPoints.maximumValueInGlucoseChartPoints
    /// - if both input values are nil, then returns constants
    private func getNewMaximumValueInGlucoseChartPoints(currentMaximumValueInGlucoseChartPoints: Double?, glucoseChartPoints: GlucoseChartPointsType) -> Double {
        
        // check if there's already a value for maximumValueInGlucoseChartPoints
        if let currentMaximumValueInGlucoseChartPoints = currentMaximumValueInGlucoseChartPoints {
            
            // check if there's a new value
            if let newMaximumValueInGlucoseChartPoints = glucoseChartPoints.maximumValueInGlucoseChartPoints {

                // return the maximum of the two
                return max(currentMaximumValueInGlucoseChartPoints, newMaximumValueInGlucoseChartPoints)

            } else {
                
                return currentMaximumValueInGlucoseChartPoints
                
            }
            
        } else {

            // there's no currentMaximumValueInGlucoseChartPoints, if glucoseChartPoints.maximumValueInGlucoseChartPoints not nil, return it
            if let maximumValueInGlucoseChartPoints = glucoseChartPoints.maximumValueInGlucoseChartPoints {
                return maximumValueInGlucoseChartPoints
            } else {
                return ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            }
            
        }

    }
    
}

