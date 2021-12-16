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
    public func share() {
        
        // unwrap sharedUserDefaults
        guard let sharedUserDefaults = sharedUserDefaults else {return}

        // get last readings with calculated value
        let lastReadings = bgReadingsAccessor.getLatestBgReadings(limit: ConstantsShareWithLoop.maxReadingsToShareWithLoop, fromDate: UserDefaults.standard.timeStampLatestLoopSharedBgReading, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)

        // if there's no readings, then no further processing
        if lastReadings.count == 0 {
            return
        }

        // convert to json Dexcom Share format
        var dictionary = [Dictionary<String, Any>]()
        for reading in lastReadings {
            var representation = reading.dictionaryRepresentationForDexcomShareUpload
            // Adding "from" field to be able to use multiple BG sources with the same shared group in FreeAPS X
            representation["from"] = "xDrip"
            dictionary.append(representation)
        }

        // get Dictionary stored in UserDefaults from previous session
        // append readings already stored in this storedDictionary so that we get dictionary filled with maxReadingsToShareWithLoop readings, if possible
        if let storedDictionary = UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary, storedDictionary.count > 0 {
            
            let maxAmountsOfReadingsToAppend = ConstantsShareWithLoop.maxReadingsToShareWithLoop - dictionary.count
            
            if maxAmountsOfReadingsToAppend > 0 {
                
                let rangeToAppend = 0..<(min(storedDictionary.count, maxAmountsOfReadingsToAppend))
                
                for value in storedDictionary[rangeToAppend] {
                    
                    dictionary.append(value)
                    
                }
                
            }
            
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            return
        }
        
        sharedUserDefaults.set(data, forKey: "latestReadings")
        
        UserDefaults.standard.timeStampLatestLoopSharedBgReading = lastReadings.first!.timeStamp
        
        UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = dictionary
        
    }
    
}
