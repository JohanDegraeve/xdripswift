import Foundation
import os

/// Shared transmitters use the Watch system log; phone file/consumer logging remains iOS-only.
func trace(_ message: StaticString, log: OSLog, category: String, type: OSLogType, _ args: CVarArg...) {
    guard log.isEnabled(type: type) else { return }
    let format = message.description.replacingOccurrences(of: "%{public}", with: "%")
    let text = String(format: format, arguments: args)
    os_log("%{public}@", log: log, type: type, text)
}
