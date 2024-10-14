import Foundation

/// To solve issue that sometimes UserDefaults value observe is triggered twice in short time frame. Goal is that can be detected up to a millisecond.
///
/// see https://stackoverflow.com/questions/36193503/kvo-broken-in-ios-9-3, to solve this
///
/// where this needs to be checked, create an instance of KeyValueObserverTimeKeeper, example in NightscoutUploadManager
class KeyValueObserverTimeKeeper {
    
    private var keyObserverKeeper = [String: Date]()
    
    /// call this to check if last observe of key was at least withMinimumDelayMilliSeconds ago
    public func verifyKey(forKey key:String, withMinimumDelayMilliSeconds minimumDelayInMilliSeconds:Int) -> Bool {
        if let lastObserveTimeStamp = keyObserverKeeper[key] {
            if Date().toMillisecondsAsDouble() > lastObserveTimeStamp.toMillisecondsAsDouble() + Double(minimumDelayInMilliSeconds) {
                keyObserverKeeper[key] = Date()
                return true
            } else {
                return false
            }
        } else {
            keyObserverKeeper[key] = Date()
            return true
        }
    }
}

