//
//  LoopManager.swift
//  xdrip
//
//  Created by Julian Groen on 05/04/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation
import OSLog

public class LoopManager: NSObject {
    
    // MARK: - private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager
    
    /// a BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    // for trace,
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLoopManager)
    
    // MARK: - public properties
    
    /// latest glucose data values - to be used only if using loopDelay
    /// - first is the youngest
    ///
    /// actually there's redundancy in data. Readings are normally read from coredata here in this module, and stored in lastReadings - disadvantage is that BgReadings in coredata only contain readings per 5 minutes + the latest reading (which can be less than 5 minutes later than latest but one reading. But when using loopdelay, we omit the most recent values, and end up with an array of readings, 5 minutes apart from each other, as a result Loop would receive a reading only every 5 minutes. For that reason, this second array glucoseData is introduced (later in the project). This array has readings per minute, smoothed. Ideally, glucoseData could be used no matter of loopDelay is used or not, but to avoid uncatched coding errors, I kept both
    public var glucoseData = [GlucoseData]()

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
        
        // will return if loop share is disabled
        guard UserDefaults.standard.loopShareType != .disabled else { return }
        
        // shared app group suite name to publish data
        let suiteName = UserDefaults.standard.loopShareType.sharedUserDefaultsSuiteName
        
        // make sure the enum didn't return an empty string
        guard suiteName != "" else { return }
        
        // create and unwrap sharedUserDefaults
        // this was previously done at the class level, but the scope must now be changed to allow us to change the target app group
        guard let sharedUserDefaults = UserDefaults(suiteName: suiteName) else {return}
        
        guard let timeStampLatestLoopSharedBgReading = UserDefaults.standard.timeStampLatestLoopSharedBgReading else {
            
            // if the last share data hasn't been set previously (could only happen on the first run) then just set it and return until next bg reading is processed. We won't normally ever get to here
            UserDefaults.standard.timeStampLatestLoopSharedBgReading = Date()
            
            return
            
        }
        
        // to make things easier to read
        let shareToLoopOnceEvery5Minutes = UserDefaults.standard.shareToLoopOnceEvery5Minutes
        
        // if the user doesn't want to limit Loop Share OR (if they do AND more than 4.5 minutes has passed since the last time we shared data) then let's process the readings and share them
        if !shareToLoopOnceEvery5Minutes || (shareToLoopOnceEvery5Minutes && Date().timeIntervalSince(timeStampLatestLoopSharedBgReading) > TimeInterval(minutes: 4.5)) {
            
            trace("    loopShare = Sharing data with Loop",log: log, category: ConstantsLog.categoryLoopManager, type: .info)
            
            // get last readings with calculated value
            // reduce timeStampLatestLoopSharedBgReading with 30 minutes. Because maybe Loop wasn't running for a while and so missed one or more readings. By adding 30 minutes of readings, we fill up a gap of maximum 30 minutes in Loop
            let lastReadings = bgReadingsAccessor.getLatestBgReadings(limit: ConstantsShareWithLoop.maxReadingsToShareWithLoop, fromDate: timeStampLatestLoopSharedBgReading.addingTimeInterval(-TimeInterval(minutes: 30)), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
            
            // calculate loopDelay, to avoid having to do it multiple times
            let loopDelay = LoopManager.loopDelay()
            
            // if needed, remove readings less than loopDelay minutes old from glucoseData
            if loopDelay > 0 {
                
                trace("    loopDelay = %{public}@. Deleting %{public}@ minutes of readings from glucoseData.",log: log, category: ConstantsLog.categoryLoopManager, type: .debug, loopDelay.description)
                
                while glucoseData.count > 0 &&  glucoseData[0].timeStamp.addingTimeInterval(loopDelay) > Date() {
                    
                    glucoseData.remove(at: 0)
                    
                }
                
                // if no readings anymore, then no need to continue
                if glucoseData.count == 0 {
                    return
                }
                
            } else if lastReadings.count == 0 {
                // this is the case where loopdelay = 0 and lastReadings is empty
                return
            }
            
            //  double check that lastReadings.first exists, because in some cases lastReadings is empty but still lastReadings.count != nil
            guard lastReadings.first != nil else {return}
            
            // convert to json Dexcom Share format
            var dictionary = [Dictionary<String, Any>]()
            
            if loopDelay > 0 {
                
                for reading in glucoseData {
                    
                    var representation = reading.dictionaryRepresentationForLoopShare
                    
                    // Adding "from" field to be able to use multiple BG sources with the same shared group in FreeAPS X
                    representation["from"] = "xDrip"
                    dictionary.append(representation)
                }
                
            } else {
                
                for reading in lastReadings {
                    
                    var representation = reading.dictionaryRepresentationForDexcomShareUpload
                    
                    // Adding "from" field to be able to use multiple BG sources with the same shared group in FreeAPS X
                    representation["from"] = "xDrip"
                    dictionary.append(representation)
                }
                
            }
            
            // now, if needed, increase the timestamp for each reading
            if loopDelay > 0 {
                
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
                        let newReadingTimeStamp = readingTimeStamp.addingTimeInterval(loopDelay)
                        
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
                            
                        }
                        
                    }
                    
                }
                
                dictionary = newDictionary
                
            }
            
            // If there are no readings to share, clear the shared container to avoid stale entries
            if dictionary.isEmpty {
                sharedUserDefaults.removeObject(forKey: "latestReadings")
                UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = nil
                return
            }
            
            guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
                return
            }
            
            // add a trace at debug level to record the data we're going to write to the shared container
            if let debugJSON = String(data: data, encoding: .utf8) {
                trace("in share: latestReadings JSON = %{public}@", log: log, category: ConstantsLog.categoryLoopManager, type: .debug, debugJSON)
            } else {
                trace("in share: latestReadings JSON = (unavailable UTF8). count = %{public}@", log: log, category: ConstantsLog.categoryLoopManager, type: .debug, dictionary.count.description)
            }
            
            // write readings to shared user defaults
            sharedUserDefaults.set(data, forKey: "latestReadings")
            
            // mirror exactly what we wrote so local deletions are reflected immediately
            UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = dictionary
            
            // initially set timeStampLatestLoopSharedBgReading to timestamp of first reading - may get another value later, in case loopdelay > 0
            // add 5 seconds to last Readings timestamp, because due to the way timestamp for libre readings is calculated, it may happen that the same reading shifts 1 or 2 seconds in next reading cycle
            if let first = lastReadings.first {
                UserDefaults.standard.timeStampLatestLoopSharedBgReading = first.timeStamp.addingTimeInterval(5.0)
            }
            
            // in case loopdelay is used, then update UserDefaults.standard.timeStampLatestLoopSharedBgReading with value of timestamp of first element in the dictionary
            if let element = dictionary.first, loopDelay > 0 {
                
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
            
        } else {
                
            trace("    loopDelay = Skipping Loop Share as user requests to limit sharing to 5 minutes and the last reading was <4.5 minutes ago at ",log: log, category: ConstantsLog.categoryLoopManager, type: .info, timeStampLatestLoopSharedBgReading.toStringInUserLocale(timeStyle: .short, dateStyle: .none, showTimeZone: false))
            
        }
        
    }
    
    /// Clear all glucose data previously shared with Loop / OS-AID from the shared app group container.
    /// Call this when BG readings are deleted to ensure stale values do not remain in the shared container.
    public func clearSharedLoopReadings() {
        let suiteName = UserDefaults.standard.loopShareType.sharedUserDefaultsSuiteName
        guard suiteName != "" else { return }
        
        if let sharedUserDefaults = UserDefaults(suiteName: suiteName) {
            sharedUserDefaults.removeObject(forKey: "latestReadings")
        }
        
        UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = nil
    }

    /// calculate loop delay to use dependent on the time of the day, based on UserDefaults loopDelaySchedule and loopDelayValueInMinutes
    ///
    /// finds element in loopDelaySchedule with value > actual minutes and uses previous element in loopDelayValueInMinutes as value to use as loopDelay
    public static func loopDelay() -> TimeInterval {
        
        // loopDelaySchedule is array of ints, giving minutes starting at 00:00 as of which new value for loopDelay should be used
        // if nil then user didn't set yet any value
        guard let loopDelaySchedule = UserDefaults.standard.loopDelaySchedule else {return TimeInterval(0)}
         
        // split in array of Int
        let loopDelayScheduleArray = loopDelaySchedule.splitToInt()
        
        // array size should be > 0
        guard loopDelaySchedule.count > 0 else {return TimeInterval(0)}
        
        // loopDelayValueInMinutes is array of ints, giving values to be applied as loopdelay, for matching minutes values in loopDelaySchedule
        guard let loopDelayValueInMinutes = UserDefaults.standard.loopDelayValueInMinutes else {return TimeInterval(0)}
            
        // splity in array of int
        let loopDelayValueInMinutesArray = loopDelayValueInMinutes.splitToInt()
        
        // array size should be > 0, and size should be equal to size of loopDelayScheduleArray
        guard loopDelayValueInMinutesArray.count > 0, loopDelayScheduleArray.count == loopDelayValueInMinutesArray.count else {return TimeInterval(0)}
        
        // minutes since midnight
        let minutes = Int16(Date().minutesSinceMidNightLocalTime())
        
        // index in loopDelaySchedule and loopDelayValueInMinutes, start with first value
        var indexInLoopDelayScheduleArray = 0
        
        // loop through Ints in loopDelayScheduleArray, until value > current minutes
        for (index, schedule) in loopDelayScheduleArray.enumerated() {
            
            if schedule > minutes {
                break
            }
            
            if index < loopDelayScheduleArray.count - 1 {
                if loopDelayScheduleArray[index + 1] > minutes {
                    break
                }
            } else {
                indexInLoopDelayScheduleArray = index
                break
            }
            indexInLoopDelayScheduleArray = indexInLoopDelayScheduleArray + 1
        }

        return TimeInterval(minutes: Double(loopDelayValueInMinutesArray[indexInLoopDelayScheduleArray]))
 
    }

    // MARK: - private functions

    private func parseTimestamp(_ timestamp: String) throws -> Date? {
        let regex = try NSRegularExpression(pattern: "\\((.*)\\)")
        if let match = regex.firstMatch(in: timestamp, range: NSMakeRange(0, timestamp.count)) {
            let epoch = Double((timestamp as NSString).substring(with: match.range(at: 1)))! / 1000
            return Date(timeIntervalSince1970: epoch)
        }
        return nil
    }

}
