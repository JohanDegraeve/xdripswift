import Foundation

extension Array where Element: BgReading {

    /// - Filter out readings that are too close to each other
    /// - BgReadings array must be sorted by timeStamp of the BgReading, ascending, ie most recent reading is at index 0
    /// - parameters:
    ///     - minimumTimeBetweenTwoReadingsInMinutes : filter out readings that are to close to each other in time, minimum difference in time between two readings = minimumTimeBetweenTwoReadingsInMinutes
    ///     - timeStampLastProcessedBgReading : only readings younger than timeStampLastProcessedBgReading will be returned, if nil then this check is not done
    ///     - lastConnectionStatusChangeTimeStamp : if lastConnectionStatusChangeTimeStamp > timeStampLastProcessedBgReading then the most recent reading will be returned, even if it's less than minimumTimeBetweenTwoReadingsInMinutes away from timeStampLastProcessedBgReading
    /// - returns
    ///     filtered array, with readings at least minimumTimeBetweenTwoReadingsInMinutes away from each other
    func filter(minimumTimeBetweenTwoReadingsInMinutes: Double, lastConnectionStatusChangeTimeStamp: Date?, timeStampLastProcessedBgReading: Date?) -> [BgReading] {

        // initialise returnValue with empty array
        var returnValue = [BgReading]()

        // if most recent reading is either the minimum time away from the last processed reading or if there's been a disconnect after the last processed reading then add the most recent reading
        // but first let's see if there's at least one reading
        if let first = self.first {

            if let timeStampLastProcessedBgReading = timeStampLastProcessedBgReading {

                if first.timeStamp.timeIntervalSince(timeStampLastProcessedBgReading) > minimumTimeBetweenTwoReadingsInMinutes * 60.0 {

                    // most recent reading is more than minimumTimeBetweenTwoReadingsInMinutes later than last processed reading, so let's add it
                    returnValue.append(first)

                } else {

                    // most recent reading is less than minimumTimeBetweenTwoReadingsInMinutes later than last processed reading, but maybe there's been a disconnect/reconnect since the last processed reading
                    if let lastConnectionStatusChangeTimeStamp = lastConnectionStatusChangeTimeStamp {
                        if lastConnectionStatusChangeTimeStamp.timeIntervalSince(timeStampLastProcessedBgReading) > 0 {

                            // there's been a disconnect/reconnect since the last processed reading
                            // add the most recent reading
                            returnValue.append(first)

                        }

                    }

                }

            } else {

                // timeStampLastProcessedBgReading is nil, so this is the first reading being processed ever, let's add it
                returnValue.append(first)

            }

        }

        // now let's see if first was added, and also if there's more readings to add
        if returnValue.count > 0 {

            // there's one reading in returnValue, it's the most recent reading in the original array

            var timeStampLastAddedReading = returnValue[0].timeStamp

            // iterate through the remaining readings
            for reading in self {

                // by checking id , we skip the first in self, because that one is already added
                if reading.id != returnValue[0].id {

                    // if the reading is earler than timeStampLastProcessedBgReading then no further processing needed, this reading and also the following readings are older readings, older than timeStampLastProcessedBgReading
                    if let timeStampLastProcessedBgReading = timeStampLastProcessedBgReading {

                        if reading.timeStamp.timeIntervalSince(timeStampLastProcessedBgReading) < 0 {

                            break

                        }

                    }

                    // add the reading if
                    //      - the reading is more than minimumTimeBetweenTwoReadingsInMinutes earlier than the last added reading
                    //  and
                    //      - the gap between last added reading and timeStampLastProcessedBgReading more than minimumTimeBetweenTwoReadingsInMinutes (otherwise we may be adding a reading in between last processed reading and last added reading even though these two are alrady less than minimumTimeBetweenTwoReadingsInMinutes minutes away from each other
                    if reading.timeStamp.timeIntervalSince(timeStampLastAddedReading) < -minimumTimeBetweenTwoReadingsInMinutes * 60.0 && abs(timeStampLastAddedReading.timeIntervalSince(timeStampLastProcessedBgReading != nil ? timeStampLastProcessedBgReading! : Date(timeIntervalSince1970: 0))) > minimumTimeBetweenTwoReadingsInMinutes * 60.0 {

                        returnValue.append(reading)

                        timeStampLastAddedReading = reading.timeStamp

                    }

                }

            }

        }

        return returnValue

    }

}

extension Array where Element == BgReadingSnapshot {

    /// - Filter out readings that are too close to each other
    /// - BgReadings array must be sorted by timeStamp of the BgReading, ascending, ie most recent reading is at index 0
    /// - parameters:
    ///     - minimumTimeBetweenTwoReadingsInMinutes : filter out readings that are to close to each other in time, minimum difference in time between two readings = minimumTimeBetweenTwoReadingsInMinutes
    ///     - timeStampLastProcessedBgReading : only readings younger than timeStampLastProcessedBgReading will be returned, if nil then this check is not done
    ///     - lastConnectionStatusChangeTimeStamp : if lastConnectionStatusChangeTimeStamp > timeStampLastProcessedBgReading then the most recent reading will be returned, even if it's less than minimumTimeBetweenTwoReadingsInMinutes away from timeStampLastProcessedBgReading
    /// - returns
    ///     filtered array, with readings at least minimumTimeBetweenTwoReadingsInMinutes away from each other
    func filter(minimumTimeBetweenTwoReadingsInMinutes: Double, lastConnectionStatusChangeTimeStamp: Date?, timeStampLastProcessedBgReading: Date?) -> [BgReadingSnapshot] {
        var returnValue = [BgReadingSnapshot]()

        if let first = self.first {
            if let timeStampLastProcessedBgReading = timeStampLastProcessedBgReading {
                if first.timeStamp.timeIntervalSince(timeStampLastProcessedBgReading) > minimumTimeBetweenTwoReadingsInMinutes * 60.0 {
                    returnValue.append(first)
                } else if let lastConnectionStatusChangeTimeStamp = lastConnectionStatusChangeTimeStamp, lastConnectionStatusChangeTimeStamp.timeIntervalSince(timeStampLastProcessedBgReading) > 0 {
                    returnValue.append(first)
                }
            } else {
                returnValue.append(first)
            }
        }

        if returnValue.count > 0 {
            var timeStampLastAddedReading = returnValue[0].timeStamp

            for reading in self {
                if reading.id != returnValue[0].id {
                    if let timeStampLastProcessedBgReading = timeStampLastProcessedBgReading, reading.timeStamp.timeIntervalSince(timeStampLastProcessedBgReading) < 0 {
                        break
                    }

                    if reading.timeStamp.timeIntervalSince(timeStampLastAddedReading) < -minimumTimeBetweenTwoReadingsInMinutes * 60.0 && abs(timeStampLastAddedReading.timeIntervalSince(timeStampLastProcessedBgReading != nil ? timeStampLastProcessedBgReading! : Date(timeIntervalSince1970: 0))) > minimumTimeBetweenTwoReadingsInMinutes * 60.0 {
                        returnValue.append(reading)
                        timeStampLastAddedReading = reading.timeStamp
                    }
                }
            }
        }

        return returnValue
    }
}
