import Foundation
import os

/// log only used for debuglogging
fileprivate var log:OSLog = {
    let log:OSLog = OSLog(subsystem: "TodayView", category: "TodayView")
    return log
}()

/// will only be used during development
func debuglogging(_ logtext:String) {
    os_log("%{public}@", log: log, type: .debug, logtext)
}
