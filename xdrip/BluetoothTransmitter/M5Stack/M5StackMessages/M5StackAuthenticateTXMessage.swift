import Foundation

struct M5StackAuthenticateTXMessage {
    
    let password: String
    
    var data: Data? {

        if password.count == 0 {return nil}
        
        var data = Data([M5StackTransmitterOpCodeTx.authenticateTx.rawValue])
        
        if let passwordAsData = password.data(using: .utf8) {
            data.append(passwordAsData)
        } else {
            return nil
        }

        return data
    }
    
}

