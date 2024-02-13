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

struct WatchState: Codable {
    
    // these are similar to the context state of the Live Activity
    var bgReadingValues: [Double] = []
    var bgReadingDates: [Date] = []
    var isMgDl: Bool?
    var slopeOrdinal: Int?
    var deltaChangeInMgDl: Double?
    var urgentLowLimitInMgDl: Double?
    var lowLimitInMgDl: Double?
    var highLimitInMgDl: Double?
    var urgentHighLimitInMgDl: Double?
    var updatedDate: Date?
    
    // specific to the Watch state
    var activeSensorDescription: String?
    var sensorAgeInMinutes: Double?
    var sensorMaxAgeInMinutes: Double?
    var dataSourceConnectionStatusImageString: String?
    var dataSourceConnectionStatusIsActive: Bool?
    
    var bgValueInMgDl: Double?
    var bgReadingDate: Date?
    var bgUnitString: String?
    var bgValueStringInUserChosenUnit: String?
    
}

class WatchStateModel: NSObject, ObservableObject {
    
    var session: WCSession
    
    var bgReadingValues: [Double] = []
    var bgReadingDates: [Date] = []
    @Published var isMgDl: Bool = true
    @Published var slopeOrdinal: Int = 5
    @Published var deltaChangeInMgDl: Double = 3
    @Published var urgentLowLimitInMgDl: Double = 60
    @Published var lowLimitInMgDl: Double = 80
    @Published var highLimitInMgDl: Double = 170
    @Published var urgentHighLimitInMgDl: Double = 250
    @Published var updatedDate: Date = Date()
    @Published var activeSensorDescription: String = ""
    @Published var sensorAgeInMinutes: Double = 2880
    @Published var sensorMaxAgeInMinutes: Double = 14400
    
    init(session: WCSession = .default) {
        self.session = session
        super.init()

        session.delegate = self
        session.activate()
    }
    
    func bgValueInMgDl() -> Double {
        return bgReadingValues[0]
    }
    
    func bgReadingDate() -> Date {
        return bgReadingDates[0]
    }
    
    func bgUnitString() -> String {
        return isMgDl ? Texts_WatchApp.mgdl : Texts_WatchApp.mmol
    }
    
    func bgValueStringInUserChosenUnit() -> String {
        return bgReadingValues[0].mgdlToMmolAndToString(mgdl: isMgDl)
    }
    
    /// Blood glucose color dependant on the user defined limit values
    /// - Returns: a Color object either red, yellow or green
    func getBgColor() -> Color {
        if bgValueInMgDl() >= urgentHighLimitInMgDl || bgValueInMgDl() <= urgentLowLimitInMgDl {
            return .red
        } else if bgValueInMgDl() >= highLimitInMgDl || bgValueInMgDl() <= lowLimitInMgDl {
            return .yellow
        } else {
            return .green
        }
    }
    
    
    ///  returns a string holding the trend arrow
    /// - Returns: trend arrow string (i.e.  "↑")
    func trendArrow() -> String {
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
    }
    
    /// convert the optional delta change int (in mg/dL) to a formatted change value in the user chosen unit making sure all zero values are shown as a positive change to follow Nightscout convention
    /// - Returns: a string holding the formatted delta change value (i.e. +0.4 or -6)
    func getDeltaChangeStringInUserChosenUnit() -> String {
        
//        if deltaChangeInMgDl != nil {
            
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
//        } else {
//            return ""
//        }
    }
    
    func activeSensorProgress() -> (progress: Float, progressColor: Color, textColor: Color) {
        
        let sensorTimeLeftInMinutes = sensorMaxAgeInMinutes - sensorAgeInMinutes
        
        let progress = Float(1 - (sensorTimeLeftInMinutes / sensorMaxAgeInMinutes))
        
        // irrespective of all the above, if the current sensor age is over the max age, then just set everything to the expired colour to make it clear
        if sensorTimeLeftInMinutes < 0 {
            
            return (1.0, ConstantsWatchApp.sensorProgressExpired, ConstantsWatchApp.sensorProgressExpired)
            
        } else if sensorTimeLeftInMinutes <= ConstantsWatchApp.sensorProgressViewUrgentInMinutes {
            
            return (progress, ConstantsWatchApp.sensorProgressViewProgressColorUrgent, ConstantsWatchApp.sensorProgressViewProgressColorUrgent)
            
        } else if sensorTimeLeftInMinutes <= ConstantsWatchApp.sensorProgressViewWarningInMinutes {
            
            return (progress, ConstantsWatchApp.sensorProgressViewProgressColorWarning, ConstantsWatchApp.sensorProgressViewProgressColorWarning)
            
        } else {
            
            return (progress, ConstantsWatchApp.sensorProgressViewNormalColor, ConstantsWatchApp.sensorProgressNormalTextColor)
        }
    }
    
    
    func requestState() {
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        session.sendMessage(["stateRequest": true], replyHandler: nil) { error in
            print("WatchStateModel error: " + error.localizedDescription)
        }
    }
    
    private func processState(_ state: WatchState) {
        bgReadingValues = state.bgReadingValues //?? [Double]()
        bgReadingDates = state.bgReadingDates //?? [Date]()
        isMgDl = state.isMgDl ?? true
        slopeOrdinal = state.slopeOrdinal ?? 5
        deltaChangeInMgDl = state.deltaChangeInMgDl ?? 2
        urgentLowLimitInMgDl = state.urgentLowLimitInMgDl ?? 60
        lowLimitInMgDl = state.lowLimitInMgDl ?? 80
        highLimitInMgDl = state.highLimitInMgDl ?? 180
        urgentHighLimitInMgDl = state.urgentHighLimitInMgDl ?? 240
        updatedDate = state.updatedDate ?? Date()
        
//        bgValueInMgDl = state.bgValueInMgDl ?? 100.0
//        bgReadingDate = state.bgReadingDate ?? Date()
//        bgUnitString = state.bgUnitString ?? ""
//        bgValueStringInUserChosenUnit = state.bgValueStringInUserChosenUnit ?? ""
        
    }
}

extension WatchStateModel: WCSessionDelegate {
    func session(_: WCSession, activationDidCompleteWith state: WCSessionActivationState, error _: Error?) {
        print("WCSession activated: \(state == .activated)")
        requestState()
    }

    func session(_: WCSession, didReceiveMessage _: [String: Any]) {}

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("WCSession Reachability: \(session.isReachable)")
    }

    func session(_: WCSession, didReceiveMessageData messageData: Data) {
        if let state = try? JSONDecoder().decode(WatchState.self, from: messageData) {
            DispatchQueue.main.async {
                self.processState(state)
            }
        }
    }
}

