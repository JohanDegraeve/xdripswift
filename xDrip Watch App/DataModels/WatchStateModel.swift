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

/// holds, the watch state and allows updates and computed properties/variables to be generated for the different views that use it
/// also used to update the ComplicationSharedUserDefaultsModel in the app group so that the complication can access the data
final class WatchStateModel: NSObject, ObservableObject {
    
    /// the Watch Connectivity session
    var session: WCSession
    
    // set timer to automatically refresh the view
    // https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-a-timer-with-swiftui
    let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()
    @Published var timerControlDate = Date()
    
    var bgReadingValues: [Double] = []
    var bgReadingDates: [Date] = []
    var bgReadingDatesAsDouble: [Double] = []
    
//    @Published var updatedDatesString: String = ""
    
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
    @Published var timeStampOfLastFollowerConnection: Date = Date()
    @Published var secondsUntilFollowerDisconnectWarning: Int = 90
    @Published var timeStampOfLastHeartBeat: Date = Date()
    @Published var secondsUntilHeartBeatDisconnectWarning: Int = 90
    @Published var isMaster: Bool = true
    @Published var followerDataSourceType: FollowerDataSourceType = .nightscout
    @Published var followerBackgroundKeepAliveType: FollowerBackgroundKeepAliveType = .normal
    @Published var keepAliveIsDisabled: Bool = false
    @Published var liveDataIsEnabled: Bool = false
    @Published var remainingComplicationUserInfoTransfers: Int = 99
    
    @Published var lastUpdatedTextString: String = Texts_WatchApp.requestingData
    @Published var lastUpdatedTimeString: String = ""
    @Published var lastUpdatedTimeAgoString: String = ""
    @Published var debugString: String = "Debug..."
    @Published var chartHoursIndex: Int = 1
    @Published var requestingDataIconColor: Color = ConstantsAppleWatch.requestingDataIconColorInactive
    @Published var lastComplicationUpdateTimeStamp: Date = .distantPast
    
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
                return .red
            } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                return .yellow
            } else {
                return .green
            }
        } else {
            return .gray
        }
    }
    
    /// Color dependant on how long ago the last BG reading was
    /// - Returns: a Color either normal (gray) or yellow/red if the reading was several minutes ago and hasn't been updated
    func lastUpdatedTimeColor() -> Color {
        if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 7) {
            return .colorSecondary
        } else if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 12) {
            return .yellow
        } else {
            return .red
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
        if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 20) {
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
        } else {
            return "-"
        }
    }
    
    /// function to calculate the sensor progress value and return a text color to be used by the view
    /// - Returns: progress: the % progress between 0 and 1, textColor:
    func activeSensorProgress() -> (progress: Float, textColor: Color) {
        if sensorAgeInMinutes > 0 {
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
        } else {
            return (0, ConstantsHomeView.sensorProgressNormalTextColorSwiftUI)
        }
    }
    
    /// check when the last follower connection was and compare that to the actual time
    /// - Returns: image and color of the correct follower connection status
    func getFollowerConnectionNetworkStatus() -> (image: Image, color: Color) {
            if timeStampOfLastFollowerConnection > Date().addingTimeInterval(-Double(secondsUntilFollowerDisconnectWarning)) {
                return(Image(systemName: "network"), .green)
            } else {
                if followerBackgroundKeepAliveType != .disabled {
                    return(Image(systemName: "network.slash"), .red)
                } else {
                    // if keep-alive is disabled, then this will never show a constant server connection so just "disable" 
                    // the icon when not recent. It would be incorrect to show a red error.
                    return(Image(systemName: "network.slash"), .gray)
                }
            }
    }
    
    /// check when the last heartbeat connection was and compare that to the actual time
    /// if no heartbeat, just return the standard gray colour for the keep alive type icon
    func getFollowerBackgroundKeepAliveColor() -> Color {
        if followerBackgroundKeepAliveType == .heartbeat {
            if let timeDifferenceInSeconds = Calendar.current.dateComponents([.second], from: timeStampOfLastHeartBeat, to: Date()).second, timeDifferenceInSeconds > secondsUntilHeartBeatDisconnectWarning {
                return .red
            } else {
                return .green
            }
        } else {
            return .gray
        }
    }
    
    /// request a state update from the iOS companion app
    func requestWatchStateUpdate() {
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        // change the text, this must be done in the main thread but only do it if the watch app is reachable
        if session.isReachable {
            DispatchQueue.main.async {
                self.requestingDataIconColor = ConstantsAppleWatch.requestingDataIconColorPending
                self.debugString = self.debugString.replacingOccurrences(of: "Idle", with: "Fetching")
            }
            
            print("Requesting watch state update from iOS")
            
            session.sendMessage(["requestWatchUpdate": "watchState"], replyHandler: nil) { error in
                print("WatchStateModel error: " + error.localizedDescription)
            }
        }
    }
    
    private func processWatchStateFromDictionary(dictionary: [String: Any]) {
        let bgReadingDatesFromDictionary: [Double] = dictionary["bgReadingDatesAsDouble"] as? [Double] ?? [0]
        
        bgReadingDates = bgReadingDatesFromDictionary.map { (bgReadingDateAsDouble) -> Date in
            return Date(timeIntervalSince1970: bgReadingDateAsDouble)
        }
        
        bgReadingValues = dictionary["bgReadingValues"] as? [Double] ?? [100]
        isMgDl = dictionary["isMgDl"] as? Bool ?? true
        slopeOrdinal = dictionary["slopeOrdinal"] as? Int ?? 0
        deltaChangeInMgDl = dictionary["deltaChangeInMgDl"] as? Double ?? 0
        urgentLowLimitInMgDl = dictionary["urgentLowLimitInMgDl"] as? Double ?? 60
        lowLimitInMgDl = dictionary["lowLimitInMgDl"] as? Double ?? 70
        highLimitInMgDl = dictionary["highLimitInMgDl"] as? Double ?? 180
        urgentHighLimitInMgDl = dictionary["urgentHighLimitInMgDl"] as? Double ?? 250
        updatedDate = dictionary["updatedDate"] as? Date ?? .now
        activeSensorDescription = dictionary["activeSensorDescription"] as? String ?? ""
        sensorAgeInMinutes = dictionary["sensorAgeInMinutes"] as? Double ?? 0
        sensorMaxAgeInMinutes = dictionary["sensorMaxAgeInMinutes"] as? Double ?? 0
        isMaster = dictionary["isMaster"] as? Bool ?? true
        followerDataSourceType = FollowerDataSourceType(rawValue: dictionary["followerDataSourceTypeRawValue"] as? Int ?? 0) ?? .nightscout
        followerBackgroundKeepAliveType = FollowerBackgroundKeepAliveType(rawValue: dictionary["followerBackgroundKeepAliveTypeRawValue"] as? Int ?? 0) ?? .normal
        timeStampOfLastHeartBeat = dictionary["timeStampOfLastHeartBeat"] as? Date ?? .distantPast
        secondsUntilHeartBeatDisconnectWarning = dictionary["secondsUntilHeartBeatDisconnectWarning"] as? Int ?? 0
        keepAliveIsDisabled = dictionary["keepAliveIsDisabled"] as? Bool ?? false
        remainingComplicationUserInfoTransfers = dictionary["remainingComplicationUserInfoTransfers"] as? Int ?? 99
        liveDataIsEnabled = dictionary["liveDataIsEnabled"] as? Bool ?? false
        
        // check if there is any BG data available before updating the data source info strings accordingly
        if let bgReadingDate = bgReadingDate() {
            lastUpdatedTextString = Texts_WatchApp.lastReading + " "
            lastUpdatedTimeString = bgReadingDate.formatted(date: .omitted, time: .shortened)
            lastUpdatedTimeAgoString = bgReadingDate.daysAndHoursAgo(appendAgo: true)
        } else {
            lastUpdatedTextString = Texts_WatchApp.noSensorData
            lastUpdatedTimeString = ""
            lastUpdatedTimeAgoString = ""
        }
        
        debugString = generateDebugString()
        
        // now process the shared user defaults to get data for the WidgetKit complications
        updateComplicationData()
    }
    
    /// once we've process the state update, then save this data to the shared app group so that the complication can read it
    private func updateComplicationData() {
        guard let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName) else { return }
        
        let bgReadingDatesAsDouble = bgReadingDates.map { date in
            date.timeIntervalSince1970
        }
        
        let complicationSharedUserDefaultsModel = ComplicationSharedUserDefaultsModel(bgReadingValues: bgReadingValues, bgReadingDatesAsDouble: bgReadingDatesAsDouble, isMgDl: isMgDl, slopeOrdinal: slopeOrdinal, deltaChangeInMgDl: deltaChangeInMgDl, urgentLowLimitInMgDl: urgentLowLimitInMgDl, lowLimitInMgDl: lowLimitInMgDl, highLimitInMgDl: highLimitInMgDl, urgentHighLimitInMgDl: urgentHighLimitInMgDl, keepAliveIsDisabled: keepAliveIsDisabled, liveDataIsEnabled: liveDataIsEnabled)
        
        // store the model in the shared user defaults using a name that is uniquely specific to this copy of the app as installed on
        // the user's device - this allows several copies of the app to be installed without cross-contamination of widget/complication data
        if let stateData = try? JSONEncoder().encode(complicationSharedUserDefaultsModel) {
            sharedUserDefaults.set(stateData, forKey: "complicationSharedUserDefaults.\(Bundle.main.mainAppBundleIdentifier)")
        }
        
        // now that the new data is stored in the app group, try to force the complications to reload
        WidgetCenter.shared.reloadAllTimelines()
        
        lastComplicationUpdateTimeStamp = .now
    }
    
    
    // generate a debugString
    private func generateDebugString() -> String {
        
        var debugString = "Last state: \(Date().formatted(date: .omitted, time: .standard))"
        
        // check if there is any BG data available before updating the strings accordingly
        if let bgReadingDate = bgReadingDate() {
            debugString += "\nBG updated: \(bgReadingDate.formatted(date: .omitted, time: .standard))"
        } else {
            debugString += "\nBG updated: ---"
        }
        
        debugString += "\nBG values: \(bgReadingValues.count)"
        
        debugString += "\nComp enabled: \(liveDataIsEnabled.description)"
        
        debugString += "\nComp updated: \(lastComplicationUpdateTimeStamp.formatted(date: .omitted, time: .standard))"
        debugString += "\nComp remain: \(remainingComplicationUserInfoTransfers.description)/50"
        
        if !isMaster {
            debugString += "\nFollower conn.: \(timeStampOfLastFollowerConnection.formatted(date: .omitted, time: .standard))"
            
            if followerBackgroundKeepAliveType == .heartbeat {
                debugString += "\nLast hearbeat: \(timeStampOfLastHeartBeat.formatted(date: .omitted, time: .standard))"
            }
        }
        
        debugString += "\nScreen width: \(Int(WKInterfaceDevice.current().screenBounds.size.width))"
        debugString += "\niOS app: Idle"
        
        return debugString
    }
}

extension WatchStateModel: WCSessionDelegate {    
    func session(_: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error _: Error?) {
        if activationState == .activated {
            requestWatchStateUpdate()
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {}
    
    func session(_: WCSession, didReceiveMessageData messageData: Data) {}
    
    func session(_: WCSession, didReceiveMessage message: [String : Any]) {
        let watchStateAsDictionary = message["watchState"] as! [String : Any]
        
        DispatchQueue.main.async {
            self.processWatchStateFromDictionary(dictionary: watchStateAsDictionary)
            self.requestingDataIconColor = ConstantsAppleWatch.requestingDataIconColorActive
            
            // change the requesting icon color back after a small delay to prevent it
            // flashing on/off too quickly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.requestingDataIconColor = ConstantsAppleWatch.requestingDataIconColorInactive
            }
        }
    }
    
//    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let watchStateAsDictionary = userInfo["watchState"] as! [String : Any]
            DispatchQueue.main.async {
                self.processWatchStateFromDictionary(dictionary: watchStateAsDictionary)
            }
//        }
     }
}
