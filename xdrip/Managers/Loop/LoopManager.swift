//
//  LoopManager.swift
//  xdrip
//
//  Created by Julian Groen on 05/04/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation

public class LoopManager:NSObject {
    
    // MARK: - public properties
    
    // MARK: - private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager
    
    /// a BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// shared UserDefaults to publish data
    private let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName)
    
    init(coreDataManager:CoreDataManager) {
        
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        
        // call super.init
        super.init()
        
    }
    
    /// share latest readings with Loop
    public func share() {
        
        // unwrap sharedUserDefaults
        guard let sharedUserDefaults = sharedUserDefaults else {return}

        // get last readings with calculated value
        let lastReadings = bgReadingsAccessor.getLatestBgReadings(limit: ConstantsShareWithLoop.maxReadingsToShareWithLoop, fromDate: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        // if there's no readings, then no further processing
        if lastReadings.count == 0 {
            return
        }
        
        // convert to json Dexcom Share format
        var dictionary = [Dictionary<String, Any>]()
        for reading in lastReadings {
            dictionary.append(reading.dictionaryRepresentationForDexcomShareUpload)
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            return
        }
        
        
        sharedUserDefaults.set(data, forKey: "latestReadings")
        
    }
    
}
