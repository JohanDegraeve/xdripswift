import Foundation

/// M5Stack may send strings in several packets. This class is there to compose to packets and allows to read the resulting string
/// - byte 1 is the total number of packets that must be received before the string is complete
/// - byte 2 is the number of the current packet being added
/// - the remaining bytes represent the string
/// if all packets are received, then the string can be retrieved with the text function
class M5StackPacket {
    
    // MARK: private properties
    
    /// keep track of when last packet was received, if more than x milliseconds, then all data is reset
    private var timeStampLastPacket: Date?
    
    /// total number of packets to receive
    private var totalNumberOfPacketsToReceive: Int?
    
    /// the packets already received, only if the number of packets equals totalNumberOfPacketsToReceive then we've received all packets
    private var packetsReceived: [Data] = []
    
    // MARK: public functions
    
    /// gets the text, only returns a value of all packets were received
    func getText() -> String? {
        
        // check that private properties are initialised
        guard timeStampLastPacket != nil, let totalNumberOfPacketsToReceive = totalNumberOfPacketsToReceive, packetsReceived.count > 0 else {return nil}
        
        // check if all packets were received
        for i in 1...totalNumberOfPacketsToReceive {
            if packetsReceived[i - 1].count == 0 {
                return nil
            }
        }
        
        // read the string first as data
        var result = Data()
        for i in 1...totalNumberOfPacketsToReceive {
            
            result.append(packetsReceived[i - 1])
            
        }

        // return the result
        return String(bytes: result, encoding: .utf8)
        
    }
    
    /// to be used when new packet received from M5Stack, value is the complete value received from M5Stack, inclusive opcode.
    ///
    /// - byte 1 is the total number of packets that must be received before the string is complete
    /// - byte 2 is the number of the current packet being added
    /// - the remaining bytes represent the string
    /// if all packets are received, then the string can be retrieved with the text function
    func addNewPacket(value: Data) {
        
        // length should be at least 3 bytes, otherwise just ignore
        if value.count < 3 {return}
        
        // if more than 200 ms ago since last packet, then reset all properties, looks like a new
        if let timeStampLastPacket = timeStampLastPacket, Date().toMillisecondsAsInt64() - timeStampLastPacket.toMillisecondsAsInt64() > ConstantsM5Stack.maximumTimeBetweenTwoPacketsInMs {
            
            resetAllProperties()
        }
        
        // set timeStampLastPacket to now
        timeStampLastPacket = Date()
        
        totalNumberOfPacketsToReceive = Int(value.uint8(position: 2))
        guard let totalNumberOfPacketsToReceive = totalNumberOfPacketsToReceive else {return}
        
        // check packetsReceived, possibly still empty which means this would be the first packet being received
        if packetsReceived.count == 0 {
            // want to have an array of Data, size totalNumberOfPacketsToReceive, actual values will be set as we receive the packets, first one being just a few lines of code later
            for _ in 1...totalNumberOfPacketsToReceive {
                packetsReceived.append(Data())
            }
        }
        
        // get number of this packet
        let numberOfThisPacket = Int(value.uint8(position: 1))
        guard numberOfThisPacket <= totalNumberOfPacketsToReceive else {return}// would be a coding error
        
        // assign data
        packetsReceived[numberOfThisPacket - 1] = value.subdata(in: 3..<value.count)
        
    }
    
    
    // MARK: private functions
    
    /// sets all properties to nil
    private func resetAllProperties() {
        timeStampLastPacket = nil
        packetsReceived = []
        totalNumberOfPacketsToReceive = nil
    }
    
}

