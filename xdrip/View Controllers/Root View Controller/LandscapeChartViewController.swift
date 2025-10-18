//
//  LandscapeChartViewController.swift
//  xdrip
//
//  Created by Paul Plant on 16/9/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import PieCharts
import SwiftCharts
import UIKit

final class LandscapeChartViewController: UIViewController {
    // MARK: - TIR Chart Data Structure
    
    /// structure to hold daily TIR statistics
    private struct DailyTIRData {
        let date: Date
        let lowPercentage: Double
        let inRangePercentage: Double
        let highPercentage: Double
        
        init(date: Date, lowPercentage: Double = 0, inRangePercentage: Double = 0, highPercentage: Double = 0) {
            self.date = date
            self.lowPercentage = lowPercentage
            self.inRangePercentage = inRangePercentage
            self.highPercentage = highPercentage
        }
    }
    
    /// shared helper struct for TIR chart layout so drawing and hit-testing stay in sync
    private struct TIRLayout {
        let topPadding: CGFloat
        let bottomPadding: CGFloat
        let leadingPadding: CGFloat
        let yAxisLabelWidth: CGFloat
        let yAxisLabelRightPadding: CGFloat
        let trailingPadding: CGFloat
        let barCornerRadius: CGFloat
        let percentLabelFontSize: CGFloat
        let dayLabelFontSize: CGFloat
        let yAxisLabelFontSize: CGFloat
        let barSpacing: CGFloat
        let chartWidth: CGFloat
        let chartHeight: CGFloat
        let barWidth: CGFloat
        let stride: CGFloat
    }
    
    // MARK: - Outlets and IBActions

    // header section
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
        if Calendar.current.isDate(selectedDate, inSameDayAs: tirWindowStartDate) {
            tirWindowStartDate = tirWindowStartDate.addingTimeInterval(-24 * 60 * 60)
            selectedDate = tirWindowStartDate
            // window changed so recalculate cache
            calculateDailyTIRData()
        } else {
            selectedDate = selectedDate.addingTimeInterval(-24 * 60 * 60).toMidnight()
        }
        updateView()
    }
    
    /// when the forward button is pressed we'll add a day from to currently selected date and refresh the view
    @IBOutlet weak var forwardButtonOutlet: UIButton!
    @IBAction func forwardButtonPressed(_ sender: Any) {
        // add a day to the selected date
        if !Calendar.current.isDateInToday(selectedDate) {
            if Calendar.current.isDate(selectedDate, inSameDayAs: tirWindowEndDate) {
                tirWindowStartDate = tirWindowStartDate.addingTimeInterval(24 * 60 * 60).toMidnight()
                selectedDate = selectedDate.addingTimeInterval(24 * 60 * 60).toMidnight()
                // window changed so recalculate cache
                calculateDailyTIRData()
            } else {
                selectedDate = selectedDate.addingTimeInterval(24 * 60 * 60).toMidnight()
            }
        }
        updateView()
    }
    
    // left section with statistics data
    @IBOutlet weak var highTitleLabelOutlet: UILabel!
    @IBOutlet weak var highLabelOutlet: UILabel!
    @IBOutlet weak var highStatisticLabelOutlet: UILabel!
    
    @IBOutlet weak var inRangeTitleLabelOutlet: UILabel!
    @IBOutlet weak var inRangeStatisticLabelOutlet: UILabel!
    
    @IBOutlet weak var lowTitleLabelOutlet: UILabel!
    @IBOutlet weak var lowLabelOutlet: UILabel!
    @IBOutlet weak var lowStatisticLabelOutlet: UILabel!
    
    @IBOutlet weak var pieChartOutlet: PieChart!
    
    @IBOutlet weak var averageTitleLabelOutlet: UILabel!
    @IBOutlet weak var averageStatisticLabelOutlet: UILabel!
    
    @IBOutlet weak var a1CTitleLabelOutlet: UILabel!
    @IBOutlet weak var a1CStatisticLabelOutlet: UILabel!
    
    @IBOutlet weak var cVTitleLabelOutlet: UILabel!
    @IBOutlet weak var cVStatisticLabelOutlet: UILabel!
        
    // right-upper section with TIR chart
    /// outlet for TIR chart
    @IBOutlet weak var tirChartContainerOutlet: UIView!
    
    /// tap gesture action to make the y-axis fixed/dynamic by double tapping
    @IBAction func tirChartTap(_ sender: UITapGestureRecognizer) {
        UserDefaults.standard.tirChartHasDynamicYAxis.toggle()
        updateView()
    }
    
    // right-lower section with 24hr glucose chart
    /// outlet for glucose chart
    @IBOutlet weak var glucoseChartOutlet: BloodGlucoseChartView!
    
    /// action to swipe left and right to change the selected date
    @IBAction func glucoseChartSwipe(_ sender: UISwipeGestureRecognizer) {
        switch sender.direction {
        case .left:
            if !Calendar.current.isDateInToday(selectedDate) {
                if Calendar.current.isDate(selectedDate, inSameDayAs: tirWindowEndDate) {
                    tirWindowStartDate = tirWindowStartDate.addingTimeInterval(24 * 60 * 60).toMidnight()
                    selectedDate = selectedDate.addingTimeInterval(24 * 60 * 60).toMidnight()
                    // window changed so recalculate cache
                    calculateDailyTIRData()
                } else {
                    selectedDate = selectedDate.addingTimeInterval(24 * 60 * 60).toMidnight()
                }
            }
            updateView()
        case .right:
            if Calendar.current.isDate(selectedDate, inSameDayAs: tirWindowStartDate) {
                tirWindowStartDate = tirWindowStartDate.addingTimeInterval(-24 * 60 * 60)
                selectedDate = tirWindowStartDate
                // window changed so recalculate cache
                calculateDailyTIRData()
            } else {
                selectedDate = selectedDate.addingTimeInterval(-24 * 60 * 60).toMidnight()
            }
            updateView()
        default:
            break
        }
    }
    
    /// tap gesture action to quickly change selected date back to today
    @IBAction func glucoseChartTap(_ sender: UITapGestureRecognizer) {
        // select today
        selectedDate = Date().toMidnight()
        tirWindowStartDate = selectedDate.addingTimeInterval(Double(-(ConstantsStatistics.numberOfDaysForTIRChartLandscapeView - 1)) * 24 * 60 * 60)
        calculateDailyTIRData()
        updateView()
    }
    
    // MARK: - private variables

    private var tirWindowStartDate: Date = .init()
    
    private var tirWindowEndDate: Date {
        return tirWindowStartDate.addingTimeInterval(Double(ConstantsStatistics.numberOfDaysForTIRChartLandscapeView * 24 * 60 * 60) - 1)
    }
    
    /// cache for daily TIR data to avoid repeated calculations
    private var dailyTIRCache: [DailyTIRData] = []
    
    /// reference to the TIR chart
    private var tirChart: Chart?
    
    /// glucoseChartManager
    private var glucoseChartManager: GlucoseChartManager?
    
    /// BgReadingsAccessor instance
    private var bgReadingsAccessor: BgReadingsAccessor?
    
    /// NightscoutSyncManager instance
    private var nightscoutSyncManager: NightscoutSyncManager?
    
    /// coreDataManager to be used throughout the project
    private var coreDataManager: CoreDataManager?
    
    /// statisticsManager needed to calculate the stats
    private var statisticsManager: StatisticsManager?
    
    /// date that will be used to show the 24 hour chart. Initialise it for today. Make a small haptic feedback if the value is changed.
    private var selectedDate: Date = Date().toMidnight() {
        didSet {
            if oldValue != selectedDate {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }
    
    /// store the first and last BgReading dates to make it easier to enable/disable the buttons
    private var firstBgReadingDate: Date = .init()
    
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        
        dateFormatter.setLocalizedDateFormatFromTemplate(ConstantsGlucoseChart.dateFormatLandscapeChart)
        
        return dateFormatter
        
    }()
    
    /// stored value to make it common through the view
    private let colorNoData = UIColor(resource: .colorTertiary)
    
    /// stored value to make it common through the view
    private let colorData = UIColor(resource: .colorPrimary)
    
    /// persisted low limit value
    private var lowLimitForTIR = 0.0
    
    /// persisted high limit value
    private var highLimitForTIR = 0.0
    
    // MARK: - overriden functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup Core Data Manager - setting up coreDataManager happens asynchronously
        // completion handler is called when finished. This gives the app time to already continue setup which is independent of coredata, like initializing the views
        coreDataManager = CoreDataManager(modelName: ConstantsCoreData.modelName, completion: {
            // if coreDataManager is nil then there's no reason to continue
            guard self.coreDataManager != nil else {
                return
            }
            
            // setup nightscout sync manager
            self.nightscoutSyncManager = NightscoutSyncManager(coreDataManager: self.coreDataManager!, messageHandler: { (title: String, message: String) in
                let alert = UIAlertController(title: title, message: message, actionHandler: nil)
                self.present(alert, animated: true, completion: nil)
            })
            
            // initialize glucoseChartManager
            self.glucoseChartManager = GlucoseChartManager(coreDataManager: self.coreDataManager!, nightscoutSyncManager: self.nightscoutSyncManager!)
            
            // initialize statisticsManager
            self.statisticsManager = StatisticsManager(coreDataManager: self.coreDataManager!)
            
            // initialize chartGenerator in chartOutlet
            self.glucoseChartOutlet.chartGenerator = { [weak self] frame in
                return self?.glucoseChartManager?.glucoseChartWithFrame(frame)?.view
            }
            
            self.selectedDate = Date().toMidnight()
            
            self.tirWindowStartDate = self.selectedDate.addingTimeInterval(Double(-(ConstantsStatistics.numberOfDaysForTIRChartLandscapeView - 1)) * 24 * 60 * 60)
            
            self.lowLimitForTIR = UserDefaults.standard.timeInRangeType.lowerLimit
            self.highLimitForTIR = UserDefaults.standard.timeInRangeType.higherLimit
            
            // Calculate daily TIR data once managers are initialized
            self.calculateDailyTIRData()
            
            self.updateTIRChart()

            // Add tap recognizer for tap-to-select on TIR bars
            let tirChartTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTIRChartBarTap(_:)))
            self.tirChartContainerOutlet.addGestureRecognizer(tirChartTapGesture)
            self.tirChartContainerOutlet.isUserInteractionEnabled = true
            
            // finally, now that everything is set up, let's update the whole view
            self.updateView()
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // set the title labels to their correct localization
        highTitleLabelOutlet.text = Texts_Common.highStatistics
        inRangeTitleLabelOutlet.text = UserDefaults.standard.timeInRangeType.title
        lowTitleLabelOutlet.text = Texts_Common.lowStatistics
        averageTitleLabelOutlet.text = Texts_Common.averageStatistics
        a1CTitleLabelOutlet.text = Texts_Common.a1cStatistics
        cVTitleLabelOutlet.text = Texts_Common.cvStatistics
        showTreatmentsOnChartLabelOutlet.text = Texts_SettingsView.settingsviews_showTreatments
        
        // show a smaller outer radius for the pie chart view if an iPhone mini screen
        pieChartOutlet.outerRadius = UIScreen.main.nativeBounds.height == 2340 ? 30 : 40
                
        showTreatmentsOnChartSwitch.isOn = UserDefaults.standard.showTreatmentsOnLandscapeChart
    }
        
    // MARK: - private functions
    
    /// Updates the view with latest data
    private func updateView() {
        // update the date outlet
        dateLabelOutlet.text = dateFormatter.string(from: selectedDate)
        
        // set the start of the day from the selected date
        let startOfDay = selectedDate
        
        // add a day and subtract one second to get one second before midnight
        let endOfDay = startOfDay.addingTimeInterval((24 * 60 * 60) - 1)
        
        // update the main glucose chart
        glucoseChartManager?.updateChartPoints(endDate: endOfDay, startDate: startOfDay, chartOutlet: glucoseChartOutlet, showTreaments: UserDefaults.standard.showTreatmentsOnLandscapeChart, completionHandler: nil)
        
        updateTIRChart()
        
        updateStatistics(startOfDay: startOfDay, endOfDay: endOfDay)
        
        // enable the forward button if the selected date is not today
        forwardButtonOutlet.isEnabled = !Calendar.current.isDateInToday(selectedDate)
    }
    
    /// helper function to calculate the statistics and update the pie chart and label outlets
    private func updateStatistics(startOfDay: Date, endOfDay: Date) {
        // just to make things easier to read
        let isMgDl: Bool = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        // remove all data models from the pie chart
        pieChartOutlet.models = []
        
        // statisticsManager will calculate the statistics in background thread and call the callback function in the main thread
        statisticsManager?.calculateStatistics(fromDate: startOfDay, toDate: endOfDay, callback: { statistics in
            
            // set the low and high limit labels - this is common to whether we have valid statistics to show or not
            self.lowLabelOutlet.text = "(<" + (isMgDl ? Int(self.lowLimitForTIR).description : self.lowLimitForTIR.round(toDecimalPlaces: 1).description) + ")"
            self.highLabelOutlet.text = "(>" + (isMgDl ? Int(self.highLimitForTIR).description : self.highLimitForTIR.round(toDecimalPlaces: 1).description) + ")"
            
            // we've got values so let's configure the value to show them
            if statistics.lowStatisticValue.value != 0 || statistics.inRangeStatisticValue.value != 0 || statistics.highStatisticValue.value != 0 {
                self.lowLabelOutlet.textColor = UIColor(resource: .colorSecondary)
                self.highLabelOutlet.textColor = UIColor(resource: .colorSecondary)
                
                self.lowStatisticLabelOutlet.textColor = ConstantsStatistics.labelLowColor
                self.lowStatisticLabelOutlet.text = Int(statistics.lowStatisticValue.round(toDecimalPlaces: 0)).description + " %"
                
                self.inRangeStatisticLabelOutlet.textColor = ConstantsStatistics.labelInRangeColor
                self.inRangeStatisticLabelOutlet.text = Int(statistics.inRangeStatisticValue.round(toDecimalPlaces: 0)).description + " %"
                
                self.highStatisticLabelOutlet.textColor = ConstantsStatistics.labelHighColor
                self.highStatisticLabelOutlet.text = Int(statistics.highStatisticValue.round(toDecimalPlaces: 0)).description + " %"
                
                self.averageStatisticLabelOutlet.textColor = self.colorData
                self.averageStatisticLabelOutlet.text = (isMgDl ? Int(statistics.averageStatisticValue.round(toDecimalPlaces: 0)).description : statistics.averageStatisticValue.round(toDecimalPlaces: 1).description) + (isMgDl ? " mg/dl" : " mmol/l")
                
                self.a1CStatisticLabelOutlet.textColor = self.colorData
                if UserDefaults.standard.useIFCCA1C {
                    self.a1CStatisticLabelOutlet.text = Int(statistics.a1CStatisticValue.round(toDecimalPlaces: 0)).description + " mmol"
                } else {
                    self.a1CStatisticLabelOutlet.text = statistics.a1CStatisticValue.round(toDecimalPlaces: 1).description + " %"
                }
                
                self.cVStatisticLabelOutlet.textColor = self.colorData
                self.cVStatisticLabelOutlet.text = Int(statistics.cVStatisticValue.round(toDecimalPlaces: 0)).description + " %"
                
                // set the reference angle of the pie chart to ensure that the in range slice is centered
                self.pieChartOutlet.referenceAngle = 90.0 - (1.8 * CGFloat(statistics.inRangeStatisticValue))
                self.pieChartOutlet.innerRadius = 0
                self.pieChartOutlet.models = [
                    PieSliceModel(value: Double(statistics.inRangeStatisticValue), color: ConstantsStatistics.pieChartInRangeSliceColor),
                    PieSliceModel(value: Double(statistics.lowStatisticValue), color: ConstantsStatistics.pieChartLowSliceColor),
                    PieSliceModel(value: Double(statistics.highStatisticValue), color: ConstantsStatistics.pieChartHighSliceColor)
                ]
            } else {
                // there are no values to show, so let's just gray everything out
                self.lowLabelOutlet.textColor = self.colorNoData
                self.highLabelOutlet.textColor = self.colorNoData
                
                self.lowStatisticLabelOutlet.textColor = ConstantsStatistics.labelLowColor
                self.lowStatisticLabelOutlet.text = "- %"
                
                self.inRangeStatisticLabelOutlet.textColor = ConstantsStatistics.labelInRangeColor
                self.inRangeStatisticLabelOutlet.text = "- %"
                
                self.highStatisticLabelOutlet.textColor = ConstantsStatistics.labelHighColor
                self.highStatisticLabelOutlet.text = "- %"
                
                self.averageStatisticLabelOutlet.textColor = self.colorNoData
                self.averageStatisticLabelOutlet.text = isMgDl ? "- mg/dl" : "- mmol/l"
                
                self.a1CStatisticLabelOutlet.textColor = self.colorNoData
                if UserDefaults.standard.useIFCCA1C {
                    self.a1CStatisticLabelOutlet.text = "- mmol"
                } else {
                    self.a1CStatisticLabelOutlet.text = "- %"
                }
                
                self.cVStatisticLabelOutlet.textColor = self.colorNoData
                self.cVStatisticLabelOutlet.text = "- %"
                
                self.pieChartOutlet.innerRadius = 0
                self.pieChartOutlet.models = [
                    PieSliceModel(value: 1, color: self.colorNoData)
                ]
            }
        })
    }
    
    // MARK: - helper functions
    
    // return a shortened, locale-friendly month name
    private func shortMonthName(for monthNumber: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current // ensures localization, e.g. “sept.” in French, “sept.” in Catalan
        dateFormatter.setLocalizedDateFormatFromTemplate("MMM")
        
        // Construct a date with the given month number
        var components = DateComponents()
        components.month = monthNumber
        components.day = 1
        components.year = 2000 // arbitrary non-leap year
        
        if let date = Calendar.current.date(from: components) {
            return dateFormatter.string(from: date).capitalized
        } else {
            return ""
        }
    }

    // MARK: - TIR chart functions
    
    /// Updates the TIR column chart with cached daily data
    private func updateTIRChart() {
        // Clear existing chart views
        tirChartContainerOutlet.subviews.forEach { $0.removeFromSuperview() }
        
        // Guard against empty cache
        guard !dailyTIRCache.isEmpty else { return }
        
        let containerFrame = tirChartContainerOutlet.bounds
        let layout = makeTIRLayout(containerBounds: containerFrame, barCount: dailyTIRCache.count)
        let topPadding = layout.topPadding, leadingPadding = layout.leadingPadding
        let yAxisLabelWidth = layout.yAxisLabelWidth, yAxisLabelRightPadding = layout.yAxisLabelRightPadding
        let barCornerRadius = layout.barCornerRadius, percentLabelFontSize = layout.percentLabelFontSize, dayLabelFontSize = layout.dayLabelFontSize, yAxisLabelFontSize = layout.yAxisLabelFontSize
        let barSpacing = layout.barSpacing
        let chartHeight = layout.chartHeight
        let chartWidth = layout.chartWidth
        let barWidth = layout.barWidth
        
        // Calculate y-axis range
        let tirValues = dailyTIRCache.map { $0.inRangePercentage }.filter { $0 > 0 }
        let tirValuesMin = min(ConstantsStatistics.tirChartYAxisMinimumAxisValue, tirValues.min() ?? 0)
        let yAxisMin = UserDefaults.standard.tirChartHasDynamicYAxis ? max(0.0, tirValuesMin - ConstantsStatistics.tirChartYAxisMinimumOffset) : 0
        let yAxisMax: Double = 100
        let yRange = yAxisMax - yAxisMin

        // Draw horizontal reference lines at 0%, 25%, 50%, 75%, 100% - pixel aligned and extended under y-axis labels
        let referencePercents: [Double] = [0, 25, 50, 75, 100]
        let screenScale = UIScreen.main.scale
        let lineHeight = 1.0 / screenScale
        // Make gridlines extend slightly under the y-axis labels, but not the full label width
        let gridlineRightExtension: CGFloat = yAxisLabelRightPadding + yAxisLabelWidth * 0.05
        for percent in referencePercents {
            guard percent >= yAxisMin else { continue }
            let clampedPercent = min(percent, yAxisMax)
            let normalized = (clampedPercent - yAxisMin) / yRange
            let rawY = topPadding + chartHeight - CGFloat(normalized) * chartHeight
            let alignedY = floor(rawY * screenScale) / screenScale
            // Extend lines under the y-axis label lane for easier visual matching
            let extendedWidth = chartWidth + gridlineRightExtension
            let lineView = UIView(frame: CGRect(x: leadingPadding, y: alignedY, width: extendedWidth, height: lineHeight))
            lineView.backgroundColor = UIColor(resource: .colorSecondary).withAlphaComponent(0.40)
            tirChartContainerOutlet.addSubview(lineView)
        }

        // Draw y-axis labels on the right next to the gridlines, pixel-aligned and centered to gridline
        for percent in referencePercents {
            guard percent >= yAxisMin else { continue }
            let clampedPercent = min(percent, yAxisMax)
            let normalized = (clampedPercent - yAxisMin) / yRange
            let rawY = topPadding + chartHeight - CGFloat(normalized) * chartHeight
            let alignedY = floor(rawY * screenScale) / screenScale
            let label = UILabel()
            label.text = "\(Int(clampedPercent))%"
            label.font = UIFont.systemFont(ofSize: yAxisLabelFontSize, weight: .regular)
            label.textColor = UIColor(resource: .colorSecondary).withAlphaComponent(0.85)
            label.textAlignment = .right
            label.numberOfLines = 1
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            let labelHeight = ceil(label.font.lineHeight)
            let labelX = containerFrame.width - yAxisLabelWidth - yAxisLabelRightPadding
            // Center vertically on the gridline, pixel-aligned
            label.frame = CGRect(x: labelX, y: alignedY - labelHeight / 2, width: yAxisLabelWidth, height: labelHeight)
            tirChartContainerOutlet.addSubview(label)
        }
        
        // used to persist the previous month number during the for loop
        // used to display the abbreviated month name on the first bar and on the 1st of each new month
        // set it to 0 so that the first date will always trigger a "new month" condition
        var previousMonth = 0
        
        // Draw each bar
        for (index, tirData) in dailyTIRCache.enumerated() {
            let xPosition = leadingPadding + (CGFloat(index) * (barWidth + barSpacing))
            
            // Calculate bar height
            let tirValue = tirData.inRangePercentage
            let barHeight: CGFloat
            if tirValue > 0 {
                let normalizedValue = (tirValue - yAxisMin) / yRange
                barHeight = CGFloat(normalizedValue) * chartHeight
            } else {
                barHeight = 0 // No bar for empty data
            }
            
            let barY = topPadding + chartHeight - barHeight
            
            // Check if this is the selected date
            let isSelectedDate = Calendar.current.isDate(tirData.date, inSameDayAs: selectedDate)
            
            // Create bar view (only if there's data)
            if barHeight > 0 {
                let barView = UIView(frame: CGRect(x: xPosition, y: barY, width: barWidth, height: barHeight))
                barView.backgroundColor = isSelectedDate ? ConstantsStatistics.pieChartInRangeSliceColor : ConstantsStatistics.pieChartInRangeSliceColorDarkened
                barView.layer.cornerRadius = barCornerRadius
                
                tirChartContainerOutlet.addSubview(barView)
            }
            
            // Add percentage label on top
            let percentLabel = UILabel()
            percentLabel.text = tirValue > 0 ? "\(Int(tirValue.rounded()))%" : "-"
            percentLabel.font = UIFont.systemFont(ofSize: percentLabelFontSize + (isSelectedDate ? 1 : 0), weight: isSelectedDate ? .bold : .regular)
            percentLabel.textColor = isSelectedDate ? UIColor(resource: .colorPrimary) : (tirValue > 0 ? UIColor(resource: .colorSecondary) : UIColor(resource: .colorQuaternary))
            percentLabel.textAlignment = .center
            percentLabel.numberOfLines = 1
            percentLabel.adjustsFontSizeToFitWidth = true
            percentLabel.minimumScaleFactor = 0.8
            percentLabel.lineBreakMode = .byClipping
            percentLabel.sizeToFit()
            percentLabel.frame = CGRect(x: xPosition, y: topPadding - 18, width: barWidth, height: 15)
            
            tirChartContainerOutlet.addSubview(percentLabel)
            
            // Add day number label at bottom
            let calendar = Calendar.current
            let day = calendar.component(.day, from: tirData.date)
            let month = calendar.component(.month, from: tirData.date)
            
            let dayLabel = UILabel()
            dayLabel.text = month != previousMonth ? "\(shortMonthName(for: month))" : "\(day)"
            dayLabel.font = UIFont.systemFont(ofSize: dayLabelFontSize + (isSelectedDate ? 4 : 0), weight: isSelectedDate ? .heavy : .regular)
            dayLabel.textColor = isSelectedDate ? UIColor(resource: .colorPrimary) : (tirValue > 0 ? UIColor(resource: .colorSecondary) : UIColor(resource: .colorQuaternary))
            dayLabel.textAlignment = .center
            dayLabel.numberOfLines = 1
            dayLabel.adjustsFontSizeToFitWidth = true
            dayLabel.minimumScaleFactor = 0.7
            dayLabel.lineBreakMode = .byClipping
            dayLabel.sizeToFit()
            dayLabel.frame = CGRect(x: xPosition, y: topPadding + chartHeight + 5, width: barWidth, height: 15)
            
            tirChartContainerOutlet.addSubview(dayLabel)
            previousMonth = month
        }
    }
    
    /// Calculates TIR statistics for the last X days and caches the results
    /// This is called once on viewDidLoad to populate the cache
    private func calculateDailyTIRData() {
        guard let statisticsManager = statisticsManager else {
            return
        }
        
        dailyTIRCache.removeAll()
        
        let startDayForWindow = tirWindowStartDate
        let endOfWindow = startDayForWindow.addingTimeInterval(Double(ConstantsStatistics.numberOfDaysForTIRChartLandscapeView * 24 * 60 * 60) - 1)
        
        statisticsManager.calculateDailyTIR(fromDate: startDayForWindow, toDate: endOfWindow) { [weak self] statisticsByDay in
            guard let self = self else { return }
            
            // Build ordered results (oldest to newest), guaranteeing an entry per day
            var orderedResults: [DailyTIRData] = []
            for dayIndex in 0 ..< ConstantsStatistics.numberOfDaysForTIRChartLandscapeView {
                let dayDate = startDayForWindow.addingTimeInterval(Double(dayIndex) * 24 * 60 * 60)
                let dayKey = Calendar.current.startOfDay(for: dayDate)
                let statistics = statisticsByDay[dayKey] ?? StatisticsManager.Statistics(lowStatisticValue: 0, highStatisticValue: 0, inRangeStatisticValue: 0, averageStatisticValue: 0, a1CStatisticValue: 0, cVStatisticValue: 0, lowLimitForTIR: UserDefaults.standard.timeInRangeType.lowerLimit, highLimitForTIR: UserDefaults.standard.timeInRangeType.higherLimit, numberOfDaysUsed: 0)
                let tirData = DailyTIRData(date: dayKey, lowPercentage: statistics.lowStatisticValue, inRangePercentage: statistics.inRangeStatisticValue, highPercentage: statistics.highStatisticValue)
                orderedResults.append(tirData)
            }
            
            self.dailyTIRCache = orderedResults
            self.updateTIRChart()
        }
    }
    
    private func makeTIRLayout(containerBounds: CGRect, barCount: Int) -> TIRLayout {
        let topPadding: CGFloat = 24
        let bottomPadding: CGFloat = 24
        let leadingPadding: CGFloat = 10
        let yAxisLabelWidth: CGFloat = 28
        let yAxisLabelRightPadding: CGFloat = 8
        let trailingPadding: CGFloat = 14 + yAxisLabelWidth + yAxisLabelRightPadding
        let barCornerRadius: CGFloat = 3
        let percentLabelFontSize: CGFloat = 10
        let dayLabelFontSize: CGFloat = 12
        let yAxisLabelFontSize: CGFloat = 10
        let barSpacing: CGFloat = 6
        let chartHeight = containerBounds.height - topPadding - bottomPadding
        let chartWidth = containerBounds.width - (leadingPadding + trailingPadding)
        let count = max(1, barCount)
        let totalSpacing = barSpacing * (CGFloat(count) - 1)
        let barWidth = (chartWidth - totalSpacing) / CGFloat(count)
        let stride = barWidth + barSpacing
        return TIRLayout(topPadding: topPadding, bottomPadding: bottomPadding, leadingPadding: leadingPadding, yAxisLabelWidth: yAxisLabelWidth, yAxisLabelRightPadding: yAxisLabelRightPadding, trailingPadding: trailingPadding, barCornerRadius: barCornerRadius, percentLabelFontSize: percentLabelFontSize, dayLabelFontSize: dayLabelFontSize, yAxisLabelFontSize: yAxisLabelFontSize, barSpacing: barSpacing, chartWidth: chartWidth, chartHeight: chartHeight, barWidth: barWidth, stride: stride)
    }
    
    // handles taps on the TIR chart bars to select a date
    @objc private func handleTIRChartBarTap(_ gesture: UITapGestureRecognizer) {
        guard !dailyTIRCache.isEmpty else { return }
        let location = gesture.location(in: tirChartContainerOutlet)

        let containerFrame = tirChartContainerOutlet.bounds
        let layout = makeTIRLayout(containerBounds: containerFrame, barCount: dailyTIRCache.count)

        // map x location to bar index using the same stride and bounds as drawing
        let relativeX = location.x - layout.leadingPadding
        guard relativeX >= 0, relativeX <= layout.chartWidth else { return }
        let stride = layout.stride
        let barWidth = layout.barWidth
        let barSpacing = layout.barSpacing
        let barCount = CGFloat(dailyTIRCache.count)
        var index = Int(floor(relativeX / stride))
        index = max(0, min(Int(barCount - 1), index))

        // verify tap is within the bar's horizontal bounds (avoid selecting gaps)
        let barXStart = CGFloat(index) * stride
        let insideBar = relativeX >= barXStart && relativeX <= (barXStart + barWidth)
        if !insideBar {
            // if tapped in the spacing then snap to the nearest bar only if within half spacing; else ignore
            let leftEdgeDistance = abs(relativeX - barXStart)
            let rightEdgeDistance = abs(relativeX - (barXStart + barWidth))
            if min(leftEdgeDistance, rightEdgeDistance) > (barSpacing / 2) { return }
        }

        // select the tapped bar/day's date and refresh
        let tappedDate = dailyTIRCache[index].date
        if !Calendar.current.isDate(tappedDate, inSameDayAs: selectedDate) {
            selectedDate = tappedDate
            updateView()
        }
    }
}
