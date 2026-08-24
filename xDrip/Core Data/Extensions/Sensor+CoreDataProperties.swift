import Foundation
import CoreData


extension Sensor {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Sensor> {
        return NSFetchRequest<Sensor>(entityName: "Sensor")
    }

    @NSManaged public var endDate: Date?
    @NSManaged public var id: String
    @NSManaged public var longTermNoise: NSNumber?
    @NSManaged public var longTermNoiseCoverage: Double
    @NSManaged public var noiseAlgorithmVersion: Int16
    @NSManaged public var noiseHistoryIsComplete: Bool
    @NSManaged public var noiseLatestReadingAt: Date?
    @NSManaged public var noiseStateRaw: Int16
    @NSManaged public var noiseUpdatedAt: Date?
    @NSManaged public var shortTermNoise: NSNumber?
    @NSManaged public var shortTermNoiseCoverage: Double
    @NSManaged public var startDate: Date
    @NSManaged public var calibrations: NSSet?
    @NSManaged public var noiseSamples: NSSet?
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

// MARK: Generated accessors for noiseSamples
extension Sensor {

    @objc(addNoiseSamplesObject:)
    @NSManaged public func addToNoiseSamples(_ value: SensorNoiseSample)

    @objc(removeNoiseSamplesObject:)
    @NSManaged public func removeFromNoiseSamples(_ value: SensorNoiseSample)

    @objc(addNoiseSamples:)
    @NSManaged public func addToNoiseSamples(_ values: NSSet)

    @objc(removeNoiseSamples:)
    @NSManaged public func removeFromNoiseSamples(_ values: NSSet)
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
