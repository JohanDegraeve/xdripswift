import AVFoundation
import Foundation
import OSLog

#if canImport(CoreNFC)
@preconcurrency import CoreNFC

// source : https://github.com/gui-dos/DiaBLE/tree/master/DiaBLE

fileprivate struct NFCCommand {
    let code: UInt8
    let parameters: Data
}

// source : https://github.com/gui-dos/DiaBLE/tree/master/DiaBLE class Sensor
fileprivate enum Subcommand: UInt8, CustomStringConvertible {
    case activate = 0x1B
    case enableStreaming = 0x1E
    case unknown0x1a = 0x1A
    case unknown0x1c = 0x1C
    case unknown0x1d = 0x1D
    case unknown0x1f = 0x1F
    
    var description: String {
        switch self {
        case .activate: return "activate"
        case .enableStreaming: return "enable BLE streaming"
        default: return "[unknown: 0x\(String(format: "%x", rawValue))]"
        }
    }
}

// MARK: - Async CoreNFC helpers (avoid capturing self inside SDK callbacks)

fileprivate func customCommandAsync(tag: NFCISO15693Tag, requestFlags: NFCISO15693RequestFlag = .highDataRate, code: Int, params: Data) async throws -> Data {
    try await withCheckedThrowingContinuation { cont in
        tag.customCommand(requestFlags: requestFlags, customCommandCode: code, customRequestParameters: params) { response, error in
            if let error = error {
                cont.resume(throwing: error)
            } else {
                cont.resume(returning: response)
            }
        }
    }
}

fileprivate func readMultipleBlocksAsync(tag: NFCISO15693Tag, requestFlags: NFCISO15693RequestFlag = [.highDataRate, .address], blockRange: NSRange) async throws -> [Data] {
    try await withCheckedThrowingContinuation { cont in
        tag.readMultipleBlocks(requestFlags: requestFlags, blockRange: blockRange) { blockArray, error in
            if let error = error {
                cont.resume(throwing: error)
            } else {
                cont.resume(returning: blockArray)
            }
        }
    }
}

fileprivate func extendedWriteSingleBlockAsync(tag: NFCISO15693Tag, blockNumber: Int, dataBlock: Data) async throws {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        tag.extendedWriteSingleBlock(requestFlags: .highDataRate, blockNumber: blockNumber, dataBlock: dataBlock) { error in
            if let error = error {
                cont.resume(throwing: error)
            } else {
                cont.resume(returning: ())
            }
        }
    }
}

fileprivate func writeMultipleBlocksAsync(tag: NFCISO15693Tag, blockRange: NSRange, dataBlocks: [Data]) async throws {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        tag.writeMultipleBlocks(requestFlags: [.highDataRate, .address], blockRange: blockRange, dataBlocks: dataBlocks) { error in
            if let error = error {
                cont.resume(throwing: error)
            } else {
                cont.resume(returning: ())
            }
        }
    }
}

// Wrapper to allow capturing the ISO15693 tag inside @Sendable closures
private final class NFCISO15693TagWrapper: @unchecked Sendable {
    let tag: NFCISO15693Tag
    init(_ tag: NFCISO15693Tag) { self.tag = tag }
}

class LibreNFC: NSObject, NFCTagReaderSessionDelegate {
    // MARK: - properties
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLibreNFC)
    
    /// will be used to pass back info like sensorUid , patchInfo to delegate
    private(set) weak var libreNFCDelegate: LibreNFCDelegate?
    
    /// fixed unlock code to use
    private let unlockCode: UInt32 = 42
    
    /// use to keep track of if a successful NFC scan has happened
    private var nfcScanSuccessful: Bool = false
    
    /// use to keep track of the sensor serial number so that we can pass it back to the delegate
    private var serialNumber: String = ""
    
    /// use to keep track of the sensor mac address so that we can pass it back to the delegate (for new Libre 2 Plus)
    private var macAddress: String = ""
    
    // MARK: - initalizer
    
    init(libreNFCDelegate: LibreNFCDelegate) {
        self.libreNFCDelegate = libreNFCDelegate
    }
    
    // MARK: - public functions
    
    public func startSession() {
        guard NFCTagReaderSession.readingAvailable else {
            xdrip.trace("NFC: NFC is not available@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
            
            return
        }
        
        if let tagSession = NFCTagReaderSession(pollingOption: [.iso15693], delegate: self, queue: .main) {
            // make sure the this is (re)set to false before we start scanning
            self.nfcScanSuccessful = false
            
            tagSession.alertMessage = TextsLibreNFC.holdTopOfIphoneNearSensor
            
            tagSession.begin()
        }
    }
    
    // MARK: - NFCTagReaderSessionDelegate functions
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        xdrip.trace("NFC: tag reader session did become active. Waiting to detect tag/sensor.", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {
            switch readerError.code {
            case .readerSessionInvalidationErrorSessionTimeout:
                
                xdrip.trace("NFC: scan time-out error", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
                
            case .readerSessionInvalidationErrorUserCanceled:

                xdrip.trace("NFC: user cancelled the NFC scan", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
                
            default:
                
                var debugInfo = "NFC: scan error code: " + readerError.errorCode.description
                xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)
                
                debugInfo = "NFC: scan error message: " + readerError.localizedDescription
                xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)
            }
            
            // if we have generated a successful NFC scan and been able to correctly parse out the needed data, then inform the user and start BLE scanning. If not, inform the user and offer to scan again
            if self.nfcScanSuccessful {
                xdrip.trace("NFC: passing NFC scan successful to the delegate and starting BLE scanning", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
                
                self.libreNFCDelegate?.nfcScanResult(successful: true)
                
                self.libreNFCDelegate?.nfcScanExpectedDevice(serialNumber: self.serialNumber, macAddress: self.macAddress)
                
                self.libreNFCDelegate?.startBLEScanning()
                
            } else {
                xdrip.trace("NFC: passing NFC scan error to the delegate", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
                
                // play "failed" vibration
                AudioServicesPlaySystemSound(1107)
                
                self.libreNFCDelegate?.nfcScanResult(successful: false)
            }
        }
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        xdrip.trace("NFC: did detect tags", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)

        guard let firstTag = tags.first else { return }
        guard case .iso15693(let tag) = firstTag else { return }

        Task { @MainActor in
            let blocks = 43
            let requestBlocks = 3
            let requests = Int(ceil(Double(blocks) / Double(requestBlocks)))
            let remainder = blocks % requestBlocks
            var dataArray = [Data](repeating: Data(), count: blocks)

            var patchInfo = Data()
            var systemInfo: NFCISO15693SystemInfo!

            let retries = ConstantsLibre.retryAttemptsForLibre2NFCScans
            var requestedRetry = 0

            // Connect with retries
            while true {
                do {
                    if requestedRetry > 0 {
                        let debugInfo = "NFC: connecting to tag, retry attempt # \(requestedRetry)/\(retries)"
                        xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)

                        let alertMessage = TextsLibreNFC.nfcErrorMessageScanErrorRetrying + requestedRetry.description + "/" + retries.description
                        session.alertMessage = alertMessage

                        self.scanRepeatHapticFeedback()
                        try await Task.sleep(nanoseconds: 200000000)
                    } else {
                        xdrip.trace("NFC: connecting to tag", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
                    }

                    try await session.connect(to: firstTag)
                    break
                } catch {
                    xdrip.trace("NFC:       error: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, error.localizedDescription)

                    if requestedRetry >= retries {
                        let debugInfo = "NFC:       fatal error: stopped trying to connect after \(requestedRetry) attempts: \(error.localizedDescription)"
                        xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)

                        session.invalidate(errorMessage: TextsLibreNFC.nfcErrorMessageScanFailed)
                        return
                    }

                    requestedRetry += 1
                }
            }

            xdrip.trace("NFC:     - tag response OK, now let's get systemInfo and patchInfo", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
            requestedRetry = 0

            // Get systemInfo + patchInfo with retries
            while true {
                do {
                    // Libre 3 workaround: call A1 before systemInfo
                    patchInfo = try await customCommandAsync(tag: tag, code: 0xA1, params: Data())
                    if requestedRetry == 0 {
                        xdrip.trace("NFC:     calling 0xA1 before getting sytemInfo", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
                    } else {
                        let debugInfo = "NFC:     calling 0xA1 before getting sytemInfo - retry attempt # \(requestedRetry)/\(retries)"
                        xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)
                    }

                    systemInfo = try await tag.systemInfo(requestFlags: .highDataRate)
                    if requestedRetry == 0 {
                        xdrip.trace("NFC:     getting tag sytemInfo", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
                    } else {
                        let debugInfo = "NFC:     getting tag sytemInfo, retry attempt # \(requestedRetry)/\(retries)"
                        xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)
                    }

                    self.scanRepeatHapticFeedback()
                    break
                } catch {
                    let debugInfo = "NFC:     - error while getting tag info: \(error.localizedDescription)"
                    xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)

                    if requestedRetry >= retries {
                        let debugInfo = "NFC:     fatal error: stopped retrying to get tag systemInfo after \(requestedRetry) attempts"
                        xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)

                        session.invalidate(errorMessage: TextsLibreNFC.nfcErrorMessageScanFailed)
                        return
                    }

                    requestedRetry += 1
                }
            }

            // Best-effort refresh
            do {
                patchInfo = try await customCommandAsync(tag: tag, code: 0xA1, params: Data())
            } catch {
                // keep previous patchInfo if this fails
            }

            xdrip.trace("NFC:     systemInfo and patchInfo retrieved. Let's try and process them.", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)

            // Read FRAM blocks
            for i in 0 ..< requests {
                let start = UInt8(i * requestBlocks)
                let end = UInt8(i * requestBlocks + (i == requests - 1 ? (remainder == 0 ? requestBlocks : remainder) : requestBlocks) - (requestBlocks > 1 ? 1 : 0))
                do {
                    let blocks = try await readMultipleBlocksAsync(tag: tag, blockRange: NSRange(start ... end))
                    for j in 0 ..< blocks.count {
                        dataArray[i * requestBlocks + j] = blocks[j]
                    }
                } catch {
                    let debugInfo = "NFC: error while reading multiple blocks (#\(i * requestBlocks) - #\(i * requestBlocks + (i == requests - 1 ? (remainder == 0 ? requestBlocks : remainder) : requestBlocks) - (requestBlocks > 1 ? 1 : 0))): " + error.localizedDescription
                    xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)

                    session.invalidate(errorMessage: TextsLibreNFC.nfcErrorMessageScanFailed)
                    if i != requests - 1 { return }
                }
            }

            var fram = Data()
            var msg = ""
            for (n, data) in dataArray.enumerated() {
                if data.count > 0 {
                    fram.append(data)
                    msg += "NFC: block #\(String(format: "%02d", n))  \(data.reduce("") { $0 + String(format: "%02X", $1) + " " }.dropLast())\n"
                }
            }
            if !msg.isEmpty {
                xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, String(msg.dropLast()))
            }

            self.traceICIdentifier(tag: tag)
            self.traceICManufacturer(tag: tag)
            self.traceICSerialNumber(tag: tag)
            self.traceROM(tag: tag)
            self.traceICReference(systemInfo: systemInfo)
            self.traceApplicationFamilyIdentifier(systemInfo: systemInfo)
            self.traceDataStorageFormatIdentifier(systemInfo: systemInfo)
            self.traceMemorySize(systemInfo: systemInfo)
            self.traceBlockSize(systemInfo: systemInfo)

            let sensorUID = Data(tag.identifier.reversed())
            guard patchInfo.count >= 6 else {
                xdrip.trace("NFC: received patchInfo has length < 6", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info)
                session.invalidate(errorMessage: TextsLibreNFC.nfcErrorMessageScanFailed)
                return
            }

            self.libreNFCDelegate?.received(sensorUID: sensorUID, patchInfo: patchInfo)
            self.traceSensorUID(sensorUID: sensorUID)
            self.tracePatchInfo(patchInfo: patchInfo)
            self.libreNFCDelegate?.received(fram: fram)

            // Enable streaming
            let subCmd: Subcommand = .enableStreaming
            let cmd = self.nfcCommand(subCmd, unlockCode: self.unlockCode, patchInfo: patchInfo, sensorUID: sensorUID)
            let info = "NFC: sending Libre 2 command to " + subCmd.description + " : code: 0x" + String(format: "%0X", cmd.code) + ", parameters: 0x" + cmd.parameters.toHexString() + "unlock code: " + self.unlockCode.description
            xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, info)

            do {
                let response = try await customCommandAsync(tag: tag, code: Int(cmd.code), params: cmd.parameters)
                let respLog = "NFC: '" + subCmd.description + " command response " + response.count.description + " bytes : 0x" + response.toHexString() + ", error: nil"
                xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, respLog)

                if subCmd == .enableStreaming && response.count == 6 {
                    self.serialNumber = LibreSensorSerialNumber(withUID: sensorUID, with: LibreSensorType.type(patchInfo: patchInfo.toHexString()))?.serialNumber ?? "unknown"
                    self.macAddress = Data(response.reversed()).hexEncodedString().uppercased()

                    let ok = "NFC: successfully enabled BLE streaming on Libre 2 " + self.serialNumber + " unlock code: " + self.unlockCode.description + " MAC address: " + self.macAddress
                    xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, ok)

                    session.alertMessage = TextsLibreNFC.scanComplete
                    self.nfcScanSuccessful = true
                    self.libreNFCDelegate?.streamingEnabled(successful: true)
                } else {
                    self.libreNFCDelegate?.streamingEnabled(successful: false)
                }
            } catch {
                let respLog = "NFC: '" + subCmd.description + " command error: " + error.localizedDescription
                xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, respLog)
                self.libreNFCDelegate?.streamingEnabled(successful: false)
            }

            session.invalidate()
        }
    }
    
    // MARK: - helper functions

    func readRaw(_ address: UInt16, _ bytes: Int, buffer: Data = Data(), tag: NFCISO15693Tag, handler: @escaping (UInt16, Data, Error?) -> Void) {
        let tagWrapper = NFCISO15693TagWrapper(tag)
        var buffer = buffer
        let addressToRead = address + UInt16(buffer.count)
        
        var remainingBytes = bytes
        let bytesToRead = remainingBytes > 24 ? 24 : bytes
        
        var remainingWords = bytes / 2
        if bytes % 2 == 1 || (bytes % 2 == 0 && addressToRead % 2 == 1) { remainingWords += 1 }
        let wordsToRead = UInt8(remainingWords > 12 ? 12 : remainingWords) // real limit is 15
        
        // this is for libre 2 only, ignoring other libre types
        let readRawCommand = NFCCommand(code: 0xB3, parameters: Data([UInt8(addressToRead & 0x00FF), UInt8(addressToRead >> 8), wordsToRead]))
        
        if buffer.count == 0 {
            xdrip.trace("NFC: sending 0x%{public}@ 0x07 0x%{public}@ command (%{public}@ read raw)", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, readRawCommand.code.description, readRawCommand.parameters.toHexString(), "libre 2")
        }

        tagWrapper.tag.customCommand(requestFlags: .highDataRate, customCommandCode: Int(readRawCommand.code), customRequestParameters: readRawCommand.parameters) {
            response, error in
            
            var data = response
            
            if error != nil {
                xdrip.trace("NFC: error while reading %{public}@ words at raw memory 0x%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, wordsToRead.description, addressToRead.description)

                remainingBytes = 0
                
            } else {
                if addressToRead % 2 == 1 { data = data.subdata(in: 1 ..< data.count) }
                if data.count - Int(bytesToRead) == 1 { data = data.subdata(in: 0 ..< data.count - 1) }
            }
            
            buffer += data
            remainingBytes -= data.count
            
            if remainingBytes == 0 {
                handler(address, buffer, error)
            } else {
                self.readRaw(address, remainingBytes, buffer: buffer, tag: tagWrapper.tag) { address, data, error in handler(address, data, error) }
            }
        }
    }

    func writeRaw(_ address: UInt16, _ data: Data, tag: NFCISO15693Tag, handler: @escaping (UInt16, Data, Error?) -> Void) {
        let tagWrapper = NFCISO15693TagWrapper(tag)
        let backdoor = [UInt8]([0xDE, 0xAD, 0xBE, 0xEF]) // "deadbeef".bytes
        
        // Unlock
        xdrip.trace("NFC: sending 0xa4 0x07 0x%{public}@ command (%{public}@ unlock)", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, Data(backdoor).toHexString(), "libre 2")

        tagWrapper.tag.customCommand(requestFlags: .highDataRate, customCommandCode: 0xA4, customRequestParameters: Data(backdoor)) {
            response, error in
            
            xdrip.trace("NFC: unlock command response: 0x%{public}@, error: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, response.toHexString(), error?.localizedDescription ?? "none")
            
            let addressToRead = (address / 8) * 8
            let startOffset = Int(address % 8)
            let endAddressToRead = ((Int(address) + data.count - 1) / 8) * 8 + 7
            let blocksToRead = (endAddressToRead - Int(addressToRead)) / 8 + 1
            
            self.readRaw(addressToRead, blocksToRead * 8, tag: tagWrapper.tag) { readAddress, readData, error in

                var msg = error?.localizedDescription ?? readData.hexDump(address: Int(readAddress), header: "NFC: blocks to overwrite:")
                
                if error != nil {
                    handler(address, data, error)
                    return
                }
                
                var bytesToWrite = readData
                bytesToWrite.replaceSubrange(startOffset ..< startOffset + data.count, with: data)
                msg += "\(bytesToWrite.hexDump(address: Int(addressToRead), header: "\nwith blocks:"))"
                
                xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, msg)
                
                let startBlock = Int(addressToRead / 8)
                let blocks = bytesToWrite.count / 8
                
                if address < 0xF860 { // lower than FRAM blocks
                    for i in 0 ..< blocks {
                        let blockToWrite = bytesToWrite[i * 8 ... i * 8 + 7]
                        
                        // FIXME: doesn't work as the custom commands C1 or A5 for other chips
                        tagWrapper.tag.extendedWriteSingleBlock(requestFlags: .highDataRate, blockNumber: startBlock + i, dataBlock: blockToWrite) { error in

                            var debugInfo = String(format: "%X", startBlock + i) + " " + Int(i + 1).description + " of " + blocks.description + " " + blockToWrite.toHexString() + " at 0x" + String(format: "%X", Int((startBlock + i) * 8))
                            
                            if let error = error {
                                debugInfo = "NFC: error while writing block 0x" + debugInfo + " : " + error.localizedDescription
                                
                                xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)

                                if i != blocks - 1 { return }
                                
                            } else {
                                debugInfo = "NFC: wrote block 0x" + debugInfo
                                
                                xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)
                            }
                            
                            if i == blocks - 1 {
                                // Lock
                                tagWrapper.tag.customCommand(requestFlags: .highDataRate, customCommandCode: 0xA2, customRequestParameters: Data(backdoor)) { response, error in
                                    
                                    xdrip.trace("NFC: lock command response: 0x%{public}@, error: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, response.toHexString(), error?.localizedDescription ?? "none")
                                    
                                    handler(address, data, error)
                                }
                            }
                        }
                    }
                    
                } else { // address >= 0xF860: write to FRAM blocks
                    let requestBlocks = 2 // 3 doesn't work
                    
                    let requests = Int(ceil(Double(blocks) / Double(requestBlocks)))
                    let remainder = blocks % requestBlocks
                    var blocksToWrite = [Data](repeating: Data(), count: blocks)
                    
                    for i in 0 ..< blocks {
                        blocksToWrite[i] = Data(bytesToWrite[i * 8 ... i * 8 + 7])
                    }
                    
                    for i in 0 ..< requests {
                        let startIndex = startBlock - 0xF860 / 8 + i * requestBlocks
                        let endIndex = startIndex + (i == requests - 1 ? (remainder == 0 ? requestBlocks : remainder) : requestBlocks) - (requestBlocks > 1 ? 1 : 0)
                        let blockRange = NSRange(UInt8(startIndex) ... UInt8(endIndex))
                        
                        var dataBlocks = [Data]()
                        for j in startIndex ... endIndex {
                            dataBlocks.append(blocksToWrite[j - startIndex])
                        }
                        
                        // snapshot to avoid mutation-after-capture compiler warning
                        let dataBlocksSnapshot = dataBlocks
                        
                        // TODO: write to 16-bit addresses as the custom cummand C4 for other chips
                        tagWrapper.tag.writeMultipleBlocks(requestFlags: [.highDataRate, .address], blockRange: blockRange, dataBlocks: dataBlocksSnapshot) {
                            error in // TEST

                            var debugInfo = String(format: "%X", startIndex) + " - 0x" + String(format: "%X", endIndex) + dataBlocksSnapshot.reduce("") { $0 + $1.toHexString() } + " at 0x" + String(format: "%X", (startBlock + i * requestBlocks) * 8)

                            if error != nil {
                                debugInfo = "NFC: error while writing multiple blocks 0x" + debugInfo + " : " + error!.localizedDescription
                                
                                xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)
                                
                                if i != requests - 1 { return }
                                
                            } else {
                                debugInfo = "NFC: wrote blocks 0x" + debugInfo
                                
                                xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)
                            }
                            
                            if i == requests - 1 {
                                // Lock
                                tagWrapper.tag.customCommand(requestFlags: .highDataRate, customCommandCode: 0xA2, customRequestParameters: Data(backdoor)) {
                                    response, error in
                                    
                                    let debugInfo = "NFC: lock command response: 0x" + response.toHexString() + "error: " + (error?.localizedDescription ?? "none")
                                    
                                    xdrip.trace("%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, debugInfo)
                                    
                                    handler(address, data, error)
                                }
                            }
                        } // TEST writeMultipleBlocks
                    }
                }
            }
        }
    }

    private func trace(systemError: Error?, ownErrorString: String, session: NFCTagReaderSession) {
        if let systemError = systemError {
            xdrip.trace("NFC: error : %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, systemError.localizedDescription)
        }
    }
    
    private func traceICIdentifier(tag: NFCISO15693Tag) {
        xdrip.trace("NFC: IC identifier: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, tag.identifier.toHexString())
    }
   
    private func traceICManufacturer(tag: NFCISO15693Tag) {
        var manufacturer = String(tag.icManufacturerCode)
        if manufacturer == "7" {
            manufacturer.append(" (Texas Instruments)")
        } else if manufacturer == "122" {
            manufacturer.append(" (Abbott Diabetes Care)")
        }

        xdrip.trace("NFC: IC manufacturer code: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, manufacturer)
    }
    
    private func traceICSerialNumber(tag: NFCISO15693Tag) {
        xdrip.trace("NFC: IC serial number: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, tag.icSerialNumber.toHexString())
    }

    private func traceROM(tag: NFCISO15693Tag) {
        var rom = "RF430"
        switch tag.identifier[2] {
        case 0xA0: rom += "TAL152H Libre 1 A0"
        case 0xA4: rom += "TAL160H Libre 2 A4"
        default: rom = String(tag.identifier[2])
        }

        xdrip.trace("NFC: %{public}@ ROM", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, rom)
    }
    
    private func traceICReference(systemInfo: NFCISO15693SystemInfo) {
        xdrip.trace("NFC: IC reference: 0x%{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, systemInfo.icReference.description)
    }
    
    private func traceApplicationFamilyIdentifier(systemInfo: NFCISO15693SystemInfo) {
        if systemInfo.applicationFamilyIdentifier != -1 {
            xdrip.trace("NFC: application family id (AFI): %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, systemInfo.applicationFamilyIdentifier.description)
        }
    }

    private func traceDataStorageFormatIdentifier(systemInfo: NFCISO15693SystemInfo) {
        if systemInfo.dataStorageFormatIdentifier != -1 {
            xdrip.trace("NFC: data storage format id: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, systemInfo.dataStorageFormatIdentifier.description)
        }
    }
    
    private func traceMemorySize(systemInfo: NFCISO15693SystemInfo) {
        xdrip.trace("NFC: memory size: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, systemInfo.totalBlocks.description)
    }
    
    private func traceBlockSize(systemInfo: NFCISO15693SystemInfo) {
        xdrip.trace("NFC: block size: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, systemInfo.blockSize.description)
    }
    
    private func traceSensorUID(sensorUID: Data) {
        xdrip.trace("NFC: sensorUID: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, sensorUID.toHexString())
    }
    
    private func tracePatchInfo(patchInfo: Data) {
        xdrip.trace("NFC: patchInfo: %{public}@", log: self.log, category: ConstantsLog.categoryLibreNFC, type: .info, patchInfo.toHexString())
    }
    
    private func nfcCommand(_ code: Subcommand, unlockCode: UInt32, patchInfo: Data, sensorUID: Data) -> NFCCommand {
        var b: [UInt8] = []
        var y: UInt16
        
        if code == .enableStreaming {
            // Enables Bluetooth on Libre 2. Returns peripheral MAC address to connect to.
            // unlockCode could be any 32 bit value. The unlockCode and sensor Uid / patchInfo
            // will have also to be provided to the login function when connecting to peripheral.
            
            b = [
                UInt8(unlockCode & 0xFF),
                UInt8((unlockCode >> 8) & 0xFF),
                UInt8((unlockCode >> 16) & 0xFF),
                UInt8((unlockCode >> 24) & 0xFF)
            ]
            
            y = UInt16(patchInfo[4 ... 5]) ^ UInt16(b[1], b[0])
            
        } else {
            y = 0x1B6A
        }
        
        let d = PreLibre2.usefulFunction(sensorUID: sensorUID, x: UInt16(code.rawValue), y: y)
        
        var parameters = Data([code.rawValue])
        
        if code == .enableStreaming {
            parameters += b
        }
        
        parameters += d
        
        return NFCCommand(code: 0xA1, parameters: parameters)
    }
    
    /// this just centralises the system sound that we will fire every time we scan the sensor in each loop.
    private func scanRepeatHapticFeedback() {
        // play "peek" vibration
        AudioServicesPlaySystemSound(1519)
    }
}

#endif
