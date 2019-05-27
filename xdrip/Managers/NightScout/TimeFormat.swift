import Foundation

class TimeFormat: NSObject {
    
    private static var formatterNightScoutDateString:DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()
    
    static func timestampNightScoutFormatFromDate(_ date: Date) -> String {
        return formatterNightScoutDateString.string(from: date)
    }
}
