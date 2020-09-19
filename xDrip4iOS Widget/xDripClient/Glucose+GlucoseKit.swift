import Foundation
import HealthKit

public struct Glucose {
    public let glucose: UInt16
    public let trend: UInt8
    public let timestamp: Date
    public let collector: String?
}

