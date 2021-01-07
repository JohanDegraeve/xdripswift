import Foundation

enum ConstantsLibreSmoothing {
    
    /// - The first 16 readings of Libre (the trend) will be smoothed using Savitzky Golay Quadratic filter (if smoothing enabled)
    /// - this smoothing happens in the LibreDataParser, before they are being sent to the delegate (ie the RootViewController)
    /// - this value defines the filter width to use
    static let filterWidthPerMinuteValues = 5
    
    ///  how many times to do the smoothing off the per minute values
    static let libreSmoothingRepeatPerMinuteSmoothing = 2
    
    /// - The first 16 readings of Libre will be extended with each receipt of new readings, extended with stored values of prevous reading
    /// - an additional smoothing will be done on per 5 minute values
    /// - this value defines the filter width to use
    static let filterWidthPer5MinuteValues = 3
    
    ///  how many times to do the smoothing off the per 5 minutes values
    static let repeatPer5MinuteSmoothing = 3
    
    /// - The last 32 readings of Libre (the history) will be smoothed using Savitzky Golay Quadratic filter (if smoothing enabled)
    /// - this smoothing happens in the LibreDataParser, before they are being sent to the delegate (ie the RootViewController)
    /// - this value defines the filter width to use
    static let libreSmoothingFilterWidthPer15MinutesValues = 4
    
    /// defines period of minutes to delete, ie all readings as of 11 minutes ago till current time will be deleted
    static let readingsToDeleteInMinutes = 21
    
    /// for Libre 1 and 2 direct reading, how many previous per minute readings to store, only useful for smoothing
    static let amountOfPreviousReadingsToStore = 70
    
}
