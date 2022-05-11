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
        var lastReadings = bgReadingsAccessor.getLatestBgReadings(limit: ConstantsShareWithLoop.maxReadingsToShareWithLoop, fromDate: UserDefaults.standard.timeStampLatestLoopSharedBgReading, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)

        // if needed, remove readings less than loopDelay minutes old
        if UserDefaults.standard.loopDelay > 0 {
            
            while lastReadings.count > 0 &&  lastReadings[0].timeStamp.addingTimeInterval(TimeInterval(minutes: Double(UserDefaults.standard.loopDelay))) > Date() {

                lastReadings.remove(at: 0)
                
            }
            
        }

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
        
        // now, if needed, increase the timestamp for each reading
        if UserDefaults.standard.loopDelay > 0 {
            
            // create new dictionary that will have the readings with timestamp increased
            var newDictionary = [Dictionary<String, Any>]()
            
            // iterate through dictionary
            for reading in dictionary {
                
                var readingTimeStamp: Date?
                if let rawGlucoseStartDate = reading["DT"] as? String {
                    do {
                        
                        readingTimeStamp = try self.parseTimestamp(rawGlucoseStartDate)
                        
                    } catch  {
                        
                    }
                }

                if let readingTimeStamp = readingTimeStamp, let slopeOrdinal = reading["Trend"] as? Int, let value = reading["Value"] as? Double {

                    // create new date : original date + loopDelay
                    let newReadingTimeStamp = readingTimeStamp.addingTimeInterval(TimeInterval(minutes: Double(UserDefaults.standard.loopDelay)))

                    // ignore the reading if newReadingTimeStamp > now
                    if newReadingTimeStamp < Date() {

                        // this is for the json representation
                        let dateAsString = "/Date(" + Int64(floor(newReadingTimeStamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"
                        
                        // create new reading and append to new dictionary
                        let newReading: [String : Any] = [
                            "Trend" : slopeOrdinal,
                            "ST" : dateAsString,
                            "DT" : dateAsString,
                            "Value" : value,
                            "direction" : slopeOrdinal
                            ]

                        newDictionary.append(newReading)

                    }
                    
                }
                
            }

            dictionary = newDictionary
            
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
    
    private func parseTimestamp(_ timestamp: String) throws -> Date? {
        let regex = try NSRegularExpression(pattern: "\\((.*)\\)")
        if let match = regex.firstMatch(in: timestamp, range: NSMakeRange(0, timestamp.count)) {
            let epoch = Double((timestamp as NSString).substring(with: match.range(at: 1)))! / 1000
            return Date(timeIntervalSince1970: epoch)
        }
        return nil
    }

}
