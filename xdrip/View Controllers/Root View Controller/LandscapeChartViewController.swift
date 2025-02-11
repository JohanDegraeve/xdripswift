//
//  LandscapeChartViewController.swift
//  xdrip
//
//  Created by Paul Plant on 16/9/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import UIKit

class LandscapeChartViewController: UIViewController {

    @IBOutlet weak var landscapeChartOutlet: BloodGlucoseChartView!
    
    @IBOutlet weak var inRangeTitleLabelOutlet: UILabel!
    @IBOutlet weak var inRangeLabelOutlet: UILabel!
    
    @IBOutlet weak var averageTitleLabelOutlet: UILabel!
    @IBOutlet weak var averageLabelOutlet: UILabel!
    
    @IBOutlet weak var cvTitleLabelOutlet: UILabel!
    @IBOutlet weak var cvLabelOutlet: UILabel!
    
    @IBOutlet weak var dateLabelOutlet: UILabel!
    
    @IBOutlet weak var backButtonOutlet: UIButton!
    
    @IBOutlet weak var forwardButtonOutlet: UIButton!
    
    /// when the back button is pressed we'll subtract a day from the currently selected date and refresh the view
    @IBAction func backButtonPressed(_ sender: Any) {
        
        // subtract a day from the selected date
        selectedDate = selectedDate.addingTimeInterval(-24 * 60 * 60).toMidnight()
        
        updateView()
        
    }
    
    /// when the forward button is pressed we'll add a day from to currently selected date and refresh the view
    @IBAction func forwardButtonPressed(_ sender: Any) {
        
        // add a day to the selected date
        selectedDate = selectedDate.addingTimeInterval(24 * 60 * 60).toMidnight()
        
        updateView()
        
    }
    
    
    // MARK: private variables
    
    /// glucoseChartManager
    private var glucoseChartManager: GlucoseChartManager?
    
    /// BgReadingsAccessor instance
    private var bgReadingsAccessor:BgReadingsAccessor?
    
    /// NightscoutSyncManager instance
    private var nightscoutSyncManager: NightscoutSyncManager?
    
    /// coreDataManager to be used throughout the project
    private var coreDataManager: CoreDataManager?
    
    /// statisticsManager needed to calculate the stats
    private var statisticsManager: StatisticsManager?
    
    /// date that will be used to show the 24 hour chart. Initialise it for today.
    private var selectedDate: Date = Date().toMidnight()
    
    /// store the first and last BgReading dates to make it easier to enable/disable the buttons
    private var firstBgReadingDate: Date = Date()
    
    private let dateFormatter: DateFormatter = {
        
        let dateFormatter = DateFormatter()

        dateFormatter.setLocalizedDateFormatFromTemplate(ConstantsGlucoseChart.dateFormatLandscapeChart)

        return dateFormatter
        
    }()
    
    
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
        nightscoutSyncManager = NightscoutSyncManager(coreDataManager: coreDataManager!, messageHandler: { (title:String, message:String) in
            
            let alert = UIAlertController(title: title, message: message, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        })
        
        // initialize glucoseChartManager
        glucoseChartManager = GlucoseChartManager(coreDataManager: coreDataManager!, nightscoutSyncManager: nightscoutSyncManager!)
        
        // initialize statisticsManager
        statisticsManager = StatisticsManager(coreDataManager: coreDataManager!)
        
        // initialize chartGenerator in chartOutlet
        self.landscapeChartOutlet.chartGenerator = { [weak self] (frame) in
            return self?.glucoseChartManager?.glucoseChartWithFrame(frame)?.view
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        // set the title labels to their correct localization
        self.inRangeTitleLabelOutlet.text = Texts_Common.inRangeStatistics
        self.averageTitleLabelOutlet.text = Texts_Common.averageStatistics
        self.cvTitleLabelOutlet.text = Texts_Common.cvStatistics
        
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
        
        // we need to define the start and end times of the day that has been selected
        let startOfDay = Calendar(identifier: .gregorian).startOfDay(for: selectedDate)
        
        // add a day and subtract one second to get one second before midnight
        let endOfDay = startOfDay.addingTimeInterval((24 * 60 * 60) - 1)
        
        // update the chart
        glucoseChartManager?.updateChartPoints(endDate: endOfDay, startDate: startOfDay, chartOutlet: landscapeChartOutlet, completionHandler: nil)
        
        updateStatistics(startOfDay: startOfDay, endOfDay: endOfDay)
        
        updateButtons()
        
    }

    
    /// helper function to calculate the statistics and update the pie chart and label outlets
    private func updateStatistics(startOfDay: Date, endOfDay: Date) {
        
        // just to make things easier to read
        let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // darken the text of the statistics
        inRangeLabelOutlet.textColor = UIColor.darkGray
        averageLabelOutlet.textColor = UIColor.darkGray
        cvLabelOutlet.textColor = UIColor.darkGray
        
        // statisticsManager will calculate the statistics in background thread and call the callback function in the main thread
        statisticsManager?.calculateStatistics(fromDate: startOfDay, toDate: endOfDay, callback: { statistics in
            
            // if there are no values returned then just leave a placeholder and darken the text
            if statistics.inRangeStatisticValue.value > 0 {
                
                self.inRangeLabelOutlet.text = Int(statistics.inRangeStatisticValue.round(toDecimalPlaces: 0)).description + "%"
                
                self.averageLabelOutlet.text = (isMgDl ? Int(statistics.averageStatisticValue.round(toDecimalPlaces: 0)).description : statistics.averageStatisticValue.round(toDecimalPlaces: 1).description) + " " + (isMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
            
                self.cvLabelOutlet.text = Int(statistics.cVStatisticValue.round(toDecimalPlaces: 0)).description + "%"
                
                self.inRangeLabelOutlet.textColor = UIColor.lightGray
                self.averageLabelOutlet.textColor = UIColor.lightGray
                self.cvLabelOutlet.textColor = UIColor.lightGray
                self.dateLabelOutlet.textColor = UIColor.lightGray
                
            } else {
                
                // no values have been returned for this date so let's just make it obvious to the user
                self.inRangeLabelOutlet.text = "--%"
                
                self.averageLabelOutlet.text = isMgDl ? "--- " + Texts_Common.mgdl : "-- " + Texts_Common.mmol
                self.cvLabelOutlet.text = "--%"
                
                self.inRangeLabelOutlet.textColor = UIColor.darkGray
                self.averageLabelOutlet.textColor = UIColor.darkGray
                self.cvLabelOutlet.textColor = UIColor.darkGray
                self.dateLabelOutlet.textColor = UIColor.red
                
            }
            
        })
    }
    
    /// This will disable the forward button if we're already at "today"
    /// Keep this as a function just in case we decide to add further validations at some point
    private func updateButtons() {
        
        forwardButtonOutlet.isEnabled = !Calendar.current.isDateInToday(selectedDate)
        
    }
    
    
}
