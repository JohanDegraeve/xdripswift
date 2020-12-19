import Foundation

enum ConstantsShareWithLoop {
    
    /// maximum number of readings to share with Loop
    static let maxReadingsToShareWithLoop = 10
    
    /// if the time between the last and last but one reading is less than minimiumTimeBetweenTwoReadingsInMinutes, then the reading will not be shared with loop - except if there's been a disconnect in between these two readings
    static let minimiumTimeBetweenTwoReadingsInMinutes = 4.75

}
