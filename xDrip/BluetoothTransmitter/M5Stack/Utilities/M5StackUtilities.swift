import Foundation

class M5StackUtilities {
    
    /// for sending text string to a ble peripheral, when text can be longer than maximum packet size.
    /// - parameters:
    ///     - text : text that needs to be sent to peripheral
    ///     - maxBytesInOneBLEPacket : maximum size of text in one packet, usually 20
    ///     - opCode : opCode will be literally copied to first byte
    /// - returns:
    ///     - array of data, each element is 1st byte opCode, 2nd byte total number of packets, 3rd byte the number of the packet, then the text utf8 encoded. returns nil if splitting fails, which probably means text could not be converted to data using .utf8
    static func splitTextInBLEPackets(text: String, maxBytesInOneBLEPacket: Int, opCode: UInt8) -> [Data]? {
        
        guard let textAsData = text.data(using: .utf8) else {
            return nil
        }

        let sizeOfTextToSend = textAsData.count

        var charactersAdded = 0

        var totalNumberOfPacketsToSent = sizeOfTextToSend/(maxBytesInOneBLEPacket - 3)
        if sizeOfTextToSend > totalNumberOfPacketsToSent * (maxBytesInOneBLEPacket - 3) {
            totalNumberOfPacketsToSent += 1
        }
        
        var returnValue = [Data]()
        
        // number of the next packet to create
        var numberOfNextPacketToSend = 1
        
        while charactersAdded < sizeOfTextToSend {
            
            // calculate size of packet to send
            var sizeOfNextPacketToSend = maxBytesInOneBLEPacket
            if numberOfNextPacketToSend == totalNumberOfPacketsToSent {
                sizeOfNextPacketToSend = 3 + (sizeOfTextToSend - charactersAdded)//First byte = opcode, second byte is packet number, third byte = total number of packets, rest is content
            }
            
            var dataToAppend = Data()
            dataToAppend.append(opCode)
            dataToAppend.append(UInt8(numberOfNextPacketToSend))
            dataToAppend.append(UInt8(totalNumberOfPacketsToSent))
            for i in 0..<(sizeOfNextPacketToSend - 3) {
                dataToAppend.append(textAsData[charactersAdded + i])
            }
            
            returnValue.append(dataToAppend)
            
            // increase charactersSent
            charactersAdded = charactersAdded + (sizeOfNextPacketToSend - 3);
            
            // increase numberOfNextPacketToSend
            numberOfNextPacketToSend += 1
            
        }
        
        return returnValue

    }
    
}
