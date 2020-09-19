import Foundation
import NotificationCenter
import os

class TodayViewController: UIViewController, NCWidgetProviding {
    
    // MARK: - private properties
    
    /// xDripClient
    private var xDripClient: XDripClient = XDripClient()
    
    // MARK: - overriden functions
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
 
    }

    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        debuglogging("in widgetPerformUpdate")
        
        let lastReading = xDripClient.fetchLast(2, callback:  { (error, glucoseArray) in
            
            if error != nil {
                return
            }
            
            guard let glucoseArray = glucoseArray, glucoseArray.count > 0 else {
                return
            }
            
            for glucose in glucoseArray {
                
                debuglogging("glucose timestamp = " + glucose.timestamp.description(with: .current))
                debuglogging("glucose value = " + glucose.glucose.description)
                
            }
            
        })
        

        
        completionHandler(NCUpdateResult.newData)
        
    }
    
    /// - updates the labels
    private func updateLabels(latestReadings: [Glucose]) {
        
        // set minutesLabelOutlet.textColor to white, might still be red due to panning back in time
        self.minutesLabelOutlet.textColor = UIColor.white
        
        // if there's no readings, then give empty fields
        guard latestReadings.count > 0 else {
            valueLabelOutlet.text = "---"
            valueLabelOutlet.textColor = UIColor.darkGray
            minutesLabelOutlet.text = ""
            diffLabelOutlet.text = ""
            return
        }
        
        // assign last reading
        let lastReading = latestReadings[0]
        // assign last but one reading
        let lastButOneReading = latestReadings.count > 1 ? latestReadings[1]:nil
        
        // start creating text for valueLabelOutlet, first the calculated value
        var calculatedValueAsString = lastReading.unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        
        // if latestReading is older than 11 minutes, then it should be strikethrough
        if lastReading.timeStamp < Date(timeIntervalSinceNow: -60 * 11) {
            
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: calculatedValueAsString)
            attributeString.addAttribute(.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
        } else {
            
            if !lastReading.hideSlope {
                calculatedValueAsString = calculatedValueAsString + " " + lastReading.slopeArrow()
            }
            
            // no strikethrough needed, but attributedText may still be set to strikethrough from previous period during which there was no recent reading.
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: calculatedValueAsString)
            attributeString.addAttribute(.strikethroughStyle, value: 0, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
        }
        
        // if data is stale (over 11 minutes old), show it as gray colour to indicate that it isn't current
        // if not, then set color, depending on value lower than low mark or higher than high mark
        // set both HIGH and LOW BG values to red as previous yellow for hig is now not so obvious due to in-range colour of green.
        if lastReading.timeStamp < Date(timeIntervalSinceNow: -60 * 11) {
            valueLabelOutlet.textColor = UIColor.lightGray
        } else if lastReading.calculatedValue >= UserDefaults.standard.urgentHighMarkValueInUserChosenUnit.mmolToMgdl(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) || lastReading.calculatedValue <= UserDefaults.standard.urgentLowMarkValueInUserChosenUnit.mmolToMgdl(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) {
            // BG is higher than urgentHigh or lower than urgentLow objectives
            valueLabelOutlet.textColor = UIColor.red
        } else if lastReading.calculatedValue >= UserDefaults.standard.highMarkValueInUserChosenUnit.mmolToMgdl(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) || lastReading.calculatedValue <= UserDefaults.standard.lowMarkValueInUserChosenUnit.mmolToMgdl(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) {
            // BG is between urgentHigh/high and low/urgentLow objectives
            valueLabelOutlet.textColor = UIColor.yellow
        } else {
            // BG is between high and low objectives so considered "in range"
            valueLabelOutlet.textColor = UIColor.green
        }
        
        // get minutes ago and create text for minutes ago label
        let minutesAgo = -Int(lastReading.timeStamp.timeIntervalSinceNow) / 60
        let minutesAgoText = minutesAgo.description + " " + (minutesAgo == 1 ? Texts_Common.minute:Texts_Common.minutes) + " " + Texts_HomeView.ago
        
        minutesLabelOutlet.text = minutesAgoText
        
        // create delta text
        diffLabelOutlet.text = lastReading.unitizedDeltaString(previousBgReading: lastButOneReading, showUnit: true, highGranularity: true, mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        
        // update the chart up to now
        updateChartWithResetEndDate()
        
    }

    /// creates string with bg value in correct unit or "HIGH" or "LOW", or other like ???
    private func unitizedString(calculatedValue: Double, unitIsMgDl:Bool) -> String {
        var returnValue:String
        if (calculatedValue >= 400) {
            returnValue = Texts_Common.HIGH
        } else if (calculatedValue >= 40) {
            returnValue = calculatedValue.mgdlToMmolAndToString(mgdl: unitIsMgDl)
        } else if (calculatedValue > 12) {
            returnValue = Texts_Common.LOW
        } else {
            switch(calculatedValue) {
            case 0:
                returnValue = "??0"
                break
            case 1:
                returnValue = "?SN"
                break
            case 2:
                returnValue = "??2"
                break
            case 3:
                returnValue = "?NA"
                break
            case 5:
                returnValue = "?NC"
                break
            case 6:
                returnValue = "?CD"
                break
            case 9:
                returnValue = "?AD"
                break
            case 12:
                returnValue = "?RF"
                break
            default:
                returnValue = "???"
                break
            }
        }
        return returnValue
    }
    

}
