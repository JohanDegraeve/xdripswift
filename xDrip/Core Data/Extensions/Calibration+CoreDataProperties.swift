import Foundation
import CoreData


extension Calibration {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Calibration> {
        return NSFetchRequest<Calibration>(entityName: "Calibration")
    }

    @NSManaged public var adjustedRawValue: Double
    @NSManaged public var bg: Double
    @NSManaged public var distanceFromEstimate: Double
    @NSManaged public var estimateRawAtTimeOfCalibration: Double
    @NSManaged public var id: String
    @NSManaged public var intercept: Double
    @NSManaged public var possibleBad: Bool
    @NSManaged public var rawTimeStamp: Date?
    @NSManaged public var rawValue: Double
    @NSManaged public var sensorConfidence: Double
    @NSManaged public var slope: Double
    @NSManaged public var slopeConfidence: Double
    @NSManaged public var timeStamp: Date
    @NSManaged public var deviceName: String?
    @NSManaged public var bgreadings: NSSet
    @NSManaged public var sensor: Sensor
    
    // only used for firefly transmitters, for now
    @NSManaged public var sentToTransmitter: Bool
    
    // only used for firefly transmitters, for now
    @NSManaged public var acceptedByTransmitter: Bool

}

// MARK: Generated accessors for bgreadings
extension Calibration {

    @objc(addBgreadingsObject:)
    @NSManaged public func addToBgreadings(_ value: BgReading)

    @objc(removeBgreadingsObject:)
    @NSManaged public func removeFromBgreadings(_ value: BgReading)

    @objc(addBgreadings:)
    @NSManaged public func addToBgreadings(_ values: NSSet)

    @objc(removeBgreadings:)
    @NSManaged public func removeFromBgreadings(_ values: NSSet)

}
