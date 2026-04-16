import Foundation

struct DexcomG6GlucoseDataRxMessage {
    
    let transmitterStatus: UInt8
    
    let sequenceNumber: UInt32
    
    let timeStamp: Date
    
    let calculatedValue: Double
    
    let algorithmStatus: DexcomAlgorithmState
    
    init?(data: Data, transmitterStartDate: Date) {
        
        guard data.count >= 16 else { return nil }
        
        guard data.starts(with: .glucoseG6Rx) else { return nil }
        
        transmitterStatus = data[1]

        sequenceNumber = data[2..<6].toInt()

        timeStamp = transmitterStartDate + TimeInterval(data.subdata(in: 6..<10).to(Int32.self))
        
        calculatedValue = Double(data[10]) + Double(data[11] & 0x0F) * 256.0
        
        if let receivedState = DexcomAlgorithmState(rawValue: data[12]) {
            
            algorithmStatus = receivedState
            
        } else {
            
            algorithmStatus = DexcomAlgorithmState.None
            
        }
        
    }
    
}
