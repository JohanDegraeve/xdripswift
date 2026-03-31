import Foundation

struct GlucoseDataRxMessage {
    
    let transmitterStatus: UInt8
    
    let calculatedValue: Double
    
    let algorithmStatus: DexcomAlgorithmState

    init?(data: Data) {

        guard data.count >= 14 else { return nil }
        
        guard data.starts(with: .glucoseRx) else { return nil }
        
        transmitterStatus = data[1]
        
        calculatedValue = Double(Data(data[10..<12]).to(UInt16.self) & 0xfff)
        
        if let receivedState = DexcomAlgorithmState(rawValue: data[12]) {
            
            algorithmStatus = receivedState
            
        } else {
            
            algorithmStatus = DexcomAlgorithmState.None
            
        }
        
        
        
    }

}
