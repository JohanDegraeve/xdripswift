import Foundation

struct GlucoseDataRxMessage {
    
    let status: UInt8
    
    let calculatedValue: Double
    
    let state: DexcomCalibrationState

    init?(data: Data) {

        guard data.count >= 14 else { return nil }
        
        guard data.starts(with: .glucoseRx) else { return nil }
        
        status = data[1]
        
        calculatedValue = Double(Data(data[10..<12]).to(UInt16.self) & 0xfff)
        
        if let receivedState = DexcomCalibrationState(rawValue: data[12]) {
            
            state = receivedState
            
        } else {
            
            state = DexcomCalibrationState.unknown
            
        }
        
        
        
    }

}
