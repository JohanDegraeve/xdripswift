import Foundation
import CoreData


extension BgReading {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BgReading> {
        return NSFetchRequest<BgReading>(entityName: "BgReading")
    }

    @NSManaged public var a: Double
    @NSManaged public var adjustedValue: NSNumber?
    @NSManaged public var ageAdjustedRawValue: Double
    @NSManaged public var backfilledAt: Date?
    @NSManaged public var valueIsFromWatch: Bool
    /// First iPhone receipt of this cycle from the Watch, including secondary-collector confirmations.
    @NSManaged public var watchReceivedAt: Date?
    /// Actual acquisition on the Watch, independent of delayed delivery to the iPhone.
    @NSManaged public var watchCollectedAt: Date?
    /// Nil identifies older stores whose live collection path was not recorded.
    /// False means only historical collection, or no collection by that device yet.
    @NSManaged public var phoneCollectedLive: NSNumber?
    @NSManaged public var watchCollectedLive: NSNumber?
    @NSManaged public var b: Double
    @NSManaged public var c: Double
    @NSManaged public var calculatedValue: Double
    @NSManaged public var calculatedValueSlope: Double
    @NSManaged public var calibrationFlag: Bool
    @NSManaged public var hideSlope: Bool
    @NSManaged public var id: String
    @NSManaged public var isSuppressedByFiveMinuteCadence: Bool
    @NSManaged public var ra: Double
    @NSManaged public var rawData: Double
    @NSManaged public var rb: Double
    @NSManaged public var rc: Double
    @NSManaged public var smoothedValue: NSNumber?
    @NSManaged public var timeStamp: Date
    @NSManaged public var deviceName: String?
    @NSManaged public var calibration: Calibration?
    @NSManaged public var sensor: Sensor?

}
