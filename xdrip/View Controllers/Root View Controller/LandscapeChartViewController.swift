//
//  LandscapeChartViewController.swift
//  xdrip
//
//  Created by Paul Plant on 16/9/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import PieCharts
import UIKit

final class LandscapeChartViewController: UIViewController {
    @IBOutlet weak var landscapeChartOutlet: BloodGlucoseChartView!
    
    @IBOutlet weak var dateLabelOutlet: UILabel!
    
    @IBOutlet weak var showTreatmentsOnChartLabelOutlet: UILabel!
    @IBOutlet weak var showTreatmentsOnChartSwitch: UISwitch!
    @IBAction func showTreatmentsOnChartValueChanged(_ sender: UISwitch) {
        UserDefaults.standard.showTreatmentsOnLandscapeChart = sender.isOn
        updateView()
    }
    
    /// when the back button is pressed we'll subtract a day from the currently selected date and refresh the view
    @IBOutlet weak var backButtonOutlet: UIButton!
    @IBAction func backButtonPressed(_ sender: Any) {
        // subtract a day from the selected date
        selectedDate = selectedDate.addingTimeInterval(-24 * 60 * 60).toMidnight()
        updateView()
    }
    
    /// when the forward button is pressed we'll add a day from to currently selected date and refresh the view
    @IBOutlet weak var forwardButtonOutlet: UIButton!
    @IBAction func forwardButtonPressed(_ sender: Any) {
        // add a day to the selected date
        selectedDate = selectedDate.addingTimeInterval(24 * 60 * 60).toMidnight()
        updateView()
    }
    
    @IBOutlet weak var lowTitleLabelOutlet: UILabel!
    @IBOutlet weak var lowLabelOutlet: UILabel!
    @IBOutlet weak var lowStatisticLabelOutlet: UILabel!
    
    @IBOutlet weak var inRangeTitleLabelOutlet: UILabel!
    @IBOutlet weak var inRangeStatisticLabelOutlet: UILabel!
    
    @IBOutlet weak var highTitleLabelOutlet: UILabel!
    @IBOutlet weak var highLabelOutlet: UILabel!
    @IBOutlet weak var highStatisticLabelOutlet: UILabel!
    
    @IBOutlet weak var pieChartOutlet: PieChart!
    @IBOutlet weak var pieChartLabelOutlet: UILabel!
    
    @IBOutlet weak var averageTitleLabelOutlet: UILabel!
    @IBOutlet weak var averageStatisticLabelOutlet: UILabel!
    
    @IBOutlet weak var a1CTitleLabelOutlet: UILabel!
    @IBOutlet weak var a1CStatisticLabelOutlet: UILabel!
    
    @IBOutlet weak var cVTitleLabelOutlet: UILabel!
    @IBOutlet weak var cVStatisticLabelOutlet: UILabel!
    
    // MARK: private variables
    
    /// glucoseChartManager
    private var glucoseChartManager: GlucoseChartManager?
    
    @IBAction func glucoseChartManagerSwipe(_ sender: UISwipeGestureRecognizer) {
        switch sender.direction {
        case .left:
            if !Calendar.current.isDateInToday(selectedDate) {
                // add a day to the selected date
                selectedDate = selectedDate.addingTimeInterval(24 * 60 * 60).toMidnight()
                updateView()
            }
        case .right:
            // subtract a day from the selected date
            selectedDate = selectedDate.addingTimeInterval(-24 * 60 * 60).toMidnight()
            updateView()
        default:
            break
        }
    }
    
    /// action to show/hide the AID status windows if AID follow is enabled
    @IBAction func tapGestureRecognizerAction(_ sender: UITapGestureRecognizer) {
        // select today
        selectedDate = Date().toMidnight()
        updateView()
    }
    
    /// BgReadingsAccessor instance
    private var bgReadingsAccessor: BgReadingsAccessor?
    
    /// NightscoutSyncManager instance
    private var nightscoutSyncManager: NightscoutSyncManager?
    
    /// coreDataManager to be used throughout the project
    private var coreDataManager: CoreDataManager?
    
    /// statisticsManager needed to calculate the stats
    private var statisticsManager: StatisticsManager?
    
    /// date that will be used to show the 24 hour chart. Initialise it for today.
    private var selectedDate: Date = Date().toMidnight()
    
    /// store the first and last BgReading dates to make it easier to enable/disable the buttons
    private var firstBgReadingDate: Date = .init()
    
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        
        dateFormatter.setLocalizedDateFormatFromTemplate(ConstantsGlucoseChart.dateFormatLandscapeChart)
        
        return dateFormatter
        
    }()
    
    /// stored value to make it common through the view
    private let noDataColor = UIColor(resource: .colorTertiary)
    
    /// stored value to make it common through the view
    private let dataColor = UIColor(resource: .colorPrimary)
    
    /// persisted low limit value
    private var lowLimitForTIR = 0.0
    
    /// persisted high limit value
    private var highLimitForTIR = 0.0
    
    // MARK: overriden functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup Core Data Manager - setting up coreDataManager happens asynchronously
        // completion handler is called when finished. This gives the app time to already continue setup which is independent of coredata, like initializing the views
        coreDataManager = CoreDataManager(modelName: ConstantsCoreData.modelName, completion: {
            // if coreDataManager is nil then there's no reason to continue
            guard self.coreDataManager != nil else {
                return
            }
            
            self.updateView()
            
        })
        
        // setup nightscout sync manager
        nightscoutSyncManager = NightscoutSyncManager(coreDataManager: coreDataManager!, messageHandler: { (title: String, message: String) in
            let alert = UIAlertController(title: title, message: message, actionHandler: nil)
            self.present(alert, animated: true, completion: nil)
        })
        
        // initialize glucoseChartManager
        glucoseChartManager = GlucoseChartManager(coreDataManager: coreDataManager!, nightscoutSyncManager: nightscoutSyncManager!)
        
        // initialize statisticsManager
        statisticsManager = StatisticsManager(coreDataManager: coreDataManager!)
        
        // initialize chartGenerator in chartOutlet
        landscapeChartOutlet.chartGenerator = { [weak self] frame in
            return self?.glucoseChartManager?.glucoseChartWithFrame(frame)?.view
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // set the title labels to their correct localization
        lowTitleLabelOutlet.text = Texts_Common.lowStatistics
        inRangeTitleLabelOutlet.text = UserDefaults.standard.timeInRangeType.title
        highTitleLabelOutlet.text = Texts_Common.highStatistics
        averageTitleLabelOutlet.text = Texts_Common.averageStatistics
        a1CTitleLabelOutlet.text = Texts_Common.a1cStatistics
        cVTitleLabelOutlet.text = Texts_Common.cvStatistics
        
        // show a smaller outer radius for the pie chart view if an iPhone mini screen
        pieChartOutlet.outerRadius = UIScreen.main.nativeBounds.height == 2340 ? 30 : 40
        
        updateView()
    }
    
    // MARK: private helper functions
    
    /// this function should do the following:
    /// - show the currently selected date
    /// - update the chart points
    /// - update the statistics values
    /// - update the button status
    private func updateView() {
        // set the selected date outlet
        dateLabelOutlet.text = dateFormatter.string(from: selectedDate) + "  "
        
        showTreatmentsOnChartSwitch.isOn = UserDefaults.standard.showTreatmentsOnLandscapeChart
        
        // we need to define the start and end times of the day that has been selected
        let startOfDay = Calendar(identifier: .gregorian).startOfDay(for: selectedDate)
        
        // add a day and subtract one second to get one second before midnight
        let endOfDay = startOfDay.addingTimeInterval((24 * 60 * 60) - 1)
        
        // update the chart
        glucoseChartManager?.updateChartPoints(endDate: endOfDay, startDate: startOfDay, chartOutlet: landscapeChartOutlet, showTreaments: UserDefaults.standard.showTreatmentsOnLandscapeChart, completionHandler: nil)
        updateStatistics(startOfDay: startOfDay, endOfDay: endOfDay)
        updateButtons()
    }
    
    /// helper function to calculate the statistics and update the pie chart and label outlets
    private func updateStatistics(startOfDay: Date, endOfDay: Date) {
        // just to make things easier to read
        let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // remove all data models from the pie chart
        pieChartOutlet.models = []
        
        // statisticsManager will calculate the statistics in background thread and call the callback function in the main thread
        statisticsManager?.calculateStatistics(fromDate: startOfDay, toDate: endOfDay, callback: { statistics in
            
            // we've got values so let's configure the value to show them
            if statistics.lowStatisticValue.value != 0 || statistics.inRangeStatisticValue.value != 0 || statistics.highStatisticValue.value != 0 {
                // persist the limits - this avoids not having them when we return zero data
                self.lowLimitForTIR = statistics.lowLimitForTIR
                self.highLimitForTIR = statistics.highLimitForTIR
                
                // set the low/high "label" labels with the low/high user values that the user has chosen to use
                self.lowLabelOutlet.textColor = UIColor(resource: .colorSecondary)
                self.lowLabelOutlet.text = "(<" + (isMgDl ? Int(self.lowLimitForTIR).description : self.lowLimitForTIR.round(toDecimalPlaces: 1).description) + ")"
                
                self.highLabelOutlet.textColor = UIColor(resource: .colorSecondary)
                self.highLabelOutlet.text = "(>" + (isMgDl ? Int(self.highLimitForTIR).description : self.highLimitForTIR.round(toDecimalPlaces: 1).description) + ")"
                
                self.lowStatisticLabelOutlet.textColor = ConstantsStatistics.labelLowColor
                self.lowStatisticLabelOutlet.text = Int(statistics.lowStatisticValue.round(toDecimalPlaces: 0)).description + " %"
                
                self.inRangeStatisticLabelOutlet.textColor = ConstantsStatistics.labelInRangeColor
                self.inRangeStatisticLabelOutlet.text = Int(statistics.inRangeStatisticValue.round(toDecimalPlaces: 0)).description + " %"
                
                self.highStatisticLabelOutlet.textColor = ConstantsStatistics.labelHighColor
                self.highStatisticLabelOutlet.text = Int(statistics.highStatisticValue.round(toDecimalPlaces: 0)).description + " %"
                
                self.averageStatisticLabelOutlet.textColor = self.dataColor
                self.averageStatisticLabelOutlet.text = (isMgDl ? Int(statistics.averageStatisticValue.round(toDecimalPlaces: 0)).description : statistics.averageStatisticValue.round(toDecimalPlaces: 1).description) + (isMgDl ? " mg/dl" : " mmol/l")
                
                self.a1CStatisticLabelOutlet.textColor = self.dataColor
                if UserDefaults.standard.useIFCCA1C {
                    self.a1CStatisticLabelOutlet.text = Int(statistics.a1CStatisticValue.round(toDecimalPlaces: 0)).description + " mmol"
                } else {
                    self.a1CStatisticLabelOutlet.text = statistics.a1CStatisticValue.round(toDecimalPlaces: 1).description + " %"
                }
                
                self.cVStatisticLabelOutlet.textColor = self.dataColor
                self.cVStatisticLabelOutlet.text = Int(statistics.cVStatisticValue.round(toDecimalPlaces: 0)).description + " %"
                
                // if the user is 100% in range, show the easter egg and make them smile
                if statistics.inRangeStatisticValue == 0 {
                    self.pieChartOutlet.innerRadius = 0
                    self.pieChartOutlet.models = [
                        PieSliceModel(value: 1, color: self.noDataColor)
                    ]
                } else if statistics.inRangeStatisticValue < 100 {
                    // set the reference angle of the pie chart to ensure that the in range slice is centered
                    self.pieChartOutlet.referenceAngle = 90.0 - (1.8 * CGFloat(statistics.inRangeStatisticValue))
                    
                    self.pieChartOutlet.innerRadius = 0
                    
                    self.pieChartOutlet.models = [
                        PieSliceModel(value: Double(statistics.inRangeStatisticValue), color: ConstantsStatistics.pieChartInRangeSliceColor),
                        PieSliceModel(value: Double(statistics.lowStatisticValue), color: ConstantsStatistics.pieChartLowSliceColor),
                        PieSliceModel(value: Double(statistics.highStatisticValue), color: ConstantsStatistics.pieChartHighSliceColor)
                    ]
                    
                    //                self.pieChartLabelOutlet.text = "P"
                }
                /* else if ConstantsStatistics.showInRangeEasterEgg {
                 // if we want to show easter eggs check if one of the following two conditions is true:
                 //      - at least 16 hours (for example) have passed since midnight if the user is showing only Today and is still 100% in range
                 //      - if the user is showing >= 1 full days and they are still 100% in range
                 // the idea is to avoid that the easter egg appears after just a few minutes of being in range (at 00:15hrs for example) as this has no merit.
                 
                 // open up the inside of the chart so that we can fit the smiley face in
                 self.pieChartOutlet.innerRadius = 16
                 self.pieChartOutlet.models = [
                 PieSliceModel(value: 1, color: ConstantsStatistics.pieChartInRangeSliceColor)
                 ]
                 
                 self.pieChartLabelOutlet.font = UIFont.boldSystemFont(ofSize: 26)
                 
                 let components = Calendar.current.dateComponents([.month, .day], from: Date())
                 
                 if components.day != nil {
                 // let's add a Christmas holiday easter egg. Because... why not?
                 if components.month == 12 && (components.day! >= 23 && components.day! <= 31) {
                 self.pieChartLabelOutlet.text = "🎁"
                 } else {
                 // ok, so it's not Chistmas, but we can still be happy about a 100% TIR
                 self.pieChartLabelOutlet.text = "😎"
                 }
                 }
                 } */
                else {
                    // the easter egg isn't wanted so just show a green circle at 100%
                    self.pieChartOutlet.innerRadius = 0
                    self.pieChartOutlet.models = [
                        PieSliceModel(value: 1, color: ConstantsStatistics.pieChartInRangeSliceColor)
                    ]
                    
                    self.pieChartLabelOutlet.text = "A"
                }
                
            } else {
                // there are no values to show, so let's just gray everything out
                
                // set the low/high "label" labels with the low/high user values that the user has chosen to use
                self.lowLabelOutlet.textColor = self.noDataColor
                self.lowLabelOutlet.text = "(<" + (isMgDl ? Int(self.lowLimitForTIR).description : self.lowLimitForTIR.round(toDecimalPlaces: 1).description) + ")"
                
                self.highLabelOutlet.textColor = self.noDataColor
                self.highLabelOutlet.text = "(>" + (isMgDl ? Int(self.highLimitForTIR).description : self.highLimitForTIR.round(toDecimalPlaces: 1).description) + ")"
                
                self.lowStatisticLabelOutlet.textColor = ConstantsStatistics.labelLowColor
                self.lowStatisticLabelOutlet.text = "- %"
                
                self.inRangeStatisticLabelOutlet.textColor = ConstantsStatistics.labelInRangeColor
                self.inRangeStatisticLabelOutlet.text = "- %"
                
                self.highStatisticLabelOutlet.textColor = ConstantsStatistics.labelHighColor
                self.highStatisticLabelOutlet.text = "- %"
                
                self.averageStatisticLabelOutlet.textColor = self.noDataColor
                self.averageStatisticLabelOutlet.text = isMgDl ? "- mg/dl" : "- mmol/l"
                
                self.a1CStatisticLabelOutlet.textColor = self.noDataColor
                if UserDefaults.standard.useIFCCA1C {
                    self.a1CStatisticLabelOutlet.text = "- mmol"
                } else {
                    self.a1CStatisticLabelOutlet.text = "- %"
                }
                
                self.cVStatisticLabelOutlet.textColor = self.noDataColor
                self.cVStatisticLabelOutlet.text = "- %"
                
                self.pieChartOutlet.innerRadius = 0
                self.pieChartOutlet.models = [
                    PieSliceModel(value: 1, color: self.noDataColor)
                ]
            }
        })
    }
    
    /// This will disable the forward button if we're already at "today"
    /// Keep this as a function just in case we decide to add further validations at some point
    private func updateButtons() {
        forwardButtonOutlet.isEnabled = !Calendar.current.isDateInToday(selectedDate)
    }
}
