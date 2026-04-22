import Foundation

public struct DexcomG7BackfillMessage: Equatable {

    public let calculatedValue: Double
    
    public let timeStamp: Date
    
    private let timeStampSincePairing: UInt32 // Seconds since pairing, ie sensorage + age of the message
    private let glucose: UInt16?
    private let trend: Double?
    private let glucoseIsDisplayOnly: Bool

    init?(data: Data, sensorAge: TimeInterval) {
        //    0 1 2  3  4 5  6  7  8
        //   TTTTTT    BGBG SS    TR
        //   45a100 00 9600 06 0f fc

        guard data.count == 9 else {
            return nil
        }

        timeStampSincePairing = data[0..<4].toInt()
        
        timeStamp = Date().addingTimeInterval(-TimeInterval(sensorAge)).addingTimeInterval(TimeInterval(timeStampSincePairing))

        let glucoseBytes = data[4..<6].to(UInt16.self)

        if glucoseBytes != 0xffff {
            glucose = glucoseBytes & 0xfff
            glucoseIsDisplayOnly = (glucoseBytes & 0xf000) > 0
            calculatedValue = Double(glucose!)
        } else {
            glucose = nil
            glucoseIsDisplayOnly = false
            calculatedValue = 0
        }

        if data[8] == 0x7f {
            trend = nil
        } else {
            trend = Double(Int8(bitPattern: data[8])) / 10
        }

    }


}

