//
//  WatchModel.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 11/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Combine
import Foundation
import SwiftUI
import WatchConnectivity
import WidgetKit

/// holds, the watch state and allows updates and computed properties/variables to be generated for the view
/// also used to update the ComplicationSharedUserDefaultsModel in the app group so that the complication can access the data
class WatchStateModel: NSObject, ObservableObject {
    
    /// shared UserDefaults to publish data
    private let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName)
    
    /// the Watch Connectivity session
    private var session: WCSession
    
    var bgReadingValues: [Double] = []
    var bgReadingDates: [Date] = []
    
    @Published var isMgDl: Bool = true
    @Published var slopeOrdinal: Int = 0
    @Published var deltaChangeInMgDl: Double = 0
    @Published var urgentLowLimitInMgDl: Double = 60
    @Published var lowLimitInMgDl: Double = 80
    @Published var highLimitInMgDl: Double = 170
    @Published var urgentHighLimitInMgDl: Double = 250
    @Published var updatedDate: Date = Date()
    @Published var activeSensorDescription: String = ""
    @Published var sensorAgeInMinutes: Double = 0
    @Published var sensorMaxAgeInMinutes: Double = 14400
    @Published var showAppleWatchDebug: Bool = false
    
    @Published var lastUpdatedTextString: String = "Updating..."
    @Published var lastUpdatedTimeString: String = "12:34"
    @Published var debugString: String = "Debug info..."
    @Published var chartHoursIndex: Int = 1
    
    init(session: WCSession = .default) {
        self.session = session
        super.init()

        session.delegate = self
        session.activate()
    }
    
    /// the latest BG reading value in the array as a double
    /// - Returns: an optional double with the bg value in mg/dL if it exists
    func bgValueInMgDl() -> Double? {
        return bgReadingValues.isEmpty ? nil : bgReadingValues[0]
    }
    
    /// return the latest BG value in the user's chosen unit as a string
    /// - Returns: a string with bgValueInMgDl() converted into the user unit
    func bgValueStringInUserChosenUnit() -> String {
        if let bgReadingDate = bgReadingDate(), let bgValueInMgDl = bgValueInMgDl(), bgReadingDate > Date().addingTimeInterval(-60 * 20) {
            return bgReadingValues.isEmpty ? "---" : bgValueInMgDl.mgdlToMmolAndToString(mgdl: isMgDl)
        } else {
            return "---"
        }
    }
    
    /// the timestamp of the latest BG reading value in the array
    /// - Returns: an optional date
    func bgReadingDate() -> Date? {
        return bgReadingDates.isEmpty ? nil : bgReadingDates[0]
    }
    
    /// returns the localized string of mg/dL or mmol/L
    /// - Returns: string representation of mg/dL or mmol/L
    func bgUnitString() -> String {
        return isMgDl ? Texts_Common.mgdl : Texts_Common.mmol
    }
    
    /// Blood glucose color dependant on the user defined limit values and also on if it is a recent value
    /// - Returns: a Color object either red, yellow or green
    func bgTextColor() -> Color {
        if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 7), let bgValueInMgDl = bgValueInMgDl() {
            if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                return Color(.red)
            } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                return Color(.yellow)
            } else {
                return Color(.green)
            }
        } else {
            return Color(.gray)
        }
    }
    
    /// Color dependant on how long ago the last BG reading was
    /// - Returns: a Color either normal (gray) or yellow/red if the reading was several minutes ago and hasn't been updated
    func lastUpdatedTimeColor() -> Color {
        if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 7) {
            return Color(.gray)
        } else if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 12) {
            return Color(.yellow)
        } else {
            return Color(.red)
        }
    }
    
    ///  returns a string holding the trend arrow
    /// - Returns: trend arrow string (i.e.  "↑")
    func trendArrow() -> String {
        if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 20) {
            switch slopeOrdinal {
            case 7:
                return "\u{2193}\u{2193}" // ↓↓
            case 6:
                return "\u{2193}" // ↓
            case 5:
                return "\u{2198}" // ↘
            case 4:
                return "\u{2192}" // →
            case 3:
                return "\u{2197}" // ↗
            case 2:
                return "\u{2191}" // ↑
            case 1:
                return "\u{2191}\u{2191}" // ↑↑
            default:
                return ""
            }
        } else {
            return ""
        }
    }
    
    /// convert the optional delta change int (in mg/dL) to a formatted change value in the user chosen unit making sure all zero values are shown as a positive change to follow Nightscout convention
    /// - Returns: a string holding the formatted delta change value (i.e. +0.4 or -6)
    func deltaChangeStringInUserChosenUnit() -> String {
            
            let valueAsString = deltaChangeInMgDl.mgdlToMmolAndToString(mgdl: isMgDl)
            
            var deltaSign: String = ""
            if (deltaChangeInMgDl > 0) { deltaSign = "+"; }
            
            // quickly check "value" and prevent "-0mg/dl" or "-0.0mmol/l" being displayed
            // show unitized zero deltas as +0 or +0.0 as per Nightscout format
            if (isMgDl) {
                if (deltaChangeInMgDl > -1) && (deltaChangeInMgDl < 1) {
                    return "+0"
                } else {
                    return deltaSign + valueAsString
                }
            } else {
                if (deltaChangeInMgDl > -0.1) && (deltaChangeInMgDl < 0.1) {
                    return "+0.0"
                } else {
                    return deltaSign + valueAsString
                }
            }
    }
    
    /// function to calculate the sensor progress value and return a text color to be used by the view
    /// - Returns: progress: the % progress between 0 and 1, textColor:
    func activeSensorProgress() -> (progress: Float, textColor: Color) {
        let sensorTimeLeftInMinutes = sensorMaxAgeInMinutes - sensorAgeInMinutes
        
        let progress = Float(1 - (sensorTimeLeftInMinutes / sensorMaxAgeInMinutes))
        
        // irrespective of all the above, if the current sensor age is over the max age, then just set everything to the expired colour to make it clear
        if sensorTimeLeftInMinutes < 0 {
            return (1.0, ConstantsHomeView.sensorProgressExpiredSwiftUI)
        } else if sensorTimeLeftInMinutes <= ConstantsHomeView.sensorProgressViewUrgentInMinutes {
            return (progress, ConstantsHomeView.sensorProgressViewProgressColorUrgentSwiftUI)
        } else if sensorTimeLeftInMinutes <= ConstantsHomeView.sensorProgressViewWarningInMinutes {
            return (progress, ConstantsHomeView.sensorProgressViewProgressColorWarningSwiftUI)
        } else {
            return (progress, ConstantsHomeView.sensorProgressNormalTextColorSwiftUI)
        }
    }
    
    
    func requestWatchStateUpdate() {
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        
        // change the text, this must be done in the main thread
        DispatchQueue.main.async {
            self.lastUpdatedTextString = "Waiting for data..."
            self.lastUpdatedTimeString = ""
        }
        
        print("Requesting watch state update from iOS")
        session.sendMessage(["requestWatchStateUpdate": true], replyHandler: nil) { error in
            print("WatchStateModel error: " + error.localizedDescription)
        }
    }
    
    private func processState(_ watchState: WatchState) {
        bgReadingValues = watchState.bgReadingValues
        bgReadingDates = watchState.bgReadingDates
        isMgDl = watchState.isMgDl ?? true
        slopeOrdinal = watchState.slopeOrdinal ?? 5
        deltaChangeInMgDl = watchState.deltaChangeInMgDl ?? 2
        urgentLowLimitInMgDl = watchState.urgentLowLimitInMgDl ?? 60
        lowLimitInMgDl = watchState.lowLimitInMgDl ?? 80
        highLimitInMgDl = watchState.highLimitInMgDl ?? 180
        urgentHighLimitInMgDl = watchState.urgentHighLimitInMgDl ?? 240
        updatedDate = watchState.updatedDate ?? Date()
        activeSensorDescription = watchState.activeSensorDescription ?? ""
        sensorAgeInMinutes = watchState.sensorAgeInMinutes ?? 0
        sensorMaxAgeInMinutes = watchState.sensorMaxAgeInMinutes ?? 0
        showAppleWatchDebug = watchState.showAppleWatchDebug ?? false
        
        // check if there is any BG data available before updating the strings accordingly
        if let bgReadingDate = bgReadingDate() {
            lastUpdatedTextString = "Last reading "
            lastUpdatedTimeString = bgReadingDate.formatted(date: .omitted, time: .shortened)
            debugString = "State updated: \(Date().formatted(date: .omitted, time: .shortened))\nBG updated: \(bgReadingDate.formatted(date: .omitted, time: .shortened))\nBG values: \(bgReadingValues.count)"
        } else {
            lastUpdatedTextString = "No sensor data"
            lastUpdatedTimeString = ""
            debugString = "State updated: \(Date().formatted(date: .omitted, time: .shortened))\nBG updated: ---\nBG values: \(bgReadingValues.count)"
        }
        
        // now process the shared user defaults to get data for the WidgetKit complications
        updateWatchSharedUserDefaults()
    }
    
    private func updateWatchSharedUserDefaults() {
        guard let sharedUserDefaults = sharedUserDefaults else { return }
        
        let bgReadingDatesAsDouble = bgReadingDates.map { date in
            date.timeIntervalSince1970
        }
        
        let complicationSharedUserDefaultsModel = ComplicationSharedUserDefaultsModel(bgReadingValues: bgReadingValues, bgReadingDatesAsDouble: bgReadingDatesAsDouble, isMgDl: isMgDl, slopeOrdinal: slopeOrdinal, deltaChangeInMgDl: deltaChangeInMgDl, urgentLowLimitInMgDl: urgentLowLimitInMgDl, lowLimitInMgDl: lowLimitInMgDl, highLimitInMgDl: highLimitInMgDl, urgentHighLimitInMgDl: urgentHighLimitInMgDl)
        
        if let stateData = try? JSONEncoder().encode(complicationSharedUserDefaultsModel) {
            sharedUserDefaults.set(stateData, forKey: "complicationSharedUserDefaults")
        }
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WatchStateModel: WCSessionDelegate {
#if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {}
#endif
    
    func session(_: WCSession, activationDidCompleteWith state: WCSessionActivationState, error _: Error?) {
        requestWatchStateUpdate()
    }

    func session(_: WCSession, didReceiveMessage _: [String: Any]) {}

    func sessionReachabilityDidChange(_ session: WCSession) {
    }

    func session(_: WCSession, didReceiveMessageData messageData: Data) {
        if let watchState = try? JSONDecoder().decode(WatchState.self, from: messageData) {
            DispatchQueue.main.async {
                self.processState(watchState)
            }
        }
    }
}
