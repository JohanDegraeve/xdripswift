import Foundation

struct M5StackReadBlePassWordTxMessage {
    
    var data: Data {
        
        let data = Data([M5StackTransmitterOpCodeTx.readBlePassWordTx.rawValue])
        
        return data
    }
}
