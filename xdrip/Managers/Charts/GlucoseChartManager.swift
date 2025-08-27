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
    /// - bgCheck = blood glucose (finger) checks
    /// - scheduledBasalRates = the scheduled basal rate from the Nightscout profile
    /// - basalRates/basalRatesFill = the temp basal rates (line and fill)
    typealias TreatmentChartPointsType = (smallBolus: [ChartPoint], mediumBolus: [ChartPoint], largeBolus: [ChartPoint], veryLargeBolus: [ChartPoint], smallCarbs: [ChartPoint], mediumCarbs: [ChartPoint], largeCarbs: [ChartPoint], veryLargeCarbs: [ChartPoint], bgChecks: [ChartPoint], scheduledBasalRates: [ChartPoint], basalRates: [ChartPoint], basalRatesFill: [ChartPoint])
    
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
    private var treatmentChartPoints: TreatmentChartPointsType = ([ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint]())
    
    /// smallBolusTreatmentChartPoints to be shown on chart
    private var smallBolusTreatmentChartPoints = [ChartPoint]()
    
    /// mediumBolusTreatmentChartPoints to be shown on chart
    private var mediumBolusTreatmentChartPoints = [ChartPoint]()
    
    /// largeBolusTreatmentChartPoints to be shown on chart
    private var largeBolusTreatmentChartPoints = [ChartPoint]()
    
    /// veryLargeBolusTreatmentChartPoints to be shown on chart
    private var veryLargeBolusTreatmentChartPoints = [ChartPoint]()
    
    /// smallCarbsTreatmentChartPoints to be shown on chart
    private var smallCarbsTreatmentChartPoints = [ChartPoint]()
    
    /// mediumCarbsTreatmentChartPoints to be shown on chart
    private var mediumCarbsTreatmentChartPoints = [ChartPoint]()
    
    /// largeCarbsTreatmentChartPoints to be shown on chart
    private var largeCarbsTreatmentChartPoints = [ChartPoint]()
    
    /// veryLargeCarbsTreatmentChartPoints to be shown on chart
    private var veryLargeCarbsTreatmentChartPoints = [ChartPoint]()
    
    /// bgCheckTreatmentChartPoints to be shown on chart
    private var bgCheckTreatmentChartPoints = [ChartPoint]()
    
    /// scheduledBasalRateTreatmentChartPoints to be shown on chart
    private var scheduledBasalRateTreatmentChartPoints = [ChartPoint]()
    
    /// basalRateTreatmentChartPoints to be shown on chart
    private var basalRateTreatmentChartPoints = [ChartPoint]()
    
    /// basalRateTreatmentChartPoints to be shown on chart
    private var basalRateFillTreatmentChartPoints = [ChartPoint]()
    
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
    
    /// initialise nightscoutSyncManager
    private var nightscoutSyncManager: NightscoutSyncManager?
    
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
    
    /// - the scaler to apply to the basal rates. Let's just set it at 0, we'll update it soon after
    private var basalRateMaximum: Double = 0
    /// - the scaler to apply to the basal rates. Let's just set it at 20, we'll update it soon after
    private var basalRateScaler: Double = 20
    
    /// if the class is iniatated by the view controller without specifying a Gesture Recogniser, then we are not displaying the main chart, but the static 24 hour chart from the landscape view controller
    private var isStatic24hrChart: Bool = false
    
    /// - if glucoseChartPoints.count > 0, then this is the latest one that has timestamp less than endDate.
    private(set) var lastChartPointEarlierThanEndDate: ChartPoint?
    
    /// is chart in panned state or not, meaning is it currently shifted back in time
    private(set) var chartIsPannedBackward: Bool = false
    
    /// array to hold the scheduled basal rates - they will be populated from NightscoutSyncManager.profile as required
    private var scheduledBasalRatesArray = [(date: Date, value: Double)]()
    
    /// track when the scheduled basal rates array was populated. If chartStartDate changes by more than, say, 6 hours, then we'll repopulate
    /// set the .distantPast on initialization so that a fresh population is forced
    private var scheduledBasalRatesLastUpdatedForStartDate: Date = .distantPast
    
    // MARK: - intializer
    
    /// - parameters:
    ///     - chartLongPressGestureRecognizer : defined here as parameter so that this class can handle the config of the recognizer
    ///     - chartLongPressGestureRecognizer has been made optional (initialized to nil) as it doesn't need to be used for the static landscape chart
    init(chartLongPressGestureRecognizer: UILongPressGestureRecognizer? = nil, coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager) {
        
        // set coreDataManager
        self.coreDataManager = coreDataManager
        
        // set nightscoutSyncManager
        self.nightscoutSyncManager = nightscoutSyncManager
        
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
    ///     - endDate: endDate to apply
    ///     - startDate: startDate to apply, if nil then no change will be done in chart width, ie current difference between start and end will be reused
    ///     - chartOutlet: the view that contains the chart
    ///     - forceReset: used to indicate that we should rescale the y-axis (done by simply setting maximumValueInGlucoseChartPointsInMgDl to it's initial value)
    ///     - completionHandler: will be called when glucoseChartPoints and chartOutlet are updated
    ///
    /// update of chartPoints array will be done on background thread. The actual redrawing of the chartoutlet is  done on the main thread. Also the completionHandler runs in the main thread.
    /// While updating glucoseChartPoints in background thread, the main thread may call again updateChartPoints with a new endDate (because the user is panning or zooming). A new block will be added in the operation queue and processed later. If there's multiple operations waiting in the queue, only the last one will be executed. This can be the case when the user is doing a fast panning.
    public func updateChartPoints(endDate: Date, startDate: Date?, chartOutlet: BloodGlucoseChartView, forceReset: Bool = false, completionHandler: (() -> ())?) {
        
        // create a new operation
        let operation = BlockOperation(block: {
            
            // if there's more than one operation waiting for execution, it makes no sense to execute this one, the next one has a newer endDate to use
            guard self.data().operationQueue.operations.count <= 1 else {
                return
            }
            
            // if the forceReset parameter has been set, then set maximumValueInGlucoseChartPointsInMgDl to it's initial value
            // this will force the y-axis to be reset to it's initial state
            if forceReset {
                self.maximumValueInGlucoseChartPointsInMgDl = ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl
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
                .count + self.glucoseChartPoints.inRange.count + self.glucoseChartPoints.notUrgentRange.count <= ConstantsGlucoseChart.maximumElementsInGlucoseChartPointsArray ? true : false
            
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
                let treatmentChartPoints: TreatmentChartPointsType = self.getTreatmentChartPoints(startDate: startDateToUse, endDate: endDate, treatmentEntryAccessor: self.data().treatmentEntryAccessor, bgReadingsAccessor: self.data().bgReadingsAccessor, on: self.coreDataManager.privateManagedObjectContext)
                
                // assign treatment arrays
                self.treatmentChartPoints.smallBolus = treatmentChartPoints.smallBolus
                self.treatmentChartPoints.mediumBolus = treatmentChartPoints.mediumBolus
                self.treatmentChartPoints.largeBolus = treatmentChartPoints.largeBolus
                self.treatmentChartPoints.veryLargeBolus = treatmentChartPoints.veryLargeBolus
                
                self.treatmentChartPoints.smallCarbs = treatmentChartPoints.smallCarbs
                self.treatmentChartPoints.mediumCarbs = treatmentChartPoints.mediumCarbs
                self.treatmentChartPoints.largeCarbs = treatmentChartPoints.largeCarbs
                self.treatmentChartPoints.veryLargeCarbs = treatmentChartPoints.veryLargeCarbs
                
                self.treatmentChartPoints.bgChecks = treatmentChartPoints.bgChecks
                
                self.treatmentChartPoints.scheduledBasalRates = treatmentChartPoints.scheduledBasalRates
                
                self.treatmentChartPoints.basalRates = treatmentChartPoints.basalRates
                self.treatmentChartPoints.basalRatesFill = treatmentChartPoints.basalRatesFill
                
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
                self.largeBolusTreatmentChartPoints = self.treatmentChartPoints.largeBolus
                self.veryLargeBolusTreatmentChartPoints = self.treatmentChartPoints.veryLargeBolus
                
                // assign the carbs treatment chart points
                self.smallCarbsTreatmentChartPoints = self.treatmentChartPoints.smallCarbs
                self.mediumCarbsTreatmentChartPoints = self.treatmentChartPoints.mediumCarbs
                self.largeCarbsTreatmentChartPoints = self.treatmentChartPoints.largeCarbs
                self.veryLargeCarbsTreatmentChartPoints = self.treatmentChartPoints.veryLargeCarbs
                
                // assign the BG check treatment chart points
                self.bgCheckTreatmentChartPoints = self.treatmentChartPoints.bgChecks
                
                // assign the basal rate treatment chart points
                self.scheduledBasalRateTreatmentChartPoints = self.treatmentChartPoints.scheduledBasalRates
                self.basalRateTreatmentChartPoints = self.treatmentChartPoints.basalRates
                self.basalRateFillTreatmentChartPoints = self.treatmentChartPoints.basalRatesFill
                
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
        
        updateChartPoints(endDate: newEndDate, startDate: newStartDate, chartOutlet: chartOutlet, forceReset: false, completionHandler: completionHandler)
        
    }
    
    private func generateGlucoseChartWithFrame(_ frame: CGRect) -> Chart? {
        
        let xAxisValues = generateXAxisValues()
        
        guard xAxisValues.count > 1 else {return nil}
        
        let xAxisModel = ChartAxisModel(axisValues: xAxisValues, lineColor: ConstantsGlucoseChart.axisLineColor, labelSpaceReservationMode: .fixed(20))
        
        // just to save typing
        let unitIsMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // create yAxisValues, start with 38 mgdl, this is to make sure we show a bit lower than the real lowest value which is usually 40 mgdl, make the label hidden. We must do this with by using a clear color label setting as the hidden property doesn't work (even if we don't know why).
        //        let firstYAxisValue = ChartAxisValueDouble((ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl).mgDlToMmol(mgDl: unitIsMgDl), labelSettings: data().chartLabelSettingsHidden)
        let minimumChartValue = UserDefaults.standard.showTreatmentsOnChart ? (UserDefaults.standard.nightscoutFollowType != .none ? (isStatic24hrChart ? ConstantsGlucoseChart.minimumChartValueInMgdlWithBasal24hrChart : ConstantsGlucoseChart.minimumChartValueInMgdlWithBasal) : ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl) : ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl
        
        let firstYAxisValue = ChartAxisValueDouble(minimumChartValue.mgDlToMmol(mgDl: unitIsMgDl), labelSettings: data().chartLabelSettingsHidden)
        
        // create now the yAxisValues and add the first
        var yAxisValues = [firstYAxisValue as ChartAxisValue]
        
        // if the user has a low urgent value > 50 (which *should* be the case), let's add a dimmed axis value of 40 to give the graph more context. If not, then just ignore it and their low urgent value will become the lowest label value
        if UserDefaults.standard.urgentLowMarkValueInUserChosenUnit >= (unitIsMgDl ? 50 : 2.7) {
            yAxisValues += [ChartAxisValueDouble(unitIsMgDl ? 40 : 2.2, labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
        }
        
        // start by adding the objective values as the axis values
        yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.urgentLowMarkValueInUserChosenUnit.bgValueRounded(mgDl: unitIsMgDl), labelSettings: data().chartLabelSettingsObjectivesSecondary) as ChartAxisValue]
        
        yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.lowMarkValueInUserChosenUnit.bgValueRounded(mgDl: unitIsMgDl), labelSettings: data().chartLabelSettingsObjectives) as ChartAxisValue]
        
        // if the user has set the target value > 0, then enable the label too
        if UserDefaults.standard.targetMarkValueInUserChosenUnit > 0 {
            yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.targetMarkValueInUserChosenUnit.bgValueRounded(mgDl: unitIsMgDl), labelSettings: data().chartLabelSettingsTarget) as ChartAxisValue]
        }
        
        yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.highMarkValueInUserChosenUnit.bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl), labelSettings: data().chartLabelSettingsObjectives) as ChartAxisValue]
        
        yAxisValues += [ChartAxisValueDouble(UserDefaults.standard.urgentHighMarkValueInUserChosenUnit.bgValueRounded(mgDl: unitIsMgDl), labelSettings: data().chartLabelSettingsObjectivesSecondary) as ChartAxisValue]
        
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
        if (UserDefaults.standard.urgentHighMarkValueInUserChosenUnit < (unitIsMgDl ? 240 : 14)) && (yAxisValues.last!.scalar < maximumValueInGlucoseChartPointsInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) ) {
            yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 250 : 15), labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
        }
        
        if (UserDefaults.standard.urgentHighMarkValueInUserChosenUnit <= (unitIsMgDl ? 280 : 17)) && (yAxisValues.last!.scalar < maximumValueInGlucoseChartPointsInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) ) {
            yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 300 : 18), labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
        }
        
        if (UserDefaults.standard.urgentHighMarkValueInUserChosenUnit <= (unitIsMgDl ? 330 : 20)) && (yAxisValues.last!.scalar < maximumValueInGlucoseChartPointsInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) ) {
            yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 350 : 21), labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
        }
        
        if (UserDefaults.standard.urgentHighMarkValueInUserChosenUnit <= (unitIsMgDl ? 380 : 23)) && (yAxisValues.last!.scalar < maximumValueInGlucoseChartPointsInMgDl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) ) {
            yAxisValues += [ChartAxisValueDouble((unitIsMgDl ? 400 : 24), labelSettings: data().chartLabelSettingsDimmed) as ChartAxisValue]
        }
        
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: ConstantsGlucoseChart.axisLineColor, labelSpaceReservationMode: .fixed(labelsWidthY))
        
        // put Y axis on right side
        let coordsSpace = ChartCoordsSpaceRightBottomSingleAxis(chartSettings: data().chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)
        
        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
        
        // as the user can modify the chart width in hours, we should slightly reduce the size of the chart point symbols so that the chart isn't crowded when using 12h or 24h options
        // fix the initial values. As this scaling should never need to be adjusted, this is done locally here and not with values stored in ConstantsGlucoseChart
        var glucoseCircleDiameter: CGFloat = 0
        
        var bolusTriangleSize: CGFloat = 0
        
        var treatmentSeparationOffset: CGFloat = 0
        
        // define the fixed separation of each label from it's corresponding marker. The bigger markers need a bigger separation to stop the label from covering it
        // we also define a separation offset which is mutable and will be adjusted next to dynamically change based upon the chart width and height - this is used to keep everything looking the same no matter what scales are in use
        var bolusLabelSeparationOffset: Double = 0
        let mediumBolusLabelSeparation: Double = ConstantsGlucoseChart.mediumBolusLabelSeparation
        let largeBolusLabelSeparation: Double = ConstantsGlucoseChart.largeBolusLabelSeparation
        let veryLargeBolusLabelSeparation: Double = ConstantsGlucoseChart.veryLargeBolusLabelSeparation
        
        var carbsLabelSeparationOffset: Double = 0
        //let smallCarbsLabelSeparation: Double = ConstantsGlucoseChart.smallCarbsLabelSeparation
        let mediumCarbsLabelSeparation: Double = ConstantsGlucoseChart.mediumCarbsLabelSeparation
        let largeCarbsLabelSeparation: Double = ConstantsGlucoseChart.largeCarbsLabelSeparation
        let veryLargeCarbsLabelSeparation: Double = ConstantsGlucoseChart.veryLargeCarbsLabelSeparation
        
        var treatmentLabelFontSize: Double = ConstantsGlucoseChart.treatmentLabelFontSize
        
        // adjust marker sizes and label size/separation based upon the chart width
        switch UserDefaults.standard.chartWidthInHours {
            
        case 3:
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter3h
            bolusTriangleSize = ConstantsGlucoseChart.bolusTriangleSize3h
            treatmentSeparationOffset += 1
            treatmentLabelFontSize += 2
            bolusLabelSeparationOffset += 1
            carbsLabelSeparationOffset += 2
        case 6:
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter6h
            bolusTriangleSize = ConstantsGlucoseChart.bolusTriangleSize6h
        case 12:
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter12h
            bolusTriangleSize = ConstantsGlucoseChart.bolusTriangleSize12h
            treatmentSeparationOffset += 2
            treatmentLabelFontSize -= 1
            bolusLabelSeparationOffset -= 1
            carbsLabelSeparationOffset -= 2
        case 24:
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter24h
            bolusTriangleSize = ConstantsGlucoseChart.bolusTriangleSize24h
            treatmentSeparationOffset += 3
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
            treatmentSeparationOffset += 5
            bolusLabelSeparationOffset += 6
            carbsLabelSeparationOffset += 6
        case 300...600:
            treatmentSeparationOffset += 10
            bolusLabelSeparationOffset += 16
            carbsLabelSeparationOffset += 16
        default:
            break
            
        }
        
        // check if we're using the static 24hr landscape chart and then just adjust further as needed. This is needed because the chart ratio is squashed more in landscape orientation
        if isStatic24hrChart {
            
            glucoseCircleDiameter = ConstantsGlucoseChart.glucoseCircleDiameter24h
            treatmentSeparationOffset += 0
            treatmentLabelFontSize -= 1
            bolusLabelSeparationOffset += 2
            carbsLabelSeparationOffset += 1
            
        }
        
        // now that we know innerFrame we can set innerFrameWidth
        innerFrameWidth = Double(innerFrame.width)
        
        chartGuideLinesLayerSettings = ChartGuideLinesLayerSettings(linesColor: ConstantsGlucoseChart.gridColorObjectives, linesWidth: 0.5)
        
        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: data().chartGuideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)
        
        // high/low/target guideline layer settings and styles
        let urgentHighLowLineLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: ConstantsGlucoseChart.guidelineUrgentHighLow, linesWidth: 1, dotWidth: 2, dotSpacing: 8)
        
        let highLowLineLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: ConstantsGlucoseChart.guidelineHighLow, linesWidth: 1, dotWidth: 4, dotSpacing: 4)
        
        let targetLineLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: ConstantsGlucoseChart.guidelineTargetColor, linesWidth: UserDefaults.standard.targetMarkValueInUserChosenUnit > 0 ? 1 : 0, dotWidth: 12, dotSpacing: 6)
        
        // high/low/target guidelines
        let urgentHighLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: urgentHighLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.urgentHighMarkValueInUserChosenUnit)])
        
        let highLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: highLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.highMarkValueInUserChosenUnit)])
        
        let targetLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: targetLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.targetMarkValueInUserChosenUnit)])
        
        let lowLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: highLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.lowMarkValueInUserChosenUnit)])
        
        let urgentLowLineLayer = ChartGuideLinesForValuesDottedLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: urgentHighLowLineLayerSettings, axisValuesX: [ChartAxisValueDouble(0)], axisValuesY: [ChartAxisValueDouble(UserDefaults.standard.urgentLowMarkValueInUserChosenUnit)])
        
        // calibration points circle layers - we'll create two circles, one on top of the other to give a white border as per Nightscout calibrations. We'll make the inner circle UIColor.red to make it slightly different to the UIColor.systemRed used by the glucoseChartPoints. Both circles will be scaled as per the current glucoseCircleDiameter but bigger so that they stand out
        let calibrationCirclesOuterLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: calibrationChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.calibrationCircleScaleOuter, height: glucoseCircleDiameter * ConstantsGlucoseChart.calibrationCircleScaleOuter), itemFillColor: ConstantsGlucoseChart.calibrationCircleColorOuter, optimized: true)
        
        let calibrationCirclesInnerLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: calibrationChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.calibrationCircleScaleInner, height: glucoseCircleDiameter * ConstantsGlucoseChart.calibrationCircleScaleInner), itemFillColor: ConstantsGlucoseChart.calibrationCircleColorInner, optimized: true)
        
        // bg check treatment circle layers - we'll create two circles, one on top of the other to give a gray border as per Nightscout BG Checks. We'll make the inner circle UIColor.red to make it slightly different to the UIColor.systemRed used by the glucoseChartPoints. Both circles will be scaled as per the current glucoseCircleDiameter but bigger so that they stand out
        let bgCheckCirclesOuterLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: bgCheckTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.bgCheckTreatmentScaleOuter , height: glucoseCircleDiameter * ConstantsGlucoseChart.bgCheckTreatmentScaleOuter), itemFillColor: ConstantsGlucoseChart.bgCheckTreatmentColorOuter, optimized: true)
        
        let bgCheckCirclesInnerLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: bgCheckTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.bgCheckTreatmentScaleInner, height: glucoseCircleDiameter * ConstantsGlucoseChart.bgCheckTreatmentScaleInner), itemFillColor: ConstantsGlucoseChart.bgCheckTreatmentColorInner, optimized: true)
        
        
        // bolus triangle layers
        let smallBolusTriangleLayer = ChartPointsScatterDownTrianglesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: smallBolusTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: bolusTriangleSize * ConstantsGlucoseChart.smallBolusTreatmentScale, height: (bolusTriangleSize * ConstantsGlucoseChart.bolusTriangleHeightScale) * ConstantsGlucoseChart.smallBolusTreatmentScale), itemFillColor: ConstantsGlucoseChart.bolusTreatmentColor)
        
        let mediumBolusTriangleLayer = ChartPointsScatterDownTrianglesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: mediumBolusTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: bolusTriangleSize * ConstantsGlucoseChart.mediumBolusTreatmentScale, height: bolusTriangleSize * ConstantsGlucoseChart.bolusTriangleHeightScale * ConstantsGlucoseChart.mediumBolusTreatmentScale), itemFillColor: ConstantsGlucoseChart.bolusTreatmentColor)
        
        let largeBolusTriangleLayer = ChartPointsScatterDownTrianglesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: largeBolusTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: bolusTriangleSize * ConstantsGlucoseChart.largeBolusTreatmentScale, height: bolusTriangleSize * ConstantsGlucoseChart.bolusTriangleHeightScale * ConstantsGlucoseChart.largeBolusTreatmentScale), itemFillColor: ConstantsGlucoseChart.bolusTreatmentColor)
        
        let veryLargeBolusTriangleLayer = ChartPointsScatterDownTrianglesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: veryLargeBolusTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: bolusTriangleSize * ConstantsGlucoseChart.veryLargeBolusTreatmentScale, height: bolusTriangleSize * ConstantsGlucoseChart.bolusTriangleHeightScale * ConstantsGlucoseChart.veryLargeBolusTreatmentScale), itemFillColor: ConstantsGlucoseChart.bolusTreatmentColor)
        
        
        // carb circle layers
        let smallCarbsLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: smallCarbsTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.smallCarbsTreatmentScale, height: glucoseCircleDiameter * ConstantsGlucoseChart.smallCarbsTreatmentScale), itemFillColor: ConstantsGlucoseChart.carbsTreatmentColor, optimized: true)
        
        let mediumCarbsLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: mediumCarbsTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.mediumCarbsTreatmentScale, height: glucoseCircleDiameter * ConstantsGlucoseChart.mediumCarbsTreatmentScale), itemFillColor: ConstantsGlucoseChart.carbsTreatmentColor, optimized: true)
        
        let largeCarbsLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: largeCarbsTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.largeCarbsTreatmentScale, height: glucoseCircleDiameter * ConstantsGlucoseChart.largeCarbsTreatmentScale), itemFillColor: ConstantsGlucoseChart.carbsTreatmentColor, optimized: true)
        
        let veryLargeCarbsLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: veryLargeCarbsTreatmentChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter * ConstantsGlucoseChart.veryLargeCarbsTreatmentScale, height: glucoseCircleDiameter * ConstantsGlucoseChart.veryLargeCarbsTreatmentScale), itemFillColor: ConstantsGlucoseChart.carbsTreatmentColor, optimized: true)
        
        
        // Scheduled basal rate line
        let scheduledBasalRateLayerLineModel = ChartLineModel(chartPoints: scheduledBasalRateTreatmentChartPoints, lineColor: ConstantsGlucoseChart.scheduledBasalRateTreatmentLineColor, lineWidth: ConstantsGlucoseChart.scheduledBasalRateTreatmentLineWidth, animDuration: 0, animDelay: 0, dashPattern: [3, 2])
        
        let scheduledBasalRateLayer = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [scheduledBasalRateLayerLineModel])
        
        
        // Basal rate line + fill layers
        let basalRateLayerLineModel = ChartLineModel(chartPoints: basalRateTreatmentChartPoints, lineColor: ConstantsGlucoseChart.basalRateTreatmentLineColor, lineWidth: ConstantsGlucoseChart.basalRateTreatmentLineWidth, animDuration: 0, animDelay: 0)
        
        let basalRateLayer = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [basalRateLayerLineModel])
        
        let basalRateFillLayer = ChartPointsFillsLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, fills: [ChartPointsFill( chartPoints: basalRateFillTreatmentChartPoints, fillColor: ConstantsGlucoseChart.basalRateFillTreatmentColor, createContainerPoints: false)])
        
        
        // in Range circle layers
        let inRangeGlucoseCirclesLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: inRangeGlucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter, height: glucoseCircleDiameter), itemFillColor: ConstantsGlucoseChart.glucoseInRangeColor, optimized: true)
        
        // urgent Range circle layers
        let urgentRangeGlucoseCirclesLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: urgentRangeGlucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter, height: glucoseCircleDiameter), itemFillColor: ConstantsGlucoseChart.glucoseUrgentRangeColor, optimized: true)
        
        // not urgent Range circle layers
        let notUrgentRangeGlucoseCirclesLayer = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: notUrgentRangeGlucoseChartPoints, displayDelay: 0, itemSize: CGSize(width: glucoseCircleDiameter, height: glucoseCircleDiameter), itemFillColor: ConstantsGlucoseChart.glucoseNotUrgentRangeColor, optimized: true)
        
        
        // treatment labels layers
        let mediumBolusLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: mediumBolusTreatmentChartPoints, labelSeparation: mediumBolusLabelSeparation, labelSeparationOffset: bolusLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Insulin, treatmentLabelFontSize: treatmentLabelFontSize, showLabelBelow: true, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        let largeBolusLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: largeBolusTreatmentChartPoints, labelSeparation: largeBolusLabelSeparation, labelSeparationOffset: bolusLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Insulin, treatmentLabelFontSize: treatmentLabelFontSize, showLabelBelow: true, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        let veryLargeBolusLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: veryLargeBolusTreatmentChartPoints, labelSeparation: veryLargeBolusLabelSeparation, labelSeparationOffset: bolusLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Insulin, treatmentLabelFontSize: treatmentLabelFontSize, showLabelBelow: true, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        
        //let smallCarbsLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: smallCarbsTreatmentChartPoints, labelSeparation: smallCarbsLabelSeparation, labelSeparationOffset: carbsLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Carbs, treatmentLabelFontSize: treatmentLabelFontSize, showLabelBelow: false, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        let mediumCarbsLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: mediumCarbsTreatmentChartPoints, labelSeparation: mediumCarbsLabelSeparation, labelSeparationOffset: carbsLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Carbs, treatmentLabelFontSize: treatmentLabelFontSize, showLabelBelow: false, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        let largeCarbsLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: largeCarbsTreatmentChartPoints, labelSeparation: largeCarbsLabelSeparation, labelSeparationOffset: carbsLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Carbs, treatmentLabelFontSize: treatmentLabelFontSize, showLabelBelow: false, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        let veryLargeCarbsLabelsLayer = createTreatmentLabelsLayer(treatmentChartPoints: veryLargeCarbsTreatmentChartPoints, labelSeparation: veryLargeCarbsLabelSeparation, labelSeparationOffset: carbsLabelSeparationOffset, xAxisLayer: xAxisLayer, yAxisLayer: yAxisLayer, treatmentType: TreatmentType.Carbs, treatmentLabelFontSize: treatmentLabelFontSize, showLabelBelow: false, y: innerFrame.origin.y, height: innerFrame.size.height)
        
        
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
            urgentLowLineLayer,
        ]
        
        if UserDefaults.standard.showTreatmentsOnChart, UserDefaults.standard.nightscoutFollowType != .none {
            let layersAIDFollow: [ChartLayer?] = [
                // basal rate layers
                basalRateFillLayer,
                basalRateLayer,
                // scheduled basal rate layers
                scheduledBasalRateLayer,
            ]
            
            layers.append(contentsOf: layersAIDFollow)
        }
        
        if UserDefaults.standard.showTreatmentsOnChart {
            let layersTreatments: [ChartLayer?] = [
                // basal rate layers
                basalRateFillLayer,
                basalRateLayer,
                // scheduled basal rate layers
                scheduledBasalRateLayer,
                // carb treatment layers
                veryLargeCarbsLayer,
                largeCarbsLayer,
                mediumCarbsLayer,
                smallCarbsLayer,
                // bolus treatment layers
                smallBolusTriangleLayer,
                mediumBolusTriangleLayer,
                largeBolusTriangleLayer,
                veryLargeBolusTriangleLayer,
            ]
            
            layers.append(contentsOf: layersTreatments)
        }
        
        let layersGlucoseCircles: [ChartLayer?] = [
            // glucosePoint layers
            inRangeGlucoseCirclesLayer,
            notUrgentRangeGlucoseCirclesLayer,
            urgentRangeGlucoseCirclesLayer,
            // calibrationPoint layers
            calibrationCirclesOuterLayer,
            calibrationCirclesInnerLayer,
        ]
        
        layers.append(contentsOf: layersGlucoseCircles)
        
        if UserDefaults.standard.showTreatmentsOnChart {
            let layersTreatmentLabels: [ChartLayer?] = [
                // bg check treatment layers
                bgCheckCirclesOuterLayer,
                bgCheckCirclesInnerLayer,
                // carb treatment label layers
                //smallCarbsLabelsLayer,
                mediumCarbsLabelsLayer,
                largeCarbsLabelsLayer,
                veryLargeCarbsLabelsLayer,
                // bolus treatment label layers
                mediumBolusLabelsLayer,
                largeBolusLabelsLayer,
                veryLargeBolusLabelsLayer,
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
    private func getTreatmentChartPoints(startDate: Date, endDate: Date, treatmentEntryAccessor: TreatmentEntryAccessor, bgReadingsAccessor: BgReadingsAccessor, on managedObjectContext: NSManagedObjectContext) -> ([ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint], [ChartPoint]) {
        
        func treatmentSeparationOffset(maximumValueInGlucoseChartPointsInMgDl: Double) -> Double {
            let defaultOffsetTreatmentPositionFromBgMarker = ConstantsGlucoseChart.defaultOffsetTreatmentPositionFromBgMarker
            
            switch maximumValueInGlucoseChartPointsInMgDl {
            case 0...299:
                return defaultOffsetTreatmentPositionFromBgMarker
            case 199...299:
                return defaultOffsetTreatmentPositionFromBgMarker + 5
            default:
                return defaultOffsetTreatmentPositionFromBgMarker + 15
            }
        }
        
        /// function to check and plot the chart points of the scheduled basal rates in case the previously enacted temp basal expires before the current temp-basal was enacted
        /// we have to assume that there could be a large gap so we should cycle through the scheduled basal rates and plot them all to the chart until the current temp-basal is enacted
        /// - Parameters:
        ///   - isFirstEntry: boolean that indicates if this is the first chartpoints on the chart (important as we need ot treat them differently)
        ///   - previousBasalRate: a double with the previous basal rate (used to cleanly finish the temp basal chart points)
        ///   - previousBasalRateTreamentEndDate: a double which represents the temp basal finish date (temp basal timestamp + minutes duration)
        ///   - basalRateTreamentDate: a date of the start of the new temp basal that has been enacted (used to cleanly finish the scheduled basal chart points at the correct time)
        func checkAndAddScheduledBasalChartPointsIfNeeded(isFirstEntry: Bool, previousBasalRate: Double, previousBasalRateTreamentEndDate: Date, basalRateTreamentDate: Date?) {
            // if this is the first entry, then we need to treat it differently to make sure we anchor the previously enacted rate to the start date
            if isFirstEntry {
                // check if the previous temp basal is still active at the start of the chart
                // if so, then display it
                if previousBasalRateTreamentEndDate > startDate {
                    // start the previous temp basal at the start date
                    basalRateTreatmentChartPoints.append(ChartPoint(basalRate: previousBasalRate, date: startDate, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                    
                    // now finish the previous temp basal at the time it is supposed to finish
                    basalRateTreatmentChartPoints.append(ChartPoint(basalRate: previousBasalRate, date: previousBasalRateTreamentEndDate, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                }
            } else {
                basalRateTreatmentChartPoints.append(ChartPoint(basalRate: previousBasalRate, date: previousBasalRateTreamentEndDate, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
            }
            
            // get the scheduled basal rate that was valid before the previous temp basal ended
            if let previousScheduledBasalRateEntry = scheduledBasalRatesArray.filter({ $0.date <= max(previousBasalRateTreamentEndDate, startDate) }).last {
                // track the scheduled basal rate being used - this will be updated as we cycle through any changes to this
                var previousScheduledBasalRate = previousScheduledBasalRateEntry.value
                
                // start the scheduled basal rate at the time the previous temp basal finished
                basalRateTreatmentChartPoints.append(ChartPoint(basalRate: previousScheduledBasalRate, date: max(previousBasalRateTreamentEndDate, startDate), basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                
                // get any scheduled basal rate changes between the previous one ending and the current one starting
                let nextScheduledBasalRateEntries = scheduledBasalRatesArray.filter({ $0.date >= max(previousBasalRateTreamentEndDate, startDate) && $0.date <= (basalRateTreamentDate ?? endDate) })
                
                // if there are some, then loop through them and create all the needed chart points
                if nextScheduledBasalRateEntries.count > 0 {
                    for nextScheduledBasalRateEntry in nextScheduledBasalRateEntries {
                        // finish the previous scheduled basal rate at the time we change to the new one
                        basalRateTreatmentChartPoints.append(ChartPoint(basalRate: previousScheduledBasalRate, date: nextScheduledBasalRateEntry.date, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                        
                        // start a new scheduled basal rate
                        basalRateTreatmentChartPoints.append(ChartPoint(basalRate: nextScheduledBasalRateEntry.value, date: nextScheduledBasalRateEntry.date, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                        
                        // update the previous scheduled basal rate with the current value so that it becomes "previous" in the next loop
                        previousScheduledBasalRate = nextScheduledBasalRateEntry.value
                    }
                }
                
                // now there are no more scheduled basal rates to display until the new temp basal,
                // extend the previous scheduled basal rate until the new temp basal date
                basalRateTreatmentChartPoints.append(ChartPoint(basalRate: previousScheduledBasalRate, date: basalRateTreamentDate ?? min(endDate, .now), basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
            }
        }
        
        // get bgReadings between the two dates
        // this will later be used to calculate the Y value for each carbsTreatment.
        let bgReadings = bgReadingsAccessor.getBgReadings(from: startDate, to: endDate, on: managedObjectContext)
        
        let minimumChartValueInMgdl = isStatic24hrChart ? ConstantsGlucoseChart.minimumChartValueInMgdlWithBasal24hrChart : ConstantsGlucoseChart.minimumChartValueInMgdlWithBasal
        
        // intialize the treatment chart point arrays
        var smallBolusTreatmentChartPoints = [ChartPoint]()
        var mediumBolusTreatmentChartPoints = [ChartPoint]()
        var largeBolusTreatmentChartPoints = [ChartPoint]()
        var veryLargeBolusTreatmentChartPoints = [ChartPoint]()
        
        var smallCarbsTreatmentChartPoints = [ChartPoint]()
        var mediumCarbsTreatmentChartPoints = [ChartPoint]()
        var largeCarbsTreatmentChartPoints = [ChartPoint]()
        var veryLargeCarbsTreatmentChartPoints = [ChartPoint]()
        
        var bgCheckTreatmentChartPoints = [ChartPoint]()
        
        var scheduledBasalRateTreatmentChartPoints = [ChartPoint]()
        
        var basalRateTreatmentChartPoints = [ChartPoint]()
        var basalRateFillTreatmentChartPoints = [ChartPoint]()
        
        if UserDefaults.standard.showTreatmentsOnChart {
            managedObjectContext.performAndWait {
                // get Treatments between the two timestamps from coredata
                // filter the treatment entries that have not been marked as deleted
                let treatmentEntries = treatmentEntryAccessor.getTreatments(fromDate: startDate, toDate: endDate, on: managedObjectContext).filter({ !$0.treatmentdeleted })
                
                // Filter the treatments by treatmentType.
                let insulinTreatments = treatmentEntries.filter { $0.treatmentType == .Insulin }
                let carbsTreatments = treatmentEntries.filter { $0.treatmentType == .Carbs }
                let bgCheckTreatments = treatmentEntries.filter { $0.treatmentType == .BgCheck }
                // for the basal rate changes, we need to have the oldest one first and work forward so let's reverse the order
                // it's needed to define the type [TreatmentEntry] explicity to prevent issues
                let basalRateTreatments: [TreatmentEntry] = treatmentEntries.filter { $0.treatmentType == .Basal }.reversed()
                
                
                // *****************************
                // ***** insulin Treatments *****
                // *****************************
                // Calculate the Y value for each treatment.
                let insulinYValues = calculateClosestYAxisValues(treatments: insulinTreatments, bgReadings: bgReadings)
                
                // For each carbsTreatment, get its Y value from insulinYValues, create a ChartPoint
                // and append it to the correct chart points list.
                for (indexInsulinTreatment, insulinTreatment) in insulinTreatments.enumerated() {
                    // Retrieve the Y value from insulinYValues
                    // note the - to show the bolus markers underneath the BG values
                    let calculatedYAxisValue = insulinYValues[indexInsulinTreatment] - treatmentSeparationOffset(maximumValueInGlucoseChartPointsInMgDl: maximumValueInGlucoseChartPointsInMgDl)
                    
                    // We use an extended ChartPoint class to pass the new y axis value
                    let chartPoint = ChartPoint(treatmentEntry: insulinTreatment, formatter: data().chartPointDateFormatter, newYAxisValue: calculatedYAxisValue)
                    
                    // cycle through the possible threshold values and append the carb chart point to the correct array.
                    if insulinTreatment.value < ConstantsGlucoseChart.smallBolusTreatmentThreshold {
                        smallBolusTreatmentChartPoints.append(chartPoint)
                    } else if insulinTreatment.value < ConstantsGlucoseChart.mediumBolusTreatmentThreshold {
                        mediumBolusTreatmentChartPoints.append(chartPoint)
                    } else if insulinTreatment.value < ConstantsGlucoseChart.largeBolusTreatmentThreshold {
                        largeBolusTreatmentChartPoints.append(chartPoint)
                    } else {
                        veryLargeBolusTreatmentChartPoints.append(chartPoint)
                    }
                }
                
                
                // ***************************
                // ***** carb treatments *****
                // ***************************
                // Calculate the Y value for each carbsTreatment.
                let carbsYValues = calculateClosestYAxisValues(treatments: carbsTreatments, bgReadings: bgReadings)
                
                // For each carbsTreatment, get its Y value from carbsYValues, create a ChartPoint
                // and append it to the correct chart points list.
                for (indexCarbsTreatment, carbsTreatment) in carbsTreatments.enumerated() {
                    // Retrieve the Y value from carbsYValues
                    // note the + to show the bolus markers above the BG values
                    let calculatedYAxisValue = carbsYValues[indexCarbsTreatment] + treatmentSeparationOffset(maximumValueInGlucoseChartPointsInMgDl: maximumValueInGlucoseChartPointsInMgDl)
                    
                    // We use an extended ChartPoint class to pass the new y axis value
                    let chartPoint = ChartPoint(treatmentEntry: carbsTreatment, formatter: data().chartPointDateFormatter, newYAxisValue: calculatedYAxisValue)
                    
                    // cycle through the possible threshold values and append the carb chart point to the correct array.
                    if carbsTreatment.value < ConstantsGlucoseChart.smallCarbsTreatmentThreshold {
                        smallCarbsTreatmentChartPoints.append(chartPoint)
                    } else if carbsTreatment.value < ConstantsGlucoseChart.mediumCarbsTreatmentThreshold {
                        mediumCarbsTreatmentChartPoints.append(chartPoint)
                    } else if carbsTreatment.value < ConstantsGlucoseChart.largeCarbsTreatmentThreshold {
                        largeCarbsTreatmentChartPoints.append(chartPoint)
                    } else {
                        veryLargeCarbsTreatmentChartPoints.append(chartPoint)
                    }
                }
                
                
                // *******************************
                // ***** BG check treatments *****
                // *******************************
                // For each bgCheckTreatment, create and append a ChartPoint to bgCheckTreatmentChartPoints.
                for bgCheckTreatment in bgCheckTreatments {
                    bgCheckTreatmentChartPoints.append(ChartPoint(bgCheck: bgCheckTreatment, formatter: data().chartPointDateFormatter, unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl))
                }
                
                
                // **********************************************
                // ***** nightscout AID follower treatments *****
                // **********************************************
                if UserDefaults.standard.nightscoutFollowType != .none {
                    // *********************************
                    // ***** scheduled basal rates *****
                    // *********************************
                    // check first if there is any basal rate data in the Nightscout profile
                    if let scheduledBasalRatesFromProfile = nightscoutSyncManager?.profile.basal, let profileHasData = nightscoutSyncManager?.profile.hasData(), profileHasData {
                        // check if the scheduled basal rate array should be refreshed for the current chart start date. This should happen at start-up and
                        // also when the chart is scrolled more than 6 hours (could be more or less, but 6 hours seems reasonable to avoid unnecessary refreshes)
                        if scheduledBasalRatesLastUpdatedForStartDate < startDate.addingTimeInterval(-60 * 60 * 6) || scheduledBasalRatesLastUpdatedForStartDate > startDate.addingTimeInterval(60 * 60 * 6) {
                            // first empty the current array
                            scheduledBasalRatesArray.removeAll()
                            
                            // let's create an array with the rate times converted to start from 24 hours before and up to 24 hours
                            // after the startDate of the chart. This prevents false steps/changes when scrolling through midnight.
                            // we need to stride until +25 or swift will exit the loop before adding the +24
                            for hoursToAddToStartDate in stride(from: -24, to: 25, by: 24) {
                                for scheduledBasalRate in scheduledBasalRatesFromProfile {
                                    scheduledBasalRatesArray.append((date: scheduledBasalRate.toDate(date: startDate.toMidnight().addingTimeInterval(TimeInterval(60 * 60 * hoursToAddToStartDate))), value: scheduledBasalRate.value))
                                }
                            }
                            
                            // set the last updated date to the current start date
                            scheduledBasalRatesLastUpdatedForStartDate = startDate
                        }
                        
                        // now we've got the scheduled basal rates in a nice array with the correct
                        // dates relative to the chart date, let's start building up the chart points
                        var previousScheduledBasalRate: Double = 0
                        var isFirstEntry: Bool = true
                        
                        let basalRates = scheduledBasalRatesArray.filter({ $0.date >= startDate && $0.date <= endDate })
                        
                        // check if the basal rate changes coincide with the current chart start/end dates
                        if basalRates.count > 0 {
                            for basalRate in basalRates {
                                // filter out the dates that are later than startDate and then use the last one left.
                                // this will be the value immediately before startDate
                                if isFirstEntry, let initialBasalRate = scheduledBasalRatesArray.filter({ $0.date < startDate}).last {
                                    scheduledBasalRateTreatmentChartPoints.append(ChartPoint(basalRate: initialBasalRate.value, date: startDate, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                                    previousScheduledBasalRate = initialBasalRate.value
                                    isFirstEntry.toggle()
                                }
                                
                                // use the previous value and current time to end the previous line at the correct value
                                scheduledBasalRateTreatmentChartPoints.append(ChartPoint(basalRate: previousScheduledBasalRate, date: basalRate.date, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                                
                                // use the current value and current time to start the new line at the correct value
                                scheduledBasalRateTreatmentChartPoints.append(ChartPoint(basalRate: basalRate.value, date: basalRate.date, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                                
                                previousScheduledBasalRate = basalRate.value
                            }
                            
                            // add the final chart point to the end of the array
                            scheduledBasalRateTreatmentChartPoints.append(
                                ChartPoint(basalRate: previousScheduledBasalRate,
                                           date: endDate, basalRateScaler: basalRateScaler,
                                           minimumChartValueinMgdl: minimumChartValueInMgdl,
                                           formatter: data().chartPointDateFormatter)
                            )
                            
                        } else {
                            // the basal rate start times don't happen within the current range of the chart, so let's add a basal rate
                            // starting at the previous rate and then keep it there until the end date.
                            if let initialBasalRate = scheduledBasalRatesArray.filter({ $0.date < startDate}).last {
                                scheduledBasalRateTreatmentChartPoints.append(ChartPoint(basalRate: initialBasalRate.value, date: startDate, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                                
                                scheduledBasalRateTreatmentChartPoints.append(ChartPoint(basalRate: initialBasalRate.value, date: endDate, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                            }
                        }
                    }
                    
                    
                    // *********************************
                    // ***** Temp basal treatments *****
                    // *********************************
                    // this is used to know where to end the line from the previous rate when we start a new one for the current basal rate
                    var previousBasalRateTreatment: TreatmentEntry?
                    
                    // for each basalRateTreatment, create and append the relevant ChartPoints to basalRateTreatmentChartPoints
                    for basalRateTreatment in basalRateTreatments {
                        
                        // check the basal rates in for the previous days to calculate a starting scaling value. This is only done the first time
                        if basalRateMaximum == 0 {
                            let basalHistoryTreatmentEntries = treatmentEntryAccessor.getTreatments(fromDate: .now.addingTimeInterval(-60 * 60 * 24 * ConstantsGlucoseChart.basalScaleDaysForCalculation), toDate: .now, on: managedObjectContext).filter({ !$0.treatmentdeleted && $0.treatmentType == .Basal })
                            
                            // find the max basal rate on the chart so that we can scale everything to fit up until the minimum bg value (40mg/dL)
                            // we'll also use the max scheduled basal rate values if bigger
                            basalRateMaximum = max(basalHistoryTreatmentEntries.max(by: { $0.value < $1.value })?.value ?? 0, scheduledBasalRatesArray.max(by: { $0.value < $1.value })?.value ?? 0)
                            basalRateScaler = (ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl - minimumChartValueInMgdl) / basalRateMaximum
                            
                            trace("in getTreatmentChartPoints, initial calculated max basal = %{public}@, basal scaler = %{public}@", log: self.oslog, category: ConstantsLog.categoryGlucoseChartManager, type: .info, basalRateMaximum.description, basalRateScaler.description)
                        } else if basalRateTreatment.value > basalRateMaximum {
                            basalRateScaler = (ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl - minimumChartValueInMgdl) / basalRateMaximum
                        }
                        
                        if let previousBasalRateTreatment = previousBasalRateTreatment {
                            // check if the basal rate actually changes
                            // if not, then don't add the extra set of chart points to keep the array as small as possible
                            // must be checked further down also where the second point would be added
                            if basalRateTreatment.value != previousBasalRateTreatment.value {
                                // get the time when the previous temp basal should end (based upon its' start date and duration)
                                let previousBasalRateTreamentEndDate = previousBasalRateTreatment.date.addingTimeInterval(TimeInterval(previousBasalRateTreatment.valueSecondary * 60))
                                
                                // check if the previous temp basal finishes before the next temp basal
                                // most times this won't be the case as the AID system will usually enact a new temp basal on every cycle
                                if previousBasalRateTreamentEndDate < basalRateTreatment.date && nightscoutSyncManager?.profile.hasData() == true {
                                    checkAndAddScheduledBasalChartPointsIfNeeded(isFirstEntry: false, previousBasalRate: previousBasalRateTreatment.value, previousBasalRateTreamentEndDate: previousBasalRateTreamentEndDate, basalRateTreamentDate: basalRateTreatment.date)
                                } else {
                                    // in this case the new temp basal is enacted before the previous one runs out (this would be the normal condition)
                                    // we'll just extend the previous temp basal line until the new temp basal date
                                    basalRateTreatmentChartPoints.append(ChartPoint(basalRateTreatmentEntry: basalRateTreatment, previousBasalRateTreatmentEntry: previousBasalRateTreatment, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                                }
                            }
                        } else {
                            // if no previous basal treatment exists, then this is because it is the first/earliest basal rate treatment in the array
                            // first we need to pull it back to the chart startDate and use the previous value (before startDate)
                            // for the chart to make sense and also to prevent a gap in the line
                            
                            // let's try and get a previous basal rate (i.e. the first one we find closest to, and before the startDate). Let's go back 120 minutes to make sure we get the previous basal rate (AID-enacted temp basals never usually last for more than 120 minutes)
                            let previousTreatmentEntries = treatmentEntryAccessor.getTreatments(fromDate: startDate.addingTimeInterval(-60 * 120), toDate: startDate, on: managedObjectContext).filter({ !$0.treatmentdeleted && $0.treatmentType == .Basal })
                            
                            // so there is a previous basal rate treatment available
                            if let previousBasalRateTreatment: TreatmentEntry = previousTreatmentEntries.first {
                                // get the time when the previous temp basal should end (based upon its' start date and duration)
                                let previousBasalRateTreamentEndDate = previousBasalRateTreatment.date.addingTimeInterval(TimeInterval(previousBasalRateTreatment.valueSecondary * 60))
                                
                                // check if the previous temp basal finishes before the start of the first temp basal
                                // this would normally be the case for the first treatment in the list
                                if previousBasalRateTreamentEndDate < basalRateTreatment.date && nightscoutSyncManager?.profile.hasData() == true {
                                    checkAndAddScheduledBasalChartPointsIfNeeded(isFirstEntry: true, previousBasalRate: previousBasalRateTreatment.value, previousBasalRateTreamentEndDate: previousBasalRateTreamentEndDate, basalRateTreamentDate: basalRateTreatment.date)
                                } else {
                                    // use the previous basal rate to start the line at the correct value
                                    basalRateTreatmentChartPoints.append(ChartPoint(basalRate: previousBasalRateTreatment.value, date: startDate, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                                    
                                    // and continue this line until we get to the first treatment entry
                                    basalRateTreatmentChartPoints.append(ChartPoint(basalRate: previousBasalRateTreatment.value, date: basalRateTreatment.date, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                                }
                            } else {
                                // this will never usually happen except if the users scrolls all the way back to before the very first basal entry
                                basalRateTreatmentChartPoints.append(ChartPoint(basalRate: 0, date: basalRateTreatment.date, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                            }
                        }
                        
                        // check if the basal rate actually changed
                        // if not, then don't add the extra set of chart points to keep the array as small as possible
                        // the first check is further up where the first point would be added
                        if basalRateTreatment.value != previousBasalRateTreatment?.value {
                            // create a chartpoint with the current date and the current value. This is the start of the new temp basal rate
                            basalRateTreatmentChartPoints.append(ChartPoint(basalRateTreatmentEntry: basalRateTreatment, previousBasalRateTreatmentEntry: nil, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                        }
                        
                        // assign the current treatment to the variable so that we can reuse the value in the next loop
                        previousBasalRateTreatment = basalRateTreatment
                    }
                    
                    
                    // now that we're out of the loop, we've got the last temp basal rate in previousBasalRateTreatment
                    if let previousBasalRateTreatment = previousBasalRateTreatment {
                        // get the time when the previous temp basal should end (based upon its' start date and duration)
                        let previousBasalRateTreamentEndDate = previousBasalRateTreatment.date.addingTimeInterval(TimeInterval(previousBasalRateTreatment.valueSecondary * 60))
                        
                        // check if the previous temp basal finishes before the chart end date, or "now" - this is to detect the 24hr chart that is showing today.
                        // most times this won't be the case as the AID system will usually enact a new temp basal on every cycle
                        if previousBasalRateTreamentEndDate < min(endDate, .now) && nightscoutSyncManager?.profile.hasData() == true {
                            checkAndAddScheduledBasalChartPointsIfNeeded(isFirstEntry: false, previousBasalRate: previousBasalRateTreatment.value, previousBasalRateTreamentEndDate: previousBasalRateTreamentEndDate, basalRateTreamentDate: nil)
                        } else {
                            // if not, then just peg it to the end date
                            basalRateTreatmentChartPoints.append(ChartPoint(basalRateTreatmentEntry: previousBasalRateTreatment, date: min(endDate, .now), basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                        }
                        
                        // if this is a 24 hour static chart, then continue the chart at 0 U/hr until the end date
                        if endDate > .now {
                            basalRateTreatmentChartPoints.append(ChartPoint(basalRate: 0, date: .now, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                            
                            basalRateTreatmentChartPoints.append(ChartPoint(basalRate: 0, date: endDate, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                        }
                    }
                    
                    
                    // create the fill chart points. Start with an initial zero point...
                    basalRateFillTreatmentChartPoints.append(ChartPoint(basalRate: 0, date: startDate, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                    // ...add the basal chart points in the middle...
                    basalRateFillTreatmentChartPoints.append(contentsOf: basalRateTreatmentChartPoints)
                    // ...and end with a final zero point
                    basalRateFillTreatmentChartPoints.append(ChartPoint(basalRate: 0, date: endDate, basalRateScaler: basalRateScaler, minimumChartValueinMgdl: minimumChartValueInMgdl, formatter: data().chartPointDateFormatter))
                    
                }
            }
        }
        
        
        // return all treatment arrays based upon treatment type and size (as defined by the threshold values)
        return (smallBolusTreatmentChartPoints, mediumBolusTreatmentChartPoints, largeBolusTreatmentChartPoints, veryLargeBolusTreatmentChartPoints, smallCarbsTreatmentChartPoints, mediumCarbsTreatmentChartPoints, largeCarbsTreatmentChartPoints, veryLargeCarbsTreatmentChartPoints, bgCheckTreatmentChartPoints, scheduledBasalRateTreatmentChartPoints, basalRateTreatmentChartPoints, basalRateFillTreatmentChartPoints)
        
    }
    
    
    /// Calculate the Y axis value for multiple treatments.
    /// The calculation searches for the two closest bgReadings and interpolates
    /// the Y value between them.
    ///
    /// - parameters:
    ///     - treatments : a list of TreatmentEntries to calculate the Y axis.
    ///     - bgReadings : list of BgReadings to be searched and calculate the Y axis
    ///         based on the nearby readings by date.
    /// - returns: a list of Doubles, with the same amount of elements of treatments
    ///       so that each treatment maps to a Y axis (by index).
    /// IMPORTANT: Must be called inside managedObjectContext perfom block.
    private func calculateClosestYAxisValues(treatments: [TreatmentEntry], bgReadings: [BgReading]) -> [Double] {
        
        // 0 bgReadings is an invalid argument.
        guard bgReadings.count > 0 else {
            return [Double](repeating: 120.0, count: treatments.count)
        }
        
        var calculatedYValues: [Double] = []
        
        // For each treatment, find the two closest BgReading.
        // Then calculates the Y value based on them.
        for treatment in treatments {
            // Find the closest bgReading.
            let indexOfClosest = findIndexOfNearestBgReadingToDate(treatment.date, bgReadings: bgReadings)
            let closestBgReading = bgReadings[indexOfClosest]
            
            // Not always there will be a second closest one.
            // (If the closest reading is at the border of the graph, for exemple).
            var secondClosestBgReading: BgReading? = nil
            if treatment.date >= closestBgReading.timeStamp {
                // If the treatment is newer than the closest bgReading,
                // attempt to get the one after it, if exists.
                let nextIndex = indexOfClosest + 1
                if nextIndex < bgReadings.count {
                    secondClosestBgReading = bgReadings[nextIndex]
                }
            } else {
                // If the treatment is older than the closest bgReading,
                // attempt to get the one before it, if exists.
                let previousIndex = indexOfClosest - 1
                if previousIndex >= 0 {
                    secondClosestBgReading = bgReadings[previousIndex]
                }
            }
            
            // Calculate the Y value and append to the result list.
            let yValue = calculateYValue(treatmentDate: treatment.date, closestBgReading: closestBgReading, secondClosestBgReading: secondClosestBgReading)
            calculatedYValues.append(yValue)
        }
        
        return calculatedYValues
    }
    
    
    /// Calculate the Y axis value for a date between two bgReadings.
    /// Calculation is done using linear interpolation.
    ///
    /// - parameters:
    ///     - treatmentDate : the date to calculate the Y value of.
    ///     - closestBgReading : the closest BgReading to carbsDate.
    ///     - secondClosestBgReading : the second closest BgReading to treatmentDate,
    ///           if it exists, optional.
    /// - returns: the result of the interpolation.
    /// IMPORTANT: Must be called inside managedObjectContext perfom block.
    private func calculateYValue(treatmentDate: Date, closestBgReading: BgReading, secondClosestBgReading: BgReading?) -> Double {
        
        // If there is no second closest, return the closestBgReading calculatedValue.
        guard let secondClosestBgReading = secondClosestBgReading else {
            return closestBgReading.calculatedValue
        }
        
        // If there is a second closest, interpolate the Y value using a linear aproach.
        
        // First, figure out which of the bgReadings is the oldest.
        // It is safe to unwrap the first and last elements.
        let sortedReadings = [closestBgReading, secondClosestBgReading].sorted(by: { $0.timeStamp < $1.timeStamp })
        let olderBgReading = sortedReadings.first!
        let newerBgReading = sortedReadings.last!
        
        // Calculate the interpolation based on the time difference
        // Time difference from newerBgReading to olderBgReading
        let timeDifference: Double = newerBgReading.timeStamp.timeIntervalSince1970 - olderBgReading.timeStamp.timeIntervalSince1970
        // Time difference from treatmentDate to olderBgReading
        let timeOffset: Double = treatmentDate.timeIntervalSince1970 - olderBgReading.timeStamp.timeIntervalSince1970
        
        // timeOffsetFactor as a double from 0 to 1.
        let timeOffsetFactor: Double = timeOffset / timeDifference
        
        // Calculate the SGV difference between the readings.
        let yDifference: Double = newerBgReading.calculatedValue - olderBgReading.calculatedValue
        // Linear interpolation for Y
        let yValue = olderBgReading.calculatedValue + (yDifference * timeOffsetFactor)
        
        return yValue
    }
    
    
    /// Given a date and list of BgReadings, find the index of the bgReading closest to the date.
    ///
    /// - parameters:
    ///     - date : the date to find the index of the bgReading closest to.
    ///     - bgReadings : list of bgReading to find the closest.
    /// - returns: the index of the nearest bgReading.
    ///
    /// IMPORTANT: Must be called inside managedObjectContext perfom block.
    ///
    /// About performance and optimization:
    ///     The complexity of this search algorithm is O(n).
    ///     This may seen like a good place to optimize and implement a binary search, since it is O(log n).
    ///     However, profiling did not show any significant differece between the two possible implementations, since the amount of elements in bgReadings is relative small (50-200).
    ///
    private func findIndexOfNearestBgReadingToDate(_ date: Date, bgReadings: [BgReading]) -> Int {
        
        // Variables to keep track of the nearest
        var indexOfNearest = 0
        var nearestDiff: Double = Double.greatestFiniteMagnitude
        
        // Iterate over bgReadings and compare the date difference to see if it is less than the previous nearestDiff.
        for (i, bgReading) in bgReadings.enumerated() {
            let difference: Double = (bgReading.timeStamp.timeIntervalSince1970 - date.timeIntervalSince1970).magnitude
            
            if difference < nearestDiff {
                nearestDiff = difference
                indexOfNearest = i
            }
        }
        
        return indexOfNearest
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
    private func createTreatmentLabelsLayer(treatmentChartPoints: [ChartPoint], labelSeparation: Double, labelSeparationOffset: Double, xAxisLayer: ChartAxisLayer, yAxisLayer: ChartAxisLayer, treatmentType: TreatmentType, treatmentLabelFontSize: Double, showLabelBelow: Bool, y: Double, height: Double) -> ChartPointsViewsLayer<ChartPoint, UIView> {
        
        // to save typing
        let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        //        if the label is to be shown below, then
        let offsetIfMmol: Double = ConstantsGlucoseChart.treatmentLabelMmolOffset.mgDlToMmol(mgDl: isMgDl)
        
        // create the chart point array of the label positions based upon the treatment chart point array
        let labelChartPoints = treatmentChartPoints.map { chartPoint in
            if showLabelBelow {
                ChartPoint(x: chartPoint.x, y: chartPoint.y.copy(chartPoint.y.scalar - labelSeparation.mgDlToMmol(mgDl: isMgDl) - labelSeparationOffset.mgDlToMmol(mgDl: isMgDl) - (isMgDl ? 0 : offsetIfMmol)))
            } else {
                ChartPoint(x: chartPoint.x, y: chartPoint.y.copy(chartPoint.y.scalar + labelSeparation.mgDlToMmol(mgDl: isMgDl) + labelSeparationOffset.mgDlToMmol(mgDl: isMgDl) + (isMgDl ? 0 : offsetIfMmol)))
            }
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
        
        // We need to increase slightly the "window" that we are using to locate the Treatment. The ChartPoint class seems to slightly round the values which might result in not getting an exact match. ±1ms seems to work, but we'll leave it at ±50ms just to be sure.
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
        treatmentChartPoints = ([ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint](), [ChartPoint]())
        
        calibrationChartPoints = [ChartPoint]()
        
        smallBolusTreatmentChartPoints = [ChartPoint]()
        mediumBolusTreatmentChartPoints = [ChartPoint]()
        largeBolusTreatmentChartPoints = [ChartPoint]()
        veryLargeBolusTreatmentChartPoints = [ChartPoint]()
        
        smallCarbsTreatmentChartPoints = [ChartPoint]()
        mediumCarbsTreatmentChartPoints = [ChartPoint]()
        largeCarbsTreatmentChartPoints = [ChartPoint]()
        veryLargeCarbsTreatmentChartPoints = [ChartPoint]()
        
        bgCheckTreatmentChartPoints = [ChartPoint]()
        
        scheduledBasalRateTreatmentChartPoints = [ChartPoint]()
        
        basalRateTreatmentChartPoints = [ChartPoint]()
        basalRateFillTreatmentChartPoints = [ChartPoint]()
        
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
            chartGuideLinesLayerSettings = ChartGuideLinesLayerSettings(linesColor: ConstantsGlucoseChart.gridColorObjectives,  linesWidth: 0.5)
        }
        
        // intialize axisLabelTimeFormatter to use the user's locale and region settings
        if axisLabelTimeFormatter == nil {
            axisLabelTimeFormatter = DateFormatter()
            axisLabelTimeFormatter!.amSymbol = ConstantsUI.timeFormatAM
            axisLabelTimeFormatter!.pmSymbol = ConstantsUI.timeFormatPM
            axisLabelTimeFormatter!.setLocalizedDateFormatFromTemplate(ConstantsUI.timeFormatHoursOnly)
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
                return ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl.mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
            }
            
        }
        
    }
    
}
