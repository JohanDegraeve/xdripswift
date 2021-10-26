import Foundation

struct GlucoseBackfillRxMessage {
    
    // variables defined according to documentation Dexcom-Doc
    
    let transmitterStatus: UInt8
    
    let backFillStatus: UInt8
    
    let backFillIdentifier: UInt8
    
    let backFillStartTimeStamp: Date
    
    let backFillEndTimeStamp: Date
    
    init?(data: Data, transmitterStartDate: Date) {
        
        guard data.count >= 20 else { return nil }
        
        guard data.starts(with: .glucoseBackfillRx) else {return nil}
        
        transmitterStatus = data[1]
        
        backFillStatus = data[2]
        
        backFillIdentifier = data[3]
        
        backFillStartTimeStamp = transmitterStartDate + TimeInterval(data.subdata(in: 4..<8).to(Int32.self))
        
        backFillEndTimeStamp = transmitterStartDate + TimeInterval(data.subdata(in: 8..<12).to(Int32.self))
        
    }
}
