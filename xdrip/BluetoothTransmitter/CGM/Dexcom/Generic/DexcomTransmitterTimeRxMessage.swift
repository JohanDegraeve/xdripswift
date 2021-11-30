import Foundation

struct DexcomTransmitterTimeRxMessage {
    
    /// transmitter start time
    public let transmitterStartDate: Date
    
    /// sensor start time
    public let sensorStartDate: Date?
    
    init?(data: Data) {
        
        guard data.count >= 5 else { return nil }
        
        guard data.starts(with: .transmitterTimeRx) else {return nil}
        
        transmitterStartDate = Date() - TimeInterval(data.subdata(in: 2..<6).to(Int32.self))
        
        if data.count >= 9 {
            
           // sensorStartDate = transmitterStartDate + TimeInterval(data.subdata(in: 6..<10).to(Int32.self))
            
            sensorStartDate = Date() - TimeInterval(data.subdata(in: 2..<6).to(Int32.self)) + TimeInterval(data.subdata(in: 6..<10).to(Int32.self))
            
        } else {
            
            sensorStartDate = nil
            
        }
        
    }
    
}
