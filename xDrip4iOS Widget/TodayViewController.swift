import Foundation
import NotificationCenter
import os

class TodayViewController: UIViewController, NCWidgetProviding {
    
    // MARK: - Properties - Outlets and Actions
    
    
    @IBOutlet weak var minutesLabelOutlet: UILabel!
    @IBOutlet weak var minutesAgoLabelOutlet: UILabel!
    
    @IBOutlet weak var diffLabelOutlet: UILabel!
    @IBOutlet weak var diffLabelUnitOutlet: UILabel!
    
    @IBOutlet weak var valueLabelOutlet: UILabel!
    
    
    
    // MARK: - private properties
    
    /// xDripClient
    private var xDripClient: XDripClient = XDripClient()
    
    // MARK: - overriden functions
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        setupView()
        
    }

    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        xDripClient.fetchLast(2, callback:  { (error, glucoseArray) in
            
            if error != nil {
                return
            }
            
            guard let glucoseArray = glucoseArray, glucoseArray.count > 0 else {
                return
            }
            
            self.updateLabels(latestReadings: glucoseArray)
            
        })
        
        completionHandler(NCUpdateResult.newData)
        
    }
    
    // MARK: - private functions
    
    /// setup colors and so
    private func setupView() {
        
        // set background color to black
        self.view.backgroundColor = UIColor.black
        
        // set minutesLabelOutlet.textColor to white
        self.minutesLabelOutlet.textColor = UIColor.white
        
        // set diffLabelOutlet.textColor to white
        self.diffLabelOutlet.textColor = UIColor.white
        
        self.minutesAgoLabelOutlet.textColor = UIColor.lightGray
        
        self.diffLabelUnitOutlet.textColor = UIColor.lightGray
        
    }
    
    /// - updates the labels
    private func updateLabels(latestReadings: [Glucose]) {
        
        // unwrap shared userdefaults
        guard let sharedUserDefaults = xDripClient.shared else {return}
        
        // unwrap bloodGlucoseUnitIsMgDl in userdefaults
        //default value for bool in userdefaults is false, false is for mgdl, true is for mmol
        let bloodGlucoseUnitIsMgDl = !sharedUserDefaults.bool(forKey: "bloodGlucoseUnit")
        
        // get urgentLowMarkValueInUserChosenUnit
        let urgentLowMarkValueInUserChosenUnit = getMarkValueInUserChosenUnit(forKey: "urgentLowMarkValue", bloodGlucoseUnitIsMgDl: bloodGlucoseUnitIsMgDl, withDefaultValue: ConstantsBGGraphBuilder.defaultUrgentLowMarkInMgdl)
        
        // get urgentHighMarkValueInUserChosenUnit
        let urgentHighMarkValueInUserChosenUnit = getMarkValueInUserChosenUnit(forKey: "urgentHighMarkValue", bloodGlucoseUnitIsMgDl: bloodGlucoseUnitIsMgDl, withDefaultValue: ConstantsBGGraphBuilder.defaultUrgentHighMarkInMgdl)
        
        // get highMarkValueInUserChoenUnit
        let highMarkValueInUserChosenUnit = getMarkValueInUserChosenUnit(forKey: "highMarkValue", bloodGlucoseUnitIsMgDl: bloodGlucoseUnitIsMgDl, withDefaultValue: ConstantsBGGraphBuilder.defaultHighMarkInMgdl)

        // get lowMarkValueInUserChosenUnit
        let lowMarkValueInUserChosenUnit = getMarkValueInUserChosenUnit(forKey: "lowMarkValue", bloodGlucoseUnitIsMgDl: bloodGlucoseUnitIsMgDl, withDefaultValue: ConstantsBGGraphBuilder.defaultLowMarkInMgdl)

        // if there's no readings, then give empty fields
        guard latestReadings.count > 0 else {
            
            valueLabelOutlet.textColor = UIColor.darkGray
            minutesLabelOutlet.text = ""
            minutesAgoLabelOutlet.text = ""
            diffLabelOutlet.text = ""
            diffLabelUnitOutlet.text = ""
                
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: "---")
            attributeString.addAttribute(.strikethroughStyle, value: 0, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
            return
        }
        
        // assign last reading
        let lastReading = latestReadings[0]
        
        // assign last but one reading
        let lastButOneReading = latestReadings.count > 1 ? latestReadings[1]:nil
        
        // start creating text for valueLabelOutlet, first the calculated value
        var calculatedValueAsString = unitizedString(calculatedValue: Double(lastReading.glucose), unitIsMgDl: bloodGlucoseUnitIsMgDl)
        
        // if latestReading is older than 11 minutes, then it should be strikethrough
        if lastReading.timestamp < Date(timeIntervalSinceNow: -60 * 11) {
            
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: calculatedValueAsString)
            attributeString.addAttribute(.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
        } else {
            
            // if lastButOneReading is available and is less than maxSlopeInMinutes earlier than lastReading, then show slopeArrow
            if let lastButOneReading = lastButOneReading {

                if lastReading.timestamp.timeIntervalSince(lastButOneReading.timestamp) <= Double(ConstantsBGGraphBuilder.maxSlopeInMinutes * 60) {
                    
                    // don't show delta if there are not enough values or the values are more than 20 mintes apart
                    calculatedValueAsString = calculatedValueAsString + " " + slopeArrow(slopeOrdinal: lastReading.trend)
                    
                }

            }
            
            // no strikethrough needed, but attributedText may still be set to strikethrough from previous period during which there was no recent reading.
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: calculatedValueAsString)
            attributeString.addAttribute(.strikethroughStyle, value: 0, range: NSMakeRange(0, attributeString.length))
            
            valueLabelOutlet.attributedText = attributeString
            
        }
        
        // if data is stale (over 11 minutes old), show it as gray colour to indicate that it isn't current
        // if not, then set color, depending on value lower than low mark or higher than high mark
        // set both HIGH and LOW BG values to red as previous yellow for hig is now not so obvious due to in-range colour of green.
        if lastReading.timestamp < Date(timeIntervalSinceNow: -60 * 11) {
            
            valueLabelOutlet.textColor = UIColor.lightGray
            
        } else if lastReading.glucose >= UInt16(urgentHighMarkValueInUserChosenUnit.mmolToMgdl(mgdl: bloodGlucoseUnitIsMgDl)) || lastReading.glucose <= UInt16(urgentLowMarkValueInUserChosenUnit.mmolToMgdl(mgdl: bloodGlucoseUnitIsMgDl)) {
            
            // BG is higher than urgentHigh or lower than urgentLow objectives
            valueLabelOutlet.textColor = UIColor.red
            
        } else if lastReading.glucose >= UInt16(highMarkValueInUserChosenUnit.mmolToMgdl(mgdl: bloodGlucoseUnitIsMgDl)) || lastReading.glucose <= UInt16(lowMarkValueInUserChosenUnit.mmolToMgdl(mgdl: bloodGlucoseUnitIsMgDl)) {
            
            // BG is between urgentHigh/high and low/urgentLow objectives
            valueLabelOutlet.textColor = UIColor.yellow
            
        } else {
            
            // BG is between high and low objectives so considered "in range"
            valueLabelOutlet.textColor = UIColor.green
            
        }
        
        // get minutes ago and create text for minutes ago label
        let minutesAgo = -Int(lastReading.timestamp.timeIntervalSinceNow) / 60
        let minutesAgoText = minutesAgo.description // + " " + (minutesAgo == 1 ? Texts.minute:Texts.minutes) + " " + Texts.ago
        
        minutesLabelOutlet.text = minutesAgoText
        
        // configure the localized text in the "mins ago" label
        let minutesAgoMinAgoText = (minutesAgo == 1 ? Texts.minute : Texts.minutes) + " " + Texts.ago
        
        minutesAgoLabelOutlet.text = minutesAgoMinAgoText
        
        minutesLabelOutlet.text = minutesAgoText
        
        // create delta value text (without the units)
        diffLabelOutlet.text = unitizedDeltaString(bgReading: lastReading, previousBgReading: lastButOneReading, mgdl: bloodGlucoseUnitIsMgDl)
        
        // set the delta unit label text
        let diffLabelUnitText = bloodGlucoseUnitIsMgDl ? Texts.mgdl : Texts.mmol
        diffLabelUnitOutlet.text = diffLabelUnitText
        
    }

    /// creates string with bg value in correct unit or "HIGH" or "LOW", or other like ???
    private func unitizedString(calculatedValue: Double, unitIsMgDl:Bool) -> String {
        var returnValue:String
        if (calculatedValue >= 400) {
            returnValue = Texts.HIGH
        } else if (calculatedValue >= 40) {
            returnValue = calculatedValue.mgdlToMmolAndToString(mgdl: unitIsMgDl)
        } else if (calculatedValue > 12) {
            returnValue = Texts.LOW
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
    
    private func slopeArrow(slopeOrdinal: UInt8) -> String {

        switch slopeOrdinal {
        
        case 7:
            return "\u{2193}\u{2193}"
            
        case 6:
            return "\u{2193}"
            
        case 5:
            return "\u{2198}"
            
        case 4:
            return "\u{2192}"
            
        case 3:
            return "\u{2197}"
            
        case 2:
            return "\u{2191}"
            
        case 1:
            return "\u{2191}\u{2191}"
            
        default:
            return ""
            
        }
       
    }
    
    /// creates string with difference from previous reading and also unit
    private func unitizedDeltaString(bgReading:Glucose, previousBgReading:Glucose?, mgdl:Bool) -> String {
        
        guard let previousBgReading = previousBgReading else {
            return "???"
        }
        
        if bgReading.timestamp.timeIntervalSince(previousBgReading.timestamp) > Double(ConstantsBGGraphBuilder.maxSlopeInMinutes * 60) {
            // don't show delta if there are not enough values or the values are more than 20 mintes apart
            return "???";
        }
        
        // delta value recalculated aligned with time difference between previous and this reading
        let value = currentSlope(thisBgReading: bgReading, previousBgReading: previousBgReading) * bgReading.timestamp.timeIntervalSince(previousBgReading.timestamp) * 1000;
        
        if(abs(value) > 100){
            // a delta > 100 will not happen with real BG values -> problematic sensor data
            return "ERR";
        }
        
        let valueAsString = value.mgdlToMmolAndToString(mgdl: mgdl)
        
        var deltaSign:String = ""
        if (value > 0) { deltaSign = "+"; }
        
        // quickly check "value" and prevent "-0mg/dl" or "-0.0mmol/l" being displayed
        if (mgdl) {
            if (value > -1) && (value < 1) {
                return "0"// + " " + Texts.mgdl;
            } else {
                return deltaSign + valueAsString //+ " " + Texts.mgdl;
            }
        } else {
            if (value > -0.1) && (value < 0.1) {
                return "0.0" //+ " " + Texts.mmol;
            } else {
                return deltaSign + valueAsString //+ " " + Texts.mmol;
            }
        }
    }
    
    private func currentSlope(thisBgReading:Glucose, previousBgReading:Glucose?) -> Double {
        
        if let previousBgReading = previousBgReading {
            let (slope,_) = calculateSlope(thisBgReading: thisBgReading, previousBgReading: previousBgReading);
            return slope
        } else {
            return 0.0
        }
        
    }
    
    private func calculateSlope(thisBgReading:Glucose, previousBgReading:Glucose) -> (Double, Bool) {
        
        if thisBgReading.timestamp == previousBgReading.timestamp
            ||
            thisBgReading.timestamp.toMillisecondsAsDouble() - previousBgReading.timestamp.toMillisecondsAsDouble() > Double(ConstantsBGGraphBuilder.maxSlopeInMinutes * 60 * 1000) {
            return (0,true)
        }
        
        return ( ( Double(previousBgReading.glucose) - Double(thisBgReading.glucose) ) / (previousBgReading.timestamp.toMillisecondsAsDouble() - thisBgReading.timestamp.toMillisecondsAsDouble()), false)
        
    }
    
    private func getMarkValueInUserChosenUnit(forKey key: String, bloodGlucoseUnitIsMgDl: Bool, withDefaultValue defaultValue: Double) -> Double {
        
        // unwrap shared userdefaults
        guard let sharedUserDefaults = xDripClient.shared else {return defaultValue}
        
        // unwrap urgentLowMarkValueInUserChosenUnit, if key not found then markValue will be 0.0
        var markValue = sharedUserDefaults.double(forKey: key)
        
        // if 0 set to defaultvalue
        if markValue == 0.0 {
            markValue = defaultValue
        }
        
        // check if conversion to mmol is needed
        if !bloodGlucoseUnitIsMgDl {
            markValue = markValue.mgdlToMmol()
        }
        
        return markValue
        
    }
    
}
