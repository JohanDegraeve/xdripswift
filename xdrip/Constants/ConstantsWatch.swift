import Foundation

enum ConstantsWatch {
    
    /// text to add as notes in glucose events
    static let textInCreatedEvent = "created by xdrip"
    
    /// if the time between the last and last but one reading is less than minimiumTimeBetweenTwoReadingsInMinutes, then no new event will be created - except if there's been a disconnect in between these two readings
    static let minimiumTimeBetweenTwoReadingsInMinutes = 4.75

}
