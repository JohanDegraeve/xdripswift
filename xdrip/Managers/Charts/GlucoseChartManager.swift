import Foundation
import HealthKit
import SwiftCharts
import os.log
import UIKit
import CoreData

public class GlucoseChartManager {
    
    /// to hold range of glucose chartpoints
    /// - urgentRange = above urgentHighMarkValue or below urgentLowMarkValue
    /// - in range = between lowMarkValue and highMarkValue
    /// - notUrgentRange = between highMarkValue and urgentHighMarkValue or between urgentLowMarkValue and lowMarkValue
    /// - firstGlucoseChartPoint is the first ChartPoint considering the three arrays together
    /// - lastGlucoseChartPoint is the last ChartPoint considering the three arrays together
    /// - maximumValueInGlucoseChartPoints = the largest x value (ie the highest Glucose value) considering the three arrays together
    typealias GlucoseChartPointsType = (urgentRange: [ChartPoint], inRange: [ChartPoint], notUrgentRange: [ChartPoint], firstGlucoseChartPoint: ChartPoint?, lastGlucoseChartPoint: ChartPoint?, maximumValueInGlucoseChartPoints: Double?)
    
    /// to hold the treatment chartpoints
    /// - smallBolus = bolus values below the micro-bolus threshold (usually around 1.0U or less)
    /// - mediumBolus = all boluses over the micro-bolus threshold ("normal" boluses and will be shown with a label)
    /// - smallCarbs / mediumCarbs / largeCarbs / veryLargeCarbs = groups of each aproximate size to be represented by a different size chart point. The exact carb size context is given using a label
    typealias TreatmentChartPointsType = (smallBolus: [ChartPoint], mediumBolus: [ChartPoint], smallCarbs: [ChartPoint], mediumCarbs: [ChartPoint], largeCarbs: [ChartPoint], veryLargeCarbs: [ChartPoint])
    
    // MARK: - private properties
    
    /// glucoseChartPoints to reuse for each iteration, or for each redrawing of glucose chart
    ///
    /// Whenever glucoseChartPoints is assigned a new value, glucoseChart is set to nil
    private var glucoseChartPoints: GlucoseChartPointsType = ([ChartPoint](), [ChartPoint](), [ChartPoint](), nil, nil, nil) {
        didSet {
            glucoseChart = nil
        }
    }

    /// CalibrationPoints to be shown on chart
    private var calibrationChartPoints = [ChartPoint]()
        
    /// treatmentChartPoints to be shown on chart
    private var treatmentChartPoints: TreatmentChartPointsType = ([ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint]())
        
    /// smallBolusTreatmentChartPoints to be shown on chart
    private var smallBolusTreatmentChartPoints = [ChartPoint]()
    
    /// mediumBolusTreatmentChartPoints to be shown on chart
    private var mediumBolusTreatmentChartPoints = [ChartPoint]()
    
    /// smallCarbsTreatmentChartPoints to be shown on chart
    private var smallCarbsTreatmentChartPoints = [ChartPoint]()
    
    /// mediumCarbsTreatmentChartPoints to be shown on chart
    private var mediumCarbsTreatmentChartPoints = [ChartPoint]()
    
    /// largeCarbsTreatmentChartPoints to be shown on chart
    private var largeCarbsTreatmentChartPoints = [ChartPoint]()
    
    /// veryLargeCarbsTreatmentChartPoints to be shown on chart
    private var veryLargeCarbsTreatmentChartPoints = [ChartPoint]()

    /// ChartPoints to be shown on chart, processed only in main thread - urgent Range
    private var urgentRangeGlucoseChartPoints = [ChartPoint]()
    
    /// ChartPoints to be shown on chart, processed only in main thread - in Range
    private var inRangeGlucoseChartPoints = [ChartPoint]()
    
    /// ChartPoints to be shown on chart, processed only in main thread - not Urgent Range
    private var notUrgentRangeGlucoseChartPoints = [ChartPoint]()
    
    /// for logging
    private var oslog = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryGlucoseChartManager)
    
    private var chartSettings: ChartSettings?
    
    private let labelsWidthY = ConstantsGlucoseChart.yAxisLabelsWidth
    
    private var chartLabelSettings: ChartLabelSettings?
    
    private var chartLabelSettingsObjectives: ChartLabelSettings?
    
    private var chartLabelSettingsObjectivesSecondary: ChartLabelSettings?
    
    private var chartLabelSettingsTarget: ChartLabelSettings?
    
    private var chartLabelSettingsDimmed: ChartLabelSettings?
    
    private var chartLabelSettingsHidden: ChartLabelSettings?
    
    private var chartGuideLinesLayerSettings: ChartGuideLinesLayerSettings?
    
    /// The latest date on the X-axis
    private(set) var endDate: Date
    
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
    
    /// initialise CalibrationsAccessor
    private var calibrationsAccessor: CalibrationsAccessor?
    
    /// initialise treatmentEntryAccessor
    private var treatmentEntryAccessor: TreatmentEntryAccessor?
    
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
    /// - in mgdl
    private var maximumValueInGlucoseChartPointsInMgDl: Double = ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl
    
    /// if the class is iniatated by the view controller without specifying a Gesture Recogniser, then we are not displaying the main chart, but the static 24 hour chart from the landscape view controller
    private var isStatic24hrChart: Bool = false
    
    /// - if glucoseChartPoints.count > 0, then this is the latest one that has timestamp less than endDate.
    private(set) var lastChartPointEarlierThanEndDate: ChartPoint?
    
    /// is chart in panned state or not, meaning is it currently shifted back in time
    private(set) var chartIsPannedBackward: Bool = false
    
    // MARK: - intializer
    
    /// - parameters:
    ///     - chartLongPressGestureRecognizer : defined here as parameter so that this class can handle the config of the recognizer
    ///     - chartLongPressGestureRecognizer has been made optional (initialized to nil) as it doesn't need to be used for the static landscape chart
    init(chartLongPressGestureRecognizer: UILongPressGestureRecognizer? = nil, coreDataManager: CoreDataManager) {
        
        // set coreDataManager
        self.coreDataManager = coreDataManager
        
        // if the call included the optional gesture recogniser, then for tapping the chart, we're using UILongPressGestureRecognizer because UITapGestureRecognizer doesn't react on touch down. With UILongPressGestureRecognizer and minimumPressDuration set to 0, we get a trigger as soon as the chart is touched
        if let chartLongPressGestureRecognizer = chartLongPressGestureRecognizer {
            
            chartLongPressGestureRecognizer.minimumPressDuration = 0
        
        } else {
            
            // as the call didn't pass a gesture recogniser, we must be initiating from the landscape view controller
            isStatic24hrChart = true
            
        }
        
        // initialize enddate
        endDate = Date()
        
        // intialize startdate, which is enddate minus a few hours
        startDate = endDate.addingTimeInterval(.hours(-UserDefaults.standard.chartWidthInHours))
        
    }
    
    // MARK: - public functions
    
    /// - updates the chartPoints arrays , and the chartOutlet, and calls completionHandler when finished
    /// - if called multiple times after each other (eg because user is panning or zooming fast) there might be calls skipped,
    /// - completionhandler will be called when chartOutlet is updated
    /// - parameters:
    ///     - completionHandler : will be called when glucoseChartPoints and chartOutlet are updated
    ///     - endDate :endDate to apply
    ///     - startDate :startDate to apply, if nil then no change will be done in chart width, ie current difference between start and end will be reused
    ///     - coreDataManager : needed to create a private managed object context, which will be used to fetch readings from CoreData
    ///
    /// update of chartPoints array will be done on background thread. The actual redrawing of the chartoutlet is  done on the main thread. Also the completionHandler runs in the main thread.
    /// While updating glucoseChartPoints in background thread, the main thread may call again updateChartPoints with a new endDate (because the user is panning or zooming). A new block will be added in the operation queue and processed later. If there's multiple operations waiting in the queue, only the last one will be executed. This can be the case when the user is doing a fast panning.
    public func updateChartPoints(endDate: Date, startDate: Date?, chartOutlet: BloodGlucoseChartView, completionHandler: (() -> ())?) {
        
        // create a new operation
        let operation = BlockOperation(block: {
            
            // if there's more than one operation waiting for execution, it makes no sense to execute this one, the next one has a newer endDate to use
            guard self.data().operationQueue.operations.count <= 1 else {
                return
            }
            
            // startDateToUse is either parameter value or (if nil), endDate minutes current chartwidth
            let startDateToUse = startDate != nil ? startDate! : Date(timeInterval: -self.endDate.timeIntervalSince(self.startDate), since: endDate)
            
            // we're going to check if we have already all chartpoints in the arrays self.glucoseChartPoints for the new start and date time. If not we're going to prepand a arrays and/or append a arrays
            
            // initialize new list of chartPoints to prepend with empty arrays
            var newGlucoseChartPointsToPrepend: GlucoseChartPointsType = ([ChartPoint](), [ChartPoint](), [ChartPoint](), nil, nil, nil)
            
            // initialize new list of chartPoints to append with empty arrays
            var newGlucoseChartPointsToAppend: GlucoseChartPointsType = ([ChartPoint](), [ChartPoint](), [ChartPoint](), nil, nil, nil)
            
            // do we reuse the existing list ? for instance if new startDate > date of currently stored last chartpoint, then we don't reuse the existing list, probably better to reinitialize from scratch to avoid ending up with too long lists
            // and if there's more than a predefined amount of elements already in the array then we restart from scratch because (on an iPhone SE with iOS 13), the panning is getting slowed down when there's more than 1000 elements in the array
            var reUseExistingChartPointList = self.glucoseChartPoints.urgentRange
                .count + self.glucoseChartPoints.inRange.count + self.glucoseChartPoints.notUrgentRange.count
                <= ConstantsGlucoseChart.maximumElementsInGlucoseChartPointsArray ? true:false
            
            if let lastGlucoseChartPoint = self.glucoseChartPoints.lastGlucoseChartPoint, let lastGlucoseChartPointX = lastGlucoseChartPoint.x as? ChartAxisValueDate {
                
                // if reUseExistingChartPointList = false, then we're actually forcing to use a complete new array, because the current array glucoseChartPoints is too big. If true, then we start from timestamp of the last chartpoint
                let lastGlucoseTimeStamp = reUseExistingChartPointList ? lastGlucoseChartPointX.date : Date(timeIntervalSince1970: 0)
                
                // first see if we need to append new chartpoints
                if startDateToUse > lastGlucoseTimeStamp {
                    
                    // startDate is bigger than the the date of the last currently stored ChartPoint, let's reinitialize the glucosechartpoints
                    reUseExistingChartPointList = false
                    
                    // use newGlucoseChartPointsToAppend and assign it to new list of chartpoints startDate to endDate
                    newGlucoseChartPointsToAppend = self.getGlucoseChartPoints(startDate: startDateToUse, endDate: endDate, bgReadingsAccessor: self.data().bgReadingsAccessor, on: self.coreDataManager.privateManagedObjectContext)
                    
                    // lastChartPointEarlierThanEndDate is the last chartPoint in the array to append
                    self.lastChartPointEarlierThanEndDate = newGlucoseChartPointsToAppend.lastGlucoseChartPoint

                    // maybe there's a higher value now
                    self.maximumValueInGlucoseChartPointsInMgDl = self.getNewMaximumValueInGlucoseChartPoints(currentMaximumValueInGlucoseChartPoints: self.maximumValueInGlucoseChartPointsInMgDl, glucoseChartPoints: newGlucoseChartPointsToAppend)
                    
                } else if endDate <= lastGlucoseTimeStamp {
                    // so starDate <= date of last known glucosechartpoint and enddate is also <= that date
                    // no need to append anything
                    
                    // lastGlucoseChartPoint is the new latest chartpoint earlier than enddate
                    // we basically ignore the calibration chart points here as the graph must be defined based upon the glucose chart points
                    self.lastChartPointEarlierThanEndDate = lastGlucoseChartPoint
                    
                    // maybe there's a higher value now for maximumValueInGlucoseChartPoints
                    self.maximumValueInGlucoseChartPointsInMgDl = self.getNewMaximumValueInGlucoseChartPoints(currentMaximumValueInGlucoseChartPoints: self.maximumValueInGlucoseChartPointsInMgDl, glucoseChartPoints: newGlucoseChartPointsToAppend)

                } else {
                    
                    // append glucseChartpoints with date > x.date up to endDate
                    newGlucoseChartPointsToAppend = self.getGlucoseChartPoints(startDate: lastGlucoseTimeStamp, endDate: endDate, bgReadingsAccessor: self.data().bgReadingsAccessor, on: self.coreDataManager.privateManagedObjectContext)
                    
                    // lastChartPointEarlierThanEndDate is the last chartPoint int he array to append
                    self.lastChartPointEarlierThanEndDate = newGlucoseChartPointsToAppend.lastGlucoseChartPoint
                    
                    // maybe there's a higher value now for maximumValueInGlucoseChartPoints
                    self.maximumValueInGlucoseChartPointsInMgDl = self.getNewMaximumValueInGlucoseChartPoints(currentMaximumValueInGlucoseChartPoints: self.maximumValueInGlucoseChartPointsInMgDl, glucoseChartPoints: newGlucoseChartPointsToAppend)

                }
                
                // now see if we need to prepend
                // if reUseExistingChartPointList = false, then it means startDate > date of last know glucosepoint, there's no need to prepend
                if reUseExistingChartPointList {
                    
                    if let firstGlucoseChartPoint = self.glucoseChartPoints.firstGlucoseChartPoint, let firstGlucoseChartPointX = firstGlucoseChartPoint.x as? ChartAxisValueDate, startDateToUse < firstGlucoseChartPointX.date {
                        
                        newGlucoseChartPointsToPrepend = self.getGlucoseChartPoints(startDate: startDateToUse, endDate: firstGlucoseChartPointX.date, bgReadingsAccessor: self.data().bgReadingsAccessor, on: self.coreDataManager.privateManagedObjectContext)
                        
                        // maybe there's a higher value now for maximumValueInGlucoseChartPoints
                        self.maximumValueInGlucoseChartPointsInMgDl = self.getNewMaximumValueInGlucoseChartPoints(currentMaximumValueInGlucoseChartPoints: self.maximumValueInGlucoseChartPointsInMgDl, glucoseChartPoints: newGlucoseChartPointsToPrepend)

                    }
                    
                }
                
            } else {
                
                // this should be a case where there's no glucoseChartPoints stored yet, we just create a new array to append
                
                // get glucosePoints from coredata
                newGlucoseChartPointsToAppend = self.getGlucoseChartPoints(startDate: startDateToUse, endDate: endDate, bgReadingsAccessor: self.data().bgReadingsAccessor, on: self.coreDataManager.privateManagedObjectContext)
                
                // lastChartPointEarlierThanEndDate is the last chartPoint in the array to append
                self.lastChartPointEarlierThanEndDate = newGlucoseChartPointsToAppend.lastGlucoseChartPoint
                
                // maybe there's a higher value now for maximumValueInGlucoseChartPoints
                self.maximumValueInGlucoseChartPointsInMgDl = self.getNewMaximumValueInGlucoseChartPoints(currentMaximumValueInGlucoseChartPoints: self.maximumValueInGlucoseChartPointsInMgDl, glucoseChartPoints: newGlucoseChartPointsToAppend)

            }
            
            // now assign glucoseChartPoints = range to prepend + existing array + range to append
            // do this for urgentRange, inRange and notUrgentRange
            self.glucoseChartPoints.urgentRange = newGlucoseChartPointsToPrepend.urgentRange + (reUseExistingChartPointList ? self.glucoseChartPoints.urgentRange : [ChartPoint]()) + newGlucoseChartPointsToAppend.urgentRange
            self.glucoseChartPoints.inRange = newGlucoseChartPointsToPrepend.inRange + (reUseExistingChartPointList ? self.glucoseChartPoints.inRange : [ChartPoint]()) + newGlucoseChartPointsToAppend.inRange
            self.glucoseChartPoints.notUrgentRange = newGlucoseChartPointsToPrepend.notUrgentRange + (reUseExistingChartPointList ? self.glucoseChartPoints.notUrgentRange : [ChartPoint]()) + newGlucoseChartPointsToAppend.notUrgentRange
            

            // get calibrations from coredata
            let calibrationChartPoints = self.getCalibrationChartPoints(startDate: startDateToUse, endDate: endDate, calibrationsAccessor: self.data().calibrationsAccessor, on: self.coreDataManager.privateManagedObjectContext)
            
            // only get and assign the treatment chartpoints if the user has chosen to show them on the chart
            if UserDefaults.standard.showTreatmentsOnChart {
                
                // get treatments from coredata
                let treatmentChartPoints: TreatmentChartPointsType = self.getTreatmentEntryChartPoints(startDate: startDateToUse, endDate: endDate, treatmentEntryAccessor: self.data().treatmentEntryAccessor, bgReadingsAccessor: self.data().bgReadingsAccessor, on: self.coreDataManager.privateManagedObjectContext)
                
                // assign treatment arrays
                self.treatmentChartPoints.smallBolus = treatmentChartPoints.smallBolus
                self.treatmentChartPoints.mediumBolus = treatmentChartPoints.mediumBolus
                self.treatmentChartPoints.smallCarbs = treatmentChartPoints.smallCarbs
                self.treatmentChartPoints.mediumCarbs = treatmentChartPoints.mediumCarbs
                self.treatmentChartPoints.largeCarbs = treatmentChartPoints.largeCarbs
                self.treatmentChartPoints.veryLargeCarbs = treatmentChartPoints.veryLargeCarbs
                
            }
            
            DispatchQueue.main.async {
                
                // so we're in the main thread, now endDate and startDate and glucoseChartPoints can be safely assigned to value that was passed in the call to updateChartPoints
                self.endDate = endDate
                self.startDate = startDateToUse
                
                // also assign urgentRangeGlucoseChartPoints, urgentRangeGlucoseChartPoints and urgentRangeGlucoseChartPoints to the corresponding arrays in glucoseChartPoints - can also be safely done because we're in the main thread
                self.urgentRangeGlucoseChartPoints = self.glucoseChartPoints.urgentRange
                self.inRangeGlucoseChartPoints = self.glucoseChartPoints.inRange
                self.notUrgentRangeGlucoseChartPoints = self.glucoseChartPoints.notUrgentRange
                
                // assign calibrationChartPoints to newCalibrationChartPoints
                self.calibrationChartPoints = calibrationChartPoints
                
                // assign the bolus treatment chart points
                self.smallBolusTreatmentChartPoints = self.treatmentChartPoints.smallBolus
                self.mediumBolusTreatmentChartPoints = self.treatmentChartPoints.mediumBolus
                
                // assign the carbs treatment chart points
                self.smallCarbsTreatmentChartPoints = self.treatmentChartPoints.smallCarbs
                self.mediumCarbsTreatmentChartPoints = self.treatmentChartPoints.mediumCarbs
                self.largeCarbsTreatmentChartPoints = self.treatmentChartPoints.largeCarbs
                self.veryLargeCarbsTreatmentChartPoints = self.treatmentChartPoints.veryLargeCarbs
                    
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
        
        updateChartPoints(endDate: newEndDate, startDate: newStartDate, chartOutlet: chartOutlet, completionHandler: completionHandler)
        
    }
    
    private func generateGlucoseChartWithFrame(_ frame: CGRect) -> Chart? {
        
        let xAxisValues = generateXAxisValues()
        
        guard xAxisValues.count > 1 else {return nil}
        
        let xAxisModel = ChartAxisModel(axisValues: xAxisValues, lineColor: ConstantsGlucoseChart.axisLineColor, labelSpaceReservationMode: .fixed(20))
        
        // just to save typing
        let unitIsMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // create yAxisValues, start with 38 mgdl, this is to make sure we show a bit lower than the real lowest value which is usually 40 mgdl, make the label hidden. We must do this with by using a clear color label setting as the hidden property doesn't work (even if we don't know why).
        let firstYAxisValue = ChartAxisValueDouble((ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl).mgdlToMmol(mgdl: unitIsMgDl), labelSettings: data().chartLabelSettingsHidden)
        
        // create now the yAxisValues and add the first
        var yAxisValues = [firstYAxisValue as ChartAxisValue]
        
        // if the user is using objectives, then let's construct the y axis array based on their objective values. Then, after leaving a prudent gap as required, we can add in the standard grid values as secondary axis values in a darker font (to keep the focus on the objective values)
        if UserDefaults.standard.useObjectives {
            
            // if the user has a low urgent value > 50 (which *should* be the case), let's add a dimmed axis value of 40 to give the graph more context. If not, then just ignore it and their low urgent value will become the lowest label value
            if UserDefaults.standard.urgentLowMarkValueInUserChosenUnit >= (unitIsMgDl ? 50 : 2.7) {
                yAxisValues += [ChartAxisValueDouble(unitIsMgDl ? 40 : 2.2, labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
            }
            
            // start by adding the objective values as the axis values
            yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.urgentLowMarkValueInUserChosenUnit.bgValueRounded(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl), labelSettings: data().chartLabelSettingsObjectivesSecondary) as ChartAxisValue]
            
            yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.lowMarkValueInUserChosenUnit.bgValueRounded(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl), labelSettings: data().chartLabelSettingsObjectives) as ChartAxisValue]
            
            // if the user is showing the Target guideline, then let's label that too
            if UserDefaults.standard.showTarget {
                yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.targetMarkValueInUserChosenUnit.bgValueRounded(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl), labelSettings: data().chartLabelSettingsTarget) as ChartAxisValue]
            }
            
            yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.highMarkValueInUserChosenUnit.bgValueRounded(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl), labelSettings: data().chartLabelSettingsObjectives) as ChartAxisValue]
            
            yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.urgentHighMarkValueInUserChosenUnit.bgValueRounded(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl), labelSettings: data().chartLabelSettingsObjectivesSecondary) as ChartAxisValue]
            
            // once the objectives are added, let's build up with standard values every 50mg/dl (minimum 200mg/dl. We'll make these secondary values a dimmer color so that they don't stand out as much as the objective values. As there are more values on the axis (>250mg/dl) and they labels get more compressed, leave more space between the urgent high objective value and the standard grid value
            if UserDefaults.standard.urgentHighMarkValueInUserChosenUnit < (unitIsMgDl ? 135 : 8.1) {
                yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 150 : 9) , labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
            }
            
            // this will be the last default value of 200. If there is an objective "nearby" at > 180, then add the 200 guideline, but hide the label so that we don't crowd the axis
            if UserDefaults.standard.urgentHighMarkValueInUserChosenUnit <= (unitIsMgDl ? 190 : 11.4) {
                yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 200 : 12), labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
            } else if UserDefaults.standard.urgentHighMarkValueInUserChosenUnit < (unitIsMgDl ? 200 : 12) {
                yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 200 : 12), labelSettings: data().chartLabelSettingsHidden) as ChartAxisValue]
            }
            
            // now that we've build up the axis values to a minimum 200mg / 12 mmol, then we should continue as needed until we've covered the maximum glucose value to be displayed.
            if (UserDefaults.standard.urgentHighMarkValueInUserChosenUnit < (unitIsMgDl ? 240 : 14)) && (yAxisValues.last!.scalar < maximumValueInGlucoseChartPointsInMgDl.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) ) {
                yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 250 : 15), labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
            }
            
            if (UserDefaults.standard.urgentHighMarkValueInUserChosenUnit <= (unitIsMgDl ? 280 : 17)) && (yAxisValues.last!.scalar < maximumValueInGlucoseChartPointsInMgDl.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) ) {
                yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 300 : 18), labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
            }
            
            if (UserDefaults.standard.urgentHighMarkValueInUserChosenUnit <= (unitIsMgDl ? 330 : 20)) && (yAxisValues.last!.scalar < maximumValueInGlucoseChartPointsInMgDl.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) ) {
                yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 350 : 21), labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
            }
            
            if (UserDefaults.standard.urgentHighMarkValueInUserChosenUnit <= (unitIsMgDl ? 380 : 23)) && (yAxisValues.last!.scalar < maximumValueInGlucoseChartPointsInMgDl.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) ) {
                yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 400 : 24), labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
            }
            
        } else {
            
            // objectives are not being used, so let's just build the standard grid. All axis values are considered equally important so don't make any of them dimmer.
            if unitIsMgDl {
                yAxisValues += ConstantsGlucoseChart.initialGlucoseValueRangeInMgDl.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
            } else {
                yAxisValues += ConstantsGlucoseChart.initialGlucoseValueRangeInMmol.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
            }
            
            // if the maxium yAxisValue doesn't support the maximum glucose value, then add the next range
            if yAxisValues.last!.scalar < maximumValueInGlucoseChartPointsInMgDl.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) {
                if unitIsMgDl {
                    yAxisValues += ConstantsGlucoseChart.secondGlucoseValueRangeInMgDl.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
                } else {
                    yAxisValues += ConstantsGlucoseChart.secondGlucoseValueRangeInMmol.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
                }
            }
            
            // if the maxium yAxisValue doesn't support the maximum glucose value, then add the next range
            if yAxisValues.last!.scalar < maximumValueInGlucoseChartPointsInMgDl.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) {
                  if unitIsMgDl {
                    yAxisValues += ConstantsGlucoseChart.thirdGlucoseValueRangeInMgDl.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
                } else {
                    yAxisValues += ConstantsGlucoseChart.thirdGlucoseValueRangeInMmol.map { ChartAxisValueDouble($0, labelSettings: data().chartLabelSettings)}
                }
            }
        
        }
        
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: ConstantsGlucoseChart.axisLineColor, labelSpaceReservationMode: .fixed(labelsWidthY))
        
        // put Y axis on right side
        let coordsSpace = ChartCoordsSpaceRightBottomSingleAxis(chartSettings: data().chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)
        
        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
        
        // as the user can modify the chart width in hours, we should slightly reduce the size of the chart point symbols so that the chart isn't crowded when using 12h or 24h options
        // fix the initial values. As this scaling should never need to be adjusted, this is done locally here and not with values stored in ConstantsGlucoseChart
        var glucoseCircleDiameter: CGFloat = 0
        
        var bolusTriangleSize: CGFloat = 0
        
        // define the fixed separation of each label from it's corresponding marker. The bigger markers need a bigger separation to stop the label from covering it
        // we also define a separation offset which is mutable and will be adjusted next to dynamically change based upon the chart width and height - this is used to keep everything looking the same no matter what scales are in use
        let mediumBolusLabelSeparation: Double = ConstantsGlucoseChart.mediumBolusLabelSeparation
        var bolusLabelSeparationOffset: Double = 0
        
        let smallCarbsLabelSeparation: Double = ConstantsGlucoseChart.smallCarbsLabelSeparation
        let mediumCarbsLabelSeparation: Double = ConstantsGlucoseChart.mediumCarbsLabelSeparation
        let largeCarbsLabelSeparation: Double = ConstantsGlucoseChart.largeCarbsLabelSeparation
        let veryLargeCarbsLabelSeparation: Double = ConstantsGlucoseChart.veryLargeCarbsLabelSeparation
        var carbsLabelSeparationOffset: Double = 0
        
        var treatmentLabelFontSize: Double = ConstantsGlucoseChart.treatmentLabelFontSize
        
        // adjust marker sizes and label size/separation based upon the chart width
        switch UserDefaults.standard.chartWidthInHours {
            
        case 3:
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter3h
            bolusTriangleSize = ConstantsGlucoseChart.bolusTriangleSize3h
            treatmentLabelFontSize += 2
            bolusLabelSeparationOffset += 1
            carbsLabelSeparationOffset += 2
        case 6:
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter6h
            bolusTriangleSize = ConstantsGlucoseChart.bolusTriangleSize6h
        case 12:
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter12h
            bolusTriangleSize = ConstantsGlucoseChart.bolusTriangleSize12h
            treatmentLabelFontSize -= 1
            bolusLabelSeparationOffset -= 1
            carbsLabelSeparationOffset -= 2
        case 24:
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter24h
            bolusTriangleSize = ConstantsGlucoseChart.bolusTriangleSize24h
            treatmentLabelFontSize -= 2
            bolusLabelSeparationOffset -= 2
            carbsLabelSeparationOffset -= 3
        default:
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter6h
            bolusTriangleSize = ConstantsGlucoseChart.bolusTriangleSize6h
            
        }
        
        // if the chart y-axis has high numbers, let's add an extra offset to the label separation to stop them touching the symbol when the axis is squashed down
        switch yAxisValues.last!.scalar {
            
        case 199...299:
            bolusLabelSeparationOffset += 2
            carbsLabelSeparationOffset += 2
        case 300...600:
            bolusLabelSeparationOffset += 3
            carbsLabelSeparationOffset += 3
        default:
            break
            
        }
        
        // check if we're using the static 24hr landscape chart and then just adjust further as needed. This is needed because the chart ratio is squashed more in landscape orientation
        if isStatic24hrChart {
            
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter24h
            treatmentLabelFontSize -= 1
            bolusLabelSeparationOffset += 2
            carbsLabelSeparationOffset += 1
            
        }
                
        // now that we know innerFrame we can set innerFrameWidth
        innerFrameWidth = Double(innerFrame.width)
        
        chartGuideLinesLayerSettings = ChartGuideLinesLayerSettings(linesColor: UserDefaults.standard.useObjectives ? ConstantsGlucoseChart.gridColorObjectives : ConstantsGlucoseChart.gridColor,  linesWidth: 0.5)
        
        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: data().chartGuideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)
        
        // high/low/target guideline layer settings and styles
        let urgentHighLowLineLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: ConstantsGlucoseChart.guidelineUrgentHighLow, linesWidth: UserDefaults.standard.useObjectives ? 1 : 0, dotWidth: 2, dotSpacing: 8)
        
        let highLowLineLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: ConstantsGlucoseChart.guidelineHighLow, linesWidth: UserDefaults.standard.useObjectives ? 1 : 0, dotWidth: 4, dotSpacing: 4)
        
        let targetLineLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: ConstantsGlucoseChart.guidelineTargetColor, linesWidth: (UserDefaults.standard.useObjectives ? (UserDefaults.standard.showTarget ? 1 : 0) : 0), dotWidth: 12, dotSpacing: 6)
        
        // high/low/target guidelines
        let urgentHighLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: urgentHighLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.urgentHighMarkValueInUserChosenUnit)])
        
        let highLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: highLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.highMarkValueInUserChosenUnit)])
        
        let targetLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: targetLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.targetMarkValueInUserChosenUnit)])
        
        let lowLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: highLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.lowMarkValueInUserChosenUnit)])
        
        let urgentLowLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: urgentHighLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.urgentLowMarkValueInUserChosenUnit)])
        
        // calibration points circle layers - we'll create two circles, one on top of the other to give a white border as per Nightscout calibrations. We'll make the inner circle UIColor.red to make it slightly different to the UIColor.systemRed used by the glucoseChartPoints. Both circles will be scaled as per the current glucoseCircleDiameter but bigger so that they stand out
        let calibrationCirclesOuterLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: calibrationChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.calibrationCircleScaleOuter, height: glucoseCircleDiameter * ConstantsGlucoseChart.calibrationCircleScaleOuter), itemFillColor: ConstantsGlucoseChart.calibrationCircleColorOuter, optimized: true)
        
        let calibrationCirclesInnerLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: calibrationChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.calibrationCircleScaleInner, height: glucoseCircleDiameter * ConstantsGlucoseChart.calibrationCircleScaleInner), itemFillColor: ConstantsGlucoseChart.calibrationCircleColorInner, optimized: true)
        
        // bolus triangle layers
        let mediumBolusTriangleLayer = ChartPointsScatterDownTrianglesWithDropdownLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: mediumBolusTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: bolusTriangleSize, height: bolusTriangleSize * ConstantsGlucoseChart.bolusTriangleHeightScale), itemFillColor: ConstantsGlucoseChart.bolusTreatmentColor)
        
        let smallBolusTriangleLayer = ChartPointsScatterDownTrianglesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: smallBolusTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: bolusTriangleSize * ConstantsGlucoseChart.smallBolusTreamentScale, height: (bolusTriangleSize * ConstantsGlucoseChart.bolusTriangleHeightScale) * ConstantsGlucoseChart.smallBolusTreamentScale), itemFillColor: ConstantsGlucoseChart.bolusTreatmentColor)
        
        //  carb circle layers
        let smallCarbsLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: smallCarbsTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.smallCarbsTreamentScale, height: glucoseCircleDiameter * ConstantsGlucoseChart.smallCarbsTreamentScale), itemFillColor: ConstantsGlucoseChart.carbsTreatmentColor, optimized: true)
        
        let mediumCarbsLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: mediumCarbsTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.mediumCarbsTreamentScale, height: glucoseCircleDiameter * ConstantsGlucoseChart.mediumCarbsTreamentScale), itemFillColor: ConstantsGlucoseChart.carbsTreatmentColor, optimized: true)
        
        let largeCarbsLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: largeCarbsTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.largeCarbsTreamentScale, height: glucoseCircleDiameter * ConstantsGlucoseChart.largeCarbsTreamentScale), itemFillColor: ConstantsGlucoseChart.carbsTreatmentColor, optimized: true)
        
        let veryLargeCarbsLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: veryLargeCarbsTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.veryLargeCarbsTreamentScale, height: glucoseCircleDiameter * ConstantsGlucoseChart.veryLargeCarbsTreamentScale), itemFillColor: ConstantsGlucoseChart.carbsTreatmentColor, optimized: true)
        
        // in Range circle layers
        let inRangeGlucoseCirclesLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: inRangeGlucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter, height: glucoseCircleDiameter), itemFillColor: ConstantsGlucoseChart.glucoseInRangeColor, optimized: true)

        // urgent Range circle layers
        let urgentRangeGlucoseCirclesLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: urgentRangeGlucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter, height: glucoseCircleDiameter), itemFillColor: ConstantsGlucoseChart.glucoseUrgentRangeColor, optimized: true)

        // above target circle layers
        let notUrgentRangeGlucoseCirclesLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: notUrgentRangeGlucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter, height: glucoseCircleDiameter), itemFillColor: ConstantsGlucoseChart.glucoseNotUrgentRangeColor, optimized: true)
        
        // treatment labels layers
        let bolusLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: mediumBolusTreatmentChartPoints, labelSeparation: mediumBolusLabelSeparation, labelSeparationOffset: bolusLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Insulin, treatmentLabelFontSize: treatmentLabelFontSize, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        let smallCarbsLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: smallCarbsTreatmentChartPoints, labelSeparation: smallCarbsLabelSeparation, labelSeparationOffset: carbsLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Carbs, treatmentLabelFontSize: treatmentLabelFontSize, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        let mediumCarbsLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: mediumCarbsTreatmentChartPoints, labelSeparation: mediumCarbsLabelSeparation, labelSeparationOffset: carbsLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Carbs, treatmentLabelFontSize: treatmentLabelFontSize, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        let largeCarbsLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: largeCarbsTreatmentChartPoints, labelSeparation: largeCarbsLabelSeparation, labelSeparationOffset: carbsLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Carbs, treatmentLabelFontSize: treatmentLabelFontSize, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        let veryLargeCarbsLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: veryLargeCarbsTreatmentChartPoints, labelSeparation: veryLargeCarbsLabelSeparation, labelSeparationOffset: carbsLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Carbs, treatmentLabelFontSize: treatmentLabelFontSize, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        // create a ChartLayer array and append extra arrays if you user has configured them to show on the chart
        var layers: [ChartLayer?] = [
            gridLayer,
            xAxisLayer,
            yAxisLayer,
            // guideline layers
            urgentHighLineLayer,
            highLineLayer,
            targetLineLayer,
            lowLineLayer,
            urgentLowLineLayer
        ]
        
        if UserDefaults.standard.showTreatmentsOnChart {
            
            let layersTreatments: [ChartLayer?] = [
                // carb treatment layers
                veryLargeCarbsLayer,
                largeCarbsLayer,
                mediumCarbsLayer,
                smallCarbsLayer,
                // bolus treatment layers
                mediumBolusTriangleLayer,
                smallBolusTriangleLayer
            ]
            
            layers.append(contentsOf: layersTreatments)
            
        }
        
        let layersGlucoseCircles: [ChartLayer?] = [
            // calibrationPoint layers
            calibrationCirclesOuterLayer,
            calibrationCirclesInnerLayer,
            // glucosePoint layers
            inRangeGlucoseCirclesLayer,
            notUrgentRangeGlucoseCirclesLayer,
            urgentRangeGlucoseCirclesLayer
        ]
        
        layers.append(contentsOf: layersGlucoseCircles)
        
        if UserDefaults.standard.showTreatmentsOnChart {
            
            let layersTreatmentLabels: [ChartLayer?] = [
                // treatment label layers
                smallCarbsLabelsLayer,
                mediumCarbsLabelsLayer,
                largeCarbsLabelsLayer,
                veryLargeCarbsLabelsLayer,
                bolusLabelsLayer
            ]
            
            layers.append(contentsOf: layersTreatmentLabels)
            
        }
        
        return Chart(
            frame: frame,
            innerFrame: innerFrame,
            settings: data().chartSettings,
            layers: layers.compactMap { $0 }
        )
    }
    
    private func generateXAxisValues() -> [ChartAxisValue] {
        
        
        if !isStatic24hrChart {
            
            // in the comments, assume it is now 13:26 and width is 6 hours, that means startDate = 07:26, endDate = 13:26
            
            /// how many full hours between startdate and enddate
            let amountOfFullHours = Int(ceil(endDate.timeIntervalSince(startDate).hours))
            
            /// create array that goes from 1 to number of full hours, as helper to map to array of ChartAxisValueDate - array will go from 1 to 6
            let mappingArray = Array(1...amountOfFullHours)
            
            /// set the stride count interval to make sure we don't add too many labels to the x-axis if the user wants to view >6 hours
            var intervalBetweenAxisValues: Int = 1
                
            switch UserDefaults.standard.chartWidthInHours {
                case 12.0:
                    intervalBetweenAxisValues = 2
                case 24.0:
                    intervalBetweenAxisValues = 4
                default:
                    break
            }
            
            /// first, for each int in mappingArray, we create a ChartAxisValueDate, which will have as date one of the hours, starting with the lower hour + 1 hour - we will create 5 in this example, starting with hour 08 (7 + 3600 seconds)
            let startDateLower = startDate.toLowerHour()
            var xAxisValues: [ChartAxisValue] = stride(from: 1, to: mappingArray.count + 1, by: intervalBetweenAxisValues).map { ChartAxisValueDate(date: Date(timeInterval: Double($0)*3600, since: startDateLower), formatter: data().axisLabelTimeFormatter, labelSettings: data().chartLabelSettings) }
            
            /// insert the start Date as first element, in this example 07:26
            xAxisValues.insert(ChartAxisValueDate(date: startDate, formatter: data().axisLabelTimeFormatter, labelSettings: data().chartLabelSettings), at: 0)
            
            /// now append the endDate as last element, in this example 13:26
            xAxisValues.append(ChartAxisValueDate(date: endDate, formatter: data().axisLabelTimeFormatter, labelSettings: data().chartLabelSettings))
            
            /// don't show the first and last hour, because this is usually not something like 13 but rather 13:26
            xAxisValues.first?.hidden = true
            xAxisValues.last?.hidden = true
            
            return xAxisValues
            
        } else {
            
            let xAxisValues: [ChartAxisValue] = stride(from: 0, to: 26, by: 2).map { ChartAxisValueDate(date: Date(timeInterval: Double($0)*3600, since: startDate), formatter: data().axisLabelTimeFormatter, labelSettings: data().chartLabelSettings) }
            
            /// don't show the first and last hour, because this is usually not something like 13 but rather 13:26
            xAxisValues.first?.hidden = true
            xAxisValues.last?.hidden = false
            
            return xAxisValues
            
        }
        
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
        
        // initialize last chartpoint
        var lastGlucoseChartPoint: ChartPoint?
        
        // initialize first chartpoint
        var firstGlucoseChartPoint: ChartPoint?
        
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
                    
                    lastGlucoseChartPoint = (lastGlucoseChartPoint != nil ? max(lastGlucoseChartPoint!, newGlucoseChartPoint) : newGlucoseChartPoint)
                    
                    firstGlucoseChartPoint = (firstGlucoseChartPoint != nil ? min(firstGlucoseChartPoint!, newGlucoseChartPoint) : newGlucoseChartPoint)
                    
                    maximumValueInGlucoseChartPoints = (maximumValueInGlucoseChartPoints != nil ? max(maximumValueInGlucoseChartPoints!, reading.calculatedValue) : reading.calculatedValue)
                    
                }
                
            }

        }
        
        return (urgentRangeChartPoints, inRangeChartPoints, notUrgentRangeChartPoints, firstGlucoseChartPoint, lastGlucoseChartPoint, maximumValueInGlucoseChartPoints)
        
    }

    
    private func getCalibrationChartPoints(startDate: Date, endDate: Date, calibrationsAccessor: CalibrationsAccessor, on managedObjectContext: NSManagedObjectContext) -> [ChartPoint] {
        
        // get calibrations between the two dates
        let calibrations = calibrationsAccessor.getCalibrations(from: startDate, to: endDate, on: managedObjectContext)

        // intialize the calibration chart point array
        var calibrationChartPoints = [ChartPoint]()
        
        managedObjectContext.performAndWait {
        
            for calibration in calibrations {
            
                if calibration.bg.value > 0.0 {
                    
                    let newCalibrationChartPoint = ChartPoint(calibration: calibration, formatter: data().chartPointDateFormatter, unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)

                    calibrationChartPoints.append(newCalibrationChartPoint)
                    
                }
                
            }
        
        }
        
        return (calibrationChartPoints)
        
    }
    
        
    /// Receives a start and end date and returns the treatment entries from coredata between these dates. These dates will typically be the start and end dates of the chart x-axis. These individual treatment entries are returned as a tuple with multiple chartPoint arrays as defined in TreatmentChartPointsTypes.
    ///
    /// - parameters:
    ///     - startDate : start date to retreive treatment entries
    ///     - endDate : end date to retreive treatment entries
    ///     - treatmentEntryAccessor : treatment entry accessor object
    ///     - bgReadingsAccessor : bg readings accessor object
    ///     - managedObjectContext : the ManagedObjectContext to use
    /// - returns: a tuple with chart point arrays for each classification of treatment type + size
    private func getTreatmentEntryChartPoints(startDate: Date, endDate: Date, treatmentEntryAccessor: TreatmentEntryAccessor, bgReadingsAccessor: BgReadingsAccessor, on managedObjectContext: NSManagedObjectContext) -> ([ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint]) {
        
        // get treaments between the two timestamps from coredata
        let treatmentEntries = treatmentEntryAccessor.getTreatments(fromDate: startDate, toDate: endDate, on: managedObjectContext)
        
        // intialize the treatment chart point arrays
        var smallBolusTreatmentEntryChartPoints = [ChartPoint]()
        var mediumBolusTreatmentEntryChartPoints = [ChartPoint]()
        var smallCarbsTreatmentEntryChartPoints = [ChartPoint]()
        var mediumCarbsTreatmentEntryChartPoints = [ChartPoint]()
        var largeCarbsTreatmentEntryChartPoints = [ChartPoint]()
        var veryLargeCarbsTreatmentEntryChartPoints = [ChartPoint]()
        
        managedObjectContext.performAndWait {
            
            // filter the treatment entries that have not been marked as deleted and append them to the relevant chart point array
            for treatmentEntry in treatmentEntries.filter({ treatment in return !treatment.treatmentdeleted}) {

                switch treatmentEntry.treatmentType {
                    
                case .Insulin:
                    
                    // cycle through the possible bolus threshold value(s) and append to the correct array
                    if treatmentEntry.value < UserDefaults.standard.smallBolusTreatmentThreshold {
                        smallBolusTreatmentEntryChartPoints.append(ChartPoint(treatmentEntry: treatmentEntry, formatter: data().chartPointDateFormatter))
                    } else {
                        mediumBolusTreatmentEntryChartPoints.append(ChartPoint(treatmentEntry: treatmentEntry, formatter: data().chartPointDateFormatter))
                    }
                    
                case .Carbs:
                    
                    // get glucose point values from before and after the current treatment time. We can then calculate a proposed y-axis value and assign this to the Y attribute of the chart point to ensure it is floating in-line with the CGM data as per Nightscout style
                    let calculatedYAxisValue = calculateClosestYAxisValue(treatmentDate: treatmentEntry.date, bgReadingsAccessor: bgReadingsAccessor, on: managedObjectContext)
                    
                    // cycle through the possible threshold values and append the carb chart point to the correct array. We use an extended ChartPoint class to pass the new y axis value
                    if treatmentEntry.value < ConstantsGlucoseChart.smallCarbsTreamentThreshold {
                        
                        smallCarbsTreatmentEntryChartPoints.append(ChartPoint(treatmentEntry: treatmentEntry, formatter: data().chartPointDateFormatter, newYAxisValue: calculatedYAxisValue))
                        
                    } else if treatmentEntry.value < ConstantsGlucoseChart.mediumCarbsTreamentThreshold {
                        
                        mediumCarbsTreatmentEntryChartPoints.append(ChartPoint(treatmentEntry: treatmentEntry, formatter: data().chartPointDateFormatter, newYAxisValue: calculatedYAxisValue))
                        
                    } else if treatmentEntry.value < ConstantsGlucoseChart.largeCarbsTreamentThreshold {
                        
                        largeCarbsTreatmentEntryChartPoints.append(ChartPoint(treatmentEntry: treatmentEntry, formatter: data().chartPointDateFormatter, newYAxisValue: calculatedYAxisValue))
                        
                    } else {
                        
                        veryLargeCarbsTreatmentEntryChartPoints.append(ChartPoint(treatmentEntry: treatmentEntry, formatter: data().chartPointDateFormatter, newYAxisValue: calculatedYAxisValue))
                        
                    }
                    
                default:
                    break
                    
                }
                
            }
        
        }
        
        // return all treatment arrays based upon treatment type and size (as defined by the threshold values)
        return (smallBolusTreatmentEntryChartPoints, mediumBolusTreatmentEntryChartPoints, smallCarbsTreatmentEntryChartPoints, mediumCarbsTreatmentEntryChartPoints, largeCarbsTreatmentEntryChartPoints, veryLargeCarbsTreatmentEntryChartPoints)
        
    }
    
    
    /// Receives a treatment timestamp and searches for the closest glucose values. It will then take the average of the before and after values and use this to return a new Y value where the carb treatments can be placed
    ///
    /// - parameters:
    ///     - treatmentDate : treatment date timestamp that we want to use
    ///     - bgReadingsAccessor : bg readings accessor object
    ///     - managedObjectContext : the ManagedObjectContext to use
    /// - returns: a double with the Y axis value for the treatment time calculated from the closest glucose point y-axis values
    private func calculateClosestYAxisValue(treatmentDate: Date, bgReadingsAccessor: BgReadingsAccessor, on managedObjectContext: NSManagedObjectContext) -> Double {
        
        // how many minutes either side of the treatmentDate we will look for glucose values. First we do a quick check and if nothing is returned we can check for an hour or two.
        let minutesEitherSide: Double = 10
        let minutesEitherSideExtended: Double = 70
        
        var lowerValueToUse: Double = 0
        var upperValueToUse: Double = 0
        
        // in normal circumstances there will always be CGM data but in the unlikely event that there is no data point to calculate 1 hour before and after, we'll just pin it to the user's target objective which should be in the middle of their desired range
        let bgReadingsBefore = bgReadingsAccessor.getBgReadings(from: treatmentDate.addingTimeInterval(-minutesEitherSide * 60), to: treatmentDate, on: managedObjectContext)
        
        if let lastBgReading = bgReadingsBefore.last {
            
            lowerValueToUse = lastBgReading.calculatedValue
            
        } else {
            
            let bgReadingsBeforeExtended = bgReadingsAccessor.getBgReadings(from: treatmentDate.addingTimeInterval(-minutesEitherSideExtended * 60), to: treatmentDate, on: managedObjectContext)
            
            if let lastBgReading = bgReadingsBeforeExtended.last {
                
                lowerValueToUse = lastBgReading.calculatedValue
                
            }
        }
        
        let bgReadingsAfter = bgReadingsAccessor.getBgReadings(from: treatmentDate, to: treatmentDate.addingTimeInterval(minutesEitherSide * 60), on: managedObjectContext)
        
        if let firstBgReading = bgReadingsAfter.last {
            
            upperValueToUse = firstBgReading.calculatedValue
            
        } else {
            
            let bgReadingsAfterExtended = bgReadingsAccessor.getBgReadings(from: treatmentDate, to: treatmentDate.addingTimeInterval(minutesEitherSideExtended * 60), on: managedObjectContext)
            
            if let firstBgReading = bgReadingsAfterExtended.last {
                
                upperValueToUse = firstBgReading.calculatedValue
                
            }
        }
        
        // if there is both an upper or lower value, return the average. If there is just one, return it.
        if lowerValueToUse != 0 && upperValueToUse != 0 {
            
            return (lowerValueToUse + upperValueToUse) / 2
            
        } else if lowerValueToUse != 0 || upperValueToUse != 0 {
            
            return lowerValueToUse + upperValueToUse
            
        } else {
            
            // Both values are missing, so just return the user's target objective and peg the treatment there
            return UserDefaults.standard.targetMarkValueInUserChosenUnit
            
        }
        
    }
    
    
    /// Receives a view layer with treatment labels (text and position).
    ///
    /// - parameters:
    ///     - treatmentChartPoint : a chart point with x:y values. This will include the real x value of the treatment and the scaled y value
    ///     - labelSeparation: how far should the label position be separated from the center of the chart point to avoid it covering the chart point
    ///     - labelSeparation: how far should the label position be separated from the chart point to avoid it covering the chart marker itself
    ///     - labelSeparationOffset: how much extra (or less) offset should be added to the separation based upon the scaling done by the possible chart widths (more hours means smaller scaled chart markers). We do this to prevent the relative position of the label from moving when the marker size changes.
    ///     - xAxisLayer : the x axis values to use to position the labels
    ///     - yAxisLayer : the y axis values to use to position the labels
    ///     - treatmentType : the treatment type being represented. This is used to set the decimal points and the unit text
    ///     - treatmentLabelFontSize : the font size to be used for the labels. This is generated automatically based upon chart width/height
    ///     - y : the y position of the inner frame of the chart
    ///     - height : the height of the inner frame
    /// - returns: a view layer with the labels and their position
    private func createTreatmentLabelsLayer(treatmentChartPoints: [ChartPoint], labelSeparation: Double, labelSeparationOffset: Double, xAxisLayer: ChartAxisLayer, yAxisLayer: ChartAxisLayer, treatmentType: TreatmentType, treatmentLabelFontSize: Double, y: Double, height: Double) -> ChartPointsViewsLayer<ChartPoint, UIView> {
        
        // to save typing
        let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        let offsetIfMmol: Double = ConstantsGlucoseChart.treatmentLabelMmolOffset.mgdlToMmol(mgdl: isMgDl)
        
        // creatte the chart point array of the label positions based upon the treatment chart point array
        let labelChartPoints = treatmentChartPoints.map { chartPoint in
            ChartPoint(x: chartPoint.x, y: chartPoint.y.copy(chartPoint.y.scalar + labelSeparation.mgdlToMmol(mgdl: isMgDl) + labelSeparationOffset.mgdlToMmol(mgdl: isMgDl) + (isMgDl ? 0 : offsetIfMmol)))
        }
        
        // based upon the label array, we can return the UI view fully populated
        return ChartPointsViewsLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: labelChartPoints, viewGenerator: {(chartPointModel, layer, chart) -> UIView? in
            let label = HandlingLabel()
            
            let pos = chartPointModel.chartPoint.y.scalar > 0
            
            let labelFormatter = NumberFormatter()
            
            // if the treatment is insulin, set the formatter to show 1 decimal place
            // if not, set to zero decimal places by default
            // we'll use a switch case to make it easier to add other options in the future
            switch treatmentType {
                
            case .Insulin:
                labelFormatter.maximumFractionDigits =  2
                
            default:
                labelFormatter.maximumFractionDigits =  0
                
            }
            
            // we need to find out the original treatment value to use in the label as the chart point has a scaled value
            let originalTreatmentValue = self.getTreatmentValueFromTimeStamp(treatmentDate: chartPointModel.chartPoint.x as! ChartAxisValueDate, treatmentType: treatmentType, treatmentEntryAccessor: self.data().treatmentEntryAccessor, on: self.coreDataManager.privateManagedObjectContext)
            
            // format the label with the correct value, decimal places, unit and also the position and font size/color/weight
            label.text = " \(labelFormatter.string(from: NSNumber(value: originalTreatmentValue))! + treatmentType.unit()) "
            label.font = UIFont.systemFont(ofSize: treatmentLabelFontSize, weight: UIFont.Weight.bold)
            label.backgroundColor = ConstantsGlucoseChart.treatmentLabelBackgroundColor
            label.textColor = ConstantsGlucoseChart.treatmentLabelFontColor
            label.sizeToFit()
            label.center = CGPoint(x: chartPointModel.screenLoc.x, y: pos ? y : y + height)
            label.alpha = 0
            
            label.movedToSuperViewHandler = {[weak label] in
                UIView.animate(withDuration: 0.0, animations: {
                    label?.alpha = 1
                    label?.center.y = chartPointModel.screenLoc.y
                })
            }
            return label
        }, displayDelay: 0.0, mode: .translate)
        
    }
    
    
    /// Receives a treatment timestamp and treatment type and returns the real treatment value. This can then be used to create the label text
    ///
    /// - parameters:
    ///     - treatmentDate : treatment date timestamp that we want to use
    ///     - treatmentType : treatment type that we want to use (this is necessary in case two separate treatments exist at exactly the same timestamp such as the case of a meal combo (bolus + carbs)
    ///     - treatmentsAccessor : treatments accessor object
    ///     - managedObjectContext : the ManagedObjectContext to use
    /// - returns: a double with the actual value for the treatment requested
    private func getTreatmentValueFromTimeStamp(treatmentDate: ChartAxisValueDate, treatmentType: TreatmentType, treatmentEntryAccessor: TreatmentEntryAccessor, on managedObjectContext: NSManagedObjectContext) -> Double {
        
        // We need to increase slightly the "window" that we are using to locate the treament. The ChartPoint class seems to slightly round the values which might result in not getting an exact match. ±1ms seems to work, but we'll leave it at ±50ms just to be sure.
        let treatmentEntries = treatmentEntryAccessor.getTreatments(fromDate: Date(timeInterval: -0.05, since: treatmentDate.date), toDate: Date(timeInterval: 0.05, since: treatmentDate.date), on: managedObjectContext)
        
        // intialize the treatmentValue that we will return
        var treatmentValue: Double = 0
        
        managedObjectContext.performAndWait {
            
            // cycle through the treatment entries (there should be only one!) and assign the value
            for treatmentEntry in treatmentEntries {
                
                // just in case there are several treatments registered at exactly the same time (such as when a meal bolus is added with carbs + bolus), just go through the treatmentEntries until we coincide with the correct treatmentType being looked for
                if treatmentEntry.treatmentType == treatmentType {
                    
                    treatmentValue = treatmentEntry.value
                    
                }
                
            }
            
        }
        
        return treatmentValue
            
    }
    

    /// - set data to nil, will be called eg to clean up memory when going to the background
    /// - all needed variables will will be reinitialized as soon as data() is called
    private func nillifyData() {
        
        stopDeceleration()
        
        glucoseChartPoints = ([ChartPoint](), [ChartPoint](), [ChartPoint](), nil, nil, nil)
        treatmentChartPoints = ([ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint]())
        
        calibrationChartPoints = [ChartPoint]()
        
        smallBolusTreatmentChartPoints = [ChartPoint]()
        mediumBolusTreatmentChartPoints = [ChartPoint]()
        
        smallCarbsTreatmentChartPoints = [ChartPoint]()
        mediumCarbsTreatmentChartPoints = [ChartPoint]()
        largeCarbsTreatmentChartPoints = [ChartPoint]()
        
        chartSettings = nil
        
        chartPointDateFormatter = nil
        
        operationQueue = nil
        
        chartLabelSettings = nil
        
        chartGuideLinesLayerSettings = nil
        
        axisLabelTimeFormatter = nil
        
        bgReadingsAccessor = nil
        
        calibrationsAccessor = nil
        
        treatmentEntryAccessor = nil
        
        urgentRangeGlucoseChartPoints = []

        inRangeGlucoseChartPoints = []

        notUrgentRangeGlucoseChartPoints = []
        
        chartLabelSettingsObjectives = nil
        
        chartLabelSettingsObjectivesSecondary = nil
        
        chartLabelSettingsTarget = nil
        
        chartLabelSettingsDimmed = nil
        
        chartLabelSettingsHidden = nil

    }
    
    /// function which gives is variables that are set back to nil when nillifyData is called
    private func data() -> (chartSettings: ChartSettings, chartPointDateFormatter: DateFormatter, operationQueue: OperationQueue, chartLabelSettings: ChartLabelSettings, chartLabelSettingsObjectives: ChartLabelSettings, chartLabelSettingsObjectivesSecondary: ChartLabelSettings, chartLabelSettingsTarget: ChartLabelSettings, chartLabelSettingsDimmed: ChartLabelSettings, chartLabelSettingsHidden: ChartLabelSettings, chartGuideLinesLayerSettings: ChartGuideLinesLayerSettings, axisLabelTimeFormatter: DateFormatter, bgReadingsAccessor: BgReadingsAccessor, calibrationsAccessor: CalibrationsAccessor, treatmentEntryAccessor: TreatmentEntryAccessor) {
        
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
        
        // intialize chartlabelsettings - this is used for the standard grid labels
        if chartLabelSettings == nil {
            chartLabelSettings = ChartLabelSettings(
                font: .systemFont(ofSize: 14),
                fontColor: ConstantsGlucoseChart.axisLabelColor
            )
        }
        
        // intialize chartlabelsettingsObjectives - this is used for the objective label
        if chartLabelSettingsObjectives == nil {
            chartLabelSettingsObjectives = ChartLabelSettings(
                font: .boldSystemFont(ofSize: 15),
                fontColor: ConstantsGlucoseChart.axisLabelColorObjectives
            )
        }
        
        // intialize chartlabelsettingsObjectivesSecondary - this is used for the high/low objective labels. Show in the same colour, but not bold
        if chartLabelSettingsObjectivesSecondary == nil {
            chartLabelSettingsObjectivesSecondary = ChartLabelSettings(
                font: .systemFont(ofSize: 14),
                fontColor: ConstantsGlucoseChart.axisLabelColorObjectives
            )
        }
        
        // intialize chartlabelsettingsTarget - this is used for the target label (if needed)
        if chartLabelSettingsTarget == nil {
            chartLabelSettingsTarget = ChartLabelSettings(
                font: .systemFont(ofSize: 14),
                fontColor: ConstantsGlucoseChart.axisLabelColorTarget
            )
        }
        
        // intialize chartlabelsettingsDimmed - used for secondary values that aren't objectives
        if chartLabelSettingsDimmed == nil {
            chartLabelSettingsDimmed = ChartLabelSettings(
                font: .systemFont(ofSize: 14),
                fontColor: ConstantsGlucoseChart.axisLabelColorDimmed
            )
        }
        
        // intialize chartlabelsettingsHidden - used to hide the first 38mg/dl value etc
        if chartLabelSettingsHidden == nil {
            chartLabelSettingsHidden = ChartLabelSettings(
                font: .systemFont(ofSize: 14),
                fontColor: ConstantsGlucoseChart.axisLabelColorHidden
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
        
        // initialize calibrationsAccessor
        if calibrationsAccessor == nil {
            calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        }
        
        // initialize treatmentEntryAccessor
        if treatmentEntryAccessor == nil {
            treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
        }
        
        return (chartSettings!, chartPointDateFormatter!, operationQueue!, chartLabelSettings!, chartLabelSettingsObjectives!, chartLabelSettingsObjectivesSecondary!, chartLabelSettingsTarget!, chartLabelSettingsDimmed!, chartLabelSettingsHidden!, chartGuideLinesLayerSettings!, axisLabelTimeFormatter!, bgReadingsAccessor!, calibrationsAccessor!, treatmentEntryAccessor!)
        
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
                return ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl.mgdlToMmol(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            }
            
        }

    }
    
}
