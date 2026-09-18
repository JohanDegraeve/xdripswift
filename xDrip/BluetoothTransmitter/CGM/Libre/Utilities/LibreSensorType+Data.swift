import Foundation
import os

extension LibreSensorType {
    /// decrypts for libre2 and libreUs,
    func decryptIfPossibleAndNeeded(rxBuffer:inout Data, headerLength: Int, log: OSLog?, patchInfo: String?, uid: [UInt8]) -> Bool {

        // index of last byte to process
        let rxBufferEnd = headerLength + 344 - 1

        // rxBuffer size should be at least headerLength + 344, if not don't further process
        guard rxBuffer.count >= headerLength + 344 else {
            return false
        }

        // decrypt if libre2 or libreUS
        if requiresLibre2Decryption {

            var libreData = rxBuffer.subdata(in: headerLength..<(rxBufferEnd + 1))

            if let info = patchInfo?.hexadecimal() {

                if let log = log {
                    trace("    decrypting libre data", log: log, category: ConstantsLog.categoryLibreSensorType, type: .info)
                }

                libreData = Data(PreLibre2.decryptFRAM(uid, Array(info), Array(libreData)))

            } else {

                return false

            }

            // replace 344 bytes to Decrypted data
            rxBuffer.replaceSubrange(headerLength..<(rxBufferEnd + 1), with: libreData)

            return true

        }

        return false

    }

    /// checks crc if needed for the sensor type
    func crcIsOk(rxBuffer:inout Data, headerLength: Int, log: OSLog?) -> Bool {

        guard Crc.LibreCrc(data: &rxBuffer, headerOffset: headerLength, libreSensorType: self) else {

            if let log = log {
                trace("    in crcIsOk, CRC check failed", log: log, category: ConstantsLog.categoryCGMBubble, type: .info)
            }

            return false
        }

        return true

    }
}
