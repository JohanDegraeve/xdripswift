import Foundation

enum ConstantsSmoothing {
    
    /// - The first 16 readings of Libre (the trend) will be smoothed using Savitzky Golay Quadratic filter (if smoothing enabled)
    /// - this smoothing happens in the LibreDataParser, before they are being sent to the delegate (ie the RootViewController)
    /// - this value defines the filter width to use
    static let libreSmoothingFilterWidth = 5
    
    /// defines period of minutes to delete, ie all readings as of 11 minutes ago till current time will be deleted
    static let readingsToDeleteInMinutes = 11
    
}
