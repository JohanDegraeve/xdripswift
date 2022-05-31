//
//  LoopManager.swift
//  xdrip
//
//  Created by Julian Groen on 05/04/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation
import OSLog

public class LoopManager:NSObject {
    
    // MARK: - private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager
    
    /// a BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// shared UserDefaults to publish data
    private let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName)
    
    // for trace,
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLoopManager)

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

        trace("in share", log: log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info)

        // get last readings with calculated value
        // reduce timeStampLatestLoopSharedBgReading with 30 minutes. Because maybe Loop wasn't running for a while and so missed one or more readings. By adding 30 minutes of readings, we fill up a gap of maximum 30 minutes in Loop
        var lastReadings = bgReadingsAccessor.getLatestBgReadings(limit: ConstantsShareWithLoop.maxReadingsToShareWithLoop, fromDate: UserDefaults.standard.timeStampLatestLoopSharedBgReading?.addingTimeInterval(-TimeInterval(minutes: 30)), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)

        trace("    list of readings before applying delay:",log: log, category: ConstantsLog.categoryLoopManager, type: .info)
        
        for reading in lastReadings {

            trace("    timestamp %{public}@", log: log, category: ConstantsLog.categoryLoopManager, type: .info, reading.timeStamp.toString(timeStyle: .long, dateStyle: .long))
            trace("        value %{public}@", log: log, category: ConstantsLog.categoryLoopManager, type: .info, reading.calculatedValue.description)
            trace("", log: log, category: ConstantsLog.categoryLoopManager, type: .info)
            
        }
        
        // if needed, remove readings less than loopDelay minutes old
        if UserDefaults.standard.loopDelay > 0 {
            
            trace("    loopDelay > 0. Deleting readings",log: log, category: ConstantsLog.categoryLoopManager, type: .info)
            
            while lastReadings.count > 0 &&  lastReadings[0].timeStamp.addingTimeInterval(TimeInterval(minutes: Double(UserDefaults.standard.loopDelay))) > Date() {

                trace("    removing reading with timestamp %{public}@", log: log, category: ConstantsLog.categoryLoopManager, type: .info, lastReadings[0].timeStamp.toString(timeStyle: .long, dateStyle: .long))
                trace("        value %{public}@", log: log, category: ConstantsLog.categoryLoopManager, type: .info, lastReadings[0].calculatedValue.description)
                trace("", log: log, category: ConstantsLog.categoryLoopManager, type: .info)
                
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
                            "direction" : slopeOrdinal,
                            "from" : "xDrip"
                            ]

                        newDictionary.append(newReading)
                        
                        trace("    adding reading with timestamp %{public}@", log: log, category: ConstantsLog.categoryLoopManager, type: .info, newReadingTimeStamp.toString(timeStyle: .long, dateStyle: .long))
                        trace("        value %{public}@", log: log, category: ConstantsLog.categoryLoopManager, type: .info, value.description)
                        trace("", log: log, category: ConstantsLog.categoryLoopManager, type: .info)

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
        
        // write readings to shared user defaults
        sharedUserDefaults.set(data, forKey: "latestReadings")
        
        // store in local userdefaults
        UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = dictionary

        // initially set timeStampLatestLoopSharedBgReading to timestamp of first reading - may get another value later, in case loopdelay > 0
        // add 5 seconds to last Readings timestamp, because due to the way timestamp for libre readings is calculated, it may happen that the same reading shifts 1 or 2 seconds in next reading cycle
        UserDefaults.standard.timeStampLatestLoopSharedBgReading = lastReadings.first!.timeStamp.addingTimeInterval(5.0)
        
        // in case loopdelay is used, then update UserDefaults.standard.timeStampLatestLoopSharedBgReading with value of timestamp of first element in the dictionary
        if let element = dictionary.first, UserDefaults.standard.loopDelay > 0 {

            if let elementDateAsString = element["DT"] as? String {
                
                do {
                    if let readingTimeStamp = try self.parseTimestamp(elementDateAsString) {
                        UserDefaults.standard.timeStampLatestLoopSharedBgReading = readingTimeStamp
                    }
                } catch  {
                    // timeStampLatestLoopSharedBgReading keeps initially set value
                }

            }
        }

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
