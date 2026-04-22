import Foundation

struct DexcomGlucoseDataTxMessage: TransmitterTxMessage {
    
    let data: Data
    
    init() {
        
        data = Data([DexcomTransmitterOpCode.glucoseTx.rawValue]).appendingCRC()
        
    }
    
}
