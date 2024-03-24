//
//  WatchManager.swift
//  xdrip
//
//  Created by Paul Plant on 9/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation
import WatchConnectivity
import WidgetKit

public final class WatchManager: NSObject, ObservableObject {
    
    // MARK: - private properties
    
    /// a watch connectivity session instance
    private let session: WCSession
    
    /// a BgReadingsAccessor instance
    private var bgReadingsAccessor: BgReadingsAccessor
    
    /// a coreDataManager instance (must be passed from RVC in the initializer)
    private var coreDataManager: CoreDataManager
    
    /// hold the current watch state model
    private var watchState = WatchState()
    
    // MARK: - intializer
    
    init(coreDataManager: CoreDataManager, session: WCSession = .default) {
        
        // set coreDataManager and bgReadingsAccessor
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        self.session = session
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        
        processWatchState()
        
    }
    
    private func processWatchState() {
        DispatchQueue.main.async {
            
            // create two simple arrays to send to the live activiy. One with the bg values in mg/dL and another with the corresponding timestamps
            // this is needed due to the not being able to pass structs that are not codable/hashable
            let hoursOfBgReadingsToSend: Double = 12
            
            let bgReadings = self.bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: Date().addingTimeInterval(-3600 * hoursOfBgReadingsToSend), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
            
            let slopeOrdinal: Int = !bgReadings.isEmpty ? bgReadings[0].slopeOrdinal() : 1
            
            var deltaChangeInMgDl: Double?
            
            // add delta if needed
            if bgReadings.count > 1 {
                deltaChangeInMgDl = bgReadings[0].currentSlope(previousBgReading: bgReadings[1]) * bgReadings[0].timeStamp.timeIntervalSince(bgReadings[1].timeStamp) * 1000;
            }
            
            var bgReadingValues: [Double] = []
            var bgReadingDates: [Date] = []
            
            for bgReading in bgReadings {
                bgReadingValues.append(bgReading.calculatedValue)
                bgReadingDates.append(bgReading.timeStamp)
            }
            
            // now process the WatchState
            self.watchState.bgReadingValues = bgReadingValues
            self.watchState.bgReadingDates = bgReadingDates
            self.watchState.isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
            self.watchState.slopeOrdinal = slopeOrdinal
            self.watchState.deltaChangeInMgDl = deltaChangeInMgDl
            self.watchState.urgentLowLimitInMgDl = UserDefaults.standard.urgentLowMarkValue
            self.watchState.lowLimitInMgDl = UserDefaults.standard.lowMarkValue
            self.watchState.highLimitInMgDl = UserDefaults.standard.highMarkValue
            self.watchState.urgentHighLimitInMgDl = UserDefaults.standard.urgentHighMarkValue
            self.watchState.activeSensorDescription = UserDefaults.standard.activeSensorDescription
            self.watchState.isMaster = UserDefaults.standard.isMaster
            self.watchState.followerDataSourceTypeRawValue = UserDefaults.standard.followerDataSourceType.rawValue
            self.watchState.followerBackgroundKeepAliveTypeRawValue = UserDefaults.standard.followerBackgroundKeepAliveType.rawValue
            self.watchState.disableComplications = !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled
            
            if let sensorStartDate = UserDefaults.standard.activeSensorStartDate {
                self.watchState.sensorAgeInMinutes = Double(Calendar.current.dateComponents([.minute], from: sensorStartDate, to: Date()).minute!)
            } else {
                self.watchState.sensorAgeInMinutes = 0
            }
            
            self.watchState.sensorMaxAgeInMinutes = (UserDefaults.standard.activeSensorMaxSensorAgeInDays ?? 0) * 24 * 60
            
            // let's set the state values if we're using a heartbeat
            if let timeStampOfLastHeartBeat = UserDefaults.standard.timeStampOfLastHeartBeat, let secondsUntilHeartBeatDisconnectWarning = UserDefaults.standard.secondsUntilHeartBeatDisconnectWarning {
                self.watchState.secondsUntilHeartBeatDisconnectWarning = Int(secondsUntilHeartBeatDisconnectWarning)
                self.watchState.timeStampOfLastHeartBeat = timeStampOfLastHeartBeat
            }
            
            // let's set the follower server connection values if we're using follower mode
            if let timeStampOfLastFollowerConnection = UserDefaults.standard.timeStampOfLastFollowerConnection {
                self.watchState.secondsUntilFollowerDisconnectWarning = UserDefaults.standard.followerDataSourceType.secondsUntilFollowerDisconnectWarning
                self.watchState.timeStampOfLastFollowerConnection = timeStampOfLastFollowerConnection
            }
            
            self.sendToWatch()
        }
    }
    
    private func sendToWatch() {        
        guard let data = try? JSONEncoder().encode(watchState) else {
            print("Watch state JSON encoding error")
            return
        }
        
        guard session.isReachable else { return }
        
        session.sendMessageData(data, replyHandler: nil) { error in
            print("Cannot send data message to watch")
        }
    }
    
    
    // MARK: - Public functions
    
    func updateWatchApp() {
        processWatchState()
    }
}


// MARK: - conform to WCSessionDelegate protocol

extension WatchManager: WCSessionDelegate {
    public func sessionDidBecomeInactive(_: WCSession) {}
    
    public func sessionDidDeactivate(_: WCSession) {}
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    // process any received messages from the watch app
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        
        // if the action: refreshBGData message is received, then force the app to send new data to the Watch App
        if let requestWatchStateUpdate = message["requestWatchStateUpdate"] as? Bool, requestWatchStateUpdate {
            DispatchQueue.main.async {
                self.sendToWatch()
            }
        }
    }
    
    public func session(_: WCSession, didReceiveMessageData _: Data) {}
    
    public func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            DispatchQueue.main.async {
                self.sendToWatch()
            }
        }
    }
}
