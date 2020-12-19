//
//  LoopManager.swift
//  xdrip
//
//  Created by Julian Groen on 05/04/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation

public class LoopManager:NSObject {
    
    // MARK: - private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager
    
    /// a BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// shared UserDefaults to publish data
    private let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName)
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager) {
        
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        // call super.init
        super.init()
        
    }
    
    // MARK: - public functions
    
    /// share latest readings with Loop
    ///     - lastConnectionStatusChangeTimeStamp : when was the last transmitter dis/reconnect - if nil then  1 1 1970 is used
    public func share(lastConnectionStatusChangeTimeStamp: Date?) {
        
        // unwrap sharedUserDefaults
        guard let sharedUserDefaults = sharedUserDefaults else {return}

        // get last readings with calculated value, don't apply yet the filtering, we will first store for the widget unfiltered
        var lastReadings = bgReadingsAccessor.getLatestBgReadings(limit: ConstantsShareWithLoop.maxReadingsToShareWithLoop, fromDate: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)

        // convert to json Dexcom Share format
        var dictionary = [Dictionary<String, Any>]()
        for reading in lastReadings {
            dictionary.append(reading.dictionaryRepresentationForDexcomShareUpload)
        }

        // to json
        if let data = try? JSONSerialization.data(withJSONObject: dictionary) {

            // share to userDefaults for widget
            if lastReadings.count > 0 {
                sharedUserDefaults.set(data, forKey: "latestReadings-widget")
            }
            
        }
        
        // applying minimumTimeBetweenTwoReadingsInMinutes filter, for loop
        lastReadings = lastReadings.filter(minimumTimeBetweenTwoReadingsInMinutes: ConstantsShareWithLoop.minimiumTimeBetweenTwoReadingsInMinutes, lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp, timeStampLastProcessedBgReading: UserDefaults.standard.timeStampLatestLoopSharedBgReading)

        // if there's no readings, then no further processing
        if lastReadings.count == 0 {
            return
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            return
        }
        
        sharedUserDefaults.set(data, forKey: "latestReadings")
        
        if let last = lastReadings.last {
            UserDefaults.standard.timeStampLatestLoopSharedBgReading = last.timeStamp
        }
        
    }
    
}
