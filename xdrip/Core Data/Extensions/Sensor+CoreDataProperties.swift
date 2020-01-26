import Foundation
import CoreData


extension Sensor {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Sensor> {
        return NSFetchRequest<Sensor>(entityName: "Sensor")
    }

    @NSManaged public var endDate: Date?
    @NSManaged public var id: String
    @NSManaged public var startDate: Date
    @NSManaged public var calibrations: NSSet?
    @NSManaged public var readings: NSSet?
    @NSManaged public var uploadedToNS: Bool

}

// MARK: Generated accessors for calibrations
extension Sensor {

    @objc(addCalibrationsObject:)
    @NSManaged public func addToCalibrations(_ value: Calibration)

    @objc(removeCalibrationsObject:)
    @NSManaged public func removeFromCalibrations(_ value: Calibration)

    @objc(addCalibrations:)
    @NSManaged public func addToCalibrations(_ values: NSSet)

    @objc(removeCalibrations:)
    @NSManaged public func removeFromCalibrations(_ values: NSSet)

}

// MARK: Generated accessors for readings
extension Sensor {

    @objc(addReadingsObject:)
    @NSManaged public func addToReadings(_ value: BgReading)

    @objc(removeReadingsObject:)
    @NSManaged public func removeFromReadings(_ value: BgReading)

    @objc(addReadings:)
    @NSManaged public func addToReadings(_ values: NSSet)

    @objc(removeReadings:)
    @NSManaged public func removeFromReadings(_ values: NSSet)

}
