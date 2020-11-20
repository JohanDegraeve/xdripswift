import Foundation
import HealthKit
import SwiftCharts
import os.log
import UIKit

public final class GlucoseChartManager {
    
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
    private var oslog = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryGlucoseChartManager)

    private var chartSettings: ChartSettings?

    private let labelsWidthY = ConstantsGlucoseChart.yAxisLabelsWidth

    private var chartLabelSettings: ChartLabelSettings?

    private var chartGuideLinesLayerSettings: ChartGuideLinesLayerSettings?
    
    /// The latest date on the X-axis
    private var endDate: Date
    
    /// The earliest date on the X-axis
    private var startDate: Date

    /// the chart with glucose values
    private var glucoseChart: Chart?
    
    /// dateformatter for timestamp in chartpoints
    private var chartPointDateFormatter: DateFormatter?
    
    /// timeformatter for horizontal axis label
    private var axisLabelTimeFormatter: DateFormatter?
    
    /// a BgReadingsAccessor
    private var bgReadingsAccessor: BgReadingsAccessor?
    
    /// a coreDataManager
    private var coreDataManager: CoreDataManager
    
    /// difference in seconds between two pixels (or x values, not sure if it's pixels)
    private var diffInSecondsBetweenTwoPoints: Double  {
        endDate.timeIntervalSince(startDate)/Double(innerFrameWidth)
    }
    
    /// innerFrame width
    ///
    /// default value 300.0 which is probably not correct but it can't be initiated as long as glusoseChart is not initialized, to avoid having to work with optional, i assign it to 300.0
    private var innerFrameWidth: Double = 300.0
    
    /// used for getting bgreadings on a background thread, bgreadings are used to create list of chartPoints
    private var operationQueue: OperationQueue?
    
    /// This timer is used when decelerating the chart after end of panning.  We'll set a timer, each time the timer expires the chart will be shifted a bit
    private var gestureTimer:RepeatingTimer?
    
    /// used when user touches the chart. Deceleration is maybe still ongoing (from a previous pan). If set to true, then deceleration needs to be stopped
    private var stopDecelerationNextGestureTimerRun = false
    
    /// - the maximum value in glucoseChartPoints array between start and endPoint
    /// - the value will never get smaller during the run time of the app
    private var maximumValueInGlucoseChartPoints:Double = ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    
    /// - if glucoseChartPoints.count > 0, then this is the latest one that has timestamp less than endDate.
    private(set) var lastChartPointEarlierThanEndDate: ChartPoint?
    
    /// is chart in panned state or not, meaning is it currently shifted back in time
    private(set) var chartIsPannedBackward: Bool = false
    
    // MARK: - intializer
    
    /// - parameters:
    ///     - chartLongPressGestureRecognizer : defined here as parameter so that this class can handle the config of the recognizer
    init(chartLongPressGestureRecognizer: UILongPressGestureRecognizer, coreDataManager: CoreDataManager) {
        
        // set coreDataManager and bgReadingsAccessor
        self.coreDataManager = coreDataManager
        
        // for tapping the chart, we're using UILongPressGestureRecognizer because UITapGestureRecognizer doesn't react on touch down. With UILongPressGestureRecognizer and minimumPressDuration set to 0, we get a trigger as soon as the chart is touched
        chartLongPressGestureRecognizer.minimumPressDuration = 0

        // initialize enddate
        endDate = Date()
        
        // intialize startdate, which is enddate minus a few hours
        startDate = endDate.addingTimeInterval(.hours(-UserDefaults.standard.chartWidthInHours))
        
    }
    
    // MARK: - public functions
    
    /// - updates the glucoseChartPoints array , and the chartOutlet, and calls completionHandler when finished
    /// - if called multiple times after each other (eg because user is panning or zooming fast) there might be calls skipped,
    /// - completionhandler will be called when chartOutlet is updated
    /// - parameters:
    ///     - completionHandler : will be called when glucoseChartPoints and chartOutlet are updated
    ///     - endDate :endDate to apply
    ///     - startDate :startDate to apply, if nil then no change will be done in chart width, ie current difference between start and end will be reused
    ///
    /// update of glucoseChartPoints array will be done on background thread. The actual redrawing of the chartoutlet is  done on the main thread. Also the completionHandler runs in the main thread.
    /// While updating glucoseChartPoints in background thread, the main thread may call again updateGlucoseChartPoints with a new endDate (because the user is panning or zooming). A new block will be added in the operation queue and processed later. If there's multiple operations waiting in the queue, only the last one will be executed. This can be the case when the user is doing a fast panning.
    public func updateGlucoseChartPoints(endDate: Date, startDate: Date?, chartOutlet: BloodGlucoseChartView, completionHandler: (() -> ())?) {

        // create a new operation
        let operation = BlockOperation(block: {
            
            // if there's more than one operation waiting for execution, it makes no sense to execute this one, the next one has a newer endDate to use
            guard self.data().operationQueue.operations.count <= 1 else {
                return
            }
            
            // startDateToUse is either parameter value or (if nil), endDate minutes current chartwidth
            let startDateToUse = startDate != nil ? startDate! : Date(timeInterval: -self.endDate.timeIntervalSince(self.startDate), since: endDate)
            
            // we're going to check if we have already all chartpoints in the array self.glucoseChartPoints for the new start and date time. If not we're going to prepand a new array and/or append a new array
            
            // initialize new list of glucoseChartPoints to prepend
            var newGlucoseChartPointsToPrepend = [ChartPoint]()

            // initialize new list of glucoseChartPoints to append
            var newGlucoseChartPointsToAppend = [ChartPoint]()
            
            // do we reuse the existing list ? for instance if new startDate > date of currently stored last chartpoint, then we don't reuse the existing list, probably better to reinitialize from scratch to avoid ending up with too long lists
            // and if there's more than a predefined amount of elements already in the array then we restart from scratch because (on an iPhone SE with iOS 13), the panning is getting slowed down when there's more than 1000 elements in the array
            var reUseExistingChartPointList = self.glucoseChartPoints.count <= ConstantsGlucoseChart.maximumElementsInGlucoseChartPointsArray ? true:false

            if let lastGlucoseChartPoint = self.glucoseChartPoints.last, let lastGlucoseChartPointX = lastGlucoseChartPoint.x as? ChartAxisValueDate {
                
                // if reUseExistingChartPointList = false, then we're actually forcing to use a complete new array, because the current array glucoseChartPoints is too big. If true, then we start from timestamp of the last chartpoint
                let lastGlucoseTimeStamp = reUseExistingChartPointList ? lastGlucoseChartPointX.date : Date(timeIntervalSince1970: 0)
                
                // first see if we need to append new chartpoints
                if startDateToUse > lastGlucoseTimeStamp {
                    
                    // startDate is bigger than the the date of the last currently stored ChartPoint, let's reinitialize the glucosechartpoints
                    reUseExistingChartPointList = false
                
                    // use newGlucoseChartPointsToAppend and assign it to new list of chartpoints startDate to endDate
                    newGlucoseChartPointsToAppend = self.getGlucoseChartPoints(startDate: startDateToUse, endDate: endDate, bgReadingsAccessor: self.data().bgReadingsAccessor)
                    
                } else if endDate <= lastGlucoseTimeStamp {
                    // so starDate <= date of last known glucosechartpoint and enddate is also <= that date
                    // no need to append anything
                } else {
                    
                    // append glucseChartpoints with date > x.date up to endDate
                    newGlucoseChartPointsToAppend = self.getGlucoseChartPoints(startDate: lastGlucoseTimeStamp, endDate: endDate, bgReadingsAccessor: self.data().bgReadingsAccessor)
                }
                
                // now see if we need to prepend
                // if reUseExistingChartPointList = false, then it means startDate > date of last know glucosepoint, there's no need to prepend
                if reUseExistingChartPointList {
                    
                    if let firstGlucoseChartPoint = self.glucoseChartPoints.first, let firstGlucoseChartPointX = firstGlucoseChartPoint.x as? ChartAxisValueDate, startDateToUse < firstGlucoseChartPointX.date {
                        
                        newGlucoseChartPointsToPrepend = self.getGlucoseChartPoints(startDate: startDateToUse, endDate: firstGlucoseChartPointX.date, bgReadingsAccessor: self.data().bgReadingsAccessor)
                    }
                    
                }
                
            } else {
                
                // this should be a case where there's no glucoseChartPoints stored yet, we just create a new array to append

                // get glucosePoints from coredata
                newGlucoseChartPointsToAppend = self.getGlucoseChartPoints(startDate: startDateToUse, endDate: endDate, bgReadingsAccessor: self.data().bgReadingsAccessor)
            }
            
            // recalculate maximumValueInGlucoseChartPoints, there may be a higher value in newGlucoseChartPointsToAppend
            for glucoseChartPoint in newGlucoseChartPointsToAppend {
                
                self.maximumValueInGlucoseChartPoints = max(self.maximumValueInGlucoseChartPoints, glucoseChartPoint.y.scalar)
                
            }
            
            // recalculate maximumValueInGlucoseChartPoints, there may be a higher value in newGlucoseChartPointsToPrepend
            for glucoseChartPoint in newGlucoseChartPointsToPrepend {
                
                self.maximumValueInGlucoseChartPoints = max(self.maximumValueInGlucoseChartPoints, glucoseChartPoint.y.scalar)
                
            }
            
            // closure will iterate through glucoseChartPoints and find latest date earlier than endDate and larger then startdate, if there isn't any it returns nil
            let findLastChartPointEarlierThanEndDateInArray = { (_ glucoseChartPoints : [ChartPoint]) -> ChartPoint? in
                
                for (_, glucoseChartPoint) in glucoseChartPoints.enumerated().reversed() {
                    
                    if let chartAxisValueDate = glucoseChartPoint.x as? ChartAxisValueDate {
                        
                        if chartAxisValueDate.date < endDate {
                            
                            return glucoseChartPoint
                            
                        } else if let startDate = startDate, chartAxisValueDate.date < startDate {
                            
                            return nil
                            
                        }
                        
                    }
                }
                
                return nil
                
            }
            
            // now calculate lastChartPointEarlierThanEndDate by using findLastChartPointEarlierThanEndDateInArray for newGlucoseChartPointsToAppend, newGlucoseChartPointsToPrepend and glucoseChartPoints
            self.lastChartPointEarlierThanEndDate = findLastChartPointEarlierThanEndDateInArray(newGlucoseChartPointsToAppend)
            if self.lastChartPointEarlierThanEndDate == nil && reUseExistingChartPointList {
                self.lastChartPointEarlierThanEndDate = findLastChartPointEarlierThanEndDateInArray(self.glucoseChartPoints)
            }
            if self.lastChartPointEarlierThanEndDate == nil {
                self.lastChartPointEarlierThanEndDate = findLastChartPointEarlierThanEndDateInArray(newGlucoseChartPointsToPrepend)
            }
            
            DispatchQueue.main.async {
                
                // so we're in the main thread, now endDate and startDate and glucoseChartPoints can be safely assigned to value that was passed in the call to updateGlucoseChartPoints
                self.endDate = endDate
                self.startDate = startDateToUse
                self.glucoseChartPoints = newGlucoseChartPointsToPrepend + (reUseExistingChartPointList ? self.glucoseChartPoints : [ChartPoint]()) + newGlucoseChartPointsToAppend

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
    
    /// handles either UIPanGestureRecognizer or UILongPressGestureRecognizer.  UILongPressGestureRecognizer is there to detect taps
    /// - parameters:
    ///     - completionhandler : any block that caller wants to see executed when chart has been updated
    ///     - chartOutlet : needed to trigger updated of chart
    public func handleUIGestureRecognizer(recognizer: UIGestureRecognizer, chartOutlet: BloodGlucoseChartView, completionHandler: (() -> ())?) {
        
        if let uiPanGestureRecognizer = recognizer as? UIPanGestureRecognizer {
            
            handleUiPanGestureRecognizer(uiPanGestureRecognizer: uiPanGestureRecognizer, chartOutlet: chartOutlet, completionHandler: completionHandler)

        } else if let uiLongPressGestureRecognizer = recognizer as? UILongPressGestureRecognizer {
            
            handleUiLongPressGestureRecognizer(uiLongPressGestureRecognizer: uiLongPressGestureRecognizer, chartOutlet: chartOutlet)
            
        }
        
    }
    
    // MARK: - private functions

    private func stopDeceleration() {
        
        // user touches the chart, in case we're handling a decelerating gesture, stop it
        // call to suspend doesn't really seem to stop the deceleration, that's why also setting to nil and using stopDecelerationNextGestureTimerRun
        gestureTimer?.suspend()
        gestureTimer = nil
        stopDecelerationNextGestureTimerRun = true

    }
    
    private func handleUiLongPressGestureRecognizer(uiLongPressGestureRecognizer: UILongPressGestureRecognizer, chartOutlet: BloodGlucoseChartView) {
        
        if uiLongPressGestureRecognizer.state == .began {
            
            stopDeceleration()
            
        }
        
    }

    private func handleUiPanGestureRecognizer(uiPanGestureRecognizer: UIPanGestureRecognizer, chartOutlet: BloodGlucoseChartView, completionHandler: (() -> ())?) {

        if uiPanGestureRecognizer.state == .began {

            // user touches the chart, possibily chart is still decelerating from a previous pan. Needs to be stopped
            stopDeceleration()
            
        }
        
        let translationX = uiPanGestureRecognizer.translation(in: uiPanGestureRecognizer.view).x
        
        // if translationX negative and if not chartIsPannedBackward, then stop processing, we're not going back to the future
        if !chartIsPannedBackward && translationX < 0 {
            uiPanGestureRecognizer.setTranslation(CGPoint.zero, in: chartOutlet)
            
            return
            
        }
        
        // user either started panning backward or continues panning (back or forward). Assume chart is currently in backward panned state, which is not necessarily true
        chartIsPannedBackward = true
        
        if uiPanGestureRecognizer.state == .ended {
            
            // user has lifted finger. Deceleration needs to be done.
            decelerate(translationX: translationX, velocityX: uiPanGestureRecognizer.velocity(in: uiPanGestureRecognizer.view).x, chartOutlet: chartOutlet, completionHandler: {
                
                uiPanGestureRecognizer.setTranslation(CGPoint.zero, in: chartOutlet)
                
                // call the completion handler that was created by the original caller, in this case RootViewController created this code block
                if let completionHandler = completionHandler {
                    completionHandler()
                }
                
            })
            
        } else {
            
            // ongoing panning
            
            // this will update the chart and set new start and enddate, for specific translation
            setNewStartAndEndDate(translationX: translationX, chartOutlet: chartOutlet, completionHandler: {
                
                uiPanGestureRecognizer.setTranslation(CGPoint.zero, in: chartOutlet)

                // call the completion handler that was created by the original caller, in this case RootViewController created this code block
                if let completionHandler = completionHandler {
                    completionHandler()
                }

            })
            
        }

    }
    
    /// - will call setNewStartAndEndDate with a new translationX value, every x milliseconds, x being 30 milliseconds by default as defined in the constants.
    /// - Every time the new values are set, the completion handler will be called
    /// - Every time the new values are set, chartOutlet will be updated
    private func decelerate(translationX: CGFloat, velocityX: CGFloat, chartOutlet: BloodGlucoseChartView, completionHandler: @escaping () -> ()) {
        
        //The default deceleration rate is λ = 0.998, meaning that the scroll view loses 0.2% of its velocity per millisecond.
        //The distance traveled is the area under the curve in a velocity-time-graph, thus the distance traveled until the content comes to rest is the integral of the velocity from zero to infinity.
        // current deceleration = v*λ^t, t in milliseconds
        // distanceTravelled = integral of current deceleration from 0 to actual time = λ^t/ln(λ) - λ^0/ln(λ)
        // this is multiplied with 0.001, I don't know why but the result matches the formula that is advised by Apple to calculate target x, target x would be translationX + (velocityX / 1000.0) * decelerationRate / (1.0 - decelerationRate)
        
        /// this is the integral calculated for time 0
        let constant = Double(velocityX) *  pow(Double(ConstantsGlucoseChart.decelerationRate), 0.0) / log(Double(ConstantsGlucoseChart.decelerationRate))
        
        /// the start time, actual elapsed time will always be calculated agains this value
        let initialStartOfDecelerationTimeStampInMilliseconds = Date().toMillisecondsAsDouble()
        
        /// initial distance travelled is nul, this will be increased each time
        var distanceTravelled: CGFloat = 0.0
        
        // set stopDecelerationNextGestureTimerRun to false initially
        stopDecelerationNextGestureTimerRun = false
        
        // at regular intervals new distance to travel the chart will be calculated and setNewStartAndEndDate will be called
        gestureTimer = RepeatingTimer(timeInterval: TimeInterval(Double(ConstantsGlucoseChart.decelerationTimerValueInSeconds)), eventHandler: {
            
            // if stopDecelerationNextGestureTimerRun is set, then return
            if self.stopDecelerationNextGestureTimerRun {
                return
            }
            
            // what is the elapsed time since the user ended the panning
            let timeSinceStart = Date().toMillisecondsAsDouble() - initialStartOfDecelerationTimeStampInMilliseconds
            
            // calculate additional distance to travel the chart - this is the integral function again that is used
            let additionalDistanceToTravel = CGFloat(round(0.001*(
                
                Double(velocityX) *  pow(Double(ConstantsGlucoseChart.decelerationRate), timeSinceStart) / log(Double(ConstantsGlucoseChart.decelerationRate))
                    
                    - constant))) - distanceTravelled
            
            // if less than 2 pixels then stop the gestureTimer
            if abs(additionalDistanceToTravel) < 2 {
                self.stopDeceleration()
            }
            
            self.setNewStartAndEndDate(translationX: translationX + additionalDistanceToTravel, chartOutlet: chartOutlet, completionHandler: completionHandler)
            
            // increase distance already travelled
            distanceTravelled += additionalDistanceToTravel
            
        })
        
        // start the timer
        gestureTimer?.resume()
        
    }
    
    /// - calculates new startDate and endDate
    /// - updates glucseChartPoints array for given translation
    /// - uptdates chartOutlet
    /// - calls block in completion handler.
    private func setNewStartAndEndDate(translationX: CGFloat, chartOutlet: BloodGlucoseChartView, completionHandler: @escaping () -> ()) {
        
        // calculate new start and enddate, based on how much the user's been panning
        var newEndDate = endDate.addingTimeInterval(-diffInSecondsBetweenTwoPoints * Double(translationX))
        
        // maximum value should be current date
        if newEndDate > Date() {
            
            newEndDate = Date()
            
            // this is also the time to set chartIsPannedBackward to false, user is panning back to the future, he can not pan further than the endDate so that chart will not be any panned state anymore
            chartIsPannedBackward = false
            
            // stop the deceleration
            stopDeceleration()
            
        }
        
        // newStartDate = enddate minus current difference between endDate and startDate
        let newStartDate = Date(timeInterval: -self.endDate.timeIntervalSince(self.startDate), since: newEndDate)
        
        updateGlucoseChartPoints(endDate: newEndDate, startDate: newStartDate, chartOutlet: chartOutlet, completionHandler: completionHandler)
        
    }
    
    private func generateGlucoseChartWithFrame(_ frame: CGRect) -> Chart? {

        let xAxisValues = generateXAxisValues()
        
        guard xAxisValues.count > 1 else {return nil}
        
        let xAxisModel = ChartAxisModel(axisValues: xAxisValues, lineColor: ConstantsGlucoseChart.axisLineColor, labelSpaceReservationMode: .fixed(20))

        // just to save typing
        let unitIsMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // create yAxisValues, start with 38 mgdl, this is to make sure we show a bit lower than the real lowest value which is usually 40 mgdl, make the label hidden
        let firstYAxisValue = ChartAxisValueDouble((ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl).mgdlToMmol(mgdl: unitIsMgDl), labelSettings: data().chartLabelSettings)
        firstYAxisValue.hidden = true
        
        // create now the yAxisValues and add the first
        var yAxisValues = [firstYAxisValue as ChartAxisValue]
        
        // add first series
        if unitIsMgDl {
            yAxisValues += ConstantsGlucoseChart.initialGlucoseValueRangeInMgDl.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
        } else {
            yAxisValues += ConstantsGlucoseChart.initialGlucoseValueRangeInMmol.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
        }
        
        // if the maxium yAxisValue doesn't support the maximum glucose value, then add the next range
        if yAxisValues.last!.scalar < maximumValueInGlucoseChartPoints {
            if unitIsMgDl {
                yAxisValues += ConstantsGlucoseChart.secondGlucoseValueRangeInMgDl.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
            } else {
                yAxisValues += ConstantsGlucoseChart.secondGlucoseValueRangeInMmol.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
            }
        }

        // if the maxium yAxisValue doesn't support the maximum glucose value, then add the next range
        if yAxisValues.last!.scalar < maximumValueInGlucoseChartPoints {
            if unitIsMgDl {
                yAxisValues += ConstantsGlucoseChart.thirdGlucoseValueRangeInMgDl.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
            } else {
                yAxisValues += ConstantsGlucoseChart.thirdGlucoseValueRangeInMmol.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
            }
        }
        
        // the last label should not be visible
        yAxisValues.last?.hidden = true
        
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: ConstantsGlucoseChart.axisLineColor, labelSpaceReservationMode: .fixed(labelsWidthY))
        
        // put Y axis on right side
        let coordsSpace = ChartCoordsSpaceRightBottomSingleAxis(chartSettings: data().chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)
        
        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
        
        // now that we know innerFrame we can set innerFrameWidth
        innerFrameWidth = Double(innerFrame.width)
        
        
        chartGuideLinesLayerSettings = ChartGuideLinesLayerSettings(linesColor: UserDefaults.standard.useObjectives ? ConstantsGlucoseChart.gridColorObjectives : ConstantsGlucoseChart.gridColor,  linesWidth: 0.5)
        
        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: data().chartGuideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)
        
        // high/low/target guideline layer settings and styles
        let urgentHighLowLineLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: UserDefaults.standard.showColoredObjectives ? ConstantsGlucoseChart.guidelineUrgentHighLowColor : ConstantsGlucoseChart.guidelineUrgentHighLow, linesWidth: UserDefaults.standard.useObjectives ? 1 : 0, dotWidth: 2, dotSpacing: 5)
        
        let highLowLineLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: UserDefaults.standard.showColoredObjectives ? ConstantsGlucoseChart.guidelineHighLowColor : ConstantsGlucoseChart.guidelineHighLow, linesWidth: UserDefaults.standard.useObjectives ? 1 : 0, dotWidth: 4, dotSpacing: 2)
        
        let targetLineLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: ConstantsGlucoseChart.guidelineTargetColor, linesWidth: UserDefaults.standard.useObjectives ? (UserDefaults.standard.showTarget ? 1 : 0) : 0, dotWidth: 4, dotSpacing: 0)
        
        // high/low/target guidelines
        let urgentHighLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: urgentHighLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.urgentHighMarkValueInUserChosenUnit)])

        let highLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: highLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.highMarkValueInUserChosenUnit)])
        
        let targetLineLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: targetLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.targetMarkValueInUserChosenUnit)])

        let lowLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: highLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.lowMarkValueInUserChosenUnit)])

        let urgentLowLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: urgentHighLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.urgentLowMarkValueInUserChosenUnit)])
        
        // red/yellow/green circle layers
        let glucoseCircles = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: glucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: ConstantsGlucoseChart.glucoseCircleDiameter, height: ConstantsGlucoseChart.glucoseCircleDiameter), itemFillColor: ConstantsGlucoseChart.glucoseTintColor, optimized: true)
            
        let layers: [ChartLayer?] = [
            gridLayer,
            xAxisLayer,
            yAxisLayer,
            // guideline layers
            urgentHighLineLayer,
            highLineLayer,
            targetLineLayer,
            lowLineLayer,
            urgentLowLineLayer,
            // glucosePoint layer(s)
            glucoseCircles,
        ]
        
        return Chart(
            frame: frame,
            innerFrame: innerFrame,
            settings: data().chartSettings,
            layers: layers.compactMap { $0 }
        )
    }

    private func generateXAxisValues() -> [ChartAxisValue] {

        // in the comments, assume it is now 13:26 and width is 6 hours, that means startDate = 07:26, endDate = 13:26
        
        /// how many full hours between startdate and enddate
        let amountOfFullHours = Int(ceil(endDate.timeIntervalSince(startDate).hours))
        
        /// create array that goes from 1 to number of full hours, as helper to map to array of ChartAxisValueDate - array will go from 1 to 6
        let mappingArray = Array(1...amountOfFullHours)
        
        /// first, for each int in mappingArray, we create a ChartAxisValueDate, which will have as date one of the hours, starting with the lower hour + 1 hour - we will create 5 in this example, starting with hour 08 (7 + 3600 seconds)
        let startDateLower = startDate.toLowerHour()
        var xAxisValues: [ChartAxisValue] = mappingArray.map { ChartAxisValueDate(date: Date(timeInterval: Double($0)*3600, since: startDateLower), formatter: data().axisLabelTimeFormatter, labelSettings: data().chartLabelSettings) }
        
        /// insert the start Date as first element, in this example 07:26
        xAxisValues.insert(ChartAxisValueDate(date: startDate, formatter: data().axisLabelTimeFormatter, labelSettings: data().chartLabelSettings), at: 0)
        
        /// now append the endDate as last element, in this example 13:26
        xAxisValues.append(ChartAxisValueDate(date: endDate, formatter: data().axisLabelTimeFormatter, labelSettings: data().chartLabelSettings))
         
        /// don't show the first and last hour, because this is usually not something like 13 but rather 13:26
        xAxisValues.first?.hidden = true
        xAxisValues.last?.hidden = true

        return xAxisValues
        
    }
    
    /// gets array of chartpoints that have a calculatedValue > 0 and date > startDate (not equal to) and < endDate (not equal to), from coreData
    /// - returns:
    ///     - chartpoints for readings that have calculatedvalue > 0, order ascending, ie first element is the oldest
    private func getGlucoseChartPoints(startDate: Date, endDate: Date, bgReadingsAccessor: BgReadingsAccessor) -> [ChartPoint] {
        
        return bgReadingsAccessor.getBgReadingsOnPrivateManagedObjectContext(from: startDate, to: endDate).compactMap {
            
            ChartPoint(bgReading: $0, formatter: data().chartPointDateFormatter, unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            
        }
    }
    
    /// - set data to nil, will be called eg to clean up memory when going to the background
    /// - all needed variables will will be reinitialized as soon as data() is called
    private func nillifyData() {
        
        stopDeceleration()
        
        glucoseChartPoints = []
        
        chartSettings = nil
        
        chartPointDateFormatter = nil
        
        operationQueue = nil
        
        chartLabelSettings = nil
        
        chartGuideLinesLayerSettings = nil
        
        axisLabelTimeFormatter = nil
        
        bgReadingsAccessor = nil
        
    }
    
    /// function which gives is variables that are set back to nil when nillifyData is called
    private func data() -> (chartSettings: ChartSettings, chartPointDateFormatter: DateFormatter, operationQueue: OperationQueue, chartLabelSettings: ChartLabelSettings, chartGuideLinesLayerSettings: ChartGuideLinesLayerSettings, axisLabelTimeFormatter: DateFormatter, bgReadingsAccessor: BgReadingsAccessor){
        
        // setup chartSettings
        if chartSettings == nil {

            var newChartSettings = ChartSettings()
            newChartSettings.top = ConstantsGlucoseChart.top
            newChartSettings.bottom = ConstantsGlucoseChart.bottom
            newChartSettings.trailing = ConstantsGlucoseChart.trailing
            newChartSettings.leading = ConstantsGlucoseChart.leading
            newChartSettings.axisTitleLabelsToLabelsSpacing = ConstantsGlucoseChart.axisTitleLabelsToLabelsSpacing
            newChartSettings.labelsToAxisSpacingX = ConstantsGlucoseChart.labelsToAxisSpacingX
            newChartSettings.clipInnerFrame = false

            chartSettings = newChartSettings
            
        }
        
        // setup chartPointDateFormatter
        if chartPointDateFormatter == nil {

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .short

            chartPointDateFormatter = dateFormatter
            
        }
        
        // setup operationqueue
        if operationQueue == nil {
            // initialize operationQueue
            operationQueue = OperationQueue()
            
            // operationQueue will be queue of blocks that gets readings and updates glucoseChartPoints, startDate and endDate. To avoid race condition, the operations should be one after the other
            operationQueue!.maxConcurrentOperationCount = 1
        }
        
        // intialize chartlabelsettings
        if chartLabelSettings == nil {
            chartLabelSettings = ChartLabelSettings(
                font: .systemFont(ofSize: 14),
                fontColor: ConstantsGlucoseChart.axisLabelColor
            )
        }
        
        // intialize chartGuideLinesLayerSettings
        if chartGuideLinesLayerSettings == nil {
            chartGuideLinesLayerSettings = ChartGuideLinesLayerSettings(linesColor: UserDefaults.standard.useObjectives ? ConstantsGlucoseChart.gridColorObjectives : ConstantsGlucoseChart.gridColor,  linesWidth: 0.5)
        }
        
        // intialize axisLabelTimeFormatter
        if axisLabelTimeFormatter == nil {
            axisLabelTimeFormatter = DateFormatter()
            axisLabelTimeFormatter!.dateFormat = UserDefaults.standard.chartTimeAxisLabelFormat
        }

        // initialize bgReadingsAccessor
        if bgReadingsAccessor == nil {
            bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        }
        
        return (chartSettings!, chartPointDateFormatter!, operationQueue!, chartLabelSettings!, chartGuideLinesLayerSettings!, axisLabelTimeFormatter!, bgReadingsAccessor!)
        
    }
    
}
