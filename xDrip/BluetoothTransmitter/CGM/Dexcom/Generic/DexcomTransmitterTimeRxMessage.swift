import Foundation

struct DexcomTransmitterTimeRxMessage {
    
    /// transmitter start time
    public let transmitterStartDate: Date
    
    /// sensor start time
    public let sensorStartDate: Date?
    
    /// Raw clock values identify a session independently of the phone's wall clock.
    let transmitterTime: UInt32
    let sensorStartCounter: UInt32?

    init?(data: Data, receivedAt: Date = Date()) {
        
        guard data.count >= 6 else { return nil }
        
        guard data.starts(with: .transmitterTimeRx) else {return nil}
        
        transmitterTime = data.subdata(in: 2..<6).to(UInt32.self)
        transmitterStartDate = receivedAt - TimeInterval(data.subdata(in: 2..<6).to(Int32.self))
        
        if data.count >= 10 {
            
            let counter = data.subdata(in: 6..<10).to(UInt32.self)
            // Keep legacy date parsing unchanged. Only use plausible, non-sentinel counters
            // for identity matching; incomplete/invalid clocks retain the existing behaviour.
            sensorStartCounter = counter > 0 && counter <= transmitterTime && transmitterTime <= UInt32(Int32.max) ? counter : nil
            sensorStartDate = transmitterStartDate + TimeInterval(data.subdata(in: 6..<10).to(Int32.self))
            
        } else {
            
            sensorStartDate = nil
            sensorStartCounter = nil
            
        }
        
    }
    
}

/// Runtime identity for the active G5/G6/ONE session. Its date binds it to the current
/// internal sensor; start/stop also clears it so explicit lifecycle changes retain their resets.
struct DexcomSensorSessionIdentity: Codable, Equatable {
    let transmitterID: String
    let startCounter: UInt32
    let lastTransmitterTime: UInt32
    let activeSensorStartDate: Date

    func matches(transmitterID: String, clock: DexcomTransmitterTimeRxMessage) -> Bool {
        return self.transmitterID == transmitterID
            && clock.sensorStartCounter == startCounter
            // A reset/replacement (including an Anubis clock restart) must not inherit an
            // identity from the previous clock epoch. Fall back to normal session detection.
            && clock.transmitterTime >= lastTransmitterTime
    }

    func resolvedStartDate(transmitterID: String, clock: DexcomTransmitterTimeRxMessage, activeStartDate: Date?) -> Date? {
        guard matches(transmitterID: transmitterID, clock: clock),
              activeStartDate == activeSensorStartDate else { return nil }
        // The counter is unchanged: receipt latency or a phone-clock correction does not
        // constitute a new sensor. Keep the established date, calibration and adjustment context.
        return activeSensorStartDate
    }
}
